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

  // ⭐ 按扩展名判断类型
  private static guessType(name: string): string {
    const lower = name.toLowerCase()
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')
      || lower.endsWith('.avi') || lower.endsWith('.mkv')
      || lower.endsWith('.webm')) {
      return 'video'
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')
      || lower.endsWith('.png') || lower.endsWith('.webp')
      || lower.endsWith('.bmp') || lower.endsWith('.gif')) {
      return 'image'
    }
    return 'doc'
  }

  /** 从相册选图 */
  async pickImages(max: number = 3): Promise<FileItem[]> {
    try {
      const p = new photoAccessHelper.PhotoViewPicker()
      const r = await p.select({
        maxSelectNumber: max,
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      })
      const list = FileUseCase.fromUriList(r.photoUris)
      for (let i = 0; i < list.length; i++) {
        list[i].type = 'image'
      }
      return list
    } catch (e) {
      Logger.e('选择图片失败: ' + (e as Error).message)
      return []
    }
  }

  /** 从相册选视频 */
  async pickVideo(max: number = 1): Promise<FileItem[]> {
    try {
      const p = new photoAccessHelper.PhotoViewPicker()
      const r = await p.select({
        maxSelectNumber: max,
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE
      })
      const list = FileUseCase.fromUriList(r.photoUris)
      for (let i = 0; i < list.length; i++) {
        list[i].type = 'video'
      }
      return list
    } catch (e) {
      Logger.e('选择视频失败: ' + (e as Error).message)
      return []
    }
  }

  /** 从文件选择器选文件（可能是文档，也可能是图片/视频） */
  async pickDocuments(max: number = 3): Promise<FileItem[]> {
    try {
      const d = new picker.DocumentViewPicker()
      const uris = await d.select({ maxSelectNumber: max })
      const list = FileUseCase.fromUriList(uris)
      for (let i = 0; i < list.length; i++) {
        list[i].type = FileViewModel.guessType(list[i].name)
      }
      return list
    } catch (e) {
      Logger.e('选择文件失败: ' + (e as Error).message)
      return []
    }
  }

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

      if (result.resultCode !== 0
        || !result.resultUri
        || result.resultUri.length === 0) {
        return null
      }

      const name = `camera_${Date.now()}.jpg`
      const destPath = `${this.ctx.cacheDir}/${name}`

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

      const item: FileItem = {
        name: name,
        uri: `file://${destPath}`,
        type: 'image'
      }
      return item
    } catch (e) {
      Logger.e('拍照失败: ' + (e as Error).message)
      return null
    }
  }
}