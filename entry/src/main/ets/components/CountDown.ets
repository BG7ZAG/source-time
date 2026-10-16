import {
  countdownStage,
  countdownTextColor,
  CountdownStage,
  trackBaseColor,
  trackGlowColor,
  trackProgressColor
} from '../theme/GlassStyle';

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
