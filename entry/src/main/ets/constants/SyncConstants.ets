/**
 * 云端备份命名：一律带日期时间，不存在「不带时间的固定副本」。
 * 例：sourcetime-20261014-154512.enc（本地时区）
 */
export const REMOTE_BACKUP_PREFIX: string = 'sourcetime-';
export const REMOTE_BACKUP_SUFFIX: string = '.enc';

export const SYNC_MAX_RETRY: number = 2;

/** 云端保留的时间戳快照份数上限（开启「自动清理旧备份」时生效）。 */
export const REMOTE_BACKUP_KEEP_COUNT: number = 10;

function pad2(value: number): string {
  return value < 10 ? '0' + value : value.toString();
}

/** 由时间戳生成带日期时间的快照文件名（本地时区）。 */
export function buildBackupFileName(timestamp: number): string {
  const date: Date = new Date(timestamp);
  return REMOTE_BACKUP_PREFIX + date.getFullYear().toString() + pad2(date.getMonth() + 1)
    + pad2(date.getDate()) + '-' + pad2(date.getHours()) + pad2(date.getMinutes())
    + pad2(date.getSeconds()) + REMOTE_BACKUP_SUFFIX;
}

/** 是否为本应用生成的时间戳快照（严格前缀+后缀，不匹配第三方文件，避免误列/误删）。 */
export function isBackupFileName(name: string): boolean {
  return name.startsWith(REMOTE_BACKUP_PREFIX) && name.endsWith(REMOTE_BACKUP_SUFFIX);
}

/** 从快照文件名解析时间戳（毫秒）；非快照名或格式不符返回 0。 */
export function parseBackupTimestamp(name: string): number {
  if (!isBackupFileName(name)) {
    return 0;
  }
  const core: string = name.substring(REMOTE_BACKUP_PREFIX.length, name.length - REMOTE_BACKUP_SUFFIX.length);
  // 期望格式：20261014-154512
  if (core.length !== 15 || core.charAt(8) !== '-') {
    return 0;
  }
  const year: number = Number(core.substring(0, 4));
  const month: number = Number(core.substring(4, 6));
  const day: number = Number(core.substring(6, 8));
  const hour: number = Number(core.substring(9, 11));
  const minute: number = Number(core.substring(11, 13));
  const second: number = Number(core.substring(13, 15));
  if (Number.isNaN(year) || Number.isNaN(month) || Number.isNaN(day)
    || Number.isNaN(hour) || Number.isNaN(minute) || Number.isNaN(second)) {
    return 0;
  }
  return new Date(year, month - 1, day, hour, minute, second).getTime();
}
