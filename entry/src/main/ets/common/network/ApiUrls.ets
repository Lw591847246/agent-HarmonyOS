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
  static readonly CHAT_ACTION = '/agent/v1/chat/action'

  // ⭐ 新增：通用上传
  static readonly UPLOAD_ASSET = '/agent/v1/upload/asset'
  static readonly UPLOAD_THUMB_PREFIX = '/agent/v1/upload/thumb/'

  // ⭐ 任务状态（换脸/liveportrait 共用）
  static readonly JOB_PREFIX = '/agent/v1/chat/job/'

  // ❌ 已删除：
  // PROCESS_FILE = '/agent/v1/process-file'
  // OCR = '/agent/v1/ocr'
}