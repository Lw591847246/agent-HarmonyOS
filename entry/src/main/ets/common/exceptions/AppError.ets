export enum ErrorType {
  NETWORK = 'NETWORK',
  TIMEOUT = 'TIMEOUT',
  UNAUTHORIZED = 'UNAUTHORIZED',
  SERVER = 'SERVER',
  PARSE = 'PARSE',
  BUSINESS = 'BUSINESS',
  UNKNOWN = 'UNKNOWN'
}

export class AppError extends Error {
  type: ErrorType
  code?: number
  detail?: string

  constructor(type: ErrorType, message: string, code?: number, detail?: string) {
    super(message)
    this.name = 'AppError'
    this.type = type
    this.code = code
    this.detail = detail
  }

  static network(msg: string): AppError {
    return new AppError(ErrorType.NETWORK, msg)
  }
  static unauthorized(msg: string = '登录已过期'): AppError {
    return new AppError(ErrorType.UNAUTHORIZED, msg)
  }
  static server(msg: string, code?: number): AppError {
    return new AppError(ErrorType.SERVER, msg, code)
  }
  static parse(msg: string, detail?: string): AppError {
    return new AppError(ErrorType.PARSE, msg, undefined, detail)
  }
  static business(msg: string, code?: number): AppError {
    return new AppError(ErrorType.BUSINESS, msg, code)
  }
}