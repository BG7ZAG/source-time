import {
  countdownStage,
  countdownTextColor,
  CountdownStage,
  particleColorRange,
  trackBaseColor,
  trackGlowColor,
  trackGradientColors,
  trackProgressColor
} from '../theme/GlassStyle';

/**
 * 光点生命周期曲线：先快速点亮再缓慢淡出。
 * 显式声明为 ParticlePropertyAnimation<number>[]，避免嵌套对象字面量在
 * Particle 泛型推断下丢失 from/to 的类型信息。
 */
const SPARKLE_OPACITY_CURVE: ParticlePropertyAnimation<number>[] = [
  { from: 0.0, to: 0.8, startMillis: 0, endMillis: 260, curve: Curve.EaseOut },
  { from: 0.8, to: 0.0, startMillis: 260, endMillis: 1200, curve: Curve.EaseIn }
];

const SPARKLE_SCALE_CURVE: ParticlePropertyAnimation<number>[] = [
  { from: 0.2, to: 0.9, startMillis: 0, endMillis: 500, curve: Curve.EaseOut }
];

/**
 * 环形呼吸倒计时。
 *
 * 替代旧版底部粗直角进度条：以圆环进度 + 内圈柔光表达剩余时间，
 * 剩余 5 秒内自动切换为危险色并加强呼吸幅度。
 */
@Component
export struct RingCountdown {
  @Prop @Watch('onRemainingChange') remaining: number = 30;
  @Prop period: number = 30;
  @Prop ringSize: number = 44;
  @Prop showText: boolean = true;
  @State breathing: boolean = false;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private breathTimerId: number = -1;

  aboutToAppear(): void {
    this.syncBreathing();
  }

  aboutToDisappear(): void {
    if (this.breathTimerId >= 0) {
      clearInterval(this.breathTimerId);
      this.breathTimerId = -1;
    }
  }

  /** 剩余时间变化时：重绘进度弧，并在最后 3 秒开启呼吸节奏。 */
  onRemainingChange(): void {
    this.draw();
    this.syncBreathing();
  }

  private syncBreathing(): void {
    if (this.stage() === 2 && this.breathTimerId < 0) {
      this.breathTimerId = setInterval(() => {
        this.breathing = !this.breathing;
      }, 780);
    } else if (this.stage() !== 2 && this.breathTimerId >= 0) {
      clearInterval(this.breathTimerId);
      this.breathTimerId = -1;
      this.breathing = false;
    }
  }

  /** 0=常规 1=琥珀预警（≤8s） 2=红色危险（≤3s）。 */
  private stage(): CountdownStage {
    return countdownStage(this.remaining);
  }

  private strokeWidth(): number {
    return this.ringSize <= 30 ? 2.5 : (this.ringSize <= 44 ? 3.5 : 4.5);
  }

  private draw(): void {
    if (!this.ready || this.ctx === undefined) {
      return;
    }
    const size: number = this.ringSize;
    const center: number = size / 2;
    const lineWidth: number = this.strokeWidth();
    const radius: number = center - lineWidth / 2 - 0.5;

    this.ctx.clearRect(0, 0, size, size);

    // 轨道
    this.ctx.beginPath();
    this.ctx.lineWidth = lineWidth;
    this.ctx.lineCap = 'round';
    this.ctx.strokeStyle = trackBaseColor();
    this.ctx.arc(center, center, radius, 0, Math.PI * 2);
    this.ctx.stroke();

    // 进度弧：自 12 点方向顺时针收束
    const ratio: number = this.period > 0 ? Math.min(1, Math.max(0, this.remaining / this.period)) : 0;
    if (ratio <= 0) {
      return;
    }
    const start: number = -Math.PI / 2;
    const end: number = start + Math.PI * 2 * ratio;

    // 内圈柔光：更宽的低透明度同色弧，营造呼吸光感
    this.ctx.beginPath();
    this.ctx.lineWidth = lineWidth * 2.4;
    this.ctx.lineCap = 'round';
    this.ctx.strokeStyle = trackGlowColor(this.stage());
    this.ctx.arc(center, center, radius, start, end);
    this.ctx.stroke();

    // 进度主体
    this.ctx.beginPath();
    this.ctx.lineWidth = lineWidth;
    this.ctx.lineCap = 'round';
    this.ctx.strokeStyle = trackProgressColor(this.stage());
    this.ctx.arc(center, center, radius, start, end);
    this.ctx.stroke();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Canvas(this.ctx)
        .width(this.ringSize)
        .height(this.ringSize)
        .onReady(() => {
          this.ready = true;
          this.draw();
        })

      if (this.showText) {
        Text(this.remaining.toString())
          .fontSize(this.ringSize <= 30 ? 12 : (this.ringSize <= 44 ? 14 : 16))
          .fontWeight(FontWeight.Medium)
          .fontFeature('"tnum" on')
          .fontColor(countdownTextColor(this.stage()))
          // HarmonyOS 20+ 数字翻牌过渡：秒数变化时逐位滚动，替代生硬的数字跳变
          .contentTransition(new NumericTextTransition({
            flipDirection: FlipDirection.DOWN,
            enableBlur: true
          }))
      }
    }
    .width(this.ringSize)
    .height(this.ringSize)
    .scale({
      x: this.stage() === 2 && this.breathing ? 1.045 : 1.0,
      y: this.stage() === 2 && this.breathing ? 1.045 : 1.0
    })
    .animation({ duration: 780, curve: Curve.EaseInOut })
  }
}

