import { textToSpeech } from '@kit.CoreSpeechKit'
import { media } from '@kit.MediaKit'
import { http } from '@kit.NetworkKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { TokenStore } from '../storage/TokenStore'
import { EnvConfig } from '../config/EnvConfig'
import { Logger } from '../logger/Logger'


interface TtsResponse {
  audio_url: string
}

/** 含中文（含中文标点）就认为"非英文" */
const CN_RE = /[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]/

/**
 * TTS 服务（智能路由 + Promise 语义 + reqId 防竞态）
 *
 * 路由规则：
 *   - 含中文 → 系统 CoreSpeechKit（中文发音好，本地，零延迟）
 *   - 纯英文 → 云端 Edge TTS（英语接近真人，带本地缓存）
 *
 * 对外接口：
 *   - speak(text, voice): Promise<void>  播完/被停止/失败时才 resolve
 *   - stop(): Promise<void>              主动停止，立即 resolve pending speak
 *   - isBusy(): boolean
 */
export class TtsService {

  // 云端 AVPlayer
  private avPlayer: media.AVPlayer | null = null

  // 系统 TTS
  private sysEngine: textToSpeech.TextToSpeechEngine | null = null
  private sysEngineReady: boolean = false
  private _sysSpeakTimer: number = 0

  // 通用状态
  private busy: boolean = false
  private _currentReqId: string = ''
  private _speakResolve: (() => void) | null = null

  isBusy(): boolean { return this.busy }

  /**
   * 朗读文本。Promise 在"播完 / 被主动停止 / 失败"时才 resolve。
   */
  async speak(text: string, voice: string = 'en-US-AriaNeural'): Promise<void> {
    if (!text) return

    // 先停掉上一次
    await this.stop()

    this.busy = true

    // ⭐ 每次 speak 生成唯一 reqId，用于拒绝过期事件
    const rid = `req_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`
    this._currentReqId = rid

    return new Promise<void>((resolve) => {
      // ⭐ 包一层：把 (value) => void 转成 () => void，与字段类型匹配
      this._speakResolve = () => { resolve() }

      if (CN_RE.test(text)) {
        Logger.i(`[TtsService] 含中文 → 系统 TTS | len=${text.length}, rid=${rid}`)
        this._speakBySystem(text, rid)
      } else {
        Logger.i(`[TtsService] 纯英文 → 云端 TTS | len=${text.length}, rid=${rid}`)
        this._speakByCloud(text, voice, rid)
      }
    })
  }

  /**
   * 主动停止（用户点"停止"或切换播放时调用）。
   * 会清掉两条链路的状态，并立即 resolve pending 的 speak。
   */
  async stop(): Promise<void> {
    // 1) 停云端
    if (this.avPlayer) {
      try {
        await this.avPlayer.stop()
        await this.avPlayer.release()
      } catch (_) { /* ignore */ }
      this.avPlayer = null
    }
    // 2) 停系统 TTS
    if (this.sysEngineReady && this.sysEngine) {
      try { await this.sysEngine.stop() } catch (_) { /* ignore */ }
    }
    // 3) 清定时器
    if (this._sysSpeakTimer) {
      clearTimeout(this._sysSpeakTimer)
      this._sysSpeakTimer = 0
    }
    // 4) 无条件结束 pending speak
    this._forceFinishSpeak()
  }

  // ============================================================
  // 系统 TTS（中文）
  // ============================================================
  private async _speakBySystem(text: string, rid: string): Promise<void> {
    if (!this.sysEngineReady) {
      const ok = await this._initSystemEngine()
      if (!ok) {
        this._finishSpeak(rid)
        return
      }
    }

    try {
      // 估算时长（onComplete 只是合成完成，不能作为"播完"信号）
      const estMs = this._estimateSpeakMs(text)
      Logger.i(`[TtsService] 系统 TTS 预估时长 ${estMs}ms, len=${text.length}`)

      if (this._sysSpeakTimer) {
        clearTimeout(this._sysSpeakTimer)
        this._sysSpeakTimer = 0
      }
      this._sysSpeakTimer = setTimeout(() => {
        this._sysSpeakTimer = 0
        if (this._currentReqId === rid) {
          Logger.i(`[TtsService] 系统 TTS 估算时长到，结束 rid=${rid}`)
          this._finishSpeak(rid)
        }
      }, estMs)

      // 系统 TTS 的 requestId 用 rid，保证回调里能匹配
      await this.sysEngine!.speak(text, {
        requestId: rid,
        extraParams: {
          'queueMode': 0,
          'speed': 1.0,
          'volume': 1.0,
          'pitch': 1.0,
          'playType': 1
        } as Record<string, Object>
      })
    } catch (e) {
      Logger.e(`[TtsService] 系统 TTS speak 失败: ${(e as Error).message}`)
      if (this._sysSpeakTimer) {
        clearTimeout(this._sysSpeakTimer)
        this._sysSpeakTimer = 0
      }
      this._finishSpeak(rid)
    }
  }

