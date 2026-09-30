import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { AddTotpViewModel } from '../viewmodel/AddTotpViewModel';
import { ParsedOtpUri } from '../service/OtpParser';
import { Result } from '../types/Result';
import { AppRoutes } from '../constants/AppConstants';
import { AuroraBackground } from '../components/AuroraBackground';
import {
  avatarGradientColors,
  avatarShadow,
  glassGroupShadow,
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
  private viewModel: AddTotpViewModel = new AddTotpViewModel();

  aboutToAppear(): void {
    const stored: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (stored !== undefined && stored.length > 0) {
      this.viewModel.setEncryptionSecret(stored);
    }
    this.startScan();
  }

  private async startScan(): Promise<void> {
    try {
      const context: common.Context = getContext(this) as common.Context;
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE]
      };
      const scanResult: scanBarcode.ScanResult = await scanBarcode.startScanForResult(context, options);
      const parsed: Result<ParsedOtpUri> = this.viewModel.parseUri(scanResult.originalValue);
      if (!parsed.success || parsed.data === undefined) {
        const message: string = parsed.error !== undefined ? parsed.error.message : '二维码无效';
        promptAction.showToast({ message: message });
        router.back({ url: AppRoutes.HOME });
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
      router.back({ url: AppRoutes.HOME });
    }
  }

  private onSave(): void {
    this.saving = true;
    this.viewModel.save().then((result: Result<void>) => {
      this.saving = false;
      if (result.success) {
        this.stage = 'DONE';
        router.back({ url: AppRoutes.HOME });
      } else {
        const message: string = result.error !== undefined ? result.error.message : '保存失败';
        promptAction.showToast({ message: message });
      }
    });
  }

  @Builder
  infoRow(icon: Resource, label: string, value: string, isLast: boolean) {
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
      Column({ space: 6 }) {
        Text('确认验证码信息')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('确认无误后保存到本地加密数据库')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

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
          Text(this.issuer.length > 0 ? this.issuer.substring(0, 1).toUpperCase() : '源')
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
        this.infoRow($r('app.media.ic_tag'), '发行方', this.issuer, false)
        this.infoRow($r('app.media.ic_person'), '账号', this.account, false)
        this.infoRow($r('app.media.ic_privacy'), '算法', this.algorithm, false)
        this.infoRow($r('app.media.ic_digits'), '位数', this.digits.toString() + ' 位', false)
        this.infoRow($r('app.media.ic_timer'), '周期', this.period.toString() + ' 秒', true)
      }
      .width('100%')
      .borderRadius(20)
      .clip(true)
      .backgroundColor($r('app.color.card_background'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
      .shadow(glassGroupShadow())

      Button(this.saving ? '保存中...' : '保 存 口 令')
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

      Text('正在扫描二维码')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Text('请将 otpauth 二维码放入取景框')
        .fontSize(12.5)
        .fontColor($r('app.color.text_tertiary'))

      Progress({ value: 60, total: 100, type: ProgressType.Linear })
        .width('52%')
        .height(4)
        .color($r('app.color.brand'))
        .backgroundColor($r('app.color.glass_track'))
        .borderRadius(2)
        .margin({ top: 4 })
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
            Column() {
              this.scanningView()
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
