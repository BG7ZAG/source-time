import { RemoteBackup } from '../model/RemoteBackup';
import { parseBackupTimestamp } from '../constants/SyncConstants';
import { glassCardShadow } from '../theme/GlassStyle';

function pad2(value: number): string {
  return value < 10 ? '0' + value : value.toString();
}

function formatStamp(ms: number): string {
  const date: Date = new Date(ms);
  return date.getFullYear().toString() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate())
    + ' ' + pad2(date.getHours()) + ':' + pad2(date.getMinutes()) + ':' + pad2(date.getSeconds());
}

function formatSize(bytes: number): string {
  if (bytes <= 0) {
    return '大小未知';
  }
  if (bytes < 1024) {
    return bytes.toString() + ' B';
  }
  const kb: number = bytes / 1024;
  if (kb < 1024) {
    return kb.toFixed(1) + ' KB';
  }
  return (kb / 1024).toFixed(1) + ' MB';
}

/**
 * 云端备份选择弹窗（冰晶模态卡片）。
 *
 * 作为 CustomDialogController 的 builder 使用。列表已由调用方按时间倒序传入，
 * 默认选中第一条（最新）；用户可改选历史快照以回滚。
 *
 * ```
 * new CustomDialogController({
 *   builder: BackupPickerDialog({ backups: [...], selected: backups[0].name, onConfirm: ... }),
 *   autoCancel: true,
 *   customStyle: true,
 *   alignment: DialogAlignment.Center
 * })
 * ```
 */
@CustomDialog
export struct BackupPickerDialog {
  controller?: CustomDialogController;
  /** 备份列表，已按时间倒序（最新在前）。 */
  backups: RemoteBackup[] = [];
  /** 默认选中的文件名（通常为最新一条）。 */
  selected: string = '';
  onConfirm: (fileName: string) => void = () => {};
  onCancel: () => void = () => {};

  @State current: string = '';

  aboutToAppear(): void {
    if (this.selected.length > 0) {
      this.current = this.selected;
    } else if (this.backups.length > 0) {
      this.current = this.backups[0].name;
    }
  }

  private isLatest(index: number): boolean {
    return index === 0;
  }

  private displayTime(item: RemoteBackup): string {
    let ms: number = item.lastModified;
    if (ms <= 0) {
      ms = parseBackupTimestamp(item.name);
    }
    if (ms <= 0) {
      return '时间未知';
    }
    return formatStamp(ms);
  }

  /** 列表标题：仅最新一条显示「最新」，其余直接显示时间。 */
  private displayTitle(item: RemoteBackup, index: number): string {
    return this.isLatest(index) ? '最新' : this.displayTime(item);
  }

  @Builder
  backupRow(item: RemoteBackup, index: number) {
    Row({ space: 10 }) {
      Radio({ value: item.name, group: 'backupPicker' })
        .checked(this.current === item.name)
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.current = item.name;
          }
        })

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(this.displayTitle(item, index))
            .fontSize(13.5)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          if (this.isLatest(index)) {
            Text(this.displayTime(item))
              .fontSize(12.5)
              .fontColor($r('app.color.text_secondary'))
          }
          Blank()
          Text(formatSize(item.size))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(item.name)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 6, right: 12, top: 10, bottom: 10 })
    .borderRadius(16)
    .backgroundColor(this.current === item.name ? $r('app.color.field_background') : $r('app.color.card_background'))    .onClick(() => {
      this.current = item.name;
    })
  }

  build() {
    Column({ space: 16 }) {
      // 顶部拖拽指示条，呼应半沉浸抽屉形态
      Column()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor($r('app.color.divider'))

      Column({ space: 4 }) {
        Text('选择要恢复的备份')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('共 ' + this.backups.length + ' 份 · 默认最新；恢复将覆盖本机数据')
          .fontSize(11.5)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')

      List({ space: 6 }) {
        ForEach(this.backups, (item: RemoteBackup, index: number) => {
          ListItem() {
            this.backupRow(item, index)
          }
        }, (item: RemoteBackup) => item.name)
      }
      .width('100%')
      .height(Math.min(this.backups.length, 5) * 66)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(46)
          .borderRadius(23)
          .fontSize(15)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onCancel())

        Button('恢复此备份')
          .layoutWeight(1)
          .height(46)
          .borderRadius(23)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .enabled(this.current.length > 0)
          .linearGradient({
            angle: 90,
            colors: [[$r('app.color.brand'), 0.0], [$r('app.color.brand_secondary'), 1.0]]
          })
          .fontColor($r('app.color.fab_foreground'))
          .shadow({ radius: 12, color: '#590A59F7', offsetX: 0, offsetY: 4 })
          .onClick(() => this.onConfirm(this.current))
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 14, bottom: 22 })
    .borderRadius(28)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
  }
}
