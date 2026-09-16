export interface ConversationDto {
  session_id: string
  title?: string
}

export interface CreateConversationResponseDto {
  session_id: string
}

export interface HistoryMessageDto {
  role: string
  content: string
}

export interface HistoryResponseDto {
  session_id: string
  messages: HistoryMessageDto[]
}