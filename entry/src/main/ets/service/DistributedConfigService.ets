import distributedKVStore from '@ohos.data.distributedKVStore';
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../utils/AppContextHolder';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';

const STORE_ID: string = 'sourcetime_config_store';
const KEY_BUNDLE: string = 'config_bundle';
const DISTRIBUTED_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC';
/** KV 里没有该键时 get() 抛出的业务码，应视为「未发现配置」而不是通道故障。 */
const KV_NOT_FOUND: number = 15100004;

/**
 * 手机 ↔ 手表的一次性配置传输通道。
 *
 * 使用 DEVICE_COLLABORATION 类型的分布式 KV 库：只在同一账号的可信设备间同步，
 * 且库本身开启加密（encrypt: true）。业务层再叠加一次性 PIN 加密，
 * 即使通道里的密文被截获，没有 PIN 也无法还原 WebDAV 密码与主密钥。
 */
export class DistributedConfigService {
  private static instance: DistributedConfigService | null = null;

  private store: distributedKVStore.SingleKVStore | null = null;
  private bundleName: string = '';

  static getInstance(): DistributedConfigService {
    if (DistributedConfigService.instance === null) {
      DistributedConfigService.instance = new DistributedConfigService();
    }
    return DistributedConfigService.instance;
  }

  /** 申请跨设备数据同步权限；已授权时系统会直接返回 0。 */
  async ensurePermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(
        AppContextHolder.getContext(), [DISTRIBUTED_PERMISSION]);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (error) {
      Logger.error('Request DISTRIBUTED_DATASYNC permission failed');
      return false;
    }
  }

  private async ensureStore(): Promise<distributedKVStore.SingleKVStore> {
    if (this.store !== null) {
      return this.store;
    }
    const context = AppContextHolder.getContext();
    this.bundleName = context.applicationInfo.name;
    const manager: distributedKVStore.KVManager = distributedKVStore.createKVManager({
      context: context,
      bundleName: this.bundleName
    });
    const options: distributedKVStore.Options = {
      createIfMissing: true,
      encrypt: true,
      backup: false,
      autoSync: true,
      kvStoreType: distributedKVStore.KVStoreType.DEVICE_COLLABORATION,
      securityLevel: distributedKVStore.SecurityLevel.S1
    };
    this.store = await manager.getKVStore<distributedKVStore.SingleKVStore>(STORE_ID, options);
    return this.store;
  }

  /** 手机端：写入配置密文并推送到在线可信设备。 */
  async publish(bundle: string): Promise<Result<void>> {
    try {
      const store = await this.ensureStore();
      await store.put(KEY_BUNDLE, bundle);
      this.syncWithPeers(store);
      Logger.info('Config bundle published, bytes=' + bundle.length);
      return ok(undefined);
    } catch (error) {
      Logger.error('Publish config bundle failed');
      return err<void>(AppErrorCode.UNKNOWN, $r('app.string.watch_sync_distributed_failed'));
    }
  }

  /**
   * 是否至少有一台在线可信设备（同账号组网）。
   *
   * publish() 只负责把密文写进本机分布式库，真正送达依赖同步；
   * 没有在线设备时写库同样成功，调用方需要用这个结果区分「已送达」与「等接收」。
   */
  hasOnlinePeer(): boolean {
    try {
      const deviceManager = distributedDeviceManager.createDeviceManager(this.bundleName);
      return deviceManager.getAvailableDeviceListSync().length > 0;
    } catch (error) {
      Logger.warn('Query trusted devices failed');
      return false;
    }
  }

  /** 手表端：主动同步并重试读取配置密文（分布式同步是异步的，首次可能还没到）。 */
  async read(): Promise<Result<string>> {
    try {
      const store = await this.ensureStore();
      for (let attempt = 0; attempt < 3; attempt++) {
        this.syncWithPeers(store);
        await this.delay(attempt === 0 ? 500 : 900);
        try {
          const value: boolean | string | number | Uint8Array = await store.get(KEY_BUNDLE);
          if (typeof value === 'string' && value.length > 0) {
            return ok(value);
          }
        } catch (error) {
          const failure = error as BusinessError;
          if (failure.code !== KV_NOT_FOUND) {
            Logger.error('Read config bundle failed: code=' + failure.code + ' message=' + failure.message);
            return err<string>(AppErrorCode.UNKNOWN, $r('app.string.watch_sync_distributed_failed'));
          }
          // 本轮还没有同步到，继续重试
        }
      }
      return err<string>(AppErrorCode.UNKNOWN, $r('app.string.watch_sync_no_bundle'));
    } catch (error) {
      const failure = error as BusinessError;
      Logger.error('Read config bundle failed: code=' + failure.code + ' message=' + failure.message);
      return err<string>(AppErrorCode.UNKNOWN, $r('app.string.watch_sync_distributed_failed'));
    }
  }

  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), ms);
    });
  }

  /** 手表端消费后清掉本机副本，避免同一份密文被重复使用。 */
  async clear(): Promise<void> {
    try {
      if (this.store === null) {
        return;
      }
      await this.store.delete(KEY_BUNDLE);
    } catch (error) {
      Logger.warn('Clear config bundle failed');
    }
  }

  /**
   * 与当前在线可信设备做一次双向同步。
   *
   * 没有权限 / 没有可信设备 / 设备未组网时会抛错，这里静默跳过：
   * 调用方随后 get() 拿到空值，会给出「未发现手机配置」的提示。
   */
  private syncWithPeers(store: distributedKVStore.SingleKVStore): void {
    try {
      const deviceManager = distributedDeviceManager.createDeviceManager(this.bundleName);
      const devices = deviceManager.getAvailableDeviceListSync();
      const deviceIds: string[] = devices.map((device) => device.deviceId);
      if (deviceIds.length > 0) {
        store.sync(deviceIds, distributedKVStore.SyncMode.PUSH_PULL);
      }
    } catch (error) {
      Logger.warn('Distributed peer sync skipped: no trusted device or permission');
    }
  }
}
