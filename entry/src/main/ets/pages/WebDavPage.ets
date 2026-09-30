import { router, promptAction } from '@kit.ArkUI';
import { WebDavService } from '../service/WebDavService';
import { SyncService } from '../service/SyncService';
import { SettingsService } from '../service/SettingsService';
import { WebDavConfig } from '../model/WebDavConfig';
import { SyncStatus } from '../model/SyncModel';
import { Result } from '../types/Result';
import { DEFAULT_WEBDAV_DIRECTORY } from '../constants/AppConstants';
import { AuroraBackground } from '../components/AuroraBackground';
import {
  focusGlowShadow,
  frostedPillColor,
  glassGroupShadow,
  glassPillShadow,
  glowButtonShadow,
  noShadow,
  particleColorRange,
  statusDotColor,
  trackGradientColors
} from '../theme/GlassStyle';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

/**
 * WebDAV 同步配置页（鸿蒙 7 版）。
 *
 * 控件：Smooth 弹性开关 + 1px 悬浮高光输入框
 * 按钮：主操作用渐变高光填充，次要操作（测试连接）用高光虚框
 * 状态：动态脉冲状态灯（灰-空闲，蓝-同步中，红-异常）
 */
@Entry
@Component
struct WebDavPage {
  @State baseUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State remotePath: string = DEFAULT_WEBDAV_DIRECTORY;
  @State webDavEnabled: boolean = false;
  @State autoPush: boolean = false;
  @State autoPullOnStart: boolean = false;
  @State testing: boolean = false;
  @State saving: boolean = false;
  @State pushing: boolean = false;
  @State pulling: boolean = false;
  @State syncStatus: SyncStatus = SyncStatus.IDLE;
  @State lastSyncAt: number = 0;
  @State syncMessage: string = '';
  @State actionParticleActive: boolean = false;

  private webDavService: WebDavService = new WebDavService();
  private settingsService: SettingsService = new SettingsService();
  private encryptionSecret: string = '';
  private actionParticleTimerId: number = -1;

  aboutToAppear(): void {
    const secret: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (secret !== undefined && secret.length > 0) {
      this.encryptionSecret = secret;
    }
    this.loadConfig();
  }

  aboutToDisappear(): void {
    if (this.actionParticleTimerId >= 0) {
      clearTimeout(this.actionParticleTimerId);
      this.actionParticleTimerId = -1;
    }
  }

  private loadConfig(): void {
    this.settingsService.loadWebDavConfig(this.encryptionSecret).then((config: WebDavConfig) => {
      this.baseUrl = config.baseUrl;
      this.username = config.username;
      this.password = config.password;
      this.remotePath = config.remotePath.length > 0 ? config.remotePath : DEFAULT_WEBDAV_DIRECTORY;
      this.webDavEnabled = config.enabled;
      this.autoPush = config.autoPush;
      this.autoPullOnStart = config.autoPullOnStart;
    });
    const settings = this.settingsService.getSettings();
    this.lastSyncAt = settings.lastSyncAt !== undefined ? settings.lastSyncAt : 0;
    const syncState = SyncService.getInstance().getState();
    this.syncStatus = syncState.status;
    this.syncMessage = syncState.message !== undefined ? syncState.message : '';
  }

  private buildConfig(): WebDavConfig {
    return {
      enabled: this.webDavEnabled,
      baseUrl: this.baseUrl,
      username: this.username,
      password: this.password,
      remotePath: this.remotePath,
      autoPush: this.autoPush,
      autoPullOnStart: this.autoPullOnStart
    };
  }

  private triggerActionParticle(): void {
    this.actionParticleActive = true;
    if (this.actionParticleTimerId >= 0) {
      clearTimeout(this.actionParticleTimerId);
    }
    this.actionParticleTimerId = setTimeout(() => {
      this.actionParticleActive = false;
      this.actionParticleTimerId = -1;
    }, 850);
  }

