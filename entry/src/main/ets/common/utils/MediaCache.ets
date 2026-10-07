import fs from '@ohos.file.fs'
import { http } from '@kit.NetworkKit'
import { common } from '@kit.AbilityKit'
import { EnvConfig } from '../config/EnvConfig'
import { TokenStore } from '../storage/TokenStore'
import { Logger } from '../logger/Logger'

const CACHE_DIR_NAME = 'media_cache'

/**
 * 媒体缓存：
 * - 视频/图片下载到 cacheDir/media_cache/
 * - 提供 url 命中查询
 * - 提供清空
 */
export class MediaCache {

  private static dir(): string {
    const ctx = getContext() as common.UIAbilityContext
    return `${ctx.cacheDir}/${CACHE_DIR_NAME}`
  }

  private static ensureDir(): void {
    const d = MediaCache.dir()
    try {
      fs.mkdirSync(d)
    } catch (_) {
      // 目录已存在
    }
  }

  private static keyFromUrl(url: string): string {
    let h = 5381
    for (let i = 0; i < url.length; i++) {
      h = ((h << 5) + h) + url.charCodeAt(i)
      h = h & 0x7fffffff
    }
    return h.toString(16)
  }

  private static extFromUrl(url: string): string {
    const lower = url.toLowerCase()
    if (lower.indexOf('.mp4') >= 0) return '.mp4'
    if (lower.indexOf('.mov') >= 0) return '.mov'
    if (lower.indexOf('.webm') >= 0) return '.webm'
    if (lower.indexOf('.png') >= 0) return '.png'
    if (lower.indexOf('.jpg') >= 0 || lower.indexOf('.jpeg') >= 0) return '.jpg'
    return '.bin'
  }

  /**
   * 确保 relativeUrl 已缓存，返回本地沙箱绝对路径。
   * 未命中 → 从后端下载。
   * 失败 → 返回 null。
   */
  static async ensureCached(relativeUrl: string): Promise<string | null> {
    if (!relativeUrl || relativeUrl.length === 0) return null

    MediaCache.ensureDir()
    const key = MediaCache.keyFromUrl(relativeUrl)
    const ext = MediaCache.extFromUrl(relativeUrl)
    const localPath = `${MediaCache.dir()}/${key}${ext}`

    // 命中
    try {
      const stat = fs.statSync(localPath)
      if (stat.size > 0) {
        Logger.i(`[MediaCache] hit ${localPath} size=${stat.size}`)
        return localPath
      }
    } catch (_) {
      // miss
    }

    // 下载
    Logger.i(`[MediaCache] miss, download ${relativeUrl}`)
    const url = relativeUrl.startsWith('http')
      ? relativeUrl : `${EnvConfig.AGENT_BASE_URL}${relativeUrl}`

    return new Promise<string | null>((resolve) => {
      const req = http.createHttp()
      req.request(
        url,
        {
          method: http.RequestMethod.GET,
          header: { 'Authorization': TokenStore.getToken() },
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: 30000,
          readTimeout: 5 * 60 * 1000
        },
        (err, data) => {
          req.destroy()
          if (err || data.responseCode !== 200) {
            Logger.e(`[MediaCache] download failed: ${err ? err.message : data.responseCode}`)
            resolve(null)
            return
          }
          try {
            const file = fs.openSync(
              localPath,
              fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC
            )
            try {
              fs.writeSync(file.fd, data.result as ArrayBuffer)
            } finally {
              fs.closeSync(file)
            }
            Logger.i(`[MediaCache] saved ${localPath}`)
            resolve(localPath)
          } catch (e) {
            Logger.e(`[MediaCache] write failed: ${(e as Error).message}`)
            resolve(null)
          }
        }
      )
    })
  }

  /** 当前缓存总大小（字节） */
  static getCacheSize(): number {
    const d = MediaCache.dir()
    let total = 0
    try {
      const files = fs.listFileSync(d)
      for (let i = 0; i < files.length; i++) {
        try {
          const stat = fs.statSync(`${d}/${files[i]}`)
          total += stat.size
        } catch (_) {
          // skip
        }
      }
    } catch (_) {
      // dir 不存在
    }
    return total
  }

  /** 清空缓存 */
  static clearAll(): void {
    const d = MediaCache.dir()
    try {
      const files = fs.listFileSync(d)
      for (let i = 0; i < files.length; i++) {
        try {
          fs.unlinkSync(`${d}/${files[i]}`)
        } catch (_) {
          // skip
        }
      }
    } catch (_) {
      // dir 不存在
    }
    Logger.i('[MediaCache] cleared')
  }

  /** 格式化大小 */
  static formatSize(bytes: number): string {
    if (bytes <= 0) return '0 B'
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
    return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
  }
}