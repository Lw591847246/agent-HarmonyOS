import http from '@ohos.net.http'
import { ChatUseCase, SendStreamOptions } from './ChatUseCase'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { FileItem } from '../../domain/models/FileItem'

export class ChatViewModel {
  private uc: ChatUseCase

  constructor(context: Context) {
    this.uc = new ChatUseCase(context)
  }
  createUserMessage(text: string, files?: string[]): ChatMessage {
    const m = ChatUseCase.createMessage('user', text)
    if (files) m.files = files
    return m
  }

  createAssistantPlaceholder(): ChatMessage {
    const m = ChatUseCase.createMessage('assistant', '')
    m.thinkingDone = false
    return m
  }

  sendStream(opt: SendStreamOptions): http.HttpRequest {
    return this.uc.sendStream(opt)
  }

  sendFiles(sessionId: string, text: string, files: FileItem[]): Promise<ChatMessage> {
    return this.uc.sendFiles(sessionId, text, files)
  }

  ocr(files: FileItem[]): Promise<ChatMessage> {
    return this.uc.ocr(files)
  }
}