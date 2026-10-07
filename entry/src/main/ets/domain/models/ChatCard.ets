/**
 * 卡片数据模型 - 与后端协议对应
 */

// ============================================================
// LivePortrait 卡片
// ============================================================

export interface ChatCardConfirmSummary {
  template?: string
  voice?: string
  tts_text?: string
}

// ============================================================
// face_swap 卡片
// ============================================================

export interface FaceSwapAssetItem {
  file_id: string
  name: string
  duration?: number
  thumb_url?: string
  removable?: boolean
}

export interface FaceSwapSummary {
  source_image: FaceSwapAssetItem | null
  target_videos: FaceSwapAssetItem[]
  prompt: string
}

export interface FaceSwapTaskItem {
  task_id: string
  video_name: string
  status: string
  progress: number
  error?: string
  video_url?: string
  file_size?: number      // ⭐ 新增
  summary?: string        // ⭐ 新增
}

// ============================================================
// extra 总结构
// ============================================================

export interface ChatCardExtra {
  task_id?: string
  status?: string
  progress?: number
  poll_url?: string

  video_url?: string
  error?: string
  summary?: ChatCardConfirmSummary
  sample_url?: string
  gender?: string
  locale?: string

  fs_summary?: FaceSwapSummary
  fs_tasks?: FaceSwapTaskItem[]
  fs_missing?: string[]
  fs_poll_url_template?: string
  fs_video_url_template?: string
}

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

export interface ChatCardButton {
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
  text_input_default?: string
  text_input_placeholder?: string
  submit_action?: ChatCardSubmitAction
  submit_text_action?: ChatCardSubmitAction
  buttons?: ChatCardButton[]
  summary?: FaceSwapSummary
  missing?: string[]
  tasks?: FaceSwapTaskItem[]
  poll_url_template?: string
  video_url_template?: string
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
  static readonly FACE_SWAP_PICK_IMAGE = 'face_swap_pick_image'   // ⭐ 新增
  static readonly FACE_SWAP_ASSET_INPUT = 'face_swap_asset_input'
  static readonly FACE_SWAP_CONFIRM = 'face_swap_confirm'
  static readonly FACE_SWAP_TASK = 'face_swap_task'
}

interface RawCardJson {
  card_id?: string
  card_type?: string
  title?: string
  description?: string
  items?: ChatCardItem[]
  allow_text_input?: boolean
  text_input_default?: string
  text_input_placeholder?: string
  submit_action?: ChatCardSubmitAction
  submit_text_action?: ChatCardSubmitAction
  buttons?: ChatCardButton[]
  summary?: FaceSwapSummary
  missing?: string[]
  tasks?: FaceSwapTaskItem[]
  poll_url_template?: string
  video_url_template?: string
  extra?: ChatCardExtra
}

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
    if (raw.submit_text_action !== undefined) card.submit_text_action = raw.submit_text_action
    if (raw.buttons !== undefined) card.buttons = raw.buttons
    if (raw.summary !== undefined) card.summary = raw.summary
    if (raw.missing !== undefined) card.missing = raw.missing
    if (raw.tasks !== undefined) card.tasks = raw.tasks
    if (raw.poll_url_template !== undefined) card.poll_url_template = raw.poll_url_template
    if (raw.video_url_template !== undefined) card.video_url_template = raw.video_url_template
    if (raw.extra !== undefined) card.extra = raw.extra
    return card
  } catch (e) {
    return null
  }
}

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
  file_size?: number      // ⭐ 新增
  video_url?: string      // ⭐ 新增
  summary?: string        // ⭐ 新增
}