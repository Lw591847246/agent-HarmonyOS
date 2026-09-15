import { EnvConfig } from '../config/EnvConfig'

export type ServiceName = 'auth' | 'agent'

export class ServiceRouter {
  static getBaseUrl(service: ServiceName): string {
    switch (service) {
      case 'auth': return EnvConfig.AUTH_BASE_URL
      case 'agent': return EnvConfig.AGENT_BASE_URL
      default: return ''
    }
  }
}