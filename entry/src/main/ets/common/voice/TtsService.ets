import { textToSpeech } from '@kit.CoreSpeechKit'
import { Logger } from '../logger/Logger'

/**
 * 语音合成服务
 * - speak() 播报一段文本
 * - stop() 打断当前播报
 */
export class TtsService {
  private engine: textToSpeech.TextToSpeechEngine | null = null
  private busy: boolean = false
  private onStateChange?: (playing: boolean) => void

  isBusy(): boolean { return this.busy }

  setStateChangeCallback(cb: (playing: boolean) => void): void {
    this.onStateChange = cb
  }

  private _setBusy(v: boolean): void {
    this.busy = v
    if (this.onStateChange) this.onStateChange(v)
  }

  async init(): Promise<boolean> {
    if (this.engine) return true
    try {
      this.engine = await textToSpeech.createEngine({
        language: 'zh-CN',
        person: 0,
        online: 1
      })
      this.engine.setListener({
        onStart: (requestId: string, response: textToSpeech.StartResponse) => {
          this._setBusy(true)
          Logger.i(`[TTS] onStart rid=${requestId}`)
        },
        onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
          this._setBusy(false)
          Logger.i(`[TTS] onComplete rid=${requestId}`)
        },
        onStop: (requestId: string, response: textToSpeech.StopResponse) => {
          this._setBusy(false)
          Logger.i(`[TTS] onStop rid=${requestId}`)
        },
        onError: (requestId: string, errorCode: number, errorMessage: string) => {
          this._setBusy(false)
          Logger.e(`[TTS] onError rid=${requestId} code=${errorCode} msg=${errorMessage}`)
        }
      })
      return true
    } catch (e) {
      Logger.e(`[TTS] init failed: ${(e as Error).message}`)
      return false
    }
  }

  async speak(text: string): Promise<boolean> {
    if (!text) return false
    if (!this.engine && !(await this.init())) return false
    try {
      this._setBusy(true)
      await this.engine!.speak(text, {
        requestId: `tts_${Date.now()}`,
        extraParams: {
          'queueMode': 0,
          'speed': 1.0,
          'volume': 1.0,
          'pitch': 1.0,
          'playType': 1
        } as Record<string, Object>
      })
      return true
    } catch (e) {
      this._setBusy(false)
      Logger.e(`[TTS] speak failed: ${(e as Error).message}`)
      return false
    }
  }

  async stop(): Promise<void> {
    if (!this.engine) return
    try { await this.engine.stop() } catch (_) { /* ignore */ }
    this._setBusy(false)
  }
}