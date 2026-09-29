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
const KEY_LAST_SYNC_AT: string = 'lastSyncAt';

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
      const lastSyncAt: number = settings.lastSyncAt !== undefined ? settings.lastSyncAt : 0;
      this.store.putSync(KEY_LAST_SYNC_AT, lastSyncAt);
      await this.store.flush();
      return ok(undefined);
    } catch (error) {
      Logger.error('Settings save failed');
      return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, '保存设置失败');
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
      if (config.password.length > 0 && encryptionSecret.length > 0) {
        const plainBytes: Uint8Array = new util.TextEncoder().encodeInto(config.password);
        const encrypted: Uint8Array = await this.cryptoService.encrypt(plainBytes, encryptionSecret);
        const encoded: string = new util.Base64Helper().encodeToStringSync(encrypted, util.Type.BASIC);
        this.store.putSync(KEY_WEBDAV_PASSWORD_ENC, encoded);
      } else if (config.password.length === 0) {
        this.store.deleteSync(KEY_WEBDAV_PASSWORD_ENC);
      }
      await this.store.flush();
      return ok(undefined);
    } catch (error) {
      Logger.error('Settings save WebDAV config failed');
      return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, '保存配置失败');
    }
  }

  async loadWebDavConfig(encryptionSecret: string): Promise<WebDavConfig> {
    let password: string = '';
    const encoded: string = this.getString(KEY_WEBDAV_PASSWORD_ENC, '');
    if (encoded.length > 0 && encryptionSecret.length > 0) {
      try {
        const encrypted: Uint8Array = new util.Base64Helper().decodeSync(encoded, util.Type.BASIC);
        const plainBytes: Uint8Array = await this.cryptoService.decrypt(encrypted, encryptionSecret);
        password = new util.TextDecoder().decode(plainBytes);
      } catch (error) {
        Logger.error('WebDAV password decrypt failed');
        password = '';
      }
    }
    const config: WebDavConfig = {
      enabled: this.getBoolean(KEY_WEBDAV_ENABLED, false),
      baseUrl: this.getString(KEY_WEBDAV_URL, ''),
      username: this.getString(KEY_WEBDAV_USERNAME, ''),
      password: password,
      remotePath: this.getString(KEY_WEBDAV_REMOTE_PATH, ''),
      autoPush: this.getBoolean(KEY_AUTO_PUSH, false),
      autoPullOnStart: this.getBoolean(KEY_AUTO_PULL, false)
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
