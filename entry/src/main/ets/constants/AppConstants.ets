import { TotpAlgorithm } from '../model/TotpItem';

export const APP_NAME: string = '源时';

export const APP_NAME_EN: string = 'SourceTime';

export const DATABASE_FILE_NAME: string = 'totp.db.enc';

export const CURRENT_SCHEMA_VERSION: number = 1;

export const CURRENT_PRIVACY_POLICY_VERSION: string = '2.3';

/** 本地运行日志文件名（NDJSON，每行一条已脱敏日志）。 */
export const LOG_FILE_NAME: string = 'sourcetime_logs.ndjson';

/** 内存与磁盘保留的最大日志条数（超出丢弃最旧条目）。 */
export const LOG_MAX_ENTRIES: number = 500;

export const DEFAULT_TOTP_PERIOD: number = 30;

/** TOTP 周期的允许范围（秒）。上限 1 小时：超过的基本都是写错的参数，接受只会让口令长期不变。 */
export const MIN_TOTP_PERIOD: number = 1;

export const MAX_TOTP_PERIOD: number = 3600;

export const DEFAULT_TOTP_DIGITS: 6 | 8 = 6;

export const DEFAULT_TOTP_ALGORITHM: TotpAlgorithm = 'SHA1';

export const DEFAULT_WEBDAV_DIRECTORY: string = '/SourceTime/';

/**
 * 联网备份总开关（WebDAV）。
 *
 * 已放开限制：设置页入口、WebDavPage、冷启动自动拉取与密钥变更后的自动推送全部可用。
 * 若后续需要再次整体关闭联网能力（如临时审核要求），把这里改为 false 即可，
 * 各页面与服务的既有判断会自动生效；同时需在 module.json5 中移除 INTERNET 权限。
 */
export const WEBDAV_FEATURE_ENABLED: boolean = true;

/** AppStorage 键：应用锁状态，true 表示需要输入 PIN 才能查看内容。 */
export const APP_LOCK_STORAGE_KEY: string = 'appLocked';

export class AppRoutes {
  static readonly HOME: string = 'pages/HomePage';

  static readonly SCAN: string = 'pages/ScanPage';

  static readonly SETTINGS: string = 'pages/SettingsPage';

  static readonly SECURITY: string = 'pages/SecurityPage';

  static readonly WEBDAV: string = 'pages/WebDavPage';

  static readonly PRIVACY_POLICY: string = 'pages/PrivacyPolicyPage';

  static readonly ABOUT: string = 'pages/AboutPage';

  static readonly LOGS: string = 'pages/LogPage';
}
