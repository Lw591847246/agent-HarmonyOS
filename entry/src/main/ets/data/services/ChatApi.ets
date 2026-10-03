import http from '@ohos.net.http'
import {
  HttpClient, HttpUploadFile, FormField, ProcessFileStreamCallbacks,
} from '../../common/network/HttpClient'
import { ApiUrls } from '../../common/network/ApiUrls'
import { ChatRequestDto, ProcessFileResponseDto, OcrResponseDto } from '../dto/Types'
import { CardActionDto } from '../../domain/models/CardActionDto'
import { SseDoneInfo } from '../../common/network/HttpClient'


export interface StreamBridgeCallbacks {
  onChunk: (text: string) => void
  onImage: (base64: string) => void
  onDone?: (info: SseDoneInfo) => void
  onCard?: (cardJson: string) => void       // ⭐ 新增
  onFinish: () => void
  onError: (err: string) => void
}


export class ChatApi {

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
      cb.onCard,                            // ⭐ 新参数
    )
  }

  // ⭐ 新增：卡片动作
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

  static processFile(
    sessionId: string, text: string, files: HttpUploadFile[]
  ): Promise<ProcessFileResponseDto> {
    const field1: FormField = { key: 'session_id', value: sessionId }
    const field2: FormField = { key: 'text', value: text }
    const fields: FormField[] = [field1, field2]
    return HttpClient.uploadFiles<ProcessFileResponseDto>(
      'agent', ApiUrls.PROCESS_FILE, files, fields
    )
  }

  static ocr(files: HttpUploadFile[]): Promise<OcrResponseDto> {
    const fields: FormField[] = []
    return HttpClient.uploadFiles<OcrResponseDto>('agent', ApiUrls.OCR, files, fields)
  }

  static processFileStream(
    fields: FormField[],
    files: HttpUploadFile[],
    cb: ProcessFileStreamCallbacks,
  ): http.HttpRequest {
    return HttpClient.streamPostUpload(
      'agent',
      ApiUrls.PROCESS_FILE,
      files,
      fields,
      cb,
    )
  }
}