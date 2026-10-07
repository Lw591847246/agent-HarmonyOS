import { ChatCard, ChatCardButton, FaceSwapTaskItem } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'

@Component
export struct FaceSwapTaskCard {
  @Prop card: ChatCard

  onAction: (
    cardId: string,
    cardType: string,
    optionKey: string,
    text: string,
    fileId?: string
  ) => void = (
    cardId: string, cardType: string, optionKey: string,
    text: string, fileId?: string
  ) => {}

  onPlay: (url: string) => void = (url: string) => {}
  onSave: (url: string) => void = (url: string) => {}    // ⭐ 新增
  onShare: (url: string) => void = (url: string) => {}  // ⭐ 新增

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

      if (this.card.tasks && this.card.tasks.length > 0) {
        ForEach(this.card.tasks, (t: FaceSwapTaskItem) => {
          this.renderTaskRow(t)
        }, (t: FaceSwapTaskItem) => `${t.task_id}_${t.status}_${t.progress}`)
      }

      if (this.card.buttons) {
        ForEach(this.card.buttons, (btn: ChatCardButton) => {
          Button(btn.label)
            .fontSize(CardStyles.FONT_BODY)
            .fontColor(CardStyles.TEXT_SECONDARY)
            .backgroundColor(CardStyles.BG_ITEM)
            .borderRadius(CardStyles.RADIUS_BTN)
            .width('100%')
            .height(36)
            .onClick(() => {
              this.onAction(this.card.card_id, this.card.card_type, btn.key, '')
            })
        }, (btn: ChatCardButton) => btn.key)
      }
    }
    .padding(CardStyles.PADDING_CARD)
    .backgroundColor(CardStyles.BG_CARD)
    .borderRadius(CardStyles.RADIUS_CARD)
    .border({ width: 1, color: CardStyles.BORDER })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  renderTaskRow(t: FaceSwapTaskItem) {
    Column({ space: 6 }) {
      Row({ space: CardStyles.GAP_SMALL }) {
        Text(t.video_name)
          .fontSize(CardStyles.FONT_BODY)
          .fontColor(CardStyles.TEXT_PRIMARY)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.statusLabel(t))
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(this.statusColor(t))
      }
      .width('100%')

      if (t.status === 'done' && t.video_url && t.video_url.length > 0) {
        // ⭐ 已完成：视频摘要 + 三按钮
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('📹').fontSize(24)

            Column({ space: 3 }) {
              Text(t.video_name)
                .fontSize(13)
                .fontColor(CardStyles.TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Row({ space: 6 }) {
                Text(this.formatSize(t.file_size))
                  .fontSize(11)
                  .fontColor(CardStyles.TEXT_HINT)
                Text('·').fontSize(11).fontColor(CardStyles.TEXT_HINT)
                Text(t.summary && t.summary.length > 0 ? t.summary : 'AI换脸视频')
                  .fontSize(11)
                  .fontColor(CardStyles.TEXT_HINT)
                  .maxLines(1)
                  .layoutWeight(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          Row({ space: 8 }) {
            Button('播放')
              .fontSize(CardStyles.FONT_SMALL)
              .fontColor(CardStyles.TEXT_WHITE)
              .backgroundColor(CardStyles.PRIMARY)
              .borderRadius(CardStyles.RADIUS_BTN)
              .layoutWeight(1)
              .height(32)
              .onClick(() => this.onPlay(t.video_url!))

            Button('保存')
              .fontSize(CardStyles.FONT_SMALL)
              .fontColor(CardStyles.PRIMARY)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: CardStyles.PRIMARY })
              .borderRadius(CardStyles.RADIUS_BTN)
              .layoutWeight(1)
              .height(32)
              .onClick(() => this.onSave(t.video_url!))

            Button('分享')
              .fontSize(CardStyles.FONT_SMALL)
              .fontColor(CardStyles.PRIMARY)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: CardStyles.PRIMARY })
              .borderRadius(CardStyles.RADIUS_BTN)
              .layoutWeight(1)
              .height(32)
              .onClick(() => this.onShare(t.video_url!))
          }
          .width('100%')
        }
        .padding(CardStyles.PADDING_ITEM)
        .width('100%')
        .backgroundColor('#F0F7FF')
        .borderRadius(CardStyles.RADIUS_ITEM)
      } else if (t.status === 'failed' || t.status === 'canceled') {
        Text(t.error && t.error.length > 0 ? t.error : '任务失败')
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.DANGER)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Row({ space: CardStyles.GAP }) {
          Progress({ value: t.progress, total: 100, type: ProgressType.Linear })
            .color(CardStyles.PRIMARY)
            .layoutWeight(1)
          Text(`${t.progress}%`)
            .fontSize(CardStyles.FONT_SMALL)
            .fontColor(CardStyles.TEXT_SECONDARY)
            .width(40)
            .textAlign(TextAlign.End)
        }
        .width('100%')
      }
    }
    .padding(CardStyles.PADDING_ITEM)
    .width('100%')
    .backgroundColor(CardStyles.BG_ITEM)
    .borderRadius(CardStyles.RADIUS_ITEM)
  }

  private statusLabel(t: FaceSwapTaskItem): string {
    if (t.status === 'done') return '已完成'
    if (t.status === 'failed') return '失败'
    if (t.status === 'canceled') return '已取消'
    if (t.status === 'running') return '处理中'
    return '排队中'
  }

  private statusColor(t: FaceSwapTaskItem): string {
    if (t.status === 'done') return CardStyles.PRIMARY
    if (t.status === 'failed' || t.status === 'canceled') return CardStyles.DANGER
    return CardStyles.TEXT_HINT
  }

  private formatSize(size?: number): string {
    if (!size || size <= 0) return '未知大小'
    if (size < 1024) return `${size} B`
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(0)} KB`
    return `${(size / 1024 / 1024).toFixed(1)} MB`
  }
}