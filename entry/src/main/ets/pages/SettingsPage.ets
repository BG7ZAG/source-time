import { router } from '@kit.ArkUI';
import { AppRoutes } from '../constants/AppConstants';
import { AuroraBackground } from '../components/AuroraBackground';
import {
  avatarGradientColors,
  avatarShadow,
  frostedPillColor,
  glassGroupShadow,
  glassPillShadow
} from '../theme/GlassStyle';

/**
 * 设置页：模块化分组冰晶卡片 + 双色柔光微立体图标。
 */
@Entry
@Component
struct SettingsPage {
  private navigateTo(route: string): void {
    router.pushUrl({ url: route });
  }

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

      Text('设置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Blank()

      Text('')
        .width(42)
    }
    .width('100%')
    // 标题栏收紧下边距，让菜单列表紧贴其下（列表整体居上，而非悬在页面中间）
    .padding({ left: 16, right: 16, top: 10, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  /** 双色柔光微立体图标：玻璃感衬底 + 渐变勾勒。 */
  @Builder
  glassIcon(icon: Resource, tintKey: string) {
    Stack({ alignContent: Alignment.Center }) {
      Image(icon)
        .width(19)
        .height(19)
        .fillColor(Color.White)
    }
    .width(38)
    .height(38)
    .borderRadius(13)
    .linearGradient({ angle: 145, colors: avatarGradientColors(tintKey) })
    .border({ width: 1, color: $r('app.color.card_highlight'), style: BorderStyle.Solid })
    .shadow(avatarShadow())
  }

  @Builder
  settingItem(title: string, subtitle: string, route: string, icon: Resource, tintKey: string, isLast: boolean) {
    Column() {
      Row({ space: 14 }) {
        this.glassIcon(icon, tintKey)

        Column({ space: 3 }) {
          Text(title)
            .fontSize(15.5)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(subtitle)
            .fontSize(11.5)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.ic_chevron_right'))
          .width(15)
          .height(15)
          .fillColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 15, bottom: 15 })
      .alignItems(VerticalAlign.Center)

      if (!isLast) {
        Divider()
          .color($r('app.color.divider'))
          .margin({ left: 68, right: 16 })
      }
    }
    .width('100%')
    .onClick(() => this.navigateTo(route))
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
            Column() {
              Column() {
                this.settingItem('安全与密钥', '应用锁、主密码与加密配置', AppRoutes.SECURITY, $r('app.media.ic_security'), '安全', false)
                this.settingItem('WebDAV 同步', '云端数据备份与多端联动', AppRoutes.WEBDAV, $r('app.media.ic_sync'), 'WebDAV', false)
                this.settingItem('隐私政策', '数据本地存储说明', AppRoutes.PRIVACY_POLICY, $r('app.media.ic_privacy'), '隐私', false)
                this.settingItem('关于源时', 'V1.0.0 (HarmonyOS Native)', AppRoutes.ABOUT, $r('app.media.ic_about'), '关于', true)
              }
              .width('100%')
              .borderRadius(22)
              .clip(true)
              .backgroundColor($r('app.color.card_background'))
              .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
              .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow(glassGroupShadow())
            }
            .width('100%')
            // Scroll 的子组件高度不足一屏时会被垂直居中，撑满视口 + Scroll 设 align(TopStart) 双重保证贴顶
            .constraintSize({ minHeight: '100%' })
            .justifyContent(FlexAlign.Start)
            .padding({ left: 16, right: 16, bottom: 20 })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.TopStart)  // 内容不足一屏时不被 Scroll 垂直居中

          // 底部标语固定在页面底部（不再随列表漂浮），与居上的菜单形成上下呼应
          Text('源时 · 本地离线优先，除 WebDAV 外不进行任何网络通信')
            .fontSize(11)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
            .padding({ top: 6, bottom: 12 })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
