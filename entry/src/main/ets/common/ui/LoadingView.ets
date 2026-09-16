@Component
export struct LoadingView {
  @Prop text: string = '加载中...'

  build() {
    Row({ space: 8 }) {
      LoadingProgress().width(18).height(18).color('#999')
      Text(this.text).fontSize(13).fontColor('#999')
    }
    .padding(20)
    .justifyContent(FlexAlign.Center)
  }
}