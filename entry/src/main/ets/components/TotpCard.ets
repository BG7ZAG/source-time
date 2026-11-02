import { TotpService } from '../service/TotpService';
import { calculateRemainingSeconds, nowMilliseconds } from '../utils/TimeUtils';
import { TotpAlgorithm } from '../model/TotpItem';
import { RingCountdown } from './CountDown';
import { DeviceAdapter } from '../utils/DeviceAdapter';
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

/** 删除「粒子消散」动画时长；父层（首页）也按此时长延迟真正移除数据。 */
export const DELETE_ANIM_DURATION: number = 500;

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
  /** 由父层驱动：为 true 时卡片执行「粒子消散」删除动画并淡出。 */
  @Prop deleting: boolean = false;
  /** 由父层驱动：为 true 时在「⋯」按钮旁展开重命名 / 删除气泡。 */
  @Prop menuVisible: boolean = false;
  onCopy: () => void = () => {};
  /** 点右上角「⋯」：由父层打开重命名 / 删除气泡。 */
  onMore: () => void = () => {};
  /** 气泡被点空白处收起时通知父层同步状态。 */
  onMenuDismiss: () => void = () => {};
  /**
   * 气泡内容由父层提供（文案与动作都在父层）。
   *
   * 之所以把气泡挂在这里而不是卡片外层：气泡的定位基准是「挂载它的那个组件」。
   * 挂在整张卡片上时 BottomRight 会按卡片右下角对齐，气泡掉到卡片下方、
   * 和三个点完全脱节；挂到 40vp 的按钮上，气泡才会贴着三个点展开。
   */
  @BuilderParam menuBuilder: () => void = this.emptyMenu;

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

  /** 剩余比例（0–100），给底部进度条用。 */
  private progressPercent(): string {
    if (this.period <= 0) {
      return '0%';
    }
    const ratio: number = Math.max(0, Math.min(1, this.remaining / this.period));
    return (ratio * 100).toFixed(1) + '%';
  }

  /** menuBuilder 的占位实现：父层没传内容时气泡里什么都不画。 */
  @Builder
  emptyMenu() {
    Column().width(0).height(0)
  }

  /**
   * 气泡外观：贴着「⋯」按钮右下方展开，右边缘与按钮对齐、向左铺开 108vp，
   * 这样它始终跟着三个点走，不会飘到卡片底部或压住下一张卡。
   */
  private moreMenuOptions(): CustomPopupOptions {
    return {
      // 惰性求值：直接写 this.menuBuilder() 会在 build() 里被立即执行，
      // 菜单内容会被内联渲染进卡片本身。
      builder: () => {
        this.menuBuilder();
      },
      placement: Placement.BottomRight,
      offset: { x: 0, y: 6 },
      popupColor: $r('app.color.menu_background'),
      enableArrow: false,
      radius: 16,
      shadow: ShadowStyle.OUTER_DEFAULT_MD,
      autoCancel: true,
      onStateChange: (event: PopupStateChangeParam) => {
        if (!event.isVisible) {
          this.onMenuDismiss();
        }
      }
    };
  }

  /** 右上角「⋯」：打开重命名 / 删除气泡，替代原来占位最大的环形倒计时。 */
  @Builder
  moreButton() {
    // 外层 40vp 是透明热区，内层 32vp 才是可见的圆点：
    // 平板上 32vp 的点击目标偏小，容易点空或误触卡片复制。
    // （曾用 responseRegion 扩热区，实测反而让整个按钮点不动，改用容器撑大）
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Center }) {
        Row({ space: 3 }) {
          Circle().width(3.6).height(3.6).fill($r('app.color.more_icon'))
          Circle().width(3.6).height(3.6).fill($r('app.color.more_icon'))
          Circle().width(3.6).height(3.6).fill($r('app.color.more_icon'))
        }
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .backgroundColor($r('app.color.pill_background'))
    }
    .width(40)
    .height(40)
    .onClick(() => this.onMore())
    // 气泡挂在这个 40vp 按钮上，定位基准才是三个点本身
    .bindPopup(this.menuVisible, this.moreMenuOptions())
  }

  /**
   * 底部倒计时横条：左边一根会随剩余时间收缩的进度条，右边是「18s」。
   *
   * 各条目周期可能不同（otpauth 可带 period，手动录入也能改），
   * 所以倒计时只能跟着卡片走，不能合并成列表顶部一条。
   */
  @Builder
  countdownBar() {
    Row({ space: 8 }) {
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(4)
          .borderRadius(2)
          .backgroundColor($r('app.color.glass_track'))
        Row()
          .width(this.progressPercent())
          .height(4)
          .borderRadius(2)
          .linearGradient({ angle: 90, colors: trackGradientColors(this.stage()) })
          // 每秒缩短一格，用等速动画连起来，避免数字跳动感
          .animation({ duration: 950, curve: Curve.Linear })
      }
      .layoutWeight(1)
      .height(4)
      .clip(true)

      Text(this.remaining.toString() + 's')
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
        .width(26)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: DeviceAdapter.isWatch() ? 4 : 8 }) {
        // ---- 层级一：发行方 + 账号 + 环形倒计时（唯一时间指示，不再叠加光轨） ----
        Row({ space: DeviceAdapter.isWatch() ? 6 : 10 }) {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.avatarLetter())
              .fontSize(DeviceAdapter.isWatch() ? 12 : 16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
          .width(DeviceAdapter.avatarSize())
          .height(DeviceAdapter.avatarSize())
          .borderRadius(DeviceAdapter.isWatch() ? 8 : 12)
          .linearGradient({ angle: 145, colors: avatarGradientColors(this.avatarKey()) })
          .border({ width: 1, color: $r('app.color.card_highlight'), style: BorderStyle.Solid })
          .shadow(avatarShadow())

          Column({ space: 2 }) {
            Text(this.issuer.length > 0 ? this.issuer : $r('app.string.card_issuer_unnamed'))
              .fontSize(DeviceAdapter.isWatch() ? 12 : 15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (!DeviceAdapter.isWatch()) {
              Text(this.account.length > 0 ? this.account : $r('app.string.card_account_missing'))
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (DeviceAdapter.isWatch()) {
            RingCountdown({
              remaining: this.remaining,
              period: this.period,
              ringSize: DeviceAdapter.ringSize(),
              showText: false
            })
          } else {
            this.moreButton()
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // ---- 层级二：更大口令字号 + 紧凑触感复制胶囊键 ----
        Row() {
          Text(this.formatCode(this.code))
            .fontSize(DeviceAdapter.codeFontSize())
            .fontWeight(FontWeight.Bold)
            // 流光口令：shaderStyle 优先级高于 fontColor，fontColor 作为兜底
            .fontColor($r('app.color.text_primary'))
            .shaderStyle(new LinearGradientStyle({
              angle: 90,
              colors: codeGradientColors(this.stage())
            }))
            .letterSpacing(DeviceAdapter.isWatch() ? 1 : 2)
            // 表格数字：每位数字等宽，口令刷新时不会因字宽差异产生跳动
            .fontFeature('"tnum" on')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (!DeviceAdapter.isWatch()) {
            Stack({ alignContent: Alignment.Center }) {
              Button($r('app.string.common_copy'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .height(DeviceAdapter.copyButtonHeight())
                .padding({ left: 16, right: 16 })
                .borderRadius(17)
                .linearGradient({ angle: 90, colors: trackGradientColors(0) })
                .fontColor($r('app.color.fab_foreground'))
                .shadow(glowButtonShadow())
                .onClick(() => {
                  this.triggerCopyParticle();
                  this.onCopy();
                })

              if (this.copyParticleActive && DeviceAdapter.supportsParticle()) {
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
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // ---- 层级三：底部倒计时进度条（横条 + 右侧剩余秒数） ----
        if (!DeviceAdapter.isWatch()) {
          this.countdownBar()
        }
      }
      // 刷新粒子：作为浮层叠在卡片上，不参与布局（早先作为 Column 子元素会让卡片在归零瞬间变高再缩回）
      if (this.refreshParticleActive && DeviceAdapter.supportsParticle()) {
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
    .padding({
      left: DeviceAdapter.cardPadding(),
      right: DeviceAdapter.cardPadding(),
      top: DeviceAdapter.isWatch() ? 6 : 10,
      bottom: DeviceAdapter.isWatch() ? 6 : 10
    })
    .width('100%')
    .borderRadius(DeviceAdapter.cardRadius())
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
    // 2in1 桌面交互：鼠标悬停时显示手形光标
    .onHover((isHover: boolean) => {
      DeviceAdapter.applyHoverCursor(this.getUIContext().getCursorController(), isHover);
    })
    // 删除：整体收缩并淡出；粒子消散由父层叠加，避免粒子随卡片一起被淡出
    .opacity(this.deleting ? 0.0 : (this.appeared ? 1.0 : 0.0))
    .scale({ x: this.deleting ? 0.9 : 1.0, y: this.deleting ? 0.9 : 1.0 })
    .translate({ y: this.appeared ? 0 : 12 })
    .animation({
      duration: this.deleting ? DELETE_ANIM_DURATION : 300,
      curve: this.deleting ? Curve.Friction : Curve.FastOutSlowIn
    })
    .onClick(() => this.onCopy())
  }
}
