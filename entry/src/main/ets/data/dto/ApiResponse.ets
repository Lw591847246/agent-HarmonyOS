export interface ApiResponse<T = Object> {
  code: number
  message: string
  data: T
  total?: number
  success?: boolean
}