  private async _initSystemEngine(): Promise<boolean> {
    try {
      this.sysEngine = await textToSpeech.createEngine({
        language: 'zh-CN',
        person: 0,
        online: 1
      })

      this.sysEngine.setListener({
        onStart: (requestId: string, response: textToSpeech.StartResponse) => {
          Logger.i(`[TtsService] 系统 TTS onStart rid=${requestId}`)
        },
        onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
          // ⭐ 合成完成 ≠ 播完，不在此结束（靠 _sysSpeakTimer）
          Logger.i(`[TtsService] 系统 TTS onComplete（合成完成，不结束） rid=${requestId}`)
        },
        onStop: (requestId: string, response: textToSpeech.StopResponse) => {
          Logger.i(`[TtsService] 系统 TTS onStop rid=${requestId}`)
          if (this._sysSpeakTimer) {
            clearTimeout(this._sysSpeakTimer)
            this._sysSpeakTimer = 0
          }
          this._finishSpeak(requestId)
        },
        onError: (requestId: string, errorCode: number, errorMessage: string) => {
          Logger.e(`[TtsService] 系统 TTS onError ${errorCode} ${errorMessage} rid=${requestId}`)
          if (this._sysSpeakTimer) {
            clearTimeout(this._sysSpeakTimer)
            this._sysSpeakTimer = 0
          }
          this._finishSpeak(requestId)
        }
      })

      this.sysEngineReady = true
      return true
    } catch (e) {
      Logger.e(`[TtsService] 初始化系统 TTS 失败: ${(e as Error).message}`)
      this.sysEngineReady = false
      return false
    }
  }

  /** 估算朗读时长（中英混合） */
  private _estimateSpeakMs(text: string): number {
    let cnCount = 0
    let enCount = 0
    for (let i = 0; i < text.length; i++) {
      const ch = text.charAt(i)
      if (/[\u4e00-\u9fff]/.test(ch)) cnCount++
      else if (/[a-zA-Z0-9]/.test(ch)) enCount++
    }
    const est = cnCount * 220 + enCount * 80 + 800
    return Math.max(2000, est)
  }

  // ============================================================
  // 云端 TTS（英文）—— 带本地 mp3 缓存
  // ============================================================
  private _hashText(text: string, voice: string): string {
    const input = `${voice}|${text}`
    let hash = 5381
    for (let i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.charCodeAt(i)
      hash = hash & 0x7fffffff
    }
    return hash.toString(16)
  }

  private async _speakByCloud(text: string, voice: string, rid: string): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      const cacheDir = `${ctx.cacheDir}/tts_cache`
      try { fs.mkdirSync(cacheDir) } catch (_) { /* 已存在 */ }

      const hash = this._hashText(text, voice)
      const localPath = `${cacheDir}/${hash}.mp3`

      // 1) 先看本地缓存
      let needDownload = true
      try {
        const stat = fs.statSync(localPath)
        if (stat.size > 0) {
          needDownload = false
          Logger.i(`[TtsService] 本地缓存命中: ${hash}`)
        }
      } catch (_) { /* 不存在 */ }

      // 2) 未命中 → 请求后端 + 下载
      if (needDownload) {
        Logger.i(`[TtsService] 本地未命中，请求后端: ${hash}`)
        const ttsUrl = await this._requestTts(text, voice)
        await this._downloadFile(ttsUrl, localPath)
      }

      // 3) 播放
      await this._playLocal(localPath, rid)
    } catch (e) {
      Logger.e(`[TtsService] 云端 TTS 失败: ${(e as Error).message}`)
      this._finishSpeak(rid)
    }
  }

  private _requestTts(text: string, voice: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const req = http.createHttp()
      req.request(
        `${EnvConfig.AGENT_BASE_URL}/agent/v1/tts`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': TokenStore.getToken()
          },
          extraData: JSON.stringify({ text, voice }),
          connectTimeout: 10000,
          readTimeout: 30000
        },
        (err, data) => {
          req.destroy()
          if (err) { reject(new Error(`TTS 请求失败: ${err.message}`)); return }
          if (data.responseCode !== 200) {
            reject(new Error(`TTS HTTP ${data.responseCode}`)); return
          }
          try {
            const obj = JSON.parse(data.result as string) as TtsResponse
            if (!obj.audio_url) { reject(new Error('缺少 audio_url')); return }
            resolve(obj.audio_url)
          } catch (e) {
            reject(new Error('TTS 响应解析失败'))
          }
        }
      )
    })
  }

  private _downloadFile(remotePath: string, localPath: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const req = http.createHttp()
      req.request(
        `${EnvConfig.AGENT_BASE_URL}${remotePath}`,
        {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: 10000,
          readTimeout: 30000
        },
        (err, data) => {
          req.destroy()
          if (err) { reject(new Error(`下载失败: ${err.message}`)); return }
          if (data.responseCode !== 200) {
            reject(new Error(`下载 HTTP ${data.responseCode}`)); return
          }
          try {
            const file = fs.openSync(
              localPath,
              fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC
            )
            fs.writeSync(file.fd, data.result as ArrayBuffer)
            fs.closeSync(file)
            resolve()
          } catch (e) {
            reject(new Error(`写入文件失败: ${(e as Error).message}`))
          }
        }
      )
    })
  }

  private async _playLocal(path: string, rid: string): Promise<void> {
    // 释放旧 player
    if (this.avPlayer) {
      try { await this.avPlayer.release() } catch (_) { /* ignore */ }
      this.avPlayer = null
    }

    // 打开文件拿 fd（AVPlayer 不接受 file://，必须用 fdSrc）
    let file: fs.File | null = null
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY)
    } catch (e) {
      Logger.e(`[TtsService] 打开 mp3 失败: ${(e as Error).message}`)
      this._finishSpeak(rid)
      return
    }

    const player = await media.createAVPlayer()
    this.avPlayer = player
    const openedFile = file

    player.on('stateChange', async (state: string) => {
      try {
        if (state === 'initialized') {
          await player.prepare()
        } else if (state === 'prepared') {
          await player.play()
        } else if (state === 'completed') {
          await player.reset()
          await player.release()
          if (this.avPlayer === player) this.avPlayer = null
          try { fs.closeSync(openedFile) } catch (_) { /* ignore */ }
          this._finishSpeak(rid)
        } else if (state === 'error') {
          Logger.e('[TtsService] AVPlayer 状态 error')
          try { fs.closeSync(openedFile) } catch (_) { /* ignore */ }
          this._finishSpeak(rid)
        }
      } catch (e) {
        Logger.e(`[TtsService] stateChange ${state} 处理失败: ${(e as Error).message}`)
      }
    })

    player.on('error', (err: Error) => {
      Logger.e(`[TtsService] AVPlayer error: ${err.message}`)
      try { fs.closeSync(openedFile) } catch (_) { /* ignore */ }
      this._finishSpeak(rid)
    })

    // ⭐ fdSrc，不是 url
    player.fdSrc = { fd: openedFile.fd }
  }

  // ============================================================
  // 结束逻辑
  // ============================================================

  /**
   * 由 TTS 事件触发。带 reqId 校验，过期事件一律忽略。
   */
  private _finishSpeak(reqId: string): void {
    if (reqId !== this._currentReqId) {
      Logger.i(`[TtsService] 忽略过期事件 reqId=${reqId}, current=${this._currentReqId}`)
      return
    }
    this._doFinishSpeak()
  }

  /**
   * 用户主动停止（stop() 里调用）。无条件结束 pending speak。
   */
  private _forceFinishSpeak(): void {
    this._doFinishSpeak()
  }

  /**
   * 内部：真正的收尾
   */
  private _doFinishSpeak(): void {
    this._currentReqId = ''
    this.busy = false
    if (this._speakResolve) {
      const r = this._speakResolve
      this._speakResolve = null
      r()
    }
  }
}