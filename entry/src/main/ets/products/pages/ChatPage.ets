import http from '@ohos.net.http'
import pasteboard from '@ohos.pasteboard'
import { promptAction } from '@kit.ArkUI'

import { ChatViewModel } from '../../features/chat/ChatViewModel'
import { ConversationViewModel } from '../../features/conversation/ConversationViewModel'
import { FileViewModel } from '../../features/file/FileViewModel'
import { AuthViewModel } from '../../features/auth/AuthViewModel'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { Conversation } from '../../domain/models/Conversation'
import { FileItem } from '../../domain/models/FileItem'
import { MessageItem } from '../../common/ui/MessageItem'
import { Sidebar } from '../../common/ui/Sidebar'
import { InputBar } from '../../common/ui/InputBar'
import { MessageActionType } from '../../common/ui/MessageAction'
import { Logger } from '../../common/logger/Logger'
import { common } from '@kit.AbilityKit'

@Component
export struct ChatPage {
  onLogout: () => void = () => {}
  @State messages: ChatMessage[] = []
  @State conversations: Conversation[] = []
  @State inputText: string = ''
  @State loadingSessionId: string = ''
  @State currentSessionId: string = ''
  @State sidebarVisible: boolean = false
  @State attachedFiles: FileItem[] = []
  @State showAddMenu: boolean = false

  private scroller: Scroller = new Scroller()
  private currentRequest: http.HttpRequest | null = null

  private chatVM: ChatViewModel = new ChatViewModel(getContext(this))
  private conversationVM = new ConversationViewModel()
  private fileVM = new FileViewModel()
  private authVM = new AuthViewModel()

  private isLoadingNow(): boolean {
    return this.loadingSessionId.length > 0 && this.loadingSessionId === this.currentSessionId
  }
  private isCanSend(): boolean {
    return this.inputText.trim().length > 0 || this.attachedFiles.length > 0
  }

  aboutToAppear(): void { this.init() }

  /** 页面回到前台时触发。App 从后台切回、从其他页返回时都会调用 */
  onPageShow(): void {
    Logger.i('[ChatPage] onPageShow：清空 loading，避免后台挂起的请求卡死状态')

    // 关键：清空 loading，让重新生成、提交等按钮恢复可点
    this.loadingSessionId = ''

    // 释放可能还挂着的请求
    if (this.currentRequest) {
      try {
        this.currentRequest.destroy()
      } catch (e) {
        Logger.e('destroy 请求失败: ' + (e as Error).message)
      }
      this.currentRequest = null
    }

    // 可选：把消息列表里还没完成的消息标记为完成，避免 UI 一直显示"正在生成"
    for (let i = 0; i < this.messages.length; i++) {
      const m = this.messages[i]
      if (!m.completed) {
        m.completed = true
        if (m.content.length === 0) {
          m.content = '[请求已中断]'
        }
      }
    }
    this.messages = [...this.messages]
  }

  /** 页面进入后台时触发 */
  onPageHide(): void {
    Logger.i('[ChatPage] onPageHide：进入后台，标记未完成消息并清理请求')
    // 尝试主动清理请求（有些场景下 onFinish 会因此触发）
    if (this.currentRequest) {
      try {
        this.currentRequest.destroy()
      } catch (e) {
        Logger.e('onPageHide destroy 失败: ' + (e as Error).message)
      }
      this.currentRequest = null
    }
    this.loadingSessionId = ''
  }


  async init(): Promise<void> {
    await this.loadConversations()
    if (this.conversations.length > 0) {
      await this.selectConversation(this.conversations[0].sessionId)
    } else {
      await this.newConversation()
    }
  }

  async loadConversations(): Promise<void> {
    this.conversations = await this.conversationVM.loadList()
  }

  async newConversation(): Promise<void> {
    const sid = await this.conversationVM.createNew()
    if (!sid) return
    this.currentSessionId = sid
    this.messages = []
    this.sidebarVisible = false
    await this.loadConversations()
  }

