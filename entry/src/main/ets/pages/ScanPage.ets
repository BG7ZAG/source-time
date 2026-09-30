import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { AddTotpViewModel } from '../viewmodel/AddTotpViewModel';
import { ParsedOtpUri } from '../service/OtpParser';
import { Result } from '../types/Result';
import { AppRoutes } from '../constants/AppConstants';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';
type ScanStage = 'SCANNING' | 'CONFIRM' | 'DONE';

@Entry
@Component
struct ScanPage {
  @State stage: ScanStage = 'SCANNING';
  @State issuer: string = '';
  @State account: string = '';
  @State algorithm: string = '';
  @State digits: number = 6;
  @State period: number = 30;
  @State saving: boolean = false;
  private viewModel: AddTotpViewModel = new AddTotpViewModel();

  aboutToAppear(): void {
    const stored: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (stored !== undefined && stored.length > 0) {
      this.viewModel.setEncryptionSecret(stored);
    }
    this.startScan();
  }

  private async startScan(): Promise<void> {
    try {
      const context: common.Context = getContext(this) as common.Context;
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE]
      };
      const scanResult: scanBarcode.ScanResult = await scanBarcode.startScanForResult(context, options);
      const parsed: Result<ParsedOtpUri> = this.viewModel.parseUri(scanResult.originalValue);
      if (!parsed.success || parsed.data === undefined) {
        const message: string = parsed.error !== undefined ? parsed.error.message : '二维码无效';
        promptAction.showToast({ message: message });
        router.back({ url: AppRoutes.HOME });
        return;
      }
      const data: ParsedOtpUri = parsed.data;
      this.viewModel.applyParsed(data);
      this.issuer = data.issuer;
      this.account = data.account;
      this.algorithm = data.algorithm;
      this.digits = data.digits;
      this.period = data.period;
      this.stage = 'CONFIRM';
    } catch (error) {
      router.back({ url: AppRoutes.HOME });
    }
  }

  private onSave(): void {
    this.saving = true;
    this.viewModel.save().then((result: Result<void>) => {
      this.saving = false;
      if (result.success) {
        this.stage = 'DONE';
        router.back({ url: AppRoutes.HOME });
      } else {
        const message: string = result.error !== undefined ? result.error.message : '保存失败';
        promptAction.showToast({ message: message });
      }
    });
  }

  @Builder
  confirmView() {
    Column({ space: 16 }) {
      Text('确认验证码信息')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Column({ space: 8 }) {
        Row() {
          Text('发行方').fontSize(14).fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.issuer).fontSize(14).fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        Row() {
          Text('账号').fontSize(14).fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.account).fontSize(14).fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        Row() {
          Text('算法').fontSize(14).fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.algorithm).fontSize(14).fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        Row() {
          Text('位数').fontSize(14).fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.digits.toString()).fontSize(14).fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        Row() {
          Text('周期').fontSize(14).fontColor($r('app.color.text_secondary'))
          Blank()
          Text(this.period.toString()).fontSize(14).fontColor($r('app.color.text_primary'))
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .borderRadius(16)
      .backgroundColor($r('app.color.card_background'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
      .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

      Button(this.saving ? '保存中...' : '保存')
        .width('100%')
        .height(48)
        .borderRadius(12)
        .backgroundColor($r('app.color.brand'))
        .fontColor($r('app.color.fab_foreground'))
        .enabled(!this.saving)
        .onClick(() => this.onSave())
    }
    .width('100%')
    .padding(16)
  }

  build() {
    Column() {
      if (this.stage === 'CONFIRM') {
        this.confirmView()
      } else {
        Column({ space: 12 }) {
          Text('正在扫描二维码...')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
          Progress({ value: 0, total: 100, type: ProgressType.Linear })
            .width('60%')
            .height(2)
            .color($r('app.color.brand'))
        }
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [[$r('app.color.page_gradient_start'), 0.0], [$r('app.color.page_gradient_end'), 1.0]]
    })
  }
}
