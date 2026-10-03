import { ChatCard, CardType } from '../../domain/models/ChatCard'
import { ConfirmCard } from './card/ConfirmCard'
import { ErrorCard } from './card/ErrorCard'
import { ProgressCard } from './card/ProgressCard'
import { ResultCard } from './card/ResultCard'
import { TemplatePickerCard } from './card/TemplatePickerCard'
import { TextInputCard } from './card/TextInputCard'
import { VoicePickerCard } from './card/VoicePickerCard'

@Component
export struct CardRenderer {
  @Prop card: ChatCard
  onCardAction: (cardId: string, cardType: string, optionKey: string, text: string) => void =
    (cardId: string, cardType: string, optionKey: string, text: string) => {}
  onPlay: (url: string) => void = (url: string) => {}

  build() {
    if (this.card.card_type === CardType.TEMPLATE_PICKER) {
      TemplatePickerCard({ card: this.card, onAction: this.onCardAction })
    } else if (this.card.card_type === CardType.TEXT_INPUT) {
      TextInputCard({ card: this.card, onAction: this.onCardAction })
    } else if (this.card.card_type === CardType.VOICE_PICKER) {
      VoicePickerCard({ card: this.card, onAction: this.onCardAction })
    } else if (this.card.card_type === CardType.CONFIRM) {
      ConfirmCard({ card: this.card, onAction: this.onCardAction })
    } else if (this.card.card_type === CardType.PROGRESS) {
      ProgressCard({ card: this.card })
    } else if (this.card.card_type === CardType.RESULT) {
      ResultCard({ card: this.card, onPlay: this.onPlay })
    } else if (this.card.card_type === CardType.ERROR) {
      ErrorCard({ card: this.card })
    }
  }
}