import http from '@ohos.net.http'
import { HttpClient, HttpUploadFile, FormField } from '../../common/network/HttpClient'
import { ApiUrls } from '../../common/network/ApiUrls'
import {
  ChatRequestDto, ProcessFileResponseDto, OcrResponseDto
} from '../dto/Types'

export interface StreamBridgeCallbacks {
  onChunk: (text: string) => void
  onFinish: () => void
  onError: (err: string) => void
}

export class ChatApi {
  static stream(body: ChatRequestDto, cb: StreamBridgeCallbacks): http.HttpRequest {
    return HttpClient.streamPost('agent', ApiUrls.CHAT, body, cb.onChunk, cb.onFinish, cb.onError)
  }

  static processFile(
    sessionId: string, text: string, files: HttpUploadFile[]
  ): Promise<ProcessFileResponseDto> {
    // 用 FormField[] 替代对象字面量
    const fields: FormField[] = [
      { key: 'session_id', value: sessionId },
      { key: 'text', value: text }
    ]
    return HttpClient.uploadFiles<ProcessFileResponseDto>(
      'agent', ApiUrls.PROCESS_FILE, files, fields
    )
  }

  static ocr(files: HttpUploadFile[]): Promise<OcrResponseDto> {
    const fields: FormField[] = []
    return HttpClient.uploadFiles<OcrResponseDto>('agent', ApiUrls.OCR, files, fields)
  }
}