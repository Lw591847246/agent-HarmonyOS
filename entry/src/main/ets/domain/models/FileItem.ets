/** 领域层：用户待上传的文件 */
export interface FileItem {
  name: string
  uri: string
  type?: string       // ⭐ 'image' | 'video' | 'doc'
}