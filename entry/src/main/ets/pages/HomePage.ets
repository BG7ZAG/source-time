import { router, promptAction, LengthMetrics } from '@kit.ArkUI';
import { TotpCard, DELETE_ANIM_DURATION } from '../components/TotpCard';
import { EmptyState, GlowFab } from '../components/EmptyState';
import { AuroraBackground } from '../components/AuroraBackground';
import { AddTotpSheet } from '../components/AddTotpSheet';
import { PrivacyDialog } from '../components/PrivacyDialog';
import { HomeViewModel, TotpDisplayItem } from '../viewmodel/HomeViewModel';
import { TotpItem } from '../model/TotpItem';
import { Result } from '../types/Result';
import { AppRoutes, CURRENT_PRIVACY_POLICY_VERSION } from '../constants/AppConstants';
import { CONTENT_MAX_WIDTH } from '../constants/LayoutConstants';
import { SettingsService } from '../service/SettingsService';
import { AppContextHolder } from '../utils/AppContextHolder';
import { UiText } from '../utils/UiText';
import {
  cardMaterial,
  frostedPillColor,
  glassCardShadow,
  glassPillShadow,
  particleColorRange,
  supportsImmersive,
  titleGradientColors
} from '../theme/GlassStyle';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

@Entry
@Component
struct HomePage {
  @State displayItems: TotpDisplayItem[] = [];
  @State showAddSheet: boolean = false;
  /** 正在播放「粒子消散」删除动画的条目 id；非空时忽略新的删除触发。 */
  @State deletingId: string = '';
  /** 本地数据无法解密时，本会话只提示一次，避免反复弹窗。 */
  @State loadErrorShown: boolean = false;
  private viewModel: HomeViewModel = new HomeViewModel();
  private settingsService: SettingsService = new SettingsService();
  private privacyDialog: CustomDialogController = new CustomDialogController({
    builder: PrivacyDialog({
      onAgree: () => {
        this.acceptPrivacyPolicy();
      },
      onDecline: () => {
        this.declinePrivacyPolicy();
      }
    }),
    autoCancel: false,
    customStyle: true,
    alignment: DialogAlignment.Center
  });

  aboutToAppear(): void {
    const settings = this.settingsService.getSettings();
    // 除「从未同意过」外，还要比对已同意的版本号：政策改版后必须重新弹窗确认，
    // 否则老用户会在没看到新条款的情况下继续使用（getSettings 对旧数据返回空串，天然会重弹）。
    if (!settings.privacyPolicyAccepted || settings.privacyPolicyVersion !== CURRENT_PRIVACY_POLICY_VERSION) {
      this.privacyDialog.open();
      return;
    }
    this.loadData();
  }

  onPageShow(): void {
    const settings = this.settingsService.getSettings();
    // 与 aboutToAppear 同一判据：政策待重新确认时不把口令加载出来，避免遮在弹窗下层可见
    const consented: boolean = settings.privacyPolicyAccepted
      && settings.privacyPolicyVersion === CURRENT_PRIVACY_POLICY_VERSION;
    if (consented && settings.encryptionInitialized) {
      this.viewModel.load().then((result: Result<void>) => {
        if (result.success) {
          this.refreshItems();
        } else {
          this.onLoadFailed(result);
        }
      });
    }
  }

  private acceptPrivacyPolicy(): void {
    const currentSettings = this.settingsService.getSettings();
    currentSettings.privacyPolicyAccepted = true;
    currentSettings.privacyPolicyVersion = CURRENT_PRIVACY_POLICY_VERSION;
    this.settingsService.saveSettings(currentSettings).then(() => {
      this.privacyDialog.close();
      if (!currentSettings.encryptionInitialized) {
        router.replaceUrl({ url: AppRoutes.SECURITY });
      } else {
        this.loadData();
      }
    });
  }

  private declinePrivacyPolicy(): void {
    this.privacyDialog.close();
    AppContextHolder.getContext().terminateSelf();
  }

