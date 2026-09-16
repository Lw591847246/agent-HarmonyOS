import http from '@ohos.net.http'
import util from '@ohos.util'
import { ServiceRouter, ServiceName } from './ServiceRouter'
import { HttpInterceptor } from './HttpInterceptor'
import { AppConfig } from '../config/AppConfig'
import { AppError } from '../exceptions/AppError'
import { Logger } from '../logger/Logger'
import { TokenStore } from '../storage/TokenStore'
import { MultipartBuilder, MultipartFile, MultipartField } from './MultipartBuilder'

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
        readTimeout: 120000
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
        readTimeout: 30000
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
    onFinish: () => void,
    onError: (err: string) => void
  ): http.HttpRequest {
    const url = ServiceRouter.getBaseUrl(service) + path
    Logger.i(`STREAM ${service} ${url}`)

    const req = http.createHttp()
    const decoder = util.TextDecoder.create('utf-8')

    req.on('dataReceive', (data: ArrayBuffer) => {
      const text = decoder.decodeWithStream(new Uint8Array(data), { stream: true })
      if (text) onChunk(text)
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

  // ==================== 文件上传（O(n) 拼接） ====================
  static async uploadFiles<T>(
    service: ServiceName,
    path: string,
    files: HttpUploadFile[],
    fields: FormField[]
  ): Promise<T> {
    const url = ServiceRouter.getBaseUrl(service) + path
    Logger.i(`UPLOAD ${service} ${url}`)

    const builder = new MultipartBuilder()

    // 普通字段
    for (let i = 0; i < fields.length; i++) {
      const field: MultipartField = {
        key: fields[i].key,
        value: fields[i].value
      }
      builder.addField(field)
    }

    // 文件字段
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
}