import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { util } from '@kit.ArkTS'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { http } from '@kit.NetworkKit'

@Component
export struct ImagePreview {
  @Prop url: string
  onClose: () => void = () => {}

  // ============================================================
  // 缩放 / 拖动 状态
  // ============================================================
  @State private imgScale: number = 1
  @State private offsetX: number = 0
  @State private offsetY: number = 0
  @State private panX: number = 0
  @State private panY: number = 0
  @State private bgOpacity: number = 1

  // ============================================================
  // ⭐ 加载状态
  // ============================================================
  @State private imageSrc: string = ''        // Image 组件实际渲染源
  @State private isLoading: boolean = false   // 是否加载中
  @State private progress: number = 0         // 0-100
  private imageBytes: ArrayBuffer | null = null   // 缓存字节（供保存/分享复用）

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

    // ⭐ 启动带进度的加载
    this.loadImageWithProgress()
  }

  // ============================================================
  // ⭐ 带进度的图片加载（统一入口）
  // ============================================================
  private async loadImageWithProgress(): Promise<void> {
    // 情况 1：data URI，直接用
    if (this.url.startsWith('data:')) {
      this.imageSrc = this.url
      this.isLoading = false
      return
    }

    // 情况 2：本地文件
    if (this.url.startsWith('file://') || this.url.startsWith('/')) {
      try {
        const path = this.url.replace('file://', '')
        const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
        try {
          const stat = fs.statSync(file.fd)
          const buf = new ArrayBuffer(stat.size)
          fs.readSync(file.fd, buf)
          this.imageBytes = buf
          this.imageSrc = this.bytesToDataUri(buf)
        } finally {
          fs.closeSync(file)
        }
      } catch (e) {
        promptAction.openToast({ message: '读取失败: ' + (e as Error).message })
      }
      this.isLoading = false
      return
    }

    // 情况 3：HTTP / HTTPS
    this.isLoading = true
    this.progress = 0
    try {
      const bytes = await this.downloadWithProgress(this.url)
      this.imageBytes = bytes
      this.imageSrc = this.bytesToDataUri(bytes)
    } catch (e) {
      promptAction.openToast({ message: '加载失败: ' + (e as Error).message })
    } finally {
      this.isLoading = false
    }
  }

  // ⭐ 带进度的 HTTP 下载
  private downloadWithProgress(url: string): Promise<ArrayBuffer> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp()

      // 注册下载进度监听
      httpRequest.on('dataReceiveProgress', (data: http.DataReceiveProgressInfo) => {
        if (data.totalSize > 0) {
          this.progress = Math.floor(data.receiveSize / data.totalSize * 100)
        }
      })

      httpRequest.request(
        url,
        {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: 10000,
          readTimeout: 30000
        },
        (err: Error, data: http.HttpResponse) => {
          if (err) {
            httpRequest.destroy()
            reject(new Error('下载失败: ' + err.message))
            return
          }
          if (data.responseCode === 200 && data.result) {
            resolve(data.result as ArrayBuffer)
          } else {
            reject(new Error('HTTP ' + data.responseCode))
          }
          httpRequest.destroy()
        }
      )
    })
  }

  // ⭐ 字节 → data URI
  private bytesToDataUri(bytes: ArrayBuffer): string {
    const helper = new util.Base64Helper()
    const base64 = helper.encodeToStringSync(new Uint8Array(bytes))
    return `data:image/png;base64,${base64}`
  }

  // ============================================================
  // 图片字节读取（含缓存命中）
  // ============================================================
  private async getImageBytes(): Promise<ArrayBuffer> {
    if (!this.url) {
      throw new Error('图片为空')
    }

    // ⭐ 优先命中缓存
    if (this.imageBytes) {
      return this.imageBytes
    }

    // 情况 1：base64 data URI
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

    // 情况 2：HTTP/HTTPS
    if (this.url.startsWith('http://') || this.url.startsWith('https://')) {
      return await this.downloadImageFromHttp(this.url)
    }

    // 情况 3：本地文件
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

  // 无 UI 依赖的下载（供保存/分享 fallback）
  private downloadImageFromHttp(url: string): Promise<ArrayBuffer> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp()
      httpRequest.request(
        url,
        {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: 10000,
          readTimeout: 30000
        },
        (err: Error, data: http.HttpResponse) => {
          if (err) {
            httpRequest.destroy()
            reject(new Error('下载图片失败: ' + err.message))
            return
          }
          if (data.responseCode === 200 && data.result) {
            resolve(data.result as ArrayBuffer)
          } else {
            reject(new Error('下载图片失败，HTTP ' + data.responseCode))
          }
          httpRequest.destroy()
        }
      )
    })
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
    const THRESHOLD = 100
    const VELOCITY_THRESHOLD = 1.0

    if (isHorizontal && Math.abs(dx) > THRESHOLD) {
      animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
        this.panX = dx > 0 ? 500 : -500
        this.bgOpacity = 0
      })
      setTimeout(() => this.onClose(), 180)
    } else {
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

      // ⭐ 加载中：进度环
      if (this.isLoading) {
        Column({ space: 16 }) {
          Progress({ value: this.progress, total: 100, type: ProgressType.Ring })
            .width(80)
            .height(80)
            .color('#ffffff')
            .style({ strokeWidth: 6 })
          Text(`${this.progress}%`)
            .fontSize(16)
            .fontColor(Color.White)
          Text('加载中...')
            .fontSize(12)
            .fontColor('#aaaaaa')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // ⭐ 图片本体
        Image(this.imageSrc)
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
                  if (s < 1) s = 1
                  if (s > 6) s = 6
                  this.imgScale = s
                })
                .onActionEnd(() => {
                  this.baseImgScale = this.imgScale
                }),
              // 单指拖动
              PanGesture({ fingers: 1, distance: 8 })
                .onActionStart(() => {
                  this.startX = this.offsetX
                  this.startY = this.offsetY
                  this.panX = 0
                  this.panY = 0
                })
                .onActionUpdate((e: GestureEvent) => {
                  if (this.imgScale > 1) {
                    this.offsetX = this.startX + e.offsetX
                    this.offsetY = this.startY + e.offsetY
                  } else {
                    this.panX = e.offsetX
                    this.panY = e.offsetY
                    const dist = Math.sqrt(e.offsetX * e.offsetX + e.offsetY * e.offsetY)
                    this.bgOpacity = Math.max(0.2, 1 - dist / 500)
                  }
                })
                .onActionEnd((e: GestureEvent) => {
                  if (this.imgScale > 1) return
                  this.handlePanEnd(e.offsetX, e.offsetY)
                })
            )
          )
      }

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

      // 底部操作栏
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