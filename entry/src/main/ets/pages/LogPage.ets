import { promptAction, router } from '@kit.ArkUI';
import { AuroraBackground } from '../components/AuroraBackground';
import { ClipboardService } from '../service/ClipboardService';
import { Logger } from '../utils/Logger';
import { LogEntry, LogLevel } from '../model/LogEntry';
import { Result } from '../types/Result';
import { frostedPillColor, glassCardShadow, glassGroupShadow, glassPillShadow } from '../theme/GlassStyle';
import { CONTENT_MAX_WIDTH } from '../constants/LayoutConstants';

const FILTER_ALL: string = 'ALL';
const FILTER_INFO: string = 'INFO';
const FILTER_WARN: string = 'WARN';
const FILTER_ERROR: string = 'ERROR';

/**
 * 统计项参数。
 *
 * ArkUI 的 @Builder 按值传参时，状态变量变化不会引起其内部 UI 刷新；
 * 只有传入对象字面量（按引用传参）才会随状态刷新。故参数收敛为一个对象。
 */
interface StatItemParams {
  label: ResourceStr;
  value: string;
  color: Resource;
}

/**
 * 运行日志页：展示本机日志（含历史），支持按级别筛选、复制、清空。
 *
 * 日志内容在 Logger 入库前已脱敏，本页不接触任何明文机密；
 * 数据只保存在应用沙箱内（filesDir/sourcetime_logs.ndjson），不上传、不联网。
 */
@Entry
@Component
struct LogPage {
  /** 展示用列表：倒序（最新在最上），已按当前筛选条件过滤 */
  @State entries: LogEntry[] = [];
  @State filter: string = FILTER_ALL;
  @State total: number = 0;
  @State warnCount: number = 0;
  @State errorCount: number = 0;

  private clipboardService: ClipboardService = new ClipboardService();

  aboutToAppear(): void {
    // 先把内存中的日志落盘，保证「本机已保存」与页面展示一致
    Logger.flush();
    this.reload();
  }

  private reload(): void {
    const all: LogEntry[] = Logger.getEntries();
    const display: LogEntry[] = [];
    // 倒序遍历：最新日志排最前
    for (let index = all.length - 1; index >= 0; index--) {
      display.push(all[index]);
    }
    let warn: number = 0;
    let error: number = 0;
    for (const entry of all) {
      if (entry.level === LogLevel.WARN) {
        warn++;
      } else if (entry.level === LogLevel.ERROR) {
        error++;
      }
    }
    this.total = all.length;
    this.warnCount = warn;
    this.errorCount = error;
    this.entries = display;
  }

  private visibleEntries(): LogEntry[] {
    if (this.filter === FILTER_ALL) {
      return this.entries;
    }
    const filtered: LogEntry[] = [];
    for (const entry of this.entries) {
      if (this.matches(entry)) {
        filtered.push(entry);
      }
    }
    return filtered;
  }

  private matches(entry: LogEntry): boolean {
    if (this.filter === FILTER_INFO) {
      // 「信息」档同时包含 DEBUG，避免调试日志在筛选下彻底不可见
      return entry.level === LogLevel.INFO || entry.level === LogLevel.DEBUG;
    }
    if (this.filter === FILTER_WARN) {
      return entry.level === LogLevel.WARN;
    }
    return entry.level === LogLevel.ERROR;
  }

  /** 级别语义色（返回 Resource，与本项目其他页面一致）。 */
  private levelColor(level: LogLevel): Resource {
    if (level === LogLevel.ERROR) {
      return $r('app.color.danger');
    }
    if (level === LogLevel.WARN) {
      return $r('app.color.warning');
    }
    if (level === LogLevel.DEBUG) {
      return $r('app.color.text_tertiary');
    }
    return $r('app.color.brand');
  }

  private two(value: number): string {
    return value < 10 ? '0' + String(value) : String(value);
  }

  private formatTime(milliseconds: number): string {
    const date: Date = new Date(milliseconds);
    return this.two(date.getMonth() + 1) + '-' + this.two(date.getDate())
      + ' ' + this.two(date.getHours()) + ':' + this.two(date.getMinutes()) + ':' + this.two(date.getSeconds());
  }

  private onCopyAll(): void {
    const text: string = Logger.toDisplayText();
    if (text.length === 0) {
      promptAction.showToast({ message: $r('app.string.log_nothing_to_copy') });
      return;
    }
    this.clipboardService.copyText(text).then((result: Result<void>) => {
      if (!result.success || result.error !== undefined) {
        const message: ResourceStr = result.error !== undefined ? result.error.message : $r('app.string.log_copy_failed');
        promptAction.showToast({ message: message });
        return;
      }
      promptAction.showToast({ message: $r('app.string.log_copied') });
    });
  }

