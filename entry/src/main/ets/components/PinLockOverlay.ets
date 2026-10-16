import { PinService } from '../service/PinService';
import { Result } from '../types/Result';
import { Logger } from '../utils/Logger';
import { UiText } from '../utils/UiText';
import { APP_LOCK_STORAGE_KEY } from '../constants/AppConstants';
import { LOCK_CONTENT_MAX_WIDTH } from '../constants/LayoutConstants';

/**
 * 应用锁遮罩：覆盖整页，遮住口令与密钥，直到 PIN 校验通过。
 *
 * 由 AuroraBackground 统一挂载，因此所有以它为底色的页面天然受保护：
 * 冷启动由 EntryAbility 置位，退后台由 EntryAbility.onBackground 重新置位。
 * 底色取不透明的 page_background（而非半透明材质），避免口令从遮罩下透出。
 */
@Component
export struct PinLockOverlay {
  @State pin: string = '';
  /** 错误提示：Resource 走多语言资源。 */
  @State error: ResourceStr = '';
  @State verifying: boolean = false;
  /** 连续失败后的剩余锁定秒数；大于 0 时禁用输入与按钮。 */
  @State lockRemaining: number = 0;

  private pinService: PinService = new PinService();
  private lockTimerId: number = -1;

  aboutToAppear(): void {
    this.refreshLockout();
  }

  aboutToDisappear(): void {
    if (this.lockTimerId >= 0) {
      clearInterval(this.lockTimerId);
      this.lockTimerId = -1;
    }
  }

  private refreshLockout(): void {
    this.lockRemaining = this.pinService.getLockoutRemainingSeconds();
    if (this.lockRemaining > 0 && this.lockTimerId < 0) {
      this.lockTimerId = setInterval(() => {
        this.refreshLockout();
      }, 1000);
      return;
    }
    if (this.lockRemaining === 0 && this.lockTimerId >= 0) {
      clearInterval(this.lockTimerId);
      this.lockTimerId = -1;
    }
  }

  private onPinChange(value: string): void {
    const digits: string = value.replace(/[^0-9]/g, '').substring(0, 6);
    if (digits !== value) {
      this.pin = digits;
    }
    this.error = '';
  }

  private onUnlock(): void {
    if (this.verifying) {
      return;
    }
    // 被限流挡住与密码输错在日志里区分：前者说明用户在被锁期间仍尝试解锁
    if (this.lockRemaining > 0) {
      Logger.warn('App lock verify blocked by rate limit, remaining=' + this.lockRemaining + 's');
      return;
    }
    if (!PinService.isValidPin(this.pin)) {
      this.error = $r('app.string.pin_required');
      return;
    }
    this.verifying = true;
    this.pinService.verify(this.pin).then((result: Result<boolean>) => {
      this.verifying = false;
      if (!result.success) {
        this.refreshLockout();
        if (this.lockRemaining > 0) {
          this.pin = '';
          this.error = '';
          Logger.warn('App lock verify failed, rate limit engaged, remaining=' + this.lockRemaining + 's');
          return;
        }
        const message: ResourceStr = result.error !== undefined ? result.error.message : $r('app.string.pin_verify_failed');
        this.error = message;
        Logger.error('App lock verify errored: ' + (typeof message === 'string' ? message : UiText.of(message)));
        return;
      }
      if (result.data === true) {
        this.pin = '';
        AppStorage.setOrCreate<boolean>(APP_LOCK_STORAGE_KEY, false);
        Logger.info('App lock unlocked');
        return;
      }
      this.pin = '';
      this.refreshLockout();
      this.error = this.lockRemaining > 0 ? '' : $r('app.string.pin_incorrect');
      Logger.warn('App lock verify failed');
    });
  }

  build() {
    Column() {
      // 宽屏（平板 / 2in1）下 PIN 面板收窄居中：全宽输入框在超宽窗口下不可用
      Column() {
        Image($r('app.media.ic_security'))
          .width(34)
          .height(34)
          .fillColor($r('app.color.text_secondary'))

        Text($r('app.string.pin_locked_title'))
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 12 })

        Text($r('app.string.pin_locked_hint'))
          .fontSize(12.5)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 6 })

        Column() {
          TextInput({ text: $$this.pin, placeholder: $r('app.string.pin_placeholder') })
            .type(InputType.Number)
            .maxLength(6)
            .fontSize(22)
            .textAlign(TextAlign.Center)
            .letterSpacing(8)
            .height(46)
            .backgroundColor($r('app.color.field_background'))
            .border({ width: 1.5, color: $r('app.color.field_border') })
            .borderRadius(14)
            .enabled(this.lockRemaining === 0)
            .onChange((value: string) => {
              this.onPinChange(value);
            })
            .onSubmit(() => {
              this.onUnlock();
            })
        }
        .width('100%')
        .margin({ top: 22 })

        if (this.lockRemaining > 0) {
          Text($r('app.string.pin_locked_retry', this.lockRemaining))
            .fontSize(12)
            .fontColor($r('app.color.danger'))
            .margin({ top: 10 })
        } else if (this.error !== '') {
          Text(this.error)
            .fontSize(12)
            .fontColor($r('app.color.danger'))
            .margin({ top: 10 })
        }

        Button(this.verifying ? $r('app.string.pin_verifying') : $r('app.string.pin_unlock'))
          .width('100%')
          .height(46)
          .borderRadius(14)
          .enabled(!this.verifying && this.lockRemaining === 0)
          .margin({ top: 16 })
          .onClick(() => {
            this.onUnlock();
          })

        Text($r('app.string.pin_forgot_hint'))
          .fontSize(11.5)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
          .margin({ top: 18 })
      }
      .width('100%')
      .constraintSize({ maxWidth: LOCK_CONTENT_MAX_WIDTH })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 34, right: 34 })
    .backgroundColor($r('app.color.page_background'))
  }
}
