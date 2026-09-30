import http from '@ohos.net.http'
import pasteboard from '@ohos.pasteboard'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'   // ⭐ 新增

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
import { SessionManager } from '../../core/session/SessionManager'
// ⭐ 阶段 3 新增
import { RouteNames } from '../../core/router/RouteNames'
import { ImageEditorParams, ImageEditorResult, IMAGE_EDITOR_DONE_EVENT } from '../imageeditor/models/ImageEditorParams'
import { ImageActionDialog } from '../../common/ui/ImageActionDialog'
import { ChatUseCase } from './ChatUseCase'
import { VoiceRecorderService } from '../../common/voice/VoiceRecorderService'
import { VoicePlayerService } from '../../common/voice/VoicePlayerService'
import { AsrService } from '../../common/voice/AsrService'
import { TtsService } from '../../common/voice/TtsService'
import { ensureMicPermission } from '../../common/voice/VoicePermission'
import { RecordPanelState } from '../../common/ui/VoiceRecordPanel'
import { VoiceRecordResult } from '../../common/voice/VoiceRecorderService'
import { DownloadUtil } from '../../common/utils/DownloadUtil'

/** ⭐ 一个"进行中的对话回合"：用户消息 + 助手占位（两者都持有引用） */
interface PendingTurn {
  user: ChatMessage
  assistant: ChatMessage
}


@Component
export struct ChatPage {

  // ⭐ 拿到全局路由栈（AppShell 里 @Provide 的）
  @Consume('navStack') navStack: NavPathStack

  @State messages: ChatMessage[] = []
  @State conversations: Conversation[] = []
  @State inputText: string = ''
  @State loadingSessionId: string = ''
  @State currentSessionId: string = ''
  @State sidebarVisible: boolean = false
  @State attachedFiles: FileItem[] = []
  @State attachedImages: FileItem[] = []
  @State showAddMenu: boolean = false
  @Watch('onPreviewUrlChange')
  @State previewUrl: string = ''

  // ⭐ 语音相关
  @State private isVoiceMode: boolean = false
  @State private recordState: RecordPanelState = RecordPanelState.IDLE
  @State private recordDuration: number = 0
  @State private partialText: string = ''
  @State private playingMsgId: string = ''
  @State private aiReadingId: string = ''      // 正在 TTS 播报的 assistant 消息 id

  private recorder: VoiceRecorderService = new VoiceRecorderService()
  private player: VoicePlayerService = new VoicePlayerService()
  private asr: AsrService = new AsrService()
  private tts: TtsService = new TtsService()
  private recordTimer: number = 0
  private voiceClientId: string = ''           // 本次语音的 clientId（松手时生成）
  private voiceTriggeredAsr: boolean = false
  // ⭐ 语音竞态保护
  private voiceStarting: boolean = false
  private voicePendingEnd: boolean | null = null   // null=无挂起, false=松手发送, true=松手取消
  private readingTimer: number = 0      // ⭐ TTS 朗读估算定时器


  private scroller: Scroller = new Scroller()
  private currentRequest: http.HttpRequest | null = null

  private chatVM: ChatViewModel = new ChatViewModel(getContext(this))
  private conversationVM = new ConversationViewModel()
  // ⭐ 构造时注入 ctx（cameraPicker 需要）
  private fileVM: FileViewModel = new FileViewModel(getContext(this) as common.Context)
  private authVM = new AuthViewModel()
  private editorListenerBound: boolean = false
  private imageActionDialog: CustomDialogController | null = null

  // ⭐ 每个会话正在生成的"对话回合"（key = sessionId）
  private pendingTurns: Map<string, PendingTurn> = new Map()

  // ⭐ 每个会话的超时定时器
  private pendingTimeouts: Map<string, number> = new Map()

  // ⭐ 当前会话是否有未完成的请求（用于 UI 响应式）
  @State private currentIsPending: boolean = false
  // ⭐ 正在加载历史的会话 id（非空 = 显示加载遮罩）
  @State private switchingSessionId: string = ''
  // ⭐ 超时时长：30 分钟
  private static readonly REQUEST_TIMEOUT_MS = 30 * 60 * 1000


  private isLoadingNow(): boolean {
    return this.loadingSessionId.length > 0 && this.loadingSessionId === this.currentSessionId
  }

  private isCanSend(): boolean {
    return this.inputText.trim().length > 0
      || this.attachedFiles.length > 0
      || this.attachedImages.length > 0
  }

