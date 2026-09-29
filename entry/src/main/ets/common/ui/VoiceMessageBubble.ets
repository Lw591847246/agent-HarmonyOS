import { ChatMessage } from '../../domain/models/ChatMessage'

@Component
export struct VoiceMessageBubble {
  @Prop msg: ChatMessage
  @Prop isPlaying: boolean
  onPlay: () => void = () => {}
  onStop: () => void = () => {}

  build() {
    Row({ space: 8 }) {
      // 左侧波形（静态 + 播放时高亮）
      Row({ space: 3 }) {
        ForEach([10, 18, 26, 18, 14], (h: number, i: number) => {
          Column()
            .width(3)
            .height(h)
            .borderRadius(2)
            .backgroundColor(this.isPlaying ? '#4a90e2' : '#888')
        })
      }

      // 时长
      Text(`${this.msg.voiceDuration}''`)
        .fontSize(14)
        .fontColor(this.isPlaying ? '#4a90e2' : '#333')
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .borderRadius(8)
    .backgroundColor('#f0f0f0')
    .onClick(() => {
      if (this.isPlaying) this.onStop()
      else this.onPlay()
    })
  }
}