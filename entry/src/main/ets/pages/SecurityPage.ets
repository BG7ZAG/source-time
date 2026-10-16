import { router, promptAction } from '@kit.ArkUI';
import { CryptoService } from '../service/CryptoService';
import { KeyStoreService } from '../service/KeyStoreService';
import { SettingsService } from '../service/SettingsService';
import { StorageService } from '../service/StorageService';
import { SyncService } from '../service/SyncService';
import { PinService } from '../service/PinService';
import { ClipboardService } from '../service/ClipboardService';
import { DatabaseModel } from '../model/DatabaseModel';
import { WebDavConfig } from '../model/WebDavConfig';
import { Result } from '../types/Result';
import { Logger } from '../utils/Logger';
import { UiText } from '../utils/UiText';
import { USER_SECRET_MAX_LENGTH, USER_SECRET_MIN_LENGTH } from '../constants/CryptoConstants';
import { CONTENT_MAX_WIDTH } from '../constants/LayoutConstants';
import { AuroraBackground } from '../components/AuroraBackground';
import {
  focusGlowShadow,
  frostedPillColor,
  glassGroupShadow,
  glassPillShadow,
  glowButtonShadow,
  noShadow,
  trackGradientColors
} from '../theme/GlassStyle';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

/**
 * 主操作按钮参数。
 *
 * ArkUI 的 @Builder 按值传参时，状态变量变化不会引起其内部 UI 刷新；
 * 只有传入对象字面量（按引用传参）才会随状态刷新。故按钮参数收敛为一个对象。
 */
interface PrimaryButtonParams {
  label: ResourceStr;
  enabled: boolean;
  onTap: () => void;
}

/**
 * 安全与密钥页（鸿蒙 7 版）：冰晶卡片 + 聚焦发光输入框 + 双色柔光步骤指示。
 */
@Entry
@Component
struct SecurityPage {
  @State isFirstSetup: boolean = true;
  @State keyLost: boolean = false;
  @State encryptionSecret: string = '';
  @State generatedSecret: string = '';
  @State hasGenerated: boolean = false;
  @State saving: boolean = false;
  @State oldSecret: string = '';
  @State newSecret: string = '';
  @State step: number = 0;
  @State verifyingOld: boolean = false;
  @State copied: boolean = false;
  /** 最近一次失败的用户可读文案：Resource 走多语言资源。 */
  @State error: ResourceStr = '';
  @State focusedField: string = '';
  @State appLockEnabled: boolean = false;
  @State lockPin: string = '';
  @State lockPinNew: string = '';
  @State lockPinConfirm: string = '';
  /** 应用锁区的错误提示：Resource 走多语言资源。 */
  @State lockError: ResourceStr = '';
  @State lockSaving: boolean = false;

  private cryptoService: CryptoService = new CryptoService();
  private settingsService: SettingsService = new SettingsService();
  private storageService: StorageService = StorageService.getInstance();
  private clipboardService: ClipboardService = new ClipboardService();
  private pinService: PinService = new PinService();

  aboutToAppear(): void {
    const settings = this.settingsService.getSettings();
    // 用 isLockUsable() 而非 appLockEnabled：校验值缺失（写入被中断）时锁其实并不会生效，
    // 若按标记显示「已开启」会让用户误以为口令已受保护；此时按未开启展示，重新录入 PIN 即可修复。
    this.appLockEnabled = this.pinService.isLockUsable();
    this.isFirstSetup = !settings.encryptionInitialized;
    if (!this.isFirstSetup) {
      const secret: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
      if (secret === undefined || secret.length === 0) {
        this.keyLost = true;
        this.isFirstSetup = true;
      } else {
        this.step = 0;
      }
    }
  }

