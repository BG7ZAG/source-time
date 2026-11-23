import { LocalBackupKind } from '../model/LocalBackup';
import { TotpItem } from '../model/TotpItem';
import { DIALOG_MAX_WIDTH } from '../constants/LayoutConstants';
import { glassCardShadow } from '../theme/GlassStyle';

/** 预览弹窗最多读取的条目数；超出部分只显示数量提示。 */
const PREVIEW_ITEM_LIMIT: number = 8;
/** 列表固定展示的行数：内容较多时在列表内滚动，弹窗高度保持稳定。 */
const PREVIEW_VISIBLE_ROWS: number = 4;

function pad2(value: number): string {
  return value < 10 ? '0' + value : value.toString();
}

function formatStamp(ms: number): string {
  const date: Date = new Date(ms);
  return date.getFullYear().toString() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate())
    + ' ' + pad2(date.getHours()) + ':' + pad2(date.getMinutes());
}

/**
 * 本机备份导入前的预览弹窗。
 *
 * 作为 CustomDialogController 的 builder 使用：调用方负责读取文件并解析出
 * `kind` / `items`，确认后回调 onConfirm，由调用方真正覆盖本地数据。
 */
@CustomDialog
export struct LocalBackupPreviewDialog {
  controller?: CustomDialogController;
  /** 备份文件名（仅展示）。 */
  fileName: string = '';
  /** 备份类型：加密备份或明文备份。 */
  kind: LocalBackupKind = LocalBackupKind.ENCRYPTED;
  /** 备份内的口令条目。 */
  items: TotpItem[] = [];
  /** 备份的数据更新时间（毫秒，0 表示未知）。 */
  updatedAt: number = 0;
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};

  private isEncrypted(): boolean {
    return this.kind === LocalBackupKind.ENCRYPTED;
  }

  private kindLabel(): ResourceStr {
    return this.isEncrypted() ? $r('app.string.local_backup_kind_encrypted')
      : $r('app.string.local_backup_kind_plain');
  }

  private metaText(): ResourceStr {
    const time: ResourceStr = this.updatedAt > 0 ? formatStamp(this.updatedAt)
      : $r('app.string.webdav_time_unknown');
    return $r('app.string.local_backup_preview_meta', this.items.length, time);
  }

  private displayName(item: TotpItem): string {
    if (item.issuer.length > 0) {
      return item.issuer;
    }
    return item.account.length > 0 ? item.account : '—';
  }

  private displayAccount(item: TotpItem): string {
    if (item.issuer.length > 0) {
      return item.account.length > 0 ? item.account : '—';
    }
    return '';
  }

  private visibleItems(): TotpItem[] {
    return this.items.slice(0, PREVIEW_ITEM_LIMIT);
  }

  private hiddenCount(): number {
    return this.items.length > PREVIEW_ITEM_LIMIT ? this.items.length - PREVIEW_ITEM_LIMIT : 0;
  }

  /** 列表可视高度：最多 4 行，多出的条目在列表内滚动。 */
  private listHeight(): number {
    const rows: number = this.visibleItems().length < PREVIEW_VISIBLE_ROWS
      ? this.visibleItems().length : PREVIEW_VISIBLE_ROWS;
    return rows * 52;
  }

  @Builder
  itemRow(item: TotpItem) {
    Row({ space: 10 }) {
      Text(item.issuer.length > 0 ? item.issuer.substring(0, 1).toUpperCase() : '#')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor($r('app.color.scrim'))

      Column({ space: 2 }) {
        Text(this.displayName(item))
          .fontSize(13.5)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.displayAccount(item).length > 0) {
          Text(this.displayAccount(item))
            .fontSize(11.5)
            .fontColor($r('app.color.text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column({ space: 14 }) {
      // 顶部拖拽指示条，与本项目其它弹窗保持一致
      Column()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor($r('app.color.divider'))

      Column({ space: 4 }) {
        Text($r('app.string.local_backup_preview_title'))
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.local_backup_preview_subtitle'))
          .fontSize(11.5)
          .lineHeight(17)
          .textAlign(TextAlign.Center)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')

      // 备份概要：类型徽标 + 条目数/时间 + 文件名
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(this.kindLabel())
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isEncrypted() ? $r('app.color.brand') : $r('app.color.warning'))
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .borderRadius(7)
            .backgroundColor($r('app.color.scrim'))
          Blank()
          Text(this.metaText())
            .fontSize(11.5)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.fileName.length > 0 ? this.fileName : '—')
          .fontSize(11.5)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .padding(12)
      .borderRadius(14)
      .backgroundColor($r('app.color.field_background'))
      .border({ width: 1, color: $r('app.color.field_border'), style: BorderStyle.Solid })

      if (this.items.length === 0) {
        Text($r('app.string.local_backup_preview_empty'))
          .fontSize(12.5)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      } else {
        Column({ space: 6 }) {
          Text($r('app.string.local_backup_preview_items'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          List({ space: 4 }) {
            ForEach(this.visibleItems(), (item: TotpItem, index: number) => {
              ListItem() {
                this.itemRow(item)
              }
            }, (item: TotpItem, index: number) => item.id + '|' + index)
          }
          .width('100%')
          .height(this.listHeight())
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          if (this.hiddenCount() > 0) {
            Text($r('app.string.local_backup_preview_more', this.hiddenCount()))
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Text($r('app.string.local_backup_overwrite_warning'))
        .fontSize(11)
        .lineHeight(17)
        .fontColor($r('app.color.danger'))
        .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.common_cancel'))
          .layoutWeight(1)
          .height(46)
          .borderRadius(23)
          .fontSize(15)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onCancel())

        Button($r('app.string.local_backup_preview_confirm'))
          .layoutWeight(1)
          .height(46)
          .borderRadius(23)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .linearGradient({
            angle: 90,
            colors: [[$r('app.color.brand'), 0.0], [$r('app.color.brand_secondary'), 1.0]]
          })
          .fontColor($r('app.color.fab_foreground'))
          .shadow({ radius: 12, color: '#590A59F7', offsetX: 0, offsetY: 4 })
          .onClick(() => this.onConfirm())
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: DIALOG_MAX_WIDTH })
    .padding({ left: 18, right: 18, top: 14, bottom: 22 })
    .borderRadius(28)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
  }
}