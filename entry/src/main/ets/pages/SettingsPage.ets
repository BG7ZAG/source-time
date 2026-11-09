import { common } from '@kit.AbilityKit';
import { privacyManager } from '@kit.AppGalleryKit';
import { AppRoutes, WEBDAV_FEATURE_ENABLED } from '../constants/AppConstants';
import { CONTENT_MAX_WIDTH } from '../constants/LayoutConstants';
import { AuroraBackground } from '../components/AuroraBackground';
import {
  avatarShadow,
  frostedPillColor,
  glassGroupShadow,
  glassPillShadow
} from '../theme/GlassStyle';
import { DeviceAdapter } from '../utils/DeviceAdapter';

/**
 * 设置页：模块化分组冰晶卡片 + 单色图标（本项目禁止彩色图标）。
 */
@Entry
@Component
struct SettingsPage {
  private navigateTo(route: string): void {
    this.getUIContext().getRouter().pushUrl({ url: route });
  }

  /**
   * 打开隐私声明。
   *
   * 应用已接入平台标准化隐私声明托管服务：应用内的隐私声明入口必须展示托管声明，
   * 与系统隐私弹窗保持同一份内容（否则属于「应用内非标隐私声明链接」）。
   * 查询失败（如调试包未预置托管信息）时回退到应用内页面，保证入口始终可用。
   */
  private openPrivacyPolicy(): void {
    // 隐私管理服务不支持手表等设备：直接回退到应用内页面，避免调用未声明的系统能力
    if (!canIUse('SystemCapability.AppGalleryService.PrivacyManager')) {
      this.navigateTo(AppRoutes.PRIVACY_POLICY);
      return;
    }
    try {
      const info: privacyManager.AppPrivacyMgmtInfo = privacyManager.getAppPrivacyMgmtInfo();
      const links: privacyManager.AppPrivacyLink[] = info.privacyInfo;
      for (let i = 0; i < links.length; i++) {
        if (links[i].type === privacyManager.AppPrivacyLinkType.PRIVACY_STATEMENT_LINK
          && links[i].url.length > 0) {
          this.openLink(links[i].url);
          return;
        }
      }
    } catch (error) {
      // 未接入隐私托管 / 非真机环境：走下面的应用内页面
    }
    this.navigateTo(AppRoutes.PRIVACY_POLICY);
  }

  private openLink(url: string): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      context.openLink(url).catch(() => {
        // 无法拉起浏览器时回退到应用内页面
        this.navigateTo(AppRoutes.PRIVACY_POLICY);
      });
    } catch (error) {
      this.navigateTo(AppRoutes.PRIVACY_POLICY);
    }
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
      .onHover((isHover: boolean) => {
        DeviceAdapter.applyHoverCursor(this.getUIContext().getCursorController(), isHover);
      })
      .onClick(() => this.getUIContext().getRouter().back())

      Blank()

      Text($r('app.string.settings_title'))
        .fontSize(DeviceAdapter.isWatch() ? 16 : 20)
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

  /** 单色图标：淡品牌蓝衬底 + 单色图标（不再使用彩色渐变衬底）。 */
  @Builder
  glassIcon(icon: Resource) {
    Stack({ alignContent: Alignment.Center }) {
      Image(icon)
        .width(19)
        .height(19)
        .fillColor($r('app.color.text_primary'))
    }
    .width(38)
    .height(38)
    .borderRadius(13)
    // 卡片改成纯白后，原来的半透明白衬底（frostedPillColor）在白底上几乎看不见，
    // 换成极淡的品牌蓝，图标块才有轮廓，也延续整体蓝色调。
    .backgroundColor($r('app.color.subtle_brand_background'))
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(avatarShadow())
  }

  @Builder
  settingItem(title: ResourceStr, subtitle: ResourceStr, route: string, icon: Resource, isLast: boolean) {
    Column() {
      Row({ space: DeviceAdapter.isWatch() ? 10 : 14 }) {
        this.glassIcon(icon)

        Column({ space: 3 }) {
          Text(title)
            .fontSize(DeviceAdapter.isWatch() ? 13 : 15.5)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          if (!DeviceAdapter.isWatch()) {
            Text(subtitle)
              .fontSize(11.5)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (!DeviceAdapter.isWatch()) {
          Image($r('app.media.ic_chevron_right'))
            .width(15)
            .height(15)
            .fillColor($r('app.color.text_tertiary'))
        }
      }
      .width('100%')
      .padding({ left: DeviceAdapter.isWatch() ? 12 : 16, right: DeviceAdapter.isWatch() ? 12 : 16, top: DeviceAdapter.isWatch() ? 12 : 15, bottom: DeviceAdapter.isWatch() ? 12 : 15 })
      .alignItems(VerticalAlign.Center)

      if (!isLast) {
        Divider()
          .color($r('app.color.divider'))
          .margin({ left: DeviceAdapter.isWatch() ? 50 : 68, right: 16 })
      }
    }
    .width('100%')
    .onHover((isHover: boolean) => {
      DeviceAdapter.applyHoverCursor(this.getUIContext().getCursorController(), isHover);
    })
    .onClick(() => {
      if (route === AppRoutes.PRIVACY_POLICY) {
        this.openPrivacyPolicy();
        return;
      }
      this.navigateTo(route);
    })
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
                this.settingItem($r('app.string.settings_item_security'),
                  $r('app.string.settings_item_security_note'), AppRoutes.SECURITY, $r('app.media.ic_security'), false)
                // 备案完成前不展示联网同步入口（WEBDAV_FEATURE_ENABLED == false）
                if (WEBDAV_FEATURE_ENABLED) {
                  this.settingItem($r('app.string.settings_item_webdav'),
                    $r('app.string.settings_item_webdav_note'), AppRoutes.WEBDAV, $r('app.media.ic_sync'), false)
                }
                this.settingItem($r('app.string.settings_item_logs'),
                  $r('app.string.settings_item_logs_note'), AppRoutes.LOGS, $r('app.media.ic_log'), false)
                this.settingItem($r('app.string.settings_item_privacy'),
                  $r('app.string.settings_item_privacy_note'), AppRoutes.PRIVACY_POLICY, $r('app.media.ic_privacy'), false)
                // 副标题为版本号，无需本地化
                this.settingItem($r('app.string.settings_item_about'),
                  'V1.0.0', AppRoutes.ABOUT, $r('app.media.ic_about'), true)
              }
              .width('100%')
              .borderRadius(22)
              .clip(true)
              // 设置页是一整块菜单列表，用纯白实底：半透明白（card_background）叠在淡蓝
              // 背景上会发灰，整片列表看着脏。纯白后文字对比也更高。
              .backgroundColor($r('app.color.card_background_solid'))
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
          if (!DeviceAdapter.isWatch()) {
            Text(WEBDAV_FEATURE_ENABLED
              ? $r('app.string.settings_footer')
              : $r('app.string.settings_footer_offline'))
              .fontSize(11)
              .textAlign(TextAlign.Center)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
              .padding({ top: 6, bottom: 12 })
          }
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
