import { router, promptAction } from '@kit.ArkUI';
import { TotpCard } from '../components/TotpCard';
import { EmptyState } from '../components/EmptyState';
import { ParticleButton } from '../components/ParticleButton';
import { HomeViewModel, TotpDisplayItem } from '../viewmodel/HomeViewModel';
import { TotpItem } from '../model/TotpItem';
import { Result } from '../types/Result';
import { AppRoutes, CURRENT_PRIVACY_POLICY_VERSION } from '../constants/AppConstants';
import { SettingsService } from '../service/SettingsService';
import { AppContextHolder } from '../utils/AppContextHolder';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

@Entry
@Component
struct HomePage {
  @State displayItems: TotpDisplayItem[] = [];
  private viewModel: HomeViewModel = new HomeViewModel();
  private settingsService: SettingsService = new SettingsService();

  aboutToAppear(): void {
    const settings = this.settingsService.getSettings();
    if (!settings.privacyPolicyAccepted) {
      this.showPrivacyDialog();
      return;
    }
    this.loadData();
  }

  onPageShow(): void {
    const settings = this.settingsService.getSettings();
    if (settings.privacyPolicyAccepted && settings.encryptionInitialized) {
      this.viewModel.load().then(() => {
        this.refreshItems();
      });
    }
  }

  private showPrivacyDialog(): void {
    promptAction.showDialog({
      title: '源时（SourceTime）隐私政策',
      message: '版本：1.0\n\n' +
        '一、数据收集与使用\n' +
        '源时不收集您的个人身份信息，不要求注册或登录。\n' +
        '您主动输入的数据包括：TOTP 配置信息（发行方、账号、密钥）、加密密钥、WebDAV 配置。\n' +
        '上述数据仅存储在您的设备本地，不会自动发送到任何外部服务器。\n\n' +
        '二、数据存储与安全\n' +
        '所有 TOTP 数据均经过 AES-256-GCM 加密后存储在设备本地。\n' +
        '加密密钥通过 PBKDF2-HMAC-SHA256 派生，迭代 100,000 次。\n' +
        'WebDAV 密码同样经过加密后存储，不会以明文形式保存。\n' +
        '应用不会在日志中输出加密密钥、TOTP Secret 或 WebDAV 密码。\n\n' +
        '三、数据共享与传输\n' +
        '源时不会主动向开发者或任何第三方服务器上传您的数据。\n' +
        '如配置 WebDAV 同步，应用只会将加密后的数据文件上传到您指定的 WebDAV 服务器。\n' +
        'WebDAV 服务由您自行配置和管理。\n\n' +
        '四、用户权利\n' +
        '您有权随时删除 TOTP 数据、修改加密密钥、启用/禁用 WebDAV 同步。\n' +
        '卸载应用将清除所有本地存储的数据。\n\n' +
        '五、重要提示\n' +
        '请妥善保管您的加密密钥。源时不提供服务器端密钥恢复能力，\n' +
        '丢失密钥后将无法解密已加密的数据。\n\n' +
        '同意后可在 设置 > 隐私政策 中查看完整隐私政策内容。',
      buttons: [
        { text: '不同意', color: '#666666' },
        { text: '同意并继续', color: '#4CAF50' }
      ]
    }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
      if (dialogResult.index === 1) {
        const currentSettings = this.settingsService.getSettings();
        currentSettings.privacyPolicyAccepted = true;
        currentSettings.privacyPolicyVersion = CURRENT_PRIVACY_POLICY_VERSION;
        this.settingsService.saveSettings(currentSettings).then(() => {
          if (!currentSettings.encryptionInitialized) {
            router.replaceUrl({ url: AppRoutes.SECURITY });
          } else {
            this.loadData();
          }
        });
      } else {
        AppContextHolder.getContext().terminateSelf();
      }
    });
  }

  private loadData(): void {
    const secret: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (secret !== undefined && secret.length > 0) {
      this.viewModel.setEncryptionSecret(secret);
      this.viewModel.load().then(() => {
        this.refreshItems();
      });
    }
  }

  private refreshItems(): void {
    this.displayItems = this.viewModel.getDisplayItems();
  }

  private openSettings(): void {
    router.pushUrl({ url: AppRoutes.SETTINGS });
  }

  private openAdd(): void {
    router.pushUrl({ url: AppRoutes.ADD_TOTP });
  }

  private onCopy(item: TotpItem): void {
    this.viewModel.copyCode(item).then((result: Result<void>) => {
      const message: string = result.success ? '复制成功'
        : (result.error !== undefined ? result.error.message : '复制失败');
      promptAction.showToast({ message: message });
    });
  }

  private onDelete(item: TotpItem): void {
    promptAction.showDialog({
      title: '删除验证码？',
      message: '删除后该验证码将从本地数据中移除。',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '删除', color: '#E84026' }
      ]
    }).then((dialogResult: promptAction.ShowDialogSuccessResponse) => {
      if (dialogResult.index === 1) {
        this.viewModel.remove(item).then((removeResult: Result<void>) => {
          if (removeResult.success) {
            this.refreshItems();
          } else {
            const message: string = removeResult.error !== undefined ? removeResult.error.message : '删除失败';
            promptAction.showToast({ message: message });
          }
        });
      }
    });
  }

  @Builder
  header() {
    Row() {
      Text('源时')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Button() {
        Text('⚙')
          .fontSize(20)
          .fontColor($r('app.color.text_secondary'))
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(Color.Transparent)
      .onClick(() => this.openSettings())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  build() {
    Column() {
      this.header()

      if (this.displayItems.length === 0) {
        EmptyState({ message: '点击 + 添加验证码' })
          .layoutWeight(1)
      } else {
        List({ space: 12 }) {
          ForEach(this.displayItems, (display: TotpDisplayItem) => {
            ListItem() {
              TotpCard({
                issuer: display.item.issuer,
                account: display.item.account,
                secret: display.item.secret,
                algorithm: display.item.algorithm,
                digits: display.item.digits,
                period: display.item.period,
                onCopy: () => {
                  this.onCopy(display.item);
                },
                onDelete: () => {
                  this.onDelete(display.item);
                }
              })
            }
          }, (display: TotpDisplayItem) => display.item.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 4 })
      }

      ParticleButton({
        text: '＋',
        buttonType: ButtonType.Circle,
        buttonWidth: 56,
        buttonHeight: 56,
        fontSize: 24,
        bgColor: $r('app.color.brand'),
        fontColor: $r('app.color.fab_foreground'),
        onTap: () => this.openAdd()
      })
        .margin({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [[$r('app.color.page_gradient_start'), 0.0], [$r('app.color.page_gradient_end'), 1.0]]
    })
  }
}