  private onSave(): void {
    this.saving = true;
    const config: WebDavConfig = this.buildConfig();
    this.settingsService.saveWebDavConfig(config, this.encryptionSecret).then((result: Result<void>) => {
      this.saving = false;
      if (result.success) {
        SyncService.getInstance().configure(config, this.encryptionSecret);
        this.triggerActionParticle();
        promptAction.showToast({ message: '保存成功' });
      } else {
        const message: string = result.error !== undefined ? result.error.message : '保存失败';
        promptAction.showToast({ message: message });
      }
    });
  }

  private onTest(): void {
    this.testing = true;
    this.webDavService.testConnection(this.buildConfig()).then((result: Result<void>) => {
      this.testing = false;
      if (result.success) {
        this.triggerActionParticle();
      }
      const message: string = result.success ? '连接成功'
        : (result.error !== undefined ? result.error.message : '连接失败');
      promptAction.showToast({ message: message });
    });
  }

  private onPush(): void {
    this.pushing = true;
    SyncService.getInstance().push().then((result: Result<void>) => {
      this.pushing = false;
      const state = SyncService.getInstance().getState();
      this.syncStatus = state.status;
      this.syncMessage = state.message !== undefined ? state.message : '';
      this.lastSyncAt = state.lastSyncAt !== undefined ? state.lastSyncAt : 0;
      if (result.success) {
        this.triggerActionParticle();
      }
      const message: string = result.success ? '推送成功'
        : (result.error !== undefined ? result.error.message : '推送失败');
      promptAction.showToast({ message: message });
    });
  }

  private onPull(): void {
    this.pulling = true;
    SyncService.getInstance().pull().then((result: Result<void>) => {
      this.pulling = false;
      const state = SyncService.getInstance().getState();
      this.syncStatus = state.status;
      this.syncMessage = state.message !== undefined ? state.message : '';
      this.lastSyncAt = state.lastSyncAt !== undefined ? state.lastSyncAt : 0;
      if (result.success) {
        this.triggerActionParticle();
      }
      const message: string = result.success ? '拉取成功'
        : (result.error !== undefined ? result.error.message : '拉取失败');
      promptAction.showToast({ message: message });
    });
  }

  private formatLastSyncAt(): string {
    if (this.lastSyncAt === 0) {
      return '从未同步';
    }
    const date: Date = new Date(this.lastSyncAt);
    const year: number = date.getFullYear();
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    const hour: number = date.getHours();
    const minute: number = date.getMinutes();
    return `${year}-${month < 10 ? '0' + month : month}-${day < 10 ? '0' + day : day} ${hour < 10 ? '0' + hour : hour}:${minute < 10 ? '0' + minute : minute}`;
  }

  private formatSyncStatus(): string {
    switch (this.syncStatus) {
      case SyncStatus.IDLE:
        return '空闲';
      case SyncStatus.PUSHING:
        return '推送中';
      case SyncStatus.PULLING:
        return '拉取中';
      case SyncStatus.SUCCESS:
        return '成功';
      case SyncStatus.FAILED:
        return '失败';
      default:
        return '未知';
    }
  }

  /** 状态灯语义：空闲灰 / 进行中蓝 / 成功绿 / 异常红。 */
  private statusTone(): string {
    if (this.syncStatus === SyncStatus.FAILED) {
      return 'failed';
    }
    if (this.syncStatus === SyncStatus.SUCCESS) {
      return 'success';
    }
    if (this.syncStatus === SyncStatus.PUSHING || this.syncStatus === SyncStatus.PULLING) {
      return 'active';
    }
    return 'idle';
  }

  private isBusy(): boolean {
    return this.syncStatus === SyncStatus.PUSHING || this.syncStatus === SyncStatus.PULLING;
  }

  @Builder
  header() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_back'))
          .width(21)
          .height(21)
          .fillColor($r('app.color.text_primary'))
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(frostedPillColor())
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
      .shadow(glassPillShadow())
      .onClick(() => router.back())

