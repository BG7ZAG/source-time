import { router, promptAction } from '@kit.ArkUI';
import { CryptoService } from '../service/CryptoService';
import { KeyStoreService } from '../service/KeyStoreService';
import { SettingsService } from '../service/SettingsService';
import { StorageService } from '../service/StorageService';
import { ClipboardService } from '../service/ClipboardService';
import { DatabaseModel } from '../model/DatabaseModel';
import { Result } from '../types/Result';
import { Logger } from '../utils/Logger';
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
 * 安全与密钥页（鸿蒙 7 版）：冰晶卡片 + 聚焦发光输入框 + 双色柔光步骤指示。
 */
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
  @State focusedField: string = '';

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
        // 交给系统关键资产存储保管，之后启动可静默自动解锁（加密只作用于本地存储与 WebDAV 密文）
        const keyStoreService: KeyStoreService = new KeyStoreService();
        keyStoreService.save(secret).then((stored: boolean) => {
          if (!stored) {
            promptAction.showToast({ message: '密钥未能写入系统安全存储，下次启动可能无法自动解锁' });
          }
          router.replaceUrl({ url: 'pages/HomePage' });
        });
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
          // 同步更新系统关键资产存储里的密钥（save 内部先删后加）
          const keyStoreService: KeyStoreService = new KeyStoreService();
          keyStoreService.save(newSecret).then((stored: boolean) => {
            if (!stored) {
              promptAction.showToast({ message: '密钥已更新，但未能写入系统安全存储' });
            }
          });
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
        Text('安全与密钥')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('保护你的数据')
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
      Text(this.step >= 1 ? '第 2 / 2 步' : '第 1 / 2 步')
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ left: 4 })
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  glassField(key: string, placeholder: string, value: string, masked: boolean) {
    TextInput({ placeholder: placeholder, text: value })
      .layoutWeight(1)
      .height(48)
      .borderRadius(14)
      .fontSize(14)
      .padding({ left: 14, right: 14 })
      .backgroundColor($r('app.color.field_background'))
      .placeholderColor($r('app.color.text_tertiary'))
      .caretColor($r('app.color.brand'))
      .type(masked ? InputType.Password : InputType.Normal)
      .showPasswordIcon(masked)
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
        if (key === 'first') {
          this.encryptionSecret = input;
          this.hasGenerated = false;
          this.copied = false;
        } else if (key === 'old') {
          this.oldSecret = input;
        } else {
          this.newSecret = input;
          this.copied = false;
        }
      })
  }

  /** 主操作：渐变高光填充 + 能量光晕（Button 不支持 letterSpacing）。 */
  @Builder
  primaryButton(label: string, enabled: boolean, onTap: () => void) {
    Button(label)
      .width('100%')
      .height(50)
      .borderRadius(25)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .linearGradient({ angle: 90, colors: trackGradientColors(0) })
      .fontColor($r('app.color.fab_foreground'))
      .shadow(glowButtonShadow())
      .enabled(enabled)
      .onClick(onTap)
  }

  /** 次级操作：Outlined Glass。 */
  @Builder
  outlinedButton(label: string, onTap: () => void) {
    Button(label)
      .width(84)
      .height(48)
      .borderRadius(14)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(Color.Transparent)
      .fontColor($r('app.color.brand'))
      .border({ width: 1, color: $r('app.color.brand'), style: BorderStyle.Solid })
      .onClick(onTap)
  }

  @Builder
  hintCard(icon: Resource, title: string, body: string, danger: boolean) {
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
    if (this.error.length > 0) {
      Text(this.error)
        .fontSize(12.5)
        .fontColor($r('app.color.danger'))
        .width('100%')
    }
  }

  @Builder
  firstSetupView() {
    Column({ space: 16 }) {
      this.hintCard($r('app.media.ic_security'), '本地加密保护',
        '源时会使用你设置的加密密钥保护本地 TOTP 数据，密钥不会上传到任何服务器。', false)

      Column({ space: 8 }) {
        Text('加密密钥')
          .fontSize(12.5)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        Row({ space: 10 }) {
          this.glassField('first', '输入加密密钥', this.encryptionSecret, true)
          this.outlinedButton('生成', () => this.onGenerate())
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.encryptionSecret.length > 0) {
        Row({ space: 10 }) {
          if (this.copied) {
            Row({ space: 6 }) {
              Image($r('app.media.ic_check'))
                .width(13)
                .height(13)
                .fillColor($r('app.color.text_secondary'))
              Text('已复制到剪贴板')
                .fontSize(12.5)
                .fontColor($r('app.color.success'))
                .layoutWeight(1)
            }
            .layoutWeight(1)
          } else {
            Text('建议立即复制并离线保存')
              .fontSize(12.5)
              .fontColor($r('app.color.text_tertiary'))
              .layoutWeight(1)
          }
          this.outlinedButton(this.copied ? '已复制' : '复制密钥', () => this.onCopy())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      this.errorText()

      this.primaryButton(this.saving ? '保存中...' : '完成初始化', !this.saving, () => this.onSaveFirstSetup())
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

      this.hintCard($r('app.media.ic_key'), '验证当前密钥',
        '修改加密密钥需要先验证当前密钥，验证通过后会用新密钥重新加密全部数据。', false)

      Column({ space: 8 }) {
        Text('当前加密密钥')
          .fontSize(12.5)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        this.glassField('old', '输入旧密钥', this.oldSecret, true)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.errorText()

      this.primaryButton(this.verifyingOld ? '验证中...' : '验证旧密钥', !this.verifyingOld,
        () => this.onVerifyOldSecret())
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

      this.hintCard($r('app.media.ic_edit'), '设置新密钥',
        '旧密钥验证成功。请输入或随机生成新的加密密钥。', false)

      Column({ space: 8 }) {
        Text('新加密密钥')
          .fontSize(12.5)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        Row({ space: 10 }) {
          this.glassField('new', '输入新密钥', this.newSecret, true)
          this.outlinedButton('生成', () => {
            this.newSecret = this.cryptoService.generateRandomEncryptionSecret();
            this.copied = false;
          })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.newSecret.length > 0) {
        Row({ space: 10 }) {
          if (this.copied) {
            Row({ space: 6 }) {
              Image($r('app.media.ic_check'))
                .width(13)
                .height(13)
                .fillColor($r('app.color.text_secondary'))
              Text('已复制到剪贴板')
                .fontSize(12.5)
                .fontColor($r('app.color.success'))
                .layoutWeight(1)
            }
            .layoutWeight(1)
          } else {
            Text('建议立即复制并离线保存')
              .fontSize(12.5)
              .fontColor($r('app.color.text_tertiary'))
              .layoutWeight(1)
          }
          this.outlinedButton(this.copied ? '已复制' : '复制新密钥', () => {
            this.clipboardService.copyText(this.newSecret).then((result: Result<void>) => {
              if (result.success) {
                this.copied = true;
                promptAction.showToast({ message: '密钥已复制' });
              } else {
                promptAction.showToast({ message: '复制失败' });
              }
            })
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      this.hintCard($r('app.media.ic_warning'), '请妥善保管',
        '源时不提供服务器端密钥恢复能力，丢失密钥后已加密数据将无法解密。', true)

      this.errorText()

      this.primaryButton(this.saving ? '保存中...' : '保存新密钥', !this.saving, () => this.onSaveNewSecret())
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
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
      }
    }
    .width('100%')
    .height('100%')
  }
}
