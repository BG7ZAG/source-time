import { SettingsService } from './SettingsService';
import { KeyStoreService } from './KeyStoreService';
import { SyncService } from './SyncService';
import { PinService } from './PinService';
import { WebDavConfig } from '../model/WebDavConfig';
import { RemoteBackup } from '../model/RemoteBackup';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { APP_LOCK_STORAGE_KEY } from '../constants/AppConstants';
import { Logger } from '../utils/Logger';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';
const BUNDLE_VERSION: number = 1;

/** 配置包新鲜度：超过 5 分钟的包不应用，避免用手表上的旧配置覆盖当前状态。 */
export const CONFIG_BUNDLE_TTL_MS: number = 5 * 60 * 1000;

/**
 * 随配置一起同步到手表的查看保护状态。
 *
 * 只同步 PBKDF2 校验值与盐，不同步明文 PIN；手表用同一套 PinService 校验。
 */
export interface AppLockBundle {
  enabled: boolean;
  pinHash: string;
  pinSalt: string;
}

/**
 * 手机 → 手表的一次性配置包。
 *
 * 传输依赖同账号可信设备通道（distributedKVStore 已开启加密），不再叠加传输 PIN；
 * 手表端的“每次查看要 PIN”由 appLock 字段控制，复用现有应用锁遮罩。
 */
export interface ConfigBundlePayload {
  version: number;
  createdAt: number;
  secret: string;
  config: WebDavConfig;
  appLock: AppLockBundle;
}

/**
 * 配置包应用结果。
 *
 * 密钥同步与云端备份拉取是两件事：没有配置 WebDAV 或服务器暂时不可用时，
 * 密钥仍应成功落到手表，不能因为拉取失败就整包报错（否则用户会误以为「无法同步密钥」）。
 */
export interface ConfigApplyResult {
  keySynced: boolean;
  backupPulled: boolean;
  /** 备份拉取失败原因；仅 backupPulled 为 false 且有实际失败时存在。 */
  backupError?: ResourceStr;
}

export class ConfigSyncService {
  private static instance: ConfigSyncService | null = null;

  private settingsService: SettingsService = new SettingsService();
  private keyStoreService: KeyStoreService = new KeyStoreService();

  static getInstance(): ConfigSyncService {
    if (ConfigSyncService.instance === null) {
      ConfigSyncService.instance = new ConfigSyncService();
    }
    return ConfigSyncService.instance;
  }

  async createBundle(config: WebDavConfig, secret: string, appLock: AppLockBundle): Promise<Result<string>> {
    try {
      const payload: ConfigBundlePayload = {
        version: BUNDLE_VERSION,
        createdAt: Date.now(),
        secret: secret,
        config: config,
        appLock: appLock
      };
      return ok(JSON.stringify(payload));
    } catch (error) {
      Logger.error('Create config bundle failed');
      return err<string>(AppErrorCode.ENCRYPT_FAILED, $r('app.string.watch_sync_bundle_failed'));
    }
  }

  async openBundle(bundle: string): Promise<Result<ConfigBundlePayload>> {
    try {
      const payload: ConfigBundlePayload = JSON.parse(bundle) as ConfigBundlePayload;
      if (payload.version !== BUNDLE_VERSION || payload.config === undefined
        || typeof payload.secret !== 'string' || payload.appLock === undefined) {
        return err<ConfigBundlePayload>(AppErrorCode.INVALID_INPUT, $r('app.string.watch_sync_bundle_invalid'));
      }
      if (Date.now() - payload.createdAt > CONFIG_BUNDLE_TTL_MS) {
        return err<ConfigBundlePayload>(AppErrorCode.INVALID_INPUT, $r('app.string.watch_sync_bundle_expired'));
      }
      return ok(payload);
    } catch (error) {
      Logger.warn('Parse config bundle failed');
      return err<ConfigBundlePayload>(AppErrorCode.INVALID_INPUT, $r('app.string.watch_sync_bundle_invalid'));
    }
  }

  /**
   * 应用配置包：落密钥 → 存 WebDAV 配置 → 同步查看保护 → 拉取云端最新备份。
   * 查看保护在拉取完成后才置位，避免 PIN 遮罩挡住同步过程。
   */
  async applyBundle(payload: ConfigBundlePayload): Promise<Result<ConfigApplyResult>> {
    if (payload.secret.length === 0) {
      return err<ConfigApplyResult>(AppErrorCode.INVALID_INPUT, $r('app.string.watch_sync_bundle_invalid'));
    }
    AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, payload.secret);
    const settings = this.settingsService.getSettings();
    settings.encryptionInitialized = true;
    // 只有手机端确实启用了应用锁才覆盖手表的查看保护；
    // 手机端关闭应用锁时保留手表自己设置的 PIN，避免一次同步把手表锁清掉。
    if (payload.appLock.enabled
      && payload.appLock.pinHash.length > 0 && payload.appLock.pinSalt.length > 0) {
      settings.appLockPinHash = payload.appLock.pinHash;
      settings.appLockPinSalt = payload.appLock.pinSalt;
      settings.appLockEnabled = true;
    }
    const saveSettingsResult: Result<void> = await this.settingsService.saveSettings(settings);
    if (!saveSettingsResult.success) {
      return err<ConfigApplyResult>(AppErrorCode.STORAGE_WRITE_FAILED,
        saveSettingsResult.error !== undefined
          ? saveSettingsResult.error.message
          : $r('app.string.security_save_failed'));
    }
    await this.keyStoreService.save(payload.secret);

    // 没有 WebDAV 配置时，配置包里最重要的「密钥」已经落盘：到这里就算同步成功。
    // 审核环境常常只配置密钥、不配置 WebDAV，不能因此让整次同步失败。
    if (payload.config.baseUrl.trim().length === 0) {
      return ok<ConfigApplyResult>({ keySynced: true, backupPulled: false });
    }

    const saveConfigResult: Result<void> =
      await this.settingsService.saveWebDavConfig(payload.config, payload.secret);
    if (!saveConfigResult.success) {
      return ok<ConfigApplyResult>({
        keySynced: true,
        backupPulled: false,
        backupError: saveConfigResult.error !== undefined
          ? saveConfigResult.error.message
          : $r('app.string.watch_sync_failed')
      });
    }

    SyncService.getInstance().configure(payload.config, payload.secret);
    const listResult: Result<RemoteBackup[]> = await SyncService.getInstance().listBackups();
    if (!listResult.success || listResult.data === undefined) {
      // 密钥已同步成功；云端不可用只影响「顺带拉取备份」，单独提示原因
      return ok<ConfigApplyResult>({
        keySynced: true,
        backupPulled: false,
        backupError: listResult.error !== undefined
          ? listResult.error.message
          : $r('app.string.watch_sync_failed')
      });
    }
    if (listResult.data.length === 0) {
      return ok<ConfigApplyResult>({
        keySynced: true,
        backupPulled: false,
        backupError: $r('app.string.watch_sync_no_backup')
      });
    }
    const pullResult: Result<void> = await SyncService.getInstance().pullBackup(listResult.data[0].name);
    if (!pullResult.success) {
      return ok<ConfigApplyResult>({
        keySynced: true,
        backupPulled: false,
        backupError: pullResult.error !== undefined
          ? pullResult.error.message
          : $r('app.string.watch_sync_failed')
      });
    }
    // 拉取完成后按手机端的开关立即上锁：符合“每次查看都要 PIN”的语义
    AppStorage.setOrCreate<boolean>(APP_LOCK_STORAGE_KEY, new PinService().isLockUsable());
    return ok<ConfigApplyResult>({ keySynced: true, backupPulled: true });
  }
}
