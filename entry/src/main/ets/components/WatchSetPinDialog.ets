import { PinService } from '../service/PinService';
import { Result } from '../types/Result';
import { UiText } from '../utils/UiText';

/**
 * 手表端设置查看 PIN。
 *
 * 手机端应用锁没有同步校验值时，手表可以自己设一个 6 位 PIN；
 * 设置成功后由调用方立即上锁，方便确认遮罩样式与后续解锁流程。
 */
@CustomDialog
export struct WatchSetPinDialog {
  controller?: CustomDialogController;
  onDone: () => void = () => {};
  onCancel: () => void = () => {};

  @State pin: string = '';
  @State confirmPin: string = '';
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
      this.errorMsg = this.messageOf(undefined, $r('app.string.watch_set_pin_invalid'));
      this.showError = true;
      return;
    }
    if (this.pin !== this.confirmPin) {
      this.errorMsg = this.messageOf(undefined, $r('app.string.watch_set_pin_mismatch'));
      this.showError = true;
      return;
    }
    this.busy = true;
    this.showError = false;
    this.pinService.setPin(this.pin).then((result: Result<void>) => {
      this.busy = false;
      if (!result.success) {
        this.errorMsg = this.messageOf(
          result.error !== undefined ? result.error.message : undefined,
          $r('app.string.watch_set_pin_failed'));
        this.showError = true;
        return;
      }
      this.pin = '';
      this.confirmPin = '';
      this.onDone();
    });
  }

  build() {
    Column({ space: 4 }) {
      Text($r('app.string.watch_set_pin_title'))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)

      Text($r('app.string.watch_set_pin_desc'))
        .fontSize(10)
        .lineHeight(14)
        .fontColor('#B3FFFFFF')
        .textAlign(TextAlign.Center)
        .maxLines(1)

      TextInput({ text: this.pin, placeholder: $r('app.string.watch_set_pin_hint') })
        .width('100%')
        .height(36)
        .fontSize(15)
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

      TextInput({ text: this.confirmPin, placeholder: $r('app.string.watch_set_pin_confirm_hint') })
        .width('100%')
        .height(36)
        .fontSize(15)
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
          this.confirmPin = value.replace(/[^0-9]/g, '').substring(0, 6);
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
          .height(34)
          .borderRadius(17)
          .fontSize(12)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .enabled(!this.busy)
          .onClick(() => this.onCancel())

        Button($r('app.string.watch_set_pin_save'))
          .layoutWeight(1)
          .height(34)
          .borderRadius(17)
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
    .constraintSize({ maxWidth: 180, minHeight: 190, maxHeight: 215 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
  }
}
