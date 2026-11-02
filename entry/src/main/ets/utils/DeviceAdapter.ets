import { deviceInfo } from '@kit.BasicServicesKit';
import { pointer } from '@kit.InputKit';
import { CursorController } from '@kit.ArkUI';

/**
 * 设备类型枚举。
 */
export enum DeviceCategory {
  WATCH = 'watch',
  PHONE = 'phone',
  TABLET = 'tablet',
  TWO_IN_ONE = '2in1'
}

/**
 * 多平台设备适配工具。
 *
 * 基于 deviceInfo.deviceType 检测设备类型，为各组件提供响应式布局参数：
 * - 手表：精简 UI（仅验证码显示），缩小字号/尺寸，禁用粒子动画
 * - 手机：标准 UI，完整功能
 * - 平板：宽屏双列布局，放大标题字号
 * - 2in1：桌面交互模式（hover/cursor/键盘）
 */
export class DeviceAdapter {
  private static category: DeviceCategory = DeviceAdapter.detectCategory();

  private static detectCategory(): DeviceCategory {
    const type: string = deviceInfo.deviceType;
    if (type === 'wearable') {
      return DeviceCategory.WATCH;
    }
    if (type === 'tablet') {
      return DeviceCategory.TABLET;
    }
    if (type === '2in1') {
      return DeviceCategory.TWO_IN_ONE;
    }
    return DeviceCategory.PHONE;
  }

  /** 获取设备类型分类。 */
  static getCategory(): DeviceCategory {
    return DeviceAdapter.category;
  }

  static isWatch(): boolean {
    return DeviceAdapter.category === DeviceCategory.WATCH;
  }

  static isTablet(): boolean {
    return DeviceAdapter.category === DeviceCategory.TABLET;
  }

  static is2in1(): boolean {
    return DeviceAdapter.category === DeviceCategory.TWO_IN_ONE;
  }

  static isPhone(): boolean {
    return DeviceAdapter.category === DeviceCategory.PHONE;
  }

  /** 是否为宽屏设备（平板/2in1）。 */
  static isWideScreen(): boolean {
    return DeviceAdapter.isTablet() || DeviceAdapter.is2in1();
  }

  // ---- 功能开关 ----

  /** 是否支持粒子动画（手表不支持，性能受限）。 */
  static supportsParticle(): boolean {
    return !DeviceAdapter.isWatch();
  }

  /** 是否支持 hover 交互（2in1 鼠标输入）。 */
  static supportsHover(): boolean {
    return DeviceAdapter.is2in1();
  }

  /** 是否显示完整功能（手表仅显示验证码）。 */
  static showFullFeatures(): boolean {
    return !DeviceAdapter.isWatch();
  }

  /** 是否支持左滑删除（手表屏幕小，不适合滑动手势）。 */
  static supportsSwipeDelete(): boolean {
    return !DeviceAdapter.isWatch();
  }

  /** 是否显示悬浮按钮（手表空间有限）。 */
  static showFab(): boolean {
    return !DeviceAdapter.isWatch();
  }

  // ---- 布局参数 ----

  /** 页面内容区最大宽度（vp）。 */
  static contentMaxWidth(): number {
    if (DeviceAdapter.isWatch()) {
      return 200;
    }
    return 680;
  }

  /**
   * 表单主按钮宽度。
   *
   * 手机/手表铺满整行（拇指容易够到）；平板与 2in1 上限制到 320vp 并居中，
   * 否则卡片宽 600+vp 时按钮会被拉成一根又长又扁的胶囊，点击目标反而不好看。
   */
  static formButtonWidth(): Length {
    if (DeviceAdapter.isWideScreen()) {
      return 320;
    }
    return '100%';
  }

  /** 口令字号。 */
  static codeFontSize(): number {
    if (DeviceAdapter.isWatch()) {
      return 22;
    }
    return 38;
  }

  /** 标题字号。 */
  static titleFontSize(): number {
    if (DeviceAdapter.isWatch()) {
      return 18;
    }
    if (DeviceAdapter.isWideScreen()) {
      return 30;
    }
    return 27;
  }

  /** 副标题字号。 */
  static subtitleFontSize(): number {
    if (DeviceAdapter.isWatch()) {
      return 10;
    }
    return 12;
  }

  /** FAB 直径。 */
  static fabDiameter(): number {
    if (DeviceAdapter.isWatch()) {
      return 36;
    }
    return 58;
  }

  /** 卡片内边距。 */
  static cardPadding(): number {
    if (DeviceAdapter.isWatch()) {
      return 8;
    }
    return 14;
  }

  /** 列表间距。 */
  static listSpacing(): number {
    if (DeviceAdapter.isWatch()) {
      return 6;
    }
    return 14;
  }

  /** 头像尺寸。 */
  static avatarSize(): number {
    if (DeviceAdapter.isWatch()) {
      return 28;
    }
    return 36;
  }

  /** 环形倒计时尺寸。 */
  static ringSize(): number {
    if (DeviceAdapter.isWatch()) {
      return 32;
    }
    return 42;
  }

  /** 复制按钮高度。 */
  static copyButtonHeight(): number {
    if (DeviceAdapter.isWatch()) {
      return 28;
    }
    return 34;
  }

  /** 极光光斑尺寸缩放比。 */
  static auroraScale(): number {
    if (DeviceAdapter.isWatch()) {
      return 0.4;
    }
    if (DeviceAdapter.isWideScreen()) {
      return 1.3;
    }
    return 1.0;
  }

  /** 卡片圆角。 */
  static cardRadius(): number {
    if (DeviceAdapter.isWatch()) {
      return 14;
    }
    return 20;
  }

  /** 页面水平内边距。 */
  static pagePaddingH(): number {
    if (DeviceAdapter.isWatch()) {
      return 8;
    }
    return 16;
  }

  /** 是否使用双列网格布局（平板/2in1 且口令数量足够时）。 */
  static useGridLayout(): boolean {
    return DeviceAdapter.isWideScreen();
  }

  // ---- 2in1 光标适配 ----

  /**
   * 在 onHover 回调中设置鼠标光标样式。
   *
   * 仅 2in1 设备生效：hover 时显示 POINTER（手形）光标，移出时恢复默认。
   * 其他设备调用此方法无任何效果。
   *
   * 用法：
   * ```
   * .onHover((isHover: boolean) => {
   *   DeviceAdapter.applyHoverCursor(this.getUIContext().getCursorController(), isHover);
   * })
   * ```
   */
  static applyHoverCursor(controller: CursorController, isHover: boolean): void {
    if (!DeviceAdapter.is2in1()) {
      return;
    }
    if (isHover) {
      controller.setCursor(pointer.PointerStyle.EAST);
    } else {
      controller.restoreDefault();
    }
  }
}
