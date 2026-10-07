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
import { SessionManager } from '../../core/session/SessionManager'
import { RouteNames } from '../../core/router/RouteNames'
import { ImageEditorParams, ImageEditorResult, IMAGE_EDITOR_DONE_EVENT } from '../imageeditor/models/ImageEditorParams'
import { ImageActionDialog } from '../../common/ui/ImageActionDialog'
import { VoiceRecorderService } from '../../common/voice/VoiceRecorderService'
import { VoicePlayerService } from '../../common/voice/VoicePlayerService'
import { AsrService } from '../../common/voice/AsrService'
import { TtsService } from '../../common/voice/TtsService'
import { ensureMicPermission } from '../../common/voice/VoicePermission'
import { RecordPanelState } from '../../common/ui/VoiceRecordPanel'
import { VoiceRecordResult } from '../../common/voice/VoiceRecorderService'
import { DownloadUtil } from '../../common/utils/DownloadUtil'
import { common, Want } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
// ⭐ 新增
import { FileApi } from '../../data/services/FileApi'
import { ServiceRouter } from '../../common/network/ServiceRouter'
import { AttachmentRefDto } from '../../data/dto/Types'
import { parseCard, ChatCard, CardType, FaceSwapTaskItem } from '../../domain/models/ChatCard'
import { UploadAssetRespDto } from '../../data/dto/Types'

interface PendingTurn {
  user: ChatMessage
  assistant: ChatMessage
}


@Component
export struct ChatPage {

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

  // 语音相关
  @State private isVoiceMode: boolean = false
  @State private recordState: RecordPanelState = RecordPanelState.IDLE
  @State private recordDuration: number = 0
  @State private partialText: string = ''
  @State private playingMsgId: string = ''
  @State private aiReadingId: string = ''
  @State private jobProgressMap: Map<string, number> = new Map()

  private recorder: VoiceRecorderService = new VoiceRecorderService()
  private player: VoicePlayerService = new VoicePlayerService()
  private asr: AsrService = new AsrService()
  private tts: TtsService = new TtsService()
  private recordTimer: number = 0
  private voiceClientId: string = ''
  private voiceTriggeredAsr: boolean = false
  private voiceStarting: boolean = false
  private voicePendingEnd: boolean | null = null
  private readingTimer: number = 0
  private pollingTimers: Map<string, number> = new Map()
  private scroller: Scroller = new Scroller()
  private currentRequest: http.HttpRequest | null = null

  private chatVM: ChatViewModel = new ChatViewModel(getContext(this))
  private conversationVM = new ConversationViewModel()
  private fileVM: FileViewModel = new FileViewModel(getContext(this) as common.Context)
  private authVM = new AuthViewModel()
  private editorListenerBound: boolean = false
  private imageActionDialog: CustomDialogController | null = null

  private pendingTurns: Map<string, PendingTurn> = new Map()
  private pendingTimeouts: Map<string, number> = new Map()

