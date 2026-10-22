@Observed
export class ChatMessage {
  id: string = ''
  role: string = ''
  content: string = ''
  thinking: string = ''
  imageBase64: string = ''
  thumbUrl: string = ''
  imageUrl: string = ''
  files: string[] = []
  completed: boolean = false
  thinkingDone: boolean = true
  duration: number = 0
  clientId: string = ''

  isVoice: boolean = false
  voicePath: string = ''
  voiceDuration: number = 0

  cardJson: string = ''
  cardVersion: number = 0

  messageType: string = 'text'

  // ⭐ 新增：断连恢复标记
  pending: boolean = false                    // 是否处于"后台执行中"状态
  networkDropped: boolean = false              // 是否因网络断连标记（内部用）
  networkDroppedAt: number = 0                 // 断连时间戳（毫秒），用于超时判断
}