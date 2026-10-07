import { FormField, HttpClient } from '../../common/network/HttpClient'
import { ApiUrls } from '../../common/network/ApiUrls'
import { FileItem } from '../../domain/models/FileItem'
import { SandboxFileUtil } from '../../common/utils/SandboxFileUtil'
import { Logger } from '../../common/logger/Logger'
import { UploadAssetRespDto } from '../dto/Types'
import fs from '@ohos.file.fs'

export class FileApi {

  /**
   * ⭐ 通用上传：把本地文件上传到 /agent/v1/upload/asset
   */
  static async uploadAsset(
    context: Context,
    sessionId: string,
    file: FileItem
  ): Promise<UploadAssetRespDto> {
    const sandboxPath = SandboxFileUtil.copyToSandbox(context, file.uri, file.name)
    if (!sandboxPath) {
      throw new Error(`文件拷贝到沙箱失败: ${file.name}`)         // ⭐ 抛 Error
    }
    try {

      const stat = fs.statSync(sandboxPath)
      const sizeMB = stat.size / 1024 / 1024
      Logger.i(`[FileApi] 上传文件 ${file.name} size=${sizeMB.toFixed(1)}MB`)

      if (sizeMB > 50) {
        throw new Error(`视频过大（${sizeMB.toFixed(1)}MB），请压缩到 50MB 以内或选择更短的视频`)
      }


      const fields: FormField[] = [
        { key: 'session_id', value: sessionId }
      ]
      return await HttpClient.uploadSingleFile<UploadAssetRespDto>(
        'agent',
        ApiUrls.UPLOAD_ASSET,
        sandboxPath,
        file.name,
        'file',
        fields
      )
    } finally {
      SandboxFileUtil.deleteFile(sandboxPath)
    }
  }

  static async uploadAssetBatch(
    context: Context,
    sessionId: string,
    files: FileItem[]
  ): Promise<UploadAssetRespDto[]> {
    const result: UploadAssetRespDto[] = []
    for (let i = 0; i < files.length; i++) {
      const r = await FileApi.uploadAsset(context, sessionId, files[i])
      result.push(r)
    }
    return result
  }
}