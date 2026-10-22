import http from '@ohos.net.http'
import { ChatUseCase, SendStreamOptions, SendWithAttachmentsOptions } from './ChatUseCase'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { ConversationViewModel } from '../conversation/ConversationViewModel'
import { Logger } from '../../common/logger/Logger'
import { HttpClient, SseDoneInfo } from '../../common/network/HttpClient'
import { CardActionDto } from '../../domain/models/CardActionDto'
import { JobStatusResp } from '../../domain/models/ChatCard'
import { StreamCallbacks } from '../../domain/repositories/IChatRepository'
import { AttachmentRefDto } from '../../data/dto/Types'


export interface SendStreamOptionsExt extends SendStreamOptions {
  onSessionIdChange?: (sid: string) => void
}

export interface SendWithAttachmentsOptionsExt extends SendWithAttachmentsOptions {
  onSessionIdChange?: (sid: string) => void
}


export class ChatViewModel {

  private uc: ChatUseCase
  private conversationVM: ConversationViewModel
  private currentSessionId: string = ''

  constructor(context: Context) {
    this.uc = new ChatUseCase(context)
    this.conversationVM = new ConversationViewModel()
  }

  setSessionId(sid: string): void {
    this.currentSessionId = sid || ''
    Logger.i(`[ChatVM] setSessionId: ${sid}`)
  }

  getSessionId(): string {
    return this.currentSessionId
  }

  genClientId(): string {
    return ChatUseCase.genClientId()
  }

  async ensureSessionId(): Promise<string> {
    if (this.currentSessionId && this.currentSessionId.length > 0) {
      return this.currentSessionId
    }
    Logger.i('[ChatVM] session_id 为空，自动创建新会话')
    const sid = await this.conversationVM.createNew()
    if (sid && sid.length > 0) {
      this.currentSessionId = sid
    }
    return this.currentSessionId
  }

  createUserMessage(text: string, files?: string[], clientId?: string): ChatMessage {
    const m = ChatUseCase.createMessage('user', text, clientId)
    if (files) m.files = files
    return m
  }

  createAssistantPlaceholder(): ChatMessage {
    const m = ChatUseCase.createMessage('assistant', '')
    m.thinkingDone = false
    return m
  }

  // ============================================================
  // ⭐ 断连识别 + 兜底（统一入口）
  // ============================================================
  private _handleStreamError(
    assistantMsg: ChatMessage,
    err: string,
    onRefresh: () => void,
  ): void {
    const errLower = (err || '').toLowerCase()
    const isNetworkDrop =
      errLower.includes('peer') ||
        errLower.includes('connection reset') ||
        errLower.includes('econnreset') ||
        errLower.includes('failed to receive') ||
        errLower.includes('socket') ||
        errLower.includes('timeout') ||
        errLower.includes('network') ||
        errLower.includes('broken pipe')

    if (isNetworkDrop) {
      Logger.e(`[ChatVM] 网络断连（非失败）: ${err}`)
      assistantMsg.content = '任务仍在后台执行，稍后自动刷新…'
      assistantMsg.completed = false
      assistantMsg.pending = true
      assistantMsg.networkDropped = true
      assistantMsg.networkDroppedAt = Date.now()
    } else {
      Logger.e(`[ChatVM] 真正的业务错误: ${err}`)
      assistantMsg.content = `[错误: ${err}]`
      assistantMsg.completed = true
    }
    onRefresh()
  }

  /**
   * ⭐ onFinish 兜底：如果流结束但 completed=false，说明是异常中断
   * （覆盖 ChatUseCase 内部 onError 没回调到 ViewModel 的情况）
   */
  private _checkDisconnectFallback(assistantMsg: ChatMessage): void {
    if (assistantMsg.completed) return
    if (assistantMsg.networkDropped) return
    // 流结束但没完成 → 异常中断
    assistantMsg.content = '任务仍在后台执行，稍后自动刷新…'
    assistantMsg.pending = true
    assistantMsg.networkDropped = true
    assistantMsg.networkDroppedAt = Date.now()
    Logger.e(`[ChatVM] onFinish 兜底：检测到流异常中断`)
  }