  private onGenerate(): void {
    if (this.hasGenerated && !this.isFirstSetup) {
      promptAction.showDialog({
        title: $r('app.string.security_regen_title'),
        message: $r('app.string.security_regen_message'),
        buttons: [
          { text: $r('app.string.common_cancel'), color: '#666666' },
          { text: $r('app.string.security_regen_confirm'), color: '#E84026' }
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
    this.clipboardService.copySensitiveText(this.encryptionSecret).then((result: Result<void>) => {
      if (result.success) {
        this.copied = true;
        promptAction.showToast({ message: $r('app.string.security_key_copied') });
      } else {
        promptAction.showToast({ message: $r('app.string.security_copy_failed') });
      }
    });
  }

  /**
   * 把密钥交给系统关键资产存储托管；写入失败则弹窗提示，用户可点「重试」重新写入。
   *
   * 无论最终是否写入成功都会回调 onDone，保证主流程（跳转首页 / 返回上一页）不被阻断——
   * 密钥已在 AppStorage 生效，本次会话可用；仅下次冷启动需手动输入密钥。
   */
  private persistSecretToKeyStore(secret: string, onDone: () => void): void {
    const keyStoreService: KeyStoreService = new KeyStoreService();
    keyStoreService.save(secret).then((stored: boolean) => {
      if (stored) {
        onDone();
        return;
      }
      promptAction.showDialog({
        title: $r('app.string.security_keystore_failed_title'),
        message: $r('app.string.security_keystore_failed_message'),
        buttons: [
          { text: $r('app.string.security_later'), color: '#666666' },
          { text: $r('app.string.common_retry'), color: '#0A59F7' }
        ]
      }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
        if (dialogResult.index === 1) {
          this.persistSecretToKeyStore(secret, onDone);
        } else {
          onDone();
        }
      });
    });
  }

  private onSaveFirstSetup(): void {
    const secret: string = this.encryptionSecret.trim();
    if (secret.length === 0) {
      this.error = $r('app.string.security_secret_required');
      return;
    }
    if (!this.isSecretLengthValid(secret)) {
      this.error = $r('app.string.security_secret_length_invalid');
      return;
    }
    this.saveFirstSetupSecret(secret);
  }

  private saveFirstSetupSecret(secret: string): void {
    this.saving = true;
    this.error = '';
    AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, secret);
    const settings = this.settingsService.getSettings();
    settings.encryptionInitialized = true;
    this.settingsService.saveSettings(settings).then((result: Result<void>) => {
      this.saving = false;
      if (result.success) {
        Logger.info('Encryption key initialized');
        // 交给系统关键资产存储保管，之后启动可静默自动解锁（加密只作用于本地存储与 WebDAV 密文）
        this.persistSecretToKeyStore(secret, () => {
          router.replaceUrl({ url: 'pages/HomePage' });
        });
      } else {
        this.error = $r('app.string.security_save_failed');
      }
    });
  }

  private isSecretLengthValid(secret: string): boolean {
    return secret.length >= USER_SECRET_MIN_LENGTH && secret.length <= USER_SECRET_MAX_LENGTH;
  }

  private onVerifyOldSecret(): void {
    this.verifyingOld = true;
    this.error = '';
    const oldSecret: string = this.oldSecret.trim();
    if (oldSecret.length === 0) {
      this.error = $r('app.string.security_old_secret_required');
      this.verifyingOld = false;
      return;
    }
    // 本地还没有加密数据（从未保存过口令，或旧密文已被「清除并重开」隔离）：
    // 没有密文需要校验与重加密，直接进入第 2 步设置新密钥，不应报「读取失败」。
    if (!this.storageService.isInitialized()) {
      this.verifyingOld = false;
      this.step = 1;
      promptAction.showToast({ message: $r('app.string.security_no_local_data') });
      return;
    }
    const bytesResult: Result<Uint8Array> = this.storageService.readEncryptedFile();
    if (!bytesResult.success || bytesResult.data === undefined) {
      this.verifyingOld = false;
      this.error = bytesResult.error !== undefined ? bytesResult.error.message : $r('app.string.security_read_local_failed');
      return;
    }
    this.storageService.decodeEncryptedDatabase(bytesResult.data, oldSecret).then((decodeResult: Result<DatabaseModel>) => {
      this.verifyingOld = false;
      if (decodeResult.success && decodeResult.data !== undefined) {
        this.step = 1;
        this.error = '';
      } else {
        this.error = $r('app.string.security_old_secret_incorrect');
      }
    });
  }

  private onSaveNewSecret(): void {
    const newSecret: string = this.newSecret.trim();
    if (newSecret.length === 0) {
      this.error = $r('app.string.security_new_secret_required');
      return;
    }
    if (!this.isSecretLengthValid(newSecret)) {
      this.error = $r('app.string.security_secret_length_invalid');
      return;
    }
    this.saving = true;
    this.error = '';
    const oldSecret: string = this.oldSecret.trim();
    // 本地无加密数据：没有密文需要重加密，直接切换密钥（否则会误报「读取本地数据失败」）
    if (!this.storageService.isInitialized()) {
      this.applyNewSecretWithoutData(newSecret);
      return;
    }
    const bytesResult: Result<Uint8Array> = this.storageService.readEncryptedFile();
    if (!bytesResult.success || bytesResult.data === undefined) {
      this.saving = false;
      this.error = bytesResult.error !== undefined ? bytesResult.error.message : $r('app.string.security_read_local_failed');
      return;
    }
    this.storageService.decodeEncryptedDatabase(bytesResult.data, oldSecret).then((decodeResult: Result<DatabaseModel>) => {
      if (!decodeResult.success || decodeResult.data === undefined) {
        this.saving = false;
        this.error = $r('app.string.security_decrypt_failed');
        return;
      }
      const db: DatabaseModel = decodeResult.data;
      this.storageService.replaceDatabase(db, newSecret).then((replaceResult: Result<void>) => {
        this.saving = false;
        if (replaceResult.success) {
          AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, newSecret);
          // WebDAV 密码同样用旧密钥加密，需用新密钥重新加密，否则之后解密失败导致同步认证失败；
          // 重加密完成后再触发上传，避免同步读到尚未更新的密码密文
          this.settingsService.loadWebDavConfig(oldSecret).then((webDavConfig: WebDavConfig) => {
            if (webDavConfig.password.length > 0) {
              this.settingsService.saveWebDavConfig(webDavConfig, newSecret).then(() => {
                this.triggerSyncAfterKeyChange(newSecret);
              });
            } else {
              this.triggerSyncAfterKeyChange(newSecret);
            }
          });
          // 更新系统关键资产存储里的密钥（存在则原地更新，不存在才新增）；写入失败弹窗可重试
          this.persistSecretToKeyStore(newSecret, () => {
            Logger.info('Encryption key changed');
            promptAction.showToast({ message: $r('app.string.security_key_updated') });
            router.back();
          });
        } else {
          this.error = $r('app.string.security_save_failed');
        }
      });
    });
  }

  /**
   * 本地已用新密钥重新加密，云端仍是旧密钥的密文：主动上传覆盖，否则之后拉取必然解密失败。
   * 未启用同步 / 未开启自动推送时，SyncService 内部会静默跳过。
   */
  private triggerSyncAfterKeyChange(newSecret: string): void {
    SyncService.getInstance().onEncryptionKeyChanged(newSecret).then((result: Result<void>) => {
      if (result.success) {
        Logger.info('Sync after key change requested');
        return;
      }
      const message: ResourceStr = result.error !== undefined ? result.error.message : $r('app.string.security_sync_failed');
      // 日志正文保持英文不变；拼接的错误详情需要纯文本，Resource 先解析为当前语言文案
      Logger.error('Sync after key change failed: ' + (typeof message === 'string' ? message : UiText.of(message)));
    });
  }

  /**
   * 本地没有加密数据文件时的密钥切换：跳过数据库重加密，只更新密钥托管与 WebDAV 密码。
   * 旧密钥取自当前生效的密钥（AppStorage），而不是用户在「验证旧密钥」里输入的文本——
   * 没有密文可校验时输入值不可信，用它去解密 WebDAV 密码会失败。
   */
  private applyNewSecretWithoutData(newSecret: string): void {
    const previous: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    const previousSecret: string = previous !== undefined ? previous : '';
    AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, newSecret);
    // WebDAV 密码用旧密钥加密，需用新密钥重新加密，否则之后解密失败导致同步认证失败
    if (previousSecret.length > 0) {
      this.settingsService.loadWebDavConfig(previousSecret).then((webDavConfig: WebDavConfig) => {
        if (webDavConfig.password.length > 0) {
          this.settingsService.saveWebDavConfig(webDavConfig, newSecret);
        }
      });
    }
    // 写入系统关键资产存储；失败弹窗可重试，完成后才收尾退出
    this.persistSecretToKeyStore(newSecret, () => {
      this.saving = false;
      Logger.info('Encryption key changed (no local encrypted data)');
      promptAction.showToast({ message: $r('app.string.security_key_updated') });
      router.back();
    });
  }

