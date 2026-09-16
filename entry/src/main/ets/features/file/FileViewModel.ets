import picker from '@ohos.file.picker'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { FileUseCase } from './FileUseCase'
import { FileItem } from '../../domain/models/FileItem'
import { Logger } from '../../common/logger/Logger'

export class FileViewModel {
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
}