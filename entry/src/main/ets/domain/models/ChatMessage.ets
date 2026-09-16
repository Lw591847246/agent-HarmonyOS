@Observed
export class ChatMessage {
  id: string = ''
  role: string = ''                 // 'user' | 'assistant'
  content: string = ''
  thinking: string = ''
  thinkingDone: boolean = true
  duration: number = 0
  imageBase64: string = ''
  completed: boolean = false
  files: string[] = []
}