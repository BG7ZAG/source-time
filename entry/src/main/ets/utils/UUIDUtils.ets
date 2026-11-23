import { util } from '@kit.ArkTS';

export function generateUuid(): string {
  return util.generateRandomUUID(true);
}
