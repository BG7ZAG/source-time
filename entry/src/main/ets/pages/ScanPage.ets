import { common } from '@kit.AbilityKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { AddTotpViewModel } from '../viewmodel/AddTotpViewModel';
import { ParsedOtpUri } from '../service/OtpParser';
import { Result } from '../types/Result';
import { AppRoutes } from '../constants/AppConstants';
import { CONTENT_MAX_WIDTH } from '../constants/LayoutConstants';
import { UiText } from '../utils/UiText';
import { DeviceAdapter } from '../utils/DeviceAdapter';
import { AuroraBackground } from '../components/AuroraBackground';
import {
  avatarGradientColors,
  avatarShadow,
  glassGroupShadow,
  glassPillShadow,
  glowButtonShadow,
  trackGradientColors
} from '../theme/GlassStyle';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';
type ScanStage = 'SCANNING' | 'CONFIRM' | 'DONE';

/**
 * 扫码页（鸿蒙 7 版）：冰晶扫描等待态 + 冰晶信息确认卡片。
 */
@Entry
@Component
struct ScanPage {
  @State stage: ScanStage = 'SCANNING';
  @State issuer: string = '';
  @State account: string = '';
  @State algorithm: string = '';
  @State digits: number = 6;
  @State period: number = 30;
  @State saving: boolean = false;
  @State scanPulse: boolean = false;
  /** 本页是否已经主动离开：防止扫描 Promise 回来时重复退栈。 */
  private dismissed: boolean = false;
  private viewModel: AddTotpViewModel = new AddTotpViewModel();

  aboutToAppear(): void {
    if (DeviceAdapter.isWatch()) {
      this.getUIContext().getRouter().back();
      return;
    }
    const stored: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (stored !== undefined && stored.length > 0) {
      this.viewModel.setEncryptionSecret(stored);
    }
    this.startScan();
  }

