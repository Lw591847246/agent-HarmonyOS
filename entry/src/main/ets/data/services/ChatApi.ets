import http from '@ohos.net.http'
import { HttpClient, SseDoneInfo } from '../../common/network/HttpClient'
import { ApiUrls } from '../../common/network/ApiUrls'
import { ChatRequestDto, AttachmentRefDto } from '../dto/Types'
import { CardActionDto } from '../../domain/models/CardActionDto'


export interface StreamBridgeCallbacks {
  onChunk: (text: string) => void
  onImage: (base64: string) => void
  onDone?: (info: SseDoneInfo) => void
  onCard?: (cardJson: string) => void
  onFinish: () => void
  onError: (err: string) => void
}


export class ChatApi {

  /** 普通 chat（无附件） */
  static stream(body: ChatRequestDto, cb: StreamBridgeCallbacks): http.HttpRequest {
    return HttpClient.streamPost(
      'agent',
      ApiUrls.CHAT,
      body,
      cb.onChunk,
      cb.onImage,
      cb.onDone,
      cb.onFinish,
      cb.onError,
      cb.onCard,
    )
  }

  /** ⭐ 新增：带 attachments 的 chat */
  static streamWithAttachments(
    text: string,
    sessionId: string,
    clientId: string,
    attachments: AttachmentRefDto[],
    flowContext: string,
    cb: StreamBridgeCallbacks,
  ): http.HttpRequest {
    const body: ChatRequestDto = {
      text: text,
      session_id: sessionId,
      client_id: clientId,
      attachments: attachments,
    }
    if (flowContext && flowContext.length > 0) {
      body.flow_context = flowContext
    }
    return ChatApi.stream(body, cb)
  }

  /** 卡片动作 */
  static sendAction(body: CardActionDto, cb: StreamBridgeCallbacks): http.HttpRequest {
    return HttpClient.streamPost(
      'agent',
      ApiUrls.CHAT_ACTION,
      body,
      cb.onChunk,
      cb.onImage,
      cb.onDone,
      cb.onFinish,
      cb.onError,
      cb.onCard,
    )
  }
}