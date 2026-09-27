import { ChatPage } from '../../features/chat/ChatPage'

@Component
export struct AppShell {
  @Provide('navStack') navStack: NavPathStack = new NavPathStack()

  build() {
    Navigation(this.navStack) {
      ChatPage()
    }
    .navDestination(this.pageMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
  }

  @Builder
  pageMap(name: string, param: object) {
    // ⚠️ @Builder 里只能写 UI
    // 用 if/else 结构，把未注册的路由显示成醒目提示
    if (name === '__never__') {
      // 这个分支永远不会命中，纯占位
      Column()
    } else {
      // 未注册的路由显示错误提示（调试友好）
      Column() {
        Text(`未注册路由: ${name}`)
          .fontSize(16).fontColor('#e74c3c')
        Text('请检查 AppShell.pageMap')
          .fontSize(12).fontColor('#999').margin({ top: 8 })
      }
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }
}