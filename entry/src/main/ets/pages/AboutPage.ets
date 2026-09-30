import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AuroraBackground } from '../components/AuroraBackground';
import { frostedPillColor, glassGroupShadow, glassPillShadow } from '../theme/GlassStyle';

/**
 * 关于页（鸿蒙 7 版）：悬浮 logo + 版本胶囊 + 冰晶信息分组卡片。
 */
@Entry
@Component
struct AboutPage {
  private repoUrl: string = 'https://github.com/BG7ZAG/source-time';

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

      Text('关于源时')
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

  @Builder
  infoRow(icon: Resource, label: string, value: string, clickable: boolean, isLast: boolean) {
    Column() {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Image(icon)
            .width(20)
            .height(20)
            .fillColor($r('app.color.brand'))
        }
        .width(36)
        .height(36)
        .borderRadius(12)
        .backgroundColor($r('app.color.brand_container'))
        .border({ width: 1, color: $r('app.color.card_highlight'), style: BorderStyle.Solid })

        Text(label)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Text(value)
          .fontSize(12.5)
          .fontColor(clickable ? $r('app.color.brand') : $r('app.color.text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (clickable) {
          Image($r('app.media.ic_chevron_right'))
            .width(14)
            .height(14)
            .fillColor($r('app.color.text_tertiary'))
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (clickable) {
          this.openRepo();
        }
      })

      if (!isLast) {
        Divider()
          .color($r('app.color.divider'))
          .margin({ left: 66, right: 16 })
      }
    }
    .width('100%')
  }

  private openRepo(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      context.openLink(this.repoUrl).catch(() => {
        // 无法拉起浏览器时保持静态展示
      });
    } catch (error) {
      // 忽略异常
    }
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
            Column({ space: 16 }) {
              // 悬浮 logo 区
              Column({ space: 12 }) {
                Stack({ alignContent: Alignment.Center }) {
                  // 背后弥散光晕
                  Column()
                    .width(132)
                    .height(132)
                    .borderRadius(66)
                    .radialGradient({
                      center: ['50%', '50%'],
                      radius: 66,
                      colors: [['#3D0A59F7', 0.0], ['#000A59F7', 1.0]]
                    })

                  Image($r('app.media.ic_logo'))
                    .width(84)
                    .height(84)
                    .borderRadius(22)
                    .border({ width: 1, color: $r('app.color.card_highlight'), style: BorderStyle.Solid })
                    .shadow({ radius: 20, color: '#4D0A59F7', offsetX: 0, offsetY: 10 })
                }
                .width(132)
                .height(132)

                Text('源时')
                  .fontSize(25)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))

                Text('开源鸿蒙 TOTP 动态口令工具')
                  .fontSize(12.5)
                  .fontColor($r('app.color.text_secondary'))

                Text('V1.0.0 · HarmonyOS Native')
                  .fontSize(11.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.brand_on_container'))
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .borderRadius(12)
                  .backgroundColor($r('app.color.brand_container'))
                  .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              }
              .width('100%')
              .padding({ top: 20, bottom: 4 })
              .alignItems(HorizontalAlign.Center)

              Column() {
                this.infoRow($r('app.media.ic_doc'), '开源协议', 'MIT License', false, false)
                this.infoRow($r('app.media.ic_github'), '项目仓库', 'BG7ZAG/source-time', true, false)
                this.infoRow($r('app.media.ic_heart'), '致谢', '感谢每一位使用者', false, true)
              }
              .width('100%')
              .borderRadius(22)
              .clip(true)
              .backgroundColor($r('app.color.card_background'))
              .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
              .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow(glassGroupShadow())

              Text('本地离线优先 · WebDAV 端到端加密同步')
                .fontSize(11)
                .textAlign(TextAlign.Center)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')
                .padding({ top: 4, bottom: 20 })
            }
            .width('100%')
            // 同设置页：避免内容短于视口时被 Scroll 垂直居中
            .constraintSize({ minHeight: '100%' })
            .justifyContent(FlexAlign.Start)
            .padding({ left: 16, right: 16 })
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
