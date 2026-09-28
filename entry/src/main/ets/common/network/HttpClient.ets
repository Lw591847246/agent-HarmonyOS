import http from '@ohos.net.http'
import util from '@ohos.util'
import { ServiceRouter, ServiceName } from './ServiceRouter'
import { HttpInterceptor } from './HttpInterceptor'
import { AppConfig } from '../config/AppConfig'
import { AppError } from '../exceptions/AppError'
import { Logger } from '../logger/Logger'
import { TokenStore } from '../storage/TokenStore'
import { MultipartBuilder, MultipartFile, MultipartField } from './MultipartBuilder'

/** ⭐ SSE done 事件回传信息 */
export interface SseDoneInfo {
  messageId: number
  durationMs: number
}


export interface HttpUploadFile {
  name: string
  uri: string
  mimeType?: string
}

export interface FormField {
  key: string
  value: string
}

/** multipart 上传请求头 */
interface MultipartHeader {
  'Content-Type': string
  'Authorization': string
}

// ⭐ 新增：流式上传回调（供 common 层使用）
export interface ProcessFileStreamCallbacks {
  onChunk: (content: string) => void
  onImage: (base64: string) => void
  onDone?: (info: SseDoneInfo) => void          // ⭐ 新增
  onFinish: () => void
  onError: (err: string) => void
}

// ⭐ 新增：SSE 单条 payload 的解析结构
interface SseUploadPayload {
  type?: string
  content?: string
  image_base64?: string
  message_id?: number
  duration_ms?: number
  error?: string
}

export class HttpClient {

