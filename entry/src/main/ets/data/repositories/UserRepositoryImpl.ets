import { UserApi } from '../services/UserApi'
import {
  IUserRepository, RegisterParams
} from '../../domain/repositories/IUserRepository'
import { LoginCredential, User } from '../../domain/models/User'
import { AppError } from '../../common/exceptions/AppError'
import { LoginResponseDto, RegisterRequestDto } from '../dto/Types'

export class UserRepositoryImpl implements IUserRepository {
  async login(username: string, password: string): Promise<LoginCredential> {
    const resp = await UserApi.login({ username, password })

    const root: LoginResponseDto | undefined = resp.data

    let authorization: string = ''
    if (root) {
      if (root.authorization) {
        authorization = root.authorization
      } else if (root.token) {
        authorization = root.token.startsWith('Bearer ')
          ? root.token
          : 'Bearer ' + root.token
      }
    }

    if (!authorization) throw AppError.business('登录返回缺少 authorization')

    const user: User = {
      userId: root && root.userId ? String(root.userId) : '',
      username: root && root.username ? root.username : username
    }
    const credential: LoginCredential = {
      authorization: authorization,
      user: user
    }
    return credential
  }

  async register(params: RegisterParams): Promise<void> {
    const body: RegisterRequestDto = {
      username: params.username,
      realName: params.realName,
      phone: params.phone,
      email: params.email,
      password: params.password,
      confirmPassword: params.confirmPassword
    }
    await UserApi.register(body)
  }
}