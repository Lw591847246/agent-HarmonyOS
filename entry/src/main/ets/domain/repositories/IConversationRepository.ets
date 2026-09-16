import { Conversation } from '../models/Conversation'

export interface HistoryMessage {
  role: string
  content: string
}

export interface IConversationRepository {
  list(): Promise<Conversation[]>
  create(): Promise<string>
  history(sessionId: string): Promise<HistoryMessage[]>
}