import { ChatCard, ChatCardConfirmSummary } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'

@Component
export struct ConfirmCard {
  @Prop card: ChatCard
  onAction: (cardId: string, cardType: string, optionKey: string, text: string) => void =
    (cardId: string, cardType: string, optionKey: string, text: string) => {}

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

      // 摘要信息
      Column({ space: 6 }) {
        this.renderSummaryRow('模板', this.getSummary().template)
        this.renderSummaryRow('声音', this.getSummary().voice)
        this.renderSummaryRow('内容', this.getSummary().tts_text)
      }
      .width('100%')
      .padding(CardStyles.PADDING_ITEM)
      .backgroundColor(CardStyles.BG_ITEM)
      .borderRadius(CardStyles.RADIUS_ITEM)

      Button(this.card.submit_action ? this.card.submit_action.label : '开始生成')
        .fontSize(CardStyles.FONT_BODY)
        .fontColor(CardStyles.TEXT_WHITE)
        .backgroundColor(CardStyles.PRIMARY)
        .borderRadius(CardStyles.RADIUS_BTN)
        .width('100%')
        .height(36)
        .onClick(() => {
          this.onAction(this.card.card_id, this.card.card_type, 'confirm_submit', '')
        })
    }
    .padding(CardStyles.PADDING_CARD)
    .backgroundColor(CardStyles.BG_CARD)
    .borderRadius(CardStyles.RADIUS_CARD)
    .border({ width: 1, color: CardStyles.BORDER })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private getSummary(): ChatCardConfirmSummary {
    if (this.card.extra && this.card.extra.summary) {
      return this.card.extra.summary
    }
    return {}
  }

  @Builder
  renderSummaryRow(label: string, value: string | undefined) {
    if (value && value.length > 0) {
      Row({ space: CardStyles.GAP_SMALL }) {
        Text(label)
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_HINT)
          .width(50)
        Text(value)
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_PRIMARY)
          .layoutWeight(1)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
    }
  }
}