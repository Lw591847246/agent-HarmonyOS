import { audio } from '@kit.AudioKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { Logger } from '../logger/Logger'

/**
 * 语音播放服务：播放 PCM 文件（与 Recorder 参数一致）
 * - 同一时刻只播一条；play() 会自动打断上一条
 */
export class VoicePlayerService {
  private renderer: audio.AudioRenderer | null = null
  private playing: boolean = false
  private onFinishCb?: () => void

  isPlaying(): boolean { return this.playing }

  async play(path: string, onFinish?: () => void): Promise<void> {
    await this.stop()
    this.onFinishCb = onFinish

    try {
      const streamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      }
      const rendererInfo: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      }
      this.renderer = await audio.createAudioRenderer({ streamInfo, rendererInfo })
      await this.renderer.start()
      this.playing = true
      this.feedLoop(path)
    } catch (e) {
      Logger.e(`[Player] play failed: ${(e as Error).message}`)
      this.finish()
    }
  }

  private async feedLoop(path: string): Promise<void> {
    const CHUNK = 3200   // 100ms
    let file: fs.File | null = null
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY)
      const buf = new ArrayBuffer(CHUNK)
      while (this.playing && this.renderer) {
        const readLen = fs.readSync(file.fd, buf)
        if (readLen <= 0) break
        await this.renderer.write(new Uint8Array(buf.slice(0, readLen)))
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 300))
    } catch (e) {
      Logger.e(`[Player] feedLoop: ${(e as Error).message}`)
    } finally {
      if (file) { try { fs.closeSync(file) } catch (_) { /* ignore */ } }
      this.finish()
    }
  }

  async stop(): Promise<void> {
    if (!this.playing) return
    this.playing = false
    await new Promise<void>((resolve) => setTimeout(resolve, 50))
    if (this.renderer) {
      try {
        await this.renderer.stop()
        await this.renderer.release()
      } catch (_) { /* ignore */ }
      this.renderer = null
    }
  }

  private finish(): void {
    this.playing = false
    if (this.renderer) {
      const r = this.renderer
      this.renderer = null
      r.stop().then(() => r.release()).catch(() => { /* ignore */ })
    }
    const cb = this.onFinishCb
    this.onFinishCb = undefined
    if (cb) cb()
  }
}