import { HttpUploadFile } from '../../common/network/HttpClient'
import { FileItem } from '../../domain/models/FileItem'
import { OcrResponseDto, ProcessFileResponseDto } from '../dto/Types'
import { SandboxFileUtil } from '../../common/utils/SandboxFileUtil'
import { ChatApi } from './ChatApi'
import { Logger } from '../../common/logger/Logger'

/** 预处理结果：上传文件 + 沙箱路径（用于上传后清理） */
export interface PreparedFiles {
  httpFiles: HttpUploadFile[]
  sandboxPaths: string[]
}

export class FileApi {

  /** 把领域文件转成可上传文件，同时记录沙箱路径 */
  static prepareFiles(context: Context, files: FileItem[]): PreparedFiles {
    const httpFiles: HttpUploadFile[] = []
    const sandboxPaths: string[] = []

    for (let i = 0; i < files.length; i++) {
      const f = files[i]
      const sandboxPath = SandboxFileUtil.copyToSandbox(context, f.uri, f.name)
      if (!sandboxPath) {
        Logger.e(`文件拷贝失败，跳过: ${f.name}`)
        continue
      }
      const hf: HttpUploadFile = {
        name: f.name,
        uri: sandboxPath,
        mimeType: SandboxFileUtil.guessMimeType(f.name)
      }
      httpFiles.push(hf)
      sandboxPaths.push(sandboxPath)
    }

    const result: PreparedFiles = {
      httpFiles: httpFiles,
      sandboxPaths: sandboxPaths
    }
    return result
  }

  /** 上传文档并处理。上传结束后自动清理沙箱文件 */
  static async uploadAndProcess(
    context: Context,
    sessionId: string,
    text: string,
    files: FileItem[]
  ): Promise<ProcessFileResponseDto> {
    const prepared = FileApi.prepareFiles(context, files)
    if (prepared.httpFiles.length === 0) {
      throw new Error('没有可上传的文件')
    }
    try {
      return await ChatApi.processFile(sessionId, text, prepared.httpFiles)
    } finally {
      // ✅ 无论成功失败，都清理沙箱文件
      SandboxFileUtil.deleteFiles(prepared.sandboxPaths)
    }
  }

  /** OCR 识别。上传结束后自动清理沙箱文件 */
  static async ocr(context: Context, files: FileItem[]): Promise<OcrResponseDto> {
    const prepared = FileApi.prepareFiles(context, files)
    if (prepared.httpFiles.length === 0) {
      throw new Error('没有可上传的文件')
    }
    try {
      return await ChatApi.ocr(prepared.httpFiles)
    } finally {
      SandboxFileUtil.deleteFiles(prepared.sandboxPaths)
    }
  }
}