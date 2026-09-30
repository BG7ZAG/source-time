import { promptAction } from '@kit.ArkUI';
import { AddTotpViewModel } from '../viewmodel/AddTotpViewModel';
import { TotpAlgorithm } from '../model/TotpItem';
import { OtpParser, ParsedOtpUri } from '../service/OtpParser';
import { Result } from '../types/Result';
import {
  focusGlowShadow,
  glassCardShadow,
  glassPillShadow,
  glowButtonShadow,
  noShadow,
  segmentShadow,
  trackGradientColors
} from '../theme/GlassStyle';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';
const ALGORITHM_OPTIONS: TotpAlgorithm[] = ['SHA1', 'SHA256', 'SHA512'];

/**
 * 内容区高度对齐：半模态为 FIT_CONTENT，两个分段的**总高度**必须一致，否则切换时弹窗会重新测量并跳动。
 *
 * - 手动录入态 = 表单卡（SHEET_BODY_MIN_HEIGHT）+ 间距 12 + 保存按钮 46
 * - 扫码态没有保存按钮，因此把「间距 + 按钮」这 58vp 直接算进卡片高度里
 * 二者相加均为 SHEET_BODY_MIN_HEIGHT + ACTION_AREA_HEIGHT，切换时尺寸恒定。
 * 表单卡取略大于自然高度（约 214vp）的值，保证 minHeight 一定生效而不是被内容顶开。
 */
const SHEET_BODY_MIN_HEIGHT: number = 232;
const ACTION_AREA_HEIGHT: number = 58;
const SCAN_BODY_MIN_HEIGHT: number = SHEET_BODY_MIN_HEIGHT + ACTION_AREA_HEIGHT;

/**
 * 主页半模态弹窗：扫码 / 手动录入 TOTP。
 *
 * 鸿蒙 7 形态：居中冰晶模态 + Segment 分段切换 + 下沉式输入框（获焦散发主色光晕）。
 * 内容刻意保持紧凑：发行方与账号并排一行，控件高度下调，避免弹窗过高。
 */
@Component
export struct AddTotpSheet {
  onSaved: () => void = () => {};
  onScan: () => void = () => {};
  // 默认进入扫码模式（0=扫码 1=手动输入）
  @State mode: number = 0;
  @State issuer: string = '';
  @State account: string = '';
  @State secret: string = '';
  @State algorithm: TotpAlgorithm = 'SHA1';
  @State digits: number = 6;
  @State period: number = 30;
  @State saving: boolean = false;
  @State showAdvanced: boolean = false;
  @State parsedFromUri: boolean = false;
  @State focusedField: string = '';

  private viewModel: AddTotpViewModel = new AddTotpViewModel();
  private parser: OtpParser = new OtpParser();

  aboutToAppear(): void {
    const stored: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (stored !== undefined && stored.length > 0) {
      this.viewModel.setEncryptionSecret(stored);
    }
  }

  private onSecretChange(value: string): void {
    if (value.trim().toLowerCase().startsWith('otpauth://')) {
      const parseResult: Result<ParsedOtpUri> = this.parser.parseUri(value.trim());
      if (parseResult.success && parseResult.data !== undefined) {
        const parsed: ParsedOtpUri = parseResult.data;
        this.secret = parsed.secret;
        this.issuer = parsed.issuer;
        this.account = parsed.account;
        this.algorithm = parsed.algorithm;
        this.digits = parsed.digits;
        this.period = parsed.period;
        this.parsedFromUri = true;
        if (parsed.algorithm !== 'SHA1' || parsed.digits !== 6 || parsed.period !== 30) {
          this.showAdvanced = true;
        }
        promptAction.showToast({ message: '已从链接解析配置' });
        return;
      }
    }
    // TextInput 受控 text 被回填时也会触发一次 onChange，其 value 与刚解析出的 secret 相同，
    // 必须忽略，否则会把刚解析出来的 algorithm/digits/period 冲回默认值（SHA1/6/30）。
    if (value === this.secret) {
      return;
    }
    this.secret = value;
    if (this.parsedFromUri) {
      this.issuer = '';
      this.account = '';
      this.algorithm = 'SHA1';
      this.digits = 6;
      this.period = 30;
      this.parsedFromUri = false;
    }
  }

