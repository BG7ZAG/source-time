import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { AppContextHolder } from '../utils/AppContextHolder';
import { SettingsModel } from '../model/SettingsModel';
import { WebDavConfig } from '../model/WebDavConfig';
import { CryptoService } from './CryptoService';
import { Logger } from '../utils/Logger';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';

const STORE_NAME: string = 'sourcetime_settings';
const KEY_PRIVACY_ACCEPTED: string = 'privacyPolicyAccepted';
const KEY_PRIVACY_VERSION: string = 'privacyPolicyVersion';
const KEY_ENCRYPTION_INITIALIZED: string = 'encryptionInitialized';
const KEY_WEBDAV_ENABLED: string = 'webDavEnabled';
const KEY_WEBDAV_URL: string = 'webDavUrl';
const KEY_WEBDAV_USERNAME: string = 'webDavUsername';
const KEY_WEBDAV_REMOTE_PATH: string = 'webDavRemotePath';
const KEY_WEBDAV_PASSWORD_ENC: string = 'webDavPasswordEnc';
const KEY_AUTO_PUSH: string = 'autoPush';
const KEY_AUTO_PULL: string = 'autoPullOnStart';
const KEY_AUTO_CLEAN_BACKUPS: string = 'webDavCleanOldBackups';
const KEY_WEBDAV_ALLOW_INSECURE: string = 'webDavAllowInsecure';
const KEY_LAST_SYNC_AT: string = 'lastSyncAt';
const KEY_APP_LOCK_ENABLED: string = 'appLockEnabled';
const KEY_APP_LOCK_PIN_HASH: string = 'appLockPinHash';
const KEY_APP_LOCK_PIN_SALT: string = 'appLockPinSalt';
const KEY_APP_LOCK_FAIL_COUNT: string = 'appLockFailCount';
const KEY_APP_LOCK_LOCK_UNTIL: string = 'appLockLockUntil';

export class SettingsService {
  private store: preferences.Preferences;
  private cryptoService: CryptoService = new CryptoService();

  constructor() {
    const context = AppContextHolder.getContext();
    const options: preferences.Options = { name: STORE_NAME };
    this.store = preferences.getPreferencesSync(context, options);
  }

  getSettings(): SettingsModel {
    const settings: SettingsModel = {
      privacyPolicyAccepted: this.getBoolean(KEY_PRIVACY_ACCEPTED, false),
      privacyPolicyVersion: this.getString(KEY_PRIVACY_VERSION, ''),
      encryptionInitialized: this.getBoolean(KEY_ENCRYPTION_INITIALIZED, false),
      webDavEnabled: this.getBoolean(KEY_WEBDAV_ENABLED, false),
      autoPush: this.getBoolean(KEY_AUTO_PUSH, false),
      autoPullOnStart: this.getBoolean(KEY_AUTO_PULL, false),
      appLockEnabled: this.getBoolean(KEY_APP_LOCK_ENABLED, false),
      appLockPinHash: this.getString(KEY_APP_LOCK_PIN_HASH, ''),
      appLockPinSalt: this.getString(KEY_APP_LOCK_PIN_SALT, ''),
      lastSyncAt: this.getNumber(KEY_LAST_SYNC_AT, 0)
    };
    return settings;
  }

