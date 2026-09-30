import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../utils/AppContextHolder';
import { SettingsService } from '../service/SettingsService';
import { KeyStoreService } from '../service/KeyStoreService';
import { initGlassTheme, initImmersiveMaterialSupport, isDarkMode, supportsImmersive } from '../theme/GlassStyle';

const DOMAIN = 0x0000;
const SECRET_STORAGE_KEY: string = 'encryptionSecret';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | undefined = undefined;
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContextHolder.init(this.context);
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onWindowStageCreate');

    // 加密只作用于本地存储与 WebDAV 密文：启动时先从系统关键资产存储取回密钥，静默完成解锁
    const keyStoreService: KeyStoreService = new KeyStoreService();
    keyStoreService.load().then((secret: string) => {
      this.loadContent(windowStage, secret);
    }).catch((error: BusinessError) => {
      hilog.error(DOMAIN, 'SourceTime', 'Failed to load encryption secret. Cause: %{public}s', JSON.stringify(error));
      this.loadContent(windowStage, '');
    });
  }

  private loadContent(windowStage: window.WindowStage, secret: string): void {
    if (secret.length > 0) {
      AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, secret);
    }

    // 跟随系统深浅色，并把色深同步给冰晶材质样式工厂。
    // context.config.colorMode 在声明中是可选值（ColorMode | undefined），故显式退化为「跟随系统」。
    let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    try {
      const configured: ConfigurationConstant.ColorMode | undefined = this.context.config.colorMode;
      if (configured !== undefined) {
        colorMode = configured;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'SourceTime', 'Failed to read colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    initGlassTheme(colorMode);

    // 探测设备是否支持 HarmonyOS 26 沉浸式系统材质，不支持则自动降级为自绘冰晶样式
    initImmersiveMaterialSupport();
    hilog.info(DOMAIN, 'SourceTime', 'Immersive material ready: %{public}s', String(supportsImmersive()));

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'SourceTime', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }

    // 页面自带极光底色，故让窗口沉浸式布局：内容区铺满整屏（状态栏与导航栏下方也绘制底色），
    // 由 AuroraBackground 统一把「页面内容」压回安全区（见 syncSafeAreaInsets）。
    this.setupImmersiveWindow(windowStage);

    const settingsService: SettingsService = new SettingsService();
    const settings = settingsService.getSettings();

    let initialPage: string = 'pages/HomePage';
    if (settings.privacyPolicyAccepted && !settings.encryptionInitialized) {
      initialPage = 'pages/SecurityPage';
    }

    windowStage.loadContent(initialPage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'SourceTime', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'SourceTime', 'Succeeded in loading the content.');
    });
  }

  /**
   * 沉浸式窗口 + 安全区尺寸采集。
   *
   * 有底色的页面需要顶部沉浸、底部避开导航条：窗口设为 full screen 后底色铺满整屏，
   * 顶部状态栏高度与底部避让高度写入 AppStorage，由 AuroraBackground 为内容统一加内边距。
   */
  private setupImmersiveWindow(windowStage: window.WindowStage): void {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      this.mainWindow = mainWindow;
      // 先同步一次，保证页面首帧就能拿到正确的安全区尺寸
      this.syncSafeAreaInsets(mainWindow);

      mainWindow.setWindowLayoutFullScreen(true).then(() => {
        this.syncSafeAreaInsets(mainWindow);
      }).catch((error: BusinessError) => {
        hilog.error(DOMAIN, 'SourceTime', 'Failed to set full screen layout. Cause: %{public}s', JSON.stringify(error));
      });

      // 状态栏 / 导航栏背景透明，让页面极光底色透上来；图标颜色跟随深浅色主题
      this.applySystemBarColors();

      // 旋转、导航栏显隐、分屏等场景会改变避让区，跟随更新
      mainWindow.on('avoidAreaChange', () => {
        this.syncSafeAreaInsets(mainWindow);
      });
    } catch (err) {
      hilog.error(DOMAIN, 'SourceTime', 'Failed to setup immersive window. Cause: %{public}s', JSON.stringify(err));
    }
  }

  /** 沉浸式下系统栏背景需透明，否则会在底色上压出一条半透明黑带。 */
  private applySystemBarColors(): void {
    if (this.mainWindow === undefined) {
      return;
    }
    const contentColor: string = isDarkMode() ? '#FFFFFF' : '#000000';
    this.mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: contentColor,
      navigationBarContentColor: contentColor
    }).catch((error: BusinessError) => {
      hilog.error(DOMAIN, 'SourceTime', 'Failed to set system bar properties. Cause: %{public}s', JSON.stringify(error));
    });
  }

  /**
   * 读取系统避让区并换算为 vp：
   * - 顶部取 TYPE_SYSTEM 的 topRect（状态栏）
   * - 底部优先取 TYPE_NAVIGATION_INDICATOR（手势条），为 0 时回退到 TYPE_SYSTEM 的 bottomRect（三键导航栏）
   */
  private syncSafeAreaInsets(mainWindow: window.Window): void {
    try {
      const systemArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const indicatorArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const top: number = px2vp(systemArea.topRect.height);
      const bottom: number = px2vp(Math.max(indicatorArea.bottomRect.height, systemArea.bottomRect.height));
      AppStorage.setOrCreate<number>('statusBarHeight', top > 0 ? top : 0);
      AppStorage.setOrCreate<number>('bottomSafeHeight', bottom > 0 ? bottom : 0);
    } catch (err) {
      hilog.error(DOMAIN, 'SourceTime', 'Failed to read avoid area. Cause: %{public}s', JSON.stringify(err));
      AppStorage.setOrCreate<number>('statusBarHeight', 0);
      AppStorage.setOrCreate<number>('bottomSafeHeight', 0);
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // newConfig.colorMode 同为可选值，未携带时保持当前色深不变
    const nextColorMode: ConfigurationConstant.ColorMode | undefined = newConfig.colorMode;
    if (nextColorMode !== undefined) {
      initGlassTheme(nextColorMode);
      // 主题切换后状态栏图标要跟着改色，否则浅色底上会出现白色图标
      this.applySystemBarColors();
    }
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Configuration updated, color mode synced.');
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'SourceTime', '%{public}s', 'Ability onBackground');
  }
}
