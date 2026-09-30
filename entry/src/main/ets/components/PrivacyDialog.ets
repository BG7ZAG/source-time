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
  section(title: string, body: string) {
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
        Text('源时（SourceTime）隐私政策')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('版本 1.0 · 本地优先')
          .fontSize(11.5)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')

      Scroll() {
        Column({ space: 13 }) {
          this.section('一、数据收集与使用',
            '源时不收集个人身份信息，不要求注册或登录。你输入的 TOTP 配置、加密密钥与 WebDAV 配置仅存储在设备本地，不会自动发送到任何外部服务器。')
          this.section('二、数据存储与安全',
            '所有 TOTP 数据经 AES-256-GCM 加密后存储；加密密钥通过 PBKDF2-HMAC-SHA256（10 万次迭代）派生。应用日志不会输出加密密钥、TOTP Secret 或 WebDAV 密码。')
          this.section('三、数据共享与传输',
            '源时不会主动向开发者或第三方上传数据。启用 WebDAV 后，仅加密文件会上传到你自己指定的服务器，服务端永远只看到密文。')
          this.section('四、用户权利',
            '你可以随时删除 TOTP 数据、修改加密密钥、启用或停用 WebDAV 同步。卸载应用将清除全部本地数据。')
          this.section('五、重要提示',
            '请妥善保管加密密钥。源时不提供服务器端密钥恢复能力，丢失密钥后已加密数据将无法解密。')
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
        Button('不同意')
          .layoutWeight(1)
          .height(46)
          .borderRadius(23)
          .fontSize(15)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onDecline())

        Button('同意并继续')
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
    .padding({ left: 22, right: 22, top: 14, bottom: 22 })
    .borderRadius(28)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
  }
}
