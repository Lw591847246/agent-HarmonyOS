import { audio } from '@kit.AudioKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { Logger } from '../logger/Logger'

export interface VoiceRecordResult {
  path: string
  duration: number      // 秒
}

/**
 * 语音录制服务
 * - 采集 PCM 16kHz / 16bit / 单声道
 * - 同时写文件（.pcm）+ 通过 onPcm 回调喂给 ASR
 */
export class VoiceRecorderService {
  private capturer: audio.AudioCapturer | null = null
  private file: fs.File | null = null
  private filePath: string = ''
  private startMs: number = 0
  private recording: boolean = false
  private onPcm?: (data: Uint8Array) => void

  isRecording(): boolean { return this.recording }

  async start(ctx: common.UIAbilityContext, onPcm?: (data: Uint8Array) => void): Promise<boolean> {
    if (this.recording) return false
    this.onPcm = onPcm
    this.startMs = Date.now()

    try {
      const fileName = `voice_${this.startMs}.pcm`
      this.filePath = `${ctx.cacheDir}/${fileName}`
      this.file = fs.openSync(this.filePath,
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)

      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      }
      const capturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      }

      this.capturer = await audio.createAudioCapturer({
        streamInfo: streamInfo,
        capturerInfo: capturerInfo
      })

      this.capturer.on('readData', (buffer: ArrayBuffer) => {
        if (!this.recording) return
        try {
          if (this.file) fs.writeSync(this.file.fd, buffer)
          if (this.onPcm) this.onPcm(new Uint8Array(buffer))
        } catch (e) {
          Logger.e(`[Recorder] readData: ${(e as Error).message}`)
        }
      })

      await this.capturer.start()
      this.recording = true
      Logger.i(`[Recorder] started ${this.filePath}`)
      return true
    } catch (e) {
      Logger.e(`[Recorder] start failed: ${(e as Error).message}`)
      await this.cleanup()
      return false
    }
  }

  /**
   * ⭐ stop：无论 recording 与否都执行清理
   * 返回 null 的两种情况：
   *   1) 从未成功开始录音
   *   2) 有效时长 < 1 秒
   */
  async stop(): Promise<VoiceRecordResult | null> {
    const wasRecording = this.recording
    const realDuration = wasRecording
      ? (Date.now() - this.startMs) / 1000
      : 0
    const path = this.filePath

    await this.cleanup()

    if (!wasRecording || realDuration < 1) {
      if (path) {
        try { fs.unlinkSync(path) } catch (_) { /* ignore */ }
      }
      Logger.i(`[Recorder] stop 丢弃：wasRecording=${wasRecording}, dur=${realDuration.toFixed(2)}s`)
      return null
    }
    return { path, duration: Math.round(realDuration) }
  }

  async cancel(): Promise<void> {
    const path = this.filePath
    await this.cleanup()
    if (path) {
      try { fs.unlinkSync(path) } catch (_) { /* ignore */ }
    }
    Logger.i('[Recorder] cancel 完成')
  }

  private async cleanup(): Promise<void> {
    this.recording = false
    if (this.capturer) {
      try {
        this.capturer.off('readData')
        await this.capturer.stop()
        await this.capturer.release()
      } catch (_) { /* ignore */ }
      this.capturer = null
    }
    if (this.file) {
      try { fs.closeSync(this.file) } catch (_) { /* ignore */ }
      this.file = null
    }
    this.onPcm = undefined
  }
}