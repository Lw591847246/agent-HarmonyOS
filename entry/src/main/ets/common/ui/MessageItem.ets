import { ChatMessage } from '../../domain/models/ChatMessage'
import { MessageActionBar } from './MessageActionBar'
import { buildAssistantActions, buildUserActions, MessageAction } from './MessageAction'
import { MarkdownParser, MdLine } from '../../common/utils/MarkdownUtil'
import { Logger } from '../../common/logger/Logger'
import { VoiceMessageBubble } from './VoiceMessageBubble'


@Component
export struct MessageItem {
  @ObjectLink msg: ChatMessage
  onAction: (type: string) => void = () => {}
  onPreviewImage: (imageUri: string) => void = () => {}

  private assistantActions: MessageAction[] = buildAssistantActions()
  private userActions: MessageAction[] = buildUserActions()

  @Prop isVoicePlaying: boolean = false
  @Prop isAiReading: boolean = false
  onVoicePlay: () => void = () => {}
  onVoiceStop: () => void = () => {}
  onToggleAiReading: () => void = () => {}

  /** ⭐ 是否可以朗读：排除图片类任务和纯占位内容 */
  private canRead(): boolean {
    if (!this.msg.completed) return false
    if (this.msg.content.length === 0) return false
    if (this.msg.content === '[图片已生成]') return false

    const hasImage = this.msg.imageBase64.length > 0
      || (this.msg.thumbUrl && this.msg.thumbUrl.length > 0)
    // 有图片且文字很短（<10）→ 视为图片任务，无朗读价值
    if (hasImage && this.msg.content.length < 10) return false
    return true
  }

  @Builder
  renderMdLine(line: MdLine) {
    if (line.type === 'code') {
      Text(line.text)
        .fontSize(12).fontColor('#d4d4d4').backgroundColor('#1e1e1e')
        .padding(8).borderRadius(4).width('100%').margin({ top: 4, bottom: 4 })
    } else if (line.type === 'h1') {
      Text(line.text).fontSize(18).fontWeight(FontWeight.Bold).width('100%').lineHeight(26).margin({ top: 6, bottom: 2 })
    } else if (line.type === 'h2') {
      Text(line.text).fontSize(17).fontWeight(FontWeight.Bold).width('100%').lineHeight(24).margin({ top: 6, bottom: 2 })
    } else if (line.type === 'h3') {
      Text(line.text).fontSize(16).fontWeight(FontWeight.Bold).width('100%').lineHeight(22).margin({ top: 4, bottom: 2 })
    } else if (line.type === 'li') {
      Row() {
        Text('•').fontSize(15).margin({ right: 6 }).flexShrink(0)
        Text(line.text).fontSize(15).lineHeight(22).layoutWeight(1)
      }
      .width('100%').margin({ top: 2, bottom: 2 }).alignItems(VerticalAlign.Top)
    } else if (line.type === 'blank') {
      Row().height(6).width('100%')
    } else {
      Text(line.text).fontSize(15).lineHeight(22).width('100%')
    }
  }

