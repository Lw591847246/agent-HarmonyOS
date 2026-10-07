import { ConversationUseCase } from './ConversationUseCase'
import { Conversation } from '../../domain/models/Conversation'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { ChatUseCase } from '../chat/ChatUseCase'
import { ErrorHandler } from '../../common/exceptions/ErrorHandler'
import { EnvConfig } from '../../common/config/EnvConfig'

export class ConversationViewModel {
  private uc = new ConversationUseCase()

  async loadList(): Promise<Conversation[]> {
    try { return await this.uc.list() }
    catch (e) {
      ErrorHandler.toUserMessage(e)
      return []
    }
  }

  async createNew(): Promise<string> {
    try { return await this.uc.create() }
    catch (e) {
      ErrorHandler.toUserMessage(e)
      return ''
    }
  }

  async loadHistory(sessionId: string): Promise<ChatMessage[]> {
    try {
      const list = await this.uc.history(sessionId)
      const result: ChatMessage[] = []

      for (let i = 0; i < list.length; i++) {
        const h = list[i]
        const cid: string = h.clientId ? h.clientId : ''

        // ⭐ 按 message_type 分流
        const msgType: string = h.message_type ? h.message_type : 'text'

        let msg: ChatMessage
        if (msgType === 'card') {
          // 卡片消息：content 里是 JSON，塞进 cardJson
          msg = ChatUseCase.createMessage(h.role, '', cid)
          msg.cardJson = h.content || ''
          msg.content = ''
        } else if (msgType === 'image') {
          msg = ChatUseCase.createMessage(h.role, h.content, cid)
          if (h.image_url) {
            msg.imageUrl = h.image_url.startsWith('http')
              ? h.image_url : EnvConfig.AGENT_BASE_URL + h.image_url
          }
          if (h.thumb_url) {
            msg.thumbUrl = h.thumb_url.startsWith('http')
              ? h.thumb_url : EnvConfig.AGENT_BASE_URL + h.thumb_url
          }
        } else {
          // text / video / 其它：默认按文本处理
          msg = ChatUseCase.createMessage(h.role, h.content, cid)
        }

        msg.messageType = msgType
        msg.completed = true
        msg.thinkingDone = true
        msg.duration = h.durationMs ? Math.round(h.durationMs / 1000) : 0

        result.push(msg)
      }

      return result
    } catch (e) {
      ErrorHandler.toUserMessage(e)
      return []
    }
  }
}