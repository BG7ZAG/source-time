@Component
export struct EmptyState {
  @Prop message: string = '暂无验证码';

  build() {
    Column({ space: 8 }) {
      Text('＋')
        .fontSize(40)
        .fontColor($r('app.color.text_secondary'))
      Text(this.message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
  }
}
