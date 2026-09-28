import { ConversationApi } from '../services/ConversationApi'
import {
  IConversationRepository, HistoryMessage
} from '../../domain/repositories/IConversationRepository'
import { Conversation } from '../../domain/models/Conversation'
import { AppError } from '../../common/exceptions/AppError'
import { ConversationDto, HistoryMessageDto } from '../dto/Types'
import { Logger } from '../../common/logger/Logger'

export class ConversationRepositoryImpl implements IConversationRepository {
  async list(): Promise<Conversation[]> {
    const list: ConversationDto[] = await ConversationApi.list()
    Logger.i(`conversations 数量: ${list ? list.length : 0}`)

    const result: Conversation[] = []
    if (list && Array.isArray(list)) {
      for (let i = 0; i < list.length; i++) {
        const d = list[i]
        const c: Conversation = {
          sessionId: d.session_id,
          title: d.title ? d.title : '未命名对话'
        }
        result.push(c)
      }
    }
    return result
  }

  async create(): Promise<string> {
    const resp = await ConversationApi.create()
    const sid: string | undefined = resp ? resp.session_id : undefined
    if (!sid) throw AppError.parse('创建会话返回缺少 session_id')
    return sid
  }

  async history(sessionId: string): Promise<HistoryMessage[]> {
    const resp = await ConversationApi.history(sessionId)
    const list: HistoryMessageDto[] = resp ? (resp.messages || []) : []

    const result: HistoryMessage[] = []
    for (let i = 0; i < list.length; i++) {
      const d = list[i]
      const m: HistoryMessage = {
        id: d.id,
        role: d.role,
        content: d.content,
        created_at: d.created_at,
        message_type: d.message_type,
        image_url: d.image_url,
        thumb_url: d.thumb_url,
      }
      result.push(m)
    }
    return result
  }
}