  // ============================================================
  // 无附件
  // ============================================================
  async sendStream(opt: SendStreamOptionsExt): Promise<http.HttpRequest> {
    if (opt.sessionId && opt.sessionId.length > 0) {
      this.currentSessionId = opt.sessionId
    }
    const sid = await this.ensureSessionId()
    if (opt.onSessionIdChange && sid) {
      opt.onSessionIdChange(sid)
    }

    // ⭐ 包装 onFinish：加兜底检测
    const wrappedOnFinish = () => {
      this._checkDisconnectFallback(opt.assistantMsg)
      opt.onFinish()
    }

    const finalOpt: SendStreamOptions = {
      text: opt.text,
      sessionId: sid,
      clientId: opt.clientId,
      assistantMsg: opt.assistantMsg,
      onRefresh: opt.onRefresh,
      onScroll: opt.onScroll,
      onDone: opt.onDone,
      onCard: opt.onCard,
      onFinish: wrappedOnFinish,
    }
    return this.uc.sendStream(finalOpt)
  }

  // ============================================================
  // ⭐ 带 attachments
  // ============================================================
  async sendWithAttachments(opt: SendWithAttachmentsOptionsExt): Promise<http.HttpRequest> {
    if (opt.sessionId && opt.sessionId.length > 0) {
      this.currentSessionId = opt.sessionId
    }
    const sid = await this.ensureSessionId()
    if (opt.onSessionIdChange && sid) {
      opt.onSessionIdChange(sid)
    }

    const wrappedOnFinish = () => {
      this._checkDisconnectFallback(opt.assistantMsg)
      opt.onFinish()
    }

    const finalOpt: SendWithAttachmentsOptions = {
      text: opt.text,
      sessionId: sid,
      clientId: opt.clientId,
      attachments: opt.attachments,
      flowContext: opt.flowContext,
      assistantMsg: opt.assistantMsg,
      onRefresh: opt.onRefresh,
      onScroll: opt.onScroll,
      onDone: opt.onDone,
      onCard: opt.onCard,
      onFinish: wrappedOnFinish,
    }
    return this.uc.sendWithAttachments(finalOpt)
  }

  // ============================================================
  // 任务状态
  // ============================================================
  async getJobStatus(taskId: string): Promise<JobStatusResp> {
    const path = `/agent/v1/chat/job/${taskId}`
    return await HttpClient.get<JobStatusResp>('agent', path)
  }

  // ============================================================
  // 卡片动作
  // ============================================================
  async sendAction(
    sessionId: string,
    cardId: string,
    cardType: string,
    optionKey: string,
    text: string,
    clientId: string,
    fileId: string,
    assistantMsg: ChatMessage,
    onRefresh: () => void,
    onDone: (info: SseDoneInfo) => void,
    onFinish: () => void,
  ): Promise<http.HttpRequest> {
    if (sessionId && sessionId.length > 0) {
      this.currentSessionId = sessionId
    }
    const sid = await this.ensureSessionId()

    const dto: CardActionDto = {
      session_id: sid,
      card_id: cardId,
      card_type: cardType,
      option_key: optionKey,
      text: text,
      client_id: clientId,
    }
    if (fileId && fileId.length > 0) {
      dto.file_id = fileId
    }

    const wrappedOnFinish = () => {
      this._checkDisconnectFallback(assistantMsg)
      onFinish()
    }

    const cb: StreamCallbacks = {
      onChunk: (chunk: string) => {
        if (assistantMsg.cardJson.length > 0) {
          assistantMsg.cardJson = ''
        }
        assistantMsg.content += chunk
        onRefresh()
      },
      onImage: (base64: string) => {
        assistantMsg.imageBase64 = base64
        onRefresh()
      },
      onCard: (cardJson: string) => {
        assistantMsg.cardJson = cardJson
        onRefresh()
      },
      onDone: onDone,
      onFinish: wrappedOnFinish,
      onError: (err: string) => {
        this._handleStreamError(assistantMsg, err, onRefresh)
      },
    }

    return this.uc.sendAction(dto, cb)
  }
}