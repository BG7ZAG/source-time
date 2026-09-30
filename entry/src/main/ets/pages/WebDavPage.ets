import { router, promptAction } from '@kit.ArkUI';
import { WebDavService } from '../service/WebDavService';
import { SyncService } from '../service/SyncService';
import { SettingsService } from '../service/SettingsService';
import { WebDavConfig } from '../model/WebDavConfig';
import { SyncStatus } from '../model/SyncModel';
import { Result } from '../types/Result';
import { DEFAULT_WEBDAV_DIRECTORY } from '../constants/AppConstants';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

@Entry
@Component
struct WebDavPage {
  @State baseUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State remotePath: string = DEFAULT_WEBDAV_DIRECTORY;
  @State webDavEnabled: boolean = false;
  @State autoPush: boolean = false;
  @State autoPullOnStart: boolean = false;
  @State testing: boolean = false;
  @State saving: boolean = false;
  @State pushing: boolean = false;
  @State pulling: boolean = false;
  @State syncStatus: SyncStatus = SyncStatus.IDLE;
  @State lastSyncAt: number = 0;
  @State syncMessage: string = '';

  private webDavService: WebDavService = new WebDavService();
  private settingsService: SettingsService = new SettingsService();
  private encryptionSecret: string = '';

  aboutToAppear(): void {
    const secret: string | undefined = AppStorage.get<string>(SECRET_STORAGE_KEY);
    if (secret !== undefined && secret.length > 0) {
      this.encryptionSecret = secret;
    }
    this.loadConfig();
  }

  private loadConfig(): void {
    this.settingsService.loadWebDavConfig(this.encryptionSecret).then((config: WebDavConfig) => {
      this.baseUrl = config.baseUrl;
      this.username = config.username;
      this.password = config.password;
      this.remotePath = config.remotePath.length > 0 ? config.remotePath : DEFAULT_WEBDAV_DIRECTORY;
      this.webDavEnabled = config.enabled;
      this.autoPush = config.autoPush;
      this.autoPullOnStart = config.autoPullOnStart;
    });
    const settings = this.settingsService.getSettings();
    this.lastSyncAt = settings.lastSyncAt !== undefined ? settings.lastSyncAt : 0;
    const syncState = SyncService.getInstance().getState();
    this.syncStatus = syncState.status;
    this.syncMessage = syncState.message !== undefined ? syncState.message : '';
  }

  private buildConfig(): WebDavConfig {
    return {
      enabled: this.webDavEnabled,
      baseUrl: this.baseUrl,
      username: this.username,
      password: this.password,
      remotePath: this.remotePath,
      autoPush: this.autoPush,
      autoPullOnStart: this.autoPullOnStart
    };
  }

  private onSave(): void {
    this.saving = true;
    const config: WebDavConfig = this.buildConfig();
    this.settingsService.saveWebDavConfig(config, this.encryptionSecret).then((result: Result<void>) => {
      this.saving = false;
      if (result.success) {
        SyncService.getInstance().configure(config, this.encryptionSecret);
        promptAction.showToast({ message: '保存成功' });
      } else {
        const message: string = result.error !== undefined ? result.error.message : '保存失败';
        promptAction.showToast({ message: message });
      }
    });
  }

  private onTest(): void {
    this.testing = true;
    this.webDavService.testConnection(this.buildConfig()).then((result: Result<void>) => {
      this.testing = false;
      const message: string = result.success ? '连接成功'
        : (result.error !== undefined ? result.error.message : '连接失败');
      promptAction.showToast({ message: message });
    });
  }

  private onPush(): void {
    this.pushing = true;
    SyncService.getInstance().push().then((result: Result<void>) => {
      this.pushing = false;
      const state = SyncService.getInstance().getState();
      this.syncStatus = state.status;
      this.syncMessage = state.message !== undefined ? state.message : '';
      this.lastSyncAt = state.lastSyncAt !== undefined ? state.lastSyncAt : 0;
      const message: string = result.success ? '推送成功'
        : (result.error !== undefined ? result.error.message : '推送失败');
      promptAction.showToast({ message: message });
    });
  }

  private onPull(): void {
    this.pulling = true;
    SyncService.getInstance().pull().then((result: Result<void>) => {
      this.pulling = false;
      const state = SyncService.getInstance().getState();
      this.syncStatus = state.status;
      this.syncMessage = state.message !== undefined ? state.message : '';
      this.lastSyncAt = state.lastSyncAt !== undefined ? state.lastSyncAt : 0;
      const message: string = result.success ? '拉取成功'
        : (result.error !== undefined ? result.error.message : '拉取失败');
      promptAction.showToast({ message: message });
    });
  }

