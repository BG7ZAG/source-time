import { router } from '@kit.ArkUI';
import { AuroraBackground } from '../components/AuroraBackground';
import { CURRENT_PRIVACY_POLICY_VERSION } from '../constants/AppConstants';
import { CONTENT_MAX_WIDTH } from '../constants/LayoutConstants';
import {
  frostedPillColor,
  glassGroupShadow,
  glassPillShadow
} from '../theme/GlassStyle';
import { UiText } from '../utils/UiText';

/**
 * 隐私政策页（鸿蒙 7 版）：冰晶章卡片 + 灰色矢量章节图标。
 */
@Entry
@Component
struct PrivacyPolicyPage {
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

      Text($r('app.string.policy_title'))
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Blank()

      Text('')
        .width(42)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }

  /** 章节卡片：双色柔光图标 + 标题 + 正文段落。 */
  @Builder
  sectionCard(icon: Resource, title: ResourceStr, paragraphs: ResourceStr[]) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Image(icon)
            .width(17)
            .height(17)
            .fillColor($r('app.color.text_secondary'))
        }
        .width(34)
        .height(34)
        .borderRadius(12)
        .backgroundColor($r('app.color.scrim'))
        .border({ width: 1, color: $r('app.color.divider'), style: BorderStyle.Solid })

        Text(title)
          .fontSize(15.5)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .color($r('app.color.divider'))
        .width('100%')

      ForEach(paragraphs, (line: ResourceStr) => {
        Text(line)
          .fontSize(13.5)
          .lineHeight(22)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }, (line: ResourceStr, index: number) => 'section' + index.toString())
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassGroupShadow())
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  noticeCard(title: ResourceStr, paragraphs: ResourceStr[]) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Image($r('app.media.ic_warning'))
          .width(17)
          .height(17)
          .fillColor($r('app.color.danger'))
        Text(title)
          .fontSize(15.5)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.danger'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(paragraphs, (line: ResourceStr) => {
        Text(line)
          .fontSize(13.5)
          .lineHeight(22)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }, (line: ResourceStr, index: number) => 'notice' + index.toString())
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.brand_container'), style: BorderStyle.Solid })
    .shadow(glassGroupShadow())
    .alignItems(HorizontalAlign.Start)
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
              // 标题区
              Column({ space: 6 }) {
                Text($r('app.string.policy_heading'))
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Row({ space: 8 }) {
                  // 版本号取自唯一的常量源：与同意判定用的是同一个值，写死会与实际生效版本漂移
                  Text(UiText.of($r('app.string.policy_version_label'), CURRENT_PRIVACY_POLICY_VERSION))
                    .fontSize(11.5)
                    .fontColor($r('app.color.brand_on_container'))
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(10)
                    .backgroundColor($r('app.color.brand_container'))

                  Text($r('app.string.policy_effective_date'))
                    .fontSize(11.5)
                    .fontColor($r('app.color.text_tertiary'))
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 4, bottom: 2 })

              this.sectionCard($r('app.media.ic_security'), $r('app.string.policy_section_intro_title'), [
                $r('app.string.policy_section_intro_body_1'),
                $r('app.string.policy_section_intro_body_2'),
                $r('app.string.policy_section_intro_body_3'),
                $r('app.string.policy_section_intro_body_4')
              ])

              this.sectionCard($r('app.media.ic_doc'), $r('app.string.policy_section_purpose_title'), [
                $r('app.string.policy_section_purpose_body_1'),
                $r('app.string.policy_section_purpose_body_2'),
                $r('app.string.policy_section_purpose_body_3'),
                $r('app.string.policy_section_purpose_body_4')
              ])

              this.sectionCard($r('app.media.ic_box'), $r('app.string.policy_section_data_title'), [
                $r('app.string.policy_section_data_body_1'),
                $r('app.string.policy_section_data_body_2'),
                $r('app.string.policy_section_data_body_3'),
                $r('app.string.policy_section_data_body_4'),
                $r('app.string.policy_section_data_body_5')
              ])

              this.sectionCard($r('app.media.ic_privacy'), $r('app.string.policy_section_permissions_title'), [
                $r('app.string.policy_section_permissions_body_1'),
                $r('app.string.policy_section_permissions_body_2'),
                $r('app.string.policy_section_permissions_body_3'),
                $r('app.string.policy_section_permissions_body_4'),
                $r('app.string.policy_section_permissions_body_5')
              ])

              this.sectionCard($r('app.media.ic_security'), $r('app.string.policy_section_storage_title'), [
                $r('app.string.policy_section_storage_body_1'),
                $r('app.string.policy_section_storage_body_2'),
                $r('app.string.policy_section_storage_body_3'),
                $r('app.string.policy_section_storage_body_4'),
                $r('app.string.policy_section_storage_body_5'),
                $r('app.string.policy_section_storage_body_6'),
                $r('app.string.policy_section_storage_body_7')
              ])

              this.sectionCard($r('app.media.ic_privacy'), $r('app.string.policy_section_secret_title'), [
                $r('app.string.policy_section_secret_body_1'),
                $r('app.string.policy_section_secret_body_2'),
                $r('app.string.policy_section_secret_body_3'),
                $r('app.string.policy_section_secret_body_4'),
                $r('app.string.policy_section_secret_body_5')
              ])

              this.noticeCard($r('app.string.policy_section_notice_title'), [
                $r('app.string.policy_section_notice_body_1'),
                $r('app.string.policy_section_notice_body_2'),
                $r('app.string.policy_section_notice_body_3')
              ])

              this.sectionCard($r('app.media.ic_log'), $r('app.string.policy_section_logs_title'), [
                $r('app.string.policy_section_logs_body_1'),
                $r('app.string.policy_section_logs_body_2'),
                $r('app.string.policy_section_logs_body_3'),
                $r('app.string.policy_section_logs_body_4'),
                $r('app.string.policy_section_logs_body_5'),
                $r('app.string.policy_section_logs_body_6'),
                $r('app.string.policy_section_logs_body_7'),
                $r('app.string.policy_section_logs_body_8')
              ])

              this.sectionCard($r('app.media.ic_cloud'), $r('app.string.policy_section_webdav_title'), [
                $r('app.string.policy_section_webdav_body_1'),
                $r('app.string.policy_section_webdav_body_2'),
                $r('app.string.policy_section_webdav_body_3'),
                $r('app.string.policy_section_webdav_body_4'),
                $r('app.string.policy_section_webdav_body_5'),
                $r('app.string.policy_section_webdav_body_6'),
                $r('app.string.policy_section_webdav_body_7'),
                $r('app.string.policy_section_webdav_body_8'),
                $r('app.string.policy_section_webdav_body_9'),
                $r('app.string.policy_section_webdav_body_10'),
                $r('app.string.policy_section_webdav_body_11'),
                $r('app.string.policy_section_webdav_body_12')
              ])

              this.sectionCard($r('app.media.ic_edit'), $r('app.string.policy_section_clipboard_title'), [
                $r('app.string.policy_section_clipboard_body_1'),
                $r('app.string.policy_section_clipboard_body_2'),
                $r('app.string.policy_section_clipboard_body_3'),
                $r('app.string.policy_section_clipboard_body_4'),
                $r('app.string.policy_section_clipboard_body_5'),
                $r('app.string.policy_section_clipboard_body_6')
              ])

              this.sectionCard($r('app.media.ic_cloud'), $r('app.string.policy_section_transfer_title'), [
                $r('app.string.policy_section_transfer_body_1'),
                $r('app.string.policy_section_transfer_body_2'),
                $r('app.string.policy_section_transfer_body_3')
              ])

              this.sectionCard($r('app.media.ic_sync'), $r('app.string.policy_section_backup_title'), [
                $r('app.string.policy_section_backup_body_1'),
                $r('app.string.policy_section_backup_body_2')
              ])

              this.sectionCard($r('app.media.ic_cloud'), $r('app.string.policy_section_sharing_title'), [
                $r('app.string.policy_section_sharing_body_1'),
                $r('app.string.policy_section_sharing_body_2'),
                $r('app.string.policy_section_sharing_body_3')
              ])

              this.sectionCard($r('app.media.ic_doc'), $r('app.string.policy_section_retention_title'), [
                $r('app.string.policy_section_retention_body_1'),
                $r('app.string.policy_section_retention_body_2'),
                $r('app.string.policy_section_retention_body_3'),
                $r('app.string.policy_section_retention_body_4'),
                $r('app.string.policy_section_retention_body_5'),
                $r('app.string.policy_section_retention_body_6'),
                $r('app.string.policy_section_retention_body_7'),
                $r('app.string.policy_section_retention_body_8')
              ])

              this.sectionCard($r('app.media.ic_person'), $r('app.string.policy_section_rights_title'), [
                $r('app.string.policy_section_rights_body_1'),
                $r('app.string.policy_section_rights_body_2'),
                $r('app.string.policy_section_rights_body_3'),
                $r('app.string.policy_section_rights_body_4'),
                $r('app.string.policy_section_rights_body_5')
              ])

              this.sectionCard($r('app.media.ic_person'), $r('app.string.policy_section_minors_title'), [
                $r('app.string.policy_section_minors_body_1'),
                $r('app.string.policy_section_minors_body_2')
              ])

              this.sectionCard($r('app.media.ic_security'), $r('app.string.policy_section_security_title'), [
                $r('app.string.policy_section_security_body_1'),
                $r('app.string.policy_section_security_body_2'),
                $r('app.string.policy_section_security_body_3'),
                $r('app.string.policy_section_security_body_4')
              ])

              this.sectionCard($r('app.media.ic_edit'), $r('app.string.policy_section_updates_title'), [
                $r('app.string.policy_section_updates_body_1'),
                $r('app.string.policy_section_updates_body_2'),
                $r('app.string.policy_section_updates_body_3'),
                $r('app.string.policy_section_updates_body_4')
              ])

              this.sectionCard($r('app.media.ic_doc'), $r('app.string.policy_section_law_title'), [
                $r('app.string.policy_section_law_body_1'),
                $r('app.string.policy_section_law_body_2')
              ])

              this.sectionCard($r('app.media.ic_about'), $r('app.string.policy_section_contact_title'), [
                $r('app.string.policy_section_contact_body_1'),
                $r('app.string.policy_section_contact_body_2'),
                $r('app.string.policy_section_contact_body_3')
              ])

              Text($r('app.string.policy_footer_note'))
                .fontSize(12)
                .textAlign(TextAlign.Center)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')
                .padding({ top: 6, bottom: 24 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.TopStart)  // 内容不足一屏时不被 Scroll 垂直居中
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
      }
    }
    .width('100%')
    .height('100%')
  }
}
