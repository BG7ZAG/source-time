import { TotpAlgorithm } from '../model/TotpItem';
import { isValidBase32, normalizeBase32 } from '../utils/Base32Utils';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { DEFAULT_TOTP_ALGORITHM, DEFAULT_TOTP_DIGITS, DEFAULT_TOTP_PERIOD } from '../constants/AppConstants';

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
        return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_URI, '二维码内容无效');
      }
      const trimmed: string = uri.trim();
      const schemeMatch: RegExpMatchArray | null = trimmed.match(SCHEME_REGEX);
      if (schemeMatch === null) {
        return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_URI, '不是有效的 TOTP 二维码');
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
        return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_SECRET, '密钥格式无效');
      }
      const parsed: ParsedOtpUri = {
        issuer: issuer,
        account: account,
        secret: normalizeBase32(secretParam),
        algorithm: this.parseAlgorithm(params.get('algorithm')),
        digits: this.parseDigits(params.get('digits')),
        period: this.parsePeriod(params.get('period'))
      };
      return ok(parsed);
    } catch (error) {
      return err<ParsedOtpUri>(AppErrorCode.INVALID_TOTP_URI, '二维码解析失败');
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
        params.set(decodeURIComponent(pair), '');
      } else {
        const key: string = decodeURIComponent(pair.substring(0, eqIndex));
        const value: string = decodeURIComponent(pair.substring(eqIndex + 1));
        params.set(key, value);
      }
    }
    return params;
  }

  private parseAlgorithm(value: string | undefined): TotpAlgorithm {
    if (value === undefined) {
      return DEFAULT_TOTP_ALGORITHM;
    }
    const upper: string = value.toUpperCase();
    if (VALID_ALGORITHMS.indexOf(upper) >= 0) {
      return upper as TotpAlgorithm;
    }
    return DEFAULT_TOTP_ALGORITHM;
  }

  private parseDigits(value: string | undefined): 6 | 8 {
    if (value === undefined) {
      return DEFAULT_TOTP_DIGITS;
    }
    const parsed: number = Number.parseInt(value, 10);
    if (parsed === 6 || parsed === 8) {
      return parsed;
    }
    return DEFAULT_TOTP_DIGITS;
  }

  private parsePeriod(value: string | undefined): number {
    if (value === undefined) {
      return DEFAULT_TOTP_PERIOD;
    }
    const parsed: number = Number.parseInt(value, 10);
    if (Number.isNaN(parsed) || parsed <= 0) {
      return DEFAULT_TOTP_PERIOD;
    }
    return parsed;
  }
}
