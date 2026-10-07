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

  // ⭐ 新增：消息类型 text / image / card / video
  messageType: string = 'text'
}