/**
 * 业务常量
 */
export class AppConfig {
  static readonly PAGE_SIZE: number = 20
  static readonly SESSION_DEFAULT: string = ''
  static readonly ROLE_USER: string = 'user'
  static readonly ROLE_ASSISTANT: string = 'assistant'
  static readonly INTENT_CHAT: string = 'chat'
  static readonly INTENT_CODE: string = 'code_generation'
  static readonly INTENT_TRANSLATION: string = 'translation'
  static readonly INTENT_IMAGE: string = 'image_generation'
  static readonly APP_NAME: string = 'AI 智能助手'
  static readonly CONNECT_TIMEOUT: number = 15000
  static readonly READ_TIMEOUT: number = 300000

  static readonly TOKEN_HEADER: string = 'Authorization'
  static readonly CONTENT_TYPE_JSON: string = 'application/json'
  static readonly CONTENT_TYPE_STREAM: string = 'text/plain'
}