  private formatLastSyncAt(): string {
    if (this.lastSyncAt === 0) {
      return '从未同步';
    }
    const date: Date = new Date(this.lastSyncAt);
    const year: number = date.getFullYear();
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    const hour: number = date.getHours();
    const minute: number = date.getMinutes();
    return `${year}-${month < 10 ? '0' + month : month}-${day < 10 ? '0' + day : day} ${hour < 10 ? '0' + hour : hour}:${minute < 10 ? '0' + minute : minute}`;
  }

  private formatSyncStatus(): string {
    switch (this.syncStatus) {
      case SyncStatus.IDLE:
        return '空闲';
      case SyncStatus.PUSHING:
        return '推送中';
      case SyncStatus.PULLING:
        return '拉取中';
      case SyncStatus.SUCCESS:
        return '成功';
      case SyncStatus.FAILED:
        return '失败';
      default:
        return '未知';
    }
  }

  @Builder
  header() {
    Row() {
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

      Blank()

      Text('WebDAV 同步')
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
  toggleRow(label: string, isOn: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange(onChange)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        this.header()

        Column({ space: 0 }) {
          this.toggleRow('启用 WebDAV', this.webDavEnabled, (value: boolean) => {
            this.webDavEnabled = value;
          })
          Divider().color($r('app.color.divider')).width('100%')
          this.toggleRow('自动推送（增删后自动上传）', this.autoPush, (value: boolean) => {
            this.autoPush = value;
          })
          Divider().color($r('app.color.divider')).width('100%')
          this.toggleRow('启动时自动拉取', this.autoPullOnStart, (value: boolean) => {
            this.autoPullOnStart = value;
          })
        }
        .width('100%')
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
        .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
        .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
        .margin({ left: 16, right: 16 })

        Column({ space: 12 }) {
          TextInput({ placeholder: '服务器地址（https://example.com/dav/）', text: this.baseUrl })
            .width('100%')
            .borderRadius(12)
            .onChange((value: string) => {
              this.baseUrl = value;
            })

          TextInput({ placeholder: '用户名', text: this.username })
            .width('100%')
            .borderRadius(12)
            .onChange((value: string) => {
              this.username = value;
            })

          TextInput({ placeholder: '密码', text: this.password })
            .type(InputType.Password)
            .width('100%')
            .borderRadius(12)
            .onChange((value: string) => {
              this.password = value;
            })

          TextInput({ placeholder: '同步目录（/SourceTime/）', text: this.remotePath })
            .width('100%')
            .borderRadius(12)
            .onChange((value: string) => {
              this.remotePath = value;
            })
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
        .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
        .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
        .margin({ left: 16, right: 16 })

        Row({ space: 12 }) {
          Button(this.testing ? '测试中...' : '测试连接')
            .layoutWeight(1)
            .borderRadius(12)
            .backgroundColor($r('app.color.brand_container'))
            .fontColor($r('app.color.brand_on_container'))
            .enabled(!this.testing && !this.saving)
            .onClick(() => this.onTest())

          Button(this.saving ? '保存中...' : '保存配置')
            .layoutWeight(1)
            .borderRadius(12)
            .backgroundColor($r('app.color.brand'))
            .fontColor($r('app.color.fab_foreground'))
            .enabled(!this.testing && !this.saving)
            .onClick(() => this.onSave())
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        Column({ space: 4 }) {
          Row() {
            Text('同步状态')
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text(this.formatSyncStatus())
              .fontSize(16)
              .fontColor(this.syncStatus === SyncStatus.FAILED ? $r('app.color.danger')
                : this.syncStatus === SyncStatus.SUCCESS ? $r('app.color.success')
                : $r('app.color.text_secondary'))
          }
          .width('100%')
          Row() {
            Text('上次同步')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
            Blank()
            Text(this.formatLastSyncAt())
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          if (this.syncMessage.length > 0) {
            Text(this.syncMessage)
              .fontSize(12)
              .fontColor($r('app.color.danger'))
              .width('100%')
          }
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
        .border({ width: 0.5, color: $r('app.color.card_border'), style: BorderStyle.Solid })
        .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
        .margin({ left: 16, right: 16 })

        Row({ space: 12 }) {
          Button(this.pushing ? '推送中...' : '手动推送')
            .layoutWeight(1)
            .borderRadius(12)
            .backgroundColor($r('app.color.brand_container'))
            .fontColor($r('app.color.brand_on_container'))
            .enabled(!this.pushing && !this.pulling && this.webDavEnabled)
            .onClick(() => this.onPush())

          Button(this.pulling ? '拉取中...' : '手动拉取')
            .layoutWeight(1)
            .borderRadius(12)
            .backgroundColor($r('app.color.brand_container'))
            .fontColor($r('app.color.brand_on_container'))
            .enabled(!this.pushing && !this.pulling && this.webDavEnabled)
            .onClick(() => this.onPull())
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
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
