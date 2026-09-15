@Component
export struct InputBar {
  @Link text: string
  @Prop loading: boolean = false
  @Prop canSend: boolean = false
  @Prop showAddMenu: boolean = false

  onSend: () => void = () => {}
  onToggleAddMenu: () => void = () => {}
  onVoice: () => void = () => {}
  onCamera: () => void = () => {}
  onAlbum: () => void = () => {}
  onFile: () => void = () => {}

  build() {
    Column() {
      Column() {
        TextArea({ text: $$this.text, placeholder: '给 AI 发消息...' })
          .width('100%')
          .constraintSize({ minHeight: 90, maxHeight: 180 })
          .backgroundColor(Color.Transparent)
          .padding({ left: 16, right: 16, top: 12, bottom: 0 })
          .fontSize(15)
          .enabled(!this.loading)

        Row({ space: 8 }) {
          // 加号
          Button() { Text('+').fontSize(20).fontColor(Color.Black) }
          .width(30).height(30).borderRadius(15)
          .backgroundColor(Color.Transparent)
          .border({ width: 1.2, color: Color.Black })
          .onClick(() => this.onToggleAddMenu())

          // 语音
          Button() {
            Image($r('app.media.icon_mic')).width(16).height(16).objectFit(ImageFit.Contain)
          }
          .width(30).height(30).borderRadius(15)
          .backgroundColor(Color.Transparent)
          .border({ width: 1.2, color: '#333' })
          .onClick(() => this.onVoice())

          // 发送
          Button() {
            if (this.loading) {
              LoadingProgress().width(16).height(16).color(Color.White)
            } else {
              Text('↑').fontSize(17).fontColor(Color.White).fontWeight(FontWeight.Bold)
            }
          }
          .width(30).height(30).borderRadius(15)
          .backgroundColor(this.canSend && !this.loading ? '#4D6BFE' : '#c8d6e5')
          .onClick(() => this.onSend())
        }
        .width('100%').padding({ left: 12, right: 12, top: 4, bottom: 8 })
        .justifyContent(FlexAlign.End)
      }
      .width('100%').backgroundColor('#f5f5f5').borderRadius(20)

      if (this.showAddMenu) {
        Row() {
          Column() {
            Image($r('app.media.icon_camera')).width(26).height(26)
            Text('拍照').fontSize(12).fontColor('#333').margin({ top: 6 })
          }.layoutWeight(1).padding({ top: 16, bottom: 16 })
          .onClick(() => this.onCamera())

          Column() {
            Image($r('app.media.icon_album')).width(26).height(26)
            Text('相册').fontSize(12).fontColor('#333').margin({ top: 6 })
          }.layoutWeight(1).padding({ top: 16, bottom: 16 })
          .onClick(() => this.onAlbum())

          Column() {
            Image($r('app.media.icon_file')).width(26).height(26)
            Text('文件').fontSize(12).fontColor('#333').margin({ top: 6 })
          }.layoutWeight(1).padding({ top: 16, bottom: 16 })
          .onClick(() => this.onFile())
        }
        .width('100%').backgroundColor('#ffffff').borderRadius(12)
        .border({ width: 1, color: '#f0f0f0' }).margin({ top: 8 })
      }
    }
    .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 12 })
    .backgroundColor(Color.White).border({ width: { top: 1 }, color: '#eee' })
  }
}