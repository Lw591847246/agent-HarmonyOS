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
  cardVersion: number = 0          // ⭐ 新增

  messageType: string = 'text'
}