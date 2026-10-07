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

      // 任务列表
      if (this.card.tasks && this.card.tasks.length > 0) {
        ForEach(this.card.tasks, (t: FaceSwapTaskItem) => {
          this.renderTaskRow(t)
        }, (t: FaceSwapTaskItem) => t.task_id)
      }

      // 底部按钮
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
              this.onAction(
                this.card.card_id, this.card.card_type,
                btn.key, ''
              )
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

      // 进度条 / 播放按钮
      if (t.status === 'done' && t.video_url && t.video_url.length > 0) {
        Button('播放')
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_WHITE)
          .backgroundColor(CardStyles.PRIMARY)
          .borderRadius(CardStyles.RADIUS_BTN)
          .height(32)
          .width('100%')
          .onClick(() => this.onPlay(t.video_url!))
      } else if (t.status === 'failed' || t.status === 'canceled') {
        Text(t.error || '任务失败')
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
}