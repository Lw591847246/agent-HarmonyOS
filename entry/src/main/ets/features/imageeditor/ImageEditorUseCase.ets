import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
import { Logger } from '../../common/logger/Logger'
import { ImageEditorResult } from './models/ImageEditorParams'

/**
 * 图片编辑用例（纯业务逻辑，可单测）
 * - 读取图片尺寸
 * - 裁剪 + 编码 + 落盘
 * - 不改动原图
 */
export class ImageEditorUseCase {

  /** 读取图片原始像素尺寸 */
  static async readImageSize(srcUri: string): Promise<image.Size> {
    const file = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY)
    let source: image.ImageSource | null = null
    try {
      source = image.createImageSource(file.fd)
      const info = await source.getImageInfo()
      return info.size
    } finally {
      if (source) await source.release()
      fileIo.closeSync(file)
    }
  }

  /**
   * 裁剪并保存到沙箱，返回新文件信息
   * @param srcUri 原图 uri
   * @param srcName 原图文件名
   * @param outputDir 输出目录（调用方传 cacheDir 或 filesDir）
   * @param cropX/Y/W/H 裁剪区域，原图像素坐标
   */
  static async cropAndSave(
    srcUri: string,
    srcName: string,
    outputDir: string,
    cropX: number,
    cropY: number,
    cropW: number,
    cropH: number
  ): Promise<ImageEditorResult> {
    const x = Math.max(0, Math.round(cropX))
    const y = Math.max(0, Math.round(cropY))
    const w = Math.max(1, Math.round(cropW))
    const h = Math.max(1, Math.round(cropH))

    Logger.i(`[ImageEditorUseCase] crop (${x},${y},${w},${h}) src=${srcUri}`)

    const srcFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY)
    let source: image.ImageSource | null = null
    let pixelMap: image.PixelMap | null = null
    let packer: image.ImagePacker | null = null
    let outFile: fileIo.File | null = null

    try {
      source = image.createImageSource(srcFile.fd)
      pixelMap = await source.createPixelMap({
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      })

      await pixelMap.crop({
        x: x,
        y: y,
        size: { width: w, height: h }
      })

      const ext = ImageEditorUseCase._pickExt(srcName)
      const format = ImageEditorUseCase._packerFormat(ext)
      const outName = ImageEditorUseCase._buildOutputName(srcName, ext)
      const outPath = `${outputDir}/${outName}`

      outFile = fileIo.openSync(
        outPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      )

      packer = image.createImagePacker()
      await packer.packToFile(pixelMap, outFile.fd, {
        format: format,
        quality: 92
      })

      Logger.i(`[ImageEditorUseCase] 裁剪完成 → ${outPath}`)

      return {
        uri: `file://${outPath}`,
        name: outName,
        originUri: srcUri
      }
    } finally {
      if (packer) { try { await packer.release() } catch (e) {} }
      if (pixelMap) { try { await pixelMap.release() } catch (e) {} }
      if (source) { try { await source.release() } catch (e) {} }
      if (outFile) { try { fileIo.closeSync(outFile) } catch (e) {} }
      try { fileIo.closeSync(srcFile) } catch (e) {}
    }
  }

  private static _pickExt(name: string): string {
    const dot = name.lastIndexOf('.')
    if (dot < 0) return 'jpg'
    const ext = name.substring(dot + 1).toLowerCase()
    if (ext === 'png' || ext === 'webp' || ext === 'jpg' || ext === 'jpeg') {
      return ext === 'jpeg' ? 'jpg' : ext
    }
    return 'jpg'
  }

  private static _packerFormat(ext: string): string {
    if (ext === 'png') return 'image/png'
    if (ext === 'webp') return 'image/webp'
    return 'image/jpeg'
  }

  private static _buildOutputName(srcName: string, ext: string): string {
    const dot = srcName.lastIndexOf('.')
    const base = dot > 0 ? srcName.substring(0, dot) : srcName
    const safeBase = base.length > 20 ? base.substring(0, 20) : base
    return `${safeBase}_crop_${Date.now()}.${ext}`
  }
}