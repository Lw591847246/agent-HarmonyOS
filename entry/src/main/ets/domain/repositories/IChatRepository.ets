import http from '@ohos.net.http'
import { FileItem } from '../models/FileItem'
import { CardActionDto } from '../models/CardActionDto'
import { SseDoneInfo } from '../../common/network/HttpClient'
import { AttachmentRefDto } from '../../data/dto/Types'

export interface StreamCallbacks {
  onChunk: (text: string) => void
  onImage: (base64: string) => void
  onDone?: (info: SseDoneInfo) => void
  onCard?: (cardJson: string) => void
  onFinish: () => void
  onError: (err: string) => void
}

export interface IChatRepository {
  stream(text: string, sessionId: string, clientId: string, cb: StreamCallbacks): http.HttpRequest

  sendAction(body: CardActionDto, cb: StreamCallbacks): http.HttpRequest

  // ⭐ 新增：带 attachments 的 chat
  streamWithAttachments(
    text: string,
    sessionId: string,
    clientId: string,
    attachments: AttachmentRefDto[],
    flowContext: string,
    cb: StreamCallbacks,
  ): http.HttpRequest
}