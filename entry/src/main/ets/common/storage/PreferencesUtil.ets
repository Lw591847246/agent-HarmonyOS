import preferences from '@ohos.data.preferences'
import { Logger } from '../logger/Logger'

export class PreferencesUtil {
  private static prefs: preferences.Preferences | null = null

  static async init(context: Context, storeName: string): Promise<void> {
    try {
      PreferencesUtil.prefs = await preferences.getPreferences(context, storeName)
    } catch (e) {
      Logger.e(`PreferencesUtil.init 失败: ${(e as Error).message}`)
    }
  }

  static async getString(key: string, def: string): Promise<string> {
    if (!PreferencesUtil.prefs) return def
    return await PreferencesUtil.prefs.get(key, def) as string
  }

  static async putString(key: string, value: string): Promise<void> {
    if (!PreferencesUtil.prefs) return
    await PreferencesUtil.prefs.put(key, value)
    await PreferencesUtil.prefs.flush()
  }

  static async delete(key: string): Promise<void> {
    if (!PreferencesUtil.prefs) return
    await PreferencesUtil.prefs.delete(key)
    await PreferencesUtil.prefs.flush()
  }
}