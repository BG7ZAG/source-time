import { SettingsService } from './SettingsService';
import { KeyStoreService } from './KeyStoreService';
import { PinService } from './PinService';
import { StorageService } from './StorageService';
import { TotpItem } from '../model/TotpItem';
import { DatabaseModel } from '../model/DatabaseModel';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { APP_LOCK_STORAGE_KEY } from '../constants/AppConstants';
import { Logger } from '../utils/Logger';
import { nowMilliseconds } from '../utils/TimeUtils';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

/**
 * 包格式版本。
 *
 * v1：带 WebDavConfig（服务器地址/账号/密码）。
 * v2：不再下发任何 WebDAV 信息——云同步凭据只留在手机侧，接收端拿不到也用不上。
 *     接收端仍接受 v1，但会忽略其中的 config 字段。
 */
const BUNDLE_VERSION: number = 2;
const LEGACY_BUNDLE_VERSION: number = 1;

/**
 * 配置包新鲜度：超过 30 分钟的包不应用，避免用旧包覆盖当前状态。
 *
 * 审核/实际使用中，手机添加口令与在目标设备上操作之间可能间隔较久；5 分钟过短会导致
 * 刚同步就提示「配置已过期」。分布式库本身加密，延长到 30 分钟仍保持一次性。
 */
export const CONFIG_BUNDLE_TTL_MS: number = 30 * 60 * 1000;

/**
 * 随包一起同步的查看保护状态。
 *
 * 只同步 PBKDF2 校验值与盐，不同步明文 PIN；接收端用同一套 PinService 校验。
 */
export interface AppLockBundle {
  enabled: boolean;
  pinHash: string;
  pinSalt: string;
}

/**
 * 手机 → 其他设备的一次性配置包。
 *
 * 传输依赖同账号可信设备通道（distributedKVStore 已开启加密），不再叠加传输 PIN；
 * 目标设备的「每次查看要 PIN」由 appLock 字段控制，复用现有应用锁遮罩。
 *
 * 刻意不含 WebDAV 配置：云同步凭据泄露的后果（整个云盘）远高于 TOTP 数据，
 * 而目标设备既不能配置它、也没有使用它的场景。
 */
export interface ConfigBundlePayload {
  version: number;
  createdAt: number;
  secret: string;
  appLock: AppLockBundle;
  /**
   * 手机端当前全部口令条目。
   *
   * 目标设备的口令唯一来源：传输走同账号可信设备的加密分布式库，保持 30 分钟新鲜度。
   * 接收端按 id 合并，不删除目标设备独有的条目。
   */
  items: TotpItem[];
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

  async createBundle(secret: string, appLock: AppLockBundle, items: TotpItem[]): Promise<Result<string>> {
    try {
      const payload: ConfigBundlePayload = {
        version: BUNDLE_VERSION,
        createdAt: Date.now(),
        secret: secret,
        appLock: appLock,
        items: items
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
      const versionOk: boolean =
        payload.version === BUNDLE_VERSION || payload.version === LEGACY_BUNDLE_VERSION;
      if (!versionOk || typeof payload.secret !== 'string' || payload.appLock === undefined) {
        return err<ConfigBundlePayload>(AppErrorCode.INVALID_INPUT, $r('app.string.watch_sync_bundle_invalid'));
      }
      // 兼容旧包（没有 items 字段）：按空数组处理，密钥仍可用。
      // v1 包里的 config 字段一律忽略——既不落盘，也不会被用于联网。
      if (!Array.isArray(payload.items)) {
        payload.items = [];
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
   * 应用配置包：落密钥 → 同步查看保护 → 合并口令条目。
   *
   * 全程不做网络操作：云同步凭据不下发，接收端也没有拉取备份的职责。
   */
  async applyBundle(payload: ConfigBundlePayload): Promise<Result<void>> {
    if (payload.secret.length === 0) {
      return err<void>(AppErrorCode.INVALID_INPUT, $r('app.string.watch_sync_bundle_invalid'));
    }
    AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, payload.secret);
    const settings = this.settingsService.getSettings();
    settings.encryptionInitialized = true;
    // 只有手机端确实启用了应用锁才覆盖本机的查看保护；
    // 手机端关闭应用锁时保留本机自己设置的 PIN，避免一次同步把锁清掉。
    if (payload.appLock.enabled
      && payload.appLock.pinHash.length > 0 && payload.appLock.pinSalt.length > 0) {
      settings.appLockPinHash = payload.appLock.pinHash;
      settings.appLockPinSalt = payload.appLock.pinSalt;
      settings.appLockEnabled = true;
    }
    const saveSettingsResult: Result<void> = await this.settingsService.saveSettings(settings);
    if (!saveSettingsResult.success) {
      return err<void>(AppErrorCode.STORAGE_WRITE_FAILED,
        saveSettingsResult.error !== undefined
          ? saveSettingsResult.error.message
          : $r('app.string.security_save_failed'));
    }
    await this.keyStoreService.save(payload.secret);
    await this.mergeItemsBundle(payload);
    // 查看保护立即生效：同步完这一屏就应该要 PIN，不能等应用退到后台才锁
    AppStorage.setOrCreate<boolean>(APP_LOCK_STORAGE_KEY, new PinService().isLockUsable());
    return ok(undefined);
  }

  /**
   * 把手机的口令条目合并到本机库。
   *
   * 以 id 为准：手机传来的同 id 条目覆盖本地版本，本机独有的条目保留，
   * 因此本机自己新增/修改的内容不会被一次同步清空。
   */
  private async mergeItemsBundle(payload: ConfigBundlePayload): Promise<void> {
    const incoming: TotpItem[] = payload.items !== undefined ? payload.items : [];
    if (incoming.length === 0) {
      return;
    }
    const storage: StorageService = StorageService.getInstance();
    const loadResult: Result<DatabaseModel> = await storage.loadDatabase(payload.secret);
    if (!loadResult.success || loadResult.data === undefined) {
      Logger.warn('Merge bundle items skipped: local database load failed');
      return;
    }
    const local: DatabaseModel = loadResult.data;
    const merged: TotpItem[] = local.items.slice();
    for (let i = 0; i < incoming.length; i++) {
      const item: TotpItem = incoming[i];
      if (typeof item.id !== 'string' || item.id.length === 0) {
        continue;
      }
      let replaced: boolean = false;
      for (let j = 0; j < merged.length; j++) {
        if (merged[j].id === item.id) {
          merged[j] = item;
          replaced = true;
          break;
        }
      }
      if (!replaced) {
        merged.push(item);
      }
    }
    const nextDb: DatabaseModel = {
      version: local.version,
      revision: local.revision + 1,
      updatedAt: nowMilliseconds(),
      deviceId: local.deviceId,
      items: merged
    };
    const saveResult: Result<void> = await storage.saveDatabase(nextDb, payload.secret);
    if (!saveResult.success) {
      Logger.warn('Merge bundle items skipped: local database save failed');
      return;
    }
    Logger.info('Bundle items merged: incoming=' + incoming.length + ' total=' + merged.length);
  }
}
