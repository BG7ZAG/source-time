import { router, promptAction } from '@kit.ArkUI';
import { CryptoService } from '../service/CryptoService';
import { SettingsService } from '../service/SettingsService';
import { StorageService } from '../service/StorageService';
import { ClipboardService } from '../service/ClipboardService';
import { DatabaseModel } from '../model/DatabaseModel';
import { Result, ok, err } from '../types/Result';
import { AppErrorCode } from '../types/Errors';
import { Logger } from '../utils/Logger';
import { CURRENT_PRIVACY_POLICY_VERSION } from '../constants/AppConstants';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

@Entry
@Component
struct SecurityPage {
  @State isFirstSetup: boolean = true;
  @State encryptionSecret: string = '';
  @State generatedSecret: string = '';
  @State hasGenerated: boolean = false;
  @State saving: boolean = false;
  @State oldSecret: string = '';
  @State newSecret: string = '';
  @State step: number = 0;
  @State verifyingOld: boolean = false;
  @State copied: boolean = false;
  @State error: string = '';

  private cryptoService: CryptoService = new CryptoService();
  private settingsService: SettingsService = new SettingsService();
  private storageService: StorageService = StorageService.getInstance();
  private clipboardService: ClipboardService = new ClipboardService();

  aboutToAppear(): void {
    const settings = this.settingsService.getSettings();
    this.isFirstSetup = !settings.encryptionInitialized;
    if (!this.isFirstSetup) {
      this.step = 0;
    }
  }

