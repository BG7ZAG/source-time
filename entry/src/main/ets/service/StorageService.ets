import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Logger } from '../utils/Logger';
import { CryptoService } from './CryptoService';
import { AppContextHolder } from '../utils/AppContextHolder';
import { generateUuid } from '../utils/UUIDUtils';
import { nowMilliseconds } from '../utils/TimeUtils';
import { DatabaseModel } from '../model/DatabaseModel';
import { TotpItem } from '../model/TotpItem';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { DATABASE_FILE_NAME, CURRENT_SCHEMA_VERSION } from '../constants/AppConstants';

const OPEN_READ_ONLY: number = 0;
const OPEN_WRITE_CREATE_TRUNC: number = 0o2 | 0o100 | 0o1000;
const TMP_SUFFIX: string = '.tmp';
const ORPHAN_SUFFIX: string = '.orphan';
const VALID_ALGORITHMS: string[] = ['SHA1', 'SHA256', 'SHA512'];

export class StorageService {
  private static instance: StorageService | null = null;

  private cryptoService: CryptoService = new CryptoService();
  private database: DatabaseModel | null = null;
  private dbPath: string;
  private tmpPath: string;

  constructor() {
    const context = AppContextHolder.getContext();
    this.dbPath = context.filesDir + '/' + DATABASE_FILE_NAME;
    this.tmpPath = this.dbPath + TMP_SUFFIX;
  }

  static getInstance(): StorageService {
    if (StorageService.instance === null) {
      StorageService.instance = new StorageService();
    }
    return StorageService.instance;
  }

  isInitialized(): boolean {
    try {
      return fs.accessSync(this.dbPath);
    } catch (error) {
      return false;
    }
  }

  async initialize(): Promise<Result<void>> {
    this.database = null;
    return ok(undefined);
  }

  async loadDatabase(encryptionSecret: string): Promise<Result<DatabaseModel>> {
    try {
      if (!this.isInitialized()) {
        // 本地还没有密文文件：返回空库（首次使用或刚清库后的正常状态），不视为错误
        const emptyDb: DatabaseModel = this.createEmptyDatabase();
        this.database = emptyDb;
        Logger.info('Storage load: local database not initialized, using empty database', 'Storage');
        return ok(emptyDb);
      }
      const bytes: Uint8Array = this.readFile();
      if (bytes.length === 0) {
        const emptyDb: DatabaseModel = this.createEmptyDatabase();
        this.database = emptyDb;
        Logger.warn('Storage load: encrypted file is empty, using empty database', 'Storage');
        return ok(emptyDb);
      }
      const plainBytes: Uint8Array = await this.cryptoService.decrypt(bytes, encryptionSecret);
      const json: string = new util.TextDecoder().decode(plainBytes);
      const parsed: DatabaseModel = JSON.parse(json) as DatabaseModel;
      if (!this.validateDatabase(parsed)) {
        Logger.error('Storage load: invalid database schema', 'Storage');
        return err<DatabaseModel>(AppErrorCode.INVALID_ENCRYPTED_FILE, '数据库格式无效');
      }
      this.database = parsed;
      Logger.info('Storage load ok: items=' + parsed.items.length + ' revision=' + parsed.revision
        + ' bytes=' + bytes.length, 'Storage');
      return ok(parsed);
    } catch (error) {
      Logger.error('Storage load failed: decrypt error (key mismatch or corrupted file)', 'Storage');
      return err<DatabaseModel>(AppErrorCode.DECRYPT_FAILED, '无法解密数据，请确认加密密钥是否正确');
    }
  }

