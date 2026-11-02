import { glassGroupShadow } from '../theme/GlassStyle';
import { PinLockOverlay } from './PinLockOverlay';
import { DeviceAdapter } from '../utils/DeviceAdapter';

/** 插槽默认值：@BuilderParam 必须以 @Builder 函数初始化，@Require 会强制父组件传入内容。 */
@Builder
function emptySlot() {
  Column() {
  }
}

/**
 * 沉浸式极光弥散背景。
 *
 * 底层：纵向柔和渐变（空间基调）
 * 上层：多枚超大径向弥散光斑叠加，浅深色各自取色，形成柔光流动的极光底。
 *
 * 用法：
 * ```
 * AuroraBackground() {
 *   Column() { ...页面内容... }
 * }
 * ```
 */
@Component
export struct AuroraBackground {
  /**
   * 内容插槽。父组件以尾随闭包传入：
   * ```
   * AuroraBackground() {
   *   Column() { ...页面内容... }
   * }
   * ```
   */
  @Require @BuilderParam content: () => void = emptySlot;

  /** 顶部状态栏高度（vp），由 EntryAbility 写入 AppStorage。 */
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  /** 底部导航条 / Home 指示条高度（vp），由 EntryAbility 写入 AppStorage。 */
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  /** 应用锁是否处于锁定态，由 EntryAbility 与 PinLockOverlay 共同维护。 */
  @StorageProp('appLocked') appLocked: boolean = false;
  /** 极光光斑缩放比，按设备类型初始化。 */
  @State auroraScaleValue: number = 1.0;

  aboutToAppear(): void {
    this.auroraScaleValue = DeviceAdapter.auroraScale();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 基底渐变：空间纵深。窗口为沉浸式布局，底色铺满整屏（含状态栏与底部导航区）
      Column()
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .linearGradient({
          angle: 180,
          colors: [
            [$r('app.color.page_gradient_start'), 0.0],
            [$r('app.color.page_gradient_mid'), 0.55],
            [$r('app.color.page_gradient_end'), 1.0]
          ]
        })

      this.auroraBlooms()

      // 内容区统一压回安全区：顶部让开状态栏、底部让开导航条/Home 指示条。
      // 水平取居中对齐：页面对内容列设了最大宽度（LayoutConstants），宽屏下由此居中。
      Stack({ alignContent: Alignment.Top }) {
        this.content()
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.statusBarHeight, bottom: this.bottomSafeHeight })

      // 应用锁遮罩置于最上层：锁定期间盖住口令、密钥与配置内容
      if (this.appLocked) {
        PinLockOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 极光光斑：用多段 alpha 衰减的径向渐变模拟高斯弥散。
   * 相比对超大图层做 blur()，这种做法不产生离屏滤镜开销，中低端机型也能稳住帧率。
   * 光斑尺寸按设备类型缩放：手表缩小至 0.4 倍，平板/2in1 放大至 1.3 倍。
   */
  @Builder
  auroraBlooms() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 极光光斑一：左上主色弥散
      Column()
        .width(440 * this.auroraScaleValue)
        .height(440 * this.auroraScaleValue)
        .borderRadius(220 * this.auroraScaleValue)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 220 * this.auroraScaleValue,
          colors: [
            ['#4D8FC0FF', 0.0],
            ['#338FC0FF', 0.35],
            ['#148FC0FF', 0.68],
            ['#008FC0FF', 1.0]
          ]
        })
        .position({ x: '-34%', y: '-8%' })

      // 极光光斑二：右上青色弥散
      Column()
        .width(380 * this.auroraScaleValue)
        .height(380 * this.auroraScaleValue)
        .borderRadius(190 * this.auroraScaleValue)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 190 * this.auroraScaleValue,
          colors: [
            ['#47A9E4FF', 0.0],
            ['#2EA9E4FF', 0.35],
            ['#12A9E4FF', 0.68],
            ['#00A9E4FF', 1.0]
          ]
        })
        .position({ x: '44%', y: '2%' })

      // 极光光斑三：中下紫调弥散
      Column()
        .width(480 * this.auroraScaleValue)
        .height(480 * this.auroraScaleValue)
        .borderRadius(240 * this.auroraScaleValue)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 240 * this.auroraScaleValue,
          colors: [
            ['#3DC6BFFF', 0.0],
            ['#29C6BFFF', 0.35],
            ['#10C6BFFF', 0.68],
            ['#00C6BFFF', 1.0]
          ]
        })
        .position({ x: '-20%', y: '46%' })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
