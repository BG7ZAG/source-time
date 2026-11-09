/**
 * 手表端「同步口令」入口的操作面板。
 *
 * 手表屏幕放不下多个并列入口，这里用一层轻量菜单：
 * - 从手机同步：同账号可信设备直接推送配置，零输入；
 * - 手动配置 WebDAV：地址/账号/密码表单；
 * - 查看保护：开/关，开启后每次查看口令都要 PIN（复用应用锁遮罩）。
 */
@CustomDialog
export struct WatchSyncChoiceDialog {
  controller?: CustomDialogController;
  /** 联网同步开关；关闭时只保留「手动输入密钥」与「查看保护」两个本地操作。 */
  webDavEnabled: boolean = true;
  lockEnabled: boolean = false;
  onPhoneSync: () => void = () => {};
  onManual: () => void = () => {};
  /** 手动输入/粘贴手机上的密钥：分布式通道不可用时的兜底路径。 */
  onManualKey: () => void = () => {};
  onToggleLock: () => void = () => {};

  build() {
    Column({ space: 6 }) {
      Text(this.webDavEnabled
        ? $r('app.string.watch_sync_choice_title')
        : $r('app.string.watch_key_choice_title'))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)

      Text(this.webDavEnabled
        ? $r('app.string.watch_sync_choice_desc')
        : $r('app.string.watch_key_choice_desc'))
        .fontSize(10)
        .lineHeight(14)
        .fontColor('#B3FFFFFF')
        .textAlign(TextAlign.Center)
        .maxLines(2)

      // 备案完成前（webDavEnabled == false）不展示任何联网同步入口
      if (this.webDavEnabled) {
        Button($r('app.string.watch_sync_from_phone'))
          .width('100%')
          .height(36)
          .borderRadius(18)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .linearGradient({
            angle: 90,
            colors: [[$r('app.color.brand'), 0.0], [$r('app.color.brand_secondary'), 1.0]]
          })
          .fontColor($r('app.color.fab_foreground'))
          .onClick(() => this.onPhoneSync())

        Button($r('app.string.watch_sync_manual'))
          .width('100%')
          .height(32)
          .borderRadius(16)
          .fontSize(11)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onManual())
      }

      Row({ space: 6 }) {
        Button($r('app.string.watch_sync_manual_key'))
          .layoutWeight(1)
          .height(30)
          .borderRadius(15)
          .fontSize(10)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.onManualKey())

        Button(this.lockEnabled ? $r('app.string.watch_view_lock_on') : $r('app.string.watch_view_lock_off'))
          .layoutWeight(1)
          .height(30)
          .borderRadius(15)
          .fontSize(10)
          .backgroundColor($r('app.color.pill_background'))
          .fontColor(this.lockEnabled ? $r('app.color.brand') : $r('app.color.text_secondary'))
          .onClick(() => this.onToggleLock())
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxWidth: 180, minHeight: 180, maxHeight: 205 })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(20)
  }
}
