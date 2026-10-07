import { ConversationUseCase } from './ConversationUseCase'
import { Conversation } from '../../domain/models/Conversation'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { ChatUseCase } from '../chat/ChatUseCase'
import { ErrorHandler } from '../../common/exceptions/ErrorHandler'
import { EnvConfig } from '../../common/config/EnvConfig'
import { FaceSwapTaskItem } from '../../domain/models/ChatCard'

interface VideoMsgData {
  video_name?: string
  file_size?: number
  summary?: string
  task_id?: string
  video_url?: string
}

interface RawCardTypeCheck {
  card_type?: string
}
interface VideoCardRaw {
  card_id: string
  card_type: string
  title: string
  description: string
  items: string[]
  tasks: FaceSwapTaskItem[]
}
export class ConversationViewModel {
  private uc = new ConversationUseCase()

  async loadList(): Promise<Conversation[]> {
    try { return await this.uc.list() }
    catch (e) {
      ErrorHandler.toUserMessage(e)
      return []
    }
  }

  async createNew(): Promise<string> {
    try { return await this.uc.create() }
    catch (e) {
      ErrorHandler.toUserMessage(e)
      return ''
    }
  }

  async loadHistory(sessionId: string): Promise<ChatMessage[]> {
    try {
      const list = await this.uc.history(sessionId)

      const result: ChatMessage[] = []

      for (let i = 0; i < list.length; i++) {
        const h = list[i]
        const cid: string = h.clientId ? h.clientId : ''
        const msgType: string = h.message_type ? h.message_type : 'text'

        // ⭐ 过滤 face_swap 中间态卡片（这两类卡片会被后续卡片/video 取代）
        if (msgType === 'card' && h.content) {
          try {
            const c = JSON.parse(h.content) as RawCardTypeCheck
            const ct: string = c.card_type ? c.card_type : ''
            if (ct === 'face_swap_pick_image'
              || ct === 'face_swap_asset_input') {
              continue
            }
          } catch (_) {}
        }

        // ⭐ video 消息：每条独立成一张卡（不合并）
        if (msgType === 'video') {
          try {
            const v = JSON.parse(h.content) as VideoMsgData
            const msg = ChatUseCase.createMessage(h.role, '', cid)
            msg.cardJson = this._buildVideoCardJson([v])
            msg.content = ''
            msg.messageType = 'video'
            msg.completed = true
            msg.thinkingDone = true
            result.push(msg)
          } catch (_) {}
          continue
        }

        // 普通消息（card / image / text）
        let msg: ChatMessage
        if (msgType === 'card') {
          msg = ChatUseCase.createMessage(h.role, '', cid)
          msg.cardJson = h.content || ''
          msg.content = ''
        } else if (msgType === 'image') {
          msg = ChatUseCase.createMessage(h.role, h.content, cid)
          if (h.image_url) {
            msg.imageUrl = h.image_url.startsWith('http')
              ? h.image_url : EnvConfig.AGENT_BASE_URL + h.image_url
          }
          if (h.thumb_url) {
            msg.thumbUrl = h.thumb_url.startsWith('http')
              ? h.thumb_url : EnvConfig.AGENT_BASE_URL + h.thumb_url
          }
        } else {
          msg = ChatUseCase.createMessage(h.role, h.content, cid)
        }

        msg.messageType = msgType
        msg.completed = true
        msg.thinkingDone = true
        msg.duration = h.durationMs ? Math.round(h.durationMs / 1000) : 0
        result.push(msg)
      }

      return result
    } catch (e) {
      ErrorHandler.toUserMessage(e)
      return []
    }
  }

  /**
   * 把 N 条 video 消息合并成一张 face_swap_task 卡片
   */
  private _buildVideoCardJson(videos: VideoMsgData[]): string {
    const tasks: FaceSwapTaskItem[] = []
    for (let i = 0; i < videos.length; i++) {
      const v = videos[i]
      const item: FaceSwapTaskItem = {
        task_id: v.task_id ? v.task_id : '',
        video_name: v.video_name ? v.video_name : '换脸视频.mp4',
        status: 'done',
        progress: 100,
        video_url: v.video_url ? v.video_url : '',
        file_size: v.file_size ? v.file_size : 0,
        summary: v.summary ? v.summary : 'AI 生成视频',
      }
      tasks.push(item)
    }

    // ⭐ 显式声明卡片类型
    const card: VideoCardRaw = {
      card_id: `video_group_${videos.length}_${Date.now()}`,
      card_type: 'face_swap_task',
      title: 'AI 视频生成完成',
      description: `共 ${videos.length} 个视频`,
      items: [],
      tasks: tasks,
    }
    return JSON.stringify(card)
  }
}