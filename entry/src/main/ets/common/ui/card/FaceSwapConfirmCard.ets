import { ChatCard, ChatCardButton, FaceSwapAssetItem } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'

@Component
export struct FaceSwapConfirmCard {
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

  // ⭐ 新增
  onPickUpload: (kind: string, cardId: string, cardType: string) => void =
    (kind: string, cardId: string, cardType: string) => {}

  @State inputText: string = ''

  aboutToAppear(): void {
    if (this.card.text_input_default) {
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

      Column({ space: 8 }) {
        if (this.card.summary && this.card.summary.source_image) {
          this.renderAssetRow('人脸图', this.card.summary.source_image)
        }
        if (this.card.summary && this.card.summary.target_videos.length > 0) {
          Column({ space: 6 }) {
            Text(`目标视频（${this.card.summary.target_videos.length}）`)
              .fontSize(CardStyles.FONT_SMALL)
              .fontColor(CardStyles.TEXT_HINT)
              .width('100%')
            ForEach(this.card.summary.target_videos, (v: FaceSwapAssetItem) => {
              this.renderAssetRow('', v)
            }, (v: FaceSwapAssetItem) => v.file_id)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(CardStyles.PADDING_ITEM)
      .backgroundColor(CardStyles.BG_ITEM)
      .borderRadius(CardStyles.RADIUS_ITEM)

      if (this.card.allow_text_input) {
        TextInput({
          text: this.inputText,
          placeholder: this.card.text_input_placeholder || '修改提示词'
        })
          .fontSize(CardStyles.FONT_BODY)
          .backgroundColor(CardStyles.BG_INPUT)
          .borderRadius(CardStyles.RADIUS_ITEM)
          .padding(CardStyles.PADDING_ITEM)
          .width('100%')
          .onChange((v: string) => { this.inputText = v })

        if (this.card.submit_text_action) {
          Button(this.card.submit_text_action.label)
            .fontSize(CardStyles.FONT_SMALL)
            .fontColor(CardStyles.PRIMARY)
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: CardStyles.PRIMARY })
            .borderRadius(CardStyles.RADIUS_BTN)
            .height(32)
            .width('100%')
            .onClick(() => {
              this.onAction(
                this.card.card_id, this.card.card_type,
                this.card.submit_text_action!.key, this.inputText
              )
            })
        }
      }

      if (this.card.buttons) {
        ForEach(this.card.buttons, (btn: ChatCardButton) => {
          Button(btn.label)
            .fontSize(CardStyles.FONT_BODY)
            .fontColor(btn.key === 'cancel' ? CardStyles.TEXT_SECONDARY : CardStyles.TEXT_WHITE)
            .backgroundColor(this.btnBg(btn.key))
            .borderRadius(CardStyles.RADIUS_BTN)
            .width('100%')
            .height(36)
            .onClick(() => {
              // ⭐ 上传类按钮分流
              if (btn.key === 'add_video') {
                this.onPickUpload('video', this.card.card_id, this.card.card_type)
              } else if (btn.key === 'replace_face') {
                this.onPickUpload('image', this.card.card_id, this.card.card_type)
              } else {
                this.onAction(this.card.card_id, this.card.card_type, btn.key, this.inputText)
              }
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
  renderAssetRow(label: string, item: FaceSwapAssetItem) {
    Row({ space: CardStyles.GAP_SMALL }) {
      if (label.length > 0) {
        Text(label)
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_HINT)
          .width(50)
      }

      if (item.thumb_url && item.thumb_url.length > 0) {
        Image(item.thumb_url)
          .width(40).height(40)
          .borderRadius(CardStyles.RADIUS_ITEM)
          .objectFit(ImageFit.Cover)
          .backgroundColor(CardStyles.BG_INPUT)
      }

      Column({ space: 2 }) {
        Text(item.name)
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.duration && item.duration > 0) {
          Text(`${item.duration.toFixed(1)}s`)
            .fontSize(10)
            .fontColor(CardStyles.TEXT_HINT)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (item.removable) {
        Text('✕')
          .fontSize(14)
          .fontColor(CardStyles.DANGER)
          .width(24).height(24)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.onAction(
              this.card.card_id, this.card.card_type,
              'remove_asset', '', item.file_id
            )
          })
      }
    }
    .width('100%')
  }

  private btnBg(key: string): string {
    if (key === 'cancel' || key === 'add_video'
      || key === 'replace_face' || key === 'clear_assets') {
      return CardStyles.BG_ITEM
    }
    return CardStyles.PRIMARY
  }
}