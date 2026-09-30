import { TotpService } from '../service/TotpService';
import { calculateRemainingSeconds, nowMilliseconds } from '../utils/TimeUtils';
import { TotpAlgorithm } from '../model/TotpItem';
import { RingCountdown } from './CountDown';
import {
  avatarGradientColors,
  avatarShadow,
  cardMaterial,
  codeGradientColors,
  countdownStage,
  CountdownStage,
  glassCardShadow,
  glowButtonShadow,
  noShadow,
  particleColorRange,
  supportsImmersive,
  trackGradientColors
} from '../theme/GlassStyle';

const COPY_PARTICLE_DURATION: number = 800;
const REFRESH_PARTICLE_DURATION: number = 900;

/**
 * 首页动态口令卡片（鸿蒙 7 冰晶材质版）。
 *
 * 视觉层级：冰晶卡片底 → 双色柔光微立体图标 → 高对比字重口令 → 环形呼吸倒计时。
 * 反馈层级：点击复制触发柔光粒子，倒计时归零（口令刷新）触发刷新粒子。
 */
@Component
export struct TotpCard {
  @Prop issuer: string = '';
  @Prop account: string = '';
  @Prop secret: string = '';
  @Prop algorithm: TotpAlgorithm = 'SHA1';
  @Prop digits: 6 | 8 = 6;
  @Prop period: number = 30;
  @Prop index: number = 0;
  @State remaining: number = 30;
  @State code: string = '';
  @State copyParticleActive: boolean = false;
  @State refreshParticleActive: boolean = false;
  @State appeared: boolean = false;
  onCopy: () => void = () => {};
  onDelete: () => void = () => {};

  private totpService: TotpService = new TotpService();
  private timerId: number = -1;
  private copyParticleTimerId: number = -1;
  private refreshParticleTimerId: number = -1;
  private appearTimerId: number = -1;
  private lastWindowKey: number = -1;

  aboutToAppear(): void {
    this.remaining = this.period > 0 ? this.period : 30;
    this.tick();
    this.timerId = setInterval(() => {
      this.tick();
    }, 1000);
    // 3D 空间层级的入场：自下方轻微抬升并淡入，按索引错峰
    this.appearTimerId = setTimeout(() => {
      this.appeared = true;
      this.appearTimerId = -1;
    }, 30 + Math.min(this.index, 6) * 45);
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
    if (this.refreshParticleTimerId >= 0) {
      clearTimeout(this.refreshParticleTimerId);
      this.refreshParticleTimerId = -1;
    }
    if (this.appearTimerId >= 0) {
      clearTimeout(this.appearTimerId);
      this.appearTimerId = -1;
    }
  }

  private tick(): void {
    const nowMs: number = nowMilliseconds();
    const nowSeconds: number = Math.floor(nowMs / 1000);
    const windowKey: number = this.period > 0 ? Math.floor(nowSeconds / this.period) : -1;
    if (windowKey !== this.lastWindowKey) {
      const isRefresh: boolean = this.lastWindowKey !== -1;
      this.lastWindowKey = windowKey;
      this.code = this.generateCode(nowSeconds);
      if (isRefresh) {
        this.triggerRefreshParticle();
      }
    }
    this.remaining = calculateRemainingSeconds(nowMs, this.period);
  }

  private generateCode(nowSeconds: number): string {
    const result = this.totpService.generate({
      secret: this.secret,
      algorithm: this.algorithm,
      digits: this.digits,
      period: this.period,
      timestamp: nowSeconds
    });
    if (result.success && result.data !== undefined) {
      return result.data;
    }
    return '';
  }

  private avatarKey(): string {
    if (this.issuer.length > 0) {
      return this.issuer;
    }
    if (this.account.length > 0) {
      return this.account;
    }
    return 'SourceTime';
  }

  private avatarLetter(): string {
    return this.avatarKey().substring(0, 1).toUpperCase();
  }

  /** 0=常规 1=琥珀预警（≤8s） 2=红色危险（≤3s）。 */
  private stage(): CountdownStage {
    return countdownStage(this.remaining);
  }

