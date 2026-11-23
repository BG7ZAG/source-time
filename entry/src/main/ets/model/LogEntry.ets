/** 日志级别。UI 上的筛选与配色都以此为准。 */
export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR'
}

/** 一条本地运行日志（message 在入库前已完成脱敏）。 */
export interface LogEntry {
  /** 记录时间（epoch 毫秒） */
  time: number;
  level: LogLevel;
  /** 来源模块：Storage / Sync / WebDAV / KeyStore / Settings / Crypto / App ... */
  tag: string;
  /** 已脱敏的消息正文 */
  message: string;
}
