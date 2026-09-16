import { FileItem } from '../../domain/models/FileItem'
import { FileUtil } from '../../common/utils/FileUtil'

export class FileUseCase {
  static fromUri(uri: string): FileItem {
    return {
      name: FileUtil.nameFromUri(uri),
      uri
    }
  }

  static fromUriList(uris: string[]): FileItem[] {
    return uris.map((u) => FileUseCase.fromUri(u))
  }
}