import { ShowDialogSuccessResponse, window } from '@kit.ArkUI';
import { TotpCard, DELETE_ANIM_DURATION } from '../components/TotpCard';
import { EmptyState, GlowFab } from '../components/EmptyState';
import { HomeSearchField } from '../components/HomeSearchField';
import { AuroraBackground } from '../components/AuroraBackground';
import { AddTotpSheet } from '../components/AddTotpSheet';
import { RenameDialog } from '../components/RenameDialog';
import { HomeViewModel, TotpDisplayItem } from '../viewmodel/HomeViewModel';
import { TotpItem } from '../model/TotpItem';
import { Result } from '../types/Result';
import { AppRoutes } from '../constants/AppConstants';
import {
  CONTENT_MAX_WIDTH,
  GRID_MIN_WIDTH,
  OVERLAY_MAX_WIDTH,
  MENU_WIDTH
} from '../constants/LayoutConstants';
import { SettingsService } from '../service/SettingsService';
import { UiText } from '../utils/UiText';
import { DeviceAdapter } from '../utils/DeviceAdapter';
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
  /** 软键盘高度（vp）：新增口令是居中气泡卡片，需要自己把卡片抬到键盘上方。 */
  @State keyboardHeightVp: number = 0;
  /** 全模态覆盖层高度（vp）：与键盘高度一起算出卡片可用高度。 */
  @State overlayHeightVp: number = 0;
  /** 当前窗口宽度（vp）：分屏/悬浮窗下用它判断还适不适合双列网格。 */
  @State windowWidthVp: number = 0;
  /** 搜索关键词：按发行方/账号过滤。 */
  @State searchQuery: string = '';
  /** 当前打开长按菜单的条目 id（空串表示没有菜单）。 */
  @State menuCardId: string = '';
  private mainWindow: window.Window | undefined = undefined;
  /** 重命名弹窗：每次打开都新建，保证输入框初值取自当前条目而不是首次快照。 */
  private renameDialog: CustomDialogController | undefined = undefined;
  private viewModel: HomeViewModel = new HomeViewModel();
  private settingsService: SettingsService = new SettingsService();
  /** 监听软键盘高度：仅用于把新增口令的居中卡片抬到键盘上方。 */
  private bindKeyboardHeight(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    window.getLastWindow(context).then((win: window.Window) => {
      this.mainWindow = win;
      win.on('keyboardHeightChange', (height: number) => {
        this.keyboardHeightVp = px2vp(height);
      });
    }).catch(() => {
      this.mainWindow = undefined;
    });
  }

  aboutToAppear(): void {
    this.bindKeyboardHeight();
    this.loadData();
  }

  aboutToDisappear(): void {
    this.mainWindow?.off('keyboardHeightChange');
    this.mainWindow = undefined;
  }

  onPageShow(): void {
    // 密钥尚未初始化时由 EntryAbility 引导到安全页，这里只加载已完成初始化的数据
    if (this.settingsService.getSettings().encryptionInitialized) {
      this.loadData();
    }
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
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.home_decrypt_dialog_title'),
      message: UiText.of($r('app.string.home_decrypt_dialog_message'), errorText),
      buttons: [
        { text: $r('app.string.home_decrypt_stay_button'), color: '#666666' },
        { text: $r('app.string.home_decrypt_reset_button'), color: '#E84026' }
      ]
    }).then((dialogResult: ShowDialogSuccessResponse) => {
      if (dialogResult.index !== 1) {
        return;
      }
      this.viewModel.resetLocalData().then((resetResult: Result<void>) => {
        if (resetResult.success) {
          this.refreshItems();
          this.getUIContext().getPromptAction().showToast({ message: $r('app.string.home_reset_success_toast') });
        } else {
          const failMessage: ResourceStr =
            resetResult.error !== undefined ? resetResult.error.message : $r('app.string.home_reset_error_fallback');
          this.getUIContext().getPromptAction().showToast({ message: failMessage });
        }
      });
    });
  }

  /**
   * 刷新首页展示列表：数据层更新后重新取一次展示项。
   */
  private refreshItems(): void {
    this.displayItems = this.viewModel.getDisplayItems();
  }

  /**
   * ForEach 的 key 必须带上会变化的展示字段。只用 id 时，改名后 key 不变，
   * ArkUI 会复用旧卡片节点，列表里仍是旧名称（实测：保存成功、库已更新，但卡片没变）。
   */
  private cardKey(display: TotpDisplayItem): string {
    return display.item.id + '|' + display.item.issuer + '|' + display.item.account;
  }

  /**
   * 搜索过滤：按发行方与账号做不区分大小写的包含匹配。
   * 关键词为空时直接返回原数组，不产生额外拷贝。
   */
  private filteredItems(): TotpDisplayItem[] {
    const keyword: string = this.searchQuery.trim().toLowerCase();
    if (keyword.length === 0) {
      return this.displayItems;
    }
    return this.displayItems.filter((display: TotpDisplayItem) =>
      display.item.issuer.toLowerCase().indexOf(keyword) >= 0 ||
      display.item.account.toLowerCase().indexOf(keyword) >= 0);
  }


  private openSettings(): void {
    this.getUIContext().getRouter().pushUrl({ url: AppRoutes.SETTINGS });
  }

  private openAdd(): void {
    this.showAddSheet = true;
  }

  @Builder
  addSheetBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      // 遮罩：必须自己铺满整个覆盖层。此前与卡片共用 16vp 的 padding，
      // 导致屏幕左右各漏出一条没有被遮住的边（暗色模式下尤其明显）。
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.modal_scrim'))
        .onClick(() => {
          this.showAddSheet = false;
        })

      // 卡片承载区：留白只作用在卡片上，并且靠下对齐——弹窗从屏幕底部向上生长，
      // 键盘弹出时底部留白变大，卡片整体被抬到键盘上方。
      Column() {
        // 气泡卡片：样式原先由 bindSheet 的 blur/radius/shadow 选项提供，
        // 改为内容自绘——半模态（尤其 SheetType.CENTER）在系统层面不做键盘避让，
        // 键盘一弹就把表单下半截和「保存口令」压在下面，弹出层内部还不可滚动。
        Column() {
          AddTotpSheet({
            // 卡片可用高度：内容超出时由面板内部的 Scroll 承接滚动（手机键盘弹出时用得上）
            contentMaxHeight: this.addCardMaxHeight(),
            onSaved: () => {
              this.showAddSheet = false;
              this.viewModel.load().then(() => {
                this.refreshItems();
              });
            },
            onScan: () => {
              this.showAddSheet = false;
              this.getUIContext().getRouter().pushUrl({ url: AppRoutes.SCAN });
            }
          })
        }
        .width('100%')
        // 宽屏下不被拉成整屏宽：平板上一张 560vp 的卡片，两侧留给遮罩
        .constraintSize({ maxWidth: OVERLAY_MAX_WIDTH, maxHeight: this.addCardMaxHeight() })
        .borderRadius(24)
        .clip(true)
        .systemMaterial(cardMaterial(supportsImmersive()))
        .backgroundColor(supportsImmersive() ? Color.Transparent : $r('app.color.card_background'))
        .backgroundBlurStyle(supportsImmersive() ? BlurStyle.NONE : BlurStyle.COMPONENT_THICK)
        .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
        .shadow(glassCardShadow())
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 + this.keyboardHeightVp })
      .justifyContent(FlexAlign.End)
      // 承载区自身不参与命中测试：卡片以外的空白处点击仍会落到遮罩上关闭弹窗
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.overlayHeightVp = newValue.height as number;
    })
  }

  /** 卡片可用高度（vp）：可视区高度减去上下留白与键盘高度；未知时给一个足够大的值。 */
  private addCardMaxHeight(): number {
    if (this.overlayHeightVp <= 0) {
      return 4000;
    }
    return this.overlayHeightVp - 32 - this.keyboardHeightVp;
  }

  /**
   * 是否使用双列网格。
   *
   * 设备类型之外还要看**当前窗口宽度**：平板一旦分屏/开悬浮窗，窗口可能只剩 400vp，
   * 此时若仍按双列排，每张卡不到 200vp，38vp 的验证码会被挤爆。
   */
  private useGridLayout(): boolean {
    if (!DeviceAdapter.useGridLayout()) {
      return false;
    }
    return this.windowWidthVp <= 0 || this.windowWidthVp >= GRID_MIN_WIDTH;
  }

  /**
   * 卡片长按菜单：宽屏网格布局没有左滑手势（swipeAction 只挂在线性列表上），
   * 且平板上左滑删除本身也不好发现，这里补「长按 → 重命名 / 删除」。
   *
   * 菜单很窄，用自绘 Row 而不是 MenuItem：MenuItem 的内容只能左对齐，
   * 两三个字挤在左边会显得很空。
   */
  @Builder
  menuItem(label: ResourceStr, color: ResourceColor, dividerOnTop: boolean, action: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(color)
    }
    .width('100%')
    .height(46)
    .justifyContent(FlexAlign.Center)
    .borderRadius(12)
    // Menu 的子组件只能是 MenuItem，塞不进 Divider，用上边框代替分隔线
    .border({
      width: { top: dividerOnTop ? 1 : 0 },
      color: $r('app.color.divider'),
      style: BorderStyle.Solid
    })
    .onClick(action)
  }

  @Builder
  cardMenu(item: TotpItem) {
    Column() {
      this.menuItem($r('app.string.menu_rename'), $r('app.color.text_primary'), false, () => {
        this.closeCardMenu();
        this.openRename(item);
      })
      this.menuItem($r('app.string.common_delete'), $r('app.color.danger'), true, () => {
        this.closeCardMenu();
        this.onDelete(item);
      })
    }
    .width(MENU_WIDTH)
  }

  /** 长按卡片：打开该条目的操作气泡。 */
  private openCardMenu(item: TotpItem): void {
    this.menuCardId = item.id;
  }

  /** 菜单项点完立刻收起：bindPopup 由状态驱动，不像 bindContextMenu 那样只能等系统收起。 */
  private closeCardMenu(): void {
    this.menuCardId = '';
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
          .fontSize(DeviceAdapter.titleFontSize())
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          // 流光标题：主蓝渐变，力度比口令更收敛
          .shaderStyle(new LinearGradientStyle({
            angle: 20,
            colors: titleGradientColors()
          }))
        Text($r('app.string.home_subtitle'))
          .fontSize(DeviceAdapter.subtitleFontSize())
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
      .onHover((isHover: boolean) => {
        DeviceAdapter.applyHoverCursor(this.getUIContext().getCursorController(), isHover);
      })
      .onClick(() => this.openSettings())
    }
    .width('100%')
    .padding({
      left: DeviceAdapter.pagePaddingH(),
      right: DeviceAdapter.pagePaddingH(),
      top: 14,
      bottom: 14
    })
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
    // 与卡片同一横向内边距：用 24 会比卡片窄 8vp，顶部信息看起来「缩进」了一截
    .padding({ left: DeviceAdapter.pagePaddingH(), right: DeviceAdapter.pagePaddingH(), bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 首页搜索：按发行方/账号实时过滤口令卡片。
   * 外层 Row 只负责页面内边距，避免 width('100%') + margin 互相挤压。
   */
  @Builder
  searchBar() {
    Row() {
      HomeSearchField({ query: $searchQuery })
    }
    .width('100%')
    .padding({ left: DeviceAdapter.pagePaddingH(), right: DeviceAdapter.pagePaddingH(), bottom: 10 })
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
      this.getUIContext().getPromptAction().showToast({ message: message });
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

  /** 长按菜单「重命名」：只改名称与账号，密钥不动，所以不用再校验密钥。 */
  private openRename(item: TotpItem): void {
    this.renameDialog = new CustomDialogController({
      builder: RenameDialog({
        issuer: item.issuer,
        account: item.account,
        onCancel: () => {
          this.closeRename();
        },
        onConfirm: (issuer: string, account: string) => {
          this.performRename(item, issuer, account);
        }
      }),
      autoCancel: true,
      customStyle: true,
      maskColor: '#66000000',
      alignment: DialogAlignment.Center
    });
    this.renameDialog.open();
  }

  private closeRename(): void {
    if (this.renameDialog !== undefined) {
      this.renameDialog.close();
      this.renameDialog = undefined;
    }
  }

  private performRename(item: TotpItem, issuer: string, account: string): void {
    this.viewModel.rename(item, issuer, account).then((result: Result<void>) => {
      this.closeRename();
      const message: ResourceStr = result.success ? $r('app.string.rename_saved_toast')
        : (result.error !== undefined ? result.error.message : $r('app.string.rename_failed'));
      this.getUIContext().getPromptAction().showToast({ message: message });
      if (result.success) {
        this.refreshItems();
      }
    });
  }

  /** 点击左滑删除图标：先弹二次确认，确认后才真正删除（不可恢复）。 */
  private onDelete(item: TotpItem): void {
    if (this.deletingId.length > 0) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.card_delete_confirm_title'),
      message: UiText.of($r('app.string.card_delete_confirm_message'), this.itemLabel(item)),
      buttons: [
        { text: $r('app.string.common_cancel'), color: '#666666' },
        { text: $r('app.string.common_delete'), color: '#E84026' }
      ]
    }).then((dialogResult: ShowDialogSuccessResponse) => {
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
          this.getUIContext().getPromptAction().showToast({ message: message });
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
                  symbol: '＋',
                  clickable: true,
                  onTap: () => this.openAdd()
                })
              }
              .layoutWeight(1)
              .width('100%')
              .justifyContent(FlexAlign.Center)
            } else {
              this.summaryBar()
              this.searchBar()

              // 有数据但搜索无结果：给出明确提示，而不是渲染空列表
              if (this.filteredItems().length === 0) {
                Column() {
                  Text($r('app.string.home_search_empty'))
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding({ bottom: 90 })
              } else if (this.useGridLayout()) {
                Scroll() {
                  GridRow({ columns: 2, gutter: { x: DeviceAdapter.listSpacing(), y: DeviceAdapter.listSpacing() } }) {
                    ForEach(this.filteredItems(), (display: TotpDisplayItem, index: number) => {
                      GridCol() {
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
                            },
                            onMore: () => {
                              this.openCardMenu(display.item);
                            },
                            menuVisible: this.menuCardId === display.item.id,
                            menuBuilder: () => {
                              this.cardMenu(display.item);
                            },
                            onMenuDismiss: () => {
                              this.closeCardMenu();
                            }
                          })
                        }
                        .width('100%')
                        // 网格卡片没有左滑手势，长按也能弹「重命名 / 删除」
                        .gesture(LongPressGesture().onAction(() => {
                          this.openCardMenu(display.item);
                        }))
                      }
                    }, (display: TotpDisplayItem) => this.cardKey(display))
                  }
                  .width('100%')
                  .padding({
                    left: DeviceAdapter.pagePaddingH(),
                    right: DeviceAdapter.pagePaddingH(),
                    top: 2,
                    bottom: 90
                  })
                }
                .layoutWeight(1)
                .align(Alignment.TopStart)  // 内容不足一屏时不被 Scroll 垂直居中（平板双列网格）
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
              } else {
                // 手机：单列列表
                List({ space: DeviceAdapter.listSpacing() }) {
                  ForEach(this.filteredItems(), (display: TotpDisplayItem, index: number) => {
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
                          },
                          onMore: () => {
                            this.openCardMenu(display.item);
                          },
                          menuVisible: this.menuCardId === display.item.id,
                          menuBuilder: () => {
                            this.cardMenu(display.item);
                          },
                          onMenuDismiss: () => {
                            this.closeCardMenu();
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
                      // 与网格一致：长按也能重命名/删除（左滑是隐藏手势，长按更好发现）
                      .gesture(LongPressGesture().onAction(() => {
                        this.openCardMenu(display.item);
                      }))
                    }
                    .swipeAction({ end: this.deleteAction(display.item) })
                  }, (display: TotpDisplayItem) => this.cardKey(display))
                }
                .layoutWeight(1)
                .width('100%')
                .padding({
                  left: DeviceAdapter.pagePaddingH(),
                  right: DeviceAdapter.pagePaddingH(),
                  top: 2,
                  bottom: 90
                })
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
              }
            }

            // 悬浮光效球：右下角，带环绕呼吸光晕与点击粒子。
            // 外层布局盒为 148x148（含光晕与粒子活动区），偏移 +45 使 58 光球视觉中心落在距右下各 37vp 处。
            // 偏移挂在普通 Row 上，避免把通用属性直接挂在自定义组件上。
            Row() {
              Row() {
                GlowFab({
                  label: '＋',
                  diameter: DeviceAdapter.fabDiameter(),
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
        .bindContentCover($$this.showAddSheet, this.addSheetBuilder(), {
          modalTransition: ModalTransition.DEFAULT,
          backgroundColor: Color.Transparent
        })
      }
    }
    .width('100%')
    .height('100%')
    // 记录窗口宽度：分屏/悬浮窗拖动时实时更新，驱动单列 ↔ 双列切换
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.windowWidthVp = newArea.width as number;
    })
  }
}
