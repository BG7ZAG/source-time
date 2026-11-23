import { describe, it, expect } from '@ohos/hypium';
import { OtpParser, ParsedOtpUri } from '../../../main/ets/service/OtpParser';
import { Result } from '../../../main/ets/types/Result';
import { AppError, AppErrorCode } from '../../../main/ets/types/Errors';

const SECRET: string = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

export default function otpParserTest() {
  describe('OtpParserTest', () => {
    it('parseFullUri', 0, () => {
      const parser = new OtpParser();
      const uri: string = 'otpauth://totp/GitHub:user@example.com?secret=' + SECRET
        + '&issuer=GitHub&algorithm=SHA1&digits=6&period=30';
      const result: Result<ParsedOtpUri> = parser.parseUri(uri);
      expect(result.success).assertTrue();
      const parsed: ParsedOtpUri = result.data as ParsedOtpUri;
      expect(parsed.issuer).assertEqual('GitHub');
      expect(parsed.account).assertEqual('user@example.com');
      expect(parsed.algorithm).assertEqual('SHA1');
      expect(parsed.digits).assertEqual(6);
      expect(parsed.period).assertEqual(30);
    });

    it('parseIssuerFromLabelWhenParamMissing', 0, () => {
      const parser = new OtpParser();
      const uri: string = 'otpauth://totp/ACME:john@example.com?secret=' + SECRET;
      const result: Result<ParsedOtpUri> = parser.parseUri(uri);
      const parsed: ParsedOtpUri = result.data as ParsedOtpUri;
      expect(parsed.issuer).assertEqual('ACME');
      expect(parsed.account).assertEqual('john@example.com');
    });

    it('appliesDefaults', 0, () => {
      const parser = new OtpParser();
      const uri: string = 'otpauth://totp/user@example.com?secret=' + SECRET;
      const result: Result<ParsedOtpUri> = parser.parseUri(uri);
      const parsed: ParsedOtpUri = result.data as ParsedOtpUri;
      expect(parsed.issuer).assertEqual('');
      expect(parsed.account).assertEqual('user@example.com');
      expect(parsed.algorithm).assertEqual('SHA1');
      expect(parsed.digits).assertEqual(6);
      expect(parsed.period).assertEqual(30);
    });

    it('parsesCustomDigitsAndPeriod', 0, () => {
      const parser = new OtpParser();
      const uri: string = 'otpauth://totp/Service:acc?secret=' + SECRET
        + '&algorithm=SHA512&digits=8&period=60';
      const result: Result<ParsedOtpUri> = parser.parseUri(uri);
      const parsed: ParsedOtpUri = result.data as ParsedOtpUri;
      expect(parsed.algorithm).assertEqual('SHA512');
      expect(parsed.digits).assertEqual(8);
      expect(parsed.period).assertEqual(60);
    });

    it('invalidSchemeRejected', 0, () => {
      const parser = new OtpParser();
      const result: Result<ParsedOtpUri> = parser.parseUri('https://example.com/totp?secret=' + SECRET);
      expect(result.success).assertFalse();
    });

    it('missingSecretRejected', 0, () => {
      const parser = new OtpParser();
      const result: Result<ParsedOtpUri> = parser.parseUri('otpauth://totp/ACME:acc?issuer=ACME');
      expect(result.success).assertFalse();
    });

    it('invalidSecretRejected', 0, () => {
      const parser = new OtpParser();
      const result: Result<ParsedOtpUri> = parser.parseUri('otpauth://totp/ACME:acc?secret=0189!');
      expect(result.success).assertFalse();
    });

    it('urlEncodedLabelDecoded', 0, () => {
      const parser = new OtpParser();
      const uri: string = 'otpauth://totp/ACME%20Co:john%40example.com?secret=' + SECRET;
      const result: Result<ParsedOtpUri> = parser.parseUri(uri);
      const parsed: ParsedOtpUri = result.data as ParsedOtpUri;
      expect(parsed.issuer).assertEqual('ACME Co');
      expect(parsed.account).assertEqual('john@example.com');
    });

    it('chineseIssuerDecoded', 0, () => {
      const parser = new OtpParser();
      const uri: string = 'otpauth://totp/%E6%BA%90%E6%97%B6:user?secret=' + SECRET;
      const result: Result<ParsedOtpUri> = parser.parseUri(uri);
      const parsed: ParsedOtpUri = result.data as ParsedOtpUri;
      expect(parsed.issuer).assertEqual('源时');
      expect(parsed.account).assertEqual('user');
    });

    it('specialCharacterAccountPreserved', 0, () => {
      const parser = new OtpParser();
      const uri: string = 'otpauth://totp/Svc:a.b%2Bc%2Fd%3De?secret=' + SECRET;
      const result: Result<ParsedOtpUri> = parser.parseUri(uri);
      const parsed: ParsedOtpUri = result.data as ParsedOtpUri;
      expect(parsed.account).assertEqual('a.b+c/d=e');
    });

    it('queryKeysAreCaseInsensitive', 0, () => {
      const parser = new OtpParser();
      const uri: string = 'otpauth://totp/Svc:acc?SECRET=' + SECRET + '&Algorithm=SHA256&DIGITS=8&Period=60';
      const result: Result<ParsedOtpUri> = parser.parseUri(uri);
      expect(result.success).assertTrue();
      const parsed: ParsedOtpUri = result.data as ParsedOtpUri;
      expect(parsed.secret).assertEqual(SECRET);
      expect(parsed.algorithm).assertEqual('SHA256');
      expect(parsed.digits).assertEqual(8);
      expect(parsed.period).assertEqual(60);
    });

    it('unsupportedAlgorithmRejected', 0, () => {
      const parser = new OtpParser();
      const result: Result<ParsedOtpUri> = parser.parseUri('otpauth://totp/Svc:acc?secret=' + SECRET
        + '&algorithm=MD5');
      expect(result.success).assertFalse();
      const error: AppError = result.error as AppError;
      expect(error.code).assertEqual(AppErrorCode.INVALID_TOTP_CONFIG);
    });

    it('unsupportedDigitsRejected', 0, () => {
      const parser = new OtpParser();
      const result: Result<ParsedOtpUri> = parser.parseUri('otpauth://totp/Svc:acc?secret=' + SECRET
        + '&digits=7');
      expect(result.success).assertFalse();
    });

    it('invalidPeriodRejected', 0, () => {
      const parser = new OtpParser();
      const zero: Result<ParsedOtpUri> = parser.parseUri('otpauth://totp/Svc:acc?secret=' + SECRET + '&period=0');
      const huge: Result<ParsedOtpUri> = parser.parseUri('otpauth://totp/Svc:acc?secret=' + SECRET + '&period=99999');
      expect(zero.success).assertFalse();
      expect(huge.success).assertFalse();
    });
  });
}