/**
 * 动态弥散光轨：沿卡片底部流动的能量进度条。
 *
 * 旧版是 3px 直角蓝色实线，这里改为渐变填充 + 呼吸光晕的胶囊光轨，
 * 并在光轨前沿持续逸出细密光点，形成「沿卡片边缘流动的光轨」。
 */
@Component
export struct LightRail {
  @Prop remaining: number = 30;
  @Prop period: number = 30;
  @Prop railHeight: number = 6;
  /** 是否在光轨前沿逸出光点（每张卡片常驻粒子开销较大，按需开启）。 */
  @Prop sparkle: boolean = false;

  private stage(): CountdownStage {
    return countdownStage(this.remaining);
  }

  private ratioPercent(): string {
    if (this.period <= 0) {
      return '0%';
    }
    const ratio: number = Math.min(1, Math.max(0, this.remaining / this.period));
    return (ratio * 100).toFixed(2) + '%';
  }

  private glowColor(): string {
    if (this.stage() === 2) {
      return '#59FF3B30';
    }
    if (this.stage() === 1) {
      return '#59FF9500';
    }
    return '#590A59F7';
  }

  build() {
    // 光轨居中放置，上下留出光点逸散区域；emitRate 为 0 时（sparkle 关闭）无任何粒子开销
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(this.railHeight)
          .borderRadius(this.railHeight)
          .backgroundColor($r('app.color.glass_track'))

        Column()
          .width(this.ratioPercent())
          .height(this.railHeight)
          .borderRadius(this.railHeight)
          .linearGradient({
            angle: 90,
            colors: trackGradientColors(this.stage())
          })
          .shadow({
            radius: 8,
            color: this.glowColor(),
            offsetX: 0,
            offsetY: 0
          })
          .animation({ duration: 280, curve: Curve.EaseOut })
      }
      .width('100%')
      .height(this.railHeight)

      if (this.sparkle) {
        Particle({
          particles: [
            {
              emitter: {
                particle: {
                  type: ParticleType.POINT,
                  config: { radius: 1.1 },
                  count: -1,
                  lifetime: 1200,
                  lifetimeRange: 400
                },
                emitRate: 26,
                // 发射带与光轨等宽等高且同层居中，故取画布坐标原点即可贴合光轨
                shape: ParticleEmitterShape.RECTANGLE,
                position: [0, 0],
                size: [360, 1]
              },
              color: { range: particleColorRange() },
              opacity: {
                range: [0.35, 0.75],
                updater: {
                  type: ParticleUpdater.CURVE,
                  config: SPARKLE_OPACITY_CURVE
                }
              },
              scale: {
                range: [0.5, 1.0],
                updater: {
                  type: ParticleUpdater.CURVE,
                  config: SPARKLE_SCALE_CURVE
                }
              },
              velocity: { angle: [-108, -72], speed: [12, 30] }
            }
          ]
        })
        .width('100%')
        .height(this.railHeight)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height(this.sparkle ? 46 : this.railHeight)
  }
}
