import { UserRepositoryImpl } from '../../data/repositories/UserRepositoryImpl'
import { IUserRepository, RegisterParams } from '../../domain/repositories/IUserRepository'
import { LoginCredential } from '../../domain/models/User'
import { TokenStore } from '../../common/storage/TokenStore'

export class AuthUseCase {
  private repo: IUserRepository = new UserRepositoryImpl()

  /** 登录成功后自动持久化 token */
  async login(username: string, password: string): Promise<LoginCredential> {
    const credential = await this.repo.login(username, password)
    await TokenStore.setToken(credential.authorization, credential.user.userId)
    return credential
  }

  register(params: RegisterParams): Promise<void> {
    return this.repo.register(params)
  }

  async logout(): Promise<void> {
    await TokenStore.clear()
  }
}