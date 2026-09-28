import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import {
  ImageEditorParams,
  ImageEditorResult,
  IMAGE_EDITOR_DONE_EVENT
} from './models/ImageEditorParams'
import { ImageEditorViewModel } from './ImageEditorViewModel'
import { ImageEditorUseCase } from './ImageEditorUseCase'
import { CropOverlay } from './CropOverlay'
import { Logger } from '../../common/logger/Logger'

/**
 * 图片编辑器页面
 * 接收 ImageEditorParams；完成后通过 EventHub 发回 ImageEditorResult
 */
@Component
export struct ImageEditorPage {
  @Consume('navStack') navStack: NavPathStack
  params: ImageEditorParams = { uri: '', name: '' }

  @State vm: ImageEditorViewModel = new ImageEditorViewModel()
  @State loadError: string = ''
  @State loadTip: string = '正在加载图片…'

  // 图片 / 容器尺寸谁先到齐谁触发 layoutImage
  private _imgW: number = 0
  private _imgH: number = 0
  private _containerW: number = 0
  private _containerH: number = 0

  aboutToAppear(): void {
    this.prepare()
  }

  private async prepare(): Promise<void> {
    try {
      const size = await ImageEditorUseCase.readImageSize(this.params.uri)
      this._imgW = size.width
      this._imgH = size.height
      this.loadTip = ''
      this.tryLayout()
    } catch (e) {
      this.loadError = (e as Error).message
      Logger.e('[ImageEditorPage] 读取图片失败: ' + this.loadError)
    }
  }

  private onContainerAreaChange(newArea: Area): void {
    this._containerW = newArea.width as number
    this._containerH = newArea.height as number
    this.tryLayout()
  }

  private tryLayout(): void {
    if (this._imgW > 0 && this._imgH > 0 && this._containerW > 0 && this._containerH > 0) {
      this.vm.layoutImage(this._imgW, this._imgH, this._containerW, this._containerH)
    }
  }

  private async onConfirm(): Promise<void> {
    if (this.vm.busy) return
    if (!this.vm.ready) {
      promptAction.openToast({ message: '图片尚未加载完成' })
      return
    }
    this.vm.busy = true
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      const outDir = ctx.cacheDir
      const r = this.vm.toSourceRect()

      const result: ImageEditorResult = await ImageEditorUseCase.cropAndSave(
        this.params.uri, this.params.name, outDir,
        r.x, r.y, r.w, r.h
      )

      // ⭐ 通过 EventHub 回传给 ChatPage
      getContext(this).eventHub.emit(IMAGE_EDITOR_DONE_EVENT, result)
      this.navStack.pop()
    } catch (e) {
      promptAction.openToast({ message: '裁剪失败: ' + (e as Error).message })
      Logger.e('[ImageEditorPage] cropAndSave 失败: ' + (e as Error).message)
    } finally {
      this.vm.busy = false
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 顶栏
        Row() {
          Text('取消')
            .fontSize(16).fontColor(Color.White).padding(14)
            .onClick(() => this.navStack.pop())
          Blank()
          Text('裁剪').fontSize(17).fontColor(Color.White).fontWeight(FontWeight.Medium)
          Blank()
          Text(this.vm.busy ? '保存中…' : '完成')
            .fontSize(16)
            .fontColor(this.vm.busy ? '#888' : '#4a90e2')
            .padding(14)
            .onClick(() => this.onConfirm())
        }
        .width('100%').height(56).backgroundColor('#111')

        // 图片 + 裁剪层
        Stack({ alignContent: Alignment.Center }) {
          if (this.loadError.length > 0) {
            Text('加载失败：' + this.loadError).fontColor('#fff').fontSize(14)
          } else {
            Image(this.params.uri)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .interpolation(ImageInterpolation.High)
          }

          if (this.vm.ready) {
            CropOverlay({ vm: this.vm })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#000')
        .onAreaChange((_, newArea: Area) => this.onContainerAreaChange(newArea))

        // 底栏
        Row() {
          Text('重置')
            .fontSize(15).fontColor(Color.White).padding(12)
            .onClick(() => this.vm.resetCrop())
        }
        .width('100%').height(56).backgroundColor('#111')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%').height('100%').backgroundColor('#111')
    }
    .hideTitleBar(true)
  }
}