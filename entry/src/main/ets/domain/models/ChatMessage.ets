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
}