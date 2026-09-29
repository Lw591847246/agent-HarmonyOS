import http from '@ohos.net.http'
import { FileItem } from '../../domain/models/FileItem'

export interface ChatRequestDto {
  text: string
  session_id: string
  client_id?: string          // ⭐ 新增
}

export interface ProcessFileResponseDto {
  type: string
  content?: string
  results?: ProcessFileResultItemDto[]
}

export interface ProcessFileResultItemDto {
  type: string
  content?: string
  image_base64?: string
}

export interface StreamJsonResponseDto {
  type?: string
  content?: string
  image_base64?: string
  results?: StreamJsonResultItemDto[]
}

export interface StreamJsonResultItemDto {
  type?: string
  content?: string
  image_base64?: string
}

export interface OcrResponseDto {
  type: string
  results: OcrResultItemDto[]
}

export interface OcrResultItemDto {
  filename: string
  text: string
}
// ============================================================
// 会话相关 DTO
// ============================================================

/** 会话列表项（GET /agent/v1/conversations 返回的数组元素） */
export interface ConversationDto {
  session_id: string
  title?: string
  updated_at?: string
}

/** 新建会话返回 */
export interface CreateConversationResponseDto {
  session_id: string
}

/** 历史消息项 */
export interface HistoryMessageDto {
  id: number
  role: string
  content: string
  message_type?: string
  image_url?: string
  thumb_url?: string
  client_id?: string          // ⭐ 新增：客户端幂等 ID（老数据可能为 null）
  duration_ms?: number              // ⭐ 新增
  created_at?: string
}

/** 历史接口返回体（GET /agent/v1/conversations/{sid}/messages） */
export interface HistoryResponseDto {
  session_id: string
  messages: HistoryMessageDto[]
}

// ============================================================
// 通用响应包装（auth 服务用）
// ============================================================

export interface ApiResponse<T> {
  code: number
  message: string
  data: T
  total?: number
  success?: boolean
}

// ============================================================
// 登录 / 注册 DTO
// ============================================================

/** 登录请求体 */
export interface LoginRequestDto {
  username: string
  password: string
}

/** 登录返回体（data 部分） */
export interface LoginResponseDto {
  /** 后端可能返回的两种字段，二选一 */
  token?: string
  authorization?: string
  userId?: number
  username?: string
}

/** 注册请求体（字段名需与后端对齐） */
export interface RegisterRequestDto {
  username: string
  realName: string
  phone: string
  email: string
  password: string
  confirmPassword: string
}

/** 用户权限/菜单返回体（data 部分） */
export interface UserPermissionDto {
  userId?: number
  menus?: string[]
  permissions?: string[]
}