      Blank()

      Column({ space: 1 }) {
        Text('WebDAV 同步')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('云端数据备份与多端联动')
          .fontSize(10.5)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)

      Blank()

      Text('')
        .width(42)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }

  /** 鸿蒙原生 Smooth 弹性开关。 */
  @Builder
  smoothSwitch(isOn: boolean, onChange: (value: boolean) => void) {
    Toggle({ type: ToggleType.Switch, isOn: isOn })
      .selectedColor($r('app.color.brand'))
      .switchPointColor(Color.White)
      .onChange(onChange)
  }

  @Builder
  toggleRow(label: string, note: string, isOn: boolean, isLast: boolean, onChange: (value: boolean) => void) {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 3 }) {
          Text(label)
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
          if (note.length > 0) {
            Text(note)
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.smoothSwitch(isOn, onChange)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .alignItems(VerticalAlign.Center)

      if (!isLast) {
        Divider()
          .color($r('app.color.divider'))
          .margin({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  fieldLabel(label: string) {
    Text(label)
      .fontSize(12.5)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
  }

  /** Outlined Glass 次要按钮：高光虚框 + 透明底。 */
  @Builder
  outlinedButton(label: string, enabled: boolean, onTap: () => void, icon?: Resource) {
    Button() {
      Row({ space: 6 }) {
        if (icon !== undefined) {
          Image(icon)
            .width(15)
            .height(15)
            .fillColor(enabled ? $r('app.color.brand') : $r('app.color.text_tertiary'))
        }
        Text(label)
          .fontSize(14.5)
          .fontWeight(FontWeight.Medium)
          .fontColor(enabled ? $r('app.color.brand') : $r('app.color.text_tertiary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .height(48)
    .borderRadius(24)
    .backgroundColor(Color.Transparent)
    .border({
      width: 1,
      color: enabled ? $r('app.color.brand') : $r('app.color.field_border'),
      style: BorderStyle.Solid
    })
    .enabled(enabled)
    .onClick(onTap)
  }

  /** 主操作按钮：渐变高光填充 + 能量光晕。 */
  @Builder
  solidButton(label: string, enabled: boolean, onTap: () => void) {
    Button(label)
      .layoutWeight(1)
      .height(48)
      .borderRadius(24)
      .fontSize(14.5)
      .fontWeight(FontWeight.Medium)
      .linearGradient({ angle: 90, colors: trackGradientColors(0) })
      .fontColor($r('app.color.fab_foreground'))
      .shadow(glowButtonShadow())
      .enabled(enabled)
      .onClick(onTap)
  }

  @Builder
  statusDot() {
    // 脉冲动画的状态与定时器收敛进 PulseDot 内部：
    // 早先放在页面级 @State 上，每 1.4s 触发整页重渲染，会让受控输入框的文本被重新同步（表现为「输入后被清空」）。
    PulseDot({
      color: statusDotColor(this.statusTone()),
      active: this.isBusy() || this.statusTone() === 'failed'
    })
  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.Push, duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
    PageTransitionExit({ type: RouteType.Push, duration: 250, curve: Curve.EaseIn })
      .slide(SlideEffect.Left)
    PageTransitionEnter({ type: RouteType.Pop, duration: 250, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ type: RouteType.Pop, duration: 250, curve: Curve.EaseIn })
      .slide(SlideEffect.Right)
  }

  build() {
    // @Entry 页面的 build 只能有唯一根节点，且必须是容器组件；
    // AuroraBackground 是自定义组件，故由 Stack 作为根承载它。
    Stack() {
      AuroraBackground() {
        Column() {
          this.header()

          Scroll() {
            Column({ space: 14 }) {
              // ---- 开关分组 ----
              Column() {
                this.toggleRow('启用 WebDAV 同步', '开启后可将加密数据备份到你自己的服务器', this.webDavEnabled, false,
                  (value: boolean) => {
                    this.webDavEnabled = value;
                  })
                this.toggleRow('自动推送', '增删改后自动上传加密副本', this.autoPush, false, (value: boolean) => {
                  this.autoPush = value;
                })
                this.toggleRow('启动时自动拉取', '冷启动时检查远端新版本', this.autoPullOnStart, true, (value: boolean) => {
                  this.autoPullOnStart = value;
                })
              }
              .width('100%')
              .borderRadius(22)
              .clip(true)
              .backgroundColor($r('app.color.card_background'))
              .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
              .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow(glassGroupShadow())

              // ---- 连接配置 ----
              Column({ space: 14 }) {
                Column({ space: 8 }) {
                  this.fieldLabel('服务器地址')
                  WebDavField({ value: $baseUrl, placeholder: 'https://example.com/dav/', masked: false })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Column({ space: 8 }) {
                  this.fieldLabel('账号与密码')
                  WebDavField({ value: $username, placeholder: '用户名', masked: false })
                  WebDavField({ value: $password, placeholder: '密码', masked: true })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Column({ space: 8 }) {
                  this.fieldLabel('同步目录')
                  WebDavField({ value: $remotePath, placeholder: '/SourceTime/', masked: false })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(16)
              .borderRadius(22)
              .backgroundColor($r('app.color.card_background'))
              .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
              .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow(glassGroupShadow())

              // ---- Outlined / Solid 按钮组合 ----
              Row({ space: 12 }) {
                this.outlinedButton(this.testing ? '测试中...' : '测试连接', !this.testing && !this.saving,
                  () => this.onTest())
                this.solidButton(this.saving ? '保存中...' : '保存配置', !this.testing && !this.saving,
                  () => this.onSave())
              }
              .width('100%')

              // ---- 状态卡片 ----
              Column({ space: 12 }) {
                Row() {
                  Row({ space: 8 }) {
                    this.statusDot()
                    Text('同步状态')
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                  }
                  .alignItems(VerticalAlign.Center)

                  Blank()

                  Text(this.formatSyncStatus())
                    .fontSize(14.5)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.syncStatus === SyncStatus.FAILED ? $r('app.color.danger')
                      : this.syncStatus === SyncStatus.SUCCESS ? $r('app.color.success')
                      : $r('app.color.text_secondary'))
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Row() {
                  Text('上次同步')
                    .fontSize(12.5)
                    .fontColor($r('app.color.text_secondary'))
                  Blank()
                  Text(this.formatLastSyncAt())
                    .fontSize(12.5)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')

                if (this.syncMessage.length > 0) {
                  Text(this.syncMessage)
                    .fontSize(11.5)
                    .lineHeight(18)
                    .fontColor($r('app.color.danger'))
                    .width('100%')
                }

                Row({ space: 12 }) {
                  this.outlinedButton(this.pushing ? '推送中...' : '手动推送',
                    !this.pushing && !this.pulling && this.webDavEnabled, () => this.onPush(),
                    $r('app.media.ic_arrow_up'))
                  this.outlinedButton(this.pulling ? '拉取中...' : '手动拉取',
                    !this.pushing && !this.pulling && this.webDavEnabled, () => this.onPull(),
                    $r('app.media.ic_arrow_down'))
                }
                .width('100%')

                // 同步动作触发粒子反馈
                if (this.actionParticleActive) {
                  Particle({
                    particles: [
                      {
                        emitter: {
                          particle: {
                            type: ParticleType.POINT,
                            config: { radius: 2 },
                            count: 24,
                            lifetime: 850,
                            lifetimeRange: 200
                          },
                          emitRate: 500,
                          shape: ParticleEmitterShape.RECTANGLE,
                          position: [0, 0],
                          size: [220, 10]
                        },
                        color: { range: particleColorRange() },
                        opacity: { range: [0.4, 0.95] },
                        scale: { range: [0.15, 0.55] },
                        velocity: { angle: [-120, -60], speed: [40, 110] },
                        acceleration: { angle: { range: [-90, -90] }, speed: { range: [40, 80] } }
                      }
                    ]
                  })
                  .width('100%')
                  .height(120)
                  .hitTestBehavior(HitTestMode.Transparent)
                }
              }
              .width('100%')
              .padding(16)
              .borderRadius(22)
              .backgroundColor($r('app.color.card_background'))
              .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
              .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow(glassGroupShadow())

              Text('同步文件在上传前已在本地完成 AES-256-GCM 加密，服务端仅保存密文。')
                .fontSize(11)
                .lineHeight(17)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')
                .padding({ left: 4, right: 4 })
            }
            .width('100%')
            // 同设置页：避免内容短于视口时被 Scroll 垂直居中
            .constraintSize({ minHeight: '100%' })
            .justifyContent(FlexAlign.Start)
            .padding({ left: 16, right: 16, bottom: 28 })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.TopStart)  // 内容不足一屏时不被 Scroll 垂直居中
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * WebDAV 表单输入框：下沉式冰晶输入 + 获焦主色光晕。
 *
 * 关键点：TextInput 的 text 用 **$$ 双向绑定**（@Link 变量）。
 * 官方明确提示 —— 只传 `text: value` 时「组件刷新会导致 TextInput 中的文本内容异常」，
 * 也就是输入后内容被回滚/清空；$$ 绑定后变量与组件内部状态实时同步，任何刷新都不会丢失输入。
 */
@Component
struct WebDavField {
  @Link value: string;
  @Prop placeholder: string = '';
  @Prop masked: boolean = false;
  @State focused: boolean = false;

  build() {
    TextInput({ placeholder: this.placeholder, text: $$this.value })
      .width('100%')
      .height(48)
      .borderRadius(14)
      .fontSize(14)
      .fontColor($r('app.color.text_primary'))
      .padding({ left: 14, right: 14 })
      .backgroundColor($r('app.color.field_background'))
      .placeholderColor($r('app.color.text_tertiary'))
      .caretColor($r('app.color.brand'))
      .type(this.masked ? InputType.Password : InputType.Normal)
      .showPasswordIcon(this.masked)
      .border({
        width: 1.5,
        color: this.focused ? $r('app.color.brand') : $r('app.color.field_border'),
        style: BorderStyle.Solid
      })
      .shadow(this.focused ? focusGlowShadow() : noShadow())
      .onFocus(() => {
        this.focused = true;
      })
      .onBlur(() => {
        this.focused = false;
      })
  }
}

/**
 * 状态脉冲灯：脉冲动画的状态与定时器收敛在组件内部，不再触发页面级重渲染。
 */
@Component
struct PulseDot {
  @Prop color: string = '';
  @Prop @Watch('onActiveChange') active: boolean = false;
  @State pulseOn: boolean = false;
  private timerId: number = -1;

  onActiveChange(): void {
    this.syncTimer();
  }

  aboutToAppear(): void {
    this.syncTimer();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private syncTimer(): void {
    if (this.active) {
      if (this.timerId < 0) {
        this.timerId = setInterval(() => {
          this.pulseOn = !this.pulseOn;
        }, 1400);
      }
      return;
    }
    this.stopTimer();
    this.pulseOn = false;
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.active) {
        Column()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.color)
          .opacity(this.pulseOn ? 0.0 : 0.55)
          .scale({ x: this.pulseOn ? 2.4 : 1.0, y: this.pulseOn ? 2.4 : 1.0 })
          .animation({ duration: 1400, curve: Curve.EaseOut })
      }

      Column()
        .width(9)
        .height(9)
        .borderRadius(5)
        .backgroundColor(this.color)
    }
    .width(14)
    .height(14)
  }
}
