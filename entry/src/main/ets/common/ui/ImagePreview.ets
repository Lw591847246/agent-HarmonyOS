@Component
export struct ImagePreview {
  @Prop url: string
  onClose: () => void = () => {}

  @State private imgScale: number = 1
  @State private offsetX: number = 0
  @State private offsetY: number = 0

  // baseScale 不是内置属性，可保留；为统一也建议改名
  private baseImgScale: number = 1
  private startX: number = 0
  private startY: number = 0

  aboutToAppear() {
    this.imgScale = 1
    this.baseImgScale = 1
    this.offsetX = 0
    this.offsetY = 0
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.92)')

      Image(this.url)
        .objectFit(ImageFit.Contain)
        .width('100%')
        .height('100%')
        // ✅ 使用改名后的状态
        .scale({ x: this.imgScale, y: this.imgScale })
        .translate({ x: this.offsetX, y: this.offsetY })
        .gesture(
          GestureGroup(
            GestureMode.Parallel,
            // ===== 双击：放大 / 恢复 =====
            TapGesture({ count: 2 })
              .onAction(() => {
                if (this.imgScale > 1.01) {
                  animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
                    this.imgScale = 1
                    this.offsetX = 0
                    this.offsetY = 0
                  })
                  this.baseImgScale = 1
                } else {
                  animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
                    this.imgScale = 2
                  })
                  this.baseImgScale = 2
                }
              }),

            // ===== 双指缩放 =====
            PinchGesture({ fingers: 2 })
              .onActionStart(() => {
                this.baseImgScale = this.imgScale
              })
              .onActionUpdate((event: GestureEvent) => {
                let s = this.baseImgScale * event.scale
                if (s < 1) s = 1
                if (s > 6) s = 6
                this.imgScale = s
              })
              .onActionEnd(() => {
                this.baseImgScale = this.imgScale
              }),

            // ===== 缩放后单指拖动 =====
            PanGesture({ fingers: 1, distance: 10 })
              .onActionStart(() => {
                this.startX = this.offsetX
                this.startY = this.offsetY
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.imgScale > 1) {
                  this.offsetX = this.startX + event.offsetX
                  this.offsetY = this.startY + event.offsetY
                }
              })
          )
        )

      Text('✕')
        .fontSize(20)
        .fontColor(Color.White)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .borderRadius(20)
        .backgroundColor('rgba(255,255,255,0.15)')
        .margin({ top: 40, right: 16 })
        .onClick(() => this.onClose())
    }
    .width('100%')
    .height('100%')
    .zIndex(999)
  }
}