import { AppError, ErrorType } from './AppError'
import { Logger } from '../logger/Logger'

export interface ErrorMessage {
  show: boolean
  text: string
}

export class ErrorHandler {
  static toUserMessage(e: Object | null | undefined): ErrorMessage {
    if (e instanceof AppError) {
      if (e.type === ErrorType.UNAUTHORIZED) {
        return { show: true, text: '登录已过期，请重新登录' }
      }
      if (e.type === ErrorType.NETWORK) {
        return { show: true, text: '网络连接失败，请检查网络' }
      }
      if (e.type === ErrorType.TIMEOUT) {
        return { show: true, text: '请求超时，请稍后重试' }
      }
      if (e.type === ErrorType.SERVER) {
        const codeStr = e.code !== undefined ? String(e.code) : ''
        return { show: true, text: `服务异常 (${codeStr})` }
      }
      if (e.type === ErrorType.PARSE) {
        return { show: true, text: '数据解析失败' }
      }
      if (e.type === ErrorType.BUSINESS) {
        return { show: true, text: e.message }
      }
      return { show: true, text: e.message || '未知错误' }
    }
    if (e instanceof Error) {
      Logger.e(`未分类异常: ${e.message}`)
      return { show: true, text: e.message }
    }
    if (typeof e === 'string') {
      return { show: true, text: e }
    }
    return { show: true, text: '未知错误' }
  }
}