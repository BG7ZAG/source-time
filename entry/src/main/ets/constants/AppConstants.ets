import { TotpAlgorithm } from '../model/TotpItem';

export const APP_NAME: string = '源时';

export const APP_NAME_EN: string = 'SourceTime';

export const DATABASE_FILE_NAME: string = 'totp.db.enc';

export const CURRENT_SCHEMA_VERSION: number = 1;

export const CURRENT_PRIVACY_POLICY_VERSION: string = '2.0';

/** 本地运行日志文件名（NDJSON，每行一条已脱敏日志）。 */
export const LOG_FILE_NAME: string = 'sourcetime_logs.ndjson';

/** 内存与磁盘保留的最大日志条数（超出丢弃最旧条目）。 */
export const LOG_MAX_ENTRIES: number = 500;

export const DEFAULT_TOTP_PERIOD: number = 30;

export const DEFAULT_TOTP_DIGITS: 6 | 8 = 6;

export const DEFAULT_TOTP_ALGORITHM: TotpAlgorithm = 'SHA1';

export const DEFAULT_WEBDAV_DIRECTORY: string = '/SourceTime/';

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
