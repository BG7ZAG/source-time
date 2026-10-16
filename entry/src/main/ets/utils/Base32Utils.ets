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
  // RFC 4648：未填充长度 mod 8 只能是 0/2/4/5/7。余 1 会让最后一个五元组凑不出一个字节
  // （'A' 解出 0 字节密钥），余 3、余 6 会丢掉 7 位/6 位尾部比特。
  // 这类串过去能通过校验，结果是「录入成功但永远出错码」——宁可在录入时就拒绝。
  const remainder: number = normalized.length % 8;
  return remainder !== 1 && remainder !== 3 && remainder !== 6;
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
