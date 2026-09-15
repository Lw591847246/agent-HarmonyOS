import { HttpClient } from '../../common/network/HttpClient'
import { ApiUrls } from '../../common/network/ApiUrls'
import {
  ApiResponse,
  LoginRequestDto, LoginResponseDto, RegisterRequestDto,
  UserPermissionDto
} from '../dto/Types'

export class UserApi {
  static login(body: LoginRequestDto): Promise<ApiResponse<LoginResponseDto>> {
    return HttpClient.post<ApiResponse<LoginResponseDto>>('auth', ApiUrls.LOGIN, body)
  }

  static register(body: RegisterRequestDto): Promise<ApiResponse<void>> {
    return HttpClient.post<ApiResponse<void>>('auth', ApiUrls.REGISTER, body)
  }

  static getMenus(userId: number): Promise<ApiResponse<UserPermissionDto>> {
    return HttpClient.get<ApiResponse<UserPermissionDto>>(
      'auth',
      `${ApiUrls.USER_MENUS}?userId=${userId}`
    )
  }
}