  async selectConversation(sessionId: string): Promise<void> {
    this.loadingSessionId = ''
    this.currentSessionId = sessionId
    this.sidebarVisible = false
    this.messages = await this.conversationVM.loadHistory(sessionId)
    this.scrollToBottom()
  }

  handleSubmit(): void {
    if (this.isLoadingNow()) return
    if (!this.isCanSend()) {
      promptAction.openToast({ message: '请输入内容或选择文件' })
      return
    }
    this.send()
  }

  send(): void {
    const text = this.inputText.trim()
    if (this.isLoadingNow()) return
    if (text.length === 0 && this.attachedFiles.length === 0) return
    if (this.attachedFiles.length > 0) { this.sendFiles(text); return }

    this.messages.push(this.chatVM.createUserMessage(text))
    const assistantMsg = this.chatVM.createAssistantPlaceholder()
    this.messages.push(assistantMsg)

    this.inputText = ''
    this.loadingSessionId = this.currentSessionId
    this.messages = [...this.messages]
    this.scrollToBottom()

    this.currentRequest = this.chatVM.sendStream({
      text,
      sessionId: this.currentSessionId,
      assistantMsg,
      onRefresh: () => { this.messages = [...this.messages] },
      onScroll: () => this.scrollToBottom(),
      onFinish: () => {
        this.loadingSessionId = ''
        this.loadConversations()
      }
    })
  }

  async sendFiles(text: string): Promise<void> {
    if (this.isLoadingNow()) return
    this.loadingSessionId = this.currentSessionId
    const files = this.attachedFiles
    this.attachedFiles = []

    this.messages.push(this.chatVM.createUserMessage(text, files.map(f => f.name)))
    this.messages.push(this.chatVM.createAssistantPlaceholder())
    this.inputText = ''
    this.messages = [...this.messages]

    const m = await this.chatVM.sendFiles(this.currentSessionId, text, files)
    // 替换最后一个占位消息
    this.messages[this.messages.length - 1] = m
    this.messages = [...this.messages]
    this.loadingSessionId = ''
    this.scrollToBottom()
  }

  async regenerate(userMsg: ChatMessage): Promise<void> {
    if (this.isLoadingNow()) return
    const text = userMsg.content
    if (!text || !this.currentSessionId) return

    this.messages.push(this.chatVM.createUserMessage(text, userMsg.files))
    const assistantMsg = this.chatVM.createAssistantPlaceholder()
    this.messages.push(assistantMsg)
    this.messages = [...this.messages]
    this.loadingSessionId = this.currentSessionId
    this.scrollToBottom()

    this.currentRequest = this.chatVM.sendStream({
      text,
      sessionId: this.currentSessionId,
      assistantMsg,
      onRefresh: () => { this.messages = [...this.messages] },
      onScroll: () => this.scrollToBottom(),
      onFinish: () => {
        this.loadingSessionId = ''
        this.loadConversations()
      }
    })
  }

