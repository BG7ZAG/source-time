export type TotpAlgorithm = 'SHA1' | 'SHA256' | 'SHA512';

export interface TotpItem {
  id: string;
  issuer: string;
  account: string;
  secret: string;
  algorithm: TotpAlgorithm;
  digits: 6 | 8;
  period: number;
  createdAt: number;
  updatedAt: number;
}