  @State private currentIsPending: boolean = false
  @State private switchingSessionId: string = ''

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
    this.pollingTimers.forEach((timer: number) => { clearTimeout(timer) })
    this.pollingTimers.clear()
  }

  private unbindEditorListener(): void {
    if (!this.editorListenerBound) return
    getContext(this).eventHub.off(IMAGE_EDITOR_DONE_EVENT, this.onImageEdited)
    this.editorListenerBound = false
  }

  private bindEditorListener(): void {
    if (this.editorListenerBound) return
    getContext(this).eventHub.on(IMAGE_EDITOR_DONE_EVENT, this.onImageEdited)
    this.editorListenerBound = true
  }

  private onImageEdited = (result: ImageEditorResult): void => {
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
    this.setGestureBackEnabled(true)
    if (this.recorder.isRecording()) {
      this.recorder.cancel().catch(() => {})
    }
    if (this.recordTimer) {
      clearInterval(this.recordTimer)
      this.recordTimer = 0
    }
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
    this.currentSessionId = sessionId
    this.chatVM.setSessionId(sessionId)
    this.sidebarVisible = false
    this.switchingSessionId = sessionId

    try {
      const remote = await this.conversationVM.loadHistory(sessionId)

      if (this.currentSessionId !== sessionId) return

      const list: ChatMessage[] = remote ? [...remote] : []

      const turn = this.pendingTurns.get(sessionId)
      if (turn) {
        if (!this._serverHasUserMsg(list, turn)) {
          list.push(turn.user)
        }
        if (list.indexOf(turn.assistant) < 0) {
          list.push(turn.assistant)
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

    // ⭐ 所有附件场景统一走新路径
    if (this.attachedImages.length > 0 || this.attachedFiles.length > 0) {
      this.sendAttachments(text)
      return
    }
    if (text.length === 0) return

    // ---- 纯文本（无附件）----
    const requestSessionId = this.currentSessionId
    const clientId = this.chatVM.genClientId()

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
          if (this.currentSessionId === requestSessionId) this.scrollToBottom()
        },
        onDone: (info) => {
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
          // ⭐ 检查是否含需要轮询的卡片
          this._scanAndStartPolling(assistantMsg)
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

  // ============================================================
  // ⭐ 附件发送：先上传拿 file_id → 再走 sendWithAttachments
  // ============================================================
  async sendAttachments(text: string): Promise<void> {
    if (this.isLoadingNow()) return

    const requestSessionId = this.currentSessionId
    const clientId = this.chatVM.genClientId()

    const images = this.attachedImages
    const docs = this.attachedFiles
    const allFiles: FileItem[] = [...images, ...docs]
    const hasImages = images.length > 0

    // ---- 1. 上传所有附件 ----
    let attachRefs: AttachmentRefDto[] = []
    try {
      const results = await FileApi.uploadAssetBatch(
        getContext(this) as common.Context,
        requestSessionId,
        allFiles
      )
      for (let i = 0; i < results.length; i++) {
        const r = results[i]
        const ref: AttachmentRefDto = { file_id: r.file_id, type: r.type }
        attachRefs.push(ref)
      }
    } catch (e) {
      promptAction.openToast({ message: `附件上传失败: ${(e as Error).message}` })
      // ⭐ 附件保留，让用户重试
      return
    }

    // ---- 2. 上传成功，清空附件条 ----
    this.attachedImages = []
    this.attachedFiles = []

    // ---- 3. 构造显示文本 ----
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

    // ---- 4. push 消息 ----
    const userMsg = this.chatVM.createUserMessage(
      displayText, allFiles.map(f => f.name), clientId
    )
    this.messages.push(userMsg)
    const assistantMsg = this.chatVM.createAssistantPlaceholder()
    this.messages.push(assistantMsg)

    this._startRequest(requestSessionId, userMsg, assistantMsg)

    this.inputText = ''
    this.loadingSessionId = requestSessionId
    this.messages = [...this.messages]
    this.scrollToBottom()

    // ---- 5. 走新路径 ----
    try {
      this.currentRequest = await this.chatVM.sendWithAttachments({
        text: backendText,
        sessionId: requestSessionId,
        clientId,
        attachments: attachRefs,
        flowContext: '',
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
          if (this.currentSessionId === requestSessionId) this.scrollToBottom()
        },
        onDone: (info) => {
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
          this._scanAndStartPolling(assistantMsg)
        },
        onSessionIdChange: (sid: string) => {
          this._handleSessionIdChange(sid, requestSessionId)
        }
      })
    } catch (e) {
      Logger.e('sendWithAttachments 失败: ' + (e as Error).message)
      this.loadingSessionId = ''
      this._finishRequest(requestSessionId)
      if (assistantMsg.content.length === 0) {
        assistantMsg.content = `[发送失败: ${(e as Error).message}]`
      }
      assistantMsg.completed = true
      this.messages = [...this.messages]
    }
  }

  async regenerate(userMsg: ChatMessage): Promise<void> {
    if (this.isLoadingNow()) return
    const text = userMsg.content
    if (!text) return

    const requestSessionId = this.currentSessionId
    const clientId = this.chatVM.genClientId()

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
          if (this.currentSessionId === requestSessionId) this.scrollToBottom()
        },
        onDone: (info) => {
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
          this._scanAndStartPolling(assistantMsg)
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

  private async handleDownload(relativeUrl: string): Promise<void> {
    const filename = relativeUrl.split('/').pop() || `file_${Date.now()}`
    promptAction.openToast({ message: '正在下载…' })
    try {
      const saved = await DownloadUtil.downloadAndSave(relativeUrl, filename)
      if (saved) {
        promptAction.openToast({ message: '已保存' })
      }
    } catch (e) {
      promptAction.openToast({ message: `下载失败: ${(e as Error).message}` })
    }
  }

  handleAction(type: string, msg: ChatMessage): void {
    if (type === MessageActionType.COPY) this.copyMessage(msg)
    else if (type === MessageActionType.REGENERATE) this.regenerate(msg)
    else if (type === MessageActionType.SHARE) promptAction.openToast({ message: '分享开发中' })
  }


  /**
   * ⭐ 换脸卡片：点击"上传人脸图 / 上传目标视频 / 补充视频 / 更换人脸图"
   *   → 前端打开文件选择器 → 上传 → 拿 file_id → 走 card_action
   */
  async onFaceSwapPickUpload(
    kind: string,
    cardId: string,
    cardType: string,
    msg: ChatMessage,
  ): Promise<void> {
    Logger.i(`[ChatPage] onFaceSwapPickUpload kind=${kind} cardId=${cardId}`)

    // 1. 打开文件选择器
    let file: FileItem | null = null
    try {
      if (kind === 'image') {
        const imgs: FileItem[] = await this.fileVM.pickImages(1)
        Logger.i(`[ChatPage] pickImages count=${imgs.length}`)
        if (imgs.length > 0) file = imgs[0]
      } else {
        const vids: FileItem[] = await this.fileVM.pickVideo(1)
        Logger.i(`[ChatPage] pickVideo count=${vids.length}`)
        if (vids.length > 0) file = vids[0]
      }
    } catch (e) {
      Logger.e(`[ChatPage] pick 异常: ${(e as Error).message}`)
      promptAction.openToast({ message: `选择文件失败: ${(e as Error).message}` })
      return
    }

    if (file === null) {
      Logger.i(`[ChatPage] 用户取消或未选中文件`)
      return
    }

    Logger.i(`[ChatPage] file selected: name=${file.name} uri=${file.uri}`)

    // 2. 上传
    promptAction.openToast({ message: '正在上传…' })

    let uploaded: UploadAssetRespDto | null = null
    try {
      uploaded = await FileApi.uploadAsset(
        getContext(this) as common.Context,
        this.currentSessionId,
        file,
      )
    } catch (e) {
      Logger.e(`[ChatPage] uploadAsset 失败: ${(e as Error).message}`)
      promptAction.openToast({ message: `上传失败: ${(e as Error).message}` })
      return
    }

    if (uploaded === null) {
      promptAction.openToast({ message: '上传返回为空' })
      return
    }

    Logger.i(`[ChatPage] uploaded file_id=${uploaded.file_id} type=${uploaded.type}`)

    // 3. 走 card_action
    const optionKey = (kind === 'image') ? 'attach_source_image' : 'attach_target_video'
    await this.onCardAction(cardId, cardType, optionKey, '', msg, uploaded.file_id)
  }



  // ============================================================
  // ⭐ 卡片动作：加 fileId 参数
  // ============================================================
  async onCardAction(
    cardId: string,
    cardType: string,
    optionKey: string,
    text: string,
    msg: ChatMessage,
    fileId?: string,
  ): Promise<void> {
    if (this.isLoadingNow()) return

    const requestSessionId = this.currentSessionId
    const clientId = this.chatVM.genClientId()

    // ⭐ face_swap 卡片：就地更新原消息
    const isFaceSwapCard =
      cardType === CardType.FACE_SWAP_ASSET_INPUT
        || cardType === CardType.FACE_SWAP_CONFIRM
        || cardType === CardType.FACE_SWAP_TASK

    if (isFaceSwapCard) {
      await this._faceSwapActionInplace(
        requestSessionId, cardId, cardType, optionKey, text, fileId, msg, clientId
      )
      return
    }

    // ---- 原有路径：非 face_swap 卡片 ----
    const newAssistant = this.chatVM.createAssistantPlaceholder()
    this.messages.push(newAssistant)
    this.messages = [...this.messages]
    this._startRequest(requestSessionId, msg, newAssistant)
    this.loadingSessionId = requestSessionId
    this.scrollToBottom()

    try {
      await this.chatVM.sendAction(
        requestSessionId,
        cardId,
        cardType,
        optionKey,
        text,
        clientId,
        fileId ?? '',
        newAssistant,
        () => {
          if (this.currentSessionId === requestSessionId) {
            this.messages = [...this.messages]
            this.scrollToBottom()
          }
        },
        (info) => {
          newAssistant.completed = true
          if (this.currentSessionId === requestSessionId) {
            this.messages = [...this.messages]
          }
        },
        () => {
          this.loadingSessionId = ''
          this._finishRequest(requestSessionId)
          this._scanAndStartPolling(newAssistant)
        },
      )
    } catch (e) {
      Logger.e(`onCardAction 失败: ${(e as Error).message}`)
      this.loadingSessionId = ''
      this._finishRequest(requestSessionId)
    }
  }


  /**
   * ⭐ face_swap 卡片：就地更新原消息，不新增气泡
   */
  private async _faceSwapActionInplace(
    requestSessionId: string,
    cardId: string,
    cardType: string,
    optionKey: string,
    text: string,
    fileId: string | undefined,
    msg: ChatMessage,
    clientId: string,
  ): Promise<void> {
    Logger.i(`[ChatPage] faceSwapInplace card=${cardId} opt=${optionKey} file=${fileId ?? ''}`)

    this.loadingSessionId = requestSessionId
    this._startRequest(requestSessionId, msg, msg)
    this.scrollToBottom()

    try {
      await this.chatVM.sendAction(
        requestSessionId,
        cardId,
        cardType,
        optionKey,
        text,
        clientId,
        fileId ?? '',
        msg,                       // ⭐ 结果写回原 msg
        () => {
          // onRefresh：就地把 cardJson 变化反映出来
          this.messages = [...this.messages]
        },
        (info) => {
          msg.completed = true
          this.messages = [...this.messages]
        },
        () => {
          this.loadingSessionId = ''
          this._finishRequest(requestSessionId)
          // ⭐ 新卡片是否需要轮询
          this._scanAndStartPolling(msg)
        },
      )
    } catch (e) {
      Logger.e(`_faceSwapActionInplace 失败: ${(e as Error).message}`)
      this.loadingSessionId = ''
      this._finishRequest(requestSessionId)
    }
  }


  // ============================================================
  // ⭐ 扫描卡片，启动对应轮询
  // ============================================================
  private _scanAndStartPolling(msg: ChatMessage): void {
    if (msg.cardJson.length === 0) return
    const card = parseCard(msg.cardJson)
    if (!card) return

    if (card.card_type === CardType.PROGRESS) {
      // LivePortrait 单任务
      if (!card.extra || !card.extra.task_id) return
      const taskId = card.extra.task_id
      if (this.pollingTimers.has(taskId)) return
      Logger.i(`[ChatPage] 启动进度轮询 taskId=${taskId}`)
      this._pollJob(msg, taskId)
      return
    }

    if (card.card_type === CardType.FACE_SWAP_TASK) {
      // 换脸 N 任务
      if (!card.tasks || card.tasks.length === 0) return
      Logger.i(`[ChatPage] 启动换脸多任务轮询 count=${card.tasks.length}`)
      for (let i = 0; i < card.tasks.length; i++) {
        this._pollSingleFaceSwapTask(msg, card.tasks[i].task_id)
      }
      return
    }
  }

  // ============================================================
  // LivePortrait 单任务轮询（保持不变）
  // ============================================================
  private _pollJob(msg: ChatMessage, taskId: string): void {
    const tick = async () => {
      try {
        const resp = await this.chatVM.getJobStatus(taskId)
        const status = resp.status ?? ''
        const progress = resp.progress ?? 0
        const resultUrl = resp.result_url ?? ''
        const errorMsg = resp.error ?? ''

        const card = parseCard(msg.cardJson)
        if (card) {
          if (status === 'done' && resultUrl.length > 0) {
            const resultCard: ChatCard = {
              card_id: card.card_id,
              card_type: CardType.RESULT,
              title: '视频生成完成',
              description: '点击下方播放查看',
              items: [],
              extra: { task_id: taskId, video_url: resultUrl },
            }
            msg.cardJson = JSON.stringify(resultCard)
            this.messages = [...this.messages]
            this._stopPolling(taskId)
            return
          } else if (status === 'failed' || status === 'canceled') {
            const errorCard: ChatCard = {
              card_id: card.card_id,
              card_type: CardType.ERROR,
              title: '生成失败',
              description: errorMsg.length > 0 ? errorMsg : '任务失败',
              items: [],
            }
            msg.cardJson = JSON.stringify(errorCard)
            this.messages = [...this.messages]
            this._stopPolling(taskId)
            return
          } else {
            if (card.extra) {
              card.extra.progress = progress
              card.extra.status = status
            }
            msg.cardJson = JSON.stringify(card)
            this.messages = [...this.messages]
          }
        }

        const oldTimer = this.pollingTimers.get(taskId)
        if (oldTimer !== undefined) clearTimeout(oldTimer)
        const timer = setTimeout(tick, 3000)
        this.pollingTimers.set(taskId, timer)
      } catch (e) {
        Logger.e(`轮询失败: ${(e as Error).message}`)
        this._stopPolling(taskId)
      }
    }
    tick()
  }

  // ============================================================
  // ⭐ 换脸单任务轮询（就地更新卡片里的对应 task）
  // ============================================================
  private _pollSingleFaceSwapTask(msg: ChatMessage, taskId: string): void {
    if (this.pollingTimers.has(taskId)) return

    const tick = async () => {
      try {
        const resp = await this.chatVM.getJobStatus(taskId)
        const status = resp.status ?? ''
        const progress = resp.progress ?? 0
        const errorMsg = resp.error ?? ''

        const card = parseCard(msg.cardJson)
        if (!card || !card.tasks) {
          this._stopPolling(taskId)
          return
        }

        // ⭐ 显式声明类型
        let target: FaceSwapTaskItem | null = null
        for (let i = 0; i < card.tasks.length; i++) {
          if (card.tasks[i].task_id === taskId) {
            target = card.tasks[i]
            break
          }
        }
        if (target === null) {
          this._stopPolling(taskId)
          return
        }

        target.status = status
        target.progress = progress
        if (errorMsg.length > 0) target.error = errorMsg

        if (status === 'done') {
          const base = ServiceRouter.getBaseUrl('agent')
          target.video_url = `${base}/agent/v1/chat/job/${taskId}/video`
          msg.cardJson = JSON.stringify(card)
          this.messages = [...this.messages]
          this._stopPolling(taskId)
          return
        }

        if (status === 'failed' || status === 'canceled') {
          msg.cardJson = JSON.stringify(card)
          this.messages = [...this.messages]
          this._stopPolling(taskId)
          return
        }

        msg.cardJson = JSON.stringify(card)
        this.messages = [...this.messages]

        const oldTimer = this.pollingTimers.get(taskId)
        if (oldTimer !== undefined) clearTimeout(oldTimer)
        const timer = setTimeout(tick, 3000)
        this.pollingTimers.set(taskId, timer)
      } catch (e) {
        Logger.e(`换脸任务轮询失败: ${(e as Error).message}`)
        this._stopPolling(taskId)
      }
    }
    tick()
  }

  private _stopPolling(taskId: string): void {
    const t = this.pollingTimers.get(taskId)
    if (t !== undefined) {
      clearTimeout(t)
      this.pollingTimers.delete(taskId)
    }
  }

  async onDownloadVideo(url: string): Promise<void> {
    promptAction.openToast({ message: '视频 URL 已准备好：' + url })
  }

  async onPlayVideo(url: string): Promise<void> {
    if (!url || url.length === 0) {
      promptAction.openToast({ message: '视频 URL 为空' })
      return
    }

    const ctx = getContext(this) as common.UIAbilityContext

    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url,
        type: 'video/mp4'
      }
      await ctx.startAbility(want)
      return
    } catch (e) {
      const err = e as BusinessError
      Logger.e(`[ChatPage] onPlayVideo 失败 code=${err.code} msg=${err.message}`)
    }

    try {
      const wantBrowser: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      }
      await ctx.startAbility(wantBrowser)
    } catch (e) {
      const err = e as BusinessError
      promptAction.openToast({ message: `无法打开视频: ${err.message}` })
    }
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

  async onTakePhoto(): Promise<void> {
    const file = await this.fileVM.capturePhoto()
    if (!file) return
    this.askEditOrUse(file)
  }

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
    this.pendingTurns.set(sessionId, { user: userMsg, assistant: assistantMsg })

    const old = this.pendingTimeouts.get(sessionId)
    if (old !== undefined) clearTimeout(old)

    const timer = setTimeout(() => {
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
  }

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
      if ((!remote || remote.length === 0) && this.messages.length > 0) return

      const list: ChatMessage[] = remote ? [...remote] : []
      const turn = this.pendingTurns.get(sessionId)
      if (turn) {
        if (!this._serverHasUserMsg(list, turn)) {
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

  // ============ 语音交互（保持不变） ============

  private async onVoiceRequestPermission(): Promise<boolean> {
    const ctx = getContext(this) as common.UIAbilityContext
    return await ensureMicPermission(ctx)
  }

  private async onVoicePressStart(): Promise<void> {
    if (this.voiceStarting || this.recorder.isRecording()) return
    this.voiceStarting = true

    const ctx = getContext(this) as common.UIAbilityContext

    try {
      this.voiceTriggeredAsr = await this.asr.start((partial: string) => {
        this.partialText = partial
      })
    } catch (e) {
      this.voiceTriggeredAsr = false
      Logger.e(`[Voice] asr.start 异常: ${(e as Error).message}`)
    }

    const ok = await this.recorder.start(ctx, (pcm: Uint8Array) => {
      if (this.voiceTriggeredAsr) this.asr.writeAudio(pcm)
    })

    this.voiceStarting = false

    if (!ok) {
      promptAction.openToast({ message: '录音启动失败' })
      if (this.voiceTriggeredAsr) {
        try { await this.asr.cancel() } catch (_) {}
        this.voiceTriggeredAsr = false
      }
      this.recordState = RecordPanelState.IDLE
      this.recordDuration = 0
      this.partialText = ''
      return
    }

    if (this.voicePendingEnd !== null) {
      const isCancel = this.voicePendingEnd
      this.voicePendingEnd = null
      await this.onVoicePressEnd(isCancel)
      return
    }

    this.recordDuration = 0
    this.recordTimer = setInterval(() => {
      this.recordDuration += 1
      if (this.recordDuration >= 60) {
        this.onVoicePressEnd(false)
      }
    }, 1000)
  }

  private async onVoicePressEnd(isCancel: boolean): Promise<void> {
    if (this.voiceStarting) {
      this.voicePendingEnd = isCancel
      return
    }

    if (this.recordTimer) {
      clearInterval(this.recordTimer)
      this.recordTimer = 0
    }

    if (isCancel) {
      await this.recorder.cancel()
      if (this.voiceTriggeredAsr) {
        try { await this.asr.cancel() } catch (_) {}
      }
      this.voiceTriggeredAsr = false
      this.recordState = RecordPanelState.IDLE
      this.recordDuration = 0
      this.partialText = ''
      return
    }

    const result = await this.recorder.stop()
    if (!result) {
      promptAction.openToast({ message: '说话时间太短' })
      if (this.voiceTriggeredAsr) {
        try { await this.asr.cancel() } catch (_) {}
      }
      this.voiceTriggeredAsr = false
      this.recordState = RecordPanelState.IDLE
      this.recordDuration = 0
      this.partialText = ''
      return
    }

    const asrText = this.voiceTriggeredAsr ? await this.asr.finish() : ''
    this.voiceTriggeredAsr = false
    this.recordState = RecordPanelState.IDLE
    this.recordDuration = 0
    this.partialText = ''

    this.voiceClientId = this.chatVM.genClientId()
    await this.sendVoice(result, asrText)
  }

  private async sendVoice(result: VoiceRecordResult, asrText: string): Promise<void> {
    const requestSessionId = this.currentSessionId
    const clientId = this.voiceClientId

    const textForAgent = asrText && asrText.length > 0 ? asrText : '[语音消息]'
    const displayText = textForAgent

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
          if (this.currentSessionId === requestSessionId) this.scrollToBottom()
        },
        onDone: (info) => {
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
          this._scanAndStartPolling(assistantMsg)
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

  private async playVoice(msg: ChatMessage): Promise<void> {
    if (!msg.voicePath) return
    if (this.playingMsgId === msg.id) {
      await this.player.stop()
      this.playingMsgId = ''
      return
    }
    this.playingMsgId = msg.id
    await this.player.play(msg.voicePath, () => {
      this.playingMsgId = ''
    })
  }

  private async triggerTtsRead(msg: ChatMessage): Promise<void> {
    if (!msg.content) return
    await this.stopTtsRead()
    this.aiReadingId = msg.id
    try {
      await this.tts.speak(msg.content)
    } catch (e) {
      Logger.e(`[ChatPage] TTS 失败: ${(e as Error).message}`)
    }
    if (this.aiReadingId === msg.id) {
      this.aiReadingId = ''
    }
  }

  private async stopTtsRead(): Promise<void> {
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
          .width(24).height(24).borderRadius(14)
          .backgroundColor(Color.Transparent)
          .border({ width: 1.2, color: Color.Black })
          .margin({ right: 12 })
          .onClick(() => this.newConversation())
        }
        .width('100%').height(56).backgroundColor(Color.White)
        .border({ width: { bottom: 1 }, color: '#eee' })

        // 朗读停止按钮
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
                  },
                  // ⭐ 加 fileId 参数
                  onCardAction: (
                    cardId: string,
                    cardType: string,
                    optionKey: string,
                    text: string,
                    fileId?: string
                  ) => {
                    this.onCardAction(cardId, cardType, optionKey, text, msg, fileId)
                  },
                  // ⭐ 新增
                  onPickUpload: (kind: string, cardId: string, cardType: string) => {
                    this.onFaceSwapPickUpload(kind, cardId, cardType, msg)
                  },
                  onPlayVideo: (url: string) => this.onPlayVideo(url),
                })
              }
            }, (msg: ChatMessage) => {
              const imgFlag = msg.imageBase64.length > 0 ? 'img'
                : (msg.thumbUrl && msg.thumbUrl.length > 0 ? 'thumb' : 'no')
              const readingFlag = this.aiReadingId === msg.id ? 'R' : 'N'
              const playingFlag = this.playingMsgId === msg.id ? 'P' : 'N'
              const dlFlag = msg.content.indexOf('[DL:') >= 0 ? 'D' : 'N'
              return `${msg.id}_${msg.completed}_${msg.content.length}_${imgFlag}_${readingFlag}_${playingFlag}`
            })
          }
          .width('100%').height('100%').backgroundColor('#fafafa')

          if (this.messages.length === 0) {
            Column({ space: 12 }) {
              Text('你好，有什么我能帮你的吗？')
                .fontSize(20).fontWeight(FontWeight.Medium)
                .fontColor('#4b4b4b').textAlign(TextAlign.Center)
              Text('我可以帮你解答问题、阅读文档、生成图片')
                .fontSize(14).fontColor('#999999').textAlign(TextAlign.Center)
            }
            .width('100%').padding({ left: 32, right: 32 })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }

          if (this.switchingSessionId.length > 0) {
            Column({ space: 10 }) {
              LoadingProgress().width(36).height(36).color('#666666')
              Text('正在加载会话…').fontSize(13).fontColor('#999999')
            }
            .width('100%').height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#fafafaee')
          }
        }
        .layoutWeight(1).width('100%')

        // 图片附件条
        if (this.attachedImages.length > 0) {
          Column() {
            Row() {
              Text(`已选择 ${this.attachedImages.length} 张图片`)
                .fontSize(12).fontColor('#666').layoutWeight(1)
              Text('清空').fontSize(12).fontColor('#e74c3c')
                .onClick(() => { this.attachedImages = [] })
            }
            .width('100%').margin({ bottom: 6 })

            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.attachedImages, (f: FileItem, idx: number) => {
                  Stack({ alignContent: Alignment.TopEnd }) {
                    Column({ space: 4 }) {
                      Image(f.uri)
                        .width(60).height(60)
                        .borderRadius(6).objectFit(ImageFit.Cover)
                        .backgroundColor('#eee')
                        .onClick(() => { this.previewUrl = f.uri })
                      Text(f.name)
                        .fontSize(10).fontColor('#666')
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width(60).textAlign(TextAlign.Center)
                    }
                    .padding(4).backgroundColor(Color.White).borderRadius(8)

                    Text('✕')
                      .fontSize(11).fontColor(Color.White)
                      .width(16).height(16)
                      .textAlign(TextAlign.Center)
                      .borderRadius(8).backgroundColor('#00000099')
                      .margin({ top: -4, right: -4 })
                      .onClick(() => this.removeImageAt(idx))
                  }
                  .width(72).height(92)
                }, (f: FileItem, idx: number) => `${f.uri}_${idx}`)
              }
            }
            .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
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
      .width('100%').height('100%').backgroundColor('#fff')
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
          onClose: () => { this.previewUrl = '' }
        })
          .width('100%').height('100%')
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  SidebarOverlay() {
    Row() {
      Sidebar({
        conversations: this.conversations,
        currentSessionId: this.currentSessionId,
        onSelect: (sid: string) => { this.selectConversation(sid) },
        onLogout: () => { this.logout() }
      })
        .width('75%').height('100%')

      Column()
        .layoutWeight(1).height('100%')
        .backgroundColor('#00000060')
        .onClick(() => { this.sidebarVisible = false })
    }
    .width('100%').height('100%')
  }
}