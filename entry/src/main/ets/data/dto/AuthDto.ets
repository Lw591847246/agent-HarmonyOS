export interface LoginRequestDto {
  username: string
  password: string
}

export interface LoginResponseDto {
  userId?: number
  username?: string
  token?: string
  authorization?: string
}

export interface RegisterRequestDto {
  username: string
  realName: string
  phone: string
  email: string
  password: string
  confirmPassword: string
}