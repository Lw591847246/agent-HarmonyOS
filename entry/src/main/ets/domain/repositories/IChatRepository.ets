import http from '@ohos.net.http'
import { FileItem } from '../models/FileItem'

export interface StreamCallbacks {
  onChunk: (text: string) => void
  onFinish: () => void
  onError: (err: string) => void
}

export interface ProcessFileResult {
  type: string
  content?: string
  results?: ProcessFileResultItem[]
}

export interface ProcessFileResultItem {
  type: string
  content?: string
  image_base64?: string
}

export interface IChatRepository {
  stream(text: string, sessionId: string, cb: StreamCallbacks): http.HttpRequest
  uploadFiles(sessionId: string, text: string, files: FileItem[]): Promise<ProcessFileResult>
  ocr(files: FileItem[]): Promise<OcrResult>
}

export interface OcrResult {
  type: string
  results: OcrResultItem[]
}

export interface OcrResultItem {
  filename: string
  text: string
}