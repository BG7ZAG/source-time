import { router } from '@kit.ArkUI';
import { AppRoutes } from '../constants/AppConstants';

@Entry
@Component
struct SettingsPage {
  private navigateTo(route: string): void {
    router.pushUrl({ url: route });
  }

  @Builder
  header() {
    Row() {
      Button() {
        Text('<')
          .fontSize(18)
          .fontColor($r('app.color.text_primary'))
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(Color.Transparent)
      .onClick(() => router.back())

      Blank()

      Text('设置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Blank()

      Text('')
        .width(40)
    }
    .width('100%')
    .padding({ left: 8, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  settingItem(title: string, subtitle: string, route: string) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        Text(subtitle)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .layoutWeight(1)

      Text('>')
        .fontSize(16)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => this.navigateTo(route))
  }

  build() {
    Column() {
      this.header()

      Column() {
        this.settingItem('安全', '加密密钥管理', AppRoutes.SECURITY)
        Divider().color($r('app.color.divider')).width('100%')
        this.settingItem('WebDAV 同步', '云端数据同步', AppRoutes.WEBDAV)
        Divider().color($r('app.color.divider')).width('100%')
        this.settingItem('隐私政策', '数据隐私说明', AppRoutes.PRIVACY_POLICY)
        Divider().color($r('app.color.divider')).width('100%')
        this.settingItem('关于', '应用信息', AppRoutes.ABOUT)
      }
      .width('100%')
      .padding(0)
      .borderRadius(16)
      .backgroundColor($r('app.color.card_background'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
      .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
      .margin({ left: 16, right: 16, top: 8 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [[$r('app.color.page_gradient_start'), 0.0], [$r('app.color.page_gradient_end'), 1.0]]
    })
  }
}
