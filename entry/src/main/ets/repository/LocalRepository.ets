import { DatabaseModel } from '../model/DatabaseModel';
import { TotpItem } from '../model/TotpItem';
import { Result } from '../types/Result';
import { StorageService } from '../service/StorageService';

export class LocalRepository {
  private storageService: StorageService = StorageService.getInstance();

  async load(encryptionSecret: string): Promise<Result<DatabaseModel>> {
    return this.storageService.loadDatabase(encryptionSecret);
  }

  async save(database: DatabaseModel, encryptionSecret: string): Promise<Result<void>> {
    return this.storageService.saveDatabase(database, encryptionSecret);
  }

  async replace(database: DatabaseModel, encryptionSecret: string): Promise<Result<void>> {
    return this.storageService.replaceDatabase(database, encryptionSecret);
  }

  async changeEncryptionSecret(oldSecret: string, newSecret: string): Promise<Result<void>> {
    return this.storageService.changeEncryptionSecret(oldSecret, newSecret);
  }

  getDatabase(): DatabaseModel | null {
    return this.storageService.getDatabase();
  }

  getItems(): TotpItem[] {
    const db: DatabaseModel | null = this.storageService.getDatabase();
    if (db === null) {
      return [];
    }
    return db.items;
  }
}
