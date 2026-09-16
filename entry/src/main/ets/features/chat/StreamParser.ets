import { ChatMessage } from '../../domain/models/ChatMessage'

export class StreamParseState {
  buffer: string = ''
  thinkingActive: boolean = false
  answerActive: boolean = false
}

export class StreamParser {
  static parse(chunk: string, state: StreamParseState, msg: ChatMessage): void {
    state.buffer += chunk
    while (state.buffer.length > 0) {
      const ch = state.buffer.charAt(0)
      state.buffer = state.buffer.substring(1)

      if (!state.thinkingActive && !state.answerActive) {
        if (ch === '<' && state.buffer.startsWith('think>')) {
          state.buffer = state.buffer.substring(6)
          state.thinkingActive = true
          msg.thinkingDone = false
          continue
        } else {
          state.answerActive = true
          msg.content += ch
        }
      } else if (state.thinkingActive) {
        if (ch === '<' && state.buffer.startsWith('/think>')) {
          state.buffer = state.buffer.substring(7)
          state.thinkingActive = false
          msg.thinkingDone = true
          continue
        } else {
          msg.thinking += ch
        }
      } else {
        msg.content += ch
      }
    }
  }
}