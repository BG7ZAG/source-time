import { CURRENT_PRIVACY_POLICY_VERSION } from '../constants/AppConstants';
import { SettingsService } from '../service/SettingsService';
import { AppContextHolder } from '../utils/AppContextHolder';
import { DeviceAdapter } from '../utils/DeviceAdapter';

/**
 * 手表端隐私声明确认页。
 *
 * 之前用 CustomDialog 展示，模态窗口拿不到表冠焦点，导致：
 * - 旋转表冠无法滚动隐私正文；
 * - 右滑无法退出。
 * 改为独立页面后，Scroll 可获得焦点（表冠滚动），右滑返回走系统页面栈，
 * 未同意就返回时在 aboutToDisappear 中退出应用，等价于「不同意」。
 */
@Entry
@Component
struct WatchPrivacyPage {
  /** 是否已完成「同意 / 不同意」处理；未处理时右滑返回视为不同意。 */
  private settled: boolean = false;
  private scroller: Scroller = new Scroller();
  private settingsService: SettingsService = new SettingsService();

  aboutToDisappear(): void {
    if (this.settled) {
      return;
    }
    // 右滑/返回键退出隐私页但没有明确同意：隐私声明未签署，不允许继续使用
    AppContextHolder.getContext().terminateSelf();
  }

  private agree(): void {
    this.settled = true;
    const settings = this.settingsService.getSettings();
    settings.privacyPolicyAccepted = true;
    settings.privacyPolicyVersion = CURRENT_PRIVACY_POLICY_VERSION;
    this.settingsService.saveSettings(settings).then(() => {
      this.getUIContext().getRouter().back();
    });
  }

  private decline(): void {
    this.settled = true;
    AppContextHolder.getContext().terminateSelf();
  }

  @Builder
  section(title: ResourceStr, body: ResourceStr) {
    Column({ space: 3 }) {
      Text(title)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width('100%')
      Text(body)
        .fontSize(10)
        .lineHeight(15)
        .fontColor('#B3FFFFFF')
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 8 }) {
      Column({ space: 4 }) {
        Text($r('app.string.dialog_privacy_title_short'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text($r('app.string.dialog_privacy_version', CURRENT_PRIVACY_POLICY_VERSION))
          .fontSize(10)
          .fontColor('#80FFFFFF')
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')

      Scroll(this.scroller) {
        Column({ space: 8 }) {
          this.section($r('app.string.dialog_section_collection_title'),
            $r('app.string.dialog_section_collection_body'))
          this.section($r('app.string.dialog_section_storage_title'),
            $r('app.string.dialog_section_storage_body'))
          this.section($r('app.string.dialog_section_sharing_title'),
            $r('app.string.dialog_section_sharing_body'))
          this.section($r('app.string.dialog_section_retention_title'),
            $r('app.string.dialog_section_retention_body'))
          this.section($r('app.string.dialog_section_notice_title'),
            $r('app.string.dialog_section_notice_body'))

          // 操作按钮紧跟协议正文，随内容一起滚动；手表横向空间不足，改为竖向排列
          Column({ space: 8 }) {
            Button() {
              Text($r('app.string.dialog_agree_short'))
                .width('100%')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.fab_foreground'))
                .textAlign(TextAlign.Center)
                .maxLines(1)
            }
            .width('100%')
            .height(38)
            .borderRadius(19)
            .linearGradient({
              angle: 90,
              colors: [[$r('app.color.brand'), 0.0], [$r('app.color.brand_secondary'), 1.0]]
            })
            .onClick(() => this.agree())

            Button() {
              Text($r('app.string.dialog_decline'))
                .width('100%')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .maxLines(1)
            }
            .width('100%')
            .height(38)
            .borderRadius(19)
            .backgroundColor($r('app.color.pill_background'))
            .onClick(() => this.decline())
          }
          .width('100%')
          .margin({ top: 8, bottom: 6 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 2, bottom: 2 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.On)
      .edgeEffect(EdgeEffect.Spring)
      .focusable(true)
      .focusOnTouch(true)
      // Scroll 获焦时直接处理表冠；未获焦时由页面根容器兜底
      .onDigitalCrown((event: CrownEvent) => {
        event.stopPropagation();
        this.scroller.scrollBy(0, event.degree * 3);
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 12 })
    .backgroundColor(Color.Black)
    // 表冠事件挂在页面根容器：无论焦点落在 Scroll 还是页面本身都能收到
    .focusable(true)
    .defaultFocus(true)
    .onDigitalCrown((event: CrownEvent) => {
      event.stopPropagation();
      // degree 为相对旋转角度（deg），换算成滚动距离要放大，否则几乎看不出移动
      this.scroller.scrollBy(0, event.degree * 3);
    })
  }
}