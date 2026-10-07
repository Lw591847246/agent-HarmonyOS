import { ChatCard, ChatCardItem } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'
import { EnvConfig } from '../../config/EnvConfig'

@Component
export struct FaceSwapPickImageCard {
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

  // 已选中 key（也当防抖锁用，点完立刻置位，避免二次点击）
  @State private pickedKey: string = ''

  /**
   * 缩略图地址兜底：后端返回的是 /agent/v1/upload/thumb/xxx 相对路径
   * 若已是 http 或 file:// 则直接用
   */
  private resolveUrl(u: string): string {
    if (!u || u.length === 0) return ''
    if (u.startsWith('http') || u.startsWith('file://')) return u
    return EnvConfig.AGENT_BASE_URL + u
  }

  private onPick(item: ChatCardItem): void {
    if (this.pickedKey.length > 0) return      // ⭐ 防抖：只响应一次
    if (!item.key || item.key.length === 0) return
    this.pickedKey = item.key
    this.onAction(
      this.card.card_id,
      this.card.card_type,
      'pick_source_image',
      '',
      item.key,
    )
  }

  private gridHeight(): number {
    const n = this.card.items ? this.card.items.length : 0
    if (n === 0) return 0
    const rows = Math.ceil(n / 3)
    // 每格 ≈ 图片 100 + 文件名 16 + padding 8
    return rows * 132 + (rows - 1) * 8
  }

  build() {
    Column({ space: CardStyles.GAP }) {
      Text(this.card.title)
        .fontSize(CardStyles.FONT_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(CardStyles.TEXT_PRIMARY)
        .width('100%')

      if (this.card.description && this.card.description.length > 0) {
        Text(this.card.description)
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_HINT)
          .width('100%')
      }

      if (this.card.items && this.card.items.length > 0) {
        Grid() {
          ForEach(this.card.items, (item: ChatCardItem) => {
            GridItem() {
              this.renderItem(item)
            }
          }, (item: ChatCardItem) => item.key)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .width('100%')
        .height(this.gridHeight())
      } else {
        Text('没有可选图片')
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_HINT)
          .width('100%')
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
  renderItem(item: ChatCardItem) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 4 }) {
        // 缩略图
        if (item.thumbnail && item.thumbnail.length > 0) {
          Image(this.resolveUrl(item.thumbnail))
            .width('100%')
            .height(100)
            .borderRadius(CardStyles.RADIUS_ITEM)
            .objectFit(ImageFit.Cover)
            .backgroundColor(CardStyles.BG_INPUT)
        } else {
          Column() {
            Text('🖼').fontSize(28)
          }
          .width('100%')
          .height(100)
          .borderRadius(CardStyles.RADIUS_ITEM)
          .backgroundColor(CardStyles.BG_INPUT)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        // 文件名
        Text(item.label || 'image')
          .fontSize(10)
          .fontColor(CardStyles.TEXT_HINT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(4)
      .backgroundColor(
        this.pickedKey === item.key ? CardStyles.BG_INPUT : CardStyles.BG_ITEM
      )
      .borderRadius(10)
      .border({
        width: this.pickedKey === item.key ? 2 : 1,
        color: this.pickedKey === item.key ? CardStyles.PRIMARY : CardStyles.BORDER,
      })

      // 选中打勾
      if (this.pickedKey === item.key) {
        Text('✓')
          .fontSize(12)
          .fontColor(Color.White)
          .width(20).height(20)
          .textAlign(TextAlign.Center)
          .borderRadius(10)
          .backgroundColor(CardStyles.PRIMARY)
          .margin({ top: 2, right: 2 })
      }
    }
    .width('100%')
    .onClick(() => this.onPick(item))
  }
}