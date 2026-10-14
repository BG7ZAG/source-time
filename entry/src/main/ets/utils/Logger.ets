import { hilog } from '@kit.PerformanceAnalysisKit';
import { LogEntry, LogLevel } from '../model/LogEntry';
import { LogStore } from '../service/LogStore';
import { maskSensitive } from './Sanitizer';
import { nowMilliseconds } from './TimeUtils';

const DOMAIN: number = 0x0000;
const TAG: string = 'SourceTime';

/**
 * 历史调用点未显式声明模块名，这里按消息前缀归类。
 * 表内是「确定性的精确前缀」，命中即归类，不做模糊匹配；未命中归为 App。
 * 新代码请直接传第二个参数（如 Logger.info('...', 'Storage')）显式声明来源。
 */
const SOURCE_PREFIXES: string[] = [
  'Storage', 'Sync', 'KeyStore', 'WebDAV', 'Settings', 'Crypto',
  'TOTP', 'Clipboard', 'Encryption', 'Asset', 'Local', 'SourceTime'
];

/**
 * 统一日志入口：hilog 输出 + 本地持久化（供「运行日志」页面查看）。
 *
 * 约定：
 * - 消息正文应写「可诊断的上下文」：目标地址/目录、HTTP 状态码、字节数、耗时、错误原因等，
 *   让日志能直接定位问题；密码、密钥、令牌、Basic 凭据等机密一律不写明文（只可记长度或「是否已设置」）；
 * - 落盘与展示前统一过 maskSensitive() 脱敏，作为最后一道兜底；
 * - 日志写入失败绝不影响业务主流程。
 */
export class Logger {
  static debug(message: string, source: string = ''): void {
    hilog.debug(DOMAIN, TAG, '%{public}s', message);
    Logger.record(LogLevel.DEBUG, source, message);
  }

  static info(message: string, source: string = ''): void {
    hilog.info(DOMAIN, TAG, '%{public}s', message);
    Logger.record(LogLevel.INFO, source, message);
  }

  static warn(message: string, source: string = ''): void {
    hilog.warn(DOMAIN, TAG, '%{public}s', message);
    Logger.record(LogLevel.WARN, source, message);
  }

  static error(message: string, source: string = ''): void {
    hilog.error(DOMAIN, TAG, '%{public}s', message);
    Logger.record(LogLevel.ERROR, source, message);
  }

  /** 本地日志（含历史），按时间升序。 */
  static getEntries(): LogEntry[] {
    return LogStore.getInstance().getEntries();
  }

  /** 清空本地日志。 */
  static clearLogs(): void {
    LogStore.getInstance().clear();
  }

  /** 立即把内存日志写入磁盘（页面加载前调用）。 */
  static flush(): void {
    LogStore.getInstance().flushNow();
  }

  /** 导出为可读文本（用于「复制全部」）。带时间戳，便于对照复现步骤。 */
  static toDisplayText(): string {
    const entries: LogEntry[] = Logger.getEntries();
    let text: string = '';
    for (const entry of entries) {
      text += '[' + Logger.formatStamp(entry.time) + '][' + entry.level + '][' + entry.tag + '] '
        + entry.message + '\n';
    }
    return text;
  }

  /** 时间戳格式化为 MM-dd HH:mm:ss.SSS。 */
  private static formatStamp(milliseconds: number): string {
    const date: Date = new Date(milliseconds);
    return Logger.pad(date.getMonth() + 1, 2) + '-' + Logger.pad(date.getDate(), 2) + ' '
      + Logger.pad(date.getHours(), 2) + ':' + Logger.pad(date.getMinutes(), 2) + ':'
      + Logger.pad(date.getSeconds(), 2) + '.' + Logger.pad(date.getMilliseconds(), 3);
  }

  private static pad(value: number, width: number): string {
    let text: string = value.toString();
    while (text.length < width) {
      text = '0' + text;
    }
    return text;
  }

  private static record(level: LogLevel, source: string, message: string): void {
    const entry: LogEntry = {
      time: nowMilliseconds(),
      level: level,
      tag: source.length > 0 ? source : Logger.inferSource(message),
      message: maskSensitive(message)
    };
    try {
      LogStore.getInstance().append(entry);
    } catch (error) {
      // 日志落盘异常绝不阻断业务
    }
  }

  private static inferSource(message: string): string {
    for (const prefix of SOURCE_PREFIXES) {
      if (message.startsWith(prefix)) {
        return prefix;
      }
    }
    return 'App';
  }
}