  aboutToAppear(): void {
    this.bindEditorListener()
    this.init()
  }

  aboutToDisappear(): void {
    this.unbindEditorListener()
  }

  private unbindEditorListener(): void {
    if (!this.editorListenerBound) return
    getContext(this).eventHub.off(IMAGE_EDITOR_DONE_EVENT, this.onImageEdited)
    this.editorListenerBound = false
  }

  /** ⭐ 监听图片编辑器完成事件 */
  private bindEditorListener(): void {
    if (this.editorListenerBound) return
    getContext(this).eventHub.on(IMAGE_EDITOR_DONE_EVENT, this.onImageEdited)
    this.editorListenerBound = true
  }

  /** ⭐ 编辑完成：把新图加入附件条 */
  private onImageEdited = (result: ImageEditorResult): void => {
    Logger.i(`[ChatPage] 收到编辑结果 uri=${result.uri}`)
    const item: FileItem = { name: result.name, uri: result.uri }
    this.attachedImages = [...this.attachedImages, item]
    promptAction.openToast({ message: '已添加到待发送' })
  }


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

  onPageShow(): void {
    Logger.i('[ChatPage] onPageShow：根据 pendingTurns 恢复 UI 状态')
    const turn = this.pendingTurns.get(this.currentSessionId)
    if (turn) {
      this.currentIsPending = true
      this.loadingSessionId = this.currentSessionId
    } else {
      this.currentIsPending = false
      this.loadingSessionId = ''
    }
  }

  onPageHide(): void {
    Logger.i('[ChatPage] onPageHide：进入后台，保留请求与 pending 状态')
    this.setGestureBackEnabled(true)
    // ⭐ 如果后台时还在录音，取消掉
    if (this.recorder.isRecording()) {
      this.recorder.cancel().catch(() => { /* ignore */ })
    }
    if (this.recordTimer) {
      clearInterval(this.recordTimer)
      this.recordTimer = 0
    }
    // ⭐ 清理 TTS 定时器
    if (this.readingTimer) {
      clearTimeout(this.readingTimer)
      this.readingTimer = 0
    }
    this.aiReadingId = ''
    this.voiceStarting = false
    this.voicePendingEnd = null
  }


  async init(): Promise<void> {
    await this.loadConversations()
    if (this.conversations.length > 0) {
      await this.selectConversation(this.conversations[0].sessionId)
    } else {
      const sid = await this.conversationVM.createNew()
      if (sid) {
        this.currentSessionId = sid
        this.messages = []
        await this.loadConversations()
      }
    }
  }

  async loadConversations(): Promise<void> {
    this.conversations = await this.conversationVM.loadList()
  }

