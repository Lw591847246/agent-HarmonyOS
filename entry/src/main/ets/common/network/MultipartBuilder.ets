import util from '@ohos.util'
import fs from '@ohos.file.fs'
import { AppError } from '../exceptions/AppError'
import { Logger } from '../logger/Logger'

/** 上传文件描述 */
export interface MultipartFile {
  fieldName: string      // 表单字段名，如 'files'
  fileName: string       // 原始文件名
  filePath: string       // 沙箱绝对路径
  mimeType: string       // 上传 Content-Type
}

/** 表单普通字段 */
export interface MultipartField {
  key: string
  value: string
}

/**
 * multipart/form-data body 构造器
 * 核心优化：所有片段先入数组，最后一次分配 + 一次拷贝 → O(n)
 */
export class MultipartBuilder {
  private boundary: string
  private crlf: string = '\r\n'
  private encoder: util.TextEncoder
  private chunks: Uint8Array[]
  private totalLength: number

  constructor() {
    this.boundary = `----HarmonyBoundary${Date.now()}${Math.floor(Math.random() * 100000)}`
    this.encoder = new util.TextEncoder()
    this.chunks = []
    this.totalLength = 0
  }

  getBoundary(): string {
    return this.boundary
  }

  getContentType(): string {
    return `multipart/form-data; boundary=${this.boundary}`
  }

  /** 追加普通表单字段 */
  addField(field: MultipartField): MultipartBuilder {
    const head = `--${this.boundary}${this.crlf}` +
      `Content-Disposition: form-data; name="${field.key}"${this.crlf}${this.crlf}` +
      `${field.value}${this.crlf}`
    this.pushString(head)
    return this
  }

  /** 追加文件 */
  addFile(file: MultipartFile): MultipartBuilder {
    // 中文文件名：ASCII 兜底 + RFC 5987 UTF-8 名
    const asciiName = file.fileName.replace(/[^\x20-\x7E]/g, '_')
    const utf8Name = encodeURIComponent(file.fileName)

    const head = `--${this.boundary}${this.crlf}` +
      `Content-Disposition: form-data; name="${file.fieldName}"; ` +
      `filename="${asciiName}"; filename*=UTF-8''${utf8Name}${this.crlf}` +
      `Content-Type: ${file.mimeType}${this.crlf}${this.crlf}`
    this.pushString(head)

    // 读取文件内容
    try {
      const stat = fs.statSync(file.filePath)
      const f = fs.openSync(file.filePath, fs.OpenMode.READ_ONLY)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(f.fd, buf)
      fs.closeSync(f)
      this.pushBytes(new Uint8Array(buf))
    } catch (e) {
      Logger.e(`读取文件失败: ${(e as Error).message}`)
      throw AppError.business(`读取文件失败: ${file.fileName}`)
    }

    this.pushString(this.crlf)
    return this
  }

  /**
   * 结束并生成完整 body
   * 单次分配 totalLength 字节，然后按顺序拷贝所有 chunks
   */
  build(): ArrayBuffer {
    // 追加结束分隔
    this.pushString(`--${this.boundary}--${this.crlf}`)

    // 一次性分配
    const result = new Uint8Array(this.totalLength)
    let offset = 0
    for (let i = 0; i < this.chunks.length; i++) {
      const b = this.chunks[i]
      result.set(b, offset)
      offset += b.length
    }

    Logger.i(`multipart body 总字节: ${this.totalLength}, chunks: ${this.chunks.length}`)
    return result.buffer as ArrayBuffer
  }

  private pushString(s: string): void {
    const b = this.encoder.encodeInto(s)
    this.chunks.push(b)
    this.totalLength += b.length
  }

  private pushBytes(b: Uint8Array): void {
    this.chunks.push(b)
    this.totalLength += b.length
  }
}