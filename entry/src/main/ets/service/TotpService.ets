import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Logger } from '../utils/Logger';
import { base32Decode, isValidBase32, normalizeBase32 } from '../utils/Base32Utils';
import { nowSeconds } from '../utils/TimeUtils';
import { TotpAlgorithm } from '../model/TotpItem';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';

export interface GenerateTotpOptions {
  secret: string;
  algorithm: TotpAlgorithm;
  digits: 6 | 8;
  period: number;
  timestamp?: number;
}

export class TotpService {
  generate(options: GenerateTotpOptions): Result<string> {
    try {
      const normalized: string = normalizeBase32(options.secret);
      if (!isValidBase32(normalized)) {
        return err<string>(AppErrorCode.INVALID_TOTP_SECRET, '密钥格式无效');
      }
      if (options.period <= 0) {
        return err<string>(AppErrorCode.INVALID_TOTP_CONFIG, '周期无效');
      }
      const keyBytes: Uint8Array = base32Decode(normalized);
      const timestamp: number = options.timestamp !== undefined ? options.timestamp : nowSeconds();
      const counter: number = Math.floor(timestamp / options.period);
      const counterBytes: Uint8Array = this.counterToBytes(counter);
      const hash: Uint8Array = this.hmac(options.algorithm, keyBytes, counterBytes);
      const code: string = this.truncate(hash, options.digits);
      return ok(code);
    } catch (error) {
      Logger.error('TOTP generate failed');
      return err<string>(AppErrorCode.INVALID_TOTP_CONFIG, '验证码生成失败');
    }
  }

  private counterToBytes(counter: number): Uint8Array {
    const bytes: Uint8Array = new Uint8Array(8);
    let value: number = counter;
    for (let i = 7; i >= 0; i--) {
      bytes[i] = value % 256;
      value = Math.floor(value / 256);
    }
    return bytes;
  }

  private hmac(algorithm: TotpAlgorithm, key: Uint8Array, message: Uint8Array): Uint8Array {
    const mac = cryptoFramework.createMac(algorithm);
    const keyGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
    const symKey = keyGenerator.convertKeySync({ data: key });
    mac.initSync(symKey);
    mac.updateSync({ data: message });
    return mac.doFinalSync().data;
  }

  private truncate(hash: Uint8Array, digits: number): string {
    const offset: number = hash[hash.length - 1] & 0x0F;
    const binary: number = ((hash[offset] & 0x7F) << 24)
      | ((hash[offset + 1] & 0xFF) << 16)
      | ((hash[offset + 2] & 0xFF) << 8)
      | (hash[offset + 3] & 0xFF);
    const modulo: number = Math.pow(10, digits);
    const otp: number = binary % modulo;
    let text: string = otp.toString();
    while (text.length < digits) {
      text = '0' + text;
    }
    return text;
  }
}