  async newConversation(force: boolean = false): Promise<void> {
    if (!force && this.messages.length === 0) {
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
    this.currentIsPending = false
    this.loadingSessionId = ''
    await this.loadConversations()
  }

  async selectConversation(sessionId: string): Promise<void> {
    Logger.i(`[ChatPage] selectConversation 入参 sessionId=${sessionId}`)

    this.currentSessionId = sessionId
    this.chatVM.setSessionId(sessionId)
    this.sidebarVisible = false

    this.switchingSessionId = sessionId

    try {
      const remote = await this.conversationVM.loadHistory(sessionId)

      if (this.currentSessionId !== sessionId) {
        Logger.e(`[ChatPage] selectConversation 过期返回，丢弃: ${sessionId}`)
        return
      }

      const list: ChatMessage[] = remote ? [...remote] : []

      const turn = this.pendingTurns.get(sessionId)
      if (turn) {
        if (!this._serverHasUserMsg(list, turn)) {          // ⭐ 改这里
          list.push(turn.user)
          Logger.i(`[ChatPage] ${sessionId} 补回本地 user 消息`)
        } else {
          Logger.i(`[ChatPage] ${sessionId} 服务端已有 user 消息，跳过补回`)
        }
        if (list.indexOf(turn.assistant) < 0) {
          list.push(turn.assistant)
          Logger.i(`[ChatPage] ${sessionId} 补回本地 assistant 占位`)
        }
        this.currentIsPending = true
        this.loadingSessionId = sessionId
      } else {
        this.currentIsPending = false
        this.loadingSessionId = ''
      }

      this.messages = list
      this.scrollToBottom()
    } catch (e) {
      Logger.e(`[ChatPage] loadHistory 失败: ${(e as Error).message}`)
    } finally {
      if (this.switchingSessionId === sessionId) {
        this.switchingSessionId = ''
      }
    }
  }

  handleSubmit(): void {
    if (this.isLoadingNow()) return
    if (!this.isCanSend()) {
      promptAction.openToast({ message: '请输入内容或选择文件' })
      return
    }
    this.send()
  }

  async send(): Promise<void> {
    const text = this.inputText.trim()
    if (this.isLoadingNow()) return

    if (this.attachedImages.length > 0 || this.attachedFiles.length > 0) {
      this.sendAttachments(text)
      return
    }
    if (text.length === 0) return

    const requestSessionId = this.currentSessionId
    const clientId = this.chatVM.genClientId()      // ⭐

    const userMsg = this.chatVM.createUserMessage(text, undefined, clientId)
    this.messages.push(userMsg)
    const assistantMsg = this.chatVM.createAssistantPlaceholder()
    this.messages.push(assistantMsg)

    this._startRequest(requestSessionId, userMsg, assistantMsg)

    this.inputText = ''
    this.loadingSessionId = requestSessionId
    this.messages = [...this.messages]
    this.scrollToBottom()

    try {
      this.currentRequest = await this.chatVM.sendStream({
        text,
        sessionId: requestSessionId,
        clientId,
        assistantMsg,
        onRefresh: () => {
          if (this.currentSessionId === requestSessionId) {
            if (this.messages.indexOf(assistantMsg) < 0) {
              this.messages.push(assistantMsg)
            }
            this.messages = [...this.messages]
            this.scrollToBottom()
          }
        },
        onScroll: () => {
          if (this.currentSessionId === requestSessionId) {
            this.scrollToBottom()
          }
        },
        // ⭐ 新增：服务端落库完成，就地更新本地消息
        onDone: (info) => {
          Logger.i(`[ChatPage] onDone msgId=${info.messageId} duration=${info.durationMs}ms`)
          if (this.currentSessionId === requestSessionId) {
            if (info.durationMs > 0) {
              assistantMsg.duration = Math.round(info.durationMs / 1000)
            }
            assistantMsg.completed = true
            this.messages = [...this.messages]
            this.scrollToBottom()
          }
        },
        onFinish: () => {
          this.loadingSessionId = ''
          this._finishRequest(requestSessionId)
          this.loadConversations()
          // ⭐ 不再轮询
        },
        onSessionIdChange: (sid: string) => {
          this._handleSessionIdChange(sid, requestSessionId)
        }
      })
    } catch (e) {
      Logger.e('sendStream 失败: ' + (e as Error).message)
      this.loadingSessionId = ''
      this._finishRequest(requestSessionId)
    }
  }

  async sendAttachments(text: string): Promise<void> {
    Logger.i(`[ChatPage] sendAttachments 发送前 currentSessionId=${this.currentSessionId}`)
    if (this.isLoadingNow()) return

    const requestSessionId = this.currentSessionId
    const clientId = this.chatVM.genClientId()      // ⭐

    const images = this.attachedImages
    const docs = this.attachedFiles
    this.attachedImages = []
    this.attachedFiles = []

    const allFiles: FileItem[] = [...images, ...docs]
    const hasImages = images.length > 0

    let backendText = text
    if (text.length === 0 && hasImages) {
      backendText = '请提取图片中的文字'
    }

    let displayText = text
    if (text.length === 0) {
      if (hasImages) {
        displayText = '请提取图片中的内容'
      } else {
        displayText = `已上传 ${allFiles.length} 个文件`
      }
    }

    const userMsg = this.chatVM.createUserMessage(displayText, allFiles.map(f => f.name), clientId)
    this.messages.push(userMsg)
    const assistantMsg = this.chatVM.createAssistantPlaceholder()
    this.messages.push(assistantMsg)

    this._startRequest(requestSessionId, userMsg, assistantMsg)

    this.inputText = ''
    this.loadingSessionId = requestSessionId
    this.messages = [...this.messages]
    this.scrollToBottom()

    try {
      this.currentRequest = await this.chatVM.sendFilesStream(
        requestSessionId,
        backendText,
        allFiles,
        clientId,
        assistantMsg,
        () => {
          if (this.currentSessionId === requestSessionId) {
            if (this.messages.indexOf(assistantMsg) < 0) {
              this.messages.push(assistantMsg)
            }
            this.messages = [...this.messages]
            this.scrollToBottom()
          }
        },
        // ⭐ 新增 onDone
        (info) => {
          Logger.i(`[ChatPage] sendFiles onDone msgId=${info.messageId} duration=${info.durationMs}ms`)
          if (this.currentSessionId === requestSessionId) {
            if (info.durationMs > 0) {
              assistantMsg.duration = Math.round(info.durationMs / 1000)
            }
            assistantMsg.completed = true
            this.messages = [...this.messages]
          }
        },
        () => {
          this.loadingSessionId = ''
          this._finishRequest(requestSessionId)
          this.loadConversations()
        },
      )
    } catch (e) {
      Logger.e('sendFilesStream 失败: ' + (e as Error).message)
      this.loadingSessionId = ''
      this._finishRequest(requestSessionId)
      if (assistantMsg.content.length === 0) {
        assistantMsg.content = `[上传失败: ${(e as Error).message}]`
      }
      assistantMsg.completed = true
      this.messages = [...this.messages]
    }
  }

  async regenerate(userMsg: ChatMessage): Promise<void> {
    Logger.i(`[ChatPage] regenerate 发送前 currentSessionId=${this.currentSessionId}`)
    if (this.isLoadingNow()) return
    const text = userMsg.content
    if (!text) return

    const requestSessionId = this.currentSessionId
    const clientId = this.chatVM.genClientId()      // ⭐

    const newUserMsg = this.chatVM.createUserMessage(text, userMsg.files, clientId)
    this.messages.push(newUserMsg)
    const assistantMsg = this.chatVM.createAssistantPlaceholder()
    this.messages.push(assistantMsg)
    this.messages = [...this.messages]

    this._startRequest(requestSessionId, newUserMsg, assistantMsg)

    this.loadingSessionId = requestSessionId
    this.scrollToBottom()

    try {
      this.currentRequest = await this.chatVM.sendStream({
        text,
        sessionId: requestSessionId,
        clientId,
        assistantMsg,
        onRefresh: () => {
          if (this.currentSessionId === requestSessionId) {
            if (this.messages.indexOf(assistantMsg) < 0) {
              this.messages.push(assistantMsg)
            }
            this.messages = [...this.messages]
            this.scrollToBottom()
          }
        },
        onScroll: () => {
          if (this.currentSessionId === requestSessionId) {
            this.scrollToBottom()
          }
        },
        // ⭐ 新增：服务端落库完成，就地更新本地消息
        onDone: (info) => {
          Logger.i(`[ChatPage] onDone msgId=${info.messageId} duration=${info.durationMs}ms`)
          if (this.currentSessionId === requestSessionId) {
            if (info.durationMs > 0) {
              assistantMsg.duration = Math.round(info.durationMs / 1000)
            }
            assistantMsg.completed = true
            this.messages = [...this.messages]
            this.scrollToBottom()
          }
        },
        onFinish: () => {
          this.loadingSessionId = ''
          this._finishRequest(requestSessionId)
          this.loadConversations()
          // ⭐ 不再轮询
        },
        onSessionIdChange: (sid: string) => {
          this._handleSessionIdChange(sid, requestSessionId)
        }
      })
    } catch (e) {
      Logger.e('regenerate sendStream 失败: ' + (e as Error).message)
      this.loadingSessionId = ''
      this._finishRequest(requestSessionId)
    }
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

  /** ⭐ 处理 PPT 等文件下载 */
  private async handleDownload(relativeUrl: string): Promise<void> {
    const filename = relativeUrl.split('/').pop() || `file_${Date.now()}`
    Logger.i(`[ChatPage] 开始下载: ${relativeUrl} → ${filename}`)

    promptAction.openToast({ message: '正在下载…' })

    try {
      const saved = await DownloadUtil.downloadAndSave(relativeUrl, filename)
      if (saved) {
        promptAction.openToast({ message: '已保存' })
      }
      // 用户取消保存：静默返回，不提示
    } catch (e) {
      promptAction.openToast({ message: `下载失败: ${(e as Error).message}` })
    }
  }


  handleAction(type: string, msg: ChatMessage): void {
    if (type === MessageActionType.COPY) this.copyMessage(msg)
    else if (type === MessageActionType.REGENERATE) this.regenerate(msg)
    else if (type === MessageActionType.SHARE) promptAction.openToast({ message: '分享开发中' })
  }

  async onCameraOrAlbum(): Promise<void> {
    const files = await this.fileVM.pickImages(3)
    if (!files.length) return

    if (files.length === 1) {
      this.askEditOrUse(files[0])
      return
    }

    this.appendImages(files)
  }

  // ⭐ 新增：拍照入口
  async onTakePhoto(): Promise<void> {
    const file = await this.fileVM.capturePhoto()
    if (!file) return
    // 复用图库的"编辑 / 直接使用"对话框
    this.askEditOrUse(file)
  }

  /** ⭐ 弹自定义对话框：编辑后上传 / 直接使用 */
  private askEditOrUse(file: FileItem): void {
    this.imageActionDialog = new CustomDialogController({
      builder: ImageActionDialog({
        fileName: file.name,
        onEdit: () => {
          this.navStack.pushPath({
            name: RouteNames.IMAGE_EDITOR,
            param: { uri: file.uri, name: file.name } as ImageEditorParams
          })
        },
        onUse: () => {
          this.appendImages([file])
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.imageActionDialog.open()
  }

  /** ⭐ 统一的"加入附件条"逻辑（带去重 + 上限） */
  private appendImages(files: FileItem[]): void {
    const exist = new Set(this.attachedImages.map(f => f.uri))
    const add = files.filter(f => !exist.has(f.uri))

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
    try {
      await this.authVM.logout()
    } catch (e) {
      Logger.e(`[ChatPage] 后端登出失败: ${(e as Error).message}`)
    }
    SessionManager.logout()
  }

  private removeImageAt(index: number): void {
    const next = this.attachedImages.slice()
    next.splice(index, 1)
    this.attachedImages = next
  }

  scrollToBottom(): void { this.scroller.scrollEdge(Edge.Bottom) }

  private _startRequest(sessionId: string, userMsg: ChatMessage, assistantMsg: ChatMessage): void {
    Logger.i(`[ChatPage] _startRequest sessionId=${sessionId}`)
    this.pendingTurns.set(sessionId, { user: userMsg, assistant: assistantMsg })

    const old = this.pendingTimeouts.get(sessionId)
    if (old !== undefined) clearTimeout(old)

    const timer = setTimeout(() => {
      Logger.e(`[ChatPage] 请求超时: ${sessionId}`)
      this._finishRequest(sessionId)
      if (this.currentSessionId === sessionId) {
        this._reloadMessages(sessionId)
      }
    }, ChatPage.REQUEST_TIMEOUT_MS)
    this.pendingTimeouts.set(sessionId, timer)

    if (sessionId === this.currentSessionId) {
      this.currentIsPending = true
    }
  }

  private _finishRequest(sessionId: string): void {
    Logger.i(`[ChatPage] _finishRequest sessionId=${sessionId}`)
    this.pendingTurns.delete(sessionId)

    const timer = this.pendingTimeouts.get(sessionId)
    if (timer !== undefined) {
      clearTimeout(timer)
      this.pendingTimeouts.delete(sessionId)
    }

    if (sessionId === this.currentSessionId) {
      this.currentIsPending = false
    }
  }

  private _handleSessionIdChange(sid: string, requestSessionId: string): void {
    if (sid === requestSessionId) return

    const turn = this.pendingTurns.get(requestSessionId)
    if (turn) {
      this.pendingTurns.delete(requestSessionId)
      this.pendingTurns.set(sid, turn)
    }
    const timer = this.pendingTimeouts.get(requestSessionId)
    if (timer !== undefined) {
      this.pendingTimeouts.delete(requestSessionId)
      this.pendingTimeouts.set(sid, timer)
    }

    if (this.currentSessionId === requestSessionId) {
      this.currentSessionId = sid
      this.chatVM.setSessionId(sid)
      if (this.loadingSessionId === requestSessionId) {
        this.loadingSessionId = sid
      }
    }
    Logger.i(`[ChatPage] session_id 兜底更新为: ${sid}，当前 UI 会话=${this.currentSessionId}`)
  }


  /**
   * ⭐ 判断 list 中是否已经包含 turn.user 这条消息
   * 有 clientId：严格比对 clientId，100% 准确
   * 无 clientId（老数据）：退化为 role+content 严格相等
   */
  private _serverHasUserMsg(list: ChatMessage[], turn: PendingTurn): boolean {
    const cid = turn.user.clientId
    if (!cid) {
      return list.some((m: ChatMessage) =>
      m.role === turn.user.role &&
        (m.content || '').trim() === (turn.user.content || '').trim())
    }
    return list.some((m: ChatMessage) => m.role === 'user' && m.clientId === cid)
  }


  private async _reloadMessages(sessionId: string): Promise<void> {
    try {
      const remote = await this.conversationVM.loadHistory(sessionId)
      if (this.currentSessionId !== sessionId) return

      if ((!remote || remote.length === 0) && this.messages.length > 0) {
        Logger.e(`[ChatPage] _reloadMessages 服务端返回空，保留本地消息`)
        return
      }

      const list: ChatMessage[] = remote ? [...remote] : []
      const turn = this.pendingTurns.get(sessionId)
      if (turn) {
        if (!this._serverHasUserMsg(list, turn)) {          // ⭐ 改这里
          list.push(turn.user)
        }
        if (list.indexOf(turn.assistant) < 0) list.push(turn.assistant)
      }
      this.messages = list
      this.currentIsPending = turn !== undefined
      this.scrollToBottom()
    } catch (e) {
      Logger.e(`[ChatPage] 重新拉消息失败: ${(e as Error).message}`)
    }
  }

  // ============ 语音交互 ============

  private async onVoiceRequestPermission(): Promise<boolean> {
    const ctx = getContext(this) as common.UIAbilityContext
    return await ensureMicPermission(ctx)
  }

  private async onVoicePressStart(): Promise<void> {
    // ⭐ 竞态保护：正在启动中 or 已在录音，拒绝重入
    if (this.voiceStarting || this.recorder.isRecording()) {
      Logger.e(`[Voice] 忽略重复 start: starting=${this.voiceStarting} recording=${this.recorder.isRecording()}`)
      return
    }
    this.voiceStarting = true

    const ctx = getContext(this) as common.UIAbilityContext

    // 1) 启动 ASR
    try {
      this.voiceTriggeredAsr = await this.asr.start((partial: string) => {
        this.partialText = partial
      })
    } catch (e) {
      this.voiceTriggeredAsr = false
      Logger.e(`[Voice] asr.start 异常: ${(e as Error).message}`)
    }

    // 2) 启动录音
    const ok = await this.recorder.start(ctx, (pcm: Uint8Array) => {
      if (this.voiceTriggeredAsr) this.asr.writeAudio(pcm)
    })

    this.voiceStarting = false

    if (!ok) {
      promptAction.openToast({ message: '录音启动失败' })
      if (this.voiceTriggeredAsr) {
        try { await this.asr.cancel() } catch (_) { /* ignore */ }
        this.voiceTriggeredAsr = false
      }
      this.recordState = RecordPanelState.IDLE
      this.recordDuration = 0
      this.partialText = ''
      return
    }

    // ⭐ 3) 如果松手发生在 start 完成前，立刻处理挂起的结束请求
    if (this.voicePendingEnd !== null) {
      const isCancel = this.voicePendingEnd
      this.voicePendingEnd = null
      Logger.i(`[Voice] start 完成后立即执行挂起的 end(cancel=${isCancel})`)
      await this.onVoicePressEnd(isCancel)
      return
    }

    // 4) 正常计时
    this.recordDuration = 0
    this.recordTimer = setInterval(() => {
      this.recordDuration += 1
      if (this.recordDuration >= 60) {
        Logger.e('[Voice] 达到 60 秒上限，自动结束')
        this.onVoicePressEnd(false)
      }
    }, 1000)
  }

  private async onVoicePressEnd(isCancel: boolean): Promise<void> {
    // ⭐ 竞态保护：如果 start 还在跑，挂起请求
    if (this.voiceStarting) {
      this.voicePendingEnd = isCancel
      Logger.i(`[Voice] start 进行中，挂起 end(cancel=${isCancel})`)
      return
    }

    // 清计时器
    if (this.recordTimer) {
      clearInterval(this.recordTimer)
      this.recordTimer = 0
    }

    if (isCancel) {
      await this.recorder.cancel()
      if (this.voiceTriggeredAsr) {
        try { await this.asr.cancel() } catch (_) { /* ignore */ }
      }
      this.voiceTriggeredAsr = false
      this.recordState = RecordPanelState.IDLE
      this.recordDuration = 0
      this.partialText = ''
      Logger.i('[Voice] 用户取消录音')
      return
    }

    // 停止录音
    const result = await this.recorder.stop()
    if (!result) {
      // ⭐ 太短或未开始
      promptAction.openToast({ message: '说话时间太短' })
      if (this.voiceTriggeredAsr) {
        try { await this.asr.cancel() } catch (_) { /* ignore */ }
      }
      this.voiceTriggeredAsr = false
      this.recordState = RecordPanelState.IDLE
      this.recordDuration = 0
      this.partialText = ''
      return
    }

    // 等 ASR 最终结果
    const asrText = this.voiceTriggeredAsr ? await this.asr.finish() : ''
    this.voiceTriggeredAsr = false
    this.recordState = RecordPanelState.IDLE
    this.recordDuration = 0
    this.partialText = ''

    this.voiceClientId = this.chatVM.genClientId()
    await this.sendVoice(result, asrText)
  }

  /** 发送语音消息：气泡展示用语音，agent 交互用 ASR 文本 */
  private async sendVoice(result: VoiceRecordResult, asrText: string): Promise<void> {
    const requestSessionId = this.currentSessionId
    const clientId = this.voiceClientId

    // 用 ASR 文本作为发给 agent 的文本
    const textForAgent = asrText && asrText.length > 0 ? asrText : '[语音消息]'
    const displayText = textForAgent       // 消息记录里同时保存文本（供后续使用）

    // ⭐ user 消息：标记为语音
    const userMsg = this.chatVM.createUserMessage(displayText, undefined, clientId)
    userMsg.isVoice = true
    userMsg.voicePath = result.path
    userMsg.voiceDuration = result.duration
    this.messages.push(userMsg)

    const assistantMsg = this.chatVM.createAssistantPlaceholder()
    this.messages.push(assistantMsg)

    this._startRequest(requestSessionId, userMsg, assistantMsg)
    this.loadingSessionId = requestSessionId
    this.messages = [...this.messages]
    this.scrollToBottom()

    try {
      this.currentRequest = await this.chatVM.sendStream({
        text: textForAgent,
        sessionId: requestSessionId,
        clientId,
        assistantMsg,
        onRefresh: () => {
          if (this.currentSessionId === requestSessionId) {
            if (this.messages.indexOf(assistantMsg) < 0) {
              this.messages.push(assistantMsg)
            }
            this.messages = [...this.messages]
            this.scrollToBottom()
          }
        },
        onScroll: () => {
          if (this.currentSessionId === requestSessionId) {
            this.scrollToBottom()
          }
        },
        onDone: (info) => {
          if (this.currentSessionId === requestSessionId) {
            if (info.durationMs > 0) {
              assistantMsg.duration = Math.round(info.durationMs / 1000)
            }
            assistantMsg.completed = true
            this.messages = [...this.messages]
            this.scrollToBottom()
            // ⭐ AI 回复完成，触发 TTS 播报
            // this.triggerTtsRead(assistantMsg)
          }
        },
        onFinish: () => {
          this.loadingSessionId = ''
          this._finishRequest(requestSessionId)
          this.loadConversations()
        },
        onSessionIdChange: (sid: string) => {
          this._handleSessionIdChange(sid, requestSessionId)
        }
      })
    } catch (e) {
      Logger.e('[Chat] sendVoice failed: ' + (e as Error).message)
      this.loadingSessionId = ''
      this._finishRequest(requestSessionId)
    }
  }

  // ============ 语音消息播放 ============

  private async playVoice(msg: ChatMessage): Promise<void> {
    if (!msg.voicePath) return
    if (this.playingMsgId === msg.id) {
      // 正在播这条 → 停止
      await this.player.stop()
      this.playingMsgId = ''
      return
    }
    this.playingMsgId = msg.id
    await this.player.play(msg.voicePath, () => {
      this.playingMsgId = ''
    })
  }

  // ============ AI 回复 TTS 播报 ============

  private async triggerTtsRead(msg: ChatMessage): Promise<void> {
    if (!msg.content) return

    // 先停掉上一条
    await this.stopTtsRead()

    // UI 立刻变红
    this.aiReadingId = msg.id

    try {
      // ⭐ await 到"播完 / 失败 / 被停止"
      await this.tts.speak(msg.content)
    } catch (e) {
      Logger.e(`[ChatPage] TTS 失败: ${(e as Error).message}`)
    }

    // ⭐ 自然结束或出错都清空
    if (this.aiReadingId === msg.id) {
      this.aiReadingId = ''
    }
  }

  private async stopTtsRead(): Promise<void> {
    // ⭐ UI 立刻变回"朗读"
    this.aiReadingId = ''
    await this.tts.stop()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // 顶栏
        Row() {
          Text('☰').fontSize(22).padding(12)
            .onClick(() => { this.sidebarVisible = !this.sidebarVisible })
          Text('AI 智能助手').fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1)

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

        // ⭐ AI 正在朗读时的浮动停止按钮
        if (this.aiReadingId.length > 0) {
          Row({ space: 6 }) {
            Text('⏹').fontSize(14).fontColor(Color.White)
            Text('停止朗读').fontSize(13).fontColor(Color.White)
          }
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#4a90e2')
          .borderRadius(20)
          .position({ x: '50%', y: '90%' })
          .translate({ x: '-50%' })
          .onClick(() => this.stopTtsRead())
        }

        // 消息区
        Stack({ alignContent: Alignment.Center }) {
          List({ scroller: this.scroller }) {
            ForEach(this.messages, (msg: ChatMessage) => {
              ListItem() {
                MessageItem({
                  msg: msg,
                  isVoicePlaying: this.playingMsgId === msg.id,
                  isAiReading: this.aiReadingId === msg.id,
                  onVoicePlay: () => this.playVoice(msg),
                  onVoiceStop: () => this.playVoice(msg),
                  // ⭐ 统一开关
                  onToggleAiReading: () => {
                    if (this.aiReadingId === msg.id) {
                      this.stopTtsRead()
                    } else {
                      this.triggerTtsRead(msg)
                    }
                  },
                  onDownload: (url: string) => this.handleDownload(url),
                  onAction: (t: string) => { this.handleAction(t, msg) },
                  onPreviewImage: (imageUrl: string) => {
                    this.previewUrl = imageUrl
                  }
                })
              }
            }, (msg: ChatMessage) => {
              const imgFlag = msg.imageBase64.length > 0 ? 'img'
                : (msg.thumbUrl && msg.thumbUrl.length > 0 ? 'thumb' : 'no')
              // ⭐ 把"朗读中/播放中"塞进 key，状态变则 key 变 → UI 强制刷新
              const readingFlag = this.aiReadingId === msg.id ? 'R' : 'N'
              const playingFlag = this.playingMsgId === msg.id ? 'P' : 'N'
              // ⭐ 加 dlFlag，让 [DL:...] 到达时触发重建
              const dlFlag = msg.content.indexOf('[DL:') >= 0 ? 'D' : 'N'
              return `${msg.id}_${msg.completed}_${msg.content.length}_${imgFlag}_${readingFlag}_${playingFlag}`
            })
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#fafafa')

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

          if (this.switchingSessionId.length > 0) {
            Column({ space: 10 }) {
              LoadingProgress()
                .width(36)
                .height(36)
                .color('#666666')

              Text('正在加载会话…')
                .fontSize(13)
                .fontColor('#999999')
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#fafafaee')
          }
        }
        .layoutWeight(1)
        .width('100%')

        // 图片附件条
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
                      Image(f.uri)
                        .width(60).height(60)
                        .borderRadius(6)
                        .objectFit(ImageFit.Cover)
                        .backgroundColor('#eee')
                        .onClick(() => {
                          this.previewUrl = f.uri
                        })

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

        // 文档附件条
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

          // ⭐ 语音模式相关
          isVoiceMode: this.isVoiceMode,
          recordState: this.recordState,
          recordDuration: this.recordDuration,
          partialText: this.partialText,
          onToggleVoiceMode: () => {
            this.isVoiceMode = !this.isVoiceMode
            this.showAddMenu = false
          },
          onVoicePressStart: () => { this.onVoicePressStart() },
          onVoicePressEnd: (cancel: boolean) => { this.onVoicePressEnd(cancel) },
          onVoiceRequestPermission: () => this.onVoiceRequestPermission(),

          onSend: () => this.handleSubmit(),
          onToggleAddMenu: () => { this.showAddMenu = !this.showAddMenu },
          onVoice: () => { this.isVoiceMode = true },
          onCamera: () => { this.showAddMenu = false; this.onTakePhoto() },
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