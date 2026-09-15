import { HttpClient } from '../../common/network/HttpClient'
import { ApiUrls } from '../../common/network/ApiUrls'
import {
  ApiResponse, ConversationDto, CreateConversationResponseDto, HistoryResponseDto
} from '../dto/Types'

export class ConversationApi {
  static list(): Promise<ApiResponse<ConversationDto[]>> {
    return HttpClient.get<ApiResponse<ConversationDto[]>>('agent', ApiUrls.CONVERSATIONS)
  }

  static create(): Promise<ApiResponse<CreateConversationResponseDto>> {
    return HttpClient.post<ApiResponse<CreateConversationResponseDto>>('agent', ApiUrls.CONVERSATION_NEW)
  }

  static history(sessionId: string): Promise<HistoryResponseDto> {
    return HttpClient.get<HistoryResponseDto>(
      'agent',
      `${ApiUrls.CONVERSATION_HISTORY}/${sessionId}/messages`
    )
  }
}