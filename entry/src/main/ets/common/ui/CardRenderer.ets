import { ChatCard, CardType } from '../../domain/models/ChatCard'
import { ConfirmCard } from './card/ConfirmCard'
import { ErrorCard } from './card/ErrorCard'
import { ProgressCard } from './card/ProgressCard'
import { ResultCard } from './card/ResultCard'
import { TemplatePickerCard } from './card/TemplatePickerCard'
import { TextInputCard } from './card/TextInputCard'
import { VoicePickerCard } from './card/VoicePickerCard'
import { FaceSwapAssetInputCard } from './card/FaceSwapAssetInputCard'
import { FaceSwapConfirmCard } from './card/FaceSwapConfirmCard'
import { FaceSwapTaskCard } from './card/FaceSwapTaskCard'

@Component
export struct CardRenderer {
  @Prop card: ChatCard
  onCardAction: (
    cardId: string,
    cardType: string,
    optionKey: string,
    text: string,
    fileId?: string
  ) => void = (
    cardId: string, cardType: string, optionKey: string,
    text: string, fileId?: string
  ) => {}

  onPickUpload: (kind: string, cardId: string, cardType: string) => void =
    (kind: string, cardId: string, cardType: string) => {}

  onPlay: (url: string) => void = (url: string) => {}
  onSave: (url: string) => void = (url: string) => {}       // ⭐ 新增
  onShare: (url: string) => void = (url: string) => {}      // ⭐ 新增

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
    } else if (this.card.card_type === CardType.FACE_SWAP_ASSET_INPUT) {
      FaceSwapAssetInputCard({
        card: this.card,
        onAction: this.onCardAction,
        onPickUpload: this.onPickUpload,
      })
    } else if (this.card.card_type === CardType.FACE_SWAP_CONFIRM) {
      FaceSwapConfirmCard({
        card: this.card,
        onAction: this.onCardAction,
        onPickUpload: this.onPickUpload,
      })
    } else if (this.card.card_type === CardType.FACE_SWAP_TASK) {
      FaceSwapTaskCard({
        card: this.card,
        onAction: this.onCardAction,
        onPlay: this.onPlay,
        onSave: this.onSave,
        onShare: this.onShare,
      })
    }
  }
}