@Component
export struct PrivacyDialog {
  onAgree: () => void = () => {};
  onDecline: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('隐私政策')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
      Text('源时是一款本地优先的 TOTP 验证器，数据默认以加密形式保存在设备本地。')
        .fontSize(14)
      Row({ space: 12 }) {
        Button('不同意')
          .layoutWeight(1)
          .onClick(() => this.onDecline())
        Button('同意并继续')
          .layoutWeight(1)
          .onClick(() => this.onAgree())
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
  }
}
