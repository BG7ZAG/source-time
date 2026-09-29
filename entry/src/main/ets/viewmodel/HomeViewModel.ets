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
import { nowMilliseconds, calculateRemainingSeconds } from '../utils/TimeUtils';

export interface TotpDisplayItem {
  item: TotpItem;
  code: string;
  remaining: number;
}

export class HomeViewModel {
  items: TotpItem[] = [];
  loading: boolean = false;
  syncing: boolean = false;
  syncStatus: SyncStatus = SyncStatus.IDLE;
  lastSyncAt: number = 0;
  now: number = nowMilliseconds();

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
        const message: string = result.error !== undefined ? result.error.message : '加载数据失败';
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
        return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, '数据加载失败');
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

  async copyCode(item: TotpItem): Promise<Result<void>> {
    const code: string = this.generateCode(item);
    if (code.length === 0) {
      return err<void>(AppErrorCode.INVALID_TOTP_CONFIG, '无法生成验证码');
    }
    return this.clipboardService.copyText(code);
  }

  refreshTime(): void {
    this.now = nowMilliseconds();
  }

  generateCode(item: TotpItem): string {
    const result: Result<string> = this.totpService.generate({
      secret: item.secret,
      algorithm: item.algorithm,
      digits: item.digits,
      period: item.period,
      timestamp: Math.floor(this.now / 1000)
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
        item: item,
        code: this.generateCode(item),
        remaining: calculateRemainingSeconds(this.now, item.period)
      };
      displayItems.push(displayItem);
    }
    return displayItems;
  }
}
