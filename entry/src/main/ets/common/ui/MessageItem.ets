import { ChatMessage } from '../../domain/models/ChatMessage'
import { MessageActionBar } from './MessageActionBar'
import { buildAssistantActions, buildUserActions, MessageAction } from './MessageAction'
import { MarkdownParser,MdLine  } from '../../common/utils/MarkdownUtil'

@Component
export struct MessageItem {
  @ObjectLink msg: ChatMessage
  onAction: (type: string) => void = () => {}
  onPreviewImage: (imageUri: string) => void = () => {}   // ✅ 新增

  private assistantActions: MessageAction[] = buildAssistantActions()
  private userActions: MessageAction[] = buildUserActions()


  @Builder
  renderMdLine(line: MdLine) {
    if (line.type === 'code') {
      Text(line.text)
        .fontSize(12)
        .fontColor('#d4d4d4')
        .backgroundColor('#1e1e1e')
        .padding(8)
        .borderRadius(4)
        .width('100%')
        .margin({ top: 4, bottom: 4 })
    } else if (line.type === 'h1') {
      Text(line.text)
        .fontSize(18).fontWeight(FontWeight.Bold)
        .width('100%').lineHeight(26)
        .margin({ top: 6, bottom: 2 })
    } else if (line.type === 'h2') {
      Text(line.text)
        .fontSize(17).fontWeight(FontWeight.Bold)
        .width('100%').lineHeight(24)
        .margin({ top: 6, bottom: 2 })
    } else if (line.type === 'h3') {
      Text(line.text)
        .fontSize(16).fontWeight(FontWeight.Bold)
        .width('100%').lineHeight(22)
        .margin({ top: 4, bottom: 2 })
    } else if (line.type === 'li') {
      Row() {
        Text('•').fontSize(15).margin({ right: 6 }).flexShrink(0)
        Text(line.text).fontSize(15).lineHeight(22).layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 2, bottom: 2 })
      .alignItems(VerticalAlign.Top)
    } else if (line.type === 'blank') {
      Row().height(6).width('100%')
    } else {
      Text(line.text)
        .fontSize(15).lineHeight(22)
        .width('100%')
    }
  }

  build() {
    Column() {
      if (this.msg.role === 'user') {
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
      } else {
        Row() {
          Column() {
            // 判断依据：整个回答是否完成（completed），而不是流式的 think 标记
            // 显示条件：还在回答中，或曾经有过思考内容
            if (!this.msg.completed || this.msg.thinking.length > 0) {
              Text(this.msg.completed ? '已思考' : '正在思考...')
                .fontSize(12)
                .fontColor('#888')
                .width('100%')
                .margin({ bottom: 4 })

              if (this.msg.thinking.length > 0) {
                Text(this.msg.thinking)
                  .fontSize(12)
                  .fontColor('#aaa')
                  .padding({ left: 8 })
                  .border({ width: { left: 2 }, color: '#ccc' })
                  .width('100%')
                  .margin({ bottom: 8 })
              }
            }

            // 图片优先 base64 渲染（避免 @Prop 深拷贝影响）
            if (this.msg.imageBase64.length > 0) {
              Image(this.msg.imageBase64)
                .width('70%')
                .aspectRatio(1)
                .borderRadius(8)
                .margin({ bottom: 8 })
                .objectFit(ImageFit.Contain)
                .gesture(
                  LongPressGesture({ repeat: false, duration: 500 })
                    .onAction(() => {
                      this.onPreviewImage(this.msg.imageBase64)
                    })
                )
            }

            if (this.msg.content.length > 0) {
              Column() {
                ForEach(MarkdownParser.parseLines(this.msg.content), (line: MdLine) => {
                  this.renderMdLine(line)
                }, (line: MdLine, idx: number) => `${idx}_${line.type}_${line.text.length}`)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            } else if (!this.msg.completed) {
              Row() {
                LoadingProgress().width(16).height(16).color('#999')
                Text('正在生成...').fontSize(13).fontColor('#999').margin({ left: 8 })
              }.width('100%')
            }

            if (this.msg.completed || this.msg.duration > 0) {
              Row() {
                if (this.msg.completed) {
                  MessageActionBar({
                    actions: this.assistantActions,
                    onAction: (t: string) => this.onAction(t)
                  })
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