  /**
   * 忘记密钥：安全提示确认后，删除系统安全存储中的旧密钥、清空本地加密数据与 WebDAV 密码，
   * 随后回到「设置新密钥」界面让用户重新录入。
   *
   * 本地密文**物理删除**（fs.unlink：totp.db.enc、写入临时文件，以及历史遗留的
   * totp.db.enc.orphan-<时间戳> 备份），不可恢复；不删除则新密钥会被旧密文挡住。
   */
  private onForgetKey(): void {
    promptAction.showDialog({
      title: $r('app.string.security_forget_title'),
      message: $r('app.string.security_forget_message'),
      buttons: [
        { text: $r('app.string.common_cancel'), color: '#666666' },
        { text: $r('app.string.security_forget_confirm'), color: '#E84026' }
      ]
    }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
      if (dialogResult.index !== 1) {
        return;
      }
      this.saving = true;
      this.error = '';
      this.removeOldKeyThenReset();
    });
  }

  /**
   * 删除系统安全存储中的旧密钥；失败时弹窗可重试。
   * 取消则中止整个「忘记密钥」流程——旧密钥仍留在系统托管里，此时若继续删本地数据，
   * 用户会以为密钥已销毁，实际仍可能被系统静默取回，属于安全隐患。
   */
  private removeOldKeyThenReset(): void {
    const keyStoreService: KeyStoreService = new KeyStoreService();
    keyStoreService.remove().then((removed: boolean) => {
      if (removed) {
        this.resetLocalAfterForgetKey();
        return;
      }
      this.saving = false;
      promptAction.showDialog({
        title: $r('app.string.security_delete_old_key_failed_title'),
        message: $r('app.string.security_delete_old_key_failed_message'),
        buttons: [
          { text: $r('app.string.common_cancel'), color: '#666666' },
          { text: $r('app.string.common_retry'), color: '#E84026' }
        ]
      }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
        if (dialogResult.index === 1) {
          this.saving = true;
          this.removeOldKeyThenReset();
        } else {
          promptAction.showToast({ message: $r('app.string.security_forget_cancelled') });
        }
      });
    });
  }

  /** 确认旧密钥已从系统托管中删除后，才真正清除本地加密数据与相关密钥副本。 */
  private resetLocalAfterForgetKey(): void {
    AppStorage.setOrCreate<string>(SECRET_STORAGE_KEY, '');
    // 旧密钥已丢弃，WebDAV 密码密文不可再解密：只清密码，保留地址等非密配置
    this.settingsService.loadWebDavConfig('').then((webDavConfig: WebDavConfig) => {
      webDavConfig.password = '';
      this.settingsService.saveWebDavConfig(webDavConfig, '');
    });
    this.storageService.deleteLocalDatabase().then((resetResult: Result<void>) => {
      const settings = this.settingsService.getSettings();
      settings.encryptionInitialized = false;
      this.settingsService.saveSettings(settings).then(() => {
        this.saving = false;
        if (!resetResult.success) {
          const message: ResourceStr = resetResult.error !== undefined ? resetResult.error.message : $r('app.string.security_clear_local_failed');
          promptAction.showToast({ message: message });
          return;
        }
        this.enterSetupAfterReset();
        promptAction.showToast({ message: $r('app.string.security_cleared') });
      });
    });
  }

  /** 重置后的本地状态：回到「设置密钥」界面，并清空全部残留输入。 */
  private enterSetupAfterReset(): void {
    this.keyLost = false;
    this.isFirstSetup = true;
    this.step = 0;
    this.oldSecret = '';
    this.newSecret = '';
    this.encryptionSecret = '';
    this.generatedSecret = '';
    this.hasGenerated = false;
    this.copied = false;
    this.focusedField = '';
    this.error = '';
  }

  /**
   * 开启应用锁：校验值写进设置成功后才把界面状态置为「已开启」。
   * 开启动作本身不弹锁定遮罩——用户此刻正在页内操作，锁只在冷启动与退后台后生效。
   */
  private async onEnableAppLock(): Promise<void> {
    if (this.lockSaving) {
      return;
    }
    this.lockError = '';
    if (!PinService.isValidPin(this.lockPinNew)) {
      this.lockError = $r('app.string.pin_invalid_format');
      return;
    }
    if (this.lockPinNew !== this.lockPinConfirm) {
      this.lockError = $r('app.string.pin_mismatch');
      return;
    }
    this.lockSaving = true;
    const result: Result<void> = await this.pinService.setPin(this.lockPinNew);
    this.lockSaving = false;
    if (!result.success) {
      this.lockError = result.error !== undefined ? result.error.message : $r('app.string.pin_enable_failed');
      return;
    }
    this.appLockEnabled = true;
    this.lockPin = '';
    this.lockPinNew = '';
    this.lockPinConfirm = '';
    promptAction.showToast({ message: $r('app.string.security_app_lock_on') });
  }

  /** 更换 PIN：先验旧 PIN 再覆盖校验值，中途任一步失败都保留原锁不被动摇。 */
  private async onChangeAppLockPin(): Promise<void> {
    if (this.lockSaving) {
      return;
    }
    this.lockError = '';
    if (!PinService.isValidPin(this.lockPin)) {
      this.lockError = $r('app.string.pin_current_required');
      return;
    }
    if (!PinService.isValidPin(this.lockPinNew)) {
      this.lockError = $r('app.string.pin_new_invalid_format');
      return;
    }
    if (this.lockPinNew !== this.lockPinConfirm) {
      this.lockError = $r('app.string.pin_new_mismatch');
      return;
    }
    this.lockSaving = true;
    const verified: Result<boolean> = await this.pinService.verify(this.lockPin);
    if (!verified.success) {
      this.lockSaving = false;
      this.lockError = verified.error !== undefined ? verified.error.message : $r('app.string.pin_verify_failed');
      return;
    }
    if (verified.data !== true) {
      this.lockSaving = false;
      this.lockPin = '';
      this.lockError = $r('app.string.pin_current_incorrect');
      return;
    }
    const result: Result<void> = await this.pinService.setPin(this.lockPinNew);
    this.lockSaving = false;
    if (!result.success) {
      this.lockError = result.error !== undefined ? result.error.message : $r('app.string.pin_change_failed');
      return;
    }
    this.lockPin = '';
    this.lockPinNew = '';
    this.lockPinConfirm = '';
    promptAction.showToast({ message: $r('app.string.security_pin_updated') });
  }

  /** 关闭应用锁：PinService.disable 内部会先校验 PIN，校验通过才清除校验值。 */
  private async onDisableAppLock(): Promise<void> {
    if (this.lockSaving) {
      return;
    }
    this.lockError = '';
    if (!PinService.isValidPin(this.lockPin)) {
      this.lockError = $r('app.string.pin_current_required_before_disable');
      return;
    }
    this.lockSaving = true;
    const result: Result<void> = await this.pinService.disable(this.lockPin);
    this.lockSaving = false;
    if (!result.success) {
      this.lockError = result.error !== undefined ? result.error.message : $r('app.string.pin_disable_failed');
      return;
    }
    this.appLockEnabled = false;
    this.lockPin = '';
    this.lockPinNew = '';
    this.lockPinConfirm = '';
    promptAction.showToast({ message: $r('app.string.security_app_lock_off') });
  }

  @Builder
  header() {
    Row() {
      if (!this.isFirstSetup) {
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
      }

      Blank()

      Column({ space: 1 }) {
        Text($r('app.string.security_title'))
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.security_subtitle'))
          .fontSize(10.5)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)

      Blank()

      Text('')
        .width(42)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }

  /** 步骤指示：双色柔光节点。 */
  @Builder
  stepIndicator() {
    Row({ space: 8 }) {
      Column()
        .width(22)
        .height(5)
        .borderRadius(3)
        .linearGradient({ angle: 90, colors: trackGradientColors(0) })
        .shadow({ radius: 8, color: '#590A59F7', offsetX: 0, offsetY: 0 })
      Column()
        .width(22)
        .height(5)
        .borderRadius(3)
        .backgroundColor(this.step >= 1 ? $r('app.color.brand') : $r('app.color.glass_track'))
        .opacity(this.step >= 1 ? 1.0 : 0.7)
      Text(this.step >= 1 ? $r('app.string.security_step_2') : $r('app.string.security_step_1'))
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ left: 4 })
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  /** 主操作：渐变高光填充 + 能量光晕（Button 不支持 letterSpacing）。 */
  @Builder
  primaryButton(params: PrimaryButtonParams) {
    Button(params.label)
      .width('100%')
      .height(50)
      .borderRadius(25)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .linearGradient({ angle: 90, colors: trackGradientColors(0) })
      .fontColor($r('app.color.fab_foreground'))
      .shadow(glowButtonShadow())
      .enabled(params.enabled)
      .onClick(params.onTap)
  }

  @Builder
  hintCard(icon: Resource, title: ResourceStr, body: ResourceStr, danger: boolean) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image(icon)
          .width(18)
          .height(18)
          .fillColor(danger ? $r('app.color.danger') : $r('app.color.text_secondary'))
      }
      .width(36)
      .height(36)
      .borderRadius(12)
      .backgroundColor($r('app.color.scrim'))
      .border({ width: 1, color: $r('app.color.divider'), style: BorderStyle.Solid })

      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(danger ? $r('app.color.danger') : $r('app.color.text_primary'))
        Text(body)
          .fontSize(12)
          .lineHeight(19)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .borderRadius(16)
    .backgroundColor($r('app.color.glass_input_background'))
    .border({ width: 1, color: $r('app.color.glass_input_border'), style: BorderStyle.Solid })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  errorText() {
    // 错误文案可能是 Resource 或 string，统一用空串判「无错误」（两种赋值都不会等于 ''）
    if (this.error !== '') {
      Text(this.error)
        .fontSize(12.5)
        .fontColor($r('app.color.danger'))
        .width('100%')
    }
  }

  @Builder
  firstSetupView() {
    Column({ space: 16 }) {
      if (this.keyLost) {
        this.hintCard($r('app.media.ic_warning'), $r('app.string.security_key_lost_title'),
          $r('app.string.security_key_lost_body'), true)
      } else {
        this.hintCard($r('app.media.ic_security'), $r('app.string.security_local_protection_title'),
          $r('app.string.security_local_protection_body'), false)
      }

      Column({ space: 8 }) {
        Text($r('app.string.security_label_encryption_key'))
          .fontSize(12.5)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        TextInput({ placeholder: $r('app.string.security_placeholder_encryption_key'), text: $$this.encryptionSecret })
          .width('100%')
          .height(40)
          .borderRadius(12)
          .fontSize(14)
          .padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.field_background'))
          .placeholderColor($r('app.color.text_tertiary'))
          .caretColor($r('app.color.brand'))
          .type(InputType.Password)
          .showPasswordIcon(true)
          .border({
            width: 1.5,
            color: this.focusedField === 'first' ? $r('app.color.brand') : $r('app.color.field_border'),
            style: BorderStyle.Solid
          })
          .shadow(this.focusedField === 'first' ? focusGlowShadow() : noShadow())
          .onFocus(() => { this.focusedField = 'first'; })
          .onBlur(() => { if (this.focusedField === 'first') { this.focusedField = ''; } })
          .onChange(() => {
            // text 已由 $$this.encryptionSecret 双向同步，这里只需清掉「已生成/已复制」提示
            this.hasGenerated = false;
            this.copied = false;
          })

        Row({ space: 10 }) {
          Button($r('app.string.common_generate'))
            .layoutWeight(1)
            .height(48)
            .borderRadius(14)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.brand'))
            .border({ width: 1, color: $r('app.color.brand'), style: BorderStyle.Solid })
            .onClick(() => this.onGenerate())

          Button(this.copied ? $r('app.string.security_copied') : $r('app.string.security_copy_key'))
            .layoutWeight(1)
            .height(48)
            .borderRadius(14)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Color.Transparent)
            .fontColor(this.encryptionSecret.length > 0 ? $r('app.color.brand') : $r('app.color.text_tertiary'))
            .border({
              width: 1,
              color: this.encryptionSecret.length > 0 ? $r('app.color.brand') : $r('app.color.field_border'),
              style: BorderStyle.Solid
            })
            .enabled(this.encryptionSecret.length > 0)
            .onClick(() => this.onCopy())
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.errorText()

      this.primaryButton({
        label: this.saving ? $r('app.string.security_saving') : (this.keyLost ? $r('app.string.security_reset_key') : $r('app.string.security_finish_setup')),
        enabled: !this.saving,
        onTap: () => this.onSaveFirstSetup()
      })
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassGroupShadow())
  }

  @Builder
  changeKeyStep0() {
    Column({ space: 16 }) {
      this.stepIndicator()

      this.hintCard($r('app.media.ic_key'), $r('app.string.security_verify_current_title'),
        $r('app.string.security_verify_current_body'), false)

      Column({ space: 8 }) {
        Text($r('app.string.security_label_current_key'))
          .fontSize(12.5)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        SecurityField({ value: $oldSecret, placeholder: $r('app.string.security_placeholder_old_secret') })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.errorText()

      this.primaryButton({
        label: this.verifyingOld ? $r('app.string.security_verifying') : $r('app.string.security_verify_old_button'),
        enabled: !this.verifyingOld,
        onTap: () => this.onVerifyOldSecret()
      })

      // 忘记密钥：删除旧密钥与本地加密数据，转入「设置新密钥」
      Button($r('app.string.security_forget_button'))
        .width('100%')
        .height(44)
        .borderRadius(14)
        .fontSize(13.5)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.danger'))
        .enabled(!this.saving && !this.verifyingOld)
        .onClick(() => this.onForgetKey())
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassGroupShadow())
  }

  @Builder
  changeKeyStep1() {
    Column({ space: 16 }) {
      this.stepIndicator()

      this.hintCard($r('app.media.ic_edit'), $r('app.string.security_set_new_title'),
        $r('app.string.security_set_new_body'), false)

      Column({ space: 8 }) {
        Text($r('app.string.security_label_new_key'))
          .fontSize(12.5)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        TextInput({ placeholder: $r('app.string.security_placeholder_new_secret'), text: $$this.newSecret })
          .width('100%')
          .height(40)
          .borderRadius(12)
          .fontSize(14)
          .padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.field_background'))
          .placeholderColor($r('app.color.text_tertiary'))
          .caretColor($r('app.color.brand'))
          .type(InputType.Password)
          .showPasswordIcon(true)
          .border({
            width: 1.5,
            color: this.focusedField === 'new' ? $r('app.color.brand') : $r('app.color.field_border'),
            style: BorderStyle.Solid
          })
          .shadow(this.focusedField === 'new' ? focusGlowShadow() : noShadow())
          .onFocus(() => { this.focusedField = 'new'; })
          .onBlur(() => { if (this.focusedField === 'new') { this.focusedField = ''; } })
          .onChange((input: string) => {
            this.newSecret = input;
            this.copied = false;
          })

        Row({ space: 10 }) {
          Button($r('app.string.common_generate'))
            .layoutWeight(1)
            .height(48)
            .borderRadius(14)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.brand'))
            .border({ width: 1, color: $r('app.color.brand'), style: BorderStyle.Solid })
            .onClick(() => {
              this.newSecret = this.cryptoService.generateRandomEncryptionSecret();
              this.copied = false;
            })

          Button(this.copied ? $r('app.string.security_copied') : $r('app.string.security_copy_new_key'))
            .layoutWeight(1)
            .height(48)
            .borderRadius(14)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Color.Transparent)
            .fontColor(this.newSecret.length > 0 ? $r('app.color.brand') : $r('app.color.text_tertiary'))
            .border({
              width: 1,
              color: this.newSecret.length > 0 ? $r('app.color.brand') : $r('app.color.field_border'),
              style: BorderStyle.Solid
            })
            .enabled(this.newSecret.length > 0)
            .onClick(() => {
              this.clipboardService.copySensitiveText(this.newSecret).then((result: Result<void>) => {
                if (result.success) {
                  this.copied = true;
                  promptAction.showToast({ message: $r('app.string.security_key_copied') });
                } else {
                  promptAction.showToast({ message: $r('app.string.security_copy_failed') });
                }
              })
            })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.hintCard($r('app.media.ic_warning'), $r('app.string.security_keep_safe_title'),
        $r('app.string.security_keep_safe_body'), true)

      this.errorText()

      this.primaryButton({
        label: this.saving ? $r('app.string.security_saving') : $r('app.string.security_save_new_key'),
        enabled: !this.saving,
        onTap: () => this.onSaveNewSecret()
      })
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassGroupShadow())
  }

  /** 应用锁卡片：未开启时录入 PIN，已开启时可改 PIN 或（验 PIN 后）关闭。 */
  @Builder
  appLockView() {
    Column({ space: 16 }) {
      // 注意：此处不能把三元表达式（$r 结果）直接作为 @Builder 参数传入 ——
      // 实测开启/关闭应用锁后，hintCard 内的 Text 不会随状态刷新（残留旧文案），
      // 必须用 if/else 包裹两次调用，让分支切换重建整个 hintCard 子树。
      if (this.appLockEnabled) {
        this.hintCard($r('app.media.ic_security'), $r('app.string.security_app_lock_on'),
          $r('app.string.security_app_lock_on_body'), false)
      } else {
        this.hintCard($r('app.media.ic_warning'), $r('app.string.security_app_lock_off'),
          $r('app.string.security_app_lock_off_body'), true)
      }

      if (this.appLockEnabled) {
        Column({ space: 8 }) {
          this.fieldLabel($r('app.string.security_label_current_pin'))
          PinField({ value: $lockPin, placeholder: $r('app.string.security_placeholder_current_pin') })

          this.fieldLabel($r('app.string.security_label_new_pin'))
          PinField({ value: $lockPinNew, placeholder: $r('app.string.security_placeholder_new_pin') })

          this.fieldLabel($r('app.string.security_label_confirm_pin'))
          PinField({ value: $lockPinConfirm, placeholder: $r('app.string.security_placeholder_confirm_pin') })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else {
        Column({ space: 8 }) {
          this.fieldLabel($r('app.string.security_label_set_pin'))
          PinField({ value: $lockPinNew, placeholder: $r('app.string.security_placeholder_set_pin') })

          this.fieldLabel($r('app.string.security_label_confirm_set_pin'))
          PinField({ value: $lockPinConfirm, placeholder: $r('app.string.security_placeholder_confirm_set_pin') })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      if (this.lockError !== '') {
        Text(this.lockError)
          .fontSize(12.5)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }

      if (this.appLockEnabled) {
        this.primaryButton({
          label: this.lockSaving ? $r('app.string.security_processing') : $r('app.string.security_change_pin'),
          enabled: !this.lockSaving,
          onTap: () => {
            this.onChangeAppLockPin();
          }
        })

        Button($r('app.string.security_disable_app_lock'))
          .width('100%')
          .height(44)
          .borderRadius(14)
          .fontSize(13.5)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.danger'))
          .enabled(!this.lockSaving)
          .onClick(() => {
            this.onDisableAppLock();
          })
      } else {
        this.primaryButton({
          label: this.lockSaving ? $r('app.string.security_processing') : $r('app.string.security_enable_app_lock'),
          enabled: !this.lockSaving,
          onTap: () => {
            this.onEnableAppLock();
          }
        })
      }
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor($r('app.color.card_background'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
    .shadow(glassGroupShadow())
  }

  @Builder
  fieldLabel(label: ResourceStr) {
    Text(label)
      .fontSize(12.5)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
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
    // @Entry 页面的 build 只能有唯一根节点，且必须是容器组件；
    // AuroraBackground 是自定义组件，故由 Stack 作为根承载它。
    Stack() {
      AuroraBackground() {
        Column() {
          this.header()

          Scroll() {
            Column({ space: 14 }) {
              if (this.isFirstSetup) {
                this.firstSetupView()
              } else {
                if (this.step === 0) {
                  this.changeKeyStep0()
                } else {
                  this.changeKeyStep1()
                }
                // 应用锁只在密钥已初始化后出现：首屏要把注意力留给「设置加密密钥」
                this.appLockView()
              }
            }
            .width('100%')
            // 同设置页：避免内容短于视口时被 Scroll 垂直居中
            .constraintSize({ minHeight: '100%' })
            .justifyContent(FlexAlign.Start)
            .padding({ left: 16, right: 16, top: 4, bottom: 28 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .align(Alignment.TopStart)  // 内容不足一屏时不被 Scroll 垂直居中
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

/**
 * 密码输入框：下沉式冰晶输入 + 获焦主色光晕。
 *
 * 关键点：TextInput 的 text 必须用 **$$ 双向绑定**（@Link 变量）。
 * 官方明确提示 —— 只传 `text: value` 时「组件刷新会导致 TextInput 中的文本内容异常」，
 * 表现为输入后一失焦（触发重渲染）内容被回滚/清空；$$ 绑定后变量与组件内部状态实时同步，
 * 任何刷新都不会丢失输入。聚焦光晕状态收敛在组件内部，不再驱动页面级重渲染。
 */
@Component
struct SecurityField {
  @Link value: string;
  @Prop placeholder: ResourceStr = '';
  @State focused: boolean = false;

  build() {
    TextInput({ placeholder: this.placeholder, text: $$this.value })
      .width('100%')
      .height(40)
      .borderRadius(12)
      .fontSize(14)
      .fontColor($r('app.color.text_primary'))
      .padding({ left: 14, right: 14 })
      .backgroundColor($r('app.color.field_background'))
      .placeholderColor($r('app.color.text_tertiary'))
      .caretColor($r('app.color.brand'))
      .type(InputType.Password)
      .showPasswordIcon(true)
      .border({
        width: 1.5,
        color: this.focused ? $r('app.color.brand') : $r('app.color.field_border'),
        style: BorderStyle.Solid
      })
      .shadow(this.focused ? focusGlowShadow() : noShadow())
      .onFocus(() => {
        this.focused = true;
      })
      .onBlur(() => {
        this.focused = false;
      })
  }
}

/**
 * 应用锁 PIN 输入框：同样必须用 `$$` 双向绑定（见 SecurityField 的说明）。
 *
 * 键盘收数字，但剪贴板粘贴仍可能带入非数字或超长内容，onChange 里再做一次过滤；
 * 过滤写在组件内部，避免每次按键都触发页面级重渲染。
 */
@Component
struct PinField {
  @Link value: string;
  @Prop placeholder: ResourceStr = '';
  @State focused: boolean = false;

  build() {
    TextInput({ placeholder: this.placeholder, text: $$this.value })
      .width('100%')
      .height(40)
      .borderRadius(12)
      .fontSize(16)
      .letterSpacing(4)
      .fontColor($r('app.color.text_primary'))
      .padding({ left: 14, right: 14 })
      .backgroundColor($r('app.color.field_background'))
      .placeholderColor($r('app.color.text_tertiary'))
      .caretColor($r('app.color.brand'))
      .type(InputType.Number)
      .maxLength(6)
      .border({
        width: 1.5,
        color: this.focused ? $r('app.color.brand') : $r('app.color.field_border'),
        style: BorderStyle.Solid
      })
      .shadow(this.focused ? focusGlowShadow() : noShadow())
      .onChange((input: string) => {
        const digits: string = input.replace(/[^0-9]/g, '').substring(0, 6);
        if (digits !== input) {
          this.value = digits;
        }
      })
      .onFocus(() => {
        this.focused = true;
      })
      .onBlur(() => {
        this.focused = false;
      })
  }
}
