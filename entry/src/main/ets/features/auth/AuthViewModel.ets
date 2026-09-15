import { AuthUseCase } from './AuthUseCase'
import { RegisterParams } from '../../domain/repositories/IUserRepository'
import { ErrorHandler } from '../../common/exceptions/ErrorHandler'

/** 统一的认证结果 */
export interface AuthResult {
  ok: boolean
  msg?: string
}

export class AuthViewModel {
  private uc = new AuthUseCase()

  async login(username: string, password: string): Promise<AuthResult> {
    try {
      await this.uc.login(username, password)
      const r: AuthResult = { ok: true }
      return r
    } catch (e) {
      const r: AuthResult = { ok: false, msg: ErrorHandler.toUserMessage(e).text }
      return r
    }
  }

  async register(params: RegisterParams): Promise<AuthResult> {
    try {
      await this.uc.register(params)
      const r: AuthResult = { ok: true }
      return r
    } catch (e) {
      const r: AuthResult = { ok: false, msg: ErrorHandler.toUserMessage(e).text }
      return r
    }
  }

  async logout(): Promise<void> {
    await this.uc.logout()
  }
}