  /** 是否使用 HarmonyOS 26 沉浸式系统材质（读取屏后真实像素），否则走自绘冰晶降级。 */
  private immersive(): boolean {
    return supportsImmersive();
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
    }, COPY_PARTICLE_DURATION);
  }

  private triggerRefreshParticle(): void {
    this.refreshParticleActive = true;
    if (this.refreshParticleTimerId >= 0) {
      clearTimeout(this.refreshParticleTimerId);
    }
    this.refreshParticleTimerId = setTimeout(() => {
      this.refreshParticleActive = false;
      this.refreshParticleTimerId = -1;
    }, REFRESH_PARTICLE_DURATION);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 8 }) {
        // ---- 层级一：发行方 + 账号 + 环形倒计时（唯一时间指示，不再叠加光轨） ----
        Row({ space: 10 }) {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.avatarLetter())
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
          .width(36)
          .height(36)
          .borderRadius(12)
          .linearGradient({ angle: 145, colors: avatarGradientColors(this.avatarKey()) })
          .border({ width: 1, color: $r('app.color.card_highlight'), style: BorderStyle.Solid })
          .shadow(avatarShadow())

          Column({ space: 2 }) {
            Text(this.issuer.length > 0 ? this.issuer : '未命名')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.account.length > 0 ? this.account : '未填写账号')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          RingCountdown({
            remaining: this.remaining,
            period: this.period,
            ringSize: 42,
            showText: true
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // ---- 层级二：更大口令字号 + 紧凑触感复制胶囊键 ----
        Row() {
          Text(this.formatCode(this.code))
            .fontSize(38)
            .fontWeight(FontWeight.Bold)
            // 流光口令：shaderStyle 优先级高于 fontColor，fontColor 作为兜底
            .fontColor($r('app.color.text_primary'))
            .shaderStyle(new LinearGradientStyle({
              angle: 90,
              colors: codeGradientColors(this.stage())
            }))
            .letterSpacing(2)
            // 表格数字：每位数字等宽，口令刷新时不会因字宽差异产生跳动
            .fontFeature('"tnum" on')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Stack({ alignContent: Alignment.Center }) {
            Button('复制')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .height(34)
              .padding({ left: 16, right: 16 })
              .borderRadius(17)
              .linearGradient({ angle: 90, colors: trackGradientColors(0) })
              .fontColor($r('app.color.fab_foreground'))
              .shadow(glowButtonShadow())
              .onClick(() => {
                this.triggerCopyParticle();
                this.onCopy();
              })

            if (this.copyParticleActive) {
              Particle({
                particles: [
                  {
                    emitter: {
                      particle: {
                        type: ParticleType.POINT,
                        config: { radius: 2 },
                        count: 26,
                        lifetime: COPY_PARTICLE_DURATION,
                        lifetimeRange: 200
                      },
                      // 一次性爆发：提高发射速率让全部粒子在同一帧内散出
                      emitRate: 500,
                      shape: ParticleEmitterShape.CIRCLE,
                      position: [0, 0],
                      size: [4, 4]
                    },
                    color: { range: particleColorRange() },
                    opacity: { range: [0.6, 1.0] },
                    scale: { range: [0.2, 0.6] },
                    velocity: { angle: [0, 360], speed: [90, 190] },
                    acceleration: { angle: { range: [90, 90] }, speed: { range: [30, 60] } }
                  }
                ]
              })
              .width(100)
              .height(100)
              .hitTestBehavior(HitTestMode.Transparent)
            }
          }
          .width(80)
          .height(36)
          .clip(false)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      // 刷新粒子：作为浮层叠在卡片上，不参与布局（早先作为 Column 子元素会让卡片在归零瞬间变高再缩回）
      if (this.refreshParticleActive) {
        Particle({
          particles: [
            {
              emitter: {
                particle: {
                  type: ParticleType.POINT,
                  config: { radius: 1.6 },
                  count: 18,
                  lifetime: REFRESH_PARTICLE_DURATION,
                  lifetimeRange: 240
                },
                emitRate: 500,
                shape: ParticleEmitterShape.RECTANGLE,
                position: [0, 0],
                size: [200, 8]
              },
              color: { range: particleColorRange() },
              opacity: { range: [0.35, 0.85] },
              scale: { range: [0.15, 0.5] },
              velocity: { angle: [-120, -60], speed: [30, 80] },
              acceleration: { angle: { range: [-90, -90] }, speed: { range: [40, 80] } }
            }
          ]
        })
        .width('100%')
        .height(14)
        .align(Alignment.BottomStart)
        .margin({ bottom: 4 })
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .width('100%')
    .borderRadius(20)
    // 视觉层级：优先 HarmonyOS 26 沉浸式系统材质，并叠加发光微边框与轻量阴影
    .systemMaterial(cardMaterial(this.immersive()))
    .backgroundColor(this.immersive() ? Color.Transparent : $r('app.color.card_background'))
    .backgroundBlurStyle(this.immersive() ? BlurStyle.NONE : BlurStyle.COMPONENT_THICK)
    .border({
      width: 1.5,
      color: $r('app.color.card_border'),
      style: BorderStyle.Solid
    })
    .shadow(glassCardShadow())
    .opacity(this.appeared ? 1.0 : 0.0)
    .translate({ y: this.appeared ? 0 : 12 })
    .animation({ duration: 300, curve: Curve.FastOutSlowIn })
    .onClick(() => this.onCopy())
    .gesture(LongPressGesture().onAction(() => this.onDelete()))
  }
}