  async saveSettings(settings: SettingsModel): Promise<Result<void>> {
    try {
      this.store.putSync(KEY_PRIVACY_ACCEPTED, settings.privacyPolicyAccepted);
      this.store.putSync(KEY_PRIVACY_VERSION, settings.privacyPolicyVersion);
      this.store.putSync(KEY_ENCRYPTION_INITIALIZED, settings.encryptionInitialized);
      this.store.putSync(KEY_WEBDAV_ENABLED, settings.webDavEnabled);
      this.store.putSync(KEY_AUTO_PUSH, settings.autoPush);
      this.store.putSync(KEY_AUTO_PULL, settings.autoPullOnStart);
      this.store.putSync(KEY_APP_LOCK_ENABLED, settings.appLockEnabled);
      this.store.putSync(KEY_APP_LOCK_PIN_HASH, settings.appLockPinHash);
      this.store.putSync(KEY_APP_LOCK_PIN_SALT, settings.appLockPinSalt);
      const lastSyncAt: number = settings.lastSyncAt !== undefined ? settings.lastSyncAt : 0;
      this.store.putSync(KEY_LAST_SYNC_AT, lastSyncAt);
      await this.store.flush();
      return ok(undefined);
    } catch (error) {
      Logger.error('Settings save failed');
      return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, $r('app.string.error_save_settings_failed'));
    }
  }

  /** 应用锁连续失败次数，用于失败限速；独立写入避免被整体保存覆盖。 */
  getAppLockFailCount(): number {
    return this.getNumber(KEY_APP_LOCK_FAIL_COUNT, 0);
  }

  /** 应用锁锁定截止时间（毫秒时间戳）；0 表示未锁定。 */
  getAppLockLockUntil(): number {
    return this.getNumber(KEY_APP_LOCK_LOCK_UNTIL, 0);
  }

  async saveAppLockThrottle(failCount: number, lockUntil: number): Promise<void> {
    try {
      this.store.putSync(KEY_APP_LOCK_FAIL_COUNT, failCount);
      this.store.putSync(KEY_APP_LOCK_LOCK_UNTIL, lockUntil);
      await this.store.flush();
    } catch (error) {
      Logger.error('App lock throttle save failed');
    }
  }

  async saveWebDavConfig(config: WebDavConfig, encryptionSecret: string): Promise<Result<void>> {
    try {
      this.store.putSync(KEY_WEBDAV_ENABLED, config.enabled);
      this.store.putSync(KEY_WEBDAV_URL, config.baseUrl);
      this.store.putSync(KEY_WEBDAV_USERNAME, config.username);
      this.store.putSync(KEY_WEBDAV_REMOTE_PATH, config.remotePath);
      this.store.putSync(KEY_AUTO_PUSH, config.autoPush);
      this.store.putSync(KEY_AUTO_PULL, config.autoPullOnStart);
      this.store.putSync(KEY_AUTO_CLEAN_BACKUPS, config.cleanOldBackups);
      this.store.putSync(KEY_WEBDAV_ALLOW_INSECURE, config.allowInsecure);
      if (config.password.length > 0) {
        if (encryptionSecret.length === 0) {
          // 没有加密密钥：明文落盘违反安全要求，静默丢弃又会让用户误以为已保存。
          Logger.error('WebDAV password save skipped: encryption secret missing');
          return err<void>(AppErrorCode.WEBDAV_AUTH_FAILED, $r('app.string.error_webdav_password_key_missing'));
        }
        const plainBytes: Uint8Array = new util.TextEncoder().encodeInto(config.password);
        const encrypted: Uint8Array = await this.cryptoService.encrypt(plainBytes, encryptionSecret);
        const encoded: string = new util.Base64Helper().encodeToStringSync(encrypted, util.Type.BASIC);
        this.store.putSync(KEY_WEBDAV_PASSWORD_ENC, encoded);
        // 只记长度：地址与账号属于可识别信息，不落到（可导出的）本机日志里
        Logger.info('WebDAV password stored (encrypted with current key): pwdLen=' + config.password.length, 'Settings');
      } else {
        this.store.deleteSync(KEY_WEBDAV_PASSWORD_ENC);
        Logger.info('WebDAV password cleared');
      }
      await this.store.flush();
      return ok(undefined);
    } catch (error) {
      Logger.error('Settings save WebDAV config failed');
      return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, $r('app.string.error_save_config_failed'));
    }
  }

  async loadWebDavConfig(encryptionSecret: string): Promise<WebDavConfig> {
    let password: string = '';
    const encoded: string = this.getString(KEY_WEBDAV_PASSWORD_ENC, '');
    if (encoded.length > 0 && encryptionSecret.length > 0) {
      try {
        const encrypted: Uint8Array = new util.Base64Helper().decodeSync(encoded, util.Type.BASIC);
        const plainBytes: Uint8Array = await this.cryptoService.decrypt(encrypted, encryptionSecret);
        password = util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(plainBytes, { stream: false });
        Logger.info('WebDAV password loaded: pwdLen=' + password.length, 'Settings');
      } catch (error) {
        Logger.error('WebDAV password decrypt failed (key mismatch or corrupted ciphertext)', 'Settings');
        password = '';
      }
    } else {
      Logger.info('WebDAV password not loadable: hasCiphertext=' + (encoded.length > 0)
        + ' hasKey=' + (encryptionSecret.length > 0), 'Settings');
    }
    const config: WebDavConfig = {
      enabled: this.getBoolean(KEY_WEBDAV_ENABLED, false),
      baseUrl: this.getString(KEY_WEBDAV_URL, ''),
      username: this.getString(KEY_WEBDAV_USERNAME, ''),
      password: password,
      remotePath: this.getString(KEY_WEBDAV_REMOTE_PATH, ''),
      autoPush: this.getBoolean(KEY_AUTO_PUSH, false),
      autoPullOnStart: this.getBoolean(KEY_AUTO_PULL, false),
      cleanOldBackups: this.getBoolean(KEY_AUTO_CLEAN_BACKUPS, true),
      allowInsecure: this.getBoolean(KEY_WEBDAV_ALLOW_INSECURE, false)
    };
    return config;
  }

  private getBoolean(key: string, defaultValue: boolean): boolean {
    const value = this.store.getSync(key, defaultValue);
    return typeof value === 'boolean' ? value : defaultValue;
  }

  private getString(key: string, defaultValue: string): string {
    const value = this.store.getSync(key, defaultValue);
    return typeof value === 'string' ? value : defaultValue;
  }

  private getNumber(key: string, defaultValue: number): number {
    const value = this.store.getSync(key, defaultValue);
    return typeof value === 'number' ? value : defaultValue;
  }
}
