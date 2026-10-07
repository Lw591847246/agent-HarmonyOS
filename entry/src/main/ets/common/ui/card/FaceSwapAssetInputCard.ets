import { ChatCard, ChatCardButton, FaceSwapAssetItem } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'

@Component
export struct FaceSwapAssetInputCard {
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
          .fontColor(CardStyles.DANGER)
          .width('100%')
      }

      if (this.card.summary && this.card.summary.source_image) {
        this.renderAssetBlock('人脸图', [this.card.summary.source_image])
      }

      if (this.card.summary && this.card.summary.target_videos.length > 0) {
        this.renderAssetBlock('目标视频', this.card.summary.target_videos)
      }

      if (this.card.allow_text_input) {
        TextInput({
          text: this.inputText,
          placeholder: this.card.text_input_placeholder || '描述换脸要求'
        })
          .fontSize(CardStyles.FONT_BODY)
          .backgroundColor(CardStyles.BG_INPUT)
          .borderRadius(CardStyles.RADIUS_ITEM)
          .padding(CardStyles.PADDING_ITEM)
          .width('100%')
          .onChange((v: string) => { this.inputText = v })
      }

      if (this.card.buttons) {
        ForEach(this.card.buttons, (btn: ChatCardButton) => {
          Button(btn.label)
            .fontSize(CardStyles.FONT_BODY)
            // ⭐ 修复：主色底用白字，浅灰底用深字
            .fontColor(this.isPrimaryButton(btn.key)
              ? CardStyles.TEXT_WHITE
              : CardStyles.TEXT_PRIMARY)
            .backgroundColor(this.btnBg(btn.key))
            .borderRadius(CardStyles.RADIUS_BTN)
            .width('100%')
            .height(36)
            .onClick(() => {
              if (btn.key === 'upload_source_image') {
                this.onPickUpload('image', this.card.card_id, this.card.card_type)
              } else if (btn.key === 'upload_target_video') {
                this.onPickUpload('video', this.card.card_id, this.card.card_type)
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
  renderAssetBlock(title: string, items: FaceSwapAssetItem[]) {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(CardStyles.FONT_SMALL)
        .fontColor(CardStyles.TEXT_HINT)
        .width('100%')

      ForEach(items, (item: FaceSwapAssetItem) => {
        Row({ space: CardStyles.GAP }) {
          if (item.thumb_url && item.thumb_url.length > 0) {
            Image(item.thumb_url)
              .width(48).height(48)
              .borderRadius(CardStyles.RADIUS_ITEM)
              .objectFit(ImageFit.Cover)
              .backgroundColor(CardStyles.BG_INPUT)
          } else {
            Column()
              .width(48).height(48)
              .borderRadius(CardStyles.RADIUS_ITEM)
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
        .padding(CardStyles.PADDING_ITEM)
        .width('100%')
        .backgroundColor(CardStyles.BG_ITEM)
        .borderRadius(CardStyles.RADIUS_ITEM)
      }, (item: FaceSwapAssetItem) => item.file_id)
    }
    .width('100%')
  }

  // ⭐ 主色按钮：上传人脸图 / 上传目标视频
  private isPrimaryButton(key: string): boolean {
    return key === 'upload_source_image' || key === 'upload_target_video'
  }

  private btnBg(key: string): string {
    return this.isPrimaryButton(key) ? CardStyles.PRIMARY : CardStyles.BG_ITEM
  }
}