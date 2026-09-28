/**
 * 图片编辑器 ViewModel
 * 职责：状态管理 + 屏幕坐标 ←→ 原图坐标换算
 * 不做 IO、不碰文件系统
 */
@Observed
export class ImageEditorViewModel {
  /** 原图像素尺寸 */
  imgW: number = 0
  imgH: number = 0

  /** 容器（vp）尺寸 */
  containerW: number = 0
  containerH: number = 0

  /** fit 缩放比：原图 1px 对应屏幕多少 vp */
  fitScale: number = 1

  /** 图片在容器中的显示区域（vp） */
  drawX: number = 0
  drawY: number = 0
  drawW: number = 0
  drawH: number = 0

  /** 裁剪框（vp，相对容器左上角） */
  cropX: number = 0
  cropY: number = 0
  cropW: number = 0
  cropH: number = 0

  /** 是否已就绪（图片 + 容器尺寸都拿到了） */
  ready: boolean = false
  /** 是否正在保存 */
  busy: boolean = false

  /** 图片与容器尺寸都就绪后调用：算 fit 布局 + 初始化裁剪框 */
  layoutImage(imgW: number, imgH: number, containerW: number, containerH: number): void {
    this.imgW = imgW
    this.imgH = imgH
    this.containerW = containerW
    this.containerH = containerH

    const sx = containerW / imgW
    const sy = containerH / imgH
    this.fitScale = Math.min(sx, sy)

    this.drawW = imgW * this.fitScale
    this.drawH = imgH * this.fitScale
    this.drawX = (containerW - this.drawW) / 2
    this.drawY = (containerH - this.drawH) / 2

    this.resetCrop()
    this.ready = true
  }

  /** 重置裁剪框到图片中心，占 85% */
  resetCrop(): void {
    const initW = this.drawW * 0.85
    const initH = this.drawH * 0.85
    this.cropW = initW
    this.cropH = initH
    this.cropX = this.drawX + (this.drawW - initW) / 2
    this.cropY = this.drawY + (this.drawH - initH) / 2
  }

  /** 整体平移裁剪框，边界 clamp 到显示区域 */
  moveCrop(dx: number, dy: number): void {
    const minX = this.drawX
    const minY = this.drawY
    const maxX = this.drawX + this.drawW - this.cropW
    const maxY = this.drawY + this.drawH - this.cropH
    this.cropX = Math.max(minX, Math.min(this.cropX + dx, maxX))
    this.cropY = Math.max(minY, Math.min(this.cropY + dy, maxY))
  }

  /**
   * 拖拽角点。corner ∈ 'tl' | 'tr' | 'bl' | 'br'
   * MIN 是裁剪框最小边长（vp），防止缩到 0
   */
  resizeByCorner(corner: string, dx: number, dy: number): void {
    const MIN = 48
    let l = this.cropX
    let t = this.cropY
    let r = this.cropX + this.cropW
    let b = this.cropY + this.cropH

    const minL = this.drawX
    const minT = this.drawY
    const maxR = this.drawX + this.drawW
    const maxB = this.drawY + this.drawH

    if (corner === 'tl') {
      l = Math.max(minL, Math.min(l + dx, r - MIN))
      t = Math.max(minT, Math.min(t + dy, b - MIN))
    } else if (corner === 'tr') {
      r = Math.min(maxR, Math.max(r + dx, l + MIN))
      t = Math.max(minT, Math.min(t + dy, b - MIN))
    } else if (corner === 'bl') {
      l = Math.max(minL, Math.min(l + dx, r - MIN))
      b = Math.min(maxB, Math.max(b + dy, t + MIN))
    } else { // 'br'
      r = Math.min(maxR, Math.max(r + dx, l + MIN))
      b = Math.min(maxB, Math.max(b + dy, t + MIN))
    }

    this.cropX = l
    this.cropY = t
    this.cropW = r - l
    this.cropH = b - t
  }

  /** 把屏幕裁剪框换算成原图像素坐标 */
  toSourceRect(): CropRect {
    let x = (this.cropX - this.drawX) / this.fitScale
    let y = (this.cropY - this.drawY) / this.fitScale
    let w = this.cropW / this.fitScale
    let h = this.cropH / this.fitScale

    x = Math.max(0, Math.min(x, this.imgW - 1))
    y = Math.max(0, Math.min(y, this.imgH - 1))
    w = Math.max(1, Math.min(w, this.imgW - x))
    h = Math.max(1, Math.min(h, this.imgH - y))
    return { x, y, w, h }
  }
}

/** 原图像素坐标下的裁剪矩形 */
export interface CropRect {
  x: number
  y: number
  w: number
  h: number
}