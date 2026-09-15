import { LoginCredential } from '../models/User'
import { RegisterRequestDto } from '../../data/dto/Types'

/** 直接复用 DTO 类型，避免 ArkTS 结构类型冲突 */
export type RegisterParams = RegisterRequestDto

export interface IUserRepository {
  login(username: string, password: string): Promise<LoginCredential>
  register(params: RegisterParams): Promise<void>
}