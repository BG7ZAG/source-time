import { router } from '@kit.ArkUI';
import { AppRoutes } from '../constants/AppConstants';

@Entry
@Component
struct SettingsPage {
  private navigateTo(route: string): void {
    router.pushUrl({ url: route });
  }

  @Builder
  settingItem(title: string, route: string) {
    ListItem() {
      Row() {
        Text(title)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('>')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => this.navigateTo(route))
    }
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('< 返回')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Blank()
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('')
          .width(48)
      }
      .width('100%')
      .padding(16)

      List({ space: 1 }) {
        this.settingItem('安全', AppRoutes.SECURITY)
        this.settingItem('WebDAV 同步', AppRoutes.WEBDAV)
        this.settingItem('隐私政策', AppRoutes.PRIVACY_POLICY)
        this.settingItem('关于', AppRoutes.ABOUT)
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0.5, color: '#E0E0E0' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
