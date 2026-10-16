import { util } from '@kit.ArkTS';
import { CryptoService } from './CryptoService';
import { SettingsService } from './SettingsService';
import { SettingsModel } from '../model/SettingsModel';
import { KDF_ITERATIONS } from '../constants/CryptoConstants';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';

/** 应用锁 PIN 固定 6 位数字。 */
export const PIN_LENGTH: number = 6;

const PIN_SALT_LENGTH: number = 16;
const PIN_PATTERN: RegExp = /^[0-9]{6}$/;

/** 连续失败前 N 次不锁定；超过后按 30s 起指数退避，封顶 5 分钟。 */
const PIN_MAX_FREE_ATTEMPTS: number = 5;
const PIN_LOCKOUT_BASE_SECONDS: number = 30;
const PIN_LOCKOUT_MAX_SECONDS: number = 300;
const MS_PER_SECOND: number = 1000;

/**
 * 应用锁 PIN 的校验值管理：只保存 PBKDF2 派生结果与盐，不保存明文。
 *
 * 派生复用数据加密同款 PBKDF2-HMAC-SHA256 迭代次数，使离线爆破每个候选都要付出一次
 * 完整 KDF 的代价。校验值放在应用沙箱内的设置文件中，与密文同级。
 */
export class PinService {
  private cryptoService: CryptoService = new CryptoService();

  static isValidPin(pin: string): boolean {
    return PIN_PATTERN.test(pin);
  }

  /**
   * 锁是否真正可用：开启且校验值与盐都齐备。
   *
   * 齐备性检查是防呆：若写入过程中被中断（留下 enabled=true 但校验值为空），
   * 直接按锁定处理会把用户永久关在门外，这里选择降级为未锁定并记录错误。
   */
  isLockUsable(): boolean {
    const settings: SettingsModel = new SettingsService().getSettings();
    const usable: boolean = settings.appLockEnabled && settings.appLockPinHash.length > 0
      && settings.appLockPinSalt.length > 0;
    if (settings.appLockEnabled && !usable) {
      Logger.error('App lock enabled but PIN verifier is incomplete, treating as unlocked');
    }
    return usable;
  }

  /** 设置新 PIN 并启用应用锁（首次开启与更换 PIN 共用）。 */
  async setPin(pin: string): Promise<Result<void>> {
    if (!PinService.isValidPin(pin)) {
      return err<void>(AppErrorCode.INVALID_INPUT, $r('app.string.error_pin_format'));
    }
    const settingsService: SettingsService = new SettingsService();
    const settings: SettingsModel = settingsService.getSettings();
    const salt: Uint8Array = this.cryptoService.generateSalt();
    if (salt.length !== PIN_SALT_LENGTH) {
      return err<void>(AppErrorCode.ENCRYPT_FAILED, $r('app.string.error_salt_generation_failed'));
    }
    const hash: string = await this.derive(pin, salt);
    if (hash.length === 0) {
      return err<void>(AppErrorCode.ENCRYPT_FAILED, $r('app.string.error_pin_process_failed'));
    }
    settings.appLockEnabled = true;
    settings.appLockPinHash = hash;
    settings.appLockPinSalt = this.toBase64(salt);
    const saveResult: Result<void> = await settingsService.saveSettings(settings);
    if (!saveResult.success) {
      return saveResult;
    }
    await this.clearThrottle();
    Logger.info('App lock PIN stored');
    return ok(undefined);
  }

  /** 剩余锁定时长（秒）；0 表示未被限速。 */
  getLockoutRemainingSeconds(): number {
    const lockUntil: number = new SettingsService().getAppLockLockUntil();
    const remainingMs: number = lockUntil - Date.now();
    return remainingMs > 0 ? Math.ceil(remainingMs / MS_PER_SECOND) : 0;
  }

  /** 校验 PIN；错误返回 success=true 且 data=false，「限速锁定」与加密异常返回 success=false。 */
  async verify(pin: string): Promise<Result<boolean>> {
    const remaining: number = this.getLockoutRemainingSeconds();
    if (remaining > 0) {
      return err<boolean>(AppErrorCode.RATE_LIMITED, $r('app.string.pin_locked_retry', remaining));
    }
    const settingsService: SettingsService = new SettingsService();
    const settings: SettingsModel = settingsService.getSettings();
    if (settings.appLockPinHash.length === 0 || settings.appLockPinSalt.length === 0) {
      return err<boolean>(AppErrorCode.INVALID_KEY, $r('app.string.error_app_lock_not_initialized'));
    }
    let salt: Uint8Array;
    try {
      salt = this.fromBase64(settings.appLockPinSalt);
    } catch (error) {
      Logger.error('App lock salt decode failed');
      return err<boolean>(AppErrorCode.INVALID_KEY, $r('app.string.error_app_lock_data_corrupted'));
    }
    const hash: string = await this.derive(pin, salt);
    if (hash.length === 0) {
      return err<boolean>(AppErrorCode.DECRYPT_FAILED, $r('app.string.error_verify_failed_retry'));
    }
    const matched: boolean = hash === settings.appLockPinHash;
    if (matched) {
      await this.clearThrottle();
    } else {
      await this.registerFailure();
    }
    return ok(matched);
  }

  /** 关闭应用锁：必须先验过一次 PIN。 */
  async disable(pin: string): Promise<Result<void>> {
    const verifyResult: Result<boolean> = await this.verify(pin);
    if (!verifyResult.success) {
      return err<void>(verifyResult.error !== undefined ? verifyResult.error.code : AppErrorCode.UNKNOWN,
        verifyResult.error !== undefined ? verifyResult.error.message : $r('app.string.error_verify_failed'));
    }
    if (verifyResult.data !== true) {
      return err<void>(AppErrorCode.INVALID_KEY, $r('app.string.error_pin_incorrect'));
    }
    const settingsService: SettingsService = new SettingsService();
    const settings: SettingsModel = settingsService.getSettings();
    settings.appLockEnabled = false;
    settings.appLockPinHash = '';
    settings.appLockPinSalt = '';
    const saveResult: Promise<Result<void>> = settingsService.saveSettings(settings);
    Logger.info('App lock disabled');
    return saveResult;
  }

  private async registerFailure(): Promise<void> {
    const settingsService: SettingsService = new SettingsService();
    const failCount: number = settingsService.getAppLockFailCount() + 1;
    let lockUntil: number = 0;
    if (failCount >= PIN_MAX_FREE_ATTEMPTS) {
      const exponent: number = failCount - PIN_MAX_FREE_ATTEMPTS;
      const delaySeconds: number = Math.min(PIN_LOCKOUT_BASE_SECONDS * Math.pow(2, exponent), PIN_LOCKOUT_MAX_SECONDS);
      lockUntil = Date.now() + delaySeconds * MS_PER_SECOND;
    }
    await settingsService.saveAppLockThrottle(failCount, lockUntil);
  }

  private async clearThrottle(): Promise<void> {
    await new SettingsService().saveAppLockThrottle(0, 0);
  }

  private async derive(pin: string, salt: Uint8Array): Promise<string> {
    try {
      const key: Uint8Array = await this.cryptoService.deriveKey(pin, salt, KDF_ITERATIONS);
      return this.toBase64(key);
    } catch (error) {
      Logger.error('App lock PIN derivation failed');
      return '';
    }
  }

  private toBase64(bytes: Uint8Array): string {
    return new util.Base64Helper().encodeToStringSync(bytes, util.Type.BASIC);
  }

  private fromBase64(text: string): Uint8Array {
    return new util.Base64Helper().decodeSync(text, util.Type.BASIC);
  }
}
