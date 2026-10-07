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
import { parseCard, ChatCard, CardType, FaceSwapTaskItem } from '../../domain/models/ChatCard'
import { common, Want } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { FileApi } from '../../data/services/FileApi'
import { ServiceRouter } from '../../common/network/ServiceRouter'
import { AttachmentRefDto, UploadAssetRespDto } from '../../data/dto/Types'
import { systemShare } from '@kit.ShareKit'
import { fileUri } from '@kit.CoreFileKit'
import fs from '@ohos.file.fs'


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
  @State private isSending: boolean = false

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
    const item: FileItem = { name: result.name, uri: result.uri, type: 'image' }
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

      // ⭐ 扫描历史卡片，恢复未完成的任务轮询
      this._scanHistoryForPolling(list)
    } catch (e) {
      Logger.e(`[ChatPage] loadHistory 失败: ${(e as Error).message}`)
    } finally {
      if (this.switchingSessionId === sessionId) {
        this.switchingSessionId = ''
      }
    }
  }

  /** ⭐ 扫描历史消息，为未完成的 task 重启轮询 */
  private _scanHistoryForPolling(list: ChatMessage[]): void {
    for (let i = 0; i < list.length; i++) {
      const m = list[i]
      if (m.cardJson.length === 0) continue
      const c = parseCard(m.cardJson)
      if (!c) continue

      if (c.card_type === CardType.FACE_SWAP_TASK && c.tasks && c.tasks.length > 0) {
        for (let j = 0; j < c.tasks.length; j++) {
          const t = c.tasks[j]
          if (t.status !== 'done' && t.status !== 'failed' && t.status !== 'canceled') {
            if (!this.pollingTimers.has(t.task_id)) {
              Logger.i(`[ChatPage] 历史卡片重启轮询 task=${t.task_id}`)
              this._pollSingleFaceSwapTask(m, t.task_id)
            }
          }
        }
      } else if (c.card_type === CardType.PROGRESS) {
        if (c.extra && c.extra.task_id) {
          const tid = c.extra.task_id
          if (!this.pollingTimers.has(tid)) {
            Logger.i(`[ChatPage] 历史卡片重启轮询 task=${tid}`)
            this._pollJob(m, tid)
          }
        }
      }
    }
  }

  handleSubmit(): void {
    if (this.isSending) return
    if (this.isLoadingNow()) return
    if (!this.isCanSend()) {
      promptAction.openToast({ message: '请输入内容或选择文件' })
      return
    }
    this.send()
  }

  async send(): Promise<void> {
    if (this.isSending) return
    const text = this.inputText.trim()

    if (this.attachedImages.length > 0 || this.attachedFiles.length > 0) {
      this.sendAttachments(text)
      return
    }
    if (text.length === 0) return

    // ⭐ 立即上锁
    this.isSending = true
    this.loadingSessionId = this.currentSessionId

    const requestSessionId = this.currentSessionId
    const clientId = this.chatVM.genClientId()
    this.inputText = ''

    const userMsg = this.chatVM.createUserMessage(text, undefined, clientId)
    this.messages.push(userMsg)
    const assistantMsg = this.chatVM.createAssistantPlaceholder()
    this.messages.push(assistantMsg)

    this._startRequest(requestSessionId, userMsg, assistantMsg)
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
          // ⭐ 识别重复请求信号
          if (info.messageId === -1) {
            this._handleDuplicate(requestSessionId, userMsg, assistantMsg)
            return
          }
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
          this.isSending = false
          this._finishRequest(requestSessionId)
          this.loadConversations()
          this._scanAndStartPolling(assistantMsg)
        },
        onSessionIdChange: (sid: string) => {
          this._handleSessionIdChange(sid, requestSessionId)
        }
      })
    } catch (e) {
      Logger.e('sendStream 失败: ' + (e as Error).message)
      this.loadingSessionId = ''
      this.isSending = false
      this._finishRequest(requestSessionId)
    }
  }
  async sendAttachments(text: string): Promise<void> {
    if (this.isSending) return

    // ⭐ 立即上锁
    this.isSending = true
    this.loadingSessionId = this.currentSessionId

    const requestSessionId = this.currentSessionId
    const clientId = this.chatVM.genClientId()

    // ⭐ 快照 + 立即清空，防止二次点击
    const images = this.attachedImages
    const docs = this.attachedFiles
    const allFiles: FileItem[] = [...images, ...docs]
    const hasImages = images.length > 0
    const originalText = text

    this.attachedImages = []
    this.attachedFiles = []
    this.inputText = ''

    // 先 push 消息让用户看到反馈
    let backendText = originalText
    if (originalText.length === 0 && hasImages) {
      backendText = '请提取图片中的文字'
    }
    let displayText = originalText
    if (originalText.length === 0) {
      if (hasImages) {
        displayText = '请提取图片中的内容'
      } else {
        displayText = `已上传 ${allFiles.length} 个文件`
      }
    }

    const userMsg = this.chatVM.createUserMessage(
      displayText, allFiles.map(f => f.name), clientId
    )
    this.messages.push(userMsg)
    const assistantMsg = this.chatVM.createAssistantPlaceholder()
    this.messages.push(assistantMsg)

    this._startRequest(requestSessionId, userMsg, assistantMsg)
    this.messages = [...this.messages]
    this.scrollToBottom()

    // ---- 上传 ----
    let attachRefs: AttachmentRefDto[] = []
    try {
      const results = await FileApi.uploadAssetBatch(
        getContext(this) as common.Context,
        requestSessionId,
        allFiles
      )
      for (let i = 0; i < results.length; i++) {
        const r = results[i]
        attachRefs.push({ file_id: r.file_id, type: r.type })
      }
    } catch (e) {
      Logger.e(`[ChatPage] 附件上传失败: ${(e as Error).message}`)
      promptAction.openToast({ message: `附件上传失败: ${(e as Error).message}` })

      // ⭐ 上传失败：移除占位消息 + 恢复附件 + 解锁
      const idx1 = this.messages.indexOf(assistantMsg)
      if (idx1 >= 0) this.messages.splice(idx1, 1)
      const idx2 = this.messages.indexOf(userMsg)
      if (idx2 >= 0) this.messages.splice(idx2, 1)
      this.messages = [...this.messages]

      this.attachedImages = images
      this.attachedFiles = docs
      this.inputText = originalText

      this.loadingSessionId = ''
      this.isSending = false
      this._finishRequest(requestSessionId)
      return
    }

    // ---- 提交 chat ----
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
          // ⭐ 识别重复信号
          if (info.messageId === -1) {
            this._handleDuplicate(requestSessionId, userMsg, assistantMsg)
            return
          }
          if (this.currentSessionId === requestSessionId) {
            if (info.durationMs > 0) {
              assistantMsg.duration = Math.round(info.durationMs / 1000)
            }
            assistantMsg.completed = true
            this.messages = [...this.messages]
          }
        },
        onFinish: () => {

          this.loadingSessionId = ''
          this._finishRequest(requestSessionId)
          this.loadConversations()

          // ⭐ 自动 confirm：素材齐全时跳过确认卡片
          const card = parseCard(assistantMsg.cardJson)
          if (card && card.card_type === CardType.FACE_SWAP_CONFIRM) {
            Logger.i(`[ChatPage] 素材齐全，自动提交换脸任务`)
            // isSending 保持 true，由 _faceSwapActionInplace 接管
            this.onCardAction(
              card.card_id,
              card.card_type,
              'confirm',
              '',
              assistantMsg,
              ''
            )
            return
          }

          // 素材不全（asset_input）或其它情况 → 正常处理
          this.isSending = false
          this._scanAndStartPolling(assistantMsg)

          // this.loadingSessionId = ''
          // this.isSending = false
          // this._finishRequest(requestSessionId)
          // this.loadConversations()
          // this._scanAndStartPolling(assistantMsg)
        },
        onSessionIdChange: (sid: string) => {
          this._handleSessionIdChange(sid, requestSessionId)
        }
      })
    } catch (e) {
      Logger.e('sendWithAttachments 失败: ' + (e as Error).message)
      this.loadingSessionId = ''
      this.isSending = false
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

  // ============================================================
  // ⭐ 视频：保存到本地
  // ============================================================
  async onSaveVideo(url: string): Promise<void> {
    Logger.i(`[ChatPage] onSaveVideo url=${url}`)
    const filename = `face_swap_${Date.now()}.mp4`
    promptAction.openToast({ message: '正在准备保存…' })
    try {
      // ⭐ 优先使用缓存，避免重复下载
      const saved = await DownloadUtil.saveCachedToUser(url, filename)
      if (saved) {
        promptAction.openToast({ message: '已保存到本地' })
      }
    } catch (e) {
      promptAction.openToast({ message: `保存失败: ${(e as Error).message}` })
    }
  }

  // ============================================================
  // ⭐ 视频：分享
  // ============================================================
  async onShareVideo(url: string): Promise<void> {
    Logger.i(`[ChatPage] onShareVideo url=${url}`)
    promptAction.openToast({ message: '正在准备分享…' })

    try {
      // 1. 从缓存拿沙箱路径（此时 MediaCache 已经存成 .mp4）
      const sandboxPath = await DownloadUtil.getOrDownload(url)
      if (sandboxPath === null || sandboxPath.length === 0) {
        promptAction.openToast({ message: '获取视频失败' })
        return
      }

      Logger.i(`[ChatPage] onShareVideo 缓存路径=${sandboxPath}`)

      // 2. ⭐ 确保有 .mp4 后缀（旧缓存可能还是 .bin）
      const ctx = getContext(this) as common.UIAbilityContext
      let sharePath = sandboxPath
      if (!sandboxPath.endsWith('.mp4')) {
        sharePath = `${ctx.cacheDir}/share_${Date.now()}.mp4`
        try {
          const src = fs.openSync(sandboxPath, fs.OpenMode.READ_ONLY)
          const dest = fs.openSync(
            sharePath,
            fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC
          )
          try {
            const stat = fs.statSync(src.fd)
            const buf = new ArrayBuffer(stat.size)
            fs.readSync(src.fd, buf)
            fs.writeSync(dest.fd, buf)
          } finally {
            fs.closeSync(src)
            fs.closeSync(dest)
          }
          Logger.i(`[ChatPage] onShareVideo 转为 mp4: ${sharePath}`)
        } catch (e) {
          Logger.e(`[ChatPage] 转 mp4 失败: ${(e as Error).message}`)
          sharePath = sandboxPath   // 失败就用原路径
        }
      }

      // 3. 转 uri
      const uri = fileUri.getUriFromPath(sharePath)

      // 4. 系统分享
      const shareData = new systemShare.SharedData({
        utd: 'general.video',
        uri: uri
      })
      const controller = new systemShare.ShareController(shareData)
      await controller.show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      })
    } catch (e) {
      Logger.e(`[ChatPage] onShareVideo 失败: ${(e as Error).message}`)
      promptAction.openToast({ message: `分享失败: ${(e as Error).message}` })
    }
  }
  // ============================================================
  // ⭐ 播放视频：优先用缓存路径，未命中则直接走 URL
  // ============================================================
  async onPlayVideo(url: string): Promise<void> {
    if (!url || url.length === 0) {
      promptAction.openToast({ message: '视频 URL 为空' })
      return
    }

    const ctx = getContext(this) as common.UIAbilityContext

    // ⭐ 直接用 HTTP URL 让系统播放器流播（支持 Range，边下边播）
    const fullUrl = url.startsWith('http')
      ? url
      : `${ServiceRouter.getBaseUrl('agent')}${url}`

    Logger.i(`[ChatPage] onPlayVideo url=${fullUrl}`)

    // 1. 系统播放器
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: fullUrl,
        type: 'video/mp4'
      }
      await ctx.startAbility(want)
      Logger.i('[ChatPage] onPlayVideo 系统播放器打开成功')
      return
    } catch (e) {
      const err = e as BusinessError
      Logger.e(`[ChatPage] 系统播放器失败 code=${err.code} msg=${err.message}`)
    }

    // 2. 兜底：浏览器打开
    try {
      const wantBrowser: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: fullUrl
      }
      await ctx.startAbility(wantBrowser)
    } catch (e) {
      const err = e as BusinessError
      promptAction.openToast({ message: `无法打开视频: ${err.message}` })
    }
  }
  // ============================================================
  // ⭐ 卡片动作
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

    const isFaceSwapCard =
      cardType === CardType.FACE_SWAP_PICK_IMAGE          // ⭐ 新增：选图卡片原地替换
        || cardType === CardType.FACE_SWAP_ASSET_INPUT
        || cardType === CardType.FACE_SWAP_CONFIRM
        || cardType === CardType.FACE_SWAP_TASK

    if (isFaceSwapCard) {
      await this._faceSwapActionInplace(
        requestSessionId, cardId, cardType, optionKey, text, fileId, msg, clientId
      )
      return
    }

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
        msg,
        () => {
          this.messages = [...this.messages]
        },
        (info) => {
          msg.completed = true
          this.messages = [...this.messages]
        },
        () => {
          this.loadingSessionId = ''
          this.isSending = false                    // ⭐ 新增：最终释放锁
          this._finishRequest(requestSessionId)
          this._scanAndStartPolling(msg)
        },
      )
    } catch (e) {
      Logger.e(`_faceSwapActionInplace 失败: ${(e as Error).message}`)
      this.loadingSessionId = ''
      this._finishRequest(requestSessionId)
    }
  }

  async onFaceSwapPickUpload(
    kind: string,
    cardId: string,
    cardType: string,
    msg: ChatMessage,
  ): Promise<void> {
    Logger.i(`[ChatPage] onFaceSwapPickUpload kind=${kind} cardId=${cardId}`)

    // ⭐ 支持多选：图片最多 9 张（跟附件条上限一致），视频最多 3 个
    let files: FileItem[] = []
    try {
      if (kind === 'image') {
        files = await this.fileVM.pickImages(9)
      } else {
        files = await this.fileVM.pickVideo(3)
      }
    } catch (e) {
      Logger.e(`[ChatPage] pick 异常: ${(e as Error).message}`)
      promptAction.openToast({ message: `选择文件失败: ${(e as Error).message}` })
      return
    }

    if (files.length === 0) {
      Logger.i(`[ChatPage] 用户取消或未选中文件`)
      return
    }

    Logger.i(`[ChatPage] picked ${files.length} files, kind=${kind}`)
    promptAction.openToast({ message: `正在上传 ${files.length} 个文件…` })

    // ⭐ 批量上传
    let uploaded: UploadAssetRespDto[] = []
    const uploadStart = Date.now()
    try {
      uploaded = await FileApi.uploadAssetBatch(
        getContext(this) as common.Context,
        this.currentSessionId,
        files,
      )
      const cost = Date.now() - uploadStart
      Logger.i(`[ChatPage] uploadAssetBatch 完成，耗时=${cost}ms 数量=${uploaded.length}`)
    } catch (e) {
      const cost = Date.now() - uploadStart
      Logger.e(`[ChatPage] uploadAssetBatch 失败，耗时=${cost}ms err=${(e as Error).message}`)
      promptAction.openToast({
        message: `上传失败（耗时 ${Math.round(cost / 1000)}秒）：${(e as Error).message}`,
        duration: 5000
      })
      return
    }

    if (uploaded.length === 0) {
      promptAction.openToast({ message: '上传返回为空' })
      return
    }

    // ⭐ file_id 逗号拼接，后端 split
    const ids = uploaded.map(u => u.file_id).join(',')
    const optionKey = (kind === 'image') ? 'attach_source_images' : 'attach_target_videos'

    Logger.i(`[ChatPage] dispatch optionKey=${optionKey} ids=${ids}`)
    await this.onCardAction(cardId, cardType, optionKey, '', msg, ids)
  }


  private _scanAndStartPolling(msg: ChatMessage): void {
    if (msg.cardJson.length === 0) return
    const card = parseCard(msg.cardJson)
    if (!card) return

    if (card.card_type === CardType.PROGRESS) {
      if (!card.extra || !card.extra.task_id) return
      const taskId = card.extra.task_id
      if (this.pollingTimers.has(taskId)) return
      Logger.i(`[ChatPage] 启动进度轮询 taskId=${taskId}`)
      this._pollJob(msg, taskId)
      return
    }

    if (card.card_type === CardType.FACE_SWAP_TASK) {
      if (!card.tasks || card.tasks.length === 0) return
      for (let i = 0; i < card.tasks.length; i++) {
        const t = card.tasks[i]
        // ⭐ 只轮询未完成的
        if (t.status === 'done' || t.status === 'failed' || t.status === 'canceled') {
          continue
        }
        Logger.i(`[ChatPage] 启动换脸轮询 task=${t.task_id}`)
        this._pollSingleFaceSwapTask(msg, t.task_id)
      }
      return
    }
  }

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

  private _pollSingleFaceSwapTask(msg: ChatMessage, taskId: string): void {
    if (this.pollingTimers.has(taskId)) return

    const tick = async () => {
      try {
        const resp = await this.chatVM.getJobStatus(taskId)
        const status = resp.status ?? ''
        const progress = resp.progress ?? 0
        const errorMsg = resp.error ?? ''
        const fileSize = resp.file_size ?? 0
        const videoUrl = resp.video_url ?? ''
        const summary = resp.summary ?? ''

        const card = parseCard(msg.cardJson)
        if (!card || !card.tasks) {
          this._stopPolling(taskId)
          return
        }

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
          if (videoUrl.length > 0) {
            target.video_url = videoUrl
          } else {
            // 兜底拼路径
            target.video_url = `/agent/v1/chat/job/${taskId}/video`
          }
          target.file_size = fileSize
          if (summary.length > 0) target.summary = summary

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

  /** ⭐ 清缓存回调（Sidebar 触发） */
  private onCacheCleared(): void {
    Logger.i('[ChatPage] 缓存已清理')
    // 未来如果需要，可以做一些界面刷新
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


  /** ⭐ 后端返回重复信号：把刚 push 的用户消息和占位消息移除 */
  private _handleDuplicate(
    sessionId: string,
    userMsg: ChatMessage,
    assistantMsg: ChatMessage,
  ): void {
    Logger.e(`[ChatPage] 检测到重复请求，移除本地占位消息`)
    const idx1 = this.messages.indexOf(assistantMsg)
    if (idx1 >= 0) this.messages.splice(idx1, 1)
    const idx2 = this.messages.indexOf(userMsg)
    if (idx2 >= 0) this.messages.splice(idx2, 1)
    this.messages = [...this.messages]

    this.loadingSessionId = ''
    this.isSending = false
    this._finishRequest(sessionId)

    promptAction.openToast({ message: '请勿重复提交' })
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
      this._scanHistoryForPolling(list)
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


  // ⭐ 合并列表
  private getAllAttachments(): FileItem[] {
    const result: FileItem[] = []
    for (let i = 0; i < this.attachedImages.length; i++) {
      result.push(this.attachedImages[i])
    }
    for (let i = 0; i < this.attachedFiles.length; i++) {
      result.push(this.attachedFiles[i])
    }
    return result
  }

  // ⭐ 按全局索引删除
  private removeAttachmentAt(globalIdx: number): void {
    const imgLen = this.attachedImages.length
    if (globalIdx < imgLen) {
      const next = this.attachedImages.slice()
      next.splice(globalIdx, 1)
      this.attachedImages = next
      return
    }
    const docIdx = globalIdx - imgLen
    const next2 = this.attachedFiles.slice()
    next2.splice(docIdx, 1)
    this.attachedFiles = next2
  }

  // ⭐ 单个附件卡片渲染
  @Builder
  renderAttachmentCard(f: FileItem, idx: number) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 4 }) {
        if (f.type === 'image') {
          // 图片：显示缩略图
          Image(f.uri)
            .width(60).height(60)
            .borderRadius(6)
            .objectFit(ImageFit.Cover)
            .backgroundColor('#eee')
            .onClick(() => { this.previewUrl = f.uri })
        } else if (f.type === 'video') {
          // 视频：🎬 图标 + 深色底
          Column() {
            Text('🎬').fontSize(24)
          }
          .width(60).height(60)
          .borderRadius(6)
          .backgroundColor('#333')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          // 文档：📄 图标
          Column() {
            Text('📄').fontSize(24)
          }
          .width(60).height(60)
          .borderRadius(6)
          .backgroundColor('#e8e8e8')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

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

      // ✕ 删除按钮
      Text('✕')
        .fontSize(11)
        .fontColor(Color.White)
        .width(16).height(16)
        .textAlign(TextAlign.Center)
        .borderRadius(8)
        .backgroundColor('#00000099')
        .margin({ top: -4, right: -4 })
        .onClick(() => this.removeAttachmentAt(idx))
    }
    .width(72).height(92)
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
                  onCardAction: (
                    cardId: string,
                    cardType: string,
                    optionKey: string,
                    text: string,
                    fileId?: string
                  ) => {
                    this.onCardAction(cardId, cardType, optionKey, text, msg, fileId)
                  },
                  onPickUpload: (kind: string, cardId: string, cardType: string) => {
                    this.onFaceSwapPickUpload(kind, cardId, cardType, msg)
                  },
                  onPlayVideo: (url: string) => this.onPlayVideo(url),
                  onSaveVideo: (url: string) => { this.onSaveVideo(url) },       // ⭐ 新增
                  onShareVideo: (url: string) => { this.onShareVideo(url) },     // ⭐ 新增
                })
              }
            }, (msg: ChatMessage) => {
              const imgFlag = msg.imageBase64.length > 0 ? 'img'
                : (msg.thumbUrl && msg.thumbUrl.length > 0 ? 'thumb' : 'no')
              const readingFlag = this.aiReadingId === msg.id ? 'R' : 'N'
              const playingFlag = this.playingMsgId === msg.id ? 'P' : 'N'
              const dlFlag = msg.content.indexOf('[DL:') >= 0 ? 'D' : 'N'
              // ⭐ 卡片消息：把 cardJson 长度也塞进 key，保证状态变化触发重建
              const cardFlag = msg.cardJson.length > 0 ? `C${msg.cardJson.length}` : 'N'
              return `${msg.id}_${msg.completed}_${msg.content.length}_${imgFlag}_${readingFlag}_${playingFlag}_${cardFlag}`
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
        // ⭐ 统一附件条（图片 + 视频 + 文档）
        if (this.getAllAttachments().length > 0) {
          Column() {
            Row() {
              Text(`已选择 ${this.getAllAttachments().length} 个文件`)
                .fontSize(12).fontColor('#666').layoutWeight(1)
              Text('清空').fontSize(12).fontColor('#e74c3c')
                .onClick(() => {
                  this.attachedImages = []
                  this.attachedFiles = []
                })
            }
            .width('100%').margin({ bottom: 6 })

            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.getAllAttachments(), (f: FileItem, idx: number) => {
                  this.renderAttachmentCard(f, idx)
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

        // 输入栏
        InputBar({
          text: $inputText,
          loading: this.isLoadingNow() || this.isSending,
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
        onLogout: () => { this.logout() },
        onClearCache: () => { this.onCacheCleared() },      // ⭐ 新增
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