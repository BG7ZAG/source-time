import {
  cardMaterial,
  glowButtonShadow,
  interactiveMaterial,
  noShadow,
  supportsImmersive,
  trackGradientColors
} from '../theme/GlassStyle';

/**
 * 空状态：冰晶光环 + 柔光提示，替代旧版虚线方框。
 */
@Component
export struct EmptyState {
  @Prop message: string = '暂无验证码';
  @Prop hint: string = '点击右下角悬浮球添加';
  @State breathing: boolean = false;

  aboutToAppear(): void {
    this.breathing = true;
  }

  private immersive(): boolean {
    return supportsImmersive();
  }

  build() {
    Column({ space: 18 }) {
      Stack({ alignContent: Alignment.Center }) {
        // 外层弥散光晕
        Column()
          .width(132)
          .height(132)
          .borderRadius(66)
          .radialGradient({
            center: ['50%', '50%'],
            radius: 66,
            colors: [['#3D0A59F7', 0.0], ['#000A59F7', 1.0]]
          })
          .scale({ x: this.breathing ? 1.06 : 0.94, y: this.breathing ? 1.06 : 0.94 })
          .animation({ duration: 2200, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })

        // 冰晶光环（优先使用系统沉浸式材质）
        Column()
          .width(104)
          .height(104)
          .borderRadius(52)
          .systemMaterial(cardMaterial(this.immersive()))
          .backgroundColor(this.immersive() ? Color.Transparent : $r('app.color.card_background'))
          .backgroundBlurStyle(this.immersive() ? BlurStyle.NONE : BlurStyle.COMPONENT_THICK)
          .border({
            width: this.immersive() ? 0 : 1,
            color: $r('app.color.card_border'),
            style: BorderStyle.Solid
          })
          .shadow(this.immersive() ? noShadow() : glowButtonShadow())

        // 渐变加号
        Text('＋')
          .fontSize(38)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand'))
      }
      .width(132)
      .height(132)

      Column({ space: 6 }) {
        Text(this.message)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
        Text(this.hint)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * 悬浮光效球（FAB）：能量渐变 + 环绕光晕 + 点击粒子爆发。
 */
@Component
export struct GlowFab {
  @Prop label: string = '＋';
  // 注意：不要命名为 size，会与 ArkUI 通用属性 size(value: SizeOptions) 冲突，
  // 编译报「Property 'size' in type 'GlowFab' is not assignable to the same property in base type 'CustomComponent'」。
  @Prop diameter: number = 58;
  @State particleActive: boolean = false;
  @State haloBreathing: boolean = false;
  onTap: () => void = () => {};

  private particleTimerId: number = -1;

  aboutToAppear(): void {
    this.haloBreathing = true;
  }

  aboutToDisappear(): void {
    if (this.particleTimerId >= 0) {
      clearTimeout(this.particleTimerId);
      this.particleTimerId = -1;
    }
  }

  /** 是否启用 HarmonyOS 26 沉浸式系统材质。 */
  private immersive(): boolean {
    return supportsImmersive();
  }

  private burst(): void {
    this.particleActive = true;
    if (this.particleTimerId >= 0) {
      clearTimeout(this.particleTimerId);
    }
    this.particleTimerId = setTimeout(() => {
      this.particleActive = false;
      this.particleTimerId = -1;
    }, 900);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 环绕呼吸光晕
      Column()
        .width(this.diameter + 16)
        .height(this.diameter + 16)
        .borderRadius((this.diameter + 16) / 2)
        .backgroundColor($r('app.color.glow'))
        .opacity(this.haloBreathing ? 0.85 : 0.35)
        .animation({ duration: 1800, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })

      Button(this.label)
        .type(ButtonType.Circle)
        .width(this.diameter)
        .height(this.diameter)
        .fontSize(26)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.fab_foreground'))
        .linearGradient({ angle: 135, colors: trackGradientColors(0) })
        .border({ width: 1, color: $r('app.color.card_highlight'), style: BorderStyle.Solid })
        .shadow(glowButtonShadow())
        .onClick(() => {
          this.burst();
          this.onTap();
        })

      // 系统沉浸式材质层：叠加在能量渐变之上，提供读取屏后像素的折射高光、按压形变与光感反馈
      Column()
        .width(this.diameter)
        .height(this.diameter)
        .borderRadius(this.diameter / 2)
        .systemMaterial(interactiveMaterial(this.immersive()))
        .hitTestBehavior(HitTestMode.Transparent)

      if (this.particleActive) {
        Particle({
          particles: [
            {
              emitter: {
                particle: {
                  type: ParticleType.POINT,
                  config: { radius: 2 },
                  count: 28,
                  lifetime: 900,
                  lifetimeRange: 240
                },
                emitRate: 500,
                shape: ParticleEmitterShape.CIRCLE,
                // 粒子画布为 (diameter + 90) 见方、光球居中，故发射原点取画布中心
                position: [(this.diameter + 90) / 2, (this.diameter + 90) / 2],
                size: [this.diameter, this.diameter]
              },
              // 定长二元组：ArkUI 的 ParticleTuple<ResourceColor, ResourceColor> 要求恰好两项
              color: { range: ['#FFFFFF', '#64B5F6'] },
              opacity: { range: [0.5, 1.0] },
              scale: { range: [0.2, 0.7] },
              velocity: { angle: [0, 360], speed: [100, 200] },
              acceleration: { angle: { range: [90, 90] }, speed: { range: [30, 60] } }
            }
          ]
        })
        .width(this.diameter + 90)
        .height(this.diameter + 90)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width(this.diameter + 90)
    .height(this.diameter + 90)
  }
}
