import { promptAction, router } from '@kit.ArkUI';
import { AuroraBackground } from '../components/AuroraBackground';
import { ClipboardService } from '../service/ClipboardService';
import { Logger } from '../utils/Logger';
import { LogEntry, LogLevel } from '../model/LogEntry';
import { Result } from '../types/Result';
import { frostedPillColor, glassCardShadow, glassGroupShadow, glassPillShadow } from '../theme/GlassStyle';

const FILTER_ALL: string = 'ALL';
const FILTER_INFO: string = 'INFO';
const FILTER_WARN: string = 'WARN';
const FILTER_ERROR: string = 'ERROR';

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
      promptAction.showToast({ message: '暂无可复制的日志' });
      return;
    }
    this.clipboardService.copyText(text).then((result: Result<void>) => {
      if (!result.success || result.error !== undefined) {
        const message: string = result.error !== undefined ? result.error.message : '复制失败';
        promptAction.showToast({ message: message });
        return;
      }
      promptAction.showToast({ message: '日志已复制到剪贴板' });
    });
  }

  private onClear(): void {
    promptAction.showDialog({
      title: '清空运行日志？',
      message: '将删除本机保存的全部日志记录，删除后无法找回。\n\n'
        + '此操作不影响你的口令数据与 WebDAV 同步配置。',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '确认清空', color: '#E84026' }
      ]
    }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
      if (dialogResult.index !== 1) {
        return;
      }
      Logger.clearLogs();
      this.reload();
      promptAction.showToast({ message: '日志已清空' });
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

      Text('运行日志')
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
  statItem(label: string, value: string, color: Resource) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  filterChip(label: string, value: string) {
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
  actionButton(label: string, danger: boolean, action: string) {
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
      Text('暂无日志')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
      Text('应用的加密、同步、密钥等运行记录会显示在这里')
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
                this.statItem('总记录', String(this.total), $r('app.color.text_primary'))
                this.statItem('警告', String(this.warnCount), $r('app.color.warning'))
                this.statItem('错误', String(this.errorCount), $r('app.color.danger'))
              }
              .width('100%')

              Text('日志仅保存在本机，不会上传；密钥、口令、令牌等敏感信息在保存与展示前已脱敏。')
                .fontSize(11)
                .lineHeight(16)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')

              Row({ space: 10 }) {
                this.filterChip('全部', FILTER_ALL)
                this.filterChip('信息', FILTER_INFO)
                this.filterChip('警告', FILTER_WARN)
                this.filterChip('错误', FILTER_ERROR)
              }
              .width('100%')

              Row({ space: 10 }) {
                this.actionButton('刷新', false, 'refresh')
                this.actionButton('复制全部', false, 'copy')
                Blank()
                this.actionButton('清空', true, 'clear')
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
      }
    }
    .width('100%')
    .height('100%')
  }
}
