import { router, promptAction, LengthMetrics } from '@kit.ArkUI';
import { TotpCard } from '../components/TotpCard';
import { EmptyState, GlowFab } from '../components/EmptyState';
import { AuroraBackground } from '../components/AuroraBackground';
import { AddTotpSheet } from '../components/AddTotpSheet';
import { PrivacyDialog } from '../components/PrivacyDialog';
import { HomeViewModel, TotpDisplayItem } from '../viewmodel/HomeViewModel';
import { TotpItem } from '../model/TotpItem';
import { Result } from '../types/Result';
import { AppRoutes, CURRENT_PRIVACY_POLICY_VERSION } from '../constants/AppConstants';
import { SettingsService } from '../service/SettingsService';
import { AppContextHolder } from '../utils/AppContextHolder';
import {
  cardMaterial,
  frostedPillColor,
  glassCardShadow,
  glassPillShadow,
  supportsImmersive,
  titleGradientColors
} from '../theme/GlassStyle';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

@Entry
@Component
struct HomePage {
  @State displayItems: TotpDisplayItem[] = [];
  @State showAddSheet: boolean = false;
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
    if (!settings.privacyPolicyAccepted) {
      this.privacyDialog.open();
      return;
    }
    this.loadData();
  }

  onPageShow(): void {
    const settings = this.settingsService.getSettings();
    if (settings.privacyPolicyAccepted && settings.encryptionInitialized) {
      this.viewModel.load().then(() => {
        this.refreshItems();
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
      this.viewModel.load().then(() => {
        this.refreshItems();
      });
    }
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

  @Builder
  header() {
    Row() {
      Column({ space: 3 }) {
        Text('源时')
          .fontSize(27)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          // 流光标题：主蓝渐变，力度比口令更收敛
          .shaderStyle(new LinearGradientStyle({
            angle: 20,
            colors: titleGradientColors()
          }))
        Text('TOTP 动态口令')
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
        Text('本地加密存储')
          .fontSize(11.5)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      Text('共 ' + this.displayItems.length.toString() + ' 个口令')
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
      const message: string = result.success ? '复制成功'
        : (result.error !== undefined ? result.error.message : '复制失败');
      promptAction.showToast({ message: message });
    });
  }

  private onDelete(item: TotpItem): void {
    promptAction.showDialog({
      title: '删除验证码？',
      message: '删除后该验证码将从本地数据中移除。',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '删除', color: '#E84026' }
      ]
    }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
      if (dialogResult.index === 1) {
        this.viewModel.remove(item).then((removeResult: Result<void>) => {
          if (removeResult.success) {
            this.refreshItems();
          } else {
            const message: string = removeResult.error !== undefined ? removeResult.error.message : '删除失败';
            promptAction.showToast({ message: message });
          }
        });
      }
    });
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
                EmptyState({ message: '还没有口令', hint: '点击右下角光球添加' })
              }
              .layoutWeight(1)
              .width('100%')
              .justifyContent(FlexAlign.Center)
            } else {
              this.summaryBar()

              List({ space: 14 }) {
                ForEach(this.displayItems, (display: TotpDisplayItem, index: number) => {
                  ListItem() {
                    TotpCard({
                      issuer: display.item.issuer,
                      account: display.item.account,
                      secret: display.item.secret,
                      algorithm: display.item.algorithm,
                      digits: display.item.digits,
                      period: display.item.period,
                      index: index,
                      onCopy: () => {
                        this.onCopy(display.item);
                      },
                      onDelete: () => {
                        this.onDelete(display.item);
                      }
                    })
                  }
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
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.TopStart)
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
