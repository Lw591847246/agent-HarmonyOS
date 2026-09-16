import http from '@ohos.net.http'
import { ChatApi } from '../services/ChatApi'
import { FileApi } from '../services/FileApi'
import {
  IChatRepository, StreamCallbacks,
  ProcessFileResult, OcrResult
} from '../../domain/repositories/IChatRepository'
import { FileItem } from '../../domain/models/FileItem'

export class ChatRepositoryImpl implements IChatRepository {
  private context: Context

  constructor(context: Context) {
    this.context = context
  }

  stream(text: string, sessionId: string, cb: StreamCallbacks): http.HttpRequest {
    return ChatApi.stream({ text, session_id: sessionId }, {
      onChunk: cb.onChunk,
      onFinish: cb.onFinish,
      onError: cb.onError
    })
  }

  uploadFiles(sessionId: string, text: string, files: FileItem[]): Promise<ProcessFileResult> {
    return FileApi.uploadAndProcess(this.context, sessionId, text, files)
  }

  ocr(files: FileItem[]): Promise<OcrResult> {
    return FileApi.ocr(this.context, files)
  }
}