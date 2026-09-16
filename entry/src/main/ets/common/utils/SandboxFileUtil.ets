import fs from '@ohos.file.fs'
import { Logger } from '../logger/Logger'

export class SandboxFileUtil {

  /** 提取扩展名（含点） */
  static getExtension(name: string): string {
    const idx = name.lastIndexOf('.')
    return idx >= 0 ? name.substring(idx) : ''
  }

  /**
   * 把外部 uri 拷到应用沙箱，沙箱名只用 ASCII
   * 返回沙箱绝对路径，失败返回空字符串
   */
  static copyToSandbox(context: Context, srcUri: string, origName: string): string {
    const cacheDir = context.cacheDir
    const ext = SandboxFileUtil.getExtension(origName)
    const targetName = `upload_${Date.now()}_${Math.floor(Math.random() * 100000)}${ext}`
    const targetPath = `${cacheDir}/${targetName}`

    let srcFile: fs.File | null = null
    let dstFile: fs.File | null = null
    try {
      srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY)
      dstFile = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      fs.copyFileSync(srcFile.fd, dstFile.fd)
    } catch (e) {
      Logger.e(`拷贝文件失败: ${(e as Error).message}`)
      return ''
    } finally {
      if (srcFile) fs.closeSync(srcFile)
      if (dstFile) fs.closeSync(dstFile)
    }

    // 验证非空
    try {
      const stat = fs.statSync(targetPath)
      Logger.i(`沙箱文件: ${targetPath}, 大小: ${stat.size}`)
      if (stat.size === 0) {
        Logger.e('沙箱文件为空，清理')
        SandboxFileUtil.deleteFile(targetPath)
        return ''
      }
    } catch (e) {
      Logger.e(`statSync 失败: ${(e as Error).message}`)
      return ''
    }

    return targetPath
  }

  /** 删除单个沙箱文件 */
  static deleteFile(path: string): void {
    if (!path) return
    try {
      fs.unlinkSync(path)
      Logger.i(`已删除沙箱文件: ${path}`)
    } catch (e) {
      Logger.e(`删除沙箱文件失败: ${(e as Error).message}`)
    }
  }

  /** 批量删除 */
  static deleteFiles(paths: string[]): void {
    for (let i = 0; i < paths.length; i++) {
      SandboxFileUtil.deleteFile(paths[i])
    }
  }

  static guessMimeType(name: string): string {
    const lower = name.toLowerCase()
    if (lower.endsWith('.pdf')) return 'application/pdf'
    if (lower.endsWith('.doc')) return 'application/msword'
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    }
    if (lower.endsWith('.txt')) return 'text/plain'
    if (lower.endsWith('.md')) return 'text/markdown'
    if (lower.endsWith('.json')) return 'application/json'
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel'
    if (lower.endsWith('.png')) return 'image/png'
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg'
    if (lower.endsWith('.gif')) return 'image/gif'
    if (lower.endsWith('.webp')) return 'image/webp'
    return 'application/octet-stream'
  }
}