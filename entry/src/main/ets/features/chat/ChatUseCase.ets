import http from '@ohos.net.http'
import { ChatRepositoryImpl } from '../../data/repositories/ChatRepositoryImpl'
import { IChatRepository } from '../../domain/repositories/IChatRepository'
import { ChatMessage } from '../../domain/models/ChatMessage'
import { FileItem } from '../../domain/models/FileItem'
import { StreamParser, StreamParseState } from '../../common/network/StreamParser'
import { StreamJsonResponseDto } from '../../data/dto/Types'
import { DateUtil } from '../../common/utils/DateUtil'
import { Logger } from '../../common/logger/Logger'

let msgCounter: number = 0

export interface SendStreamOptions {
  text: string
  sessionId: string
  assistantMsg: ChatMessage
  onRefresh: () => void
  onScroll: () => void
  onFinish: () => void
}

// ⭐ 新增：文件流式选项
export interface SendFilesStreamOptions {
  sessionId: string
  text: string
  files: FileItem[]
  assistantMsg: ChatMessage
  onRefresh: () => void
  onFinish: () => void
}

export class ChatUseCase {
  private repo: IChatRepository

  constructor(context: Context) {
    this.repo = new ChatRepositoryImpl(context)
  }

  static createMessage(role: string, content: string): ChatMessage {
    msgCounter++
    const m = new ChatMessage()
    m.id = `msg_${Date.now()}_${msgCounter}`
    m.role = role
    m.content = content
    return m
  }

  /** 处理非流式 JSON 响应（保留，兼容旧逻辑） */
  private async applyJsonResponse(data: StreamJsonResponseDto, msg: ChatMessage): Promise<void> {
    const type = data.type || ''
    if (type === 'image') {
      msg.imageBase64 = this.toDataUri(data.image_base64 || '')
      if (!msg.content) msg.content = '[图片已生成]'
      return
    }
    if (type === 'multi') {
      const parts: string[] = []
      let imageHandled = false
      for (const item of data.results || []) {
        if (item.type === 'text') parts.push(item.content || '')
        else if (item.type === 'image') {
          if (!imageHandled) {
            msg.imageBase64 = this.toDataUri(item.image_base64 || '')
            imageHandled = true
          }
          parts.push('[图片已生成]')
        }
      }
      msg.content = parts.join('\n\n')
      return
    }
    if (type === 'error') {
      msg.content = data.content || '[请求出错]'
      return
    }
    msg.content = data.content || ''
  }

  private toDataUri(raw: string): string {
    if (!raw) return ''
    if (raw.startsWith('data:')) return raw
    return 'data:image/png;base64,' + raw
  }

