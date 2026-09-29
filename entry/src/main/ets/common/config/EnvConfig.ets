/**
 * 环境配置，对标后端 application.yml
 * 切换环境只改这里
 */
export class EnvConfig {
  // 服务地址（内网穿透）
  static readonly AUTH_BASE_URL: string = 'http://1ca22d02.r27.cpolar.top'
  static readonly AGENT_BASE_URL: string = 'http://c58205c.r27.cpolar.top'
}