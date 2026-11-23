import { DIALOG_MAX_WIDTH } from '../constants/LayoutConstants';
import { glassCardShadow } from '../theme/GlassStyle';
import { SheetField } from './AddTotpSheet';

/**
 * 重命名口令（冰晶模态卡片）。
 *
 * 只改 issuer / account 两个展示字段：密钥、算法、位数、周期都不动，
 * 因此不需要重新输入或校验密钥，也不必走「删除 + 重新添加」。
 *
 * 作为 CustomDialogController 的 builder 使用（每次打开新建一个 controller，
 * 这样 issuer / account 的初值一定是当前条目的最新值，而不是组件首次创建时的快照）：
 * ```
 * new CustomDialogController({
 *   builder: RenameDialog({ issuer: ..., account: ..., onConfirm: ... }),
 *   autoCancel: true, customStyle: true, alignment: DialogAlignment.Center
 * })
 * ```
 */
@CustomDialog
export struct RenameDialog {
  controller?: CustomDialogController;
  /** 当前条目的名称与账号，作为输入框初值。 */
  issuer: string = '';
  account: string = '';
  onCancel: () => void = () => {};
  onConfirm: (issuer: string, account: string) => void = () => {};

  @State draftIssuer: string = '';
  @State draftAccount: string = '';
  @State busy: boolean = false;

  aboutToAppear(): void {
    this.draftIssuer = this.issuer;
    this.draftAccount = this.account;
  }

  private submit(): void {
    if (this.busy) {
      return;
    }
    const issuer: string = this.draftIssuer.trim();
    const account: string = this.draftAccount.trim();
    // 两个都空时卡片会退化成「未命名」，直接拦下来
    if (issuer.length === 0 && account.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.rename_empty_hint') });
      return;
    }
    this.busy = true;
    this.onConfirm(issuer, account);
  }

  @Builder
  fieldLabel(label: ResourceStr) {
    Text(label)
      .fontSize(12)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 4 }) {
        Text($r('app.string.rename_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
        Text($r('app.string.rename_desc'))
          .fontSize(11.5)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Column({ space: 12 }) {
        Column({ space: 6 }) {
          this.fieldLabel($r('app.string.rename_issuer_label'))
          SheetField({ value: $draftIssuer, placeholder: $r('app.string.rename_issuer_hint'), numeric: false })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          this.fieldLabel($r('app.string.rename_account_label'))
          SheetField({ value: $draftAccount, placeholder: $r('app.string.rename_account_hint'), numeric: false })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.common_cancel'))
          .layoutWeight(1)
          .height(44)
          .borderRadius(22)
          .fontSize(15)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onCancel())

        Button($r('app.string.rename_save'))
          .layoutWeight(1)
          .height(44)
          .borderRadius(22)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .linearGradient({
            angle: 90,
            colors: [[$r('app.color.brand'), 0.0], [$r('app.color.brand_secondary'), 1.0]]
          })
          .fontColor($r('app.color.fab_foreground'))
          .shadow({ radius: 12, color: '#590A59F7', offsetX: 0, offsetY: 4 })
          .enabled(!this.busy)
          .onClick(() => this.submit())
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: DIALOG_MAX_WIDTH })
    .padding({ left: 22, right: 22, top: 20, bottom: 20 })
    .borderRadius(26)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
  }
}
