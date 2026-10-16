import { WebDavConfig } from '../model/WebDavConfig';
import { DatabaseModel } from '../model/DatabaseModel';
import { RemoteBackup } from '../model/RemoteBackup';
import { SyncState, SyncStatus, SyncReason } from '../model/SyncModel';
import { WebDavService } from './WebDavService';
import { StorageService } from './StorageService';
import { SettingsService } from './SettingsService';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';
import { UiText } from '../utils/UiText';
import { nowMilliseconds } from '../utils/TimeUtils';
import { REMOTE_BACKUP_KEEP_COUNT, buildBackupFileName, isBackupFileName }
  from '../constants/SyncConstants';

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

  /**
   * 加密密钥变更后调用：同步本服务内的密钥副本，并主动上传本地已用新密钥重新加密的文件。
   *
   * 本地重新加密后云端仍是旧密钥的密文，若不覆盖，之后 pull 一定解密失败、同步会永久卡住。
   * pushInternal 上传的就是本地密文文件本身，所以这里只需更新密钥并触发一次上传即可。
   * 未配置 WebDAV / 未开启自动推送时静默跳过。
   */
  async onEncryptionKeyChanged(newSecret: string): Promise<Result<void>> {
    this.encryptionSecret = newSecret;
    if (this.config === null || this.config.password.length === 0) {
      // 会话内还没配置过同步（或密码已被清空）：从持久化配置里取一次，取到的密码已用新密钥加密
      const config: WebDavConfig = await this.settingsService.loadWebDavConfig(newSecret);
      this.configure(config, newSecret);
    }
    return this.enqueuePush(SyncReason.KEY_CHANGED);
  }

  /**
   * 手动推送：写入带日期时间的新快照文件（sourcetime-<日期时间>.enc），不覆盖已有备份，
   * 便于在「拉取」列表里回溯历史版本。
   */
  async push(): Promise<Result<void>> {
    if (!this.isConfigured()) {
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, $r('app.string.error_webdav_sync_not_enabled'));
    }
    if (this.pushing) {
      this.dirty = true;
      return ok(undefined);
    }
    return this.runPushQueue(buildBackupFileName(nowMilliseconds()));
  }

  /**
   * 自动推送：同样写入带日期时间的新快照文件（不覆盖历史备份）。
   * 云端文件数量由「自动清理旧备份」控制在最近 REMOTE_BACKUP_KEEP_COUNT 份。
   */
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
    return this.runPushQueue(buildBackupFileName(nowMilliseconds()));
  }

  /**
   * 列出远端可用备份（滚动副本 + 时间戳快照），已按时间倒序（最新在前）。
   * 未启用同步时返回失败，调用方据此提示。
   */
  async listBackups(): Promise<Result<RemoteBackup[]>> {
    if (this.config === null || !this.config.enabled) {
      return err<RemoteBackup[]>(AppErrorCode.WEBDAV_CONNECTION_FAILED, $r('app.string.error_webdav_sync_not_enabled'));
    }
    const listResult: Result<RemoteBackup[]> = await this.webDavService.list(this.config);
    if (!listResult.success || listResult.data === undefined) {
      const message: ResourceStr =
        listResult.error !== undefined ? listResult.error.message : $r('app.string.error_backup_list_failed');
      const logText: string = typeof message === 'string' ? message : UiText.of(message);
      Logger.error('Sync list backups failed: ' + logText + ' | ' + this.describeTarget());
      return err<RemoteBackup[]>(AppErrorCode.WEBDAV_DOWNLOAD_FAILED, message);
    }
    Logger.info('Sync list backups ok: files=' + listResult.data.length + ' | ' + this.describeTarget());
    return ok(listResult.data);
  }

  /**
   * 拉取用户显式选择的备份文件。
   * 显式选择允许「回滚」到更旧的版本（不做 revision 冲突拦截），
   * 由 UI 在调用前给出「将覆盖本机数据」的二次确认。
   */
  async pullBackup(fileName: string): Promise<Result<void>> {
    return this.pullNamed(fileName, false);
  }

  /** 启动时自动拉取云端最新备份（受 revision 冲突保护，避免用旧版本覆盖本机新数据）。 */
  async autoPullOnStart(): Promise<Result<void>> {
    if (this.config === null || !this.config.enabled || !this.config.autoPullOnStart) {
      return ok(undefined);
    }
    const listResult: Result<RemoteBackup[]> = await this.listBackups();
    if (!listResult.success || listResult.data === undefined) {
      return err<void>(AppErrorCode.WEBDAV_DOWNLOAD_FAILED,
        listResult.error !== undefined ? listResult.error.message : $r('app.string.error_backup_list_failed'));
    }
    if (listResult.data.length === 0) {
      Logger.info('Sync auto pull skipped: no remote backup | ' + this.describeTarget());
      return ok(undefined);
    }
    return this.pullNamed(listResult.data[0].name, true);
  }

  /**
   * 下载指定备份并替换本地库。
   * protectRollback 为 true 时，若远端 revision 小于本地则拒绝（保护本机较新的数据）。
   */
  private async pullNamed(fileName: string, protectRollback: boolean): Promise<Result<void>> {
    if (this.config === null || !this.config.enabled) {
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, $r('app.string.error_webdav_sync_not_enabled'));
    }
    this.state = { status: SyncStatus.PULLING, lastSyncAt: this.state.lastSyncAt, message: '' };
    const target: string = this.describeTarget() + ' file=' + fileName;
    const startedAt: number = nowMilliseconds();
    Logger.info('Sync pull start | ' + target);
    const downloadResult: Result<Uint8Array> = await this.webDavService.download(this.config, fileName);
    if (!downloadResult.success || downloadResult.data === undefined) {
      const message: ResourceStr =
        downloadResult.error !== undefined ? downloadResult.error.message : $r('app.string.error_pull_failed');
      const logText: string = typeof message === 'string' ? message : UiText.of(message);
      Logger.error('Sync pull download failed after ' + (nowMilliseconds() - startedAt) + 'ms: ' + logText
        + ' | ' + target);
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: message };
      return err<void>(AppErrorCode.WEBDAV_DOWNLOAD_FAILED, message);
    }
    const downloaded: Uint8Array = downloadResult.data;
    const decodeResult: Result<DatabaseModel> =
      await this.storageService.decodeEncryptedDatabase(downloaded, this.encryptionSecret);
    if (!decodeResult.success || decodeResult.data === undefined) {
      const message: ResourceStr =
        decodeResult.error !== undefined ? decodeResult.error.message : $r('app.string.error_remote_data_invalid');
      const logText: string = typeof message === 'string' ? message : UiText.of(message);
      Logger.error('Sync pull decode failed: ' + logText + ' downloadedBytes=' + downloaded.length
        + ' | ' + target);
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: message };
      return err<void>(AppErrorCode.WEBDAV_INVALID_REMOTE_FILE, message);
    }
    const remoteDb: DatabaseModel = decodeResult.data;
    const localDb: DatabaseModel | null = this.storageService.getDatabase();
    if (protectRollback && localDb !== null && remoteDb.revision < localDb.revision) {
      const conflictMessage: ResourceStr = $r('app.string.error_remote_not_latest');
      Logger.warn('Sync pull conflict: remoteRevision=' + remoteDb.revision + ' localRevision=' + localDb.revision
        + ' | ' + target);
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: conflictMessage };
      return err<void>(AppErrorCode.SYNC_CONFLICT, conflictMessage);
    }
    const replaceResult: Result<void> = await this.storageService.replaceDatabase(remoteDb, this.encryptionSecret);
    if (!replaceResult.success) {
      const message: ResourceStr =
        replaceResult.error !== undefined ? replaceResult.error.message : $r('app.string.error_local_replace_failed');
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: message };
      return replaceResult;
    }
    const lastSyncAt: number = nowMilliseconds();
    this.state = { status: SyncStatus.SUCCESS, lastSyncAt: lastSyncAt, message: '' };
    await this.persistLastSyncAt(lastSyncAt);
    Logger.info('Sync pull finished: file=' + fileName + ' items=' + remoteDb.items.length
      + ' revision=' + remoteDb.revision + ' bytes=' + downloaded.length
      + ' cost=' + (lastSyncAt - startedAt) + 'ms | ' + target);
    return ok(undefined);
  }

  private async runPushQueue(fileName: string): Promise<Result<void>> {
    this.pushing = true;
    let result: Result<void> = ok(undefined);
    try {
      result = await this.pushInternal(fileName);
      while (this.dirty) {
        this.dirty = false;
        result = await this.pushInternal(fileName);
      }
    } finally {
      this.pushing = false;
    }
    return result;
  }

  private async pushInternal(fileName: string): Promise<Result<void>> {
    if (this.config === null) {
      this.state = {
        status: SyncStatus.FAILED,
        lastSyncAt: this.state.lastSyncAt,
        message: $r('app.string.error_webdav_not_configured')
      };
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, $r('app.string.error_webdav_not_configured'));
    }
    this.state = { status: SyncStatus.PUSHING, lastSyncAt: this.state.lastSyncAt, message: '' };
    const config: WebDavConfig = this.config;
    // 日志用目标描述：账号 + 服务器地址 + 目录 + 目标文件名（不含密码，密码永不落日志）。
    const target: string = this.describeTarget() + ' file=' + fileName;
    // 本地还没有加密数据文件（首次安装、刚「忘记密钥」清库、或尚未添加任何口令）：
    // 必须明确告知「无可推送内容」。绝不推空库，否则会覆盖云端已有的备份。
    if (!this.storageService.isInitialized()) {
      const notReady: ResourceStr = $r('app.string.error_no_local_data_to_push');
      Logger.warn('Sync push skipped: local database not initialized | ' + target);
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: notReady };
      return err<void>(AppErrorCode.STORAGE_READ_FAILED, notReady);
    }
    const bytesResult: Result<Uint8Array> = this.storageService.readEncryptedFile();
    if (!bytesResult.success || bytesResult.data === undefined) {
      // 透传底层真实原因（「本地尚无数据」「读取数据失败」等），不再统一改写成模糊的「读取本地数据失败」
      const readError: ResourceStr =
        bytesResult.error !== undefined ? bytesResult.error.message : $r('app.string.error_read_local_data_failed');
      const logText: string = typeof readError === 'string' ? readError : UiText.of(readError);
      Logger.error('Sync push read failed: ' + logText + ' | ' + target);
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: readError };
      return err<void>(AppErrorCode.STORAGE_READ_FAILED, readError);
    }
    const payload: Uint8Array = bytesResult.data;
    if (payload.length === 0) {
      const emptyError: ResourceStr = $r('app.string.error_local_data_empty_skip_push');
      Logger.warn('Sync push skipped: empty payload | ' + target);
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: emptyError };
      return err<void>(AppErrorCode.STORAGE_READ_FAILED, emptyError);
    }
    const startedAt: number = nowMilliseconds();
    Logger.info('Sync push start: bytes=' + payload.length + ' | ' + target);
    const uploadResult: Result<void> = await this.webDavService.upload(config, fileName, payload);
    if (!uploadResult.success) {
      const message: ResourceStr =
        uploadResult.error !== undefined ? uploadResult.error.message : $r('app.string.error_sync_failed');
      const logText: string = typeof message === 'string' ? message : UiText.of(message);
      Logger.error('Sync push failed after ' + (nowMilliseconds() - startedAt) + 'ms: ' + logText + ' | ' + target);
      this.state = { status: SyncStatus.FAILED, lastSyncAt: this.state.lastSyncAt, message: message };
      return uploadResult;
    }
    const lastSyncAt: number = nowMilliseconds();
    this.state = { status: SyncStatus.SUCCESS, lastSyncAt: lastSyncAt, message: '' };
    await this.persistLastSyncAt(lastSyncAt);
    Logger.info('Sync push finished: bytes=' + payload.length + ' cost=' + (lastSyncAt - startedAt) + 'ms | ' + target);
    // 推送成功后按设置清理云端旧快照（失败只记日志，不影响本次推送结果）。
    if (config.cleanOldBackups) {
      await this.pruneOldBackups();
    }
    return ok(undefined);
  }

  /**
   * 清理云端旧快照：仅保留最近 REMOTE_BACKUP_KEEP_COUNT 份。
   *
   * 安全边界：只删除本应用生成的时间戳快照（sourcetime-*.enc），
   * 绝不触碰同步目录里用户的其它文件（含第三方文件）。
   * 删除失败只记日志，不抛出（不能因为清理失败而让本次推送显示失败）。
   */
  private async pruneOldBackups(): Promise<void> {
    if (this.config === null) {
      return;
    }
    const config: WebDavConfig = this.config;
    const listResult: Result<RemoteBackup[]> = await this.webDavService.list(config);
    if (!listResult.success || listResult.data === undefined) {
      Logger.warn('Sync prune skipped: list failed | ' + this.describeTarget());
      return;
    }
    const snapshots: RemoteBackup[] = [];
    for (const item of listResult.data) {
      if (isBackupFileName(item.name)) {
        snapshots.push(item);
      }
    }
    if (snapshots.length <= REMOTE_BACKUP_KEEP_COUNT) {
      return;
    }
    // list() 已按时间倒序，超出保留份数的即为最旧的一批
    const expired: RemoteBackup[] = snapshots.slice(REMOTE_BACKUP_KEEP_COUNT);
    let removed: number = 0;
    for (const item of expired) {
      const deleteResult: Result<void> = await this.webDavService.delete(config, item.name);
      if (deleteResult.success) {
        removed++;
      } else {
        Logger.warn('Sync prune delete failed: file=' + item.name + ' | ' + this.describeTarget());
      }
    }
    Logger.info('Sync prune finished: kept=' + REMOTE_BACKUP_KEEP_COUNT + ' removed=' + removed
      + ' snapshots=' + snapshots.length + ' | ' + this.describeTarget());
  }

  /** 供日志定位的同步目标：地址与账号属可识别信息，只记长度，不落明文（不含密码）。 */
  private describeTarget(): string {
    if (this.config === null) {
      return 'remote=<未配置>';
    }
    const path: string = this.config.remotePath.trim();
    return 'userLen=' + this.config.username.length + ' urlLen=' + this.config.baseUrl.trim().length
      + ' pathLen=' + path.length;
  }

  private async persistLastSyncAt(lastSyncAt: number): Promise<void> {
    const settings = this.settingsService.getSettings();
    settings.lastSyncAt = lastSyncAt;
    await this.settingsService.saveSettings(settings);
  }
}
