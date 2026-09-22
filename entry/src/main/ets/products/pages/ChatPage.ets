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
import { ImagePreview } from '../../common/ui/ImagePreview'
import { window } from '@kit.ArkUI'


@Entry
@Component
export struct ChatPage {
  onLogout: () => void = () => {}
  @State messages: ChatMessage[] = []
  @State conversations: Conversation[] = []
  @State inputText: string = ''
  @State loadingSessionId: string = ''
  @State currentSessionId: string = ''
  @State sidebarVisible: boolean = false
  @State attachedFiles: FileItem[] = []        // 文档附件
  @State attachedImages: FileItem[] = []       // 图片附件（新增）
  @State showAddMenu: boolean = false
  @Watch('onPreviewUrlChange')
  @State previewUrl: string = ''               // 空串 = 不显示预览

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
    return this.inputText.trim().length > 0
      || this.attachedFiles.length > 0
      || this.attachedImages.length > 0
  }

  aboutToAppear(): void { this.init() }


  /** previewUrl 变化时切换系统返回手势 */
  onPreviewUrlChange(): void {
    this.setGestureBackEnabled(this.previewUrl.length === 0)
  }

  private async setGestureBackEnabled(enabled: boolean): Promise<void> {
    try {
      const win = await window.getLastWindow(getContext(this))
      win.setGestureBackEnabled(enabled)
    } catch (e) {
      Logger.e('setGestureBackEnabled 失败: ' + (e as Error).message)
    }
  }

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
    // ← 新增这行，防止退出时手势还处于禁用状态
    this.setGestureBackEnabled(true)
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
    // 判断当前是否已经是新对话（没有消息）
    if (this.messages.length === 0) {
      promptAction.openToast({
        message: '已在新对话中',
        duration: 2000,
        alignment: Alignment.Bottom,
        offset: { dx: 0, dy: -1360 }
      })
      return
    }

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

  // ============================================================
  // 发送总入口
  //   - 有图片 / 文档 → sendAttachments（合并走 /process-file）
  //   - 纯文本        → sendStream
  // ============================================================
  send(): void {
    const text = this.inputText.trim()
    if (this.isLoadingNow()) return

    if (this.attachedImages.length > 0 || this.attachedFiles.length > 0) {
      this.sendAttachments(text)
      return
    }

    if (text.length === 0) return

    // ---- 纯文本发送 ----
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

  // ============================================================
  // 统一发送附件（图片 + 文档），复用后端 /agent/v1/process-file
  // 后端 FileService.process_files 会按扩展名自动分流处理
  //
  // 关于 text 的取值：
  //   ① 用户填了提示词 → 原文传
  //   ② 用户没填 + 有图片 → 传 "请提取图片中的文字"，
  //      命中后端 _process_image 的 OCR 关键词分支
  //   ③ 用户没填 + 只有文档 → 传空串，后端走"请概括"
  // ============================================================
  async sendAttachments(text: string): Promise<void> {
    if (this.isLoadingNow()) return

    const images = this.attachedImages
    const docs = this.attachedFiles
    this.attachedImages = []
    this.attachedFiles = []

    const allFiles: FileItem[] = [...images, ...docs]
    const hasImages = images.length > 0

    // ① 给后端的实际 text
    let backendText = text
    if (text.length === 0 && hasImages) {
      backendText = '请提取图片中的文字'
    }

    // ② 用户消息展示文本
    let displayText = text
    if (text.length === 0) {
      if (hasImages) {
        displayText = '请提取图片中的内容'
      } else {
        displayText = `已上传 ${allFiles.length} 个文件`
      }
    }

    this.messages.push(this.chatVM.createUserMessage(displayText, allFiles.map(f => f.name)))
    this.messages.push(this.chatVM.createAssistantPlaceholder())
    this.inputText = ''
    this.loadingSessionId = this.currentSessionId
    this.messages = [...this.messages]
    this.scrollToBottom()

    // ③ 复用 sendFiles（内部就是 /process-file 接口）
    const m = await this.chatVM.sendFiles(this.currentSessionId, backendText, allFiles)
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

  // ============================================================
  // 拍照 / 相册：只暂存，不立刻处理
  // ============================================================
  async onCameraOrAlbum(): Promise<void> {
    const files = await this.fileVM.pickImages(3)
    if (!files.length) return

    // 按 uri 去重（用户反复选同一张图时不重复添加）
    const exist = new Set(this.attachedImages.map(f => f.uri))
    const add = files.filter(f => !exist.has(f.uri))

    // 总量上限 9 张
    const maxCount = 9
    const total = this.attachedImages.length + add.length
    if (total > maxCount) {
      promptAction.openToast({ message: `最多选择 ${maxCount} 张图片` })
      this.attachedImages = [...this.attachedImages, ...add].slice(0, maxCount)
      return
    }
    this.attachedImages = [...this.attachedImages, ...add]
  }

  async onPickFile(): Promise<void> {
    this.attachedFiles = await this.fileVM.pickDocuments(3)
  }

  async logout(): Promise<void> {
    await this.authVM.logout()
    this.onLogout()
  }

  /** 删除单张已选图片 */
  private removeImageAt(index: number): void {
    const next = this.attachedImages.slice()
    next.splice(index, 1)
    this.attachedImages = next
  }

  scrollToBottom(): void { this.scroller.scrollEdge(Edge.Bottom) }

  build() {
    // 根节点 Stack：Column 是页面主体，ImagePreview 是最顶层的覆盖层
    Stack({ alignContent: Alignment.TopStart }) {
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

        // 消息区（Stack 叠加：列表 + 空态欢迎语）
        Stack({ alignContent: Alignment.Center }) {
          List({ scroller: this.scroller }) {
            ForEach(this.messages, (msg: ChatMessage) => {
              ListItem() {
                MessageItem({
                  msg: msg,
                  onAction: (t: string) => { this.handleAction(t, msg) },
                  onPreviewImage: (imageUrl: string) => {
                    this.previewUrl = imageUrl
                  }
                })
              }
            }, (msg: ChatMessage) => {
              const imgFlag = msg.imageBase64.length > 0 ? 'img' : 'no'
              return `${msg.id}_${msg.completed}_${msg.content.length}_${imgFlag}`
            })
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#fafafa')

          // 空态欢迎语：只在没有任何消息时显示
          if (this.messages.length === 0) {
            Column({ space: 12 }) {
              Text('你好，有什么我能帮你的吗？')
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor('#4b4b4b')
                .textAlign(TextAlign.Center)

              Text('我可以帮你解答问题、阅读文档、生成图片')
                .fontSize(14)
                .fontColor('#999999')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ left: 32, right: 32 })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .layoutWeight(1)
        .width('100%')

        // ============================================================
        // 图片附件条：缩略图 + 文件名 + 单个删除 + 清空
        // ============================================================
        if (this.attachedImages.length > 0) {
          Column() {
            Row() {
              Text(`已选择 ${this.attachedImages.length} 张图片`)
                .fontSize(12).fontColor('#666').layoutWeight(1)
              Text('清空').fontSize(12).fontColor('#e74c3c')
                .onClick(() => { this.attachedImages = [] })
            }
            .width('100%')
            .margin({ bottom: 6 })

            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.attachedImages, (f: FileItem, idx: number) => {
                  Stack({ alignContent: Alignment.TopEnd }) {
                    Column({ space: 4 }) {
                      // ⚠️ 若 FileItem 的图片路径字段不叫 uri，改成你的字段名
                      Image(f.uri)
                        .width(60).height(60)
                        .borderRadius(6)
                        .objectFit(ImageFit.Cover)
                        .backgroundColor('#eee')

                      Text(f.name)
                        .fontSize(10)
                        .fontColor('#666')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width(60)
                        .textAlign(TextAlign.Center)
                    }
                    .padding(4)
                    .backgroundColor(Color.White)
                    .borderRadius(8)

                    // 单个删除按钮
                    Text('✕')
                      .fontSize(11)
                      .fontColor(Color.White)
                      .width(16).height(16)
                      .textAlign(TextAlign.Center)
                      .borderRadius(8)
                      .backgroundColor('#00000099')
                      .margin({ top: -4, right: -4 })
                      .onClick(() => this.removeImageAt(idx))
                  }
                  .width(72).height(92)
                }, (f: FileItem, idx: number) => `${f.uri}_${idx}`)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#fff9e6')
          .alignItems(HorizontalAlign.Start)
        }

        // 文档附件条（紧贴输入栏上方）
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
      .height('100%')
      .backgroundColor('#fff')
      .bindContentCover(
        this.sidebarVisible,
        this.SidebarOverlay(),
        {
          modalTransition: ModalTransition.NONE,
          onDisappear: () => { this.sidebarVisible = false }
        }
      )

      // 全屏图片预览：根 Stack 的最后一个子节点，覆盖整页（含输入栏）
      if (this.previewUrl.length > 0) {
        ImagePreview({
          url: this.previewUrl,
          onClose: () => {
            this.previewUrl = ''
          }
        })
          .width('100%')
          .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  //====================

  @Builder
  SidebarOverlay() {
    Row() {
      Sidebar({
        conversations: this.conversations,
        currentSessionId: this.currentSessionId,
        onSelect: (sid: string) => {
          this.selectConversation(sid)
        },
        onLogout: () => {
          this.logout()
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