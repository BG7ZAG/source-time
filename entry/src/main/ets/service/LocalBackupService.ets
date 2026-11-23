import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { DatabaseModel } from '../model/DatabaseModel';
import { LocalBackupKind, LocalBackupPreview } from '../model/LocalBackup';
import { CryptoService } from './CryptoService';
import { StorageService } from './StorageService';
import { SyncService } from './SyncService';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';

const OPEN_READ_ONLY: number = 0;
const OPEN_WRITE_CREATE_TRUNC: number = 0o2 | 0o100 | 0o1000;
/** 备份文件大小上限：正常备份只有几十 KB，超过该值基本是选错了文件。 */
const MAX_BACKUP_BYTES: number = 32 * 1024 * 1024;

/**
 * 本机备份与恢复。
 *
 * 加密备份直接复用 SyncService.buildEncryptedBackup()，与 WebDAV 推送产出同一份密文；
 * 明文备份是该密文解密后的 JSON。恢复时按文件头魔数自动识别两种格式，
 * 解析结果交给 UI 预览，用户确认后才写回本地库。
 */
export class LocalBackupService {
  private storageService: StorageService = StorageService.getInstance();
  private syncService: SyncService = SyncService.getInstance();

  /** 加密备份载荷：与 WebDAV 推送完全相同。 */
  async buildEncrypted(): Promise<Result<Uint8Array>> {
    return this.syncService.buildEncryptedBackup();
  }

  /** 明文备份载荷：解密当前库后序列化为 UTF-8 JSON。 */
  async buildPlain(encryptionSecret: string): Promise<Result<Uint8Array>> {
    const encrypted: Result<Uint8Array> = await this.buildEncrypted();
    if (!encrypted.success || encrypted.data === undefined) {
      return err<Uint8Array>(encrypted.error !== undefined ? encrypted.error.code : AppErrorCode.STORAGE_READ_FAILED,
        encrypted.error !== undefined ? encrypted.error.message : $r('app.string.local_backup_export_failed'));
    }
    const decoded: Result<DatabaseModel> =
      await this.storageService.decodeEncryptedDatabase(encrypted.data, encryptionSecret);
    if (!decoded.success || decoded.data === undefined) {
      Logger.error('Local plain backup decrypt failed', 'LocalBackup');
      return err<Uint8Array>(decoded.error !== undefined ? decoded.error.code : AppErrorCode.DECRYPT_FAILED,
        $r('app.string.local_backup_export_failed'));
    }
    const json: string = JSON.stringify(decoded.data);
    return ok(new util.TextEncoder().encodeInto(json));
  }

  /**
   * 自动识别备份格式并解析。
   *
   * 先看文件头：带 STOT 魔数按加密备份处理，其余按明文 JSON 处理。
   * 加密文件头正确但解密失败，说明用错了密钥，需要单独提示而不是笼统的「文件损坏」。
   */
  async inspect(bytes: Uint8Array, encryptionSecret: string): Promise<Result<LocalBackupPreview>> {
    if (bytes.length === 0) {
      return err<LocalBackupPreview>(AppErrorCode.INVALID_ENCRYPTED_FILE, $r('app.string.local_backup_empty_file'));
    }
    if (CryptoService.isEncryptedPayload(bytes)) {
      const decoded: Result<DatabaseModel> =
        await this.storageService.decodeEncryptedDatabase(bytes, encryptionSecret);
      if (!decoded.success || decoded.data === undefined) {
        const code: AppErrorCode = decoded.error !== undefined ? decoded.error.code : AppErrorCode.DECRYPT_FAILED;
        const message: ResourceStr = code === AppErrorCode.INVALID_ENCRYPTED_FILE
          ? $r('app.string.local_backup_unrecognized')
          : $r('app.string.local_backup_key_mismatch');
        Logger.warn('Local backup inspect failed: encrypted payload, code=' + code, 'LocalBackup');
        return err<LocalBackupPreview>(code, message);
      }
      return ok<LocalBackupPreview>({ kind: LocalBackupKind.ENCRYPTED, database: decoded.data });
    }
    const plain: Result<DatabaseModel> = this.storageService.parsePlainDatabase(bytes);
    if (!plain.success || plain.data === undefined) {
      Logger.warn('Local backup inspect failed: not a recognized backup format', 'LocalBackup');
      return err<LocalBackupPreview>(AppErrorCode.INVALID_ENCRYPTED_FILE, $r('app.string.local_backup_unrecognized'));
    }
    return ok<LocalBackupPreview>({ kind: LocalBackupKind.PLAIN, database: plain.data });
  }

  /** 将预览确认过的备份写回本地库（用当前密钥重新加密落盘）。 */
  async restore(database: DatabaseModel, encryptionSecret: string): Promise<Result<void>> {
    const result: Result<void> = await this.storageService.replaceDatabase(database, encryptionSecret);
    if (result.success) {
      Logger.info('Local backup restored: items=' + database.items.length + ' revision=' + database.revision,
        'LocalBackup');
    } else {
      const message: ResourceStr =
        result.error !== undefined ? result.error.message : $r('app.string.local_backup_restore_failed');
      Logger.error('Local backup restore failed: ' + (typeof message === 'string' ? message : 'see ui message'),
        'LocalBackup');
    }
    return result;
  }

  /** 把备份字节写入用户通过系统保存框选定的位置。 */
  writeToUri(uri: string, data: Uint8Array): Result<void> {
    try {
      const file = fs.openSync(uri, OPEN_WRITE_CREATE_TRUNC);
      try {
        // slice 生成独立 ArrayBuffer，避免把视图共享的底层缓冲区整个写出去
        const independent: Uint8Array = data.slice(0, data.length);
        fs.writeSync(file.fd, independent.buffer);
        fs.fsyncSync(file.fd);
      } finally {
        fs.closeSync(file);
      }
      Logger.info('Local backup written: uriLen=' + uri.length + ' bytes=' + data.length, 'LocalBackup');
      return ok(undefined);
    } catch (error) {
      Logger.error('Local backup write failed: uriLen=' + uri.length, 'LocalBackup');
      return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, $r('app.string.local_backup_write_failed'));
    }
  }

  /** 读取用户通过系统文件选择器选中的备份文件。 */
  readFromUri(uri: string): Result<Uint8Array> {
    try {
      const stat = fs.statSync(uri);
      if (stat.size <= 0) {
        return err<Uint8Array>(AppErrorCode.INVALID_ENCRYPTED_FILE, $r('app.string.local_backup_empty_file'));
      }
      if (stat.size > MAX_BACKUP_BYTES) {
        Logger.warn('Local backup read rejected: size=' + stat.size, 'LocalBackup');
        return err<Uint8Array>(AppErrorCode.INVALID_ENCRYPTED_FILE, $r('app.string.local_backup_too_large'));
      }
      const file = fs.openSync(uri, OPEN_READ_ONLY);
      try {
        const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buffer);
        return ok(new Uint8Array(buffer));
      } finally {
        fs.closeSync(file);
      }
    } catch (error) {
      Logger.error('Local backup read failed: uriLen=' + uri.length, 'LocalBackup');
      return err<Uint8Array>(AppErrorCode.STORAGE_READ_FAILED, $r('app.string.local_backup_read_failed'));
    }
  }
}