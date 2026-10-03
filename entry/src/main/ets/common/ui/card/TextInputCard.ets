import { ChatCard } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'

@Component
export struct TextInputCard {
  @Prop card: ChatCard
  onAction: (cardId: string, cardType: string, optionKey: string, text: string) => void =
    (cardId: string, cardType: string, optionKey: string, text: string) => {}

  @State inputText: string = ''

  aboutToAppear(): void {
    // ⭐ 预填：优先用 text_input_default，没有才空
    if (this.card.text_input_default && this.card.text_input_default.length > 0) {
      this.inputText = this.card.text_input_default
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

      TextArea({
        text: this.inputText,
        placeholder: this.card.text_input_placeholder || '请输入内容'
      })
        .fontSize(CardStyles.FONT_BODY)
        .backgroundColor(CardStyles.BG_INPUT)
        .borderRadius(CardStyles.RADIUS_ITEM)
        .padding(CardStyles.PADDING_ITEM)
        .width('100%')
        .constraintSize({ minHeight: 70, maxHeight: 140 })
        .onChange((value: string) => { this.inputText = value })

      Button(this.card.submit_action ? this.card.submit_action.label : '下一步')
        .fontSize(CardStyles.FONT_BODY)
        .fontColor(CardStyles.TEXT_WHITE)
        .backgroundColor(this.inputText.trim().length > 0 ? CardStyles.PRIMARY : CardStyles.PRIMARY_DISABLED)
        .borderRadius(CardStyles.RADIUS_BTN)
        .width('100%')
        .height(36)
        .enabled(this.inputText.trim().length > 0)
        .onClick(() => {
          this.onAction(this.card.card_id, this.card.card_type, '', this.inputText.trim())
        })
    }
    .padding(CardStyles.PADDING_CARD)
    .backgroundColor(CardStyles.BG_CARD)
    .borderRadius(CardStyles.RADIUS_CARD)
    .border({ width: 1, color: CardStyles.BORDER })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}