  async saveDatabase(database: DatabaseModel, encryptionSecret: string): Promise<Result<void>> {
    try {
      const json: string = JSON.stringify(database);
      const plainBytes: Uint8Array = new util.TextEncoder().encodeInto(json);
      const encrypted: Uint8Array = await this.cryptoService.encrypt(plainBytes, encryptionSecret);
      this.atomicWrite(encrypted);
      this.database = database;
      Logger.info('Storage save ok: items=' + database.items.length + ' revision=' + database.revision
        + ' bytes=' + encrypted.length, 'Storage');
      return ok(undefined);
    } catch (error) {
      Logger.error('Storage save failed', 'Storage');
      return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, '保存数据失败');
    }
  }

  async replaceDatabase(database: DatabaseModel, encryptionSecret: string): Promise<Result<void>> {
    return this.saveDatabase(database, encryptionSecret);
  }

  /**
   * 隔离当前无法解密的本地数据文件，并返回一个全新的空数据库。
   *
   * 场景：加密密钥丢失 / 变更后，本地的 totp.db.enc 已无法用当前密钥解开，
   * 若不处理会导致「读取失败 → 新增/删除全部失败」的死锁。
   *
   * 安全性：只做同目录**重命名**（totp.db.enc → totp.db.enc.orphan-<时间戳>），
   * 不删除任何字节；原密文仍留在磁盘上，日后用原密钥仍可手动恢复。
   */
  async quarantineUnreadableDatabase(): Promise<Result<DatabaseModel>> {
    try {
      if (this.isInitialized()) {
        const orphanPath: string = this.dbPath + ORPHAN_SUFFIX + '-' + nowMilliseconds().toString();
        fs.renameSync(this.dbPath, orphanPath);
        Logger.info('Unreadable database quarantined: ' + orphanPath);
      }
      const emptyDb: DatabaseModel = this.createEmptyDatabase();
      this.database = emptyDb;
      return ok(emptyDb);
    } catch (error) {
      Logger.error('Storage quarantine failed');
      return err<DatabaseModel>(AppErrorCode.STORAGE_WRITE_FAILED, '清除本地数据失败');
    }
  }

  /**
   * 物理删除本地加密数据文件（含临时文件与历史隔离备份），不可恢复。
   *
   * 与 quarantineUnreadableDatabase()（同目录重命名、保留字节）不同：本方法真正 unlink，
   * 只用于「忘记密钥」这类用户已明确要求销毁数据的场景。
   */
  async deleteLocalDatabase(): Promise<Result<void>> {
    this.database = null;
    const dir: string = AppContextHolder.getContext().filesDir;
    // 待删清单：当前密文、写入临时文件、以及历史隔离备份 totp.db.enc.orphan-<时间戳>
    const targets: string[] = [this.dbPath, this.tmpPath];
    try {
      const names: string[] = fs.listFileSync(dir);
      const orphanPrefix: string = DATABASE_FILE_NAME + ORPHAN_SUFFIX;
      for (const name of names) {
        if (name.startsWith(orphanPrefix)) {
          targets.push(dir + '/' + name);
        }
      }
    } catch (error) {
      // 列目录失败不阻断主流程：仍继续删除当前密文
      Logger.error('Storage delete: list files failed');
    }
    for (const path of targets) {
      try {
        fs.unlinkSync(path);
        Logger.info('Local encrypted file removed: ' + path);
      } catch (error) {
        // 文件本就不存在属正常情况，忽略
      }
    }
    Logger.info('Local encrypted data physically deleted');
    return ok(undefined);
  }

  async changeEncryptionSecret(oldSecret: string, newSecret: string): Promise<Result<void>> {
    try {
      if (!this.isInitialized()) {
        return err<void>(AppErrorCode.KEY_REQUIRED, '尚无加密数据');
      }
      const bytes: Uint8Array = this.readFile();
      const plainBytes: Uint8Array = await this.cryptoService.decrypt(bytes, oldSecret);
      const reEncrypted: Uint8Array = await this.cryptoService.encrypt(plainBytes, newSecret);
      this.atomicWrite(reEncrypted);
      return ok(undefined);
    } catch (error) {
      Logger.error('Storage change key failed');
      return err<void>(AppErrorCode.INVALID_KEY, '当前密钥不正确');
    }
  }

  getDatabase(): DatabaseModel | null {
    return this.database;
  }

  readEncryptedFile(): Result<Uint8Array> {
    try {
      if (!this.isInitialized()) {
        Logger.warn('Storage read skipped: local database not initialized', 'Storage');
        return err<Uint8Array>(AppErrorCode.STORAGE_READ_FAILED, '本地尚无数据');
      }
      const bytes: Uint8Array = this.readFile();
      Logger.debug('Storage read encrypted file: bytes=' + bytes.length, 'Storage');
      return ok(bytes);
    } catch (error) {
      Logger.error('Storage read encrypted file failed', 'Storage');
      return err<Uint8Array>(AppErrorCode.STORAGE_READ_FAILED, '读取数据失败');
    }
  }

  async decodeEncryptedDatabase(bytes: Uint8Array, encryptionSecret: string): Promise<Result<DatabaseModel>> {
    try {
      const plainBytes: Uint8Array = await this.cryptoService.decrypt(bytes, encryptionSecret);
      const json: string = new util.TextDecoder().decode(plainBytes);
      const parsed: DatabaseModel = JSON.parse(json) as DatabaseModel;
      if (!this.validateDatabase(parsed)) {
        Logger.error('Storage decode: invalid database schema');
        return err<DatabaseModel>(AppErrorCode.INVALID_ENCRYPTED_FILE, '数据库格式无效');
      }
      return ok(parsed);
    } catch (error) {
      Logger.error('Storage decode encrypted database failed');
      return err<DatabaseModel>(AppErrorCode.DECRYPT_FAILED, '无法解密远程数据，请确认加密密钥是否正确');
    }
  }

  private createEmptyDatabase(): DatabaseModel {
    return {
      version: CURRENT_SCHEMA_VERSION,
      revision: 0,
      updatedAt: 0,
      deviceId: generateUuid(),
      items: []
    };
  }

  private readFile(): Uint8Array {
    const file = fs.openSync(this.dbPath, OPEN_READ_ONLY);
    try {
      const stat = fs.statSync(this.dbPath);
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      return new Uint8Array(buffer);
    } finally {
      fs.closeSync(file);
    }
  }

  private atomicWrite(data: Uint8Array): void {
    try {
      fs.unlinkSync(this.tmpPath);
    } catch (error) {
      // tmp may not exist, ignore
    }
    const file = fs.openSync(this.tmpPath, OPEN_WRITE_CREATE_TRUNC);
    try {
      const independent: Uint8Array = data.slice(0, data.length);
      fs.writeSync(file.fd, independent.buffer);
      fs.fsyncSync(file.fd);
    } finally {
      fs.closeSync(file);
    }
    const stat = fs.statSync(this.tmpPath);
    if (stat.size !== data.length) {
      try {
        fs.unlinkSync(this.tmpPath);
      } catch (error) {
        // ignore
      }
      throw new Error('STORAGE_WRITE_FAILED');
    }
    fs.renameSync(this.tmpPath, this.dbPath);
  }

  private validateDatabase(db: DatabaseModel): boolean {
    if (db.version !== CURRENT_SCHEMA_VERSION) {
      return false;
    }
    if (!Array.isArray(db.items)) {
      return false;
    }
    for (let i = 0; i < db.items.length; i++) {
      if (!this.validateTotpItem(db.items[i])) {
        return false;
      }
    }
    return true;
  }

  private validateTotpItem(item: TotpItem): boolean {
    if (typeof item.id !== 'string' || item.id.length === 0) {
      return false;
    }
    if (typeof item.issuer !== 'string') {
      return false;
    }
    if (typeof item.account !== 'string') {
      return false;
    }
    if (typeof item.secret !== 'string' || item.secret.length === 0) {
      return false;
    }
    if (VALID_ALGORITHMS.indexOf(item.algorithm) < 0) {
      return false;
    }
    if (item.digits !== 6 && item.digits !== 8) {
      return false;
    }
    if (typeof item.period !== 'number' || item.period <= 0) {
      return false;
    }
    return true;
  }
}
