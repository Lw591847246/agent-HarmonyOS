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
  // ⭐ 客户端幂等 ID：user 消息落库后原样回传；assistant 消息不用
  clientId: string = ''
}