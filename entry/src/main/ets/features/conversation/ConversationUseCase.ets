import { ConversationRepositoryImpl } from '../../data/repositories/ConversationRepositoryImpl'
import { IConversationRepository, HistoryMessage } from '../../domain/repositories/IConversationRepository'
import { Conversation } from '../../domain/models/Conversation'

export class ConversationUseCase {
  private repo: IConversationRepository = new ConversationRepositoryImpl()

  list(): Promise<Conversation[]> { return this.repo.list() }
  create(): Promise<string> { return this.repo.create() }
  history(sessionId: string): Promise<HistoryMessage[]> { return this.repo.history(sessionId) }
}