import http from '@ohos.net.http'
import { AppConfig } from '../config/AppConfig'
import { TokenStore } from '../storage/TokenStore'
import { AppError } from '../exceptions/AppError'
import { Logger } from '../logger/Logger'

/** HTTP 请求头：属性名用引号包住，匹配 header 规范 */
export interface RequestHeader {
  'Content-Type'?: string
  'Accept'?: string
  'Authorization'?: string
}

/** JSON 请求头 */
export interface JsonRequestHeader {
  'Content-Type': string
  'Authorization'?: string
}

/** 流式请求头 */
export interface StreamRequestHeader {
  'Content-Type': string
  'Accept': string
  'Authorization'?: string
}

/** 上传请求头（关键：只有 Authorization，绝不带 Content-Type） */
export interface UploadRequestHeader {
  'Authorization'?: string
}

export class HttpInterceptor {


  static buildJsonHeader(): JsonRequestHeader {
    const token = TokenStore.getToken()
    if (token) {
      const h: JsonRequestHeader = {
        'Content-Type': AppConfig.CONTENT_TYPE_JSON,
        'Authorization': token
      }
      return h
    }
    const h: JsonRequestHeader = {
      'Content-Type': AppConfig.CONTENT_TYPE_JSON
    }
    return h
  }

  static buildStreamHeader(): StreamRequestHeader {
    const token = TokenStore.getToken()
    if (token) {
      const h: StreamRequestHeader = {
        'Content-Type': AppConfig.CONTENT_TYPE_JSON,
        'Accept': AppConfig.CONTENT_TYPE_STREAM,
        'Authorization': token
      }
      return h
    }
    const h: StreamRequestHeader = {
      'Content-Type': AppConfig.CONTENT_TYPE_JSON,
      'Accept': AppConfig.CONTENT_TYPE_STREAM
    }
    return h
  }

  static buildUploadHeader(): UploadRequestHeader {
    const token = TokenStore.getToken()
    if (token) {
      const h: UploadRequestHeader = { 'Authorization': token }
      return h
    }
    const h: UploadRequestHeader = {}
    return h
  }

  static handleResponse(resp: http.HttpResponse): string {
    Logger.i(`响应状态 ${resp.responseCode}`)

    Logger.i(`响应状态 ${resp.result}`)

    if (resp.responseCode === 401) {
      TokenStore.clear()
      throw AppError.unauthorized()
    }
    if (resp.responseCode < 200 || resp.responseCode >= 300) {
      throw AppError.server(`HTTP ${resp.responseCode}`, resp.responseCode)
    }
    return resp.result as string
  }

  static buildTokenHeader(): RequestHeader {
    const token = TokenStore.getToken()
    if (token) {
      const h: RequestHeader = {
        'Authorization': token
      }
      return h
    }
    const h: RequestHeader = {}
    return h
  }
}


