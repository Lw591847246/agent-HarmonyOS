import { ChatCard } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'

@Component
export struct ProgressCard {
  @Prop card: ChatCard

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

      // 进度条
      Row({ space: CardStyles.GAP }) {
        Progress({
          value: this.getProgress(),
          total: 100,
          type: ProgressType.Linear
        })
          .color(CardStyles.PRIMARY)
          .layoutWeight(1)

        Text(`${this.getProgress()}%`)
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_SECONDARY)
          .width(40)
          .textAlign(TextAlign.End)
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

  private getProgress(): number {
    if (this.card.extra && this.card.extra.progress !== undefined) {
      return this.card.extra.progress
    }
    return 0
  }
}