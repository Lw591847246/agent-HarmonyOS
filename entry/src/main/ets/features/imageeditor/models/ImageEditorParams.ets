/**
 * 图片编辑器：入参 / 出参 / 事件名
 * 职责：跨层契约，隔离 Navigation 传参细节
 */

/** 打开图片编辑器的入参 */
export interface ImageEditorParams {
  /** 原图 uri（沙箱或媒体库） */
  uri: string
  /** 原图文件名，用于生成新文件名 */
  name: string
}

/** 编辑器输出结果 */
export interface ImageEditorResult {
  /** 裁剪后新图片的沙箱 uri */
  uri: string
  /** 新文件名 */
  name: string
  /** ⭐ 原图 uri，仅用于溯源展示，不上传 */
  originUri: string
}

/** EventHub 事件名：编辑器完成 */
export const IMAGE_EDITOR_DONE_EVENT: string = 'image_editor_done'