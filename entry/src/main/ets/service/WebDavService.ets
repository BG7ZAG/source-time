import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { WebDavConfig } from '../model/WebDavConfig';
import { RemoteBackup } from '../model/RemoteBackup';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';
import { nowMilliseconds } from '../utils/TimeUtils';
import { isBackupFileName, parseBackupTimestamp } from '../constants/SyncConstants';
import { DEFAULT_WEBDAV_DIRECTORY } from '../constants/AppConstants';

const TIMEOUT_MS: number = 15000;
const URL_PATTERN: RegExp = /^https?:\/\//i;

/** PROPFIND 响应里单个 <response> 块（兼容带命名空间前缀的标签，如 D:response）。 */
const RESPONSE_BLOCK_PATTERN: RegExp = /<(?:[\w-]+:)?response\b[^>]*>[\s\S]*?<\/(?:[\w-]+:)?response>/gi;
const HREF_PATTERN: RegExp = /<(?:[\w-]+:)?href\b[^>]*>([\s\S]*?)<\/(?:[\w-]+:)?href>/i;
const LASTMODIFIED_PATTERN: RegExp =
  /<(?:[\w-]+:)?getlastmodified\b[^>]*>([\s\S]*?)<\/(?:[\w-]+:)?getlastmodified>/i;
const CONTENTLENGTH_PATTERN: RegExp =
  /<(?:[\w-]+:)?getcontentlength\b[^>]*>([\s\S]*?)<\/(?:[\w-]+:)?getcontentlength>/i;

