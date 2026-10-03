import http from '@ohos.net.http'
import { ChatApi } from '../services/ChatApi'
import { FileApi } from '../services/FileApi'
import {
  IChatRepository, StreamCallbacks,
  ProcessFileResult, OcrResult,
  UploadFilesStreamCallbacks,
} from '../../domain/repositories/IChatRepository'
import { FileItem } from '../../domain/models/FileItem'
import { CardActionDto } from '../../domain/models/CardActionDto'


export class ChatRepositoryImpl implements IChatRepository {
  private context: Context

  constructor(context: Context) {
    this.context = context
  }

  stream(text: string, sessionId: string, clientId: string, cb: StreamCallbacks): http.HttpRequest {
    return ChatApi.stream({ text, session_id: sessionId, client_id: clientId }, {
      onChunk: cb.onChunk,
      onImage: cb.onImage,
      onDone: cb.onDone,
      onCard: cb.onCard,                    // ⭐ 透传
      onFinish: cb.onFinish,
      onError: cb.onError,
    })
  }

  // ⭐ 新增
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

  uploadFiles(sessionId: string, text: string, files: FileItem[]): Promise<ProcessFileResult> {
    return FileApi.uploadAndProcess(this.context, sessionId, text, files)
  }

  uploadFilesStream(
    sessionId: string,
    text: string,
    clientId: string,
    files: FileItem[],
    cb: UploadFilesStreamCallbacks,
  ): http.HttpRequest {
    return FileApi.uploadAndProcessStream(this.context, sessionId, text, clientId, files, cb)
  }

  ocr(files: FileItem[]): Promise<OcrResult> {
    return FileApi.ocr(this.context, files)
  }
}