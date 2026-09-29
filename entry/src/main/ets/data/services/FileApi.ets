import { HttpUploadFile } from '../../common/network/HttpClient'
import { FileItem } from '../../domain/models/FileItem'
import { OcrResponseDto, ProcessFileResponseDto } from '../dto/Types'
import { SandboxFileUtil } from '../../common/utils/SandboxFileUtil'
import { ChatApi } from './ChatApi'
import { Logger } from '../../common/logger/Logger'
import http from '@ohos.net.http'
import { FormField } from '../../common/network/HttpClient'
import { UploadFilesStreamCallbacks } from '../../domain/repositories/IChatRepository'
import { ProcessFileStreamCallbacks } from '../../common/network/HttpClient'

export interface PreparedFiles {
  httpFiles: HttpUploadFile[]
  sandboxPaths: string[]
}

export class FileApi {

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

    const result: PreparedFiles = { httpFiles, sandboxPaths }
    return result
  }

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
      SandboxFileUtil.deleteFiles(prepared.sandboxPaths)
    }
  }

  /** ⭐ 加 clientId 参数 */
  static uploadAndProcessStream(
    context: Context,
    sessionId: string,
    text: string,
    clientId: string,          // ⭐ 新增
    files: FileItem[],
    cb: UploadFilesStreamCallbacks,
  ): http.HttpRequest {
    const prepared = FileApi.prepareFiles(context, files)

    if (prepared.httpFiles.length === 0) {
      const dummy = http.createHttp()
      Promise.resolve().then(() => { cb.onError('没有可上传的文件') })
      try { dummy.destroy() } catch (e) { /* ignore */ }
      return dummy
    }

    // ⭐ fields 里带 client_id
    const fields: FormField[] = [
      { key: 'session_id', value: sessionId },
      { key: 'text', value: text },
      { key: 'client_id', value: clientId },
    ]

    const streamCb: ProcessFileStreamCallbacks = {
      onChunk: (content: string) => { cb.onChunk(content) },
      onImage: (base64: string) => { cb.onImage(base64) },
      onFinish: () => {
        SandboxFileUtil.deleteFiles(prepared.sandboxPaths)
        cb.onFinish()
      },
      onError: (err: string) => {
        SandboxFileUtil.deleteFiles(prepared.sandboxPaths)
        cb.onError(err)
      },
    }

    return ChatApi.processFileStream(fields, prepared.httpFiles, streamCb)
  }

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