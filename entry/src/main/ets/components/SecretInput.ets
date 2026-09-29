@Component
export struct SecretInput {
  @Link value: string;
  onGenerate: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      TextInput({ text: this.value })
        .layoutWeight(1)
        .type(InputType.Password)
        .onChange((val: string) => {
          this.value = val;
        })
      Button('生成')
        .fontSize(14)
        .onClick(() => this.onGenerate())
    }
    .width('100%')
  }
}
