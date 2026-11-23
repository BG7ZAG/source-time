import { describe, it, expect } from '@ohos/hypium';
import { TotpService } from '../../../main/ets/service/TotpService';
import { Result } from '../../../main/ets/types/Result';

const SHA1_SECRET: string = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
const SHA256_SECRET: string = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA';
const SHA512_SECRET: string =
  'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA';

export default function totpServiceTest() {
  describe('TotpServiceTest', () => {
    it('rfc6238Sha1Vector59', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: SHA1_SECRET, algorithm: 'SHA1', digits: 8, period: 30, timestamp: 59
      });
      expect(result.success).assertTrue();
      expect(result.data as string).assertEqual('94287082');
    });

    it('rfc6238Sha1Vector1111111109', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: SHA1_SECRET, algorithm: 'SHA1', digits: 8, period: 30, timestamp: 1111111109
      });
      expect(result.data as string).assertEqual('07081804');
    });

    it('rfc6238Sha1Vector1111111111', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: SHA1_SECRET, algorithm: 'SHA1', digits: 8, period: 30, timestamp: 1111111111
      });
      expect(result.data as string).assertEqual('14050471');
    });

    it('rfc6238Sha1Vector1234567890', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: SHA1_SECRET, algorithm: 'SHA1', digits: 8, period: 30, timestamp: 1234567890
      });
      expect(result.data as string).assertEqual('89005924');
    });

    it('rfc6238Sha1Vector2000000000', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: SHA1_SECRET, algorithm: 'SHA1', digits: 8, period: 30, timestamp: 2000000000
      });
      expect(result.data as string).assertEqual('69279037');
    });

    it('rfc6238Sha1Vector20000000000', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: SHA1_SECRET, algorithm: 'SHA1', digits: 8, period: 30, timestamp: 20000000000
      });
      expect(result.data as string).assertEqual('65353130');
    });

    it('rfc6238Sha256Vector59', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: SHA256_SECRET, algorithm: 'SHA256', digits: 8, period: 30, timestamp: 59
      });
      expect(result.data as string).assertEqual('46119246');
    });

    it('rfc6238Sha512Vector59', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: SHA512_SECRET, algorithm: 'SHA512', digits: 8, period: 30, timestamp: 59
      });
      expect(result.data as string).assertEqual('90693936');
    });

    it('sixDigitsPadsLeadingZeros', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: SHA1_SECRET, algorithm: 'SHA1', digits: 6, period: 30, timestamp: 59
      });
      expect(result.data as string).assertEqual('287082');
    });

    it('invalidSecretRejected', 0, () => {
      const service = new TotpService();
      const result: Result<string> = service.generate({
        secret: '0189!', algorithm: 'SHA1', digits: 6, period: 30, timestamp: 59
      });
      expect(result.success).assertFalse();
    });
  });
}