  copyMessage(msg: ChatMessage): void {
    if (!msg.content) return
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, msg.content)
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      promptAction.openToast({ message: '已复制到剪贴板' })
    }).catch((e: Error) => {
      promptAction.openToast({ message: '复制失败: ' + e.message })
    })
  }

  handleAction(type: string, msg: ChatMessage): void {
    if (type === MessageActionType.COPY) this.copyMessage(msg)
    else if (type === MessageActionType.REGENERATE) this.regenerate(msg)
    else if (type === MessageActionType.SHARE) promptAction.openToast({ message: '分享开发中' })
  }

  async onCameraOrAlbum(): Promise<void> {
    const files = await this.fileVM.pickImages(3)
    if (!files.length) return
    this.loadingSessionId = this.currentSessionId
    const m = await this.chatVM.ocr(files)
    this.messages.push(m)
    this.messages = [...this.messages]
    this.loadingSessionId = ''
    this.scrollToBottom()
  }

  async onPickFile(): Promise<void> {
    this.attachedFiles = await this.fileVM.pickDocuments(3)
  }

  async logout(): Promise<void> {
    await this.authVM.logout()
    this.onLogout()
  }



  scrollToBottom(): void { this.scroller.scrollEdge(Edge.Bottom) }

  build() {
    // ✅ Column 作为根节点，不再用 Stack 包
    Column() {
      // 顶栏
      Row() {
        Text('☰').fontSize(22).padding(12)
          .onClick(() => { this.sidebarVisible = !this.sidebarVisible })
        Text('AI 智能助手').fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1)

        // 右上角：新建会话（加号外圆圈）
        Button() {
          Text('+')
            .fontSize(18)
            .fontColor(Color.Black)
            .fontWeight(FontWeight.Regular)
        }
        .width(24)
        .height(24)
        .borderRadius(14)
        .backgroundColor(Color.Transparent)
        .border({ width: 1.2, color: Color.Black })
        .margin({ right: 12 })
        .onClick(() => this.newConversation())
      }
      .width('100%').height(56).backgroundColor(Color.White)
      .border({ width: { bottom: 1 }, color: '#eee' })

      // 消息列表
      List({ scroller: this.scroller }) {
        ForEach(this.messages, (msg: ChatMessage) => {
          ListItem() {
            MessageItem({
              msg: msg,
              onAction: (t: string) => { this.handleAction(t, msg) }
            })
          }
        }, (msg: ChatMessage) => {
          const imgFlag = msg.imageBase64.length > 0 ? 'img' : 'no'
          return `${msg.id}_${msg.completed}_${msg.content.length}_${imgFlag}`
        })
      }
      .layoutWeight(1)      // ✅ 占满剩余高度
      .width('100%')
      .backgroundColor('#fafafa')

      // 附件提示（紧贴输入栏上方）
      if (this.attachedFiles.length > 0) {
        Row() {
          Text(`已选择 ${this.attachedFiles.length} 个文件`)
            .fontSize(12).fontColor('#666').layoutWeight(1)
          Text('清空').fontSize(12).fontColor('#e74c3c')
            .onClick(() => { this.attachedFiles = [] })
        }
        .width('100%').padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .backgroundColor('#fff9e6')
      }

      // 输入栏
      InputBar({
        text: $inputText,
        loading: this.isLoadingNow(),
        canSend: this.isCanSend(),
        showAddMenu: this.showAddMenu,
        onSend: () => this.handleSubmit(),
        onToggleAddMenu: () => { this.showAddMenu = !this.showAddMenu },
        onVoice: () => promptAction.openToast({ message: '语音开发中' }),
        onCamera: () => { this.showAddMenu = false; this.onCameraOrAlbum() },
        onAlbum: () => { this.showAddMenu = false; this.onCameraOrAlbum() },
        onFile: () => { this.showAddMenu = false; this.onPickFile() }
      })
    }
    .width('100%')
    .height('100%')          // ✅ 用百分比，随父容器压缩
    .backgroundColor('#fff')
    // ✅ 绑定侧边栏浮层（不参与布局，不阻挡压缩）
    .bindContentCover(
      this.sidebarVisible,
      this.SidebarOverlay(),
      {
        modalTransition: ModalTransition.NONE,
        onDisappear: () => { this.sidebarVisible = false }
      }
    )
  }

  @Builder
  SidebarOverlay() {
    Row() {
      Sidebar({
        conversations: this.conversations,
        currentSessionId: this.currentSessionId,
        onSelect: (sid: string) => {
          this.selectConversation(sid)      // 包 {}，返回 void
        },
        onLogout: () => {
          this.logout()                     // 包 {}，返回 void
        }
      })
        .width('75%')
        .height('100%')

      Column()
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#00000060')
        .onClick(() => { this.sidebarVisible = false })
    }
    .width('100%')
    .height('100%')
  }
}