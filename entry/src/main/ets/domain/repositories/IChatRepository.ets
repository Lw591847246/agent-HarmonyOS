import http from '@ohos.net.http'
import { FileItem } from '../models/FileItem'
import { CardActionDto } from '../models/CardActionDto'
import { SseDoneInfo } from '../../common/network/HttpClient'


export interface StreamCallbacks {
  onChunk: (text: string) => void
  onImage: (base64: string) => void
  onDone?: (info: SseDoneInfo) => void
  onCard?: (cardJson: string) => void
  onFinish: () => void
  onError: (err: string) => void
}


export interface UploadFilesStreamCallbacks {
  onChunk: (text: string) => void
  onImage: (base64: string) => void
  onDone?: (info: SseDoneInfo) => void
  onCard?: (cardJson: string) => void
  onFinish: () => void
  onError: (err: string) => void
}


export interface ProcessFileResultItem {
  type: string
  content?: string
  image_base64?: string
}


export interface ProcessFileResult {
  type: string
  content?: string
  image_base64?: string                    // ⭐ 补上这一行
  results?: ProcessFileResultItem[]
}


export interface OcrResultItem {
  filename: string
  text: string
}


export interface OcrResult {
  type: string
  results: OcrResultItem[]
}


export interface IChatRepository {
  stream(text: string, sessionId: string, clientId: string, cb: StreamCallbacks): http.HttpRequest

  sendAction(body: CardActionDto, cb: StreamCallbacks): http.HttpRequest

  uploadFiles(sessionId: string, text: string, files: FileItem[]): Promise<ProcessFileResult>

  uploadFilesStream(
    sessionId: string,
    text: string,
    clientId: string,
    files: FileItem[],
    cb: UploadFilesStreamCallbacks,
  ): http.HttpRequest

  ocr(files: FileItem[]): Promise<OcrResult>
}