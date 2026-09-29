@Component
export struct CountDown {
  @Prop remaining: number = 0;

  build() {
    Text(this.remaining.toString())
      .fontSize(14)
      .fontColor($r('app.color.text_secondary'))
  }
}
