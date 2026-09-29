import { TotpItem } from './TotpItem';

export interface DatabaseModel {
  version: number;
  revision: number;
  updatedAt: number;
  deviceId: string;
  items: TotpItem[];
}
