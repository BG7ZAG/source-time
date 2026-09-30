import { router } from '@kit.ArkUI';
import { AuroraBackground } from '../components/AuroraBackground';
import {
  frostedPillColor,
  glassGroupShadow,
  glassPillShadow
} from '../theme/GlassStyle';

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

      Text('隐私政策')
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
  sectionCard(icon: Resource, title: string, paragraphs: string[]) {
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

      ForEach(paragraphs, (line: string) => {
        Text(line)
          .fontSize(13.5)
          .lineHeight(22)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }, (line: string, index: number) => title + index.toString())
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
  noticeCard(paragraphs: string[]) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Image($r('app.media.ic_warning'))
          .width(17)
          .height(17)
          .fillColor($r('app.color.danger'))
        Text('重要提示')
          .fontSize(15.5)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.danger'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(paragraphs, (line: string) => {
        Text(line)
          .fontSize(13.5)
          .lineHeight(22)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }, (line: string, index: number) => 'notice' + index.toString())
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
                Text('源时（SourceTime）隐私政策')
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')

                Row({ space: 8 }) {
                  Text('版本 1.0')
                    .fontSize(11.5)
                    .fontColor($r('app.color.brand_on_container'))
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(10)
                    .backgroundColor($r('app.color.brand_container'))

                  Text('更新日期：2026年9月29日')
                    .fontSize(11.5)
                    .fontColor($r('app.color.text_tertiary'))
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 4, bottom: 2 })

              this.sectionCard($r('app.media.ic_security'), '一、引言', [
                '源时是一款本地优先的 TOTP（基于时间的一次性密码）验证器应用。我们高度重视你的隐私和数据安全。本政策说明我们如何收集、使用、存储和保护你的数据，以及你享有的权利。'
              ])

              this.sectionCard($r('app.media.ic_box'), '二、数据收集与使用', [
                '2.1 我们不收集你的个人身份信息。源时不要求注册、登录，也不关联手机号码或邮箱。',
                '2.2 你主动输入的数据包括：TOTP 配置信息（发行方、账号、密钥、算法、位数、周期）、加密密钥、WebDAV 连接配置（服务器地址、用户名、密码、远程路径）。',
                '2.3 上述数据仅存储在设备本地，不会自动发送到任何外部服务器。'
              ])

              this.sectionCard($r('app.media.ic_privacy'), '三、数据存储与安全', [
                '3.1 所有 TOTP 数据均经过 AES-256-GCM 加密后存储在设备本地文件中。',
                '3.2 加密密钥通过 PBKDF2-HMAC-SHA256 派生为 256 位密钥，迭代 100,000 次。',
                '3.3 WebDAV 密码同样经过加密后存储在本地，不会以明文形式保存。',
                '3.4 应用不会在日志中输出加密密钥、TOTP Secret 或 WebDAV 密码等敏感信息。'
              ])

              this.sectionCard($r('app.media.ic_cloud'), '四、数据共享与传输', [
                '4.1 源时不会主动向开发者或任何第三方服务器上传你的数据。',
                '4.2 如果你配置了 WebDAV 同步，应用只会将加密后的数据文件上传到你指定的服务器，服务端无法直接读取你的 TOTP 数据。',
                '4.3 WebDAV 服务由你自行配置和管理，开发者不对其安全性与可用性负责。',
                '4.4 扫码功能仅在本地处理二维码内容，不会将扫描结果发送到任何外部服务。'
              ])

              this.sectionCard($r('app.media.ic_person'), '五、用户权利', [
                '5.1 你有权随时删除应用中的所有 TOTP 配置数据，删除操作不可恢复。',
                '5.2 你有权随时修改加密密钥；修改时需验证旧密钥，通过后应用会使用新密钥重新加密所有数据。',
                '5.3 你有权随时启用或禁用 WebDAV 同步，并清除已保存的配置。',
                '5.4 卸载应用将清除所有本地存储的数据，包括加密数据库与设置信息。'
              ])

              this.noticeCard([
                '6.1 请妥善保管加密密钥。源时不提供服务器端密钥恢复能力，丢失密钥后将无法解密已加密的数据。',
                '6.2 建议在设置密钥后立即备份到安全位置（如密码管理器或离线存储）。',
                '6.3 WebDAV 同步传输的是加密文件，但请确保服务器使用 HTTPS，防止传输过程中的中间人攻击。'
              ])

              this.sectionCard($r('app.media.ic_edit'), '七、隐私政策更新', [
                '7.1 本政策可能随版本更新而修订。政策版本号记录在应用设置中，发生重大变更时应用会在启动时重新提示确认。',
                '7.2 你可以在「设置 > 隐私政策」中随时查看当前版本内容。'
              ])

              this.sectionCard($r('app.media.ic_doc'), '八、开源声明', [
                '8.1 源时是一款开源应用，源代码可供审查。你可以通过审查源代码验证本政策的各项声明。'
              ])

              Text('如对本政策有任何疑问，请通过项目仓库提交 Issue 反馈。')
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
      }
    }
    .width('100%')
    .height('100%')
  }
}