  private loadData(): void {
    const secret: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (secret !== undefined && secret.length > 0) {
      this.viewModel.setEncryptionSecret(secret);
      this.viewModel.load().then((result: Result<void>) => {
        if (result.success) {
          this.refreshItems();
        } else {
          this.onLoadFailed(result);
        }
      });
    }
  }

  /**
   * 本地数据加载/解密失败：不再静默显示空列表——那会让用户以为「本来就空了」，
   * 直到新增口令时才撞到一句笼统的「数据加载失败」。
   * 这里明确说明原因，并提供「隔离旧密文、重新开始」的自助恢复入口（不删除原文件）。
   */
  private onLoadFailed(result: Result<void>): void {
    if (this.loadErrorShown) {
      return;
    }
    this.loadErrorShown = true;
    const message: ResourceStr = result.error !== undefined ? result.error.message : $r('app.string.home_load_error_fallback');
    // 弹窗正文需要拼接：ResourceStr 可能是 Resource，先解析成当前语言文本
    const errorText: string = typeof message === 'string' ? message : UiText.of(message);
    promptAction.showDialog({
      title: $r('app.string.home_decrypt_dialog_title'),
      message: UiText.of($r('app.string.home_decrypt_dialog_message'), errorText),
      buttons: [
        { text: $r('app.string.home_decrypt_stay_button'), color: '#666666' },
        { text: $r('app.string.home_decrypt_reset_button'), color: '#E84026' }
      ]
    }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
      if (dialogResult.index !== 1) {
        return;
      }
      this.viewModel.resetLocalData().then((resetResult: Result<void>) => {
        if (resetResult.success) {
          this.refreshItems();
          promptAction.showToast({ message: $r('app.string.home_reset_success_toast') });
        } else {
          const failMessage: ResourceStr =
            resetResult.error !== undefined ? resetResult.error.message : $r('app.string.home_reset_error_fallback');
          promptAction.showToast({ message: failMessage });
        }
      });
    });
  }

  private refreshItems(): void {
    this.displayItems = this.viewModel.getDisplayItems();
  }

  private openSettings(): void {
    router.pushUrl({ url: AppRoutes.SETTINGS });
  }

  private openAdd(): void {
    this.showAddSheet = true;
  }

  @Builder
  addSheetBuilder() {
    AddTotpSheet({
      onSaved: () => {
        this.showAddSheet = false;
        this.viewModel.load().then(() => {
          this.refreshItems();
        });
      },
      onScan: () => {
        this.showAddSheet = false;
        router.pushUrl({ url: AppRoutes.SCAN });
      }
    })
  }

  /** 左滑动作区：点击删除图标触发二次确认；确认后图标也播放「粒子消散」并淡出。 */
  @Builder
  deleteAction(item: TotpItem) {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.ic_delete'))
            .width(22)
            .height(22)
            .fillColor(Color.White)
        }
        .width(54)
        .height(54)
        .borderRadius(18)
        .linearGradient({ angle: 135, colors: [['#FF7A70', 0.0], ['#FF3B30', 1.0]] })
        .shadow({ radius: 12, color: '#66FF3B30', offsetX: 0, offsetY: 4 })
        .onClick(() => this.onDelete(item))
        // 删除时图标淡出；粒子消散由下方浮层叠加（与卡片粒子同一走向）
        .opacity(this.deletingId === item.id ? 0.0 : 1.0)
        .animation({
          duration: this.deletingId === item.id ? DELETE_ANIM_DURATION : 200,
          curve: Curve.Friction
        })

        // 图标区域粒子消散：一次性爆发后整体向左流动（自右向左）
        if (this.deletingId === item.id) {
          Particle({
            particles: [
              {
                emitter: {
                  particle: {
                    type: ParticleType.POINT,
                    config: { radius: 2.4 },
                    count: 80,
                    lifetime: DELETE_ANIM_DURATION,
                    lifetimeRange: 160
                  },
                  emitRate: 1400,
                  shape: ParticleEmitterShape.RECTANGLE,
                  position: [0, 0],
                  size: [54, 54]
                },
                color: { range: particleColorRange() },
                opacity: { range: [0.5, 1.0] },
                scale: { range: [0.2, 0.6] },
                velocity: { angle: [150, 210], speed: [50, 130] },
                acceleration: { angle: { range: [180, 180] }, speed: { range: [40, 90] } }
              }
            ]
          })
          .width(74)
          .height(74)
          .hitTestBehavior(HitTestMode.Transparent)
        }
      }
      .width('100%')
      .height('100%')
    }
    .width(74)
    .height('100%')
    .padding({ left: 10, right: 10 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  header() {
    Row() {
      Column({ space: 3 }) {
        Text($r('app.string.home_title'))
          .fontSize(27)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          // 流光标题：主蓝渐变，力度比口令更收敛
          .shaderStyle(new LinearGradientStyle({
            angle: 20,
            colors: titleGradientColors()
          }))
        Text($r('app.string.home_subtitle'))
          .fontSize(12)
          .letterSpacing(0.6)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 磨砂玻璃胶囊按键
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_settings'))
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
      .onClick(() => this.openSettings())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  summaryBar() {
    Row({ space: 8 }) {
      Row({ space: 6 }) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.status_active'))
        Text($r('app.string.home_secure_storage'))
          .fontSize(11.5)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      Text($r('app.string.home_summary_count', this.displayItems.length))
        .fontSize(11.5)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding({ left: 24, right: 24, bottom: 10 })
    .alignItems(VerticalAlign.Center)
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

  private onCopy(item: TotpItem): void {
    this.viewModel.copyCode(item).then((result: Result<void>) => {
      const message: ResourceStr = result.success ? $r('app.string.home_copy_success')
        : (result.error !== undefined ? result.error.message : $r('app.string.home_copy_failed'));
      promptAction.showToast({ message: message });
    });
  }

  /** 条目显示名：发行方 · 账号，缺省时退回可用的一项。 */
  private itemLabel(item: TotpItem): string {
    if (item.issuer.length > 0 && item.account.length > 0) {
      return item.issuer + ' · ' + item.account;
    }
    if (item.issuer.length > 0) {
      return item.issuer;
    }
    if (item.account.length > 0) {
      return item.account;
    }
    return UiText.of($r('app.string.home_item_fallback_label'));
  }

  /** 点击左滑删除图标：先弹二次确认，确认后才真正删除（不可恢复）。 */
  private onDelete(item: TotpItem): void {
    if (this.deletingId.length > 0) {
      return;
    }
    promptAction.showDialog({
      title: $r('app.string.card_delete_confirm_title'),
      message: UiText.of($r('app.string.card_delete_confirm_message'), this.itemLabel(item)),
      buttons: [
        { text: $r('app.string.common_cancel'), color: '#666666' },
        { text: $r('app.string.common_delete'), color: '#E84026' }
      ]
    }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
      if (dialogResult.index === 1) {
        this.performDelete(item);
      }
    });
  }

  /** 确认后的实际删除：先播放「粒子消散」动画，动画结束再从数据层移除。 */
  private performDelete(item: TotpItem): void {
    // 删除动画进行中，忽略重复触发
    if (this.deletingId.length > 0) {
      return;
    }
    this.deletingId = item.id;
    // 先播放「粒子消散」动画，动画结束再从数据层移除，避免卡片瞬间消失看不出效果
    setTimeout(() => {
      this.viewModel.remove(item).then((removeResult: Result<void>) => {
        if (removeResult.success) {
          this.refreshItems();
        } else {
          const message: ResourceStr = removeResult.error !== undefined ? removeResult.error.message : $r('app.string.home_delete_failed');
          promptAction.showToast({ message: message });
        }
        this.deletingId = '';
      });
    }, DELETE_ANIM_DURATION);
  }

  build() {
    // @Entry 页面的 build 只能有唯一根节点，且必须是容器组件；AuroraBackground 是自定义组件，
    // 故由 Stack 作为根承载它。内层 Stack 再承担另一职责：bindSheet 属于通用属性，
    // 不能挂在「以尾随闭包接收内容的自定义组件」上。
    Stack() {
      AuroraBackground() {
        Stack() {
          Column() {
            this.header()

            if (this.displayItems.length === 0) {
              // 用普通容器承载 layoutWeight：避免把通用属性挂在自定义组件上
              Column() {
                EmptyState({
                  message: $r('app.string.home_empty_message'),
                  hint: $r('app.string.home_empty_hint'),
                  onTap: () => this.openAdd()
                })
              }
              .layoutWeight(1)
              .width('100%')
              .justifyContent(FlexAlign.Center)
            } else {
              this.summaryBar()

              List({ space: 14 }) {
                ForEach(this.displayItems, (display: TotpDisplayItem, index: number) => {
                  ListItem() {
                    Stack({ alignContent: Alignment.Center }) {
                      TotpCard({
                        issuer: display.item.issuer,
                        account: display.item.account,
                        secret: display.item.secret,
                        algorithm: display.item.algorithm,
                        digits: display.item.digits,
                        period: display.item.period,
                        index: index,
                        deleting: this.deletingId === display.item.id,
                        onCopy: () => {
                          this.onCopy(display.item);
                        }
                      })

                      // 删除粒子层：作为卡片兄弟节点，卡片淡出时粒子仍可见，形成「瓦解消散」观感。
                      // 画布宽取卡片宽度、发射矩形铺满卡片主体，保证粒子覆盖整卡。
                      if (this.deletingId === display.item.id) {
                        Particle({
                          particles: [
                            {
                              emitter: {
                                particle: {
                                  type: ParticleType.POINT,
                                  config: { radius: 2.8 },
                                  count: 160,
                                  lifetime: DELETE_ANIM_DURATION,
                                  lifetimeRange: 200
                                },
                                // 一次性爆发：提高发射速率让全部粒子在同一帧内散出
                                emitRate: 1800,
                                shape: ParticleEmitterShape.RECTANGLE,
                                position: [0, 0],
                                size: [340, 96]
                              },
                              color: { range: particleColorRange() },
                              opacity: { range: [0.5, 1.0] },
                              scale: { range: [0.2, 0.6] },
                              velocity: { angle: [150, 210], speed: [60, 150] },
                              acceleration: { angle: { range: [180, 180] }, speed: { range: [40, 90] } }
                            }
                          ]
                        })
                        .width('100%')
                        .height(96)
                        .align(Alignment.Center)
                        .hitTestBehavior(HitTestMode.Transparent)
                      }
                    }
                    .width('100%')
                  }
                  .swipeAction({ end: this.deleteAction(display.item) })
                }, (display: TotpDisplayItem) => display.item.id)
              }
              .layoutWeight(1)
              .width('100%')
              .padding({ left: 16, right: 16, top: 2, bottom: 90 })
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
            }

            // 悬浮光效球：右下角，带环绕呼吸光晕与点击粒子。
            // 外层布局盒为 148x148（含光晕与粒子活动区），偏移 +45 使 58 光球视觉中心落在距右下各 37vp 处。
            // 偏移挂在普通 Row 上，避免把通用属性直接挂在自定义组件上。
            Row() {
              Row() {
                GlowFab({
                  label: '＋',
                  diameter: 58,
                  onTap: () => this.openAdd()
                })
              }
              .offset({ x: 45, y: 45 })
            }
            .width('100%')
            .padding({ right: 8, bottom: 8 })
            .justifyContent(FlexAlign.End)
          }
          .width('100%')
          .height('100%')
          .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        }
        .width('100%')
        .height('100%')
        // 水平居中对齐：内容列在宽屏下按最大宽度收窄后由此居中（同 AuroraBackground 内容槽）
        .alignContent(Alignment.Top)
        // 弹窗采用居中沉浸式气泡卡片，尺寸自适应内容，告别占满屏幕的常规抽屉
        .bindSheet($$this.showAddSheet, this.addSheetBuilder(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: false,
          preferType: SheetType.CENTER,
          showClose: false,
          blurStyle: BlurStyle.COMPONENT_THICK,
          systemMaterial: cardMaterial(supportsImmersive()),
          backgroundColor: supportsImmersive() ? Color.Transparent : $r('app.color.card_background'),
          radius: LengthMetrics.vp(24),
          shadow: glassCardShadow()
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
