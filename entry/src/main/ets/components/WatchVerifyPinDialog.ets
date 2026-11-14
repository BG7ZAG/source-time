import { PinService } from '../service/PinService';
import { Result } from '../types/Result';
import { UiText } from '../utils/UiText';

/**
 * 手表端关闭查看保护前的 PIN 校验。
 *
 * 只负责验证当前 PIN；验证通过后由调用方关闭 appLockEnabled，
 * 复用 PinService 的失败计数与限速，避免在手表上另起一套校验逻辑。
 */
@CustomDialog
export struct WatchVerifyPinDialog {
  controller?: CustomDialogController;
  onConfirmed: () => void = () => {};
  onCancel: () => void = () => {};

  @State pin: string = '';
  @State errorMsg: string = '';
  @State showError: boolean = false;
  @State busy: boolean = false;

  private pinService: PinService = new PinService();

  private messageOf(message: ResourceStr | undefined, fallback: ResourceStr): string {
    const value: ResourceStr = message !== undefined ? message : fallback;
    return typeof value === 'string' ? value : UiText.of(value);
  }

  private submit(): void {
    if (this.busy) {
      return;
    }
    if (!PinService.isValidPin(this.pin)) {
      this.errorMsg = this.messageOf(undefined, $r('app.string.pin_required'));
      this.showError = true;
      return;
    }
    this.busy = true;
    this.showError = false;
    this.pinService.verify(this.pin).then((result: Result<boolean>) => {
      this.busy = false;
      if (!result.success) {
        this.errorMsg = this.messageOf(
          result.error !== undefined ? result.error.message : undefined,
          $r('app.string.pin_verify_failed'));
        this.showError = true;
        return;
      }
      if (result.data === true) {
        this.pin = '';
        this.onConfirmed();
        return;
      }
      this.pin = '';
      this.errorMsg = this.messageOf(undefined, $r('app.string.pin_incorrect'));
      this.showError = true;
    });
  }

  build() {
    Column({ space: 6 }) {
      Text($r('app.string.watch_view_lock_verify_title'))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)

      Text($r('app.string.watch_view_lock_verify_desc'))
        .fontSize(10)
        .lineHeight(14)
        .fontColor('#B3FFFFFF')
        .textAlign(TextAlign.Center)
        .maxLines(2)

      TextInput({ text: this.pin, placeholder: $r('app.string.pin_placeholder') })
        .width('100%')
        .height(40)
        .fontSize(16)
        .letterSpacing(4)
        .textAlign(TextAlign.Center)
        .type(InputType.NUMBER_PASSWORD)
        .showPasswordIcon(true)
        .maxLength(6)
        .borderRadius(12)
        .padding({ left: 8, right: 8, top: 0, bottom: 0 })
        .backgroundColor($r('app.color.pill_background'))
        .placeholderColor($r('app.color.text_tertiary'))
        .onChange((value: string) => {
          this.pin = value.replace(/[^0-9]/g, '').substring(0, 6);
        })

      if (this.showError) {
        Text(this.errorMsg)
          .fontSize(10)
          .lineHeight(14)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }

      Row({ space: 8 }) {
        Button($r('app.string.common_cancel'))
          .layoutWeight(1)
          .height(36)
          .borderRadius(18)
          .fontSize(12)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .enabled(!this.busy)
          .onClick(() => this.onCancel())

        Button($r('app.string.watch_view_lock_verify_confirm'))
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
          .enabled(!this.busy)
          .onClick(() => this.submit())
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: 180, minHeight: 180, maxHeight: 210 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(20)
  }
}
