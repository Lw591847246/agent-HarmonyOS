import { PreferencesUtil } from './PreferencesUtil'

const STORE_NAME = 'agent_store'
const KEY_TOKEN = 'authorization'
const KEY_USER = 'user_id'
const KEY_IN_APP = 'auth_token'
const KEY_USER_IN_APP = 'user_id_app'

export class TokenStore {
  static async init(context: Context): Promise<void> {
    await PreferencesUtil.init(context, STORE_NAME)
    AppStorage.setOrCreate(KEY_IN_APP, await PreferencesUtil.getString(KEY_TOKEN, ''))
    AppStorage.setOrCreate(KEY_USER_IN_APP, await PreferencesUtil.getString(KEY_USER, ''))
  }

  static getToken(): string {
    return AppStorage.get<string>(KEY_IN_APP) ?? ''
  }

  static getUserId(): string {
    return AppStorage.get<string>(KEY_USER_IN_APP) ?? ''
  }

  static async setToken(token: string, userId: string): Promise<void> {
    if (!token) throw new Error('token 为空')
    AppStorage.setOrCreate(KEY_IN_APP, token)
    AppStorage.setOrCreate(KEY_USER_IN_APP, userId)
    await PreferencesUtil.putString(KEY_TOKEN, token)
    await PreferencesUtil.putString(KEY_USER, userId)
  }

  static async clear(): Promise<void> {
    AppStorage.setOrCreate(KEY_IN_APP, '')
    AppStorage.setOrCreate(KEY_USER_IN_APP, '')
    await PreferencesUtil.delete(KEY_TOKEN)
    await PreferencesUtil.delete(KEY_USER)
  }
}