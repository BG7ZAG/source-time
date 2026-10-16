import { TotpItem } from '../model/TotpItem';
import { DatabaseModel } from '../model/DatabaseModel';
import { SyncStatus, SyncReason } from '../model/SyncModel';
import { LocalRepository } from '../repository/LocalRepository';
import { TotpService } from '../service/TotpService';
import { ClipboardService } from '../service/ClipboardService';
import { SyncService } from '../service/SyncService';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';
import { nowMilliseconds } from '../utils/TimeUtils';

export interface TotpDisplayItem {
  item: TotpItem;
}

export class HomeViewModel {
  items: TotpItem[] = [];
  loading: boolean = false;
  syncing: boolean = false;
  syncStatus: SyncStatus = SyncStatus.IDLE;
  lastSyncAt: number = 0;

  private repository: LocalRepository = new LocalRepository();
  private totpService: TotpService = new TotpService();
  private clipboardService: ClipboardService = new ClipboardService();
  private encryptionSecret: string = '';

  setEncryptionSecret(secret: string): void {
    this.encryptionSecret = secret;
  }

  hasEncryptionSecret(): boolean {
    return this.encryptionSecret.length > 0;
  }

  async load(): Promise<Result<void>> {
    this.loading = true;
    try {
      const result: Result<DatabaseModel> = await this.repository.load(this.encryptionSecret);
      if (!result.success || result.data === undefined) {
        const code: AppErrorCode = result.error !== undefined ? result.error.code : AppErrorCode.STORAGE_READ_FAILED;
        const message: ResourceStr =
          result.error !== undefined ? result.error.message : $r('app.string.error_load_data_failed');
        return err<void>(code, message);
      }
      this.items = result.data.items;
      return ok(undefined);
    } finally {
      this.loading = false;
    }
  }

  async remove(item: TotpItem): Promise<Result<void>> {
    let db: DatabaseModel | null = this.repository.getDatabase();
    if (db === null) {
      const loadResult: Result<DatabaseModel> = await this.repository.load(this.encryptionSecret);
      if (!loadResult.success || loadResult.data === undefined) {
        const message: ResourceStr =
          loadResult.error !== undefined ? loadResult.error.message : $r('app.string.error_data_load_failed');
        return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, message);
      }
      db = loadResult.data;
    }
    const nextItems: TotpItem[] = [];
    for (let i = 0; i < db.items.length; i++) {
      if (db.items[i].id !== item.id) {
        nextItems.push(db.items[i]);
      }
    }
    const nextDb: DatabaseModel = {
      version: db.version,
      revision: db.revision + 1,
      updatedAt: nowMilliseconds(),
      deviceId: db.deviceId,
      items: nextItems
    };
    const result: Result<void> = await this.repository.save(nextDb, this.encryptionSecret);
    if (!result.success) {
      return result;
    }
    this.items = nextItems;
    Logger.info('TOTP deleted: id=' + item.id);
    SyncService.getInstance().enqueuePush(SyncReason.DELETE_TOTP);
    return ok(undefined);
  }

  /**
   * 本地文件已无法用当前密钥解密时的自助恢复：隔离旧密文（重命名备份，不删除），
   * 以空库重建内存数据，使应用重新可用。
   */
  async resetLocalData(): Promise<Result<void>> {
    const result: Result<DatabaseModel> = await this.repository.quarantineUnreadable();
    if (!result.success) {
      const message: ResourceStr =
        result.error !== undefined ? result.error.message : $r('app.string.error_clear_local_data_failed');
      return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, message);
    }
    this.items = [];
    return ok(undefined);
  }

  async copyCode(item: TotpItem): Promise<Result<void>> {
    const code: string = this.generateCode(item);
    if (code.length === 0) {
      return err<void>(AppErrorCode.INVALID_TOTP_CONFIG, $r('app.string.error_cannot_generate_code'));
    }
    return this.clipboardService.copySensitiveText(code);
  }

  generateCode(item: TotpItem): string {
    const result: Result<string> = this.totpService.generate({
      secret: item.secret,
      algorithm: item.algorithm,
      digits: item.digits,
      period: item.period,
      timestamp: Math.floor(nowMilliseconds() / 1000)
    });
    if (!result.success || result.data === undefined) {
      return '';
    }
    return result.data;
  }

  getDisplayItems(): TotpDisplayItem[] {
    const displayItems: TotpDisplayItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      const item: TotpItem = this.items[i];
      const displayItem: TotpDisplayItem = {
        item: item
      };
      displayItems.push(displayItem);
    }
    return displayItems;
  }
}