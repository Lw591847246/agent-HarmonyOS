import http from '@ohos.net.http'

// ============================================================
// 通用：附件引用（file_id 模式）
// ============================================================

export interface AttachmentRefDto {
  file_id: string
  type: string                // image | video | doc | audio
}

// ============================================================
// 上传接口
// ============================================================

export interface UploadAssetRespDto {
  file_id: string
  type: string
  name: string
  size: number
  duration?: number
  thumb_url?: string
}

// ============================================================
// Chat 请求 / 响应
// ============================================================

export interface ChatRequestDto {
  text: string
  session_id: string
  client_id?: string
  attachments?: AttachmentRefDto[]     // ⭐ 新增
  flow_context?: string                // ⭐ 新增
}

export interface StreamJsonResponseDto {
  type?: string
  content?: string
  image_base64?: string
  card_json?: string                   // ⭐ 新增
  results?: StreamJsonResultItemDto[]
}

export interface StreamJsonResultItemDto {
  type?: string
  content?: string
  image_base64?: string
}

// ============================================================
// 会话
// ============================================================

export interface ConversationDto {
  session_id: string
  title?: string
  updated_at?: string
}

export interface CreateConversationResponseDto {
  session_id: string
}

export interface HistoryMessageDto {
  id: number
  role: string
  content: string
  message_type?: string
  image_url?: string
  thumb_url?: string
  client_id?: string
  duration_ms?: number
  created_at?: string
}

export interface HistoryResponseDto {
  session_id: string
  messages: HistoryMessageDto[]
}

// ============================================================
// Auth
// ============================================================

export interface ApiResponse<T> {
  code: number
  message: string
  data: T
  total?: number
  success?: boolean
}

export interface LoginRequestDto {
  username: string
  password: string
}

export interface LoginResponseDto {
  token?: string
  authorization?: string
  userId?: number
  username?: string
}

export interface RegisterRequestDto {
  username: string
  realName: string
  phone: string
  email: string
  password: string
  confirmPassword: string
}

export interface UserPermissionDto {
  userId?: number
  menus?: string[]
  permissions?: string[]
}