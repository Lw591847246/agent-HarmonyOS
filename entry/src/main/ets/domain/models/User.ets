export interface User {
  userId: string
  username: string
  realName?: string
  avatar?: string
}

export interface LoginCredential {
  authorization: string
  user: User
}