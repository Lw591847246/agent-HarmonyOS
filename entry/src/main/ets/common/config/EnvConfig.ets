/**
 * 环境配置，对标后端 application.yml
 * 切换环境只改这里
 */
export class EnvConfig {
  // 服务地址（内网穿透）
  static readonly AUTH_BASE_URL: string = 'http://1b6e4f94.r26.cpolar.top'
  static readonly AGENT_BASE_URL: string = 'http://3a5df093.r26.cpolar.top'
}