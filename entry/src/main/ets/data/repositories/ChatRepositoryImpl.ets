import http from '@ohos.net.http'
import { ChatApi } from '../services/ChatApi'
import { IChatRepository, StreamCallbacks } from '../../domain/repositories/IChatRepository'
import { CardActionDto } from '../../domain/models/CardActionDto'
import { AttachmentRefDto } from '../dto/Types'


export class ChatRepositoryImpl implements IChatRepository {
  private context: Context

  constructor(context: Context) {
    this.context = context
  }

  stream(text: string, sessionId: string, clientId: string, cb: StreamCallbacks): http.HttpRequest {
    return ChatApi.stream(
      { text, session_id: sessionId, client_id: clientId },
      {
        onChunk: cb.onChunk,
        onImage: cb.onImage,
        onDone: cb.onDone,
        onCard: cb.onCard,
        onFinish: cb.onFinish,
        onError: cb.onError,
      }
    )
  }

  streamWithAttachments(
    text: string,
    sessionId: string,
    clientId: string,
    attachments: AttachmentRefDto[],
    flowContext: string,
    cb: StreamCallbacks,
  ): http.HttpRequest {
    return ChatApi.streamWithAttachments(
      text, sessionId, clientId, attachments, flowContext,
      {
        onChunk: cb.onChunk,
        onImage: cb.onImage,
        onDone: cb.onDone,
        onCard: cb.onCard,
        onFinish: cb.onFinish,
        onError: cb.onError,
      }
    )
  }

  sendAction(body: CardActionDto, cb: StreamCallbacks): http.HttpRequest {
    return ChatApi.sendAction(body, {
      onChunk: cb.onChunk,
      onImage: cb.onImage,
      onDone: cb.onDone,
      onCard: cb.onCard,
      onFinish: cb.onFinish,
      onError: cb.onError,
    })
  }
}