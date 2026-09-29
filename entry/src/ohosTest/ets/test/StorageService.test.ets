import { describe, it, expect, beforeAll } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { StorageService } from '../../../main/ets/service/StorageService';
import { AppContextHolder } from '../../../main/ets/utils/AppContextHolder';
import { DatabaseModel } from '../../../main/ets/model/DatabaseModel';
import { TotpItem } from '../../../main/ets/model/TotpItem';
import { CURRENT_SCHEMA_VERSION } from '../../../main/ets/constants/AppConstants';

function makeItem(): TotpItem {
  return {
    id: 'test-id',
    issuer: 'GitHub',
    account: 'user@example.com',
    secret: 'JBSWY3DPEHPK3PXP',
    algorithm: 'SHA1',
    digits: 6,
    period: 30,
    createdAt: 1727000000000,
    updatedAt: 1727000000000
  };
}

function makeDatabase(deviceId: string, items: TotpItem[]): DatabaseModel {
  return {
    version: CURRENT_SCHEMA_VERSION,
    revision: 1,
    updatedAt: 1727000000000,
    deviceId: deviceId,
    items: items
  };
}

export default function storageServiceTest() {
  describe('StorageServiceTest', () => {
    beforeAll(() => {
      const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext() as common.Context;
      AppContextHolder.init(context);
    });

    it('saveThenLoadRestoresDatabase', 0, async () => {
      const service = new StorageService();
      const secret: string = 'storage-test-secret';
      const db: DatabaseModel = makeDatabase('device-1', [makeItem()]);
      const saveResult = await service.saveDatabase(db, secret);
      expect(saveResult.success).assertTrue();
      const loadResult = await service.loadDatabase(secret);
      expect(loadResult.success).assertTrue();
      const loaded: DatabaseModel = loadResult.data as DatabaseModel;
      expect(loaded.items.length).assertEqual(1);
      expect(loaded.items[0].issuer).assertEqual('GitHub');
    });

    it('loadWithWrongSecretFails', 0, async () => {
      const service = new StorageService();
      const db: DatabaseModel = makeDatabase('device-2', []);
      await service.saveDatabase(db, 'correct-secret');
      const loadResult = await service.loadDatabase('wrong-secret');
      expect(loadResult.success).assertFalse();
    });

    it('changeEncryptionSecretPreservesData', 0, async () => {
      const service = new StorageService();
      const db: DatabaseModel = makeDatabase('device-3', [makeItem()]);
      await service.saveDatabase(db, 'old-secret');
      const changeResult = await service.changeEncryptionSecret('old-secret', 'new-secret');
      expect(changeResult.success).assertTrue();
      const loadResult = await service.loadDatabase('new-secret');
      expect(loadResult.success).assertTrue();
      const loaded: DatabaseModel = loadResult.data as DatabaseModel;
      expect(loaded.items.length).assertEqual(1);
    });

    it('changeEncryptionSecretWithWrongOldFails', 0, async () => {
      const service = new StorageService();
      const db: DatabaseModel = makeDatabase('device-4', []);
      await service.saveDatabase(db, 'old-secret-2');
      const changeResult = await service.changeEncryptionSecret('wrong', 'new-secret-2');
      expect(changeResult.success).assertFalse();
    });
  });
}
