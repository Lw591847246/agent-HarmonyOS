import { ChatPage } from '../../features/chat/ChatPage'
import { RouteNames } from './RouteNames'
import { ImageEditorPage } from '../../features/imageeditor/ImageEditorPage'
import { ImageEditorParams } from '../../features/imageeditor/models/ImageEditorParams'

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
    if (name === RouteNames.IMAGE_EDITOR) {
      ImageEditorPage({ params: param as ImageEditorParams })
    } else {
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