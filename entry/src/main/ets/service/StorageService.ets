import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Logger } from '../utils/Logger';
import { CryptoService } from './CryptoService';
import { AppContextHolder } from '../utils/AppContextHolder';
import { generateUuid } from '../utils/UUIDUtils';
import { DatabaseModel } from '../model/DatabaseModel';
import { TotpItem } from '../model/TotpItem';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { DATABASE_FILE_NAME, CURRENT_SCHEMA_VERSION } from '../constants/AppConstants';

const OPEN_READ_ONLY: number = 0;
const OPEN_WRITE_CREATE_TRUNC: number = 0o2 | 0o100 | 0o1000;
const TMP_SUFFIX: string = '.tmp';
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
        const emptyDb: DatabaseModel = this.createEmptyDatabase();
        this.database = emptyDb;
        return ok(emptyDb);
      }
      const bytes: Uint8Array = this.readFile();
      if (bytes.length === 0) {
        const emptyDb: DatabaseModel = this.createEmptyDatabase();
        this.database = emptyDb;
        return ok(emptyDb);
      }
      const plainBytes: Uint8Array = await this.cryptoService.decrypt(bytes, encryptionSecret);
      const json: string = new util.TextDecoder().decode(plainBytes);
      const parsed: DatabaseModel = JSON.parse(json) as DatabaseModel;
      if (!this.validateDatabase(parsed)) {
        Logger.error('Storage load: invalid database schema');
        return err<DatabaseModel>(AppErrorCode.INVALID_ENCRYPTED_FILE, '数据库格式无效');
      }
      this.database = parsed;
      return ok(parsed);
    } catch (error) {
      Logger.error('Storage load failed');
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
      return ok(undefined);
    } catch (error) {
      Logger.error('Storage save failed');
      return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, '保存数据失败');
    }
  }

  async replaceDatabase(database: DatabaseModel, encryptionSecret: string): Promise<Result<void>> {
    return this.saveDatabase(database, encryptionSecret);
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
        return err<Uint8Array>(AppErrorCode.STORAGE_READ_FAILED, '本地尚无数据');
      }
      return ok(this.readFile());
    } catch (error) {
      Logger.error('Storage read encrypted file failed');
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