  private async startScan(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE]
      };
      const scanResult: scanBarcode.ScanResult = await scanBarcode.startScanForResult(context, options);
      // 等待期间用户已经点了返回：页面已弹出，这里不能再解析结果或再退一次栈
      if (this.dismissed) {
        return;
      }
      const parsed: Result<ParsedOtpUri> = this.viewModel.parseUri(scanResult.originalValue);
      if (!parsed.success || parsed.data === undefined) {
        const message: ResourceStr = parsed.error !== undefined ? parsed.error.message : $r('app.string.scan_invalid_qr');
        this.getUIContext().getPromptAction().showToast({ message: message });
        this.leaveToHome();
        return;
      }
      const data: ParsedOtpUri = parsed.data;
      this.viewModel.applyParsed(data);
      this.issuer = data.issuer;
      this.account = data.account;
      this.algorithm = data.algorithm;
      this.digits = data.digits;
      this.period = data.period;
      this.stage = 'CONFIRM';
      this.scanPulse = true;
    } catch (error) {
      // 系统扫描界面被取消（或相机不可用）会走这里
      this.leaveToHome();
    }
  }

  /**
   * 退出本页并回到首页。
   *
   * `dismissed` 同时充当「已经离开」的闸门：用户点左上角返回后，
   * 系统扫描的 Promise 稍后仍会 resolve/reject，若不加判断会再退一次栈，
   * 把首页一起退掉。
   */
  private leaveToHome(): void {
    if (this.dismissed) {
      return;
    }
    this.dismissed = true;
    this.getUIContext().getRouter().back({ url: AppRoutes.HOME });
  }

  private onSave(): void {
    this.saving = true;
    this.viewModel.save().then((result: Result<void>) => {
      this.saving = false;
      if (result.success) {
        this.stage = 'DONE';
        this.leaveToHome();
      } else {
        const message: ResourceStr = result.error !== undefined ? result.error.message : $r('app.string.scan_save_failed');
        this.getUIContext().getPromptAction().showToast({ message: message });
      }
    });
  }

  /**
   * 左上角返回。
   *
   * 之前这里没有返回入口：等待态依赖系统返回手势，而 2in1 没有返回手势，
   * 一旦系统扫描界面因无相机/权限被拒而不返回，用户就被卡在这一页。
   * 底色用不透明白（card_background_solid）而不是半透明磨砂：无相机时页面底色是白的，
   * 半透明白圆在纯白背景上会看不见。
   */
  @Builder
  backButton() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.ic_back'))
        .width(21)
        .height(21)
        .fillColor($r('app.color.text_primary'))
    }
    .width(42)
    .height(42)
    .borderRadius(21)
    .backgroundColor($r('app.color.card_background_solid'))
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassPillShadow())
    .onHover((isHover: boolean) => {
      DeviceAdapter.applyHoverCursor(this.getUIContext().getCursorController(), isHover);
    })
    .onClick(() => {
      // 只弹本页、回首页：系统扫描界面若还在前台，由它自己的关闭/返回处理
      this.leaveToHome();
    })
  }

  @Builder
  infoRow(icon: Resource, label: ResourceStr, value: string, isLast: boolean) {
    Column() {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Image(icon)
            .width(16)
            .height(16)
            .fillColor($r('app.color.text_secondary'))
        }
        .width(30)
        .height(30)
        .borderRadius(10)
        .backgroundColor($r('app.color.scrim'))
        .border({ width: 1, color: $r('app.color.divider'), style: BorderStyle.Solid })

        Text(label)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)

        Text(value.length > 0 ? value : '—')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      if (!isLast) {
        Divider()
          .color($r('app.color.divider'))
          .margin({ left: 56, right: 14 })
      }
    }
    .width('100%')
  }

  @Builder
  confirmView() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        this.backButton()

        Column({ space: 6 }) {
          Text($r('app.string.scan_confirm_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.scan_confirm_subtitle'))
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 柔光微立体品牌图标
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(96)
          .height(96)
          .borderRadius(48)
          .radialGradient({
            center: ['50%', '50%'],
            radius: 48,
            colors: [['#3D0A59F7', 0.0], ['#000A59F7', 1.0]]
          })

        Stack({ alignContent: Alignment.Center }) {
          Text(this.issuer.length > 0 ? this.issuer.substring(0, 1).toUpperCase() : $r('app.string.scan_avatar_fallback'))
            .fontSize(26)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .width(64)
        .height(64)
        .borderRadius(22)
        .linearGradient({
          angle: 145,
          colors: avatarGradientColors(this.issuer.length > 0 ? this.issuer : 'SourceTime')
        })
        .border({ width: 1, color: $r('app.color.card_highlight'), style: BorderStyle.Solid })
        .shadow(avatarShadow())
      }
      .width(96)
      .height(96)
      .align(Alignment.Center)

      Column() {
        this.infoRow($r('app.media.ic_tag'), $r('app.string.scan_label_issuer'), this.issuer, false)
        this.infoRow($r('app.media.ic_person'), $r('app.string.scan_label_account'), this.account, false)
        this.infoRow($r('app.media.ic_privacy'), $r('app.string.scan_label_algorithm'), this.algorithm, false)
        this.infoRow($r('app.media.ic_digits'), $r('app.string.scan_label_digits'),
          UiText.of($r('app.string.scan_digits_value'), this.digits), false)
        this.infoRow($r('app.media.ic_timer'), $r('app.string.scan_label_period'),
          UiText.of($r('app.string.scan_period_value'), this.period), true)
      }
      .width('100%')
      .borderRadius(20)
      .clip(true)
      .backgroundColor($r('app.color.card_background'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
      .shadow(glassGroupShadow())

      Button(this.saving ? $r('app.string.scan_saving') : $r('app.string.scan_save_button'))
        .width('100%')
        .height(50)
        .borderRadius(25)
        .fontSize(15.5)
        .fontWeight(FontWeight.Medium)
        .linearGradient({ angle: 90, colors: trackGradientColors(0) })
        .fontColor($r('app.color.fab_foreground'))
        .shadow(glowButtonShadow())
        .enabled(!this.saving)
        .onClick(() => this.onSave())
    }
    .width('100%')
    // 同设置页：避免内容短于视口时被 Scroll 垂直居中
    .constraintSize({ minHeight: '100%' })
    .justifyContent(FlexAlign.Start)
    .padding(18)
  }

  @Builder
  scanningView() {
    Column({ space: 18 }) {
      Stack({ alignContent: Alignment.Center }) {
        // 脉冲扩散环
        Column()
          .width(104)
          .height(104)
          .borderRadius(52)
          .backgroundColor($r('app.color.glow'))
          .opacity(0.7)
          .scale({ x: 1.45, y: 1.45 })
          .animation({ duration: 1600, curve: Curve.EaseOut, iterations: -1, playMode: PlayMode.Normal })

        Column()
          .width(104)
          .height(104)
          .borderRadius(52)
          .backgroundColor($r('app.color.card_background'))
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
          .shadow(glowButtonShadow())

        Image($r('app.media.ic_scan'))
          .width(34)
          .height(34)
          .fillColor($r('app.color.text_secondary'))
      }
      .width(104)
      .height(104)

      Text($r('app.string.scan_scanning_title'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Text($r('app.string.scan_scanning_hint'))
        .fontSize(12.5)
        .fontColor($r('app.color.text_tertiary'))
      // 原来这里是一条写死 60% 的 Linear Progress，永远不会动，看起来像卡住的进度条；
      // 扫描本身没有可量化的进度，去掉它，只保留上方脉冲环表达「正在识别」。
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
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
          if (this.stage === 'CONFIRM') {
            Scroll() {
              this.confirmView()
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .align(Alignment.TopStart)  // 内容不足一屏时不被 Scroll 垂直居中
          } else {
            // @Builder 方法返回 void，不能在其调用结果上继续挂属性，
            // 故用普通容器承载 layoutWeight。
            Stack({ alignContent: Alignment.TopStart }) {
              Column() {
                this.scanningView()
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)

              // 等待态没有标题栏，返回按钮浮在左上角
              Row() {
                this.backButton()
              }
              .margin({ left: 16, top: 12 })
            }
            .layoutWeight(1)
            .width('100%')
          }
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
