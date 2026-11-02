import { SyncService } from '../service/SyncService';
import { SettingsService } from '../service/SettingsService';
import { WebDavConfig } from '../model/WebDavConfig';
import { RemoteBackup } from '../model/RemoteBackup';
import { Result } from '../types/Result';
import { UiText } from '../utils/UiText';
import { DEFAULT_WEBDAV_DIRECTORY } from '../constants/AppConstants';

const SECRET_STORAGE_KEY: string = 'encryptionSecret';

/**
 * 手表端「从 WebDAV 拉取」弹窗。
 *
 * 手表没有设置入口，也没有空间放完整的 WebDavPage（838 行），
 * 这里只保留最小闭环：服务器地址 + 用户名 + 密码 → 拉取云端最新备份。
 * 远程目录沿用默认 /SourceTime/（与手机端默认值一致）。
 */
@CustomDialog
export struct WatchSyncDialog {
  controller?: CustomDialogController;
  onDone: () => void = () => {};
  onCancel: () => void = () => {};

  @State baseUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State status: string = '';
  @State statusIsError: boolean = false;
  @State busy: boolean = false;

  private secret: string = '';
  private settingsService: SettingsService = new SettingsService();

  aboutToAppear(): void {
    this.secret = AppStorage.get<string>(SECRET_STORAGE_KEY) ?? '';
    this.settingsService.loadWebDavConfig(this.secret).then((config: WebDavConfig) => {
      this.baseUrl = config.baseUrl;
      this.username = config.username;
      this.password = config.password;
    });
  }

  private messageOf(message: ResourceStr | undefined, fallback: ResourceStr): string {
    const value: ResourceStr = message !== undefined ? message : fallback;
    return typeof value === 'string' ? value : UiText.of(value);
  }

  private pull(): void {
    if (this.busy) {
      return;
    }
    const url: string = this.baseUrl.trim();
    if (url.length === 0) {
      this.status = this.messageOf(undefined, $r('app.string.watch_sync_url_required'));
      this.statusIsError = true;
      return;
    }
    // 明文 http 会连同 Basic 凭据一起裸奔，手表端直接拒绝，避免依赖底层错误映射
    if (/^http:\/\//i.test(url)) {
      this.status = this.messageOf(undefined, $r('app.string.watch_sync_https_required'));
      this.statusIsError = true;
      return;
    }
    this.busy = true;
    this.statusIsError = false;
    this.status = this.messageOf(undefined, $r('app.string.watch_sync_connecting'));

    const config: WebDavConfig = {
      enabled: true,
      baseUrl: url,
      username: this.username.trim(),
      password: this.password,
      remotePath: DEFAULT_WEBDAV_DIRECTORY,
      autoPush: false,
      autoPullOnStart: true,
      cleanOldBackups: true,
      allowInsecure: false
    };

    this.settingsService.saveWebDavConfig(config, this.secret).then((saveResult: Result<void>) => {
      if (!saveResult.success) {
        this.busy = false;
        this.status = this.messageOf(saveResult.error !== undefined ? saveResult.error.message : undefined, $r('app.string.webdav_save_failed'));
        this.statusIsError = true;
        return;
      }
      SyncService.getInstance().configure(config, this.secret);
      SyncService.getInstance().listBackups().then((listResult: Result<RemoteBackup[]>) => {
        if (!listResult.success || listResult.data === undefined) {
          this.busy = false;
          this.status = this.messageOf(listResult.error !== undefined ? listResult.error.message : undefined, $r('app.string.watch_sync_failed'));
          this.statusIsError = true;
          return;
        }
        if (listResult.data.length === 0) {
          this.busy = false;
          this.status = this.messageOf(undefined, $r('app.string.watch_sync_no_backup'));
          this.statusIsError = true;
          return;
        }
        this.status = this.messageOf(undefined, $r('app.string.watch_sync_pulling'));
        SyncService.getInstance().pullBackup(listResult.data[0].name).then((pullResult: Result<void>) => {
          this.busy = false;
          if (pullResult.success) {
            this.status = this.messageOf(undefined, $r('app.string.watch_sync_done'));
            this.statusIsError = false;
            this.onDone();
          } else {
            this.status = this.messageOf(pullResult.error !== undefined ? pullResult.error.message : undefined, $r('app.string.watch_sync_failed'));
            this.statusIsError = true;
          }
        });
      });
    });
  }

  build() {
    Column({ space: 4 }) {
      Text($r('app.string.watch_sync_title'))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)

      Scroll() {
        Column({ space: 4 }) {
          Text($r('app.string.watch_sync_desc'))
            .fontSize(10)
            .lineHeight(14)
            .fontColor('#B3FFFFFF')
            .textAlign(TextAlign.Center)
            .maxLines(1)

          TextInput({ text: this.baseUrl, placeholder: $r('app.string.watch_sync_url_hint') })
            .width('100%')
            .height(30)
            .fontSize(10.5)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .borderRadius(10)
            .padding({ left: 8, right: 8, top: 0, bottom: 0 })
            .backgroundColor($r('app.color.pill_background'))
            .onChange((value: string) => {
              this.baseUrl = value;
            })

          TextInput({ text: this.username, placeholder: $r('app.string.watch_sync_user_hint') })
            .width('100%')
            .height(30)
            .fontSize(10.5)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .borderRadius(10)
            .padding({ left: 8, right: 8, top: 0, bottom: 0 })
            .backgroundColor($r('app.color.pill_background'))
            .onChange((value: string) => {
              this.username = value;
            })

          TextInput({ text: this.password, placeholder: $r('app.string.watch_sync_password_hint') })
            .width('100%')
            .height(30)
            .fontSize(10.5)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .type(InputType.Password)
            .borderRadius(10)
            .padding({ left: 8, right: 8, top: 0, bottom: 0 })
            .backgroundColor($r('app.color.pill_background'))
            .onChange((value: string) => {
              this.password = value;
            })

          if (this.status.length > 0) {
            Text(this.status)
              .fontSize(10)
              .lineHeight(14)
              .fontColor(this.statusIsError ? $r('app.color.danger') : $r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .maxLines(2)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

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

        Button($r('app.string.watch_sync_pull'))
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
          .onClick(() => this.pull())
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: 180, minHeight: 210, maxHeight: 220 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(20)
  }
}
