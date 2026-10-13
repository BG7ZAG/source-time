import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { WebDavConfig } from '../model/WebDavConfig';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';
import { REMOTE_DATABASE_FILE_NAME } from '../constants/SyncConstants';
import { DEFAULT_WEBDAV_DIRECTORY } from '../constants/AppConstants';

const TIMEOUT_MS: number = 15000;
const URL_PATTERN: RegExp = /^https?:\/\//i;

export class WebDavService {
  async testConnection(config: WebDavConfig): Promise<Result<void>> {
    const urlResult: Result<string> = this.buildDirectoryUrl(config);
    if (!urlResult.success || urlResult.data === undefined) {
      return err<void>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    try {
      const request = http.createHttp();
      try {
        const response = await request.request(urlResult.data, {
          customMethod: 'PROPFIND',
          header: this.buildHeaders(config, true),
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        if (code >= 200 && code < 300) {
          return ok(undefined);
        }
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
      Logger.error('WebDAV test connection failed');
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, '无法连接 WebDAV 服务器');
    }
  }

  async upload(config: WebDavConfig, data: Uint8Array): Promise<Result<void>> {
    const urlResult: Result<string> = this.buildFileUrl(config);
    if (!urlResult.success || urlResult.data === undefined) {
      return err<void>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    // 确保目标目录存在（幂等）。否则首次上传会因目录不存在而 409/404 失败。
    const ensureDir: Result<void> = await this.createDirectory(config);
    if (!ensureDir.success) {
      return ensureDir;
    }
    try {
      const request = http.createHttp();
      try {
        const response = await request.request(urlResult.data, {
          method: http.RequestMethod.PUT,
          header: this.buildHeaders(config, false),
          extraData: this.toArrayBuffer(data),
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        if (code >= 200 && code < 300) {
          return ok(undefined);
        }
        return err<void>(this.mapStatus(code), this.statusMessage(code));
      } finally {
        request.destroy();
      }
    } catch (error) {
      Logger.error('WebDAV upload failed');
      return err<void>(AppErrorCode.WEBDAV_UPLOAD_FAILED, '上传失败');
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
          header: this.buildHeaders(config, false),
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        if (code >= 200 && code < 300) {
          return ok(undefined);
        }
        if (code === 405) {
          // 集合已存在或该路径已是集合：视为可用，无需创建
          return ok(undefined);
        }
        if (code === 401 || code === 403) {
          return err<void>(AppErrorCode.WEBDAV_AUTH_FAILED, this.statusMessage(code));
        }
        return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, this.statusMessage(code));
      } finally {
        request.destroy();
      }
    } catch (error) {
      Logger.error('WebDAV create directory failed');
      return err<void>(AppErrorCode.WEBDAV_CONNECTION_FAILED, '无法连接 WebDAV 服务器');
    }
  }

  async download(config: WebDavConfig): Promise<Result<Uint8Array>> {
    const urlResult: Result<string> = this.buildFileUrl(config);
    if (!urlResult.success || urlResult.data === undefined) {
      return err<Uint8Array>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    try {
      const request = http.createHttp();
      try {
        const response = await request.request(urlResult.data, {
          method: http.RequestMethod.GET,
          header: this.buildHeaders(config, false),
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: TIMEOUT_MS,
          readTimeout: TIMEOUT_MS,
          usingCache: false
        });
        const code: number = response.responseCode as number;
        if (code === 404) {
          // 尚未推送过任何备份：视为远端暂无数据，而非「路径不存在」
          return err<Uint8Array>(AppErrorCode.WEBDAV_INVALID_REMOTE_FILE, '远端暂无备份数据');
        }
        if (code < 200 || code >= 300) {
          return err<Uint8Array>(this.mapStatus(code), this.statusMessage(code));
        }
        const result: string | Object | ArrayBuffer = response.result;
        if (result instanceof ArrayBuffer) {
          return ok(new Uint8Array(result));
        }
        return err<Uint8Array>(AppErrorCode.WEBDAV_INVALID_REMOTE_FILE, '远程数据格式无效');
      } finally {
        request.destroy();
      }
    } catch (error) {
      Logger.error('WebDAV download failed');
      return err<Uint8Array>(AppErrorCode.WEBDAV_DOWNLOAD_FAILED, '下载失败');
    }
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

  private buildFileUrl(config: WebDavConfig): Result<string> {
    const directoryResult: Result<string> = this.buildDirectoryUrl(config);
    if (!directoryResult.success || directoryResult.data === undefined) {
      return err<string>(AppErrorCode.WEBDAV_INVALID_URL, '服务器地址无效');
    }
    const directory: string = directoryResult.data;
    const normalizedDirectory: string = directory.endsWith('/') ? directory : directory + '/';
    return ok(normalizedDirectory + REMOTE_DATABASE_FILE_NAME);
  }

  private joinUrl(base: string, path: string): string {
    const trimmedBase: string = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    const encodedPath: string = encodeURI(path);
    const normalizedPath: string = encodedPath.startsWith('/') ? encodedPath : '/' + encodedPath;
    return trimmedBase + normalizedPath;
  }

  private buildHeaders(config: WebDavConfig, isPropfind: boolean): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Authorization'] = 'Basic ' + this.encodeBasicAuth(config.username, config.password);
    if (isPropfind) {
      headers['Depth'] = '0';
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
