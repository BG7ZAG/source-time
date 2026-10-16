import { TotpAlgorithm } from '../model/TotpItem';
import { isValidBase32, normalizeBase32 } from '../utils/Base32Utils';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { DEFAULT_TOTP_ALGORITHM, DEFAULT_TOTP_DIGITS, DEFAULT_TOTP_PERIOD, MAX_TOTP_PERIOD } from '../constants/AppConstants';

export interface ParsedOtpUri {
  issuer: string;
  account: string;
  secret: string;
  algorithm: TotpAlgorithm;
  digits: 6 | 8;
  period: number;
}

const SCHEME_REGEX: RegExp = /^otpauth:\/\/totp\//i;
const VALID_ALGORITHMS: string[] = ['SHA1', 'SHA256', 'SHA512'];

export class OtpParser {
  parseUri(uri: string): Result<ParsedOtpUri> {
    try {
      if (uri === undefined || uri === null || uri.trim().length === 0) {
        return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_URI, $r('app.string.error_qr_content_invalid'));
      }
      const trimmed: string = uri.trim();
      const schemeMatch: RegExpMatchArray | null = trimmed.match(SCHEME_REGEX);
      if (schemeMatch === null) {
        return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_URI, $r('app.string.error_not_totp_qr'));
      }
      const labelAndQuery: string = trimmed.substring(schemeMatch[0].length);
      let label: string = labelAndQuery;
      let query: string = '';
      const queryIndex: number = labelAndQuery.indexOf('?');
      if (queryIndex >= 0) {
        label = labelAndQuery.substring(0, queryIndex);
        query = labelAndQuery.substring(queryIndex + 1);
      }
      const params: Map<string, string> = this.parseQuery(query);
      let issuer: string = '';
      let account: string = '';
      const decodedLabel: string = decodeURIComponent(label);
      const colonIndex: number = decodedLabel.indexOf(':');
      if (colonIndex >= 0) {
        issuer = decodedLabel.substring(0, colonIndex).trim();
        account = decodedLabel.substring(colonIndex + 1).trim();
      } else {
        account = decodedLabel.trim();
      }
      const issuerParam: string | undefined = params.get('issuer');
      if (issuerParam !== undefined && issuerParam.length > 0) {
        issuer = issuerParam;
      }
      const secretParam: string | undefined = params.get('secret');
      if (secretParam === undefined || !isValidBase32(secretParam)) {
        return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_SECRET, $r('app.string.error_secret_format'));
      }
      const algorithm: TotpAlgorithm | null = this.parseAlgorithm(params.get('algorithm'));
      if (algorithm === null) {
        return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_CONFIG, $r('app.string.error_qr_algorithm_unsupported'));
      }
      const digits: 6 | 8 | null = this.parseDigits(params.get('digits'));
      if (digits === null) {
        return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_CONFIG, $r('app.string.error_qr_digits_unsupported'));
      }
      const period: number | null = this.parsePeriod(params.get('period'));
      if (period === null) {
        return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_CONFIG, $r('app.string.error_qr_period_invalid'));
      }
      const parsed: ParsedOtpUri = {
        issuer: issuer,
        account: account,
        secret: normalizeBase32(secretParam),
        algorithm: algorithm,
        digits: digits,
        period: period
      };
      return ok(parsed);
    } catch (error) {
      return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_URI, $r('app.string.error_qr_parse_failed'));
    }
  }

  private parseQuery(query: string): Map<string, string> {
    const params: Map<string, string> = new Map<string, string>();
    if (query.length === 0) {
      return params;
    }
    const pairs: string[] = query.split('&');
    for (let i = 0; i < pairs.length; i++) {
      const pair: string = pairs[i];
      if (pair.length === 0) {
        continue;
      }
      const eqIndex: number = pair.indexOf('=');
      if (eqIndex < 0) {
        // 参数名按 RFC 6238 生态的惯例大小写不敏感：Google/Microsoft 生成的 URI 里出现过 Secret=、Algorithm=
        params.set(decodeURIComponent(pair).toLowerCase(), '');
      } else {
        const key: string = decodeURIComponent(pair.substring(0, eqIndex)).toLowerCase();
        const value: string = decodeURIComponent(pair.substring(eqIndex + 1));
        params.set(key, value);
      }
    }
    return params;
  }

  /**
   * 返回 null 表示「二维码明确给了一个不支持的值」，由调用方报错。
   * 过去这里静默回落到默认值：条目能录进去，但和服务器算出来的码永远对不上，
   * 用户只会看到一次次验证失败，完全想不到是录入被悄悄改写过。
   */
  private parseAlgorithm(value: string | undefined): TotpAlgorithm | null {
    if (value === undefined || value.trim().length === 0) {
      return DEFAULT_TOTP_ALGORITHM;
    }
    const upper: string = value.trim().toUpperCase();
    if (VALID_ALGORITHMS.indexOf(upper) >= 0) {
      return upper as TotpAlgorithm;
    }
    return null;
  }

  private parseDigits(value: string | undefined): 6 | 8 | null {
    if (value === undefined || value.trim().length === 0) {
      return DEFAULT_TOTP_DIGITS;
    }
    const parsed: number = Number.parseInt(value.trim(), 10);
    if (parsed === 6) {
      return 6;
    }
    if (parsed === 8) {
      return 8;
    }
    return null;
  }

  private parsePeriod(value: string | undefined): number | null {
    if (value === undefined || value.trim().length === 0) {
      return DEFAULT_TOTP_PERIOD;
    }
    const parsed: number = Number.parseInt(value.trim(), 10);
    if (Number.isNaN(parsed) || parsed <= 0 || parsed > MAX_TOTP_PERIOD) {
      return null;
    }
    return parsed;
  }
}
