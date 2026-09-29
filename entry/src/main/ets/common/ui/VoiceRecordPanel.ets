import { promptAction } from '@kit.ArkUI'

/** 录音面板状态 */
export enum RecordPanelState {
  IDLE = 0,
  RECORDING = 1,
  WILL_CANCEL = 2
}

@Component
export struct VoiceRecordPanel {
  @Link state: RecordPanelState
  @Link durationSec: number
  @Link partialText: string

  onPressStart: () => void = () => {}
  onPressEnd: (isCancel: boolean) => void = () => {}
  onRequestPermission: () => Promise<boolean> = async () => false

  private startY: number = 0

  private stateText(): string {
    if (this.state === RecordPanelState.WILL_CANCEL) return '松开 取消'
    if (this.state === RecordPanelState.RECORDING) {
      if (this.durationSec > 0) {
        return `松开发送 · ${this.durationSec}'' · 上滑取消`
      }
      return '松开发送 · 上滑取消'
    }
    return '按住 说话'
  }

  private bgColor(): string {
    if (this.state === RecordPanelState.WILL_CANCEL) return '#ffdede'
    if (this.state === RecordPanelState.RECORDING) return '#dbe9ff'
    return '#f0f0f0'
  }

  private txtColor(): string {
    if (this.state === RecordPanelState.WILL_CANCEL) return '#e74c3c'
    if (this.state === RecordPanelState.RECORDING) return '#4a90e2'
    return '#333333'
  }

  build() {
    Row() {
      Text(this.stateText())
        .fontSize(15)
        .fontColor(this.txtColor())
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .height(46)
    .borderRadius(8)
    .backgroundColor(this.bgColor())
    .onTouch((e: TouchEvent) => this.handleTouch(e))
  }

  private handleTouch(e: TouchEvent): void {
    const t = e.touches[0]
    if (e.type === TouchType.Down) {
      this.startY = t.windowY
      this.triggerStart()
    } else if (e.type === TouchType.Move) {
      const dy = t.windowY - this.startY
      if (dy < -80) {
        if (this.state === RecordPanelState.RECORDING) {
          this.state = RecordPanelState.WILL_CANCEL
        }
      } else {
        if (this.state === RecordPanelState.WILL_CANCEL) {
          this.state = RecordPanelState.RECORDING
        }
      }
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      const isCancel = this.state === RecordPanelState.WILL_CANCEL
      this.triggerEnd(isCancel)
    }
  }

  private async triggerStart(): Promise<void> {
    const ok = await this.onRequestPermission()
    if (!ok) {
      promptAction.openToast({ message: '未获得麦克风权限' })
      return
    }
    this.state = RecordPanelState.RECORDING
    this.onPressStart()
  }

  private triggerEnd(isCancel: boolean): void {
    const wasRecording = this.state !== RecordPanelState.IDLE
    this.state = RecordPanelState.IDLE
    if (wasRecording) {
      this.onPressEnd(isCancel)
    }
  }
}