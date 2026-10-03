/**
 * 卡片数据模型 - 与后端协议对应
 * 后端 SSE 事件：{ type: "card", card_json: "{...}" }
 * card_json 解析后就是 ChatCard 结构
 */

/** confirm 卡片的摘要信息 */
export interface ChatCardConfirmSummary {
  template?: string
  voice?: string
  tts_text?: string
}

/** 卡片的额外数据（按 card_type 不同而不同） */
export interface ChatCardExtra {
  // progress 卡片
  task_id?: string
  status?: string
  progress?: number
  poll_url?: string

  // result 卡片
  video_url?: string

  // error 卡片
  error?: string

  // confirm 卡片
  summary?: ChatCardConfirmSummary

  // voice 卡片
  sample_url?: string
  gender?: string
  locale?: string
}

/** 卡片项（模板列表、声音列表等）的额外字段 */
export interface ChatCardItemExtra {
  sample_url?: string
  gender?: string
  locale?: string
}

export interface ChatCardItem {
  key: string
  label: string
  description?: string
  thumbnail?: string
  preview?: string
  tags?: string[]
  default?: boolean
  extra?: ChatCardItemExtra
}

export interface ChatCardSubmitAction {
  key: string
  label: string
}

export interface ChatCard {
  card_id: string
  card_type: string
  title: string
  description?: string
  items: ChatCardItem[]
  allow_text_input?: boolean
  text_input_default?: string              // ⭐ 预填值（用户可编辑）
  text_input_placeholder?: string          // ⭐ 仅作输入框提示
  submit_action?: ChatCardSubmitAction
  extra?: ChatCardExtra
}

export class CardType {
  static readonly TEMPLATE_PICKER = 'template_picker'
  static readonly TEXT_INPUT = 'text_input'
  static readonly VOICE_PICKER = 'voice_picker'
  static readonly CONFIRM = 'confirm'
  static readonly PROGRESS = 'progress'
  static readonly RESULT = 'result'
  static readonly ERROR = 'error'
}

/**
 * JSON.parse 结果的中间接口。
 * 所有字段可选，避免 as ChatCard 时字段缺失导致运行时问题。
 */
interface RawCardJson {
  card_id?: string
  card_type?: string
  title?: string
  description?: string
  items?: ChatCardItem[]
  allow_text_input?: boolean
  text_input_default?: string              // ⭐ 新增
  text_input_placeholder?: string
  submit_action?: ChatCardSubmitAction
  extra?: ChatCardExtra
}

/** 解析后端返回的 card_json 字符串，失败返回 null */
export function parseCard(json: string): ChatCard | null {
  if (!json || json.length === 0) return null
  try {
    const raw = JSON.parse(json) as RawCardJson
    if (!raw.card_id || !raw.card_type) return null

    const card: ChatCard = {
      card_id: raw.card_id,
      card_type: raw.card_type,
      title: raw.title ?? '',
      items: raw.items ?? [],
    }
    if (raw.description !== undefined) card.description = raw.description
    if (raw.allow_text_input !== undefined) card.allow_text_input = raw.allow_text_input
    if (raw.text_input_default !== undefined) card.text_input_default = raw.text_input_default
    if (raw.text_input_placeholder !== undefined) card.text_input_placeholder = raw.text_input_placeholder
    if (raw.submit_action !== undefined) card.submit_action = raw.submit_action
    if (raw.extra !== undefined) card.extra = raw.extra
    return card
  } catch (e) {
    return null
  }
}

/** 任务状态查询响应 */
export interface JobStatusResp {
  task_id?: string
  session_id?: string
  user_id?: number
  intent?: string
  template_id?: string
  provider?: string
  provider_job_id?: string
  status?: string
  progress?: number
  output_path?: string
  result_url?: string
  error?: string
  created_at?: string
  finished_at?: string
}