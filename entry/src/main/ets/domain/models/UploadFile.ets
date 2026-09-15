export interface UploadFile {
  name: string
  uri: string
}

export function createUploadFileFromUri(uri: string): UploadFile {
  const name = uri.substring(uri.lastIndexOf('/') + 1)
  return { name, uri }
}