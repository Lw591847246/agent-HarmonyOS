/* ========== 通用响应（去掉索引签名） ========== */
export interface ApiResponse<T = Object> {
  code: number
  message: string
  data: T
  total?: number
  success?: boolean
}

/* ========== 权限菜单 ========== */
export interface MenuItemDto {
  id: number
  parentId: number
  name: string
  code: string
  level: number
  type?: number | null
  menuType?: string | null
  path?: string | null
  component?: string | null
  icon?: string | null
  sort?: number | null
  status?: string | null
  children?: MenuItemDto[] | null
}

export interface SubsystemDto {
  systemName: string
  systemCode: string
  description: string
  baseUrl: string
  logo: string | null
}

export interface UserPermissionDto {
  routes: MenuItemDto[]
  buttons: string[]
  subsystems: SubsystemDto[]
}

/* ========== 认证 ========== */
export interface LoginRequestDto {
  username: string
  password: string
}

export interface LoginResponseDto {
  userId?: number
  username?: string
  token?: string
  authorization?: string
}

export interface RegisterRequestDto {
  username: string
  realName: string
  phone: string
  email: string
  password: string
  confirmPassword: string
}

/* ========== 会话 ========== */
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

/* ========== 聊天 ========== */
export interface ChatRequestDto {
  text: string
  session_id: string
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

/* ========== 文件上传表单（明确类型） ========== */
export interface ProcessFileFormData {
  session_id: string
  text: string
}

export interface OcrFormData {
  // 空表单也要有明确类型
  _placeholder: string
}

/* ========== 仓储实现中所需的中间类型 ========== */
export interface LoginRootDto {
  userId?: number
  username?: string
  token?: string
  authorization?: string
}