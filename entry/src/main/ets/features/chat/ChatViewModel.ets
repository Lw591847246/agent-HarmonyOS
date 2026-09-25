import http from '@ohos.net.http'
import { ChatUseCase, SendStreamOptions } from './ChatUseCase'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { FileItem } from '../../domain/models/FileItem'
import { ConversationViewModel } from '../conversation/ConversationViewModel'
import { Logger } from '../../common/logger/Logger'


/**
 * 流式消息扩展选项：增加 session_id 变更回调
 * 当 ViewModel 内部兜底创建了新会话时，通知 ChatPage 同步 UI
 */
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

  // ============================================================
  // 会话管理
  // ============================================================

  /** 外部设置当前 session_id（例如从侧边栏切换会话时） */
  setSessionId(sid: string): void {
    this.currentSessionId = sid || ''
    Logger.i(`[ChatVM] setSessionId: ${sid}`)
  }

  /** 获取当前 session_id */
  getSessionId(): string {
    return this.currentSessionId
  }

  /**
   * ⭐ 核心兜底：确保有有效的 session_id
   * - 有则直接返回
   * - 无则调后端新建会话，拿到 sid 后缓存
   */
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

  // ============================================================
  // 消息工厂
  // ============================================================

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

  // ============================================================
  // 发送消息（带 session_id 兜底）
  // ============================================================

  /**
   * 发送流式消息
   * - 内部会自动兜底 session_id
   * - 通过 onSessionIdChange 回调通知 ChatPage 更新 currentSessionId
   */
  async sendStream(opt: SendStreamOptionsExt): Promise<http.HttpRequest> {
    const sid = await this.ensureSessionId()

    // 通知外部同步 session_id
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

  /**
   * 发送带文件的消息（process-file 接口）
   * 兼容原签名，但内部强制用兜底后的 session_id
   */
  async sendFiles(sessionId: string, text: string, files: FileItem[]): Promise<ChatMessage> {
    const sid = await this.ensureSessionId()
    return this.uc.sendFiles(sid, text, files)
  }

  /** OCR */
  async ocr(files: FileItem[]): Promise<ChatMessage> {
    return this.uc.ocr(files)
  }
}