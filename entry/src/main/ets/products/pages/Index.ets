import { LoginPage } from '../../features/auth/LoginPage'
import { SessionManager } from '../../core/session/SessionManager'
import { Logger } from '../../common/logger/Logger'
import { AppShell } from '../../core/router/AppShell'

@Entry
@Component
struct Index {
  @State loggedIn: boolean = false

  aboutToAppear(): void {
    SessionManager.init()
    this.loggedIn = SessionManager.isLoggedIn()
    SessionManager.onChange((loggedIn: boolean) => {
      Logger.i(`[Index] 登录态变化: ${loggedIn}`)
      this.loggedIn = loggedIn
    })
  }

  build() {
    Stack() {
      if (this.loggedIn) {
        AppShell()
      } else {
        LoginPage()
      }
    }
    .width('100%')
    .height('100%')
  }
}