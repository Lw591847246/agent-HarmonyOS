import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { util } from '@kit.ArkTS'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

@Component
export struct ImagePreview {
  @Prop url: string
  onClose: () => void = () => {
  }
  @State private imgScale: number = 1
  @State private offsetX: number = 0
  @State private offsetY: number = 0
  // ↓ 滑动关闭相关
  @State private panX: number = 0
  @State private panY: number = 0
  @State private bgOpacity: number = 1
  private baseImgScale: number = 1
  private startX: number = 0
  private startY: number = 0

  aboutToAppear() {
    this.imgScale = 1
    this.baseImgScale = 1
    this.offsetX = 0
    this.offsetY = 0
    this.panX = 0
    this.panY = 0
    this.bgOpacity = 1
  }

  // ============================================================
  // 图片字节读取
  // ============================================================
  private async getImageBytes(): Promise<ArrayBuffer> {
    if (!this.url) {
      throw new Error('图片为空')
    }

    if (this.url.startsWith('data:')) {
      const commaIdx = this.url.indexOf(',')
      if (commaIdx < 0) {
        throw new Error('无效的 data URI')
      }
      const base64Str = this.url.substring(commaIdx + 1)
      const helper = new util.Base64Helper()
      const bytes = helper.decodeSync(base64Str)
      return bytes.buffer as ArrayBuffer
    }

    const file = fs.openSync(this.url, fs.OpenMode.READ_ONLY)
    try {
      const stat = fs.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      return buf
    } finally {
      fs.closeSync(file)
    }
  }

  private async ensureShareablePath(): Promise<string> {
    if (this.url.startsWith('file://')) {
      return this.url.replace('file://', '')
    }
    const ctx = getContext(this) as common.UIAbilityContext
    const tempPath = `${ctx.cacheDir}/share_${Date.now()}.png`

    const bytes = await this.getImageBytes()
    const file = fs.openSync(
      tempPath,
      fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC
    )
    try {
      fs.writeSync(file.fd, bytes)
    } finally {
      fs.closeSync(file)
    }
    return tempPath
  }

  private async saveToLocal(): Promise<void> {
    try {
      const bytes = await this.getImageBytes()
      const saveOptions = new picker.DocumentSaveOptions()
      saveOptions.newFileNames = [`image_${Date.now()}.png`]
      saveOptions.fileSuffixChoices = ['.png']

      const docPicker = new picker.DocumentViewPicker()
      const uris = await docPicker.save(saveOptions)
      if (!uris || uris.length === 0) {
        return
      }

      const file = fs.openSync(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      try {
        fs.writeSync(file.fd, bytes)
      } finally {
        fs.closeSync(file)
      }
      promptAction.openToast({ message: '已保存到本地' })
    } catch (e) {
      promptAction.openToast({ message: '保存失败: ' + (e as Error).message })
    }
  }

  private async shareImage(): Promise<void> {
    try {
      const filePath = await this.ensureShareablePath()
      const uri = fileUri.getUriFromPath(filePath)
      const ctx = getContext(this) as common.UIAbilityContext

      const shareData = new systemShare.SharedData({
        utd: 'general.image',
        uri: uri
      })
      const controller = new systemShare.ShareController(shareData)
      await controller.show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      })
    } catch (e) {
      promptAction.openToast({ message: '分享失败: ' + (e as Error).message })
    }
  }

  // ============================================================
  // 滑动松手后的处理
  // ============================================================
  private handlePanEnd(dx: number, dy: number): void {
    const isHorizontal = Math.abs(dx) > Math.abs(dy)
    const THRESHOLD = 100 // 位移阈值（vp）
    const VELOCITY_THRESHOLD = 1.0

    if (isHorizontal && Math.abs(dx) > THRESHOLD) {
      // 关闭：跟手方向飞出 + 淡出
      animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
        this.panX = dx > 0 ? 500 : -500
        this.bgOpacity = 0
      })
      setTimeout(() => this.onClose(), 180)
    } else {
      // 弹回
      animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
        this.panX = 0
        this.panY = 0
        this.bgOpacity = 1
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 黑背景（透明度跟随滑动）
      Column()
        .width('100%').height('100%')
        .backgroundColor(Color.Black)
        .opacity(this.bgOpacity)

      // 图片本体
      Image(this.url)
        .objectFit(ImageFit.Contain)
        .width('100%')
        .height('100%')
        .scale({ x: this.imgScale, y: this.imgScale })
        .translate({
          x: this.offsetX + this.panX,
          y: this.offsetY + this.panY
        })
        .gesture(
          GestureGroup(
            GestureMode.Parallel,
            // 双击：放大 / 复位
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
            // 双指缩放
            PinchGesture({ fingers: 2 })
              .onActionStart(() => {
                this.baseImgScale = this.imgScale
              })
              .onActionUpdate((e: GestureEvent) => {
                let s = this.baseImgScale * e.scale
                if (s < 1) {
                  s = 1
                }
                if (s > 6) {
                  s = 6
                }
                this.imgScale = s
              })
              .onActionEnd(() => {
                this.baseImgScale = this.imgScale
              }),
            // 单指拖动
            //   ① scale = 1 → 滑动关闭
            //   ② scale > 1 → 拖动查看
            PanGesture({ fingers: 1, distance: 8 })
              .onActionStart(() => {
                this.startX = this.offsetX
                this.startY = this.offsetY
                this.panX = 0
                this.panY = 0
              })
              .onActionUpdate((e: GestureEvent) => {
                if (this.imgScale > 1) {
                  // 拖动查看
                  this.offsetX = this.startX + e.offsetX
                  this.offsetY = this.startY + e.offsetY
                } else {
                  // 滑动关闭：图片跟手移动 + 背景变淡
                  this.panX = e.offsetX
                  this.panY = e.offsetY
                  const dist = Math.sqrt(e.offsetX * e.offsetX + e.offsetY * e.offsetY)
                  this.bgOpacity = Math.max(0.2, 1 - dist / 500)
                }
              })
              .onActionEnd((e: GestureEvent) => {
                if (this.imgScale > 1) {
                  return
                }
                this.handlePanEnd(e.offsetX, e.offsetY)
              })
          )
        )

      // 关闭按钮（右上角）
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

      // ============================================================
      // 底部操作栏：纯图标，居中
      // ============================================================
      Column() {
        Row({ space: 96 }) {
          this.SaveButton()
          this.ShareButton()
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 80 })
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
  }

  // ============================================================
  // 保存按钮
  // ============================================================
  @Builder
  SaveButton() {
    Row() {
      Image($r('app.media.ic_save'))
        .width(28)
        .height(28)
    }
    .width(64)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(32)
    .backgroundColor('rgba(255,255,255,0.10)')
    .onClick(() => this.saveToLocal())
  }

  @Builder
  ShareButton() {
    Row() {
      Image($r('app.media.ic_share'))
        .width(28)
        .height(28)
    }
    .width(64)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(32)
    .backgroundColor('rgba(255,255,255,0.10)')
    .onClick(() => this.shareImage())
  }
}