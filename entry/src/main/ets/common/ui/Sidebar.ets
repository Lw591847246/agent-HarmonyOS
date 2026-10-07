import { Conversation } from '../../domain/models/Conversation'
import { MediaCache } from '../../common/utils/MediaCache'
import { Logger } from '../../common/logger/Logger'
import { promptAction } from '@kit.ArkUI'

@Component
export struct Sidebar {
  @Prop conversations: Conversation[] = []
  @Prop currentSessionId: string = ''
  @State keyword: string = ''

  onSelect: (sessionId: string) => void = () => {}
  onLogout: () => void = () => {}
  onClearCache: () => void = () => {}     // ⭐ 新增

  private filtered(): Conversation[] {
    const kw = this.keyword.trim().toLowerCase()
    if (!kw) return this.conversations
    const result: Conversation[] = []
    for (let i = 0; i < this.conversations.length; i++) {
      const c = this.conversations[i]
      if (c.title.toLowerCase().includes(kw)) {
        result.push(c)
      }
    }
    return result
  }

  /** ⭐ 清理缓存：弹确认 → 清 → toast */
  private handleClearCache(): void {
    const size = MediaCache.getCacheSize()
    const sizeText = MediaCache.formatSize(size)

    AlertDialog.show({
      title: '清理缓存',
      message: `当前缓存 ${sizeText}，确定清理所有已缓存的视频和图片？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清理',
        fontColor: '#e74c3c',
        action: () => {
          try {
            MediaCache.clearAll()
            promptAction.openToast({ message: `已清理 ${sizeText}` })
            Logger.i(`[Sidebar] cleared cache ${sizeText}`)
            this.onClearCache()
          } catch (e) {
            promptAction.openToast({ message: `清理失败: ${(e as Error).message}` })
          }
        }
      }
    })
  }

  build() {
    Column() {
      // 搜索框
      Row() {
        TextInput({ text: $$this.keyword, placeholder: '搜索会话...' })
          .width('100%')
          .height(36)
          .backgroundColor('#ececf0')
          .borderRadius(18)
          .fontSize(13)
          .padding({ left: 12, right: 12 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 48, bottom: 12 })

      Divider().color('#eee')

      List() {
        ForEach(this.filtered(), (conv: Conversation) => {
          ListItem() {
            Text(conv.title || '未命名对话')
              .fontSize(14)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding(12)
              .backgroundColor(conv.sessionId === this.currentSessionId ? '#ececf0' : Color.Transparent)
              .borderRadius(6)
          }
          .onClick(() => {
            this.onSelect(conv.sessionId)
          })
        }, (conv: Conversation) => conv.sessionId)
      }
      .layoutWeight(1)
      .width('100%')

      Divider().color('#eee')

      // ⭐ 清理缓存
      Row() {
        Text('清理缓存')
          .fontSize(14)
          .fontColor('#333')
          .width('100%')
          .padding(16)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .onClick(() => {
        this.handleClearCache()
      })

      Divider().color('#eee')

      // 退出登录
      Row() {
        Text('退出登录')
          .fontSize(14)
          .fontColor('#e74c3c')
          .width('100%')
          .padding(16)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .onClick(() => {
        this.onLogout()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f7f7f9')
  }
}