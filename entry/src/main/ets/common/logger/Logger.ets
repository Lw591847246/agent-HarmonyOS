import hilog from '@ohos.hilog'

const DOMAIN = 0x0001
const TAG = 'AgentApp'

export class Logger {
  private static readonly ENABLED: boolean = true

  static i(msg: string): void {
    if (!Logger.ENABLED) return
    hilog.info(DOMAIN, TAG, '%{public}s', msg)
  }

  static e(msg: string): void {
    if (!Logger.ENABLED) return
    hilog.error(DOMAIN, TAG, '%{public}s', msg)
  }

  static json(label: string, obj: Object): void {
    if (!Logger.ENABLED) return
    try {
      hilog.info(DOMAIN, TAG, '%{public}s', `${label}: ${JSON.stringify(obj)}`)
    } catch (e) {
      Logger.e(`${label}: [序列化失败]`)
    }
  }
}