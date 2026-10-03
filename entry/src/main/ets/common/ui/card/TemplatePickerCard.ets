import { ChatCard, ChatCardItem } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'

@Component
export struct TemplatePickerCard {
  @Prop card: ChatCard
  onAction: (cardId: string, cardType: string, optionKey: string, text: string) => void =
    (cardId: string, cardType: string, optionKey: string, text: string) => {}

  @State selectedKey: string = ''
  @State inputText: string = ''

  aboutToAppear(): void {
    // 默认选中第一个 default 项
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
      // 标题
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

      // 模板列表
      Column({ space: CardStyles.GAP_SMALL }) {
        ForEach(this.card.items, (item: ChatCardItem) => {
          this.renderItem(item)
        }, (item: ChatCardItem) => item.key)
      }
      .width('100%')

      // 可选的补充输入框
      if (this.card.allow_text_input) {
        TextInput({ text: this.inputText, placeholder: this.card.text_input_placeholder || '可选，补充说明' })
          .fontSize(CardStyles.FONT_BODY)
          .backgroundColor(CardStyles.BG_INPUT)
          .borderRadius(CardStyles.RADIUS_ITEM)
          .padding(CardStyles.PADDING_ITEM)
          .width('100%')
          .onChange((value: string) => { this.inputText = value })
      }

      // 提交按钮（如果 card 定义了 submit_action）
      Button(this.card.submit_action ? this.card.submit_action.label : '确定')
        .fontSize(CardStyles.FONT_BODY)
        .fontColor(CardStyles.TEXT_WHITE)
        .backgroundColor(this.selectedKey.length > 0 ? CardStyles.PRIMARY : CardStyles.PRIMARY_DISABLED)
        .borderRadius(CardStyles.RADIUS_BTN)
        .width('100%')
        .height(36)
        .enabled(this.selectedKey.length > 0)
        .onClick(() => {
          this.onAction(this.card.card_id, this.card.card_type, this.selectedKey, this.inputText)
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
      // 缩略图（如果有）
      if (item.thumbnail && item.thumbnail.length > 0) {
        Image(item.thumbnail)
          .width(56).height(56)
          .borderRadius(CardStyles.RADIUS_ITEM)
          .objectFit(ImageFit.Cover)
          .backgroundColor(CardStyles.BG_INPUT)
      }

      Column({ space: 4 }) {
        Text(item.label)
          .fontSize(CardStyles.FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(CardStyles.TEXT_PRIMARY)
        if (item.description) {
          Text(item.description)
            .fontSize(CardStyles.FONT_SMALL)
            .fontColor(CardStyles.TEXT_HINT)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (item.tags && item.tags.length > 0) {
          Row({ space: 4 }) {
            ForEach(item.tags, (tag: string) => {
              Text(tag)
                .fontSize(10)
                .fontColor(CardStyles.PRIMARY)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(CardStyles.BG_ITEM_SELECTED)
                .borderRadius(4)
            }, (tag: string) => tag)
          }
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