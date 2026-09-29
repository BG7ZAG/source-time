const BASE32_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function normalizeBase32(input: string): string {
  return input.replace(/\s+/g, '').replace(/=+$/, '').toUpperCase();
}

export function isValidBase32(input: string): boolean {
  const normalized: string = normalizeBase32(input);
  if (normalized.length === 0) {
    return false;
  }
  for (let i = 0; i < normalized.length; i++) {
    if (BASE32_ALPHABET.indexOf(normalized.charAt(i)) < 0) {
      return false;
    }
  }
  return true;
}

export function base32Decode(input: string): Uint8Array {
  const normalized: string = normalizeBase32(input);
  if (!isValidBase32(normalized)) {
    throw new Error('INVALID_TOTP_SECRET');
  }
  let bits: number = 0;
  let value: number = 0;
  const output: number[] = [];
  for (let i = 0; i < normalized.length; i++) {
    value = (value << 5) | BASE32_ALPHABET.indexOf(normalized.charAt(i));
    bits += 5;
    if (bits >= 8) {
      output.push((value >>> (bits - 8)) & 0xFF);
      bits -= 8;
    }
  }
  return new Uint8Array(output);
}
