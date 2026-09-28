import { Conversation } from '../models/Conversation'

export interface HistoryMessage {
  id?: number
  role: string
  content: string
  created_at?: string
  message_type?: string
  image_thumb_base64?: string
  image_url?: string
  thumb_url?: string   // ⭐ 新增
  clientId?: string          // ⭐ 新增（camelCase）
  durationMs?: number               // ⭐ 新增
}

export interface IConversationRepository {
  list(): Promise<Conversation[]>
  create(): Promise<string>
  history(sessionId: string): Promise<HistoryMessage[]>
}