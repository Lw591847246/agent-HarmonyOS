import http from '@ohos.net.http'
import { ChatRepositoryImpl } from '../../data/repositories/ChatRepositoryImpl'
import { IChatRepository, StreamCallbacks } from '../../domain/repositories/IChatRepository'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { CardActionDto } from '../../domain/models/CardActionDto'
import { AttachmentRefDto } from '../../data/dto/Types'
import { StreamParser, StreamParseState } from '../../common/network/StreamParser'
import { DateUtil } from '../../common/utils/DateUtil'
import { Logger } from '../../common/logger/Logger'
import { SseDoneInfo } from '../../common/network/HttpClient'


let msgCounter: number = 0


// ============================================================
// ⭐ 基类接口：所有 stream 选项的公共字段
// ============================================================
interface StreamCallbackOpts {
  assistantMsg: ChatMessage
  onRefresh: () => void
  onScroll: () => void
  onDone: (info: SseDoneInfo) => void
  onFinish: () => void
}


// ============================================================
// 无附件
// ============================================================
export interface SendStreamOptions extends StreamCallbackOpts {
  text: string
  sessionId: string
  clientId: string
  onCard?: (cardJson: string) => void
}


// ============================================================
// 带附件
// ============================================================
export interface SendWithAttachmentsOptions extends StreamCallbackOpts {
  text: string
  sessionId: string
  clientId: string
  attachments: AttachmentRefDto[]
  flowContext: string
  onCard?: (cardJson: string) => void
}


export class ChatUseCase {
  private repo: IChatRepository

  constructor(context: Context) {
    this.repo = new ChatRepositoryImpl(context)
  }

  static genClientId(): string {
    return `${Date.now()}_${Math.floor(Math.random() * 0xffffff).toString(36)}`
  }

  static createMessage(role: string, content: string, clientId?: string): ChatMessage {
    msgCounter++
    const m = new ChatMessage()
    m.id = `msg_${Date.now()}_${msgCounter}`
    m.role = role
    m.content = content
    if (clientId) m.clientId = clientId
    return m
  }

  private toDataUri(raw: string): string {
    if (!raw) return ''
    if (raw.startsWith('data:')) return raw
    return 'data:image/png;base64,' + raw
  }

  // ============================================================
  // 无附件
  // ============================================================
  sendStream(opt: SendStreamOptions): http.HttpRequest {
    return this._streamWithCb(
      () => this.repo.stream(opt.text, opt.sessionId, opt.clientId, this._buildCb(opt)),
      opt
    )
  }

  // ============================================================
  // 带附件
  // ============================================================
  sendWithAttachments(opt: SendWithAttachmentsOptions): http.HttpRequest {
    return this._streamWithCb(
      () => this.repo.streamWithAttachments(
        opt.text, opt.sessionId, opt.clientId,
        opt.attachments, opt.flowContext,
        this._buildCb(opt)
      ),
      opt
    )
  }

  // ============================================================
  // callbacks
  // ============================================================
  private _buildCb(opt: StreamCallbackOpts): StreamCallbacks {
    return {
      onChunk: (chunk: string) => {
        StreamParser.parse(chunk, new StreamParseState(), opt.assistantMsg)
        opt.onRefresh()
        opt.onScroll()
      },
      onImage: (base64: string) => {
        opt.assistantMsg.imageBase64 = this.toDataUri(base64)
        if (!opt.assistantMsg.content) {
          opt.assistantMsg.content = '[图片已生成]'
        }
        opt.onRefresh()
        opt.onScroll()
      },
      onCard: (cardJson: string) => {
        opt.assistantMsg.cardJson = cardJson
        opt.onRefresh()
        opt.onScroll()
      },
      onDone: (info: SseDoneInfo) => { opt.onDone(info) },
      onFinish: () => {
        opt.assistantMsg.completed = true
        opt.onRefresh()
        opt.onFinish()
      },
      onError: (err: string) => {
        opt.assistantMsg.content += `\n[请求失败: ${err}]`
        opt.assistantMsg.completed = true
        opt.onRefresh()
        opt.onFinish()
      },
    }
  }

  private _streamWithCb(
    starter: () => http.HttpRequest,
    opt: StreamCallbackOpts
  ): http.HttpRequest {
    try {
      return starter()
    } catch (e) {
      const err = e as Error
      Logger.e(`[ChatUseCase] stream 失败: ${err.message}`)
      opt.assistantMsg.content += `\n[请求失败: ${err.message}]`
      opt.assistantMsg.completed = true
      opt.onRefresh()
      opt.onFinish()
      throw new Error(err.message)
    }
  }

  // ============================================================
  // 卡片动作
  // ============================================================
  sendAction(dto: CardActionDto, cb: StreamCallbacks): http.HttpRequest {
    return this.repo.sendAction(dto, cb)
  }
}