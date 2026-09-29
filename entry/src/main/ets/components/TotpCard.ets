@Component
export struct TotpCard {
  @Prop issuer: string = '';
  @Prop account: string = '';
  @Prop code: string = '';
  @Prop remaining: number = 0;
  onCopy: () => void = () => {};
  onDelete: () => void = () => {};

  private formatCode(code: string): string {
    if (code.length === 6) {
      return code.substring(0, 3) + ' ' + code.substring(3);
    }
    if (code.length === 8) {
      return code.substring(0, 4) + ' ' + code.substring(4);
    }
    return code;
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.issuer)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.remaining.toString())
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Text(this.account)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Text(this.formatCode(this.code))
        .fontSize(32)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
    }
    .padding(16)
    .width('100%')
    .borderRadius(12)
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => this.onCopy())
    .gesture(LongPressGesture().onAction(() => this.onDelete()))
  }
}
