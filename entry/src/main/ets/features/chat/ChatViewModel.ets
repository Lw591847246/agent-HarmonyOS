import http from '@ohos.net.http'
import { ChatUseCase, SendStreamOptions, SendFilesStreamOptions } from './ChatUseCase'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { FileItem } from '../../domain/models/FileItem'
import { ConversationViewModel } from '../conversation/ConversationViewModel'
import { Logger } from '../../common/logger/Logger'


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

  createUserMessage(text: string, files?: string[]): ChatMessage {
    const m = ChatUseCase.createMessage('user', text)
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
      assistantMsg: opt.assistantMsg,
      onRefresh: opt.onRefresh,
      onScroll: opt.onScroll,
      onFinish: opt.onFinish,
    }
    return this.uc.sendStream(finalOpt)
  }

  // ============================================================
  // ⭐ 新增：文件流式上传
  // ============================================================
  async sendFilesStream(
    sessionId: string,
    text: string,
    files: FileItem[],
    assistantMsg: ChatMessage,
    onRefresh: () => void,
    onFinish: () => void,
  ): Promise<http.HttpRequest> {
    if (sessionId && sessionId.length > 0) {
      this.currentSessionId = sessionId
      Logger.i(`[ChatVM] sendFilesStream 使用外部 sessionId: ${sessionId}`)
    }
    const sid = await this.ensureSessionId()

    const opt: SendFilesStreamOptions = {
      sessionId: sid,
      text: text,
      files: files,
      assistantMsg: assistantMsg,
      onRefresh: onRefresh,
      onFinish: onFinish,
    }
    return this.uc.sendFilesStream(opt)
  }

  /** @deprecated 用 sendFilesStream */
  async sendFiles(sessionId: string, text: string, files: FileItem[]): Promise<ChatMessage> {
    if (sessionId && sessionId.length > 0) {
      this.currentSessionId = sessionId
      Logger.i(`[ChatVM] sendFiles 使用外部 sessionId: ${sessionId}`)
    }
    const sid = await this.ensureSessionId()
    return this.uc.sendFiles(sid, text, files)
  }

  async ocr(files: FileItem[]): Promise<ChatMessage> {
    return this.uc.ocr(files)
  }
}