  private onGenerate(): void {
    if (this.hasGenerated && !this.isFirstSetup) {
      promptAction.showDialog({
        title: '重新生成密钥？',
        message: '重新生成将覆盖当前输入的密钥。已加密的数据需要用旧密钥才能解密。',
        buttons: [
          { text: '取消', color: '#666666' },
          { text: '确认重新生成', color: '#E84026' }
        ]
      }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
        if (dialogResult.index === 1) {
          this.generatedSecret = this.cryptoService.generateRandomEncryptionSecret();
          this.encryptionSecret = this.generatedSecret;
          this.hasGenerated = true;
        }
      });
    } else {
      this.generatedSecret = this.cryptoService.generateRandomEncryptionSecret();
      this.encryptionSecret = this.generatedSecret;
      this.hasGenerated = true;
    }
  }

  private onCopy(): void {
    this.clipboardService.copyText(this.encryptionSecret).then((result: Result<void>) => {
      if (result.success) {
        this.copied = true;
        promptAction.showToast({ message: '密钥已复制' });
      } else {
        promptAction.showToast({ message: '复制失败' });
      }
    });
  }

  private onSaveFirstSetup(): void {
    if (this.encryptionSecret.trim().length === 0) {
      this.error = '请输入或生成加密密钥';
      return;
    }
    this.saving = true;
    this.error = '';
    const secret: string = this.encryptionSecret.trim();
    AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, secret);
    const settings = this.settingsService.getSettings();
    settings.encryptionInitialized = true;
    this.settingsService.saveSettings(settings).then((result: Result<void>) => {
      this.saving = false;
      if (result.success) {
        Logger.info('Encryption key initialized');
        router.replaceUrl({ url: 'pages/HomePage' });
      } else {
        this.error = '保存失败';
      }
    });
  }

  private onVerifyOldSecret(): void {
    this.verifyingOld = true;
    this.error = '';
    const oldSecret: string = this.oldSecret.trim();
    if (oldSecret.length === 0) {
      this.error = '请输入旧密钥';
      this.verifyingOld = false;
      return;
    }
    const bytesResult: Result<Uint8Array> = this.storageService.readEncryptedFile();
    if (!bytesResult.success || bytesResult.data === undefined) {
      this.verifyingOld = false;
      this.error = '读取本地数据失败';
      return;
    }
    this.storageService.decodeEncryptedDatabase(bytesResult.data, oldSecret).then((decodeResult: Result<DatabaseModel>) => {
      this.verifyingOld = false;
      if (decodeResult.success && decodeResult.data !== undefined) {
        this.step = 1;
        this.error = '';
      } else {
        this.error = '旧密钥错误';
      }
    });
  }

  private onSaveNewSecret(): void {
    if (this.newSecret.trim().length === 0) {
      this.error = '请输入新密钥';
      return;
    }
    this.saving = true;
    this.error = '';
    const newSecret: string = this.newSecret.trim();
    const oldSecret: string = this.oldSecret.trim();
    const bytesResult: Result<Uint8Array> = this.storageService.readEncryptedFile();
    if (!bytesResult.success || bytesResult.data === undefined) {
      this.saving = false;
      this.error = '读取本地数据失败';
      return;
    }
    this.storageService.decodeEncryptedDatabase(bytesResult.data, oldSecret).then((decodeResult: Result<DatabaseModel>) => {
      if (!decodeResult.success || decodeResult.data === undefined) {
        this.saving = false;
        this.error = '解密失败';
        return;
      }
      const db: DatabaseModel = decodeResult.data;
      this.storageService.replaceDatabase(db, newSecret).then((replaceResult: Result<void>) => {
        this.saving = false;
        if (replaceResult.success) {
          AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, newSecret);
          Logger.info('Encryption key changed');
          promptAction.showToast({ message: '密钥已更新' });
          router.back();
        } else {
          this.error = '保存失败';
        }
      });
    });
  }

  @Builder
  header() {
    Row() {
      if (!this.isFirstSetup) {
        Button() {
          Text('<')
            .fontSize(18)
            .fontColor($r('app.color.text_primary'))
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())
      }
      Blank()
      Text('保护你的数据')
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
  firstSetupView() {
    Column({ space: 16 }) {
      Text('源时会使用你设置的加密密钥保护本地 TOTP 数据。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Text('请妥善保存此密钥，忘记后将无法解密已经加密的数据。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Row() {
        TextInput({ placeholder: '输入加密密钥', text: this.encryptionSecret })
          .layoutWeight(1)
          .borderRadius(12)
          .onChange((value: string) => {
            this.encryptionSecret = value;
            this.hasGenerated = false;
            this.copied = false;
          })

        Button('生成')
          .width(80)
          .borderRadius(12)
          .backgroundColor($r('app.color.brand'))
          .fontColor($r('app.color.fab_foreground'))
          .onClick(() => this.onGenerate())
      }
      .width('100%')

      if (this.encryptionSecret.length > 0) {
        Row() {
          Button(this.copied ? '已复制' : '复制密钥')
            .width(140)
            .borderRadius(12)
            .backgroundColor(this.copied ? $r('app.color.success') : $r('app.color.brand'))
            .fontColor($r('app.color.fab_foreground'))
            .onClick(() => this.onCopy())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }

      Text('请将此密钥保存到安全的位置。源时不会提供服务器端密钥恢复能力。')
        .fontSize(12)
        .fontColor($r('app.color.danger'))
        .width('100%')

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(14)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }

      Button(this.saving ? '保存中...' : '保存')
        .width('100%')
        .borderRadius(12)
        .backgroundColor($r('app.color.brand'))
        .fontColor($r('app.color.fab_foreground'))
        .enabled(!this.saving)
        .onClick(() => this.onSaveFirstSetup())
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
    .margin({ left: 16, right: 16 })
    .width('100%')
  }

  @Builder
  changeKeyStep0() {
    Column({ space: 16 }) {
      Text('修改加密密钥需要先验证当前密钥。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      TextInput({ placeholder: '输入旧密钥', text: this.oldSecret })
        .type(InputType.Password)
        .width('100%')
        .borderRadius(12)
        .onChange((value: string) => {
          this.oldSecret = value;
        })

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(14)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }

      Button(this.verifyingOld ? '验证中...' : '验证旧密钥')
        .width('100%')
        .borderRadius(12)
        .backgroundColor($r('app.color.brand'))
        .fontColor($r('app.color.fab_foreground'))
        .enabled(!this.verifyingOld)
        .onClick(() => this.onVerifyOldSecret())
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
    .margin({ left: 16, right: 16 })
    .width('100%')
  }

  @Builder
  changeKeyStep1() {
    Column({ space: 16 }) {
      Text('旧密钥验证成功，请输入新密钥。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Row() {
        TextInput({ placeholder: '输入新密钥', text: this.newSecret })
          .layoutWeight(1)
          .borderRadius(12)
          .onChange((value: string) => {
            this.newSecret = value;
            this.copied = false;
          })

        Button('生成')
          .width(80)
          .borderRadius(12)
          .backgroundColor($r('app.color.brand'))
          .fontColor($r('app.color.fab_foreground'))
          .onClick(() => {
            this.newSecret = this.cryptoService.generateRandomEncryptionSecret();
            this.copied = false;
          })
      }
      .width('100%')

      if (this.newSecret.length > 0) {
        Row() {
          Button(this.copied ? '已复制' : '复制新密钥')
            .width(140)
            .borderRadius(12)
            .backgroundColor(this.copied ? $r('app.color.success') : $r('app.color.brand'))
            .fontColor($r('app.color.fab_foreground'))
            .onClick(() => {
              this.clipboardService.copyText(this.newSecret).then((result: Result<void>) => {
                if (result.success) {
                  this.copied = true;
                  promptAction.showToast({ message: '密钥已复制' });
                } else {
                  promptAction.showToast({ message: '复制失败' });
                }
              });
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }

      Text('请将此密钥保存到安全的位置。源时不会提供服务器端密钥恢复能力。')
        .fontSize(12)
        .fontColor($r('app.color.danger'))
        .width('100%')

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(14)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }

      Button(this.saving ? '保存中...' : '保存新密钥')
        .width('100%')
        .borderRadius(12)
        .backgroundColor($r('app.color.brand'))
        .fontColor($r('app.color.fab_foreground'))
        .enabled(!this.saving)
        .onClick(() => this.onSaveNewSecret())
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
    .margin({ left: 16, right: 16 })
    .width('100%')
  }

  build() {
    Column() {
      this.header()

      Scroll() {
        Column() {
          if (this.isFirstSetup) {
            this.firstSetupView()
          } else {
            if (this.step === 0) {
              this.changeKeyStep0()
            } else {
              this.changeKeyStep1()
            }
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [[$r('app.color.page_gradient_start'), 0.0], [$r('app.color.page_gradient_end'), 1.0]]
    })
  }
}
