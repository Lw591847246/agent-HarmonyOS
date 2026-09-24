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
  image_base64?: string   // ← 新增，图生图返回的单张图片
  prompt?: string         // ← 新增，图生图使用的提示词
  results?: ProcessFileResultItem[]
}

// ⭐ 核心修复 2：ProcessFileResultItem 补上 prompt
export interface ProcessFileResultItem {
  type: string
  content?: string
  image_base64?: string   // 已有
  prompt?: string         // ← 新增
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