import { KeyboardAvoidMode, ShowDialogSuccessResponse } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { WebDavService } from '../service/WebDavService';
import { LocalBackupService } from '../service/LocalBackupService';
import { SyncService } from '../service/SyncService';
import { SettingsService } from '../service/SettingsService';
import { WebDavConfig } from '../model/WebDavConfig';
import { RemoteBackup } from '../model/RemoteBackup';
import { DatabaseModel } from '../model/DatabaseModel';
import { LocalBackupKind, LocalBackupPreview } from '../model/LocalBackup';
import { TotpItem } from '../model/TotpItem';
import { SyncStatus } from '../model/SyncModel';
import { Result } from '../types/Result';
import { DEFAULT_WEBDAV_DIRECTORY, WEBDAV_FEATURE_ENABLED } from '../constants/AppConstants';
import { buildBackupFileName, buildPlainBackupFileName } from '../constants/SyncConstants';
import { CONTENT_MAX_WIDTH } from '../constants/LayoutConstants';
import { Logger } from '../utils/Logger';
import { UiText } from '../utils/UiText';
import { nowMilliseconds } from '../utils/TimeUtils';
import { AuroraBackground } from '../components/AuroraBackground';
import { BackupPickerDialog } from '../components/BackupPickerDialog';
import { LocalBackupPreviewDialog } from '../components/LocalBackupPreviewDialog';
import {
  focusGlowShadow,
  frostedPillColor,
  glassGroupShadow,
  glassPillShadow,
  glowButtonShadow,
  noShadow,
  statusDotColor,
  trackGradientColors
} from '../theme/GlassStyle';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

/**
 * 操作按钮参数。
 *
 * ArkUI 的 @Builder 按值传参时，状态变量变化不会引起其内部 UI 刷新；
 * 只有传入对象字面量（按引用传参）才会随状态刷新。故按钮参数收敛为一个对象。
 */
interface ActionButtonParams {
  label: ResourceStr;
  enabled: boolean;
  onTap: () => void;
  icon?: Resource;
}

/**
 * WebDAV 同步配置页（鸿蒙 7 版）。
 *
 * 控件：Smooth 弹性开关 + 1px 悬浮高光输入框
 * 按钮：主操作用渐变高光填充，次要操作（测试连接）用高光虚框
 * 状态：动态脉冲状态灯（灰-空闲，蓝-同步中，红-异常）
 */
@Entry
@Component
struct WebDavPage {
  @State baseUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State passwordInput: string = '';
  @State remotePath: string = DEFAULT_WEBDAV_DIRECTORY;
  @State webDavEnabled: boolean = false;
  @State autoPush: boolean = false;
  @State autoPullOnStart: boolean = false;
  /** 推送后自动清理云端旧快照，仅保留最近 REMOTE_BACKUP_KEEP_COUNT（10）份。 */
  @State cleanOldBackups: boolean = true;
  /** 显式允许 http:// 明文同步（默认关闭，由 WebDavService 在请求前拦截）。 */
  @State allowInsecure: boolean = false;
  @State testing: boolean = false;
  @State saving: boolean = false;
  @State pushing: boolean = false;
  @State pulling: boolean = false;
  @State syncStatus: SyncStatus = SyncStatus.IDLE;
  @State lastSyncAt: number = 0;
  @State syncMessage: ResourceStr = '';

  /** 远端备份列表（已按时间倒序，最新在前），供选择弹窗展示。 */
  @State backups: RemoteBackup[] = [];
  /** 备份选择弹窗的默认选中项（最新一条）。 */
  @State selectedBackup: string = '';

  /** 本机备份/恢复操作进行中：三个入口一并禁用，避免同时打开多个系统文件框。 */
  @State localBusy: boolean = false;
  /** 连接配置表单是否展开：已保存过服务器地址时默认折叠，把首屏留给备份操作。 */
  @State showConfigForm: boolean = true;
  /**
   * 本机恢复预览数据：仅在打开弹窗时读取，不参与页面渲染，
   * 因此用普通字段而非 @State，避免大条目数组触发多余的深比较与重渲染。
   */
  private previewKind: LocalBackupKind = LocalBackupKind.ENCRYPTED;
  private previewItems: TotpItem[] = [];
  private previewFileName: string = '';
  private previewUpdatedAt: number = 0;
  /** 预览确认后待写回的数据库；为空表示没有待导入内容。 */
  private previewDatabase: DatabaseModel | null = null;
  private previewDialog: CustomDialogController | null = null;

  private webDavService: WebDavService = new WebDavService();
  private localBackupService: LocalBackupService = new LocalBackupService();
  private settingsService: SettingsService = new SettingsService();
  private encryptionSecret: string = '';
  /**
   * 远端配置是否已读入内存。
   *
   * 载入是异步的，而保存会用内存里的 this.password 作为「未重新输入时保留旧密码」的兜底值。
   * 若在载入完成前就落盘，password 还是空串，SettingsService 会据此删除已存的密码密文——
   * 用户什么都没做就丢了 WebDAV 密码。故未完成载入前一律拒绝写入。
   */
  private configLoaded: boolean = false;
  /** 备份选择弹窗控制器：需等列表返回后才创建，故非初始化字段。 */
  private backupDialog: CustomDialogController | null = null;

