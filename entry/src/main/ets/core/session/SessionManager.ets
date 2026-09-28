import { TokenStore } from '../../common/storage/TokenStore'
import { Logger } from '../../common/logger/Logger'

/** 用户信息 */
export interface UserInfo {
  userId: number
  username: string
}

/** 会话状态监听器 */
export type SessionListener = (loggedIn: boolean) => void

/**
 * 全局会话管理器（单例）
 *
 * ⚠️ ArkTS 静态方法里不能用 this，全部用类名调用
 */
export class SessionManager {

  private static _user: UserInfo | null = null
  private static _listeners: SessionListener[] = []

  // ==================== 生命周期 ====================

  static init(): void {
    const token = TokenStore.getToken()
    if (token && token.length > 0) {
      SessionManager._user = { userId: 0, username: '' }
      Logger.i('[Session] 从存储恢复登录态')
    } else {
      SessionManager._user = null
      Logger.i('[Session] 无有效登录态')
    }
  }

  // ==================== 查询 ====================

  static isLoggedIn(): boolean {
    const token = TokenStore.getToken()
    return !!token && token.length > 0
  }

  static getUser(): UserInfo | null {
    return SessionManager._user
  }

  static getUserId(): number {
    return SessionManager._user ? SessionManager._user.userId : 0
  }

  // ==================== 状态变更 ====================

  static notifyLogin(user: UserInfo | null): void {
    SessionManager._user = user
    Logger.i(`[Session] 登录成功 userId=${user ? user.userId : 'unknown'}`)
    SessionManager._broadcast()
  }

  static logout(): void {
    TokenStore.clear()
    SessionManager._user = null
    Logger.i('[Session] 已登出')
    SessionManager._broadcast()
  }

  // ==================== 监听器 ====================

  static onChange(cb: SessionListener): void {
    SessionManager._listeners.push(cb)
  }

  private static _broadcast(): void {
    const loggedIn = SessionManager.isLoggedIn()
    for (let i = 0; i < SessionManager._listeners.length; i++) {
      try {
        SessionManager._listeners[i](loggedIn)
      } catch (e) {
        Logger.e(`[Session] 监听器异常: ${(e as Error).message}`)
      }
    }
  }
}