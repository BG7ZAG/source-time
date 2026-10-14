import { fileIo as fs } from '@kit.CoreFileKit';
import { AppContextHolder } from '../utils/AppContextHolder';
import { LogEntry } from '../model/LogEntry';
import { LOG_FILE_NAME, LOG_MAX_ENTRIES } from '../constants/AppConstants';

const FLUSH_DELAY_MS: number = 400;

/**
 * 本地日志存储：内存环形缓冲 + 防抖落盘（NDJSON，单文件覆盖写）。
 *
 * 设计取舍：
 * - 覆盖写而非追加：文件最多 LOG_MAX_ENTRIES 行，天然完成轮转，不需要额外的清理/切割逻辑，
 *   也不会出现日志文件无限膨胀把用户磁盘写满的情况。
 * - 防抖落盘：Logger 可能被高频调用（每次同步、每次加解密），逐条 fs.write 会拖慢主线程。
 * - 脱敏在 Logger 入库前完成，本类只负责存取，不做二次处理。
 * - 极早期（AppContext 未就绪）只留在内存，不抛错、不丢业务。
 */
export class LogStore {
  private static instance: LogStore | null = null;

  private entries: LogEntry[] = [];
  private loaded: boolean = false;
  private flushTimer: number = -1;

  static getInstance(): LogStore {
    if (LogStore.instance === null) {
      LogStore.instance = new LogStore();
    }
    return LogStore.instance;
  }

  /** 追加一条日志（内存立即可见，磁盘防抖写入）。 */
  append(entry: LogEntry): void {
    this.ensureLoaded();
    this.entries.push(entry);
    if (this.entries.length > LOG_MAX_ENTRIES) {
      this.entries.splice(0, this.entries.length - LOG_MAX_ENTRIES);
    }
    this.scheduleFlush();
  }

  /** 全部日志（启动时已从磁盘载入历史），按时间升序。 */
  getEntries(): LogEntry[] {
    this.ensureLoaded();
    return this.entries;
  }

  /** 清空内存与磁盘日志。 */
  clear(): void {
    this.entries = [];
    this.loaded = true;
    const path: string = this.resolvePath();
    if (path.length === 0) {
      return;
    }
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (error) {
      // 文件本就不存在或删除失败都不阻断：后续 flush 会重建文件
    }
  }

  /** 立即落盘（页面打开前调用，确保读到的是最新内容）。 */
  flushNow(): void {
    if (this.flushTimer !== -1) {
      clearTimeout(this.flushTimer);
      this.flushTimer = -1;
    }
    this.flush();
  }

  /** 日志文件绝对路径；AppContext 未就绪时返回空串（表示只保留在内存）。 */
  private resolvePath(): string {
    try {
      return AppContextHolder.getContext().filesDir + '/' + LOG_FILE_NAME;
    } catch (error) {
      return '';
    }
  }

  /** 首次访问时把磁盘历史读入内存（只读一次；失败则视为没有历史）。 */
  private ensureLoaded(): void {
    if (this.loaded) {
      return;
    }
    // 先置位，避免读盘过程中再次进入本方法造成递归
    this.loaded = true;
    const path: string = this.resolvePath();
    if (path.length === 0) {
      return;
    }
    try {
      if (!fs.accessSync(path)) {
        return;
      }
      const text: string = fs.readTextSync(path);
      const lines: string[] = text.split('\n');
      for (const line of lines) {
        const trimmed: string = line.trim();
        if (trimmed.length === 0) {
          continue;
        }
        try {
          this.entries.push(JSON.parse(trimmed) as LogEntry);
        } catch (error) {
          // 单行损坏（如写入中途断电）跳过，不影响其余历史
        }
      }
      if (this.entries.length > LOG_MAX_ENTRIES) {
        this.entries.splice(0, this.entries.length - LOG_MAX_ENTRIES);
      }
    } catch (error) {
      // 读日志失败不影响主流程
    }
  }

  private scheduleFlush(): void {
    if (this.flushTimer !== -1) {
      return;
    }
    this.flushTimer = setTimeout(() => {
      this.flushTimer = -1;
      this.flush();
    }, FLUSH_DELAY_MS);
  }

  private flush(): void {
    const path: string = this.resolvePath();
    if (path.length === 0) {
      return;
    }
    try {
      let text: string = '';
      for (const entry of this.entries) {
        text += JSON.stringify(entry) + '\n';
      }
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, text);
      fs.fsyncSync(file.fd);
      fs.closeSync(file);
    } catch (error) {
      // 落盘失败只损失本地日志，不影响业务
    }
  }
}