  aboutToAppear(): void {
    // 总开关关闭时（例如临时审核要求）即使通过路由/深链进入本页也直接返回，避免发起网络请求
    if (!WEBDAV_FEATURE_ENABLED) {
      this.getUIContext().getRouter().back();
      return;
    }
    const secret: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (secret !== undefined && secret.length > 0) {
      this.encryptionSecret = secret;
    }
    this.loadConfig();
  }

  /**
   * 本页是长表单、底部紧跟「保存配置 / 测试连接」：
   * 默认 OFFSET 会把整页顶上去，顶部标题被推出屏幕；改用 RESIZE 让页面随键盘收缩，
   * 由内部 Scroll 把焦点框与按钮滚进可视区（与安全与密钥页同一套处理）。
   */
  onPageShow(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
  }

  /** 避让模式挂在 UIContext 上、会带到后续页面，离开本页立刻恢复系统默认。 */
  onPageHide(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET);
  }

  aboutToDisappear(): void {
  }

  private loadConfig(): void {
    this.settingsService.loadWebDavConfig(this.encryptionSecret).then((config: WebDavConfig) => {
      this.baseUrl = config.baseUrl;
      this.username = config.username;
      this.password = config.password;
      this.passwordInput = '';
      this.remotePath = config.remotePath.length > 0 ? config.remotePath : DEFAULT_WEBDAV_DIRECTORY;
      this.webDavEnabled = config.enabled;
      this.autoPush = config.autoPush;
      this.autoPullOnStart = config.autoPullOnStart;
      this.cleanOldBackups = config.cleanOldBackups;
      this.allowInsecure = config.allowInsecure;
      this.configLoaded = true;
      // 已保存过服务器地址时默认折叠连接表单：进入本页通常是为了备份/恢复，不必每次铺满半屏。
      // 首次配置（地址为空）保持展开，避免用户找不到输入框。
      this.showConfigForm = config.baseUrl.trim().length === 0;
      SyncService.getInstance().configure(config, this.encryptionSecret);
    });
    const settings = this.settingsService.getSettings();
    this.lastSyncAt = settings.lastSyncAt !== undefined ? settings.lastSyncAt : 0;
    const syncState = SyncService.getInstance().getState();
    this.syncStatus = syncState.status;
    this.syncMessage = syncState.message !== undefined ? syncState.message : '';
  }

  private buildConfig(): WebDavConfig {
    return {
      enabled: this.webDavEnabled,
      baseUrl: this.baseUrl,
      username: this.username,
      password: this.passwordInput.length > 0 ? this.passwordInput : this.password,
      remotePath: this.remotePath,
      autoPush: this.autoPush,
      autoPullOnStart: this.autoPullOnStart,
      cleanOldBackups: this.cleanOldBackups,
      allowInsecure: this.allowInsecure
    };
  }

  /**
   * 将页面当前配置同步到 SyncService。
   *
   * 使「启用 WebDAV 同步」开关打开后即可直接推送/拉取，无需先点「保存配置」；
   * 同时让依赖 SyncService.isConfigured() 的自动推送在本次会话内即时生效。
   */
  private syncConfigToService(): void {
    SyncService.getInstance().configure(this.buildConfig(), this.encryptionSecret);
  }

  private persistConfig(): void {
    if (!this.configLoaded) {
      Logger.warn('WebDAV config write skipped: remote config not loaded yet');
      return;
    }
    const config: WebDavConfig = this.buildConfig();
    this.settingsService.saveWebDavConfig(config, this.encryptionSecret).then((result: Result<void>) => {
      if (result.success) {
        SyncService.getInstance().configure(config, this.encryptionSecret);
      }
    });
  }

  /** 是否已填写必要的同步配置：至少包含服务器地址。 */
  private hasConfig(): boolean {
    return this.baseUrl.trim().length > 0;
  }

  /** 是否已保存过连接配置；用于决定折叠状态下的摘要是否展示。 */
  private hasSavedConfig(): boolean {
    return this.configLoaded && this.baseUrl.trim().length > 0;
  }

  /** 折叠时展示的配置摘要：账号 + 服务器地址（不含密码）。 */
  private configSummary(): string {
    const base: string = this.baseUrl.trim();
    if (base.length === 0) {
      return '';
    }
    const user: string = this.username.trim();
    return user.length > 0 ? user + ' · ' + base : base;
  }

  /** 服务器地址是否用了 http:// 明文前缀（仅用于本页提示；真正的拦截在 WebDavService）。 */
  private isPlainHttpUrl(): boolean {
    return /^http:\/\//i.test(this.baseUrl.trim());
  }

  private onSave(): void {
    if (!this.configLoaded) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.webdav_config_loading') });
      return;
    }
    this.saving = true;
    const config: WebDavConfig = this.buildConfig();
    this.settingsService.saveWebDavConfig(config, this.encryptionSecret).then((result: Result<void>) => {
      this.saving = false;
      if (result.success) {
        if (this.passwordInput.length > 0) {
          this.password = this.passwordInput;
          this.passwordInput = '';
        }
        SyncService.getInstance().configure(config, this.encryptionSecret);
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.webdav_save_success') });
      } else {
        const message: ResourceStr = result.error !== undefined ? result.error.message : $r('app.string.webdav_save_failed');
        this.getUIContext().getPromptAction().showToast({ message: message });
      }
    });
  }

  private onTest(): void {
    this.testing = true;
    this.webDavService.testConnection(this.buildConfig()).then((result: Result<void>) => {
      this.testing = false;
      const message: ResourceStr = result.success ? $r('app.string.webdav_test_success')
        : (result.error !== undefined ? result.error.message : $r('app.string.webdav_test_failed'));
      this.getUIContext().getPromptAction().showToast({ message: message });
    });
  }

  private onPush(): void {
    this.syncConfigToService();
    const config: WebDavConfig = this.buildConfig();
    // 账号与地址属于可识别信息，且不记录它们也能定位问题，故只记长度/开关状态
    Logger.info('WebDAV push requested: urlLen=' + this.baseUrl.length
      + ' pathLen=' + this.remotePath.length + ' enabled=' + this.webDavEnabled + ' autoPush=' + this.autoPush
      + ' passwordSet=' + (config.password.length > 0), 'WebDAV');
    this.pushing = true;
    SyncService.getInstance().push().then((result: Result<void>) => {
      this.pushing = false;
      const state = SyncService.getInstance().getState();
      this.syncStatus = state.status;
      this.syncMessage = state.message !== undefined ? state.message : '';
      this.lastSyncAt = state.lastSyncAt !== undefined ? state.lastSyncAt : 0;
      const message: ResourceStr = result.success ? $r('app.string.webdav_push_success')
        : (result.error !== undefined ? result.error.message : $r('app.string.webdav_push_failed'));
      const logText: string = typeof message === 'string' ? message : UiText.of(message);
      Logger.info('WebDAV push result: success=' + result.success + ' message=' + logText, 'WebDAV');
      this.getUIContext().getPromptAction().showToast({ message: message });
    });
  }

  /**
   * 点击「手动拉取」：先取远端备份列表，再弹窗让用户选择要恢复的版本（默认最新一条）。
   * 避免以前那样直接覆盖本地、无法选择历史版本。
   */
  private onPull(): void {
    this.syncConfigToService();
    Logger.info('WebDAV pull requested: urlLen=' + this.baseUrl.length + ' pathLen=' + this.remotePath.length, 'WebDAV');
    this.pulling = true;
    SyncService.getInstance().listBackups().then((result: Result<RemoteBackup[]>) => {
      this.pulling = false;
      if (!result.success || result.data === undefined) {
        const message: ResourceStr = result.error !== undefined ? result.error.message : $r('app.string.webdav_backup_list_failed');
        this.getUIContext().getPromptAction().showToast({ message: message });
        return;
      }
      const backups: RemoteBackup[] = result.data;
      if (backups.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.webdav_no_remote_backup') });
        return;
      }
      this.backups = backups;
      this.selectedBackup = backups[0].name;   // 默认勾选最新一条
      this.openBackupPicker();
    });
  }

  /** 弹出备份选择列表（默认选中最新一条）。 */
  private openBackupPicker(): void {    const controller: CustomDialogController = new CustomDialogController({
      builder: BackupPickerDialog({
        backups: this.backups,
        selected: this.selectedBackup,
        onConfirm: (fileName: string) => {
          // 先关闭选择弹窗，再做「覆盖并恢复」二次确认，避免弹窗叠弹窗
          this.closeBackupPicker();
          this.doPullBackup(fileName);
        },
        onCancel: () => {
          this.closeBackupPicker();
        }
      }),
      autoCancel: true,
      customStyle: true,
      alignment: DialogAlignment.Center
    });
    this.backupDialog = controller;
    controller.open();
  }

  /** 关闭备份选择弹窗；重复调用安全。 */
  private closeBackupPicker(): void {
    if (this.backupDialog !== null) {
      this.backupDialog.close();
      this.backupDialog = null;
    }
  }

  /** 用户选好备份后：二次确认「覆盖本机数据」，再按文件名拉取。 */
  private doPullBackup(fileName: string): void {
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.webdav_restore_dialog_title'),
      message: UiText.of($r('app.string.webdav_restore_dialog_message'), fileName),
      buttons: [
        { text: $r('app.string.common_cancel'), color: '#666666' },
        { text: $r('app.string.webdav_restore_confirm'), color: '#E84026' }
      ]
    }).then((dialogResult: ShowDialogSuccessResponse) => {
      if (dialogResult.index !== 1) {
        return;
      }
      this.pulling = true;
      SyncService.getInstance().pullBackup(fileName).then((result: Result<void>) => {
        this.pulling = false;
        const state = SyncService.getInstance().getState();
        this.syncStatus = state.status;
        this.syncMessage = state.message !== undefined ? state.message : '';
        this.lastSyncAt = state.lastSyncAt !== undefined ? state.lastSyncAt : 0;
        const message: ResourceStr = result.success ? $r('app.string.webdav_pull_success')
          : (result.error !== undefined ? result.error.message : $r('app.string.webdav_pull_failed'));
        const logText: string = typeof message === 'string' ? message : UiText.of(message);
        Logger.info('WebDAV pull result: file=' + fileName + ' success=' + result.success
          + ' message=' + logText, 'WebDAV');
        this.getUIContext().getPromptAction().showToast({ message: message });
      });
    });
  }

  // ---- 本机备份与恢复 ----

  /** 加密备份：载荷与 WebDAV 推送完全相同，可直接互换使用。 */
  private onExportEncrypted(): void {
    this.startExport(true);
  }

  /** 明文备份：当前库解密后导出为 UTF-8 JSON，便于用户自行查看或迁移。 */
  private onExportPlain(): void {
    this.startExport(false);
  }

  private startExport(encrypted: boolean): void {
    if (this.localBusy) {
      return;
    }
    this.localBusy = true;
    Logger.info('Local backup requested: ' + (encrypted ? 'encrypted' : 'plain'), 'LocalBackup');
    const build: Promise<Result<Uint8Array>> = encrypted
      ? this.localBackupService.buildEncrypted()
      : this.localBackupService.buildPlain(this.encryptionSecret);
    build.then((result: Result<Uint8Array>) => {
      if (!result.success || result.data === undefined) {
        this.localBusy = false;
        const message: ResourceStr = result.error !== undefined ? result.error.message
          : $r('app.string.local_backup_export_failed');
        const logText: string = typeof message === 'string' ? message : 'see ui message';
        Logger.error('Local backup build failed: encrypted=' + encrypted + ' message=' + logText, 'LocalBackup');
        this.getUIContext().getPromptAction().showToast({ message: message });
        return;
      }
      const now: number = nowMilliseconds();
      const fileName: string = encrypted ? buildBackupFileName(now) : buildPlainBackupFileName(now);
      const successMessage: ResourceStr = encrypted ? $r('app.string.local_backup_encrypted_success')
        : $r('app.string.local_backup_plain_success');
      this.saveLocalCopy(fileName, result.data, successMessage);
    });
  }

  /** 弹出系统保存框并写入备份字节；用户取消时保持静默。 */
  private async saveLocalCopy(fileName: string, data: Uint8Array, successMessage: ResourceStr): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) {
        this.localBusy = false;
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.local_backup_export_failed') });
        return;
      }
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const uris: string[] = await new picker.DocumentViewPicker(context).save(options);
      if (uris.length === 0) {
        Logger.info('Local backup save cancelled by user', 'LocalBackup');
        this.localBusy = false;
        return;
      }
      const written: Result<void> = this.localBackupService.writeToUri(uris[0], data);
      this.localBusy = false;
      if (written.success) {
        Logger.info('Local backup saved: bytes=' + data.length, 'LocalBackup');
        this.getUIContext().getPromptAction().showToast({ message: successMessage });
        return;
      }
      const writeMessage: ResourceStr = written.error !== undefined ? written.error.message
        : $r('app.string.local_backup_export_failed');
      this.getUIContext().getPromptAction().showToast({ message: writeMessage });
    } catch (error) {
      this.localBusy = false;
      Logger.error('Local backup save dialog failed', 'LocalBackup');
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.local_backup_export_failed') });
    }
  }

  /** 选择本机备份文件，自动识别加密/明文后弹出预览，确认后才覆盖本地库。 */
  private onImportLocal(): void {
    if (this.localBusy) {
      return;
    }
    this.localBusy = true;
    Logger.info('Local restore requested', 'LocalBackup');
    this.pickAndPreviewLocalBackup();
  }

  private async pickAndPreviewLocalBackup(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) {
        this.localBusy = false;
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.local_backup_import_failed') });
        return;
      }
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const uris: string[] = await new picker.DocumentViewPicker(context).select(options);
      if (uris.length === 0) {
        Logger.info('Local restore cancelled by user', 'LocalBackup');
        this.localBusy = false;
        return;
      }
      const uri: string = uris[0];
      const readResult: Result<Uint8Array> = this.localBackupService.readFromUri(uri);
      if (!readResult.success || readResult.data === undefined) {
        this.localBusy = false;
        const message: ResourceStr = readResult.error !== undefined ? readResult.error.message
          : $r('app.string.local_backup_import_failed');
        Logger.error('Local restore read failed: ' + (typeof message === 'string' ? message : 'ui message'),
          'LocalBackup');
        this.getUIContext().getPromptAction().showToast({ message: message });
        return;
      }
      const inspected: Result<LocalBackupPreview> =
        await this.localBackupService.inspect(readResult.data, this.encryptionSecret);
      if (!inspected.success || inspected.data === undefined) {
        this.localBusy = false;
        const message: ResourceStr = inspected.error !== undefined ? inspected.error.message
          : $r('app.string.local_backup_import_failed');
        Logger.error('Local restore inspect failed: ' + (typeof message === 'string' ? message : 'ui message'),
          'LocalBackup');
        this.getUIContext().getPromptAction().showToast({ message: message });
        return;
      }
      this.previewDatabase = inspected.data.database;
      this.previewKind = inspected.data.kind;
      this.previewItems = inspected.data.database.items;
      this.previewUpdatedAt = inspected.data.database.updatedAt;
      this.previewFileName = this.displayFileName(uri);
      this.localBusy = false;
      Logger.info('Local restore inspected: kind=' + inspected.data.kind + ' items='
        + this.previewItems.length, 'LocalBackup');
      this.openPreviewDialog();
    } catch (error) {
      this.localBusy = false;
      Logger.error('Local restore dialog failed', 'LocalBackup');
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.local_backup_import_failed') });
    }
  }

  /** 从系统文件 URI 中取出可读文件名（仅用于展示）。 */
  private displayFileName(uri: string): string {
    const slashIndex: number = uri.lastIndexOf('/');
    const raw: string = slashIndex >= 0 ? uri.substring(slashIndex + 1) : uri;
    try {
      return decodeURIComponent(raw);
    } catch (error) {
      return raw;
    }
  }

  private openPreviewDialog(): void {
    this.closePreviewDialog();
    const controller: CustomDialogController = new CustomDialogController({
      builder: LocalBackupPreviewDialog({
        fileName: this.previewFileName,
        kind: this.previewKind,
        items: this.previewItems,
        updatedAt: this.previewUpdatedAt,
        onConfirm: () => {
          this.closePreviewDialog();
          this.doRestoreLocal();
        },
        onCancel: () => {
          this.closePreviewDialog();
          this.previewDatabase = null;
        }
      }),
      autoCancel: true,
      customStyle: true,
      alignment: DialogAlignment.Center
    });
    this.previewDialog = controller;
    controller.open();
  }

  /** 关闭预览弹窗；重复调用安全。 */
  private closePreviewDialog(): void {
    if (this.previewDialog !== null) {
      this.previewDialog.close();
      this.previewDialog = null;
    }
  }

  /** 用户已在预览弹窗中确认：用当前密钥把备份数据重新加密写回本地库。 */
  private doRestoreLocal(): void {
    const database: DatabaseModel | null = this.previewDatabase;
    if (database === null) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.local_backup_restore_failed') });
      return;
    }
    this.previewDatabase = null;
    this.localBusy = true;
    this.localBackupService.restore(database, this.encryptionSecret).then((result: Result<void>) => {
      this.localBusy = false;
      const message: ResourceStr = result.success ? $r('app.string.local_backup_restore_success')
        : (result.error !== undefined ? result.error.message : $r('app.string.local_backup_restore_failed'));
      this.getUIContext().getPromptAction().showToast({ message: message });
    });
  }

  private formatLastSyncAt(): ResourceStr {
    if (this.lastSyncAt === 0) {
      return $r('app.string.webdav_never_synced');
    }
    const date: Date = new Date(this.lastSyncAt);
    const year: number = date.getFullYear();
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    const hour: number = date.getHours();
    const minute: number = date.getMinutes();
    return `${year}-${month < 10 ? '0' + month : month}-${day < 10 ? '0' + day : day} ${hour < 10 ? '0' + hour : hour}:${minute < 10 ? '0' + minute : minute}`;
  }

  private formatSyncStatus(): ResourceStr {
    switch (this.syncStatus) {
      case SyncStatus.IDLE:
        return $r('app.string.webdav_status_idle');
      case SyncStatus.PUSHING:
        return $r('app.string.webdav_status_pushing');
      case SyncStatus.PULLING:
        return $r('app.string.webdav_status_pulling');
      case SyncStatus.SUCCESS:
        return $r('app.string.webdav_status_success');
      case SyncStatus.FAILED:
        return $r('app.string.webdav_status_failed');
      default:
        return $r('app.string.webdav_status_unknown');
    }
  }

  /** 状态灯语义：空闲灰 / 进行中蓝 / 成功绿 / 异常红。 */
  private statusTone(): string {
    if (this.syncStatus === SyncStatus.FAILED) {
      return 'failed';
    }
    if (this.syncStatus === SyncStatus.SUCCESS) {
      return 'success';
    }
    if (this.syncStatus === SyncStatus.PUSHING || this.syncStatus === SyncStatus.PULLING) {
      return 'active';
    }
    return 'idle';
  }

  private isBusy(): boolean {
    return this.syncStatus === SyncStatus.PUSHING || this.syncStatus === SyncStatus.PULLING;
  }

  /** syncMessage 为 Resource（恒视为有内容）或空串：仅在非空时渲染提示行。 */
  private hasSyncMessage(): boolean {
    const message: ResourceStr = this.syncMessage;
    return typeof message === 'string' ? message.length > 0 : true;
  }

  @Builder
  header() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_back'))
          .width(21)
          .height(21)
          .fillColor($r('app.color.text_primary'))
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(frostedPillColor())
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
      .shadow(glassPillShadow())
      .onClick(() => this.getUIContext().getRouter().back())

      Blank()

      Column({ space: 1 }) {
        Text($r('app.string.webdav_title'))
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.webdav_subtitle'))
          .fontSize(10.5)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)

      Blank()

      Text('')
        .width(42)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }

  /** 鸿蒙原生 Smooth 弹性开关。 */
  @Builder
  smoothSwitch(isOn: boolean, onChange: (value: boolean) => void) {
    Toggle({ type: ToggleType.Switch, isOn: isOn })
      .selectedColor($r('app.color.brand'))
      .switchPointColor(Color.White)
      .onChange(onChange)
  }

  @Builder
  toggleRow(label: ResourceStr, note: ResourceStr, isOn: boolean, isLast: boolean, onChange: (value: boolean) => void) {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 3 }) {
          Text(label)
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
          // Resource 副文案恒有内容；string 副文案为空串时不渲染
          if (note !== '') {
            Text(note)
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.smoothSwitch(isOn, onChange)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .alignItems(VerticalAlign.Center)

      if (!isLast) {
        Divider()
          .color($r('app.color.divider'))
          .margin({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  fieldLabel(label: ResourceStr) {
    Text(label)
      .fontSize(12.5)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
  }

  /** Outlined Glass 次要按钮：高光虚框 + 透明底。 */
  @Builder
  outlinedButton(params: ActionButtonParams) {
    Button() {
      Row({ space: 6 }) {
        if (params.icon !== undefined) {
          Image(params.icon)
            .width(15)
            .height(15)
            .fillColor(params.enabled ? $r('app.color.brand') : $r('app.color.text_tertiary'))
        }
        Text(params.label)
          .fontSize(14.5)
          .fontWeight(FontWeight.Medium)
          .fontColor(params.enabled ? $r('app.color.brand') : $r('app.color.text_tertiary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .height(48)
    .borderRadius(24)
    .backgroundColor(Color.Transparent)
    .border({
      width: 1,
      color: params.enabled ? $r('app.color.brand') : $r('app.color.field_border'),
      style: BorderStyle.Solid
    })
    .enabled(params.enabled)
    .onClick(params.onTap)
  }

  /** 主操作按钮：渐变高光填充 + 能量光晕。 */
  @Builder
  solidButton(params: ActionButtonParams) {
    Button(params.label)
      .layoutWeight(1)
      .height(48)
      .borderRadius(24)
      .fontSize(14.5)
      .fontWeight(FontWeight.Medium)
      .linearGradient({ angle: 90, colors: trackGradientColors(0) })
      .fontColor($r('app.color.fab_foreground'))
      .shadow(glowButtonShadow())
      .enabled(params.enabled)
      .onClick(params.onTap)
  }

  /** 半宽主按钮：与同排虚框按钮各占一半，长文案允许折成两行而不被截断。 */
  @Builder
  solidHalfButton(params: ActionButtonParams) {
    Button() {
      Text(params.label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.fab_foreground'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .lineHeight(16)
        .width('100%')
    }
    .layoutWeight(1)
    .height(46)
    .borderRadius(23)
    .padding({ left: 8, right: 8 })
    .linearGradient({ angle: 90, colors: trackGradientColors(0) })
    .shadow(glowButtonShadow())
    .enabled(params.enabled)
    .onClick(params.onTap)
  }

  /** 半宽虚框按钮：与主按钮同一行，各占一半。 */
  @Builder
  outlinedHalfButton(params: ActionButtonParams) {
    Button() {
      Text(params.label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(params.enabled ? $r('app.color.brand') : $r('app.color.text_tertiary'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .lineHeight(16)
        .width('100%')
    }
    .layoutWeight(1)
    .height(46)
    .borderRadius(23)
    .padding({ left: 8, right: 8 })
    .backgroundColor(Color.Transparent)
    .border({
      width: 1,
      color: params.enabled ? $r('app.color.brand') : $r('app.color.field_border'),
      style: BorderStyle.Solid
    })
    .enabled(params.enabled)
    .onClick(params.onTap)
  }

  /** 整宽虚框按钮：本机恢复使用；与上方两枚半宽按钮保持同一套字号、高度与配色。 */
  @Builder
  outlinedFullButton(params: ActionButtonParams) {
    Button(params.label)
      .width('100%')
      .height(46)
      .borderRadius(23)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(params.enabled ? $r('app.color.brand') : $r('app.color.text_tertiary'))
      .backgroundColor(Color.Transparent)
      .border({
        width: 1,
        color: params.enabled ? $r('app.color.brand') : $r('app.color.field_border'),
        style: BorderStyle.Solid
      })
      .enabled(params.enabled)
      .onClick(params.onTap)
  }

  @Builder
  statusDot() {
    // 脉冲动画的状态与定时器收敛进 PulseDot 内部：
    // 早先放在页面级 @State 上，每 1.4s 触发整页重渲染，会让受控输入框的文本被重新同步（表现为「输入后被清空」）。
    PulseDot({
      color: statusDotColor(this.statusTone()),
      active: this.isBusy() || this.statusTone() === 'failed'
    })
  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.Push, duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
    PageTransitionExit({ type: RouteType.Push, duration: 250, curve: Curve.EaseIn })
      .slide(SlideEffect.Left)
    PageTransitionEnter({ type: RouteType.Pop, duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ type: RouteType.Pop, duration: 250, curve: Curve.EaseIn })
      .slide(SlideEffect.Right)
  }

  build() {
    // @Entry 页面的 build 只能有唯一根节点，且必须是容器组件；
    // AuroraBackground 是自定义组件，故由 Stack 作为根承载它。
    Stack() {
      AuroraBackground() {
        Column() {
          this.header()

          Scroll() {
            Column({ space: 14 }) {
              // ---- 本机备份与恢复（置顶：本页的主入口） ----
              Column({ space: 10 }) {
                Column({ space: 3 }) {
                  Text($r('app.string.local_backup_title'))
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                  Text($r('app.string.local_backup_note'))
                    .fontSize(11)
                    .lineHeight(17)
                    .fontColor($r('app.color.text_tertiary'))
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Row({ space: 12 }) {
                  this.solidHalfButton({
                    label: $r('app.string.local_backup_export_encrypted'),
                    enabled: !this.localBusy,
                    onTap: () => this.onExportEncrypted()
                  })
                  this.outlinedHalfButton({
                    label: $r('app.string.local_backup_export_plain'),
                    enabled: !this.localBusy,
                    onTap: () => this.onExportPlain()
                  })
                }
                .width('100%')

                this.outlinedFullButton({
                  label: $r('app.string.local_backup_import'),
                  enabled: !this.localBusy,
                  onTap: () => this.onImportLocal()
                })

                Text($r('app.string.local_backup_plain_warning'))
                  .fontSize(11)
                  .lineHeight(17)
                  .fontColor($r('app.color.danger'))
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .borderRadius(22)
              .backgroundColor($r('app.color.card_background_solid'))
              .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow(glassGroupShadow())

              // ---- 开关分组 ----
              Column() {
                this.toggleRow($r('app.string.webdav_enable_label'), $r('app.string.webdav_enable_note'), this.webDavEnabled, false,
                  (value: boolean) => {
                    this.webDavEnabled = value;
                    this.persistConfig();
                  })
                this.toggleRow($r('app.string.webdav_auto_push_label'), $r('app.string.webdav_auto_push_note'), this.autoPush, false, (value: boolean) => {
                    this.autoPush = value;
                    this.persistConfig();
                })
                this.toggleRow($r('app.string.webdav_auto_pull_label'), $r('app.string.webdav_auto_pull_note'), this.autoPullOnStart, false, (value: boolean) => {
                    this.autoPullOnStart = value;
                    this.persistConfig();
                })
                this.toggleRow($r('app.string.webdav_clean_label'), $r('app.string.webdav_clean_note'),
                  this.cleanOldBackups, false, (value: boolean) => {
                    this.cleanOldBackups = value;
                    this.persistConfig();
                })
                this.toggleRow($r('app.string.webdav_insecure_label'), $r('app.string.webdav_insecure_note'),
                  this.allowInsecure, true, (value: boolean) => {
                    this.allowInsecure = value;
                    this.persistConfig();
                })
              }
              .width('100%')
              .borderRadius(22)
              .clip(true)
              .backgroundColor($r('app.color.card_background_solid'))
              .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow(glassGroupShadow())

              // ---- 连接配置（已保存过地址时默认折叠） ----
              Column({ space: 14 }) {
                Row({ space: 10 }) {
                  Column({ space: 2 }) {
                    Text($r('app.string.webdav_config_section_title'))
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                    if (!this.showConfigForm && this.hasSavedConfig()) {
                      Text(this.configSummary())
                        .fontSize(11.5)
                        .fontColor($r('app.color.text_tertiary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Image($r('app.media.ic_chevron_down'))
                    .width(14)
                    .height(14)
                    .fillColor($r('app.color.text_tertiary'))
                    .rotate({ angle: this.showConfigForm ? 180 : 0 })
                    .animation({ duration: 220, curve: Curve.FastOutSlowIn })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  this.showConfigForm = !this.showConfigForm;
                })

                if (this.showConfigForm) {
                  Column({ space: 8 }) {
                    this.fieldLabel($r('app.string.webdav_server_address'))
                    WebDavField({ value: $baseUrl, placeholder: $r('app.string.webdav_server_placeholder'), masked: false })

                    if (this.isPlainHttpUrl() && !this.allowInsecure) {
                      Text($r('app.string.webdav_http_blocked_warning'))
                        .fontSize(11.5)
                        .lineHeight(17)
                        .fontColor($r('app.color.danger'))
                        .width('100%')
                    }
                    if (this.isPlainHttpUrl() && this.allowInsecure) {
                      Text($r('app.string.webdav_insecure_warning'))
                        .fontSize(11.5)
                        .lineHeight(17)
                        .fontColor($r('app.color.warning'))
                        .width('100%')
                    }
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)

                  Column({ space: 8 }) {
                    this.fieldLabel($r('app.string.webdav_account_password'))
                    WebDavField({ value: $username, placeholder: $r('app.string.webdav_username_placeholder'), masked: false })
                    WebDavField({ value: $passwordInput, placeholder: $r('app.string.webdav_password_placeholder'), masked: true })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)

                  Column({ space: 8 }) {
                    this.fieldLabel($r('app.string.webdav_remote_path'))
                    WebDavField({ value: $remotePath, placeholder: '/SourceTime/', masked: false })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)

                  // 测试与保存跟随表单一起折叠：配置收起时不再占据首屏
                  Row({ space: 12 }) {
                    this.outlinedButton({
                      label: this.testing ? $r('app.string.webdav_testing') : $r('app.string.webdav_test_connection'),
                      enabled: !this.testing && !this.saving,
                      onTap: () => this.onTest()
                    })
                    this.solidButton({
                      label: this.saving ? $r('app.string.webdav_saving') : $r('app.string.webdav_save_config'),
                      enabled: !this.testing && !this.saving,
                      onTap: () => this.onSave()
                    })
                  }
                  .width('100%')
                }
              }
              .width('100%')
              .padding(16)
              .borderRadius(22)
              .backgroundColor($r('app.color.card_background_solid'))
              .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow(glassGroupShadow())

              // ---- 状态卡片 ----
              Column({ space: 12 }) {
                Row() {
                  Row({ space: 8 }) {
                    this.statusDot()
                    Text($r('app.string.webdav_sync_status'))
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                  }
                  .alignItems(VerticalAlign.Center)

                  Blank()

                  Text(this.formatSyncStatus())
                    .fontSize(14.5)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.syncStatus === SyncStatus.FAILED ? $r('app.color.danger')
                      : this.syncStatus === SyncStatus.SUCCESS ? $r('app.color.success')
                      : $r('app.color.text_secondary'))
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Row() {
                  Text($r('app.string.webdav_last_sync'))
                    .fontSize(12.5)
                    .fontColor($r('app.color.text_secondary'))
                  Blank()
                  Text(this.formatLastSyncAt())
                    .fontSize(12.5)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')

                if (this.hasSyncMessage()) {
                  Text(this.syncMessage)
                    .fontSize(11.5)
                    .lineHeight(18)
                    .fontColor($r('app.color.danger'))
                    .width('100%')
                }

                Row({ space: 12 }) {
                  this.outlinedButton({
                    label: this.pushing ? $r('app.string.webdav_pushing') : $r('app.string.webdav_manual_push'),
                    enabled: !this.pushing && !this.pulling && this.webDavEnabled && this.hasConfig(),
                    onTap: () => this.onPush(),
                    icon: $r('app.media.ic_arrow_up')
                  })
                  this.outlinedButton({
                    label: this.pulling ? $r('app.string.webdav_pulling') : $r('app.string.webdav_manual_pull'),
                    enabled: !this.pushing && !this.pulling && this.webDavEnabled && this.hasConfig(),
                    onTap: () => this.onPull(),
                    icon: $r('app.media.ic_arrow_down')
                  })
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .borderRadius(22)
              .backgroundColor($r('app.color.card_background_solid'))
              .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow(glassGroupShadow())

              Text($r('app.string.webdav_encryption_note'))
                .fontSize(11)
                .lineHeight(17)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')
                .padding({ left: 4, right: 4 })
            }
            .width('100%')
            // 同设置页：避免内容短于视口时被 Scroll 垂直居中
            .constraintSize({ minHeight: '100%' })
            .justifyContent(FlexAlign.Start)
            .padding({ left: 16, right: 16, bottom: 12 })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.TopStart)  // 内容不足一屏时不被 Scroll 垂直居中
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
      }
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * WebDAV 表单输入框：下沉式冰晶输入 + 获焦主色光晕。
 *
 * 关键点：TextInput 的 text 用 **$$ 双向绑定**（@Link 变量）。
 * 官方明确提示 —— 只传 `text: value` 时「组件刷新会导致 TextInput 中的文本内容异常」，
 * 也就是输入后内容被回滚/清空；$$ 绑定后变量与组件内部状态实时同步，任何刷新都不会丢失输入。
 */
@Component
struct WebDavField {
  @Link value: string;
  @Prop placeholder: ResourceStr = '';
  @Prop masked: boolean = false;
  @State focused: boolean = false;

  build() {
    TextInput({ placeholder: this.placeholder, text: $$this.value })
      .width('100%')
      .height(48)
      .borderRadius(14)
      .fontSize(14)
      .fontColor($r('app.color.text_primary'))
      .padding({ left: 14, right: 14 })
      .backgroundColor($r('app.color.field_background'))
      .placeholderColor($r('app.color.text_tertiary'))
      .caretColor($r('app.color.brand'))
      .type(this.masked ? InputType.Password : InputType.Normal)
      .showPasswordIcon(this.masked)
      .border({
        width: 1.5,
        color: this.focused ? $r('app.color.brand') : $r('app.color.field_border'),
        style: BorderStyle.Solid
      })
      .shadow(this.focused ? focusGlowShadow() : noShadow())
      .onFocus(() => {
        this.focused = true;
      })
      .onBlur(() => {
        this.focused = false;
      })
  }
}

/**
 * 状态脉冲灯：脉冲动画的状态与定时器收敛在组件内部，不再触发页面级重渲染。
 */
@Component
struct PulseDot {
  @Prop color: string = '';
  @Prop @Watch('onActiveChange') active: boolean = false;
  @State pulseOn: boolean = false;
  private timerId: number = -1;

  onActiveChange(): void {
    this.syncTimer();
  }

  aboutToAppear(): void {
    this.syncTimer();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private syncTimer(): void {
    if (this.active) {
      if (this.timerId < 0) {
        this.timerId = setInterval(() => {
          this.pulseOn = !this.pulseOn;
        }, 1400);
      }
      return;
    }
    this.stopTimer();
    this.pulseOn = false;
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.active) {
        Column()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.color)
          .opacity(this.pulseOn ? 0.0 : 0.55)
          .scale({ x: this.pulseOn ? 2.4 : 1.0, y: this.pulseOn ? 2.4 : 1.0 })
          .animation({ duration: 1400, curve: Curve.EaseOut })
      }

      Column()
        .width(9)
        .height(9)
        .borderRadius(5)
        .backgroundColor(this.color)
    }
    .width(14)
    .height(14)
  }
}
