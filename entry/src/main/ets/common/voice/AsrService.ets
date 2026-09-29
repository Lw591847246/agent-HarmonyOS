import { speechRecognizer } from '@kit.CoreSpeechKit'
import { Logger } from '../logger/Logger'

/**
 * 语音识别服务
 * - 流式识别：录音过程中 writeAudio 喂 PCM，onPartial 回调给 UI 显示
 * - 松手时调用 finish()，返回最终文本
 */
export class AsrService {
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null
  private sessionId: string = ''
  private finalText: string = ''
  private partialText: string = ''
  private onPartial?: (text: string) => void

  async init(): Promise<boolean> {
    if (this.engine) return true
    try {
      this.engine = await speechRecognizer.createEngine({
        language: 'zh-CN',
        online: 1,
        extraParams: {
          'recognitionMode': 0,
          'vadBegin': 2000,
          'vadEnd': 3000,
          'maxAudioDuration': 60000
        } as Record<string, Object>
      })

      this.engine.setListener({
        onStart: (sid: string, eventMessage: string) => {
          Logger.i(`[ASR] onStart ${sid}`)
        },
        onEvent: (sid: string, eventCode: number, eventMessage: string) => {
          Logger.i(`[ASR] onEvent ${sid} ${eventCode}`)
        },
        onResult: (sid: string, result: speechRecognizer.SpeechRecognitionResult) => {
          this.partialText = result.result
          if (result.isFinal) {
            this.finalText = result.result
            Logger.i(`[ASR] final: ${this.finalText}`)
          } else if (this.onPartial) {
            this.onPartial(this.partialText)
          }
        },
        onComplete: (sid: string, eventMessage: string) => {
          Logger.i(`[ASR] onComplete ${sid}`)
        },
        onError: (sid: string, code: number, msg: string) => {
          Logger.e(`[ASR] onError ${sid} code=${code} msg=${msg}`)
        }
      })
      return true
    } catch (e) {
      Logger.e(`[ASR] init failed: ${(e as Error).message}`)
      return false
    }
  }

  async start(onPartial?: (text: string) => void): Promise<boolean> {
    if (!this.engine && !(await this.init())) return false
    this.onPartial = onPartial
    this.finalText = ''
    this.partialText = ''

    try {
      this.sessionId = `asr_${Date.now()}`
      const audioInfo: speechRecognizer.AudioInfo = {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      }
      await this.engine!.startListening({
        sessionId: this.sessionId,
        audioInfo: audioInfo,
        extraParams: {
          'recognitionMode': 0,
          'vadBegin': 2000,
          'vadEnd': 3000,
          'maxAudioDuration': 60000
        } as Record<string, Object>
      })
      return true
    } catch (e) {
      Logger.e(`[ASR] start failed: ${(e as Error).message}`)
      return false
    }
  }

  writeAudio(pcm: Uint8Array): void {
    if (!this.engine) return
    try {
      this.engine.writeAudio(this.sessionId, pcm)
    } catch (e) {
      Logger.e(`[ASR] writeAudio: ${(e as Error).message}`)
    }
  }

  async finish(): Promise<string> {
    if (!this.engine) return this.partialText
    try {
      await this.engine.finish(this.sessionId)
    } catch (e) {
      Logger.e(`[ASR] finish: ${(e as Error).message}`)
    }
    await new Promise<void>((resolve) => setTimeout(resolve, 300))
    return this.finalText || this.partialText
  }

  async cancel(): Promise<void> {
    if (!this.engine) return
    try { await this.engine.cancel(this.sessionId) } catch (_) { /* ignore */ }
    this.finalText = ''
    this.partialText = ''
  }
}