  private onSave(): void {
    this.viewModel.issuer = this.issuer;
    this.viewModel.account = this.account;
    this.viewModel.secret = this.secret;
    this.viewModel.algorithm = this.algorithm;
    this.viewModel.digits = this.digits === 8 ? 8 : 6;
    this.viewModel.period = this.period;
    this.saving = true;
    this.viewModel.save().then((result: Result<void>) => {
      this.saving = false;
      if (result.success) {
        promptAction.showToast({ message: '已添加' });
        this.onSaved();
      } else {
        const message: string = result.error !== undefined ? result.error.message : '保存失败';
        promptAction.showToast({ message: message });
      }
    });
  }

  /**
   * 下沉式输入框：比卡片更暗一档的填充 + 清晰描边，与上方的浅色 label 形成明确的层级差异；
   * 获焦时描边转主色并散发光晕。
   */
  @Builder
  glassField(key: string, placeholder: string, value: string, numeric: boolean) {
    TextInput({ placeholder: placeholder, text: value })
      .width('100%')
      .height(44)
      .borderRadius(12)
      .fontSize(14)
      .fontColor($r('app.color.text_primary'))
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('app.color.field_background'))
      .placeholderColor($r('app.color.text_tertiary'))
      .caretColor($r('app.color.brand'))
      .type(numeric ? InputType.Number : InputType.Normal)
      .border({
        width: 1.5,
        color: this.focusedField === key ? $r('app.color.brand') : $r('app.color.field_border'),
        style: BorderStyle.Solid
      })
      .shadow(this.focusedField === key ? focusGlowShadow() : noShadow())
      .onFocus(() => {
        this.focusedField = key;
      })
      .onBlur(() => {
        if (this.focusedField === key) {
          this.focusedField = '';
        }
      })
      .onChange((input: string) => {
        if (key === 'secret') {
          this.onSecretChange(input);
        } else if (key === 'issuer') {
          this.issuer = input;
        } else if (key === 'account') {
          this.account = input;
        } else {
          const parsed: number = Number.parseInt(input, 10);
          this.period = Number.isNaN(parsed) ? 30 : parsed;
        }
      })
  }

  /**
   * 字段标签行。badge 用于在行尾追加状态徽标（例如密钥由 otpauth 链接解析而来）。
   * 徽标与标签同处一行，不会额外增加表单高度，避免弹窗尺寸抖动。
   */
  @Builder
  fieldLabel(label: string, optional: boolean, badge: string = '') {
    Row({ space: 6 }) {
      Text(label)
        .fontSize(12.5)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      if (optional) {
        Text('可选')
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
          .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          .borderRadius(6)
          .backgroundColor($r('app.color.scrim'))
      }
      if (badge.length > 0) {
        Blank()
        Row({ space: 4 }) {
          Image($r('app.media.ic_check'))
            .width(11)
            .height(11)
            .fillColor($r('app.color.text_secondary'))
          Text(badge)
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
        }
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .borderRadius(6)
        .backgroundColor($r('app.color.scrim'))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /** Segment 胶囊分段按钮组：灰色矢量图标 + 文案。 */
  @Builder
  segmentOption(icon: Resource, label: string, index: number) {
    Row({ space: 6 }) {
      Image(icon)
        .width(15)
        .height(15)
        .fillColor(this.mode === index ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
      Text(label)
        .fontSize(13)
        .fontWeight(this.mode === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.mode === index ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height(34)
    .borderRadius(11)
    .backgroundColor(this.mode === index ? $r('app.color.card_background') : Color.Transparent)
    .shadow(this.mode === index ? segmentShadow() : noShadow())
    .animation({ duration: 220, curve: Curve.FastOutSlowIn })
    .onClick(() => {
      this.mode = index;
    })
  }

  @Builder
  chipOption(label: string, active: boolean, onSelect: () => void) {
    Text(label)
      .fontSize(12.5)
      .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(active ? $r('app.color.fab_foreground') : $r('app.color.text_primary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(32)
      .borderRadius(11)
      .backgroundColor(active ? $r('app.color.brand') : $r('app.color.field_background'))
      .border({
        width: 1,
        color: active ? $r('app.color.brand') : $r('app.color.field_border'),
        style: BorderStyle.Solid
      })
      .shadow(active ? glowButtonShadow() : noShadow())
      .animation({ duration: 200, curve: Curve.FastOutSlowIn })
      .onClick(() => onSelect())
  }

  /** 扫码态：整张卡片即点击区域（不额外放按钮），高度与手动录入态一致。 */
  @Builder
  scanCard() {
    Column({ space: 8 }) {
      Image($r('app.media.ic_scan'))
        .width(38)
        .height(38)
        .fillColor($r('app.color.text_secondary'))
        .opacity(0.85)
      Text('点击开始扫描')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('将服务方提供的 otpauth 二维码放入取景框')
        .fontSize(11.5)
        .fontColor($r('app.color.text_tertiary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .constraintSize({ minHeight: SCAN_BODY_MIN_HEIGHT })
    .justifyContent(FlexAlign.Center)
    .padding(14)
    .borderRadius(18)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
    .onClick(() => this.onScan())
  }

  @Builder
  manualCard() {
    Column({ space: 12 }) {
        Column({ space: 6 }) {
          this.fieldLabel('密钥 / otpauth 链接', false, this.parsedFromUri ? '已解析' : '')
          this.glassField('secret', '粘贴 Base32 密钥或 otpauth:// 链接', this.secret, false)
        }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 10 }) {
        Column({ space: 6 }) {
          this.fieldLabel('发行方', true)
          this.glassField('issuer', '如：Google', this.issuer, false)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          this.fieldLabel('账号', true)
          this.glassField('account', '如：user@xx.com', this.account, false)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      // 高级选项
      Column() {
        Row({ space: 6 }) {
          Text('高级选项')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Image($r('app.media.ic_chevron_down'))
            .width(14)
            .height(14)
            .fillColor($r('app.color.text_tertiary'))
            .rotate({ angle: this.showAdvanced ? 180 : 0 })
            .animation({ duration: 220, curve: Curve.FastOutSlowIn })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          this.showAdvanced = !this.showAdvanced;
        })

        if (this.showAdvanced) {
          Column({ space: 10 }) {
            Divider().color($r('app.color.divider'))

            Column({ space: 6 }) {
              this.fieldLabel('算法', false)
              Row({ space: 8 }) {
                ForEach(ALGORITHM_OPTIONS, (value: TotpAlgorithm) => {
                  this.chipOption(value, this.algorithm === value, () => {
                    this.algorithm = value;
                  })
                })
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              this.fieldLabel('位数', false)
              Row({ space: 8 }) {
                this.chipOption('6 位', this.digits === 6, () => {
                  this.digits = 6;
                })
                this.chipOption('8 位', this.digits === 8, () => {
                  this.digits = 8;
                })
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              this.fieldLabel('周期（秒）', false)
              this.glassField('period', '30', this.period.toString(), true)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: SHEET_BODY_MIN_HEIGHT })
    // 内容不足最小高度时把余量分摊到各行之间，视觉上像留白而不是底部空洞
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .borderRadius(18)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassCardShadow())
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 2 }) {
          Text('添加动态口令')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('扫码或手动录入，数据仅加密保存在本机')
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        // ---- Segment 分段选择器 ----
        Row({ space: 4 }) {
          this.segmentOption($r('app.media.ic_scan'), '扫描二维码', 0)
          this.segmentOption($r('app.media.ic_edit'), '手动输入', 1)
        }
        .width('100%')
        .padding(4)
        .borderRadius(14)
        .backgroundColor($r('app.color.pill_background'))
        .border({ width: 1, color: $r('app.color.pill_border'), style: BorderStyle.Solid })
        .shadow(glassPillShadow())

        if (this.mode === 0) {
          this.scanCard()
        } else {
          this.manualCard()

          // 能量感主色渐变大按钮（Button 不支持 letterSpacing，字距靠文案空格表达）
          Button(this.saving ? '保存中...' : '保 存 口 令')
            .width('100%')
            .height(46)
            .borderRadius(23)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .linearGradient({ angle: 90, colors: trackGradientColors(0) })
            .fontColor($r('app.color.fab_foreground'))
            .shadow(glowButtonShadow())
            .enabled(!this.saving)
            .onClick(() => this.onSave())
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 20 })
      .alignItems(HorizontalAlign.Start)
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
