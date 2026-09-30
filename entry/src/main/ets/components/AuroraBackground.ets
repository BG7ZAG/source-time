import { glassCardShadow, glassGroupShadow } from '../theme/GlassStyle';

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

      // 内容区统一压回安全区：顶部让开状态栏、底部让开导航条/Home 指示条
      Stack({ alignContent: Alignment.TopStart }) {
        this.content()
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.statusBarHeight, bottom: this.bottomSafeHeight })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 极光光斑：用多段 alpha 衰减的径向渐变模拟高斯弥散。
   * 相比对超大图层做 blur()，这种做法不产生离屏滤镜开销，中低端机型也能稳住帧率。
   */
  @Builder
  auroraBlooms() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 极光光斑一：左上主色弥散
      Column()
        .width(440)
        .height(440)
        .borderRadius(220)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 220,
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
        .width(380)
        .height(380)
        .borderRadius(190)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 190,
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
        .width(480)
        .height(480)
        .borderRadius(240)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 240,
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

/**
 * 半透明冰晶卡片容器：
 * 24px 大圆角 + 1px 微发光边缘高光 + 高斯模糊材质 + Z 轴柔和空间阴影。
 *
 * 说明：各页面为控制层级与间距，多数直接内联冰晶样式；此容器用于需要统一包裹的场景。
 */
@Component
export struct GlassCard {
  @Prop cornerRadius: number = 24;
  @Prop paddingSize: number = 16;
  @Prop compact: boolean = false;

  /** 内容插槽，父组件以尾随闭包传入。 */
  @Require @BuilderParam content: () => void = emptySlot;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.paddingSize)
    .borderRadius(this.cornerRadius)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(this.compact ? glassGroupShadow() : glassCardShadow())
  }
}
