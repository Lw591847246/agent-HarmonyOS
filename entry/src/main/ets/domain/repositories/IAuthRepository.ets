export interface LoginResult {
  authorization: string
  userId: string
}

export interface RegisterParams {
  username: string
  realName: string
  phone: string
  email: string
  password: string
  confirmPassword: string
}

export interface IAuthRepository {
  login(username: string, password: string): Promise<LoginResult>
  register(params: RegisterParams): Promise<void>
}