import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { common } from '@kit.AbilityKit'
import { TokenStore } from '../storage/TokenStore'
import { EnvConfig } from '../config/EnvConfig'
import { Logger } from '../logger/Logger'
import { MediaCache } from './MediaCache'

export class DownloadUtil {

  /**
   * 从后端下载文件到沙箱
   */
  static async downloadToSandbox(relativeUrl: string, filename: string): Promise<string> {
    const ctx = getContext() as common.UIAbilityContext
    const sandboxPath = `${ctx.cacheDir}/${filename}`
    const url = `${EnvConfig.AGENT_BASE_URL}${relativeUrl}`
    Logger.i(`[Download] 开始下载: ${url}`)

    return new Promise<string>((resolve, reject) => {
      const req = http.createHttp()
      req.request(
        url,
        {
          method: http.RequestMethod.GET,
          header: {
            'Authorization': TokenStore.getToken()
          },
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: 10000,
          readTimeout: 5 * 60 * 1000
        },
        (err, data) => {
          req.destroy()
          if (err) {
            reject(new Error(`下载失败: ${err.message}`))
            return
          }
          if (data.responseCode !== 200) {
            reject(new Error(`下载失败 HTTP ${data.responseCode}`))
            return
          }
          try {
            const file = fs.openSync(
              sandboxPath,
              fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC
            )
            try {
              fs.writeSync(file.fd, data.result as ArrayBuffer)
            } finally {
              fs.closeSync(file)
            }
            Logger.i(`[Download] 已落地到沙箱: ${sandboxPath}`)
            resolve(sandboxPath)
          } catch (e) {
            reject(new Error(`写入沙箱失败: ${(e as Error).message}`))
          }
        }
      )
    })
  }

  /**
   * ⭐ 优先从 MediaCache 拿，未命中才下载。
   * 返回沙箱绝对路径。
   */
  static async getOrDownload(relativeUrl: string): Promise<string | null> {
    const cached = await MediaCache.ensureCached(relativeUrl)
    return cached
  }

  /**
   * 弹出"另存为"选择器，把沙箱文件拷贝到用户选定的位置
   */
  static async saveToUserLocation(sandboxPath: string, filename: string): Promise<boolean> {
    try {
      const docPicker = new picker.DocumentViewPicker()
      const options = new picker.DocumentSaveOptions()
      options.newFileNames = [filename]

      const uris = await docPicker.save(options)
      if (!uris || uris.length === 0) {
        Logger.i('[Download] 用户取消保存')
        return false
      }

      const srcFile = fs.openSync(sandboxPath, fs.OpenMode.READ_ONLY)
      try {
        const stat = fs.statSync(srcFile.fd)
        const buf = new ArrayBuffer(stat.size)
        fs.readSync(srcFile.fd, buf)

        const destFile = fs.openSync(
          uris[0],
          fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC
        )
        try {
          fs.writeSync(destFile.fd, buf)
        } finally {
          fs.closeSync(destFile)
        }
      } finally {
        fs.closeSync(srcFile)
      }

      Logger.i(`[Download] 已保存到: ${uris[0]}`)
      return true
    } catch (e) {
      Logger.e(`[Download] 保存失败: ${(e as Error).message}`)
      throw new Error(`保存失败: ${(e as Error).message}`)
    }
  }

  /**
   * ⭐ 一站式保存：走 MediaCache 拿本地 → 保存到用户位置。
   * 与 downloadAndSave 的区别：优先用缓存，不重新下载。
   */
  static async saveCachedToUser(relativeUrl: string, filename: string): Promise<boolean> {
    // 1. 先确保缓存
    const cached = await MediaCache.ensureCached(relativeUrl)
    if (!cached) {
      throw new Error('获取视频失败')
    }
    // 2. 弹窗另存为
    return await DownloadUtil.saveToUserLocation(cached, filename)
  }

  /**
   * 旧的：下载 + 保存 + 清理沙箱
   * 保留兼容
   */
  static async downloadAndSave(relativeUrl: string, filename: string): Promise<boolean> {
    const sandboxPath = await DownloadUtil.downloadToSandbox(relativeUrl, filename)
    try {
      return await DownloadUtil.saveToUserLocation(sandboxPath, filename)
    } finally {
      try { fs.unlinkSync(sandboxPath) } catch (_) { /* ignore */ }
    }
  }
}