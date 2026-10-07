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
    const finalOpt: SendStreamOptions = {
      text: opt.text,
      sessionId: sid,
      clientId: opt.clientId,
      assistantMsg: opt.assistantMsg,
      onRefresh: opt.onRefresh,
      onScroll: opt.onScroll,
      onDone: opt.onDone,
      onCard: opt.onCard,
      onFinish: opt.onFinish,
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
      onFinish: opt.onFinish,
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
    fileId: string,                    // ⭐ 新增
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

    const cb: StreamCallbacks = {
      onChunk: (chunk: string) => {
        // ⭐ 收到文本说明卡片流程结束，清空卡片
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
      onFinish: onFinish,
      onError: (err: string) => {
        assistantMsg.content = `[错误: ${err}]`
        assistantMsg.completed = true
        onRefresh()
      },
    }

    return this.uc.sendAction(dto, cb)
  }
}