export interface WebDavConfig {
  enabled: boolean;
  baseUrl: string;
  username: string;
  password: string;
  remotePath: string;
  autoPush: boolean;
  autoPullOnStart: boolean;
  /** 推送后自动清理云端旧快照，仅保留最近 REMOTE_BACKUP_KEEP_COUNT 份。 */
  cleanOldBackups: boolean;
}