  build() {
    Column() {
      if (this.msg.role === 'user') {
        if (this.msg.isVoice) {
          Row() {
            VoiceMessageBubble({
              msg: this.msg,
              isPlaying: this.isVoicePlaying,
              onPlay: () => this.onVoicePlay(),
              onStop: () => this.onVoiceStop()
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
        } else {
          Row() {
            Column() {
              Text(this.msg.content).fontSize(15).lineHeight(22).width('100%')

              if (this.msg.files.length > 0) {
                ForEach(this.msg.files, (name: string) => {
                  Text('📎 ' + name).fontSize(12).fontColor('#555').margin({ top: 2 })
                })
              }

              MessageActionBar({
                actions: this.userActions,
                onAction: (t: string) => this.onAction(t)
              })
            }
            .padding(12).backgroundColor('#d9ecff').borderRadius(12)
            .alignItems(HorizontalAlign.Start).width('75%')
          }
          .width('100%').justifyContent(FlexAlign.End)
        }
      } else {
        Row() {
          Column() {
            // 思考过程
            if (!this.msg.completed || this.msg.thinking.length > 0) {
              Text(this.msg.completed ? '已思考' : '正在思考...')
                .fontSize(12).fontColor('#888').width('100%').margin({ bottom: 4 })

              if (this.msg.thinking.length > 0) {
                Text(this.msg.thinking)
                  .fontSize(12).fontColor('#aaa')
                  .padding({ left: 8 })
                  .border({ width: { left: 2 }, color: '#ccc' })
                  .width('100%').margin({ bottom: 8 })
              }
            }

            // 实时生成图片
            if (this.msg.imageBase64.length > 0) {
              Image(this.msg.imageBase64)
                .width(200).height(200)
                .borderRadius(8)
                .margin({ bottom: 8 })
                .objectFit(ImageFit.Cover)
                .backgroundColor('#eee')
                .onClick(() => {
                  this.onPreviewImage(this.msg.imageBase64)
                })
                .onError(() => {
                  Logger.e(`[MessageItem] 实时图加载失败`)
                })
            } else if (this.msg.thumbUrl && this.msg.thumbUrl.length > 0) {
              Column() {
                Image(this.msg.thumbUrl)
                  .width(200).height(200)
                  .borderRadius(8)
                  .margin({ bottom: 8 })
                  .objectFit(ImageFit.Cover)
                  .backgroundColor('#eee')
                  .gesture(
                    TapGesture({ count: 2 })
                      .onAction(() => {
                        Logger.i(`[MessageItem] 双击预览, imageUrl=${this.msg.imageUrl}, thumbUrl=${this.msg.thumbUrl}`)
                        this.onPreviewImage(this.msg.imageUrl)
                      })
                  )
                  .onError(() => {
                    Logger.e(`[MessageItem] 缩略图加载失败: ${this.msg.thumbUrl}`)
                  })
                Text('双击查看原图')
                  .fontSize(10).fontColor('#999').margin({ bottom: 8 })
              }
              .width('100%').alignItems(HorizontalAlign.Start)
            }

            // 正文
            if (this.msg.content.length > 0) {
              Column() {
                ForEach(MarkdownParser.parseLines(this.msg.content), (line: MdLine) => {
                  this.renderMdLine(line)
                }, (line: MdLine, idx: number) => `${idx}_${line.type}_${line.text.length}`)
              }
              .width('100%').alignItems(HorizontalAlign.Start)
            } else if (!this.msg.completed) {
              Row() {
                LoadingProgress().width(16).height(16).color('#999')
                Text('正在生成...').fontSize(13).fontColor('#999').margin({ left: 8 })
              }.width('100%')
            }

            // 底部操作栏 + 朗读按钮 + 耗时
            if (this.msg.completed || this.msg.duration > 0) {
              Row() {
                if (this.msg.completed) {
                  MessageActionBar({
                    actions: this.assistantActions,
                    onAction: (t: string) => this.onAction(t)
                  })
                }

                // ⭐ 朗读按钮：只有可朗读内容才显示
                if (this.canRead()) {
                  Row({ space: 3 }) {
                    Image(this.isAiReading
                      ? $r('app.media.ic_speaker_stop')
                      : $r('app.media.ic_speaker'))
                      .width(14).height(14)
                      .objectFit(ImageFit.Contain)
                    Text(this.isAiReading ? '停止' : '朗读')
                      .fontSize(11)
                      .fontColor(this.isAiReading ? '#e74c3c' : '#666')
                  }
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .borderRadius(10)
                  .backgroundColor(this.isAiReading ? '#ffe5e5' : '#e8e8e8')
                  .margin({ left: 6 })
                  .onClick(() => this.onToggleAiReading())
                }

                Blank()

                if (this.msg.duration > 0) {
                  Text(`耗时 ${this.msg.duration.toFixed(2)} 秒`)
                    .fontSize(10).fontColor('#bbb')
                }
              }.width('100%').margin({ top: 6 })
            }
          }
          .padding(12).backgroundColor('#f5f5f5').borderRadius(12)
          .alignItems(HorizontalAlign.Start).width('75%')
        }
        .width('100%').justifyContent(FlexAlign.Start)
      }
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .width('100%')
  }
}