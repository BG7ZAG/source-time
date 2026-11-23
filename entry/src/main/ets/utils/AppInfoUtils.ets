import { bundleManager } from '@kit.AbilityKit';
import { Logger } from './Logger';

/**
 * 应用级只读信息。
 *
 * 版本号直接取安装包内 app.json5 的 versionName：升级版本只需改 AppScope/app.json5，
 * 页面不再维护第二份硬编码版本（此前设置页与关于页各有一处，容易漏改）。
 */
export class AppInfoUtils {
  /** 读取 versionName；失败返回空串，由页面回退显示占位符。 */
  static getVersionName(): string {
    try {
      const info: bundleManager.BundleInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return info.versionName;
    } catch (error) {
      Logger.warn('Read bundle version name failed');
      return '';
    }
  }
}