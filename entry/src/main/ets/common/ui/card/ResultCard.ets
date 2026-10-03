import { ChatCard } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'
import { ServiceRouter } from '../../../common/network/ServiceRouter'
import { Logger } from '../../../common/logger/Logger'

@Component
export struct ResultCard {
  @Prop card: ChatCard
  onPlay: (url: string) => void = (url: string) => {}   // 保留，用于外部浏览器兜底

  private videoController: VideoController = new VideoController()
  @State private isPlaying: boolean = false

  build() {
    Column({ space: CardStyles.GAP }) {
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

      // ⭐ 内嵌视频播放器
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
          this.isPlaying = true
        })
        .onPause(() => {
          Logger.i('[ResultCard] video onPause')
          this.isPlaying = false
        })
        .onFinish(() => {
          Logger.i('[ResultCard] video onFinish')
          this.isPlaying = false
        })
        .onError(() => {
          Logger.e('[ResultCard] video onError')
        })
        .onPrepared((e) => {
          Logger.i(`[ResultCard] video prepared duration=${e.duration}`)
        })

      // 兜底按钮：内嵌播放失败时用系统播放器
      Button('用外部播放器打开')
        .fontSize(CardStyles.FONT_SMALL)
        .fontColor(CardStyles.TEXT_SECONDARY)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: CardStyles.BORDER })
        .borderRadius(CardStyles.RADIUS_BTN)
        .width('100%')
        .height(32)
        .onClick(() => {
          this.onPlay(this.getFullVideoUrl())
        })
    }
    .padding(CardStyles.PADDING_CARD)
    .backgroundColor(CardStyles.BG_CARD)
    .borderRadius(CardStyles.RADIUS_CARD)
    .border({ width: 1, color: CardStyles.BORDER })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private getFullVideoUrl(): string {
    if (!this.card.extra || !this.card.extra.video_url) return ''
    const path = this.card.extra.video_url
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path
    }
    const base = ServiceRouter.getBaseUrl('agent')
    return base + path
  }
}