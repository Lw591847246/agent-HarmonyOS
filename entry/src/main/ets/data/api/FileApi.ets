import { ChatApi } from './ChatApi'
import { HttpUploadFile } from '../../common/network/HttpClient'
import { FileItem } from '../../domain/models/FileItem'
import { OcrResponseDto, ProcessFileResponseDto } from '../dto/Types'

/** FileItem → HttpUploadFile 的适配（明确返回类型） */
export function toHttpFile(f: FileItem): HttpUploadFile {
  const result: HttpUploadFile = { name: f.name, uri: f.uri }
  return result
}

export class FileApi {
  static uploadAndProcess(
    sessionId: string, text: string, files: FileItem[]
  ): Promise<ProcessFileResponseDto> {
    const httpFiles: HttpUploadFile[] = []
    for (let i = 0; i < files.length; i++) {
      httpFiles.push(toHttpFile(files[i]))
    }
    return ChatApi.processFile(sessionId, text, httpFiles)
  }

  static ocr(files: FileItem[]): Promise<OcrResponseDto> {
    const httpFiles: HttpUploadFile[] = []
    for (let i = 0; i < files.length; i++) {
      httpFiles.push(toHttpFile(files[i]))
    }
    return ChatApi.ocr(httpFiles)
  }
}