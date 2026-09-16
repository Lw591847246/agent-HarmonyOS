export interface ChatRequestDto {
  text: string
  session_id: string
}

export interface ProcessFileResponseDto {
  type: string
  content?: string
  results?: ProcessFileResultItemDto[]
}

export interface ProcessFileResultItemDto {
  type: string
  content?: string
  image_base64?: string
}

export interface StreamJsonResponseDto {
  type?: string
  content?: string
  image_base64?: string
  results?: StreamJsonResultItemDto[]
}

export interface StreamJsonResultItemDto {
  type?: string
  content?: string
  image_base64?: string
}

export interface OcrResponseDto {
  type: string
  results: OcrResultItemDto[]
}

export interface OcrResultItemDto {
  filename: string
  text: string
}