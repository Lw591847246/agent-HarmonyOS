import { ConversationUseCase } from './ConversationUseCase'
import { Conversation } from '../../domain/models/Conversation'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { ChatUseCase } from '../chat/ChatUseCase'
import { ErrorHandler } from '../../common/exceptions/ErrorHandler'

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
        const m = ChatUseCase.createMessage(h.role, h.content)
        m.completed = true
        return m
      })
    } catch (e) {
      ErrorHandler.toUserMessage(e)
      return []
    }
  }
}