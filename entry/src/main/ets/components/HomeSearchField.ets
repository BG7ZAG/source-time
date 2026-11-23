/**
 * 首页搜索框。
 *
 * 单独成组件的原因：TextInput 的 text 只有走 `$$` 双向绑定才不会在页面刷新时
 * 把用户输入回滚（与 WebDavField 同一套处理）。`$$` 绑定在子组件里配合 @Link 使用，
 * 比直接写在页面 @Builder 中更稳定，也便于首页按关键词过滤时只刷新这一处状态。
 */
@Component
export struct HomeSearchField {
  @Link query: string;

  build() {
    Row({ space: 8 }) {
      Image($r('app.media.ic_search'))
        .width(17)
        .height(17)
        .fillColor($r('app.color.text_tertiary'))

      TextInput({ text: $$this.query, placeholder: $r('app.string.home_search_placeholder') })
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .placeholderFont({ size: 14 })
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .padding({ left: 0, right: 0 })
        .enterKeyType(EnterKeyType.Search)
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 12 })
    .borderRadius(22)
    .backgroundColor($r('app.color.field_background'))
    .border({ width: 1, color: $r('app.color.card_border'), style: BorderStyle.Solid })
  }
}