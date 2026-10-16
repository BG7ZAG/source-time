export const CRYPTO_FORMAT_VERSION: number = 1;

export const KDF_ALGORITHM: string = 'PBKDF2-HMAC-SHA256';

export const KDF_KEY_LENGTH: number = 32;

export const KDF_SALT_LENGTH: number = 16;

export const KDF_ITERATIONS: number = 100000;

export const KDF_ITERATIONS_MIN: number = 1000;

export const KDF_ITERATIONS_MAX: number = 1000000;

export const GCM_NONCE_LENGTH: number = 12;

export const GCM_TAG_LENGTH: number = 16;

export const RANDOM_SECRET_LENGTH: number = 32;

export const USER_SECRET_MIN_LENGTH: number = 12;

export const USER_SECRET_MAX_LENGTH: number = 128;
