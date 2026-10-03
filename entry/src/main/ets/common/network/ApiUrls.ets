export class ApiUrls {
  // auth
  static readonly LOGIN = '/front/v1/login'
  static readonly REGISTER = '/front/v1/user/add'
  static readonly USER_MENUS = '/front/v1/menu/user/list'

  // agent
  static readonly CHAT = '/agent/v1/chat'
  static readonly CONVERSATIONS = '/agent/v1/conversations'
  static readonly CONVERSATION_NEW = '/agent/v1/conversation/new'
  static readonly CONVERSATION_HISTORY = '/agent/v1/conversation'
  static readonly PROCESS_FILE = '/agent/v1/process-file'
  static readonly OCR = '/agent/v1/ocr'
  static readonly CHAT_ACTION = '/agent/v1/chat/action'    // ⭐ 新增

}