import picker from '@ohos.file.picker'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { cameraPicker, camera } from '@kit.CameraKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { FileUseCase } from './FileUseCase'
import { FileItem } from '../../domain/models/FileItem'
import { Logger } from '../../common/logger/Logger'

export class FileViewModel {
  private ctx: common.Context

  constructor(ctx: common.Context) {
    this.ctx = ctx
  }

  /** 从相册选图 */
  async pickImages(max: number = 3): Promise<FileItem[]> {
    try {
      const p = new photoAccessHelper.PhotoViewPicker()
      const r = await p.select({
        maxSelectNumber: max,
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      })
      return FileUseCase.fromUriList(r.photoUris)
    } catch (e) {
      Logger.e('选择图片失败: ' + (e as Error).message)
      return []
    }
  }

  /** 从文件选择器选文件 */
  async pickDocuments(max: number = 3): Promise<FileItem[]> {
    try {
      const d = new picker.DocumentViewPicker()
      const uris = await d.select({ maxSelectNumber: max })
      return FileUseCase.fromUriList(uris)
    } catch (e) {
      Logger.e('选择文件失败: ' + (e as Error).message)
      return []
    }
  }

  /**
   * ⭐ 拍照：拉起系统相机，返回沙箱内的新文件
   * 用户取消 / 失败 → 返回 null
   */
  async capturePhoto(): Promise<FileItem | null> {
    try {
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      }

      const result: cameraPicker.PickerResult = await cameraPicker.pick(
        this.ctx,
        [cameraPicker.PickerMediaType.PHOTO],
        profile
      )

      // 用户取消或失败
      if (result.resultCode !== 0
        || !result.resultUri
        || result.resultUri.length === 0) {
        Logger.i('[FileViewModel] 用户取消拍照')
        return null
      }

      // ⭐ 相机返回的 uri 是临时的，立刻拷贝到沙箱
      const name = `camera_${Date.now()}.jpg`
      const destPath = `${this.ctx.cacheDir}/${name}`

      // 用 fd 方式拷贝，兼容 media uri
      const srcFile = fs.openSync(result.resultUri, fs.OpenMode.READ_ONLY)
      const destFile = fs.openSync(
        destPath,
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC
      )
      try {
        fs.copyFileSync(srcFile.fd, destFile.fd)
      } finally {
        fs.closeSync(srcFile)
        fs.closeSync(destFile)
      }

      Logger.i(`[FileViewModel] 拍照成功 → ${destPath}`)
      return {
        name: name,
        uri: `file://${destPath}`
      }
    } catch (e) {
      Logger.e('拍照失败: ' + (e as Error).message)
      return null
    }
  }
}