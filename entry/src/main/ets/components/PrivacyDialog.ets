import { CURRENT_PRIVACY_POLICY_VERSION } from '../constants/AppConstants';
import { DIALOG_MAX_WIDTH } from '../constants/LayoutConstants';
import { glassCardShadow } from '../theme/GlassStyle';

/**
 * 首次启动隐私政策确认（冰晶模态卡片）。
 *
 * 作为 CustomDialogController 的 builder 使用：
 * ```
 * new CustomDialogController({
 *   builder: PrivacyDialog({ onAgree: ..., onDecline: ... }),
 *   autoCancel: false,
 *   customStyle: true,
 *   alignment: DialogAlignment.Center
 * })
 * ```
 */
@CustomDialog
export struct PrivacyDialog {
  controller?: CustomDialogController;
  onAgree: () => void = () => {};
  onDecline: () => void = () => {};

  @Builder
  section(title: ResourceStr, body: ResourceStr) {
    Column({ space: 5 }) {
      Text(title)
        .fontSize(14.5)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(body)
        .fontSize(12.5)
        .lineHeight(20)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 16 }) {
      // 顶部拖拽指示条，呼应半沉浸抽屉形态
      Column()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor($r('app.color.divider'))

      Column({ space: 4 }) {
        Text($r('app.string.dialog_privacy_title'))
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.dialog_privacy_version', CURRENT_PRIVACY_POLICY_VERSION))
          .fontSize(11.5)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')

      Scroll() {
        Column({ space: 13 }) {
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
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 2, bottom: 2 })
      }
      .width('100%')
      .height(300)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Row({ space: 12 }) {
        Button($r('app.string.dialog_decline'))
          .layoutWeight(1)
          .height(46)
          .borderRadius(23)
          .fontSize(15)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onDecline())

        Button($r('app.string.dialog_agree'))
          .layoutWeight(1)
          .height(46)
          .borderRadius(23)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .linearGradient({
            angle: 90,
            colors: [[$r('app.color.brand'), 0.0], [$r('app.color.brand_secondary'), 1.0]]
          })
          .fontColor($r('app.color.fab_foreground'))
          .shadow({ radius: 12, color: '#590A59F7', offsetX: 0, offsetY: 4 })
          .onClick(() => this.onAgree())
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: DIALOG_MAX_WIDTH })
    .padding({ left: 22, right: 22, top: 14, bottom: 22 })
    .borderRadius(28)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
  }
}
