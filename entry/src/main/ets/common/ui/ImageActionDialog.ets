/**
 * 选图后的处理选择弹窗
 * 左：编辑后上传（主按钮）
 * 右：直接使用（次要按钮）
 */
@CustomDialog
export struct ImageActionDialog {
  controller?: CustomDialogController
  fileName: string = ''
  onEdit: () => void = () => {}
  onUse: () => void = () => {}

  build() {
    Column({ space: 20 }) {
      // 标题区
      Column({ space: 6 }) {
        Text('图片处理')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#222')
        Text(this.fileName)
          .fontSize(12)
          .fontColor('#999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // ⭐ 两个圆角矩形按钮，同一行两列
      Row({ space: 12 }) {
        // 左：编辑后上传（主色）
        Button('编辑后上传')
          .layoutWeight(1)
          .height(46)
          .borderRadius(12)
          .backgroundColor('#4a90e2')
          .fontColor(Color.White)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.controller?.close()
            this.onEdit()
          })

        // 右：直接使用（次要）
        Button('直接使用')
          .layoutWeight(1)
          .height(46)
          .borderRadius(12)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.controller?.close()
            this.onUse()
          })
      }
      .width('100%')
    }
    .width('78%')
    .padding({ left: 20, right: 20, top: 24, bottom: 22 })
    .backgroundColor(Color.White)
    .borderRadius(18)
  }
}