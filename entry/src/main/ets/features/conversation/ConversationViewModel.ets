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
      return list.map((h) => {
        // ⭐ 第三参传 client_id（老数据后端返回 null → 前端置 ''）
        const cid: string = h.clientId ? h.clientId : ''
        const m = ChatUseCase.createMessage(h.role, h.content, cid)

        m.completed = true
        m.thinkingDone = true
        m.duration = h.durationMs ? Math.round(h.durationMs / 1000) : 0    // ⭐ 新增

        if (h.message_type === 'image') {
          if (h.image_url) {
            m.imageUrl = h.image_url.startsWith('http')
              ? h.image_url : EnvConfig.AGENT_BASE_URL + h.image_url
          }
          if (h.thumb_url) {
            m.thumbUrl = h.thumb_url.startsWith('http')
              ? h.thumb_url : EnvConfig.AGENT_BASE_URL + h.thumb_url
          }
        }

        return m
      })
    } catch (e) {
      ErrorHandler.toUserMessage(e)
      return []
    }
  }
}