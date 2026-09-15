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
      const m: HistoryMessage = {
        role: list[i].role,
        content: list[i].content
      }
      result.push(m)
    }
    return result
  }
}