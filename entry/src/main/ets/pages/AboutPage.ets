import { router } from '@kit.ArkUI';

@Entry
@Component
struct AboutPage {
  build() {
    Column() {
      Row() {
        Text('< 返回')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Blank()
        Text('关于')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('')
          .width(48)
      }
      .width('100%')
      .padding(16)

      Column({ space: 8 }) {
        Text('源时')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('开源鸿蒙 TOTP 动态口令工具')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        Text('版本 1.0.0')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
