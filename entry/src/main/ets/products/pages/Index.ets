import { ChatPage } from './ChatPage'
import { LoginPage } from './LoginPage'
import { TokenStore } from '../../common/storage/TokenStore'

@Entry
@Component
struct Index {
  @State loggedIn: boolean = false

  aboutToAppear(): void {
    this.loggedIn = TokenStore.getToken().length > 0
  }

  build() {
    Stack() {
      if (this.loggedIn) {
        ChatPage({ onLogout: () => { this.loggedIn = false } })
      } else {
        LoginPage({ onLoginSuccess: () => { this.loggedIn = true } })
      }
    }.width('100%').height('100%')
  }
}