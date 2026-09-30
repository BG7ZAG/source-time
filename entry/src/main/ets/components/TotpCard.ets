import { TotpService } from '../service/TotpService';
import { calculateRemainingSeconds, nowMilliseconds } from '../utils/TimeUtils';
import { TotpAlgorithm } from '../model/TotpItem';

@Component
export struct TotpCard {
  @Prop issuer: string = '';
  @Prop account: string = '';
  @Prop secret: string = '';
  @Prop algorithm: TotpAlgorithm = 'SHA1';
  @Prop digits: 6 | 8 = 6;
  @Prop period: number = 30;
  @State remaining: number = 30;
  @State code: string = '';
  @State copyParticleActive: boolean = false;
  onCopy: () => void = () => {};
  onDelete: () => void = () => {};

  private totpService: TotpService = new TotpService();
  private timerId: number = -1;
  private copyParticleTimerId: number = -1;

  aboutToAppear(): void {
    this.remaining = calculateRemainingSeconds(nowMilliseconds(), this.period);
    this.code = this.generateCode();
    this.timerId = setInterval(() => {
      const newRemaining: number = calculateRemainingSeconds(nowMilliseconds(), this.period);
      if (newRemaining > this.remaining) {
        this.code = this.generateCode();
      }
      this.remaining = newRemaining;
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.copyParticleTimerId >= 0) {
      clearTimeout(this.copyParticleTimerId);
      this.copyParticleTimerId = -1;
    }
  }

  private generateCode(): string {
    const result = this.totpService.generate({
      secret: this.secret,
      algorithm: this.algorithm,
      digits: this.digits,
      period: this.period,
      timestamp: Math.floor(nowMilliseconds() / 1000)
    });
    if (result.success && result.data !== undefined) {
      return result.data;
    }
    return '';
  }

  private formatCode(code: string): string {
    if (code.length === 6) {
      return code.substring(0, 3) + ' ' + code.substring(3);
    }
    if (code.length === 8) {
      return code.substring(0, 4) + ' ' + code.substring(4);
    }
    return code;
  }

  private triggerCopyParticle(): void {
    this.copyParticleActive = true;
    if (this.copyParticleTimerId >= 0) {
      clearTimeout(this.copyParticleTimerId);
    }
    this.copyParticleTimerId = setTimeout(() => {
      this.copyParticleActive = false;
      this.copyParticleTimerId = -1;
    }, 800);
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.issuer)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Text(this.remaining.toString() + 's')
          .fontSize(12)
          .fontColor(this.remaining <= 5 ? $r('app.color.danger') : $r('app.color.text_secondary'))
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(10)
          .backgroundColor($r('app.color.scrim'))
      }
      .width('100%')

      Text(this.account)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Row() {
        Text(this.formatCode(this.code))
          .fontSize(32)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Stack() {
          Button('复制')
            .fontSize(12)
            .height(32)
            .borderRadius(16)
            .backgroundColor($r('app.color.brand_container'))
            .fontColor($r('app.color.brand_on_container'))
            .onClick(() => {
              this.triggerCopyParticle();
              this.onCopy();
            })

          if (this.copyParticleActive) {
            Particle({
              particles: [{
                emitter: {
                  particle: {
                    type: ParticleType.POINT,
                    config: { radius: 1 },
                    count: 8,
                    lifetime: 800
                  },
                  shape: ParticleEmitterShape.CIRCLE,
                  position: [30, 16],
                  size: [1, 1]
                },
                velocity: {
                  angle: [0, 360],
                  speed: [40, 80]
                },
                acceleration: {
                  angle: { range: [90, 90] },
                  speed: { range: [10, 20] }
                },
                color: { range: ['#3D7DF7', '#6ED0FF'] },
                opacity: { range: [0.5, 0.9] },
                scale: { range: [0.1, 0.3] }
              }]
            })
            .width(60)
            .height(32)
            .hitTestBehavior(HitTestMode.Transparent)
          }
        }
        .width(60)
        .height(32)
        .clip(false)
      }
      .width('100%')

      Progress({ value: this.remaining, total: this.period, type: ProgressType.Linear })
        .width('100%')
        .height(2)
        .color(this.remaining <= 5 ? $r('app.color.danger') : $r('app.color.brand'))
        .backgroundColor($r('app.color.divider'))
    }
    .padding(16)
    .width('100%')
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
    .onClick(() => this.onCopy())
    .gesture(LongPressGesture().onAction(() => this.onDelete()))
  }
}