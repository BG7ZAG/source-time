import distributedKVStore from '@ohos.data.distributedKVStore';
import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../utils/AppContextHolder';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';

const STORE_ID: string = 'sourcetime_config_store_v2';
const KEY_BUNDLE: string = 'config_bundle';
const DISTRIBUTED_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC';
/** KV 里没有该键时 get() 抛出的业务码，应视为「未发现配置」而不是通道故障。 */
const KV_NOT_FOUND: number = 15100004;
/**
 * 推送成功后清理本机副本的延迟。
 *
 * 不能设成几秒：分布式 KV 的同步要求收发两端的应用都持有着同一个库，
 * 用户点完推送再去打开手表应用通常要十几秒到一分钟；删早了对方就永远拿不到。
 * 一分钟足够覆盖「推送 → 立刻看手表」这个正常动作，又不至于让主密钥长期留在库里。
 */
const PUBLISH_CLEANUP_DELAY_MS: number = 60 * 1000;

/**
 * 在线可信设备（同账号组网）。
 *
 * 只暴露推送需要的最小字段：deviceType 用来在列表里区分手表/手机，并让手表排在前面。
 */
export interface PeerDevice {
  deviceId: string;
  deviceName: string;
  deviceType: string;
}

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
  private deviceManager: distributedDeviceManager.DeviceManager | null = null;
  /** 推送后清理本机副本的定时器；重复推送时先取消，避免旧定时器删掉新包。 */
  private cleanupTimer: number = -1;

  static getInstance(): DistributedConfigService {
    if (DistributedConfigService.instance === null) {
      DistributedConfigService.instance = new DistributedConfigService();
    }
    return DistributedConfigService.instance;
  }

  private permissionGranted: boolean = false;
  /** 用户拒绝过一次：此后 requestPermissionsFromUser 不会再弹框，只能改走权限设置页。 */
  private permissionDeniedBefore: boolean = false;

  /**
   * 申请跨设备数据同步权限。
   *
   * 系统规定：用户拒绝后 requestPermissionsFromUser 不再弹框。此前这里直接返回 false，
   * 于是手表上一次误触（小屏很容易点错）就让整个进程生命周期内再也同步不了，只能杀进程重启。
   * 现在改为：首次正常申请；被拒后改用 requestPermissionOnSetting 拉起权限设置页，
   * 用户在设置里打开开关返回即可继续，不再存在「永久失败」状态。
   */
  async ensurePermission(): Promise<boolean> {
    if (this.permissionGranted) {
      return true;
    }
    const context = AppContextHolder.getContext();
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      if (this.permissionDeniedBefore) {
        const settingResult: Array<abilityAccessCtrl.GrantStatus> =
          await atManager.requestPermissionOnSetting(context, [DISTRIBUTED_PERMISSION]);
        const grantedBySetting: boolean = settingResult.length > 0
          && settingResult[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
        this.permissionGranted = grantedBySetting;
        Logger.info('Distributed permission granted by setting: ' + grantedBySetting);
        return grantedBySetting;
      }
      const result = await atManager.requestPermissionsFromUser(context, [DISTRIBUTED_PERMISSION]);
      // authResults 里 0 表示已授权
      const granted: boolean = result.authResults.length > 0 && result.authResults[0] === 0;
      this.permissionGranted = granted;
      this.permissionDeniedBefore = !granted;
      return granted;
    } catch (error) {
      const failure = error as BusinessError;
      Logger.error('Request DISTRIBUTED_DATASYNC permission failed: code='
        + failure.code + ' message=' + failure.message);
      // 不置任何永久标志：用户可能刚在设置里改过授权，下次仍应允许重试
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
      // 必须关闭自动同步：autoSync 会把写入广播给组内所有可信设备，
      // 那样「选择接收设备」就是摆设。改为在 publish() 里按选中的 deviceId 定向 PUSH_ONLY。
      // 注意：改这个选项需要换库名（v2），已存在的库不会重新应用 options。
      autoSync: false,
      kvStoreType: distributedKVStore.KVStoreType.DEVICE_COLLABORATION,
      securityLevel: distributedKVStore.SecurityLevel.S1
    };
    this.store = await manager.getKVStore<distributedKVStore.SingleKVStore>(STORE_ID, options);
    return this.store;
  }

  /**
   * 手机端：写入配置密文并推送。
   *
   * targetDeviceIds 为空时退化为「推给所有在线可信设备」；指定时只 PUSH_ONLY 给这些设备。
   * 这是「选择接收设备」能生效的前提——库已关闭 autoSync，否则写入仍会广播给全组。
   */
  async publish(bundle: string, targetDeviceIds: string[] = []): Promise<Result<void>> {
    try {
      const store = await this.ensureStore();
      await store.put(KEY_BUNDLE, bundle);
      if (targetDeviceIds.length > 0) {
        // 定向推送必须 PUSH_ONLY：PUSH_PULL 会把目标设备上的旧包拉回来覆盖刚写入的新包
        store.sync(targetDeviceIds, distributedKVStore.SyncMode.PUSH_ONLY);
      } else {
        this.syncWithPeers(store, distributedKVStore.SyncMode.PUSH_ONLY);
      }
      // 推送完成后清掉本机副本：包里有主密钥，没有长期留在分布式库里的理由。
      // 清掉之后同账号其它设备也拉不到，「选择设备」才不只是个操作姿势。
      this.scheduleLocalCleanup();
      Logger.info('Config bundle published, bytes=' + bundle.length
        + ' targets=' + targetDeviceIds.length);
      return ok(undefined);
    } catch (error) {
      const failure = error as BusinessError;
      Logger.error('Publish config bundle failed: code=' + failure.code + ' message=' + failure.message);
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
      return this.getDeviceManager().getAvailableDeviceListSync().length > 0;
    } catch (error) {
      const failure = error as BusinessError;
      // 801=该设备不支持分布式服务（部分手表如此）、201=权限未授予、11600101=系统执行失败。
      // 这三种在 UI 上都只表现为「未发现设备」，不留错误码就无法区分是设备能力问题还是组网问题。
      Logger.warn('Query trusted devices failed: code=' + failure.code + ' message=' + failure.message);
      return false;
    }
  }

  /**
   * 列出当前在线可信设备。
   *
   * 未授权 / 未组网 / 手表不支持分布式时都返回空数组，调用方据此给「同账号 + 蓝牙」的引导；
   * 具体是 801 还是 201，只能靠日志里的错误码区分。
   */
  listPeers(): PeerDevice[] {
    try {
      const devices: distributedDeviceManager.DeviceBasicInfo[] =
        this.getDeviceManager().getAvailableDeviceListSync();
      const peers: PeerDevice[] = devices.map((device: distributedDeviceManager.DeviceBasicInfo) => {
        const peer: PeerDevice = {
          deviceId: device.deviceId,
          deviceName: device.deviceName,
          deviceType: device.deviceType
        };
        return peer;
      });
      // 手表优先：这条链路的默认目标就是手表，多设备时把它排到最前
      peers.sort((left: PeerDevice, right: PeerDevice) => {
        const leftRank: number = left.deviceType === 'wearable' ? 0 : 1;
        const rightRank: number = right.deviceType === 'wearable' ? 0 : 1;
        return leftRank - rightRank;
      });
      Logger.info('Trusted devices: ' + peers.length);
      return peers;
    } catch (error) {
      const failure = error as BusinessError;
      Logger.warn('List trusted devices failed: code=' + failure.code + ' message=' + failure.message);
      return [];
    }
  }

  /** bundleName 只在 ensureStore() 里赋值，早于建库调用设备接口时会拿到空串。 */
  private ensureBundleName(): void {
    if (this.bundleName.length === 0) {
      this.bundleName = AppContextHolder.getContext().applicationInfo.name;
    }
  }

  /**
   * 复用同一个 DeviceManager 实例。
   *
   * 每次发布/读取都 createDeviceManager 会在系统侧不断累积实例（这里没有明确的 release 时机），
   * 长时间使用后有句柄耗尽的风险；按进程缓存一个即可。
   */
  private getDeviceManager(): distributedDeviceManager.DeviceManager {
    this.ensureBundleName();
    if (this.deviceManager === null) {
      this.deviceManager = distributedDeviceManager.createDeviceManager(this.bundleName);
    }
    return this.deviceManager;
  }

  /** 手表端：主动同步并重试读取配置密文（分布式同步是异步的，首次可能还没到）。 */
  async read(): Promise<Result<string>> {
    try {
      const store = await this.ensureStore();
      // 跨设备同步不是即时的：拉取后通常要数秒才落到本机。首次组网、手表刚开机时更慢，
      // 窗口放宽到 ~12s（500ms + 14×800ms），避免手机端刚提示「已发送」、
      // 手表端却因读得太早而报「未发现手机配置」——这个误报会直接引导用户去重试。
      for (let attempt = 0; attempt < 15; attempt++) {
        // 接收端只拉不推：消费后 clear() 会删掉本机副本，双向同步会把这个删除反向推回手机，
        // 多设备场景下第二台设备就再也拿不到包了。
        this.syncWithPeers(store, distributedKVStore.SyncMode.PULL_ONLY);
        await this.delay(attempt === 0 ? 500 : 800);
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
      // 区分「通道里暂时没有包」与「根本没有同账号设备」：后者重试也没用，提示用户先组网
      return err<string>(AppErrorCode.UNKNOWN,
        this.hasOnlinePeer() ? $r('app.string.watch_sync_no_bundle') : $r('app.string.watch_sync_no_peer'));
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

  /**
   * 推送完成后延迟清掉本机副本。
   *
   * 两个原因：sync() 返回只代表任务已发起，要留发送窗口；接收端应用可能还没打开、
   * 库没建立起来就收不到，删早了这次推送就白做了。
   */
  private scheduleLocalCleanup(): void {
    if (this.cleanupTimer !== -1) {
      clearTimeout(this.cleanupTimer);
    }
    this.cleanupTimer = setTimeout(() => {
      this.cleanupTimer = -1;
      this.clear();
    }, PUBLISH_CLEANUP_DELAY_MS);
  }

  /**
   * 接收端消费后清掉本机副本，避免明文密钥长期留在本机分布式库。
   *
   * 只删本地：同步方向已是 PULL_ONLY，这个删除不会传播给发送端，
   * 所以同账号下其它设备仍能正常接收同一份包（30 分钟 TTL 内）。
   */
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
   * 与全部在线可信设备同步一次，方向由 mode 决定。
   *
   * 刻意不做双向：发送端只 PUSH、接收端只 PULL。接收端消费后会 clear() 删除本机副本，
   * 若是 PUSH_PULL，这个删除会反向推回手机，导致同账号下的第二台设备再也拿不到包。
   *
   * 没有权限 / 没有可信设备 / 设备未组网时会抛错，这里静默跳过。
   */
  private syncWithPeers(store: distributedKVStore.SingleKVStore,
    mode: distributedKVStore.SyncMode): void {
    try {
      const devices: distributedDeviceManager.DeviceBasicInfo[] =
        this.getDeviceManager().getAvailableDeviceListSync();
      const deviceIds: string[] = devices.map((device: distributedDeviceManager.DeviceBasicInfo) => device.deviceId);
      if (deviceIds.length > 0) {
        store.sync(deviceIds, mode);
      }
    } catch (error) {
      const failure = error as BusinessError;
      Logger.warn('Distributed peer sync skipped: code=' + failure.code + ' message=' + failure.message);
    }
  }
}
