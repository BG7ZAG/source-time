import { CryptoService } from '../service/CryptoService';
import { KeyStoreService } from '../service/KeyStoreService';
import { SettingsService } from '../service/SettingsService';
import { ClipboardService } from '../service/ClipboardService';
import { Result } from '../types/Result';
import { USER_SECRET_MAX_LENGTH, USER_SECRET_MIN_LENGTH } from '../constants/CryptoConstants';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

/**
 * 手表端加密密钥初始化弹窗。
 *
 * 手表屏幕放不下完整的安全与密钥页（1136 行、含密钥轮换 / 应用锁），
 * 首次使用时在首页内用这个紧凑弹窗完成「生成或输入密钥 → 持久化」，
 * 避免被路由到会在 aboutToAppear 里直接 back() 的 SecurityPage 而造成死循环。
 */
@CustomDialog
export struct WatchKeySetupDialog {
  controller?: CustomDialogController;
  onDone: () => void = () => {};
  onCancel: () => void = () => {};

  @State secret: string = '';
  @State errorMsg: ResourceStr = '';
  @State showError: boolean = false;
  @State saving: boolean = false;

  private cryptoService: CryptoService = new CryptoService();
  private keyStoreService: KeyStoreService = new KeyStoreService();
  private settingsService: SettingsService = new SettingsService();
  private clipboardService: ClipboardService = new ClipboardService();

  aboutToAppear(): void {
    // 已有密钥时直接显示当前值（便于查看/复制/覆盖为手机上的密钥），
    // 仅在首次初始化时给出一枚 256-bit 随机密钥。
    const current: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    this.secret = (current !== undefined && current.length > 0)
      ? current
      : this.cryptoService.generateRandomEncryptionSecret();
  }

  private regenerate(): void {
    this.secret = this.cryptoService.generateRandomEncryptionSecret();
    this.showError = false;
  }

  private copyKey(): void {
    const value: string = this.secret.trim();
    if (value.length === 0) {
      return;
    }
    this.clipboardService.copySensitiveText(value).then((result: Result<void>) => {
      this.getUIContext().getPromptAction().showToast({
        message: result.success ? $r('app.string.watch_key_copied') : $r('app.string.watch_key_copy_failed')
      });
    });
  }

  private save(): void {
    const value: string = this.secret.trim();
    if (value.length < USER_SECRET_MIN_LENGTH || value.length > USER_SECRET_MAX_LENGTH) {
      this.errorMsg = $r('app.string.watch_key_length_invalid');
      this.showError = true;
      return;
    }
    this.saving = true;
    this.showError = false;
    AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, value);
    const settings = this.settingsService.getSettings();
    settings.encryptionInitialized = true;
    this.settingsService.saveSettings(settings).then((result: Result<void>) => {
      if (!result.success) {
        this.saving = false;
        this.errorMsg = $r('app.string.security_save_failed');
        this.showError = true;
        return;
      }
      // 关键资产写入失败不阻断：密钥已展示，用户可自行抄写，下次启动重新输入即可
      this.keyStoreService.save(value).then((stored: boolean) => {
        this.saving = false;
        this.onDone();
      });
    });
  }

  build() {
    Column({ space: 6 }) {
      Text($r('app.string.watch_key_title'))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)

      Text($r('app.string.watch_key_desc'))
        .fontSize(10)
        .lineHeight(14)
        .fontColor('#B3FFFFFF')
        .textAlign(TextAlign.Center)
        .maxLines(3)

      TextInput({ text: this.secret, placeholder: $r('app.string.watch_key_placeholder') })
        .width('100%')
        .height(36)
        .fontSize(11)
        .borderRadius(10)
        .padding({ left: 8, right: 8 })
        .backgroundColor($r('app.color.pill_background'))
        .maxLength(USER_SECRET_MAX_LENGTH)
        .onChange((value: string) => {
          this.secret = value;
        })

      Row({ space: 8 }) {
        Button() {
          Text($r('app.string.common_generate'))
            .width('100%')
            .fontSize(10.5)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            // 英文 "Generate" 在等宽按钮里会被省略号截断，用跑马灯兜底
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .marqueeOptions({ start: true, fromStart: true, step: 6, loop: -1, delay: 800 })
        }
        .layoutWeight(1)
        .height(30)
        .borderRadius(15)
        .padding({ left: 2, right: 2 })
        .backgroundColor($r('app.color.pill_background'))
        .onClick(() => this.regenerate())

        Button() {
          Text($r('app.string.common_copy'))
            .width('100%')
            .fontSize(10.5)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .marqueeOptions({ start: true, fromStart: true, step: 6, loop: -1, delay: 800 })
        }
        .layoutWeight(1)
        .height(30)
        .borderRadius(15)
        .padding({ left: 2, right: 2 })
        .backgroundColor($r('app.color.pill_background'))
        .onClick(() => this.copyKey())
      }
      .width('100%')

      if (this.showError) {
        Text(this.errorMsg)
          .fontSize(10)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .maxLines(1)
      }

      Row({ space: 8 }) {
        Button($r('app.string.common_cancel'))
          .layoutWeight(1)
          .height(36)
          .borderRadius(18)
          .fontSize(12)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onCancel())

        Button($r('app.string.watch_key_done'))
          .layoutWeight(1)
          .height(36)
          .borderRadius(18)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .linearGradient({
            angle: 90,
            colors: [[$r('app.color.brand'), 0.0], [$r('app.color.brand_secondary'), 1.0]]
          })
          .fontColor($r('app.color.fab_foreground'))
          .enabled(!this.saving)
          .onClick(() => this.save())
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: 180, minHeight: 200, maxHeight: 230 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(20)
  }
}