  private onClear(): void {
    promptAction.showDialog({
      title: $r('app.string.log_clear_dialog_title'),
      message: $r('app.string.log_clear_dialog_message'),
      buttons: [
        { text: $r('app.string.common_cancel'), color: '#666666' },
        { text: $r('app.string.log_clear_confirm'), color: '#E84026' }
      ]
    }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
      if (dialogResult.index !== 1) {
        return;
      }
      Logger.clearLogs();
      this.reload();
      promptAction.showToast({ message: $r('app.string.log_cleared') });
    });
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

      Text($r('app.string.log_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Blank()

      Text('')
        .width(42)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  statItem(params: StatItemParams) {
    Column({ space: 4 }) {
      Text(params.value)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(params.color)
      Text(params.label)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  filterChip(label: ResourceStr, value: string) {
    Text(label)
      .fontSize(12.5)
      .fontWeight(this.filter === value ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.filter === value ? $r('app.color.brand') : $r('app.color.text_secondary'))
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius(15)
      .backgroundColor(this.filter === value ? $r('app.color.brand_container') : frostedPillColor())
      .border({
        width: 1,
        color: this.filter === value ? $r('app.color.brand') : $r('app.color.card_border'),
        style: BorderStyle.Solid
      })
      .onClick(() => {
        this.filter = value;
      })
  }

  /** 动作按钮：用 id 分发而非传入回调，避免 @Builder 参数携带函数带来的响应式不确定性。 */
  @Builder
  actionButton(label: ResourceStr, danger: boolean, action: string) {
    Text(label)
      .fontSize(12.5)
      .fontWeight(FontWeight.Medium)
      .fontColor(danger ? $r('app.color.danger') : $r('app.color.brand'))
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius(15)
      .backgroundColor(frostedPillColor())
      .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
      .onClick(() => {
        if (action === 'refresh') {
          this.reload();
        } else if (action === 'copy') {
          this.onCopyAll();
        } else {
          this.onClear();
        }
      })
  }

  @Builder
  logCard(entry: LogEntry) {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        // 级别徽标：小圆点 + 文本（单色语义，不使用彩色图标）
        Row({ space: 5 }) {
          Column()
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor(this.levelColor(entry.level))
          Text(entry.level)
            .fontSize(10.5)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.levelColor(entry.level))
        }
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(10)
        .backgroundColor(frostedPillColor())
        .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })

        Text(entry.tag)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))

        Blank()

        Text(this.formatTime(entry.time))
          .fontSize(10.5)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(entry.message)
        .fontSize(12.5)
        .lineHeight(18)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
  }

  @Builder
  emptyView() {
    Column({ space: 8 }) {
      Image($r('app.media.ic_log'))
        .width(30)
        .height(30)
        .fillColor($r('app.color.text_tertiary'))
      Text($r('app.string.log_empty_title'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
      Text($r('app.string.log_empty_hint'))
        .fontSize(11.5)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding({ top: 46, bottom: 46 })
    .borderRadius(18)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassGroupShadow())
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
    // @Entry 页面 build 只能有唯一根节点，AuroraBackground 是自定义组件，故由 Stack 承载
    Stack() {
      AuroraBackground() {
        Column() {
          this.header()

          Column({ space: 14 }) {
            // 统计 + 说明卡片
            Column({ space: 12 }) {
              Row() {
                this.statItem({ label: $r('app.string.log_stat_total'), value: String(this.total), color: $r('app.color.text_primary') })
                this.statItem({ label: $r('app.string.log_stat_warn'), value: String(this.warnCount), color: $r('app.color.warning') })
                this.statItem({ label: $r('app.string.log_stat_error'), value: String(this.errorCount), color: $r('app.color.danger') })
              }
              .width('100%')

              Text($r('app.string.log_privacy_note'))
                .fontSize(11)
                .lineHeight(16)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')

              Row({ space: 10 }) {
                this.filterChip($r('app.string.log_filter_all'), FILTER_ALL)
                this.filterChip($r('app.string.log_filter_info'), FILTER_INFO)
                this.filterChip($r('app.string.log_filter_warn'), FILTER_WARN)
                this.filterChip($r('app.string.log_filter_error'), FILTER_ERROR)
              }
              .width('100%')

              Row({ space: 10 }) {
                this.actionButton($r('app.string.common_refresh'), false, 'refresh')
                this.actionButton($r('app.string.log_copy_all'), false, 'copy')
                Blank()
                this.actionButton($r('app.string.common_clear'), true, 'clear')
              }
              .width('100%')
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .alignItems(HorizontalAlign.Start)
            .borderRadius(22)
            .backgroundColor($r('app.color.card_background'))
            .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
            .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
            .shadow(glassGroupShadow())
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })

          if (this.visibleEntries().length === 0) {
            Column() {
              this.emptyView()
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 16, right: 16, bottom: 20 })
            .alignItems(HorizontalAlign.Start)
          } else {
            List({ space: 10 }) {
              ForEach(this.visibleEntries(), (entry: LogEntry) => {
                ListItem() {
                  this.logCard(entry)
                }
              }, (entry: LogEntry) => entry.time.toString() + '-' + entry.tag + '-' + entry.message)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 20 })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
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
