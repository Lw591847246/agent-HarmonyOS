import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { Logger } from '../logger/Logger'

/**
 * 麦克风权限动态申请
 * 返回 true 表示已授权
 */
export async function ensureMicPermission(ctx: common.UIAbilityContext): Promise<boolean> {
  const atManager = abilityAccessCtrl.createAtManager()
  try {
    const perms: Permissions[] = ['ohos.permission.MICROPHONE']
    const result = await atManager.requestPermissionsFromUser(ctx, perms)
    return result.authResults.length > 0 && result.authResults[0] === 0
  } catch (e) {
    Logger.e(`[Permission] mic request failed: ${(e as Error).message}`)
    return false
  }
}