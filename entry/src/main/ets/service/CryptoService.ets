import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { Logger } from '../utils/Logger';
import {
  CRYPTO_FORMAT_VERSION,
  GCM_NONCE_LENGTH,
  GCM_TAG_LENGTH,
  KDF_ITERATIONS,
  KDF_KEY_LENGTH,
  KDF_SALT_LENGTH,
  RANDOM_SECRET_LENGTH
} from '../constants/CryptoConstants';

const MAGIC_BYTES: number[] = [0x53, 0x54, 0x4F, 0x54];
const MAGIC_LENGTH: number = 4;
const VERSION_LENGTH: number = 1;
const ALGORITHM_ID_LENGTH: number = 1;
const ITERATIONS_LENGTH: number = 4;
const LENGTH_FIELD_SIZE: number = 1;
const KDF_ALGORITHM_ID_PBKDF2_SHA256: number = 1;
const KDF_CRYPTO_ALGORITHM: string = 'PBKDF2|SHA256';
const KDF_SPEC_ALGORITHM: string = 'PBKDF2';
const AES_SYM_KEY_ALGORITHM: string = 'AES256';
const AES_GCM_TRANSFORMATION: string = 'AES256|GCM|NoPadding';
const GCM_PARAMS_ALGORITHM: string = 'GcmParamsSpec';
const EMPTY_BYTES: Uint8Array = new Uint8Array(0);

interface EncryptedFileParts {
  iterations: number;
  salt: Uint8Array;
  nonce: Uint8Array;
  cipherText: Uint8Array;
  authTag: Uint8Array;
}

export class CryptoService {
  generateRandomEncryptionSecret(): string {
    const random = cryptoFramework.createRandom();
    const blob = random.generateRandomSync(RANDOM_SECRET_LENGTH);
    const helper = new util.Base64Helper();
    return helper.encodeToStringSync(blob.data, util.Type.BASIC_URL_SAFE);
  }

  generateSalt(): Uint8Array {
    const random = cryptoFramework.createRandom();
    return random.generateRandomSync(KDF_SALT_LENGTH).data;
  }

  generateNonce(): Uint8Array {
    const random = cryptoFramework.createRandom();
    return random.generateRandomSync(GCM_NONCE_LENGTH).data;
  }

