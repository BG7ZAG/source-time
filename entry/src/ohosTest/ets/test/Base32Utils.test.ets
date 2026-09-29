import { describe, it, expect } from '@ohos/hypium';
import { base32Decode, isValidBase32, normalizeBase32 } from '../../../main/ets/utils/Base32Utils';

export default function base32UtilsTest() {
  describe('Base32UtilsTest', () => {
    it('decodeUppercaseSecret', 0, () => {
      const bytes: Uint8Array = base32Decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      expect(bytes.length).assertEqual(20);
      expect(String.fromCharCode(bytes[0])).assertEqual('1');
      expect(String.fromCharCode(bytes[1])).assertEqual('2');
    });

    it('decodeLowercaseWithSpacesAndPadding', 0, () => {
      const bytes: Uint8Array = base32Decode('gezd gnbv gy3t qojq====');
      expect(bytes.length).assertEqual(10);
      expect(String.fromCharCode(bytes[0])).assertEqual('1');
      expect(String.fromCharCode(bytes[9])).assertEqual('0');
    });

    it('normalizeUppercasesAndStrips', 0, () => {
      expect(normalizeBase32(' ab cd ')).assertEqual('ABCD');
      expect(normalizeBase32('abcd====')).assertEqual('ABCD');
    });

    it('invalidCharactersRejected', 0, () => {
      expect(isValidBase32('ABC!123')).assertFalse();
      expect(isValidBase32('0189')).assertFalse();
      expect(isValidBase32('ABC1')).assertFalse();
    });

    it('emptySecretRejected', 0, () => {
      expect(isValidBase32('')).assertFalse();
      expect(isValidBase32('   ')).assertFalse();
    });

    it('shortValidSecretAccepted', 0, () => {
      expect(isValidBase32('AB')).assertTrue();
      expect(isValidBase32('MZXW6')).assertTrue();
    });

    it('decodeInvalidThrows', 0, () => {
      let threw: boolean = false;
      try {
        base32Decode('!@#$');
      } catch (error) {
        threw = true;
      }
      expect(threw).assertTrue();
    });
  });
}
