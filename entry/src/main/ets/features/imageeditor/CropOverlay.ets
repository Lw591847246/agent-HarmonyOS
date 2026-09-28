import { ImageEditorViewModel } from './ImageEditorViewModel'

/**
 * 裁剪框 UI + 手势
 * - 四块遮罩拼出"框外变暗"效果
 * - 白框：整体拖动
 * - 四角：拉伸
 */
@Component
export struct CropOverlay {
  @ObjectLink vm: ImageEditorViewModel

  private lastX: number = 0
  private lastY: number = 0

  // ⭐ 遮罩色：60% 黑，任何底色上都能明显看出"要裁掉"的区域
  private static readonly MASK: string = '#00000099'

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ── 上遮罩 ─────────────────────────────
      Row()
        .width('100%')
        .height(Math.max(0, this.vm.cropY))
        .backgroundColor(CropOverlay.MASK)
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)

      // ── 下遮罩 ─────────────────────────────
      Row()
        .width('100%')
        .height(Math.max(0, this.vm.containerH - this.vm.cropY - this.vm.cropH))
        .backgroundColor(CropOverlay.MASK)
        .position({ x: 0, y: this.vm.cropY + this.vm.cropH })
        .hitTestBehavior(HitTestMode.None)

      // ── 左遮罩 ─────────────────────────────
      Row()
        .width(Math.max(0, this.vm.cropX))
        .height(this.vm.cropH)
        .backgroundColor(CropOverlay.MASK)
        .position({ x: 0, y: this.vm.cropY })
        .hitTestBehavior(HitTestMode.None)

      // ── 右遮罩 ─────────────────────────────
      Row()
        .width(Math.max(0, this.vm.containerW - this.vm.cropX - this.vm.cropW))
        .height(this.vm.cropH)
        .backgroundColor(CropOverlay.MASK)
        .position({ x: this.vm.cropX + this.vm.cropW, y: this.vm.cropY })
        .hitTestBehavior(HitTestMode.None)

      // ── 裁剪框（整体拖动）──────────────────
      Row()
        .width(this.vm.cropW)
        .height(this.vm.cropH)
        .border({ width: 1.5, color: Color.White })
        .position({ x: this.vm.cropX, y: this.vm.cropY })
        .onTouch((e: TouchEvent) => this.onBoxTouch(e))

      // ── 四角手柄 ───────────────────────────
      this.CornerHandle('tl')
      this.CornerHandle('tr')
      this.CornerHandle('bl')
      this.CornerHandle('br')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  CornerHandle(corner: string) {
    Column() {
      Column()
        .width(14)
        .height(14)
        .border({
          width: {
            left: (corner === 'tl' || corner === 'bl') ? 3 : 0,
            right: (corner === 'tr' || corner === 'br') ? 3 : 0,
            top: (corner === 'tl' || corner === 'tr') ? 3 : 0,
            bottom: (corner === 'bl' || corner === 'br') ? 3 : 0
          },
          color: Color.White
        })
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .position(this._cornerPos(corner))
    .onTouch((e: TouchEvent) => this.onCornerTouch(e, corner))
  }

  private _cornerPos(corner: string): Position {
    const off = 22
    if (corner === 'tl') return { x: this.vm.cropX - off, y: this.vm.cropY - off }
    if (corner === 'tr') return { x: this.vm.cropX + this.vm.cropW - off, y: this.vm.cropY - off }
    if (corner === 'bl') return { x: this.vm.cropX - off, y: this.vm.cropY + this.vm.cropH - off }
    return { x: this.vm.cropX + this.vm.cropW - off, y: this.vm.cropY + this.vm.cropH - off }
  }

  private onBoxTouch(e: TouchEvent): void {
    const t = e.touches[0]
    if (e.type === TouchType.Down) {
      this.lastX = t.windowX
      this.lastY = t.windowY
    } else if (e.type === TouchType.Move) {
      const dx = t.windowX - this.lastX
      const dy = t.windowY - this.lastY
      this.vm.moveCrop(dx, dy)
      this.lastX = t.windowX
      this.lastY = t.windowY
    }
  }

  private onCornerTouch(e: TouchEvent, corner: string): void {
    const t = e.touches[0]
    if (e.type === TouchType.Down) {
      e.stopPropagation()
      this.lastX = t.windowX
      this.lastY = t.windowY
    } else if (e.type === TouchType.Move) {
      e.stopPropagation()
      const dx = t.windowX - this.lastX
      const dy = t.windowY - this.lastY
      this.vm.resizeByCorner(corner, dx, dy)
      this.lastX = t.windowX
      this.lastY = t.windowY
    }
  }
}