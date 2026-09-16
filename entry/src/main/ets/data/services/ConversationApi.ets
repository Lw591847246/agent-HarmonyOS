import { HttpClient } from '../../common/network/HttpClient'
import { ApiUrls } from '../../common/network/ApiUrls'
import {
  ConversationDto, CreateConversationResponseDto, HistoryResponseDto
} from '../dto/Types'

export class ConversationApi {
  // agent 服务直接返回数组，不包装
  static list(): Promise<ConversationDto[]> {
    return HttpClient.get<ConversationDto[]>('agent', ApiUrls.CONVERSATIONS)
  }

  // agent 服务直接返回 { session_id: "..." }
  static create(): Promise<CreateConversationResponseDto> {
    return HttpClient.post<CreateConversationResponseDto>('agent', ApiUrls.CONVERSATION_NEW)
  }

  // 直接返回 { session_id, messages }
  static history(sessionId: string): Promise<HistoryResponseDto> {
    return HttpClient.get<HistoryResponseDto>(
      'agent',
      `${ApiUrls.CONVERSATION_HISTORY}/${sessionId}/messages`
    )
  }
}