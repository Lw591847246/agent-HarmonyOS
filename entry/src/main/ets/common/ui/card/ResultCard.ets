import { ChatCard } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'
import { ServiceRouter } from '../../../common/network/ServiceRouter'
import { Logger } from '../../../common/logger/Logger'
import { DownloadUtil } from '../../../common/utils/DownloadUtil'
import { fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

@Component
export struct ResultCard {
  @Prop card: ChatCard
  onPlay: (url: string) => void = (url: string) => {}

  private videoController: VideoController = new VideoController()
  @State private isSaving: boolean = false

  build() {
    Column({ space: CardStyles.GAP }) {
      // 标题
      Text(this.card.title)
        .fontSize(CardStyles.FONT_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(CardStyles.TEXT_PRIMARY)
        .width('100%')

      if (this.card.description) {
        Text(this.card.description)
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_HINT)
          .width('100%')
      }

      // 内嵌视频播放器
      Video({
        src: this.getFullVideoUrl(),
        currentProgressRate: 1.0,
        controller: this.videoController
      })
        .width('100%')
        .height(220)
        .controls(true)
        .autoPlay(false)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#000000')
        .borderRadius(CardStyles.RADIUS_ITEM)
        .onStart(() => {
          Logger.i('[ResultCard] video onStart')
        })
        .onFinish(() => {
          Logger.i('[ResultCard] video onFinish')
        })
        .onError(() => {
          Logger.e('[ResultCard] video onError')
        })

      // 底部按钮：保存 + 分享
      Row({ space: 8 }) {
        Button('保存到本地')
          .fontSize(CardStyles.FONT_BODY)
          .fontColor(CardStyles.PRIMARY)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: CardStyles.PRIMARY })
          .borderRadius(CardStyles.RADIUS_BTN)
          .layoutWeight(1)
          .height(36)
          .enabled(!this.isSaving)
          .onClick(() => this.saveVideo())

        Button('分享')
          .fontSize(CardStyles.FONT_BODY)
          .fontColor(CardStyles.TEXT_WHITE)
          .backgroundColor(CardStyles.PRIMARY)
          .borderRadius(CardStyles.RADIUS_BTN)
          .layoutWeight(1)
          .height(36)
          .enabled(!this.isSaving)
          .onClick(() => this.shareVideo())
      }
      .width('100%')
    }
    .padding(CardStyles.PADDING_CARD)
    .backgroundColor(CardStyles.BG_CARD)
    .borderRadius(CardStyles.RADIUS_CARD)
    .border({ width: 1, color: CardStyles.BORDER })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ============================================================
  // URL 处理
  // ============================================================

  /** 完整 URL（给 Video 组件和 systemShare 用） */
  private getFullVideoUrl(): string {
    const rel = this.getRelativeUrl()
    if (rel.length === 0) return ''
    if (rel.startsWith('http://') || rel.startsWith('https://')) {
      return rel
    }
    const base = ServiceRouter.getBaseUrl('agent')
    return base + rel
  }

  /** 相对 URL（给 DownloadUtil 用） */
  private getRelativeUrl(): string {
    if (!this.card.extra || !this.card.extra.video_url) return ''
    return this.card.extra.video_url
  }

  // ============================================================
  // 保存到本地
  // ============================================================

  private async saveVideo(): Promise<void> {
    if (this.isSaving) return
    const rel = this.getRelativeUrl()
    if (rel.length === 0) {
      promptAction.openToast({ message: '视频地址为空' })
      return
    }

    this.isSaving = true
    promptAction.openToast({ message: '正在准备视频…' })

    try {
      const filename = `video_${Date.now()}.mp4`
      const saved = await DownloadUtil.downloadAndSave(rel, filename)
      if (saved) {
        promptAction.openToast({ message: '已保存到本地' })
      }
      // 用户取消：静默
    } catch (e) {
      promptAction.openToast({ message: `保存失败: ${(e as Error).message}` })
    } finally {
      this.isSaving = false
    }
  }

  // ============================================================
  // 分享
  // ============================================================

  private async shareVideo(): Promise<void> {
    if (this.isSaving) return
    const rel = this.getRelativeUrl()
    if (rel.length === 0) {
      promptAction.openToast({ message: '视频地址为空' })
      return
    }

    this.isSaving = true
    promptAction.openToast({ message: '正在准备分享…' })

    try {
      // 1. 下载到沙箱
      const filename = `share_${Date.now()}.mp4`
      const sandboxPath = await DownloadUtil.downloadToSandbox(rel, filename)

      // 2. 沙箱路径 → uri
      const uri = fileUri.getUriFromPath(sandboxPath)
      const ctx = getContext(this) as common.UIAbilityContext

      // 3. 调系统分享
      const shareData = new systemShare.SharedData({
        utd: 'general.video',
        uri: uri
      })
      const controller = new systemShare.ShareController(shareData)
      await controller.show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      })

      // 4. 分享完成后清理沙箱文件（可选）
      // 不清理，让系统分享器使用完自动释放
    } catch (e) {
      promptAction.openToast({ message: `分享失败: ${(e as Error).message}` })
    } finally {
      this.isSaving = false
    }
  }
}