  // ==================== JSON POST ====================
  static async post<T>(service: ServiceName, path: string, body?: Object): Promise<T> {
    const url = ServiceRouter.getBaseUrl(service) + path
    Logger.i(`POST ${service} ${url}`)
    const req = http.createHttp()
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.POST,
        header: HttpInterceptor.buildJsonHeader(),
        extraData: body ? JSON.stringify(body) : undefined,
        connectTimeout: AppConfig.CONNECT_TIMEOUT,
        readTimeout: AppConfig.READ_TIMEOUT
      })
      const text = HttpInterceptor.handleResponse(resp)
      try {
        return JSON.parse(text) as T
      } catch (e) {
        throw AppError.parse('响应非 JSON', text.substring(0, 200))
      }
    } finally {
      req.destroy()
    }
  }

  // ==================== JSON GET ====================
  static async get<T>(service: ServiceName, path: string): Promise<T> {
    const url = ServiceRouter.getBaseUrl(service) + path
    Logger.i(`GET ${service} ${url}`)
    const req = http.createHttp()
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: HttpInterceptor.buildTokenHeader(),
        connectTimeout: AppConfig.CONNECT_TIMEOUT,
        readTimeout: AppConfig.READ_TIMEOUT
      })
      const text = HttpInterceptor.handleResponse(resp)
      try {
        return JSON.parse(text) as T
      } catch (e) {
        throw AppError.parse('响应非 JSON', text.substring(0, 200))
      }
    } finally {
      req.destroy()
    }
  }

  // ==================== 流式 POST ====================
  static streamPost(
    service: ServiceName,
    path: string,
    body: Object,
    onChunk: (text: string) => void,
    onDone: ((info: SseDoneInfo) => void) | undefined,
    onFinish: () => void,
    onError: (err: string) => void
  ): http.HttpRequest {
    const url = ServiceRouter.getBaseUrl(service) + path
    Logger.i(`STREAM ${service} ${url}`)

    const req = http.createHttp()
    const decoder = util.TextDecoder.create('utf-8')

    // ⭐ 兼容两路回调：把 onDone 桥接为 ProcessFileStreamCallbacks 形态
    const bridge: ProcessFileStreamCallbacks = {
      onChunk: (content: string) => { onChunk(content) },
      onImage: (_: string) => { /* chat 接口不会来图 */ },
      onDone: onDone
        ? (info: SseDoneInfo) => { onDone(info) }
        : undefined,
      onFinish: () => { /* 由 dataEnd 控制 */ },
      onError: (err: string) => { onError(err) },
    }

    let buffer = ''
    req.on('dataReceive', (data: ArrayBuffer) => {
      const text = decoder.decodeWithStream(new Uint8Array(data), { stream: true })
      buffer += text
      let idx: number = buffer.indexOf('\n\n')
      while (idx >= 0) {
        const raw = buffer.substring(0, idx)
        buffer = buffer.substring(idx + 2)
        HttpClient._handleSseLine(raw, bridge)
        idx = buffer.indexOf('\n\n')
      }
    })
    req.on('dataEnd', () => {
      Logger.i('dataEnd 流结束')
      onFinish()
      req.destroy()
    })

    req.requestInStream(url, {
      method: http.RequestMethod.POST,
      header: HttpInterceptor.buildStreamHeader(),
      extraData: JSON.stringify(body),
      connectTimeout: AppConfig.CONNECT_TIMEOUT,
      readTimeout: AppConfig.READ_TIMEOUT
    }).then((code: number) => {
      Logger.i(`requestInStream 返回码: ${code}`)
    }).catch((err: Error) => {
      Logger.e(`STREAM 错误: ${err.message}`)
      onError(err.message)
      req.destroy()
    })

    return req
  }

  // ==================== 文件上传（非流式，保留原样） ====================
  static async uploadFiles<T>(
    service: ServiceName,
    path: string,
    files: HttpUploadFile[],
    fields: FormField[]
  ): Promise<T> {
    const url = ServiceRouter.getBaseUrl(service) + path
    Logger.i(`UPLOAD ${service} ${url}`)

    const builder = new MultipartBuilder()

    for (let i = 0; i < fields.length; i++) {
      const field: MultipartField = {
        key: fields[i].key,
        value: fields[i].value
      }
      builder.addField(field)
    }

    for (let i = 0; i < files.length; i++) {
      const file = files[i]
      const mf: MultipartFile = {
        fieldName: 'files',
        fileName: file.name,
        filePath: file.uri,
        mimeType: file.mimeType ? file.mimeType : 'application/octet-stream'
      }
      builder.addFile(mf)
    }

    const body = builder.build()

    const token = TokenStore.getToken()
    const header: MultipartHeader = {
      'Content-Type': builder.getContentType(),
      'Authorization': token
    }

    const req = http.createHttp()
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: body,
        connectTimeout: AppConfig.CONNECT_TIMEOUT,
        readTimeout: AppConfig.READ_TIMEOUT
      })
      Logger.i(`上传返回码: ${resp.responseCode}`)
      const text = HttpInterceptor.handleResponse(resp)
      try {
        return JSON.parse(text) as T
      } catch (e) {
        throw AppError.parse('上传响应非 JSON', text.substring(0, 200))
      }
    } finally {
      req.destroy()
    }
  }

  // ==================== ⭐ 新增：文件流式上传（SSE） ====================
  static streamPostUpload(
    service: ServiceName,
    path: string,
    files: HttpUploadFile[],
    fields: FormField[],
    cb: ProcessFileStreamCallbacks,
  ): http.HttpRequest {
    const url = ServiceRouter.getBaseUrl(service) + path
    Logger.i(`STREAM-UPLOAD ${service} ${url}`)

    // ---------- 1) 构造 multipart body（照抄 uploadFiles） ----------
    const builder = new MultipartBuilder()

    for (let i = 0; i < fields.length; i++) {
      const field: MultipartField = {
        key: fields[i].key,
        value: fields[i].value
      }
      builder.addField(field)
    }

    for (let i = 0; i < files.length; i++) {
      const file = files[i]
      const mf: MultipartFile = {
        fieldName: 'files',
        fileName: file.name,
        filePath: file.uri,
        mimeType: file.mimeType ? file.mimeType : 'application/octet-stream'
      }
      builder.addFile(mf)
    }

    const body = builder.build()

    const token = TokenStore.getToken()
    const header: MultipartHeader = {
      'Content-Type': builder.getContentType(),
      'Authorization': token
    }

    // ---------- 2) 发起流式请求 ----------
    const req = http.createHttp()
    const decoder = util.TextDecoder.create('utf-8')
    let buffer = ''

    // ⭐ 逐块接收 + SSE 累积解析
    req.on('dataReceive', (data: ArrayBuffer) => {
      try {
        const text = decoder.decodeWithStream(new Uint8Array(data), { stream: true })
        buffer += text

        // SSE 每条消息以 \n\n 结尾
        let idx: number = buffer.indexOf('\n\n')
        while (idx >= 0) {
          const raw = buffer.substring(0, idx)
          buffer = buffer.substring(idx + 2)
          HttpClient._handleSseLine(raw, cb)
          idx = buffer.indexOf('\n\n')
        }
      } catch (e) {
        Logger.e(`STREAM-UPLOAD 解码失败: ${(e as Error).message}`)
      }
    })

    req.on('dataEnd', () => {
      Logger.i('STREAM-UPLOAD dataEnd')
      cb.onFinish()
      req.destroy()
    })

    req.requestInStream(url, {
      method: http.RequestMethod.POST,
      header: header,
      extraData: body,
      connectTimeout: AppConfig.CONNECT_TIMEOUT,
      readTimeout: AppConfig.READ_TIMEOUT
    }).then((code: number) => {
      Logger.i(`STREAM-UPLOAD 返回码: ${code}`)
    }).catch((err: Error) => {
      Logger.e(`STREAM-UPLOAD 错误: ${err.message}`)
      cb.onError(err.message)
      req.destroy()
    })

    return req
  }

  // ---------- ⭐ 私有：解析单条 SSE ----------
  private static _handleSseLine(raw: string, cb: ProcessFileStreamCallbacks): void {
    if (!raw.startsWith('data:')) return
    const payload = raw.substring(5).trim()
    if (!payload || payload === '[DONE]') return

    try {
      const obj: SseUploadPayload = JSON.parse(payload) as SseUploadPayload
      if (obj.error) {
        cb.onError(String(obj.error))
      } else if (obj.type === 'done') {
        if (cb.onDone) {
          cb.onDone({
            messageId: obj.message_id ?? 0,
            durationMs: obj.duration_ms ?? 0,
          })
        }
      } else if (obj.type === 'image' && obj.image_base64) {
        cb.onImage(obj.image_base64)
      } else if (obj.content) {
        cb.onChunk(obj.content)
      }
    } catch (e) {
      Logger.e(`SSE 解析失败: ${payload.substring(0, 200)}`)
    }
  }
}