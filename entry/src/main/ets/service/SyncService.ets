import { WebDavConfig } from '../model/WebDavConfig';
import { DatabaseModel } from '../model/DatabaseModel';
import { SyncState, SyncStatus, SyncReason } from '../model/SyncModel';
import { WebDavService } from './WebDavService';
import { StorageService } from './StorageService';
import { SettingsService } from './SettingsService';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';
import { nowMilliseconds } from '../utils/TimeUtils';

export class SyncService {
  private static instance: SyncService | null = null;

  private webDavService: WebDavService = new WebDavService();
  private storageService: StorageService = StorageService.getInstance();
  private settingsService: SettingsService = new SettingsService();

  private config: WebDavConfig | null = null;
  private encryptionSecret: string = '';
  private pushing: boolean = false;
  private dirty: boolean = false;
  private state: SyncState = { status: SyncStatus.IDLE, lastSyncAt: 0, message: '' };

  static getInstance(): SyncService {
    if (SyncService.instance === null) {
      SyncService.instance = new SyncService();
    }
    return SyncService.instance;
  }

  configure(config: WebDavConfig, encryptionSecret: string): void {
    this.config = config;
    this.encryptionSecret = encryptionSecret;
  }

  isConfigured(): boolean {
    return this.config !== null && this.config.enabled;
  }

  getState(): SyncState {
    return this.state;
  }

  async push(): Promise<Result<void>> {
    if (!this.isConfigured()) {
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, '未启用 WebDAV 同步');
    }
    if (this.pushing) {
      this.dirty = true;
      return ok(undefined);
    }
    return this.runPushQueue();
  }

  async enqueuePush(reason: SyncReason): Promise<Result<void>> {
    if (!this.isConfigured()) {
      return ok(undefined);
    }
    if (this.config !== null && !this.config.autoPush) {
      return ok(undefined);
    }
    if (this.pushing) {
      this.dirty = true;
      return ok(undefined);
    }
    return this.runPushQueue();
  }

  async pull(): Promise<Result<void>> {
    if (this.config === null || !this.config.enabled) {
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, '未启用 WebDAV 同步');
    }
    this.state = { status: SyncStatus.PULLING, lastSyncAt: this.state.lastSyncAt, message: '' };
    const downloadResult: Result<Uint8Array> = await this.webDavService.download(this.config);
    if (!downloadResult.success || downloadResult.data === undefined) {
      const message: string = downloadResult.error !== undefined ? downloadResult.error.message : '拉取失败';
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: message };
      return err<void>(AppErrorCode.WEBDAV_DOWNLOAD_FAILED, message);
    }
    const decodeResult: Result<DatabaseModel> =
      await this.storageService.decodeEncryptedDatabase(downloadResult.data, this.encryptionSecret);
    if (!decodeResult.success || decodeResult.data === undefined) {
      const message: string = decodeResult.error !== undefined ? decodeResult.error.message : '远程数据无效';
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: message };
      return err<void>(AppErrorCode.WEBDAV_INVALID_REMOTE_FILE, message);
    }
    const remoteDb: DatabaseModel = decodeResult.data;
    const localDb: DatabaseModel | null = this.storageService.getDatabase();
    if (localDb !== null && remoteDb.revision < localDb.revision) {
      const conflictMessage: string = '远程数据不是最新版本';
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: conflictMessage };
      return err<void>(AppErrorCode.SYNC_CONFLICT, conflictMessage);
    }
    const replaceResult: Result<void> = await this.storageService.replaceDatabase(remoteDb, this.encryptionSecret);
    if (!replaceResult.success) {
      const message: string = replaceResult.error !== undefined ? replaceResult.error.message : '本地替换失败';
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: message };
      return replaceResult;
    }
    const lastSyncAt: number = nowMilliseconds();
    this.state = { status: SyncStatus.SUCCESS, lastSyncAt: lastSyncAt, message: '' };
    await this.persistLastSyncAt(lastSyncAt);
    Logger.info('Sync pull finished');
    return ok(undefined);
  }

  async autoPullOnStart(): Promise<Result<void>> {
    if (this.config === null || !this.config.enabled || !this.config.autoPullOnStart) {
      return ok(undefined);
    }
    return this.pull();
  }

  private async runPushQueue(): Promise<Result<void>> {
    this.pushing = true;
    let result: Result<void> = ok(undefined);
    try {
      result = await this.pushInternal();
      while (this.dirty) {
        this.dirty = false;
        result = await this.pushInternal();
      }
    } finally {
      this.pushing = false;
    }
    return result;
  }

  private async pushInternal(): Promise<Result<void>> {
    if (this.config === null) {
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: '未配置 WebDAV' };
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, '未配置 WebDAV');
    }
    this.state = { status: SyncStatus.PUSHING, lastSyncAt: this.state.lastSyncAt, message: '' };
    const bytesResult: Result<Uint8Array> = this.storageService.readEncryptedFile();
    if (!bytesResult.success || bytesResult.data === undefined) {
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: '读取本地数据失败' };
      return err<void>(AppErrorCode.STORAGE_READ_FAILED, '读取本地数据失败');
    }
    const uploadResult: Result<void> = await this.webDavService.upload(this.config, bytesResult.data);
    if (!uploadResult.success) {
      const message: string = uploadResult.error !== undefined ? uploadResult.error.message : '同步失败';
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: message };
      return uploadResult;
    }
    const lastSyncAt: number = nowMilliseconds();
    this.state = { status: SyncStatus.SUCCESS, lastSyncAt: lastSyncAt, message: '' };
    await this.persistLastSyncAt(lastSyncAt);
    Logger.info('Sync push finished');
    return ok(undefined);
  }

  private async persistLastSyncAt(lastSyncAt: number): Promise<void> {
    const settings = this.settingsService.getSettings();
    settings.lastSyncAt = lastSyncAt;
    await this.settingsService.saveSettings(settings);
  }
}