export class WebDavService {
  async testConnection(config: WebDavConfig): Promise<Result<void>> {
    const urlResult: Result<string> = this.buildDirectoryUrl(config);
    if (!urlResult.success || urlResult.data === undefined) {
      return err<void>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    const startedAt: number = nowMilliseconds();
    Logger.info('WebDAV PROPFIND ' + urlResult.data, 'WebDAV');
    try {
      const request = http.createHttp();
      try {
        const response = await request.request(urlResult.data, {
          customMethod: 'PROPFIND',
          header: this.buildHeaders(config, '0'),
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        const cost: number = nowMilliseconds() - startedAt;
        if (code >= 200 && code < 300) {
          Logger.info('WebDAV PROPFIND ok: status=' + code + ' cost=' + cost + 'ms', 'WebDAV');
          return ok(undefined);
        }
        Logger.warn('WebDAV PROPFIND rejected: status=' + code + ' cost=' + cost + 'ms body='
          + this.responseSnippet(response), 'WebDAV');
        // 目录不存在：WebDAV 同步目录本应由客户端建立，自动 MKCOL 逐级创建后再验证，
        // 避免对尚未创建的目标目录误报「路径不存在」。
        if (code === 404) {
          return await this.createDirectory(config);
        }
        return err<void>(this.mapStatus(code), this.statusMessage(code));
      } finally {
        request.destroy();
      }
    } catch (error) {
      Logger.error('WebDAV PROPFIND error after ' + (nowMilliseconds() - startedAt) + 'ms: url='
        + urlResult.data, 'WebDAV');
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, '无法连接 WebDAV 服务器');
    }
  }

  async upload(config: WebDavConfig, fileName: string, data: Uint8Array): Promise<Result<void>> {
    const urlResult: Result<string> = this.buildFileUrl(config, fileName);
    if (!urlResult.success || urlResult.data === undefined) {
      return err<void>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    // 确保目标目录存在（幂等）。否则首次上传会因目录不存在而 409/404 失败。
    const ensureDir: Result<void> = await this.createDirectory(config);
    if (!ensureDir.success) {
      return ensureDir;
    }
    const startedAt: number = nowMilliseconds();
    Logger.info('WebDAV PUT ' + urlResult.data + ' bytes=' + data.length, 'WebDAV');
    try {
      const request = http.createHttp();
      try {
        const response = await request.request(urlResult.data, {
          method: http.RequestMethod.PUT,
          header: this.buildHeaders(config, ''),
          extraData: this.toArrayBuffer(data),
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        const cost: number = nowMilliseconds() - startedAt;
        if (code >= 200 && code < 300) {
          Logger.info('WebDAV PUT ok: status=' + code + ' bytes=' + data.length + ' cost=' + cost + 'ms', 'WebDAV');
          return ok(undefined);
        }
        Logger.warn('WebDAV PUT rejected: status=' + code + ' bytes=' + data.length + ' cost=' + cost
          + 'ms body=' + this.responseSnippet(response), 'WebDAV');
        return err<void>(this.mapStatus(code), this.statusMessage(code));
      } finally {
        request.destroy();
      }
    } catch (error) {
      Logger.error('WebDAV PUT error after ' + (nowMilliseconds() - startedAt) + 'ms: url=' + urlResult.data, 'WebDAV');
      return err<void>(AppErrorCode.WEBDAV_UPLOAD_FAILED, '上传失败（网络异常或服务器无响应）');
    }
  }

  /**
   * 确保远程同步目录存在：从 baseUrl 起，对 remotePath 逐级执行 MKCOL。
   *
   * 逐级创建可兼容多级目录（如 /a/b/c/）以及父目录尚未建立的情况——
   * 直接对完整路径发一次 MKCOL 会因父目录缺失返回 409，导致误报失败。
   * 集合已存在（405）视为成功，因此该方法是幂等的，可安全地在上传/测试连接前调用。
   */
  async createDirectory(config: WebDavConfig): Promise<Result<void>> {
    const base: string = config.baseUrl.trim();
    if (base.length === 0 || !URL_PATTERN.test(base)) {
      return err<void>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    const segments: string[] = this.buildRemoteSegments(config);
    let current: string = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    for (let i = 0; i < segments.length; i++) {
      current = current + '/' + encodeURI(segments[i]);
      const result: Result<void> = await this.mkcol(current, config);
      if (!result.success) {
        return result;
      }
    }
    return ok(undefined);
  }

  /** 将 remotePath 拆分为非空路径段；为空时回退到默认同步目录。 */
  private buildRemoteSegments(config: WebDavConfig): string[] {
    let remotePath: string = config.remotePath.trim();
    if (remotePath.length === 0) {
      remotePath = DEFAULT_WEBDAV_DIRECTORY;
    }
    const segments: string[] = [];
    const parts: string[] = remotePath.split('/');
    for (let i = 0; i < parts.length; i++) {
      const part: string = parts[i].trim();
      if (part.length > 0) {
        segments.push(part);
      }
    }
    return segments;
  }

  /** 发送一次 MKCOL 请求创建集合。集合已存在（405）视为成功。 */
  private async mkcol(url: string, config: WebDavConfig): Promise<Result<void>> {
    try {
      const request = http.createHttp();
      try {
        const response = await request.request(url, {
          customMethod: 'MKCOL',
          header: this.buildHeaders(config, ''),
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        if (code >= 200 && code < 300) {
          Logger.debug('WebDAV MKCOL ok: status=' + code + ' url=' + url, 'WebDAV');
          return ok(undefined);
        }
        if (code === 405) {
          // 集合已存在或该路径已是集合：视为可用，无需创建
          Logger.debug('WebDAV MKCOL exists: status=' + code + ' url=' + url, 'WebDAV');
          return ok(undefined);
        }
        if (code === 401 || code === 403) {
          Logger.error('WebDAV MKCOL auth failed: status=' + code + ' url=' + url, 'WebDAV');
          return err<void>(AppErrorCode.WEBDAV_AUTH_FAILED, this.statusMessage(code));
        }
        Logger.warn('WebDAV MKCOL rejected: status=' + code + ' url=' + url + ' body='
          + this.responseSnippet(response), 'WebDAV');
        return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, this.statusMessage(code));
      } finally {
        request.destroy();
      }
    } catch (error) {
      Logger.error('WebDAV MKCOL error: url=' + url, 'WebDAV');
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, '无法连接 WebDAV 服务器');
    }
  }

  async download(config: WebDavConfig, fileName: string): Promise<Result<Uint8Array>> {
    const urlResult: Result<string> = this.buildFileUrl(config, fileName);
    if (!urlResult.success || urlResult.data === undefined) {
      return err<Uint8Array>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    const startedAt: number = nowMilliseconds();
    Logger.info('WebDAV GET ' + urlResult.data, 'WebDAV');
    try {
      const request = http.createHttp();
      try {
        const response = await request.request(urlResult.data, {
          method: http.RequestMethod.GET,
          header: this.buildHeaders(config, ''),
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        const cost: number = nowMilliseconds() - startedAt;
        if (code === 404) {
          // 尚未推送过任何备份：视为远端暂无数据，而非「路径不存在」
          Logger.warn('WebDAV GET rejected: status=404（远端暂无备份） cost=' + cost + 'ms', 'WebDAV');
          return err<Uint8Array>(AppErrorCode.WEBDAV_INVALID_REMOTE_FILE, '远端暂无备份数据');
        }
        if (code < 200 || code >= 300) {
          Logger.warn('WebDAV GET rejected: status=' + code + ' cost=' + cost + 'ms body='
            + this.responseSnippet(response), 'WebDAV');
          return err<Uint8Array>(this.mapStatus(code), this.statusMessage(code));
        }
        const result: string | Object | ArrayBuffer = response.result;
        if (result instanceof ArrayBuffer) {
          const bytes: Uint8Array = new Uint8Array(result);
          Logger.info('WebDAV GET ok: status=' + code + ' bytes=' + bytes.length + ' cost=' + cost + 'ms', 'WebDAV');
          return ok(bytes);
        }
        Logger.warn('WebDAV GET unexpected payload: status=' + code + ' cost=' + cost + 'ms', 'WebDAV');
        return err<Uint8Array>(AppErrorCode.WEBDAV_INVALID_REMOTE_FILE, '远程数据格式无效');
      } finally {
        request.destroy();
      }
    } catch (error) {
      Logger.error('WebDAV GET error after ' + (nowMilliseconds() - startedAt) + 'ms: url=' + urlResult.data, 'WebDAV');
      return err<Uint8Array>(AppErrorCode.WEBDAV_DOWNLOAD_FAILED, '下载失败（网络异常或服务器无响应）');
    }
  }

  /**
   * 删除远端指定文件（仅用于清理本应用生成的旧快照）。
   * 404 视为删除成功（文件已不存在，保持幂等）。
   */
  async delete(config: WebDavConfig, fileName: string): Promise<Result<void>> {
    const urlResult: Result<string> = this.buildFileUrl(config, fileName);
    if (!urlResult.success || urlResult.data === undefined) {
      return err<void>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    const startedAt: number = nowMilliseconds();
    Logger.info('WebDAV DELETE ' + urlResult.data, 'WebDAV');
    try {
      const request = http.createHttp();
      try {
        const response = await request.request(urlResult.data, {
          method: http.RequestMethod.DELETE,
          header: this.buildHeaders(config, ''),
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        const cost: number = nowMilliseconds() - startedAt;
        if (code >= 200 && code < 300) {
          Logger.info('WebDAV DELETE ok: status=' + code + ' cost=' + cost + 'ms', 'WebDAV');
          return ok(undefined);
        }
        if (code === 404) {
          Logger.info('WebDAV DELETE ok (already gone): status=404', 'WebDAV');
          return ok(undefined);
        }
        Logger.warn('WebDAV DELETE rejected: status=' + code + ' cost=' + cost + 'ms body='
          + this.responseSnippet(response), 'WebDAV');
        return err<void>(this.mapStatus(code), this.statusMessage(code));
      } finally {
        request.destroy();
      }
    } catch (error) {
      Logger.error('WebDAV DELETE error after ' + (nowMilliseconds() - startedAt) + 'ms: url='
        + urlResult.data, 'WebDAV');
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, '删除失败（网络异常或服务器无响应）');
    }
  }

  /**
   * 列出同步目录下的备份文件（PROPFIND Depth: 1）。
   *
   * 只返回本应用生成的时间戳快照 sourcetime-*.enc；
   * 目录里的其它文件一律忽略（不误列、不误删用户数据）。结果按时间倒序（最新在前）。
   */
  async list(config: WebDavConfig): Promise<Result<RemoteBackup[]>> {
    const urlResult: Result<string> = this.buildDirectoryUrl(config);
    if (!urlResult.success || urlResult.data === undefined) {
      return err<RemoteBackup[]>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    const startedAt: number = nowMilliseconds();
    Logger.info('WebDAV PROPFIND (list) ' + urlResult.data, 'WebDAV');
    try {
      const request = http.createHttp();
      try {
        const response = await request.request(urlResult.data, {
          customMethod: 'PROPFIND',
          header: this.buildHeaders(config, '1'),
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        const cost: number = nowMilliseconds() - startedAt;
        if (code < 200 || code >= 300) {
          Logger.warn('WebDAV PROPFIND (list) rejected: status=' + code + ' cost=' + cost + 'ms body='
            + this.responseSnippet(response), 'WebDAV');
          return err<RemoteBackup[]>(this.mapStatus(code), this.statusMessage(code));
        }
        const xml: string = `${response.result}`;
        const backups: RemoteBackup[] = this.parseBackupList(xml);
        Logger.info('WebDAV PROPFIND (list) ok: status=' + code + ' files=' + backups.length
          + ' cost=' + cost + 'ms', 'WebDAV');
        return ok(backups);
      } finally {
        request.destroy();
      }
    } catch (error) {
      Logger.error('WebDAV PROPFIND (list) error after ' + (nowMilliseconds() - startedAt) + 'ms: url='
        + urlResult.data, 'WebDAV');
      return err<RemoteBackup[]>(AppErrorCode.WEBDAV_CONNECTION_FAILED, '无法连接 WebDAV 服务器');
    }
  }

  /** 解析 PROPFIND 响应 XML，抽出本应用的备份文件并按时间倒序排列。 */
  private parseBackupList(xml: string): RemoteBackup[] {
    const backups: RemoteBackup[] = [];
    const blocks: RegExpMatchArray | null = xml.match(RESPONSE_BLOCK_PATTERN);
    if (blocks === null) {
      return backups;
    }
    for (const block of blocks) {
      const name: string = this.fileNameFromHref(this.extractHref(block));
      // 只认带日期时间的本应用快照，其它文件（含第三方文件）一律忽略
      if (!isBackupFileName(name)) {
        continue;
      }
      backups.push({
        name: name,
        lastModified: this.parseHttpDate(this.extractLastModified(block)),
        size: this.toPositiveNumber(this.extractContentLength(block))
      });
    }
    backups.sort((left: RemoteBackup, right: RemoteBackup): number => {
      return this.backupRank(right) - this.backupRank(left);
    });
    return backups;
  }

  /** 排序权重：优先采用服务端最后修改时间，缺失时回退到文件名内的时间戳。 */
  private backupRank(item: RemoteBackup): number {
    if (item.lastModified > 0) {
      return item.lastModified;
    }
    return parseBackupTimestamp(item.name);
  }

  /** 从单个 <response> 块中抽取 href（去掉查询串并做 URL 解码）。 */
  private extractHref(block: string): string {
    const match: RegExpMatchArray | null = block.match(HREF_PATTERN);
    if (match === null) {
      return '';
    }
    return this.decodeXmlText(match[1]).trim();
  }

  /** 从单个 <response> 块中抽取最后修改时间（RFC1123 文本）。 */
  private extractLastModified(block: string): string {
    const match: RegExpMatchArray | null = block.match(LASTMODIFIED_PATTERN);
    return match === null ? '' : match[1].trim();
  }

  /** 从单个 <response> 块中抽取内容长度（十进制文本）。 */
  private extractContentLength(block: string): string {
    const match: RegExpMatchArray | null = block.match(CONTENTLENGTH_PATTERN);
    return match === null ? '' : match[1].trim();
  }

  /** 从 href 中取出文件名；目录自身（以 / 结尾）返回空串。 */
  private fileNameFromHref(href: string): string {
    let path: string = href;
    const queryIndex: number = path.indexOf('?');
    if (queryIndex >= 0) {
      path = path.substring(0, queryIndex);
    }
    const slashIndex: number = path.lastIndexOf('/');
    let name: string = slashIndex >= 0 ? path.substring(slashIndex + 1) : path;
    if (name.length === 0) {
      return '';
    }
    try {
      name = decodeURIComponent(name);
    } catch (error) {
      // 名称非标准编码时保持原样
    }
    return name;
  }

  /** 解析 HTTP 日期（如 Wed, 14 Oct 2026 07:45:12 GMT）；无法解析返回 0。 */
  private parseHttpDate(text: string): number {
    if (text.length === 0) {
      return 0;
    }
    const parsed: number = new Date(text).getTime();
    return Number.isNaN(parsed) ? 0 : parsed;
  }

  /** 解析非负整数；非法输入返回 0。 */
  private toPositiveNumber(text: string): number {
    if (text.length === 0) {
      return 0;
    }
    const parsed: number = Number(text);
    return Number.isNaN(parsed) || parsed < 0 ? 0 : parsed;
  }

  /** 反转义 XML 实体（文件名里可能出现 & 等）。 */
  private decodeXmlText(text: string): string {
    return text.replace(/</g, '<').replace(/>/g, '>').replace(/"/g, '"')
      .replace(/'/g, "'").replace(/&/g, '&');
  }

  private buildDirectoryUrl(config: WebDavConfig): Result<string> {
    const base: string = config.baseUrl.trim();
    if (base.length === 0 || !URL_PATTERN.test(base)) {
      return err<string>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    let remotePath: string = config.remotePath.trim();
    if (remotePath.length === 0) {
      remotePath = DEFAULT_WEBDAV_DIRECTORY;
    }
    return ok(this.joinUrl(base, remotePath));
  }

  private buildFileUrl(config: WebDavConfig, fileName: string): Result<string> {
    const directoryResult: Result<string> = this.buildDirectoryUrl(config);
    if (!directoryResult.success || directoryResult.data === undefined) {
      return err<string>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    const directory: string = directoryResult.data;
    const normalizedDirectory: string = directory.endsWith('/') ? directory : directory + '/';
    return ok(normalizedDirectory + encodeURI(fileName));
  }

  private joinUrl(base: string, path: string): string {
    const trimmedBase: string = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    const encodedPath: string = encodeURI(path);
    const normalizedPath: string = encodedPath.startsWith('/') ? encodedPath : '/' + encodedPath;
    return trimmedBase + normalizedPath;
  }

  /**
   * 组装请求头。depth 为 '' 时不发送 Depth（PUT/GET/MKCOL 不需要）；
   * PROPFIND 需要它：'0' 只查自身，'1' 列出目录下一级（用于枚举备份文件）。
   */
  private buildHeaders(config: WebDavConfig, depth: string): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Authorization'] = 'Basic ' + this.encodeBasicAuth(config.username, config.password);
    if (depth.length > 0) {
      headers['Depth'] = depth;
    }
    return headers;
  }

  private encodeBasicAuth(username: string, password: string): string {
    const raw: string = username + ':' + password;
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(raw);
    return new util.Base64Helper().encodeToStringSync(bytes, util.Type.BASIC);
  }

  private toArrayBuffer(data: Uint8Array): ArrayBuffer {
    const copy: Uint8Array = data.slice(0, data.length);
    return copy.buffer;
  }

  /**
   * 截取响应体片段用于日志（仅错误路径调用）。
   *
   * WebDAV 的错误响应多为 XML/纯文本（如 401 的鉴权提示、500 的服务器错误详情），
   * 记录前 200 字符能直接定位「为什么被拒」；二进制或空响应退化为空串。
   * 响应体不会包含密码——鉴权信息在请求头，而请求头从不入日志。
   */
  private responseSnippet(response: http.HttpResponse): string {
    const text: string = `${response.result}`;
    if (text.length <= 200) {
      return text;
    }
    return text.substring(0, 200) + '...';
  }

  private mapStatus(code: number): AppErrorCode {
    if (code === 401 || code === 403) {
      return AppErrorCode.WEBDAV_AUTH_FAILED;
    }
    if (code === 404) {
      return AppErrorCode.WEBDAV_CONNECTION_FAILED;
    }
    if (code >= 500) {
      return AppErrorCode.WEBDAV_CONNECTION_FAILED;
    }
    return AppErrorCode.WEBDAV_CONNECTION_FAILED;
  }

  private statusMessage(code: number): string {
    if (code === 401) {
      return '认证失败，请检查用户名或密码';
    }
    if (code === 403) {
      return '权限不足，无法访问该目录';
    }
    if (code === 404) {
      return '远程路径不存在';
    }
    if (code === 409) {
      return '上级目录不存在，请检查服务器地址与同步目录层级';
    }
    if (code === 408) {
      return '请求超时';
    }
    if (code === 429) {
      return '请求过于频繁，请稍后再试';
    }
    if (code >= 500) {
      return '服务器错误';
    }
    return '请求失败（状态码 ' + code + '）';
  }
}
