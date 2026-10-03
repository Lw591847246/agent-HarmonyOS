import http from '@ohos.net.http'
import { ChatUseCase, SendStreamOptions, SendFilesStreamOptions } from './ChatUseCase'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { FileItem } from '../../domain/models/FileItem'
import { ConversationViewModel } from '../conversation/ConversationViewModel'
import { Logger } from '../../common/logger/Logger'
import { HttpClient, SseDoneInfo } from '../../common/network/HttpClient'
import { CardActionDto } from '../../domain/models/CardActionDto'
import { JobStatusResp } from '../../domain/models/ChatCard'
import { StreamCallbacks } from '../../domain/repositories/IChatRepository'


export interface SendStreamOptionsExt extends SendStreamOptions {
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
      Logger.i(`[ChatVM] 自动创建会话成功: ${sid}`)
    } else {
      Logger.e('[ChatVM] 自动创建会话失败')
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

  async sendStream(opt: SendStreamOptionsExt): Promise<http.HttpRequest> {
    if (opt.sessionId && opt.sessionId.length > 0) {
      this.currentSessionId = opt.sessionId
      Logger.i(`[ChatVM] sendStream 使用外部 sessionId: ${opt.sessionId}`)
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
      onCard: opt.onCard,                        // ⭐ 关键透传
      onFinish: opt.onFinish,
    }
    return this.uc.sendStream(finalOpt)
  }

  /**
   * ⭐ 查询任务状态
   * 返回显式接口，避免 Record<string, Object> 触发 ArkTS 索引签名错误
   */
  async getJobStatus(taskId: string): Promise<JobStatusResp> {
    const path = `/agent/v1/chat/job/${taskId}`
    const resp = await HttpClient.get<JobStatusResp>('agent', path)
    return resp
  }

  async sendFilesStream(
    sessionId: string,
    text: string,
    files: FileItem[],
    clientId: string,
    assistantMsg: ChatMessage,
    onRefresh: () => void,
    onDone: (info: SseDoneInfo) => void,
    onFinish: () => void,
  ): Promise<http.HttpRequest> {
    if (sessionId && sessionId.length > 0) {
      this.currentSessionId = sessionId
    }
    const sid = await this.ensureSessionId()

    const opt: SendFilesStreamOptions = {
      sessionId: sid,
      text: text,
      clientId: clientId,
      files: files,
      assistantMsg: assistantMsg,
      onRefresh: onRefresh,
      onDone: onDone,
      onFinish: onFinish,
    }
    return this.uc.sendFilesStream(opt)
  }

  async sendFiles(sessionId: string, text: string, files: FileItem[]): Promise<ChatMessage> {
    if (sessionId && sessionId.length > 0) {
      this.currentSessionId = sessionId
    }
    const sid = await this.ensureSessionId()
    return this.uc.sendFiles(sid, text, files)
  }

  async ocr(files: FileItem[]): Promise<ChatMessage> {
    return this.uc.ocr(files)
  }

  async sendAction(
    sessionId: string,
    cardId: string,
    cardType: string,
    optionKey: string,
    text: string,
    clientId: string,
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

    const cb: StreamCallbacks = {
      onChunk: (chunk: string) => {
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