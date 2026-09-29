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
