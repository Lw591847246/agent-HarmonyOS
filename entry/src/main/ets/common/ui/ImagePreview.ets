import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { util } from '@kit.ArkTS'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

@Component
export struct ImagePreview {
  @Prop url: string
  onClose: () => void = () => {}

  @State private imgScale: number = 1
  @State private offsetX: number = 0
  @State private offsetY: number = 0

  private baseImgScale: number = 1
  private startX: number = 0
  private startY: number = 0

  aboutToAppear() {
    this.imgScale = 1
    this.baseImgScale = 1
    this.offsetX = 0
    this.offsetY = 0
  }

  // ============================================================
  // 图片字节读取：兼容 data URI 和 file URI
  // ============================================================
  private async getImageBytes(): Promise<ArrayBuffer> {
    if (!this.url) throw new Error('图片为空')

    if (this.url.startsWith('data:')) {
      const commaIdx = this.url.indexOf(',')
      if (commaIdx < 0) throw new Error('无效的 data URI')
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

  // ============================================================
  // 确保有可分享的 file:// URI（分享 API 只认 file URI）
  // ============================================================
  private async ensureTempFile(): Promise<string> {
    if (this.url.startsWith('file://')) return this.url

    const ctx = getContext(this) as common.UIAbilityContext
    const tempPath = `${ctx.cacheDir}/preview_${Date.now()}.png`

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
    return `file://${tempPath}`
  }

  // ============================================================
  // 保存到本地（DocumentViewPicker，零权限）
  // ============================================================
  private async saveToLocal(): Promise<void> {
    try {
      const bytes = await this.getImageBytes()

      const saveOptions = new picker.DocumentSaveOptions()
      saveOptions.newFileNames = [`image_${Date.now()}.png`]
      saveOptions.fileSuffixChoices = ['.png']

      const docPicker = new picker.DocumentViewPicker()
      const uris = await docPicker.save(saveOptions)
      if (!uris || uris.length === 0) return

      const dstUri = uris[0]
      const file = fs.openSync(dstUri, fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
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

  // ============================================================
  // 系统分享
  // ============================================================
  private async shareImage(): Promise<void> {
    try {
      const fileUri = await this.ensureTempFile()
      const ctx = getContext(this) as common.UIAbilityContext

      const shareData = new systemShare.SharedData({
        utd: 'general.image',
        uri: fileUri
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

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 黑背景
      Column()
        .width('100%').height('100%')
        .backgroundColor(Color.Black)

      // 图片本体
      Image(this.url)
        .objectFit(ImageFit.Contain)
        .width('100%').height('100%')
        .scale({ x: this.imgScale, y: this.imgScale })
        .translate({ x: this.offsetX, y: this.offsetY })
        .gesture(
          GestureGroup(
            GestureMode.Parallel,
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
            PinchGesture({ fingers: 2 })
              .onActionStart(() => { this.baseImgScale = this.imgScale })
              .onActionUpdate((e: GestureEvent) => {
                let s = this.baseImgScale * e.scale
                if (s < 1) s = 1
                if (s > 6) s = 6
                this.imgScale = s
              })
              .onActionEnd(() => { this.baseImgScale = this.imgScale }),
            PanGesture({ fingers: 1, distance: 10 })
              .onActionStart(() => {
                this.startX = this.offsetX
                this.startY = this.offsetY
              })
              .onActionUpdate((e: GestureEvent) => {
                if (this.imgScale > 1) {
                  this.offsetX = this.startX + e.offsetX
                  this.offsetY = this.startY + e.offsetY
                }
              })
          )
        )

      // 关闭按钮（右上角）
      Text('✕')
        .fontSize(20).fontColor(Color.White)
        .width(40).height(40)
        .textAlign(TextAlign.Center)
        .borderRadius(20)
        .backgroundColor('rgba(255,255,255,0.15)')
        .margin({ top: 40, right: 16 })
        .onClick(() => this.onClose())

      // ============================================================
      // 底部操作栏（全屏 Column 靠底居中对齐，且不拦截图片手势）
      // ============================================================
      Column() {
        Row({ space: 64 }) {
          // ---- 保存 ----
          Column({ space: 6 }) {
            this.SaveIcon()
            Text('保存')
              .fontSize(12)
              .fontColor(Color.White)
          }
          .padding(8)
          .borderRadius(8)
          .onClick(() => this.saveToLocal())

          // ---- 分享 ----
          Column({ space: 6 }) {
            this.ShareIcon()
            Text('分享')
              .fontSize(12)
              .fontColor(Color.White)
          }
          .padding(8)
          .borderRadius(8)
          .onClick(() => this.shareImage())
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 60 })
      .hitTestBehavior(HitTestMode.None)   // 关键：空白不拦截，图片仍可双击/缩放
    }
    .width('100%')
    .height('100%')
  }

  // ============================================================
  // 保存图标：向下箭头 + 底部托盘（HarmonyOS 图库/下载风格）
  // ============================================================
  @Builder
  SaveIcon() {
    Shape() {
      // 竖线 + 箭头
      Path()
        .commands('M12 4 V15 M7 10 L12 15 L17 10')
        .stroke(Color.White)
        .strokeWidth(1.8)
        .fill(Color.Transparent)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
      // 底部托盘
      Path()
        .commands('M5 19 H19')
        .stroke(Color.White)
        .strokeWidth(1.8)
        .fill(Color.Transparent)
        .strokeLineCap(LineCapStyle.Round)
    }
    .viewPort({ x: 0, y: 0, width: 24, height: 24 })
    .width(24)
    .height(24)
  }

  // ============================================================
  // 分享图标：三点连线（微信/经典分享风格）
  // ============================================================
  @Builder
  ShareIcon() {
    Shape() {
      // 连线
      Path()
        .commands('M8 12 L16 7.5 M8 12 L16 16.5')
        .stroke(Color.White)
        .strokeWidth(1.8)
        .fill(Color.Transparent)
        .strokeLineCap(LineCapStyle.Round)
      // 三个圆点
      Path()
        .commands(
          'M8 12 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 ' +
            'M16 7.5 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 ' +
            'M16 16.5 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0'
        )
        .fill(Color.White)
    }
    .viewPort({ x: 0, y: 0, width: 24, height: 24 })
    .width(24)
    .height(24)
  }
}