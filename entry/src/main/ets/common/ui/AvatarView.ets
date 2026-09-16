@Component
export struct AvatarView {
  @Prop label: string = '你'
  @Prop bgColor: string = '#e3f2fd'
  @Prop textColor: string = '#1976d2'
  @Prop avatarSize: number = 32

  build() {
    Text(this.label)
      .width(this.avatarSize)
      .height(this.avatarSize)
      .borderRadius(this.avatarSize / 2)
      .backgroundColor(this.bgColor)
      .fontColor(this.textColor)
      .fontSize(this.avatarSize * 0.45)
      .fontWeight(FontWeight.Bold)
      .textAlign(TextAlign.Center)
  }
}