/**
 * 环境配置，对标后端 application.yml
 * 切换环境只改这里
 */
export class EnvConfig {
  // 服务地址（内网穿透）
  static readonly AUTH_BASE_URL: string = 'http://111baea6.r27.cpolar.top'
  static readonly AGENT_BASE_URL: string = 'http://15b98615.r27.cpolar.top'
}