  async deriveKey(userSecret: string, salt: Uint8Array, iterations: number): Promise<Uint8Array> {
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: KDF_SPEC_ALGORITHM,
      password: userSecret,
      salt: salt,
      iterations: iterations,
      keySize: KDF_KEY_LENGTH
    };
    const kdf = cryptoFramework.createKdf(KDF_CRYPTO_ALGORITHM);
    const derived = kdf.generateSecretSync(spec);
    return derived.data;
  }

  async encrypt(plaintext: Uint8Array, userSecret: string): Promise<Uint8Array> {
    try {
      const salt: Uint8Array = this.generateSalt();
      const nonce: Uint8Array = this.generateNonce();
      const key: Uint8Array = await this.deriveKey(userSecret, salt, KDF_ITERATIONS);
      const output: Uint8Array = this.aesGcmEncrypt(plaintext, key, nonce);
      const cipherLength: number = output.length - GCM_TAG_LENGTH;
      const cipherText: Uint8Array = output.slice(0, cipherLength);
      const authTag: Uint8Array = output.slice(cipherLength, output.length);
      return this.serialize(KDF_ITERATIONS, salt, nonce, cipherText, authTag);
    } catch (error) {
      Logger.error('Crypto encrypt failed');
      throw new Error('ENCRYPT_FAILED');
    }
  }

  async decrypt(encryptedData: Uint8Array, userSecret: string): Promise<Uint8Array> {
    try {
      const parts: EncryptedFileParts = this.parse(encryptedData);
      const key: Uint8Array = await this.deriveKey(userSecret, parts.salt, parts.iterations);
      return this.aesGcmDecrypt(parts.cipherText, key, parts.nonce, parts.authTag);
    } catch (error) {
      Logger.error('Crypto decrypt failed');
      throw new Error('DECRYPT_FAILED');
    }
  }

  private aesGcmEncrypt(plaintext: Uint8Array, key: Uint8Array, nonce: Uint8Array): Uint8Array {
    const generator = cryptoFramework.createSymKeyGenerator(AES_SYM_KEY_ALGORITHM);
    const symKey = generator.convertKeySync({ data: key });
    const cipher = cryptoFramework.createCipher(AES_GCM_TRANSFORMATION);
    const params: cryptoFramework.GcmParamsSpec = {
      algName: GCM_PARAMS_ALGORITHM,
      iv: { data: nonce },
      aad: { data: EMPTY_BYTES },
      authTag: { data: EMPTY_BYTES }
    };
    cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, params);
    return cipher.doFinalSync({ data: plaintext }).data;
  }

  private aesGcmDecrypt(cipherText: Uint8Array, key: Uint8Array, nonce: Uint8Array, authTag: Uint8Array): Uint8Array {
    const generator = cryptoFramework.createSymKeyGenerator(AES_SYM_KEY_ALGORITHM);
    const symKey = generator.convertKeySync({ data: key });
    const cipher = cryptoFramework.createCipher(AES_GCM_TRANSFORMATION);
    const params: cryptoFramework.GcmParamsSpec = {
      algName: GCM_PARAMS_ALGORITHM,
      iv: { data: nonce },
      aad: { data: EMPTY_BYTES },
      authTag: { data: authTag }
    };
    cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, params);
    return cipher.doFinalSync({ data: cipherText }).data;
  }

  private serialize(iterations: number, salt: Uint8Array, nonce: Uint8Array, cipherText: Uint8Array,
    authTag: Uint8Array): Uint8Array {
    const total: number = MAGIC_LENGTH + VERSION_LENGTH + ALGORITHM_ID_LENGTH + ITERATIONS_LENGTH
      + LENGTH_FIELD_SIZE + salt.length + LENGTH_FIELD_SIZE + nonce.length
      + cipherText.length + authTag.length;
    const buffer: Uint8Array = new Uint8Array(total);
    let offset: number = 0;
    buffer.set(new Uint8Array(MAGIC_BYTES), offset);
    offset += MAGIC_LENGTH;
    buffer[offset] = CRYPTO_FORMAT_VERSION;
    offset += VERSION_LENGTH;
    buffer[offset] = KDF_ALGORITHM_ID_PBKDF2_SHA256;
    offset += ALGORITHM_ID_LENGTH;
    this.writeUint32(buffer, offset, iterations);
    offset += ITERATIONS_LENGTH;
    buffer[offset] = salt.length;
    offset += LENGTH_FIELD_SIZE;
    buffer.set(salt, offset);
    offset += salt.length;
    buffer[offset] = nonce.length;
    offset += LENGTH_FIELD_SIZE;
    buffer.set(nonce, offset);
    offset += nonce.length;
    buffer.set(cipherText, offset);
    offset += cipherText.length;
    buffer.set(authTag, offset);
    return buffer;
  }

  private parse(encryptedData: Uint8Array): EncryptedFileParts {
    const minimalLength: number = MAGIC_LENGTH + VERSION_LENGTH + ALGORITHM_ID_LENGTH + ITERATIONS_LENGTH
      + LENGTH_FIELD_SIZE + LENGTH_FIELD_SIZE + GCM_TAG_LENGTH;
    if (encryptedData.length < minimalLength) {
      throw new Error('INVALID_ENCRYPTED_FILE');
    }
    let offset: number = 0;
    for (let i = 0; i < MAGIC_LENGTH; i++) {
      if (encryptedData[offset + i] !== MAGIC_BYTES[i]) {
        throw new Error('INVALID_ENCRYPTED_FILE');
      }
    }
    offset += MAGIC_LENGTH;
    const version: number = encryptedData[offset];
    offset += VERSION_LENGTH;
    if (version !== CRYPTO_FORMAT_VERSION) {
      throw new Error('INVALID_ENCRYPTED_FILE');
    }
    const algorithmId: number = encryptedData[offset];
    offset += ALGORITHM_ID_LENGTH;
    if (algorithmId !== KDF_ALGORITHM_ID_PBKDF2_SHA256) {
      throw new Error('INVALID_ENCRYPTED_FILE');
    }
    const iterations: number = this.readUint32(encryptedData, offset);
    offset += ITERATIONS_LENGTH;
    const saltLength: number = encryptedData[offset];
    offset += LENGTH_FIELD_SIZE;
    const salt: Uint8Array = encryptedData.slice(offset, offset + saltLength);
    offset += saltLength;
    const nonceLength: number = encryptedData[offset];
    offset += LENGTH_FIELD_SIZE;
    const nonce: Uint8Array = encryptedData.slice(offset, offset + nonceLength);
    offset += nonceLength;
    const cipherLength: number = encryptedData.length - offset - GCM_TAG_LENGTH;
    if (cipherLength < 0) {
      throw new Error('INVALID_ENCRYPTED_FILE');
    }
    const cipherText: Uint8Array = encryptedData.slice(offset, offset + cipherLength);
    offset += cipherLength;
    const authTag: Uint8Array = encryptedData.slice(offset, offset + GCM_TAG_LENGTH);
    const parts: EncryptedFileParts = {
      iterations: iterations,
      salt: salt,
      nonce: nonce,
      cipherText: cipherText,
      authTag: authTag
    };
    return parts;
  }

  private writeUint32(buffer: Uint8Array, offset: number, value: number): void {
    buffer[offset] = (value >>> 24) & 0xFF;
    buffer[offset + 1] = (value >>> 16) & 0xFF;
    buffer[offset + 2] = (value >>> 8) & 0xFF;
    buffer[offset + 3] = value & 0xFF;
  }

  private readUint32(buffer: Uint8Array, offset: number): number {
    const value: number = (buffer[offset] << 24) | (buffer[offset + 1] << 16)
      | (buffer[offset + 2] << 8) | buffer[offset + 3];
    return value >>> 0;
  }
}
