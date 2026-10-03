import { ChatCard } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'

@Component
export struct ErrorCard {
  @Prop card: ChatCard

  build() {
    Column({ space: CardStyles.GAP }) {
      Text(this.card.title)
        .fontSize(CardStyles.FONT_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(CardStyles.DANGER)
        .width('100%')

      if (this.card.description) {
        Text(this.card.description)
          .fontSize(CardStyles.FONT_BODY)
          .fontColor(CardStyles.TEXT_SECONDARY)
          .width('100%')
      }
    }
    .padding(CardStyles.PADDING_CARD)
    .backgroundColor(CardStyles.BG_CARD)
    .borderRadius(CardStyles.RADIUS_CARD)
    .border({ width: 1, color: CardStyles.DANGER })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}