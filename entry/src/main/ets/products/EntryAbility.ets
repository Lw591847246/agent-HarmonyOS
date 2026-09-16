import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window, KeyboardAvoidMode } from '@kit.ArkUI'
import { TokenStore } from '../common/storage/TokenStore'
import { Logger } from '../common/logger/Logger'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    TokenStore.init(this.context).catch((e: Error) => {
      Logger.e('TokenStore 初始化失败: ' + e.message)
    })
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('products/pages/Index', (err) => {
      if (err.code) {
        Logger.e('加载首页失败: ' + JSON.stringify(err))
        return
      }
      // ✅ 内容加载完成后，设置键盘避让模式
      try {
        const win = windowStage.getMainWindowSync()
        // RESIZE：键盘弹出时压缩窗口高度，底部输入栏自动跟随
        win.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
        Logger.i('Keyboard avoid mode set to RESIZE')
      } catch (e) {
        Logger.e('设置键盘避让模式失败: ' + (e as Error).message)
      }
    })
  }
}