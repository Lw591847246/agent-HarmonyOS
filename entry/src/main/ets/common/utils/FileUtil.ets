export class FileUtil {
  /** 从 uri 中提取文件名，并做 URL 解码 */
  static nameFromUri(uri: string): string {
    if (!uri) return ''
    const idx = uri.lastIndexOf('/')
    let name = idx >= 0 ? uri.substring(idx + 1) : uri
    // 去掉可能存在的查询参数
    const qIdx = name.indexOf('?')
    if (qIdx >= 0) name = name.substring(0, qIdx)
    // URL 解码（%E7%AE%80 → 简）
    try {
      name = decodeURIComponent(name)
    } catch (e) {
      // 解码失败就保留原样
    }
    return name
  }
}