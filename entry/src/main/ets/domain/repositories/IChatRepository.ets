import http from '@ohos.net.http'
import { FileItem } from '../models/FileItem'

export interface StreamCallbacks {
  onChunk: (text: string) => void
  onFinish: () => void
  onError: (err: string) => void
}

// ⭐ 新增：文件流式上传回调
export interface UploadFilesStreamCallbacks {
  onChunk: (content: string) => void
  onImage: (base64: string) => void
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
  stream(text: string, sessionId: string, cb: StreamCallbacks): http.HttpRequest

  uploadFiles(sessionId: string, text: string, files: FileItem[]): Promise<ProcessFileResult>

  // ⭐ 新增：流式上传
  uploadFilesStream(
    sessionId: string,
    text: string,
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