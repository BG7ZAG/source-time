import { CURRENT_PRIVACY_POLICY_VERSION } from '../constants/AppConstants';
import { DIALOG_MAX_WIDTH } from '../constants/LayoutConstants';
import { glassCardShadow } from '../theme/GlassStyle';
import { DeviceAdapter } from '../utils/DeviceAdapter';

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
 *
 * 手表适配：圆形表盘只有 233vp 高，手机端的「300vp 固定正文 + 46vp 按钮 + 22vp 内边距」
 * 会超过一屏，按钮行被挤成 0 高而完全消失。手表端改为固定 200vp 高、170vp 宽，
 * 正文用 layoutWeight 吃掉剩余空间，按钮行始终保留 36vp，保证「同意 / 不同意」可达。
 */
@CustomDialog
export struct PrivacyDialog {
  controller?: CustomDialogController;
  onAgree: () => void = () => {};
  onDecline: () => void = () => {};

  private isWatch(): boolean {
    return DeviceAdapter.isWatch();
  }

  private dialogPadding(): Padding {
    if (this.isWatch()) {
      return { left: 12, right: 12, top: 10, bottom: 10 };
    }
    return { left: 22, right: 22, top: 14, bottom: 22 };
  }

  private dialogConstraint(): ConstraintSizeOptions {
    if (this.isWatch()) {
      // 圆形表盘：宽度收窄到 170vp 避免标题左右被表盘边缘裁切；
      // 高度固定 200vp，居中后上下都留出圆弧安全区。
      return { maxWidth: 170, minHeight: 200, maxHeight: 200 };
    }
    return { maxWidth: DIALOG_MAX_WIDTH };
  }

  @Builder
  section(title: ResourceStr, body: ResourceStr) {
    Column({ space: this.isWatch() ? 3 : 5 }) {
      Text(title)
        .fontSize(this.isWatch() ? 11 : 14.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isWatch() ? Color.White : $r('app.color.text_primary'))
        .width('100%')
      Text(body)
        .fontSize(this.isWatch() ? 10 : 12.5)
        .lineHeight(this.isWatch() ? 15 : 20)
        .fontColor(this.isWatch() ? '#B3FFFFFF' : $r('app.color.text_secondary'))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: this.isWatch() ? 8 : 16 }) {
      // 顶部拖拽指示条，呼应半沉浸抽屉形态；手表屏幕太小，省略
      if (!this.isWatch()) {
        Column()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor($r('app.color.divider'))
      }

      Column({ space: 4 }) {
        Text(this.isWatch() ? $r('app.string.dialog_privacy_title_short') : $r('app.string.dialog_privacy_title'))
          .fontSize(this.isWatch() ? 15 : 19)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isWatch() ? Color.White : $r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
        Text($r('app.string.dialog_privacy_version', CURRENT_PRIVACY_POLICY_VERSION))
          .fontSize(this.isWatch() ? 10 : 11.5)
          .fontColor(this.isWatch() ? '#80FFFFFF' : $r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')

      Scroll() {
        Column({ space: this.isWatch() ? 8 : 13 }) {
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
      // 手表端给一个保守的固定高度作为兜底；layoutWeight 生效时会自动吃掉剩余空间
      .height(this.isWatch() ? 86 : 300)
      .layoutWeight(this.isWatch() ? 1 : 0)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Row({ space: this.isWatch() ? 8 : 12 }) {
        Button($r('app.string.dialog_decline'))
          .layoutWeight(1)
          .height(this.isWatch() ? 36 : 46)
          .borderRadius(this.isWatch() ? 18 : 23)
          .fontSize(this.isWatch() ? 12 : 15)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onDecline())

        Button(this.isWatch() ? $r('app.string.dialog_agree_short') : $r('app.string.dialog_agree'))
          .layoutWeight(1)
          .height(this.isWatch() ? 36 : 46)
          .borderRadius(this.isWatch() ? 18 : 23)
          .fontSize(this.isWatch() ? 12 : 15)
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
    .constraintSize(this.dialogConstraint())
    .padding(this.dialogPadding())
    .borderRadius(this.isWatch() ? 20 : 28)
    .backgroundColor(this.isWatch() ? Color.Transparent : $r('app.color.card_background'))
    .backgroundBlurStyle(this.isWatch() ? BlurStyle.NONE : BlurStyle.COMPONENT_THICK)
    .border({ width: this.isWatch() ? 0 : 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
  }
}
