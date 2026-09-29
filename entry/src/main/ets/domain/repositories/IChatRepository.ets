import http from '@ohos.net.http'
import { FileItem } from '../models/FileItem'
import { SseDoneInfo } from '../../common/network/HttpClient'

export interface StreamCallbacks {
  onChunk: (text: string) => void
  onDone?: (info: SseDoneInfo) => void          // ⭐ 新增
  onFinish: () => void
  onError: (err: string) => void
}


export interface UploadFilesStreamCallbacks {
  onChunk: (content: string) => void
  onImage: (base64: string) => void
  onDone?: (info: SseDoneInfo) => void          // ⭐ 新增
  onFinish: () => void
  onError: (err: string) => void
}


export interface ProcessFileResult {
  type: string
  content?: string
  image_base64?: string
  prompt?: string
  results?: ProcessFileResultItem[]
}

export interface ProcessFileResultItem {
  type: string
  content?: string
  image_base64?: string
  prompt?: string
}

export interface IChatRepository {
  // ⭐ 加 clientId
  stream(text: string, sessionId: string, clientId: string, cb: StreamCallbacks): http.HttpRequest

  uploadFiles(sessionId: string, text: string, files: FileItem[]): Promise<ProcessFileResult>

  // ⭐ 加 clientId
  uploadFilesStream(
    sessionId: string,
    text: string,
    clientId: string,
    files: FileItem[],
    cb: UploadFilesStreamCallbacks,
  ): http.HttpRequest

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