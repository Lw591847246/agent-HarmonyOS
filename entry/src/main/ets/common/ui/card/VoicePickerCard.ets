import { ChatCard, ChatCardItem } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'

@Component
export struct VoicePickerCard {
  @Prop card: ChatCard
  onAction: (cardId: string, cardType: string, optionKey: string, text: string) => void =
    (cardId: string, cardType: string, optionKey: string, text: string) => {}

  @State selectedKey: string = ''

  aboutToAppear(): void {
    for (let i = 0; i < this.card.items.length; i++) {
      if (this.card.items[i].default) {
        this.selectedKey = this.card.items[i].key
        break
      }
    }
    if (this.selectedKey.length === 0 && this.card.items.length > 0) {
      this.selectedKey = this.card.items[0].key
    }
  }

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

      Column({ space: CardStyles.GAP_SMALL }) {
        ForEach(this.card.items, (item: ChatCardItem) => {
          this.renderItem(item)
        }, (item: ChatCardItem) => item.key)
      }
      .width('100%')

      Button('确定')
        .fontSize(CardStyles.FONT_BODY)
        .fontColor(CardStyles.TEXT_WHITE)
        .backgroundColor(this.selectedKey.length > 0 ? CardStyles.PRIMARY : CardStyles.PRIMARY_DISABLED)
        .borderRadius(CardStyles.RADIUS_BTN)
        .width('100%')
        .height(36)
        .enabled(this.selectedKey.length > 0)
        .onClick(() => {
          this.onAction(this.card.card_id, this.card.card_type, this.selectedKey, '')
        })
    }
    .padding(CardStyles.PADDING_CARD)
    .backgroundColor(CardStyles.BG_CARD)
    .borderRadius(CardStyles.RADIUS_CARD)
    .border({ width: 1, color: CardStyles.BORDER })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  renderItem(item: ChatCardItem) {
    Row({ space: CardStyles.GAP }) {
      Column({ space: 4 }) {
        Text(item.label)
          .fontSize(CardStyles.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(CardStyles.TEXT_PRIMARY)
        if (item.description) {
          Text(item.description)
            .fontSize(CardStyles.FONT_SMALL)
            .fontColor(CardStyles.TEXT_HINT)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .padding(CardStyles.PADDING_ITEM)
    .width('100%')
    .backgroundColor(this.selectedKey === item.key ? CardStyles.BG_ITEM_SELECTED : CardStyles.BG_ITEM)
    .borderRadius(CardStyles.RADIUS_ITEM)
    .border({
      width: 1,
      color: this.selectedKey === item.key ? CardStyles.PRIMARY : Color.Transparent
    })
    .onClick(() => { this.selectedKey = item.key })
  }
}