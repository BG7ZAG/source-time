import { router } from '@kit.ArkUI';

@Entry
@Component
struct AboutPage {
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

      Text('关于')
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

  build() {
    Column() {
      this.header()

      Column({ space: 8 }) {
        Text('源时')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand'))
        Text('开源鸿蒙 TOTP 动态口令工具')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        Text('版本 1.0.0')
          .fontSize(14)
          .fontColor($r('app.color.text_tertiary'))
      }
      .padding(32)
      .borderRadius(16)
      .backgroundColor($r('app.color.card_background'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
      .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
      .margin({ left: 16, right: 16 })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [[$r('app.color.page_gradient_start'), 0.0], [$r('app.color.page_gradient_end'), 1.0]]
    })
  }
}
