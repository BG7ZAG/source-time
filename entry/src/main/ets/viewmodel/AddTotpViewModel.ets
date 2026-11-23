import { TotpItem, TotpAlgorithm } from '../model/TotpItem';
import { DatabaseModel } from '../model/DatabaseModel';
import { SyncReason } from '../model/SyncModel';
import { LocalRepository } from '../repository/LocalRepository';
import { OtpParser, ParsedOtpUri } from '../service/OtpParser';
import { SyncService } from '../service/SyncService';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';
import { generateUuid } from '../utils/UUIDUtils';
import { nowMilliseconds } from '../utils/TimeUtils';
import { isValidBase32, normalizeBase32 } from '../utils/Base32Utils';
import { DEFAULT_TOTP_ALGORITHM, DEFAULT_TOTP_DIGITS, DEFAULT_TOTP_PERIOD } from '../constants/AppConstants';

export type AddMode = 'SCAN' | 'MANUAL';

export class AddTotpViewModel {
  mode: AddMode = 'MANUAL';
  issuer: string = '';
  account: string = '';
  secret: string = '';
  algorithm: TotpAlgorithm = DEFAULT_TOTP_ALGORITHM;
  digits: 6 | 8 = DEFAULT_TOTP_DIGITS;
  period: number = DEFAULT_TOTP_PERIOD;
  saving: boolean = false;
  /** 最近一次失败的用户可读文案：Resource 走多语言资源。 */
  error: ResourceStr = '';

  private repository: LocalRepository = new LocalRepository();
  private parser: OtpParser = new OtpParser();
  private encryptionSecret: string = '';

  setEncryptionSecret(secret: string): void {
    this.encryptionSecret = secret;
  }

  parseUri(uri: string): Result<ParsedOtpUri> {
    return this.parser.parseUri(uri);
  }

  applyParsed(parsed: ParsedOtpUri): void {
    this.issuer = parsed.issuer;
    this.account = parsed.account;
    this.secret = parsed.secret;
    this.algorithm = parsed.algorithm;
    this.digits = parsed.digits;
    this.period = parsed.period;
  }

  async save(): Promise<Result<void>> {
    this.error = '';
    const issuer: string = this.issuer.trim();
    const account: string = this.account.trim();
    const secret: string = normalizeBase32(this.secret);
    if (secret.length === 0) {
      this.error = $r('app.string.error_secret_required');
      return err<void>(AppErrorCode.INVALID_INPUT, this.error);
    }
    if (!isValidBase32(secret)) {
      this.error = $r('app.string.error_secret_format');
      return err<void>(AppErrorCode.INVALID_TOTP_SECRET, this.error);
    }
    if (this.digits !== 6 && this.digits !== 8) {
      this.error = $r('app.string.error_digits_invalid');
      return err<void>(AppErrorCode.INVALID_TOTP_CONFIG, this.error);
    }
    if (this.period <= 0) {
      this.error = $r('app.string.error_period_invalid');
      return err<void>(AppErrorCode.INVALID_TOTP_CONFIG, this.error);
    }
    if (this.encryptionSecret.length === 0) {
      // 密钥由 KeyStoreService 在启动时自动取回；为空说明系统安全存储里没有可用密钥
      this.error = $r('app.string.error_encryption_key_unavailable');
      return err<void>(AppErrorCode.KEY_REQUIRED, this.error);
    }
    let db: DatabaseModel | null = this.repository.getDatabase();
    if (db === null) {
      const loadResult: Result<DatabaseModel> = await this.repository.load(this.encryptionSecret);
      if (!loadResult.success || loadResult.data === undefined) {
        // 回流底层真实原因（如「无法解密数据，请确认加密密钥是否正确」），避免笼统的「数据加载失败」无从定位
        this.error = loadResult.error !== undefined ? loadResult.error.message : $r('app.string.error_data_load_failed');
        return err<void>(AppErrorCode.STORAGE_WRITE_FAILED, this.error);
      }
      db = loadResult.data;
    }
    this.saving = true;
    try {
      const now: number = nowMilliseconds();
      const item: TotpItem = {
        id: generateUuid(),
        issuer: issuer,
        account: account,
        secret: secret,
        algorithm: this.algorithm,
        digits: this.digits,
        period: this.period,
        createdAt: now,
        updatedAt: now
      };
      const nextItems: TotpItem[] = db.items.slice();
      nextItems.push(item);
      const nextDb: DatabaseModel = {
        version: db.version,
        revision: db.revision + 1,
        updatedAt: now,
        deviceId: db.deviceId,
        items: nextItems
      };
      const result: Result<void> = await this.repository.save(nextDb, this.encryptionSecret);
      if (!result.success) {
        this.error = result.error !== undefined ? result.error.message : $r('app.string.error_save_failed');
        return result;
      }
      Logger.info('TOTP added: id=' + item.id);
      SyncService.getInstance().enqueuePush(SyncReason.ADD_TOTP);
      return ok(undefined);
    } finally {
      this.saving = false;
    }
  }
}