  /** 流式对话（保持不变） */
  sendStream(opt: SendStreamOptions): http.HttpRequest {
    const state = new StreamParseState()
    let jsonMode = false
    let jsonBuffer = ''
    let firstChunk = false
    const startMs = DateUtil.nowMs()

    return this.repo.stream(opt.text, opt.sessionId, {
      onChunk: (chunk: string) => {
        if (!firstChunk) {
          firstChunk = true
          const trimmed = chunk.trimStart()
          if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            jsonMode = true
            jsonBuffer = chunk
            return
          }
        }
        if (jsonMode) { jsonBuffer += chunk; return }

        StreamParser.parse(chunk, state, opt.assistantMsg)
        opt.onRefresh()
        opt.onScroll()
      },
      onFinish: () => {
        const finalize = () => {
          opt.assistantMsg.duration = DateUtil.elapsedSeconds(startMs)
          opt.assistantMsg.completed = true
          Logger.i(`[finalize] imgLen=${opt.assistantMsg.imageBase64.length}`)
          opt.onRefresh()
          opt.onFinish()
        }

        if (jsonMode && jsonBuffer.length > 0) {
          try {
            const data: StreamJsonResponseDto = JSON.parse(jsonBuffer) as StreamJsonResponseDto
            this.applyJsonResponse(data, opt.assistantMsg)
              .then(() => { finalize() })
              .catch((e: Error) => {
                Logger.e(`applyJsonResponse 失败: ${e.message}`)
                opt.assistantMsg.content = '[响应解析失败]'
                finalize()
              })
          } catch (e) {
            Logger.e(`JSON 解析失败: ${(e as Error).message}`)
            opt.assistantMsg.content = '[响应解析失败]'
            finalize()
          }
        } else {
          finalize()
        }
      },
      onError: (err: string) => {
        opt.assistantMsg.content += `\n[请求失败: ${err}]`
        opt.assistantMsg.completed = true
        opt.onRefresh()
        opt.onFinish()
      }
    })
  }

  // ============================================================
  // ⭐ 新增：文件上传（流式版）
  //   与 sendStream 语义一致：立即返回 HttpRequest，
  //   内容通过 onRefresh 回调逐步呈现
  // ============================================================
  sendFilesStream(opt: SendFilesStreamOptions): http.HttpRequest {
    const startMs = DateUtil.nowMs()
    opt.assistantMsg.thinkingDone = true

    return this.repo.uploadFilesStream(opt.sessionId, opt.text, opt.files, {
      onChunk: (content: string) => {
        // ⭐ 图片场景：后端会先发 {"type":"image","image_base64":"..."}，
        //   repo 层已经解析成 content，或调用 onImage 回调单独处理
        opt.assistantMsg.content += content
        opt.onRefresh()
      },
      onImage: (base64: string) => {
        // 图生图/文生图返回图片时走这里
        opt.assistantMsg.imageBase64 = this.toDataUri(base64)
        opt.onRefresh()
      },
      onFinish: () => {
        opt.assistantMsg.duration = DateUtil.elapsedSeconds(startMs)
        opt.assistantMsg.completed = true
        opt.onRefresh()
        opt.onFinish()
      },
      onError: (err: string) => {
        opt.assistantMsg.content += `\n[请求失败: ${err}]`
        opt.assistantMsg.completed = true
        opt.onRefresh()
        opt.onFinish()
      }
    })
  }

  // ⚠️ 旧的 sendFiles 保留，但标记为待废弃
  /** @deprecated 改用 sendFilesStream */
  async sendFiles(sessionId: string, text: string, files: FileItem[]): Promise<ChatMessage> {
    const startMs = DateUtil.nowMs()
    const msg = ChatUseCase.createMessage('assistant', '')
    msg.thinkingDone = true
    try {
      const resp = await this.repo.uploadFiles(sessionId, text, files)
      if (resp.type === 'image') {
        msg.imageBase64 = this.toDataUri(resp.image_base64 || '')
        msg.content = resp.content ?? '[图片已生成]'
      } else if (resp.type === 'text') {
        msg.content = resp.content ?? ''
      } else if (resp.type === 'multi') {
        const parts: string[] = []
        let imageHandled = false
        for (const item of resp.results ?? []) {
          if (item.type === 'text') parts.push(item.content ?? '')
          else if (item.type === 'image') {
            if (!imageHandled) {
              msg.imageBase64 = this.toDataUri(item.image_base64 || '')
              imageHandled = true
            }
            parts.push('[图片已生成]')
          }
        }
        msg.content = parts.join('\n\n')
      } else if (resp.type === 'error') {
        msg.content = resp.content ?? '[请求出错]'
      } else {
        msg.content = resp.content ?? '[未知响应类型]'
      }
      msg.duration = DateUtil.elapsedSeconds(startMs)
      msg.completed = true
    } catch (e) {
      msg.content = `[文件处理失败: ${(e as Error).message}]`
      msg.completed = true
    }
    return msg
  }

  /** OCR（保持） */
  async ocr(files: FileItem[]): Promise<ChatMessage> {
    const msg = ChatUseCase.createMessage('assistant', '')
    msg.thinkingDone = true
    try {
      const resp = await this.repo.ocr(files)
      let content = ''
      const results = resp.results || []
      for (let i = 0; i < results.length; i++) {
        content += `**${results[i].filename}**\n${results[i].text}`
        if (i < results.length - 1) content += '\n\n---\n\n'
      }
      msg.content = content
      msg.completed = true
    } catch (e) {
      msg.content = `[OCR 失败: ${(e as Error).message}]`
      msg.completed = true
    }
    return msg
  }
}