import { describe, it, expect } from '@ohos/hypium';
import { CryptoService } from '../../../main/ets/service/CryptoService';
import { GCM_TAG_LENGTH } from '../../../main/ets/constants/CryptoConstants';

const HEADER_LENGTH: number = 40;

export default function cryptoServiceTest() {
  describe('CryptoServiceTest', () => {
    it('encryptThenDecryptReturnsOriginal', 0, async () => {
      const service = new CryptoService();
      const userSecret: string = 'correct-horse-battery-staple';
      const plaintext: Uint8Array = new Uint8Array([0, 1, 2, 3, 4, 5, 250, 251, 252]);
      const encrypted: Uint8Array = await service.encrypt(plaintext, userSecret);
      const decrypted: Uint8Array = await service.decrypt(encrypted, userSecret);
      expect(decrypted.length).assertEqual(plaintext.length);
      for (let i = 0; i < plaintext.length; i++) {
        expect(decrypted[i]).assertEqual(plaintext[i]);
      }
    });

    it('decryptWithWrongSecretFails', 0, async () => {
      const service = new CryptoService();
      const encrypted: Uint8Array = await service.encrypt(new Uint8Array([9, 8, 7]), 'secret-a');
      let failed: boolean = false;
      try {
        await service.decrypt(encrypted, 'secret-b');
      } catch (error) {
        failed = true;
      }
      expect(failed).assertTrue();
    });

    it('decryptTamperedCiphertextFails', 0, async () => {
      const service = new CryptoService();
      const encrypted: Uint8Array = await service.encrypt(new Uint8Array([1, 2, 3, 4]), 'secret');
      const tampered: Uint8Array = encrypted.slice(0, encrypted.length);
      tampered[HEADER_LENGTH] = tampered[HEADER_LENGTH] ^ 0xFF;
      let failed: boolean = false;
      try {
        await service.decrypt(tampered, 'secret');
      } catch (error) {
        failed = true;
      }
      expect(failed).assertTrue();
    });

    it('decryptTamperedAuthTagFails', 0, async () => {
      const service = new CryptoService();
      const encrypted: Uint8Array = await service.encrypt(new Uint8Array([5, 6, 7, 8]), 'secret');
      const tampered: Uint8Array = encrypted.slice(0, encrypted.length);
      tampered[tampered.length - GCM_TAG_LENGTH] = tampered[tampered.length - GCM_TAG_LENGTH] ^ 0xFF;
      let failed: boolean = false;
      try {
        await service.decrypt(tampered, 'secret');
      } catch (error) {
        failed = true;
      }
      expect(failed).assertTrue();
    });

    it('nonceAndSaltChangeBetweenEncryptions', 0, async () => {
      const service = new CryptoService();
      const plaintext: Uint8Array = new Uint8Array([1, 1, 1]);
      const first: Uint8Array = await service.encrypt(plaintext, 'secret');
      const second: Uint8Array = await service.encrypt(plaintext, 'secret');
      expect(first.length).assertEqual(second.length);
      let identical: boolean = true;
      for (let i = 0; i < first.length; i++) {
        if (first[i] !== second[i]) {
          identical = false;
          break;
        }
      }
      expect(identical).assertFalse();
    });
  });
}
