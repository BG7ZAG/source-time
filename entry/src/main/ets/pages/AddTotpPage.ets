import { router, promptAction } from '@kit.ArkUI';
import { AddTotpViewModel } from '../viewmodel/AddTotpViewModel';
import { TotpAlgorithm } from '../model/TotpItem';
import { OtpParser, ParsedOtpUri } from '../service/OtpParser';
import { Result } from '../types/Result';
import { AppRoutes } from '../constants/AppConstants';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';
const ALGORITHM_OPTIONS: TotpAlgorithm[] = ['SHA1', 'SHA256', 'SHA512'];
type PageStage = 'SELECT' | 'MANUAL';

@Entry
@Component
struct AddTotpPage {
  @State stage: PageStage = 'SELECT';
  @State issuer: string = '';
  @State account: string = '';
  @State secret: string = '';
  @State algorithm: TotpAlgorithm = 'SHA1';
  @State digits: number = 6;
  @State period: number = 30;
  @State saving: boolean = false;
  @State showAdvanced: boolean = false;
  @State parsedFromUri: boolean = false;
  private viewModel: AddTotpViewModel = new AddTotpViewModel();
  private parser: OtpParser = new OtpParser();

  aboutToAppear(): void {
    const stored: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (stored !== undefined && stored.length > 0) {
      this.viewModel.setEncryptionSecret(stored);
    }
  }

  private goScan(): void {
    router.pushUrl({ url: AppRoutes.SCAN });
  }

  private showManual(): void {
    this.stage = 'MANUAL';
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
        promptAction.showToast({ message: '已从链接解析配置' });
        return;
      }
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
        router.back({ url: AppRoutes.HOME });
      } else {
        const message: string = result.error !== undefined ? result.error.message : '保存失败';
        promptAction.showToast({ message: message });
      }
    });
  }

  @Builder
  header() {
    Row() {
      if (this.stage === 'MANUAL') {
        Button() {
          Text('<')
            .fontSize(18)
            .fontColor($r('app.color.text_primary'))
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.stage = 'SELECT';
        })
      }
      Blank()
      Text(this.stage === 'SELECT' ? '添加验证码' : '手动输入')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text('')
        .width(40)
    }
    .width('100%')
    .padding({ left: 8, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  algorithmSelector() {
    Row({ space: 12 }) {
      ForEach(ALGORITHM_OPTIONS, (value: TotpAlgorithm) => {
        Button(value)
          .fontSize(14)
          .borderRadius(12)
          .backgroundColor(this.algorithm === value ? $r('app.color.brand') : $r('app.color.card_background'))
          .fontColor(this.algorithm === value ? $r('app.color.fab_foreground') : $r('app.color.text_primary'))
          .onClick(() => {
            this.algorithm = value;
          })
      })
    }
    .width('100%')
  }

  @Builder
  digitsSelector() {
    Row({ space: 12 }) {
      Button('6 位')
        .fontSize(14)
        .borderRadius(12)
        .backgroundColor(this.digits === 6 ? $r('app.color.brand') : $r('app.color.card_background'))
        .fontColor(this.digits === 6 ? $r('app.color.fab_foreground') : $r('app.color.text_primary'))
        .onClick(() => {
          this.digits = 6;
        })
      Button('8 位')
        .fontSize(14)
        .borderRadius(12)
        .backgroundColor(this.digits === 8 ? $r('app.color.brand') : $r('app.color.card_background'))
        .fontColor(this.digits === 8 ? $r('app.color.fab_foreground') : $r('app.color.text_primary'))
        .onClick(() => {
          this.digits = 8;
        })
    }
    .width('100%')
  }

  build() {
    Column() {
      this.header()

      if (this.stage === 'SELECT') {
        Column({ space: 12 }) {
          Button('扫描二维码')
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor($r('app.color.brand'))
            .fontColor($r('app.color.fab_foreground'))
            .onClick(() => this.goScan())
          Button('手动输入')
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor($r('app.color.brand_container'))
            .fontColor($r('app.color.brand_on_container'))
            .onClick(() => this.showManual())
        }
        .padding(16)
        .margin({ left: 16, right: 16 })
        .width('100%')
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 12 }) {
              TextInput({ placeholder: '密钥（Base32 或 otpauth 链接，必填）', text: this.secret })
                .width('100%')
                .borderRadius(12)
                .onChange((value: string) => this.onSecretChange(value))

              if (this.parsedFromUri) {
                Text('已从 otpauth 链接自动解析以下字段，可手动修改')
                  .fontSize(12)
                  .fontColor($r('app.color.success'))
                  .width('100%')
              }

              TextInput({ placeholder: '发行方（可选）', text: this.issuer })
                .width('100%')
                .borderRadius(12)
                .onChange((value: string) => {
                  this.issuer = value;
                })

              TextInput({ placeholder: '账号（可选）', text: this.account })
                .width('100%')
                .borderRadius(12)
                .onChange((value: string) => {
                  this.account = value;
                })
            }
            .width('100%')
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('app.color.card_background'))
            .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
            .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
            .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

            Row() {
              Text('高级选项')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
              Blank()
              Text(this.showAdvanced ? '收起' : '展开')
                .fontSize(14)
                .fontColor($r('app.color.brand'))
                .onClick(() => {
                  this.showAdvanced = !this.showAdvanced;
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 4, bottom: 4 })

            if (this.showAdvanced) {
              Column({ space: 8 }) {
                Text('算法')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                this.algorithmSelector()

                Text('位数')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                this.digitsSelector()

                TextInput({ placeholder: '周期（秒，默认30）', text: this.period.toString() })
                  .type(InputType.Number)
                  .width('100%')
                  .borderRadius(12)
                  .onChange((value: string) => {
                    const parsed: number = Number.parseInt(value, 10);
                    this.period = Number.isNaN(parsed) ? 30 : parsed;
                  })
              }
              .width('100%')
              .padding(16)
              .borderRadius(16)
              .backgroundColor($r('app.color.card_background'))
              .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
              .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
              .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
            }

            Button(this.saving ? '保存中...' : '保存')
              .width('100%')
              .height(48)
              .borderRadius(12)
              .backgroundColor($r('app.color.brand'))
              .fontColor($r('app.color.fab_foreground'))
              .enabled(!this.saving)
              .onClick(() => this.onSave())
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [[$r('app.color.page_gradient_start'), 0.0], [$r('app.color.page_gradient_end'), 1.0]]
    })
  }
}
