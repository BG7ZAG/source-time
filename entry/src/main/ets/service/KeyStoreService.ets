import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../utils/Logger';

const KEY_ALIAS: string = 'sourcetime_encryption_secret_v1';
const KEY_LABEL: string = 'SourceTime encryption secret';
const MAX_SECRET_BYTES: number = 1024;
const NOT_FOUND_CODE: number = 24000002;

/**
 * 用系统关键资产存储（Asset Store Kit）保管用户的加密密钥。
 *
 * 加密只作用于本地存储文件与 WebDAV 上传的密文，所以启动时静默取回密钥即可自动解密，
 * 不需要在进入应用时要求用户输入。密钥由系统加密托管在应用沙箱之外，不落明文盘。
 */
export class KeyStoreService {
  private encode(value: string): Uint8Array {
    return new util.TextEncoder().encodeInto(value);
  }

  private decode(bytes: Uint8Array): string {
    return util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(bytes, { stream: false });
  }

  private alias(): Uint8Array {
    return this.encode(KEY_ALIAS);
  }

  /** 保存（覆盖）加密密钥，失败返回 false，调用方需要提示用户。 */
  async save(secret: string): Promise<boolean> {
    const secretBytes: Uint8Array = this.encode(secret);
    if (secretBytes.length === 0 || secretBytes.length > MAX_SECRET_BYTES) {
      Logger.error('KeyStore save skipped: secret length out of range');
      return false;
    }
    // 先删后加，避免别名冲突（24000003 / 24000002）
    await this.remove();
    const attrs: asset.AssetMap = new Map();
    attrs.set(asset.Tag.ALIAS, this.alias());
    attrs.set(asset.Tag.SECRET, secretBytes);
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    attrs.set(asset.Tag.DATA_LABEL_NORMAL_1, this.encode(KEY_LABEL));
    try {
      await asset.add(attrs);
      Logger.info('Encryption secret stored in asset store');
      return true;
    } catch (error) {
      const err = error as BusinessError;
      Logger.error('KeyStore save failed, code=' + err.code);
      return false;
    }
  }

  /** 读取加密密钥，不存在或失败时返回空串。 */
  async load(): Promise<string> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias());
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results: asset.AssetMap[] = await asset.query(query);
      if (results === undefined || results.length === 0) {
        return '';
      }
      const value: Uint8Array | undefined = results[0].get(asset.Tag.SECRET) as Uint8Array | undefined;
      if (value === undefined) {
        return '';
      }
      return this.decode(value);
    } catch (error) {
      const err = error as BusinessError;
      if (err.code !== NOT_FOUND_CODE) {
        Logger.error('KeyStore load failed, code=' + err.code);
      }
      return '';
    }
  }

  async remove(): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias());
    try {
      await asset.remove(query);
    } catch (error) {
      const err = error as BusinessError;
      if (err.code !== NOT_FOUND_CODE) {
        Logger.error('KeyStore remove failed, code=' + err.code);
      }
    }
  }
}
