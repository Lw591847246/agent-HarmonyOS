import { ChatCard, ChatCardButton, FaceSwapTaskItem } from '../../../domain/models/ChatCard'
import { CardStyles } from './CardStyles'
import { MediaCache } from '../../../common/utils/MediaCache'
import { Logger } from '../../../common/logger/Logger'
import { fileUri } from '@kit.CoreFileKit'


// ⭐ 每个 task 独立管理"缓存→播放"的状态
@Component
struct TaskVideoCell {
  @Prop videoUrl: string         // 相对路径（后端给的 /agent/v1/chat/job/xxx/video）
  @Prop taskId: string

  @State private localPath: string = ''
  @State private loading: boolean = false
  @State private loadFailed: boolean = false

  private controller: VideoController = new VideoController()

  aboutToAppear(): void {
    this.resolveLocal()
  }

  private async resolveLocal(): Promise<void> {
    if (!this.videoUrl || this.videoUrl.length === 0) {
      this.loadFailed = true
      return
    }
    this.loading = true
    this.loadFailed = false
    try {
      // ⭐ 优先从 MediaCache 拿本地路径，未命中会自动下载
      const p = await MediaCache.ensureCached(this.videoUrl)
      if (p && p.length > 0) {
        this.localPath = p
        Logger.i(`[TaskVideoCell] ${this.taskId} 本地路径=${p}`)
      } else {
        this.loadFailed = true
        Logger.e(`[TaskVideoCell] ${this.taskId} 缓存返回空`)
      }
    } catch (e) {
      this.loadFailed = true
      Logger.e(`[TaskVideoCell] ${this.taskId} 缓存失败: ${(e as Error).message}`)
    } finally {
      this.loading = false
    }
  }

  build() {
    Stack() {
      if (this.localPath.length > 0) {
        Video({
          src: this.localPath.startsWith('file://')
            ? this.localPath
            : fileUri.getUriFromPath(this.localPath),   // ⭐ 转成 file://xxx
          controller: this.controller
        })
          .width('100%')
          .height(220)
          .controls(true)
          .autoPlay(false)
          .objectFit(ImageFit.Contain)
          .backgroundColor('#000000')
          .borderRadius(CardStyles.RADIUS_ITEM)
          .onStart(() => { Logger.i(`[TaskVideoCell] ${this.taskId} start`) })
          .onFinish(() => { Logger.i(`[TaskVideoCell] ${this.taskId} finish`) })
          .onError(() => {
            Logger.e(`[TaskVideoCell] ${this.taskId} 本地播放失败，重试下载`)
            this.localPath = ''
            this.loadFailed = false
            this.resolveLocal()
          })
      } else if (this.loadFailed) {
        Column({ space: 8 }) {
          Text('视频加载失败').fontSize(12).fontColor('#ccc')
          Button('重试')
            .fontSize(12)
            .fontColor(CardStyles.PRIMARY)
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: CardStyles.PRIMARY })
            .borderRadius(CardStyles.RADIUS_BTN)
            .height(28)
            .onClick(() => {
              this.loadFailed = false
              this.resolveLocal()
            })
        }
        .width('100%').height(220)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#000000')
        .borderRadius(CardStyles.RADIUS_ITEM)
      } else {
        // ⭐ 加载中：转圈 + 提示
        Column({ space: 10 }) {
          LoadingProgress().width(36).height(36).color('#ffffff')
          Text('正在加载视频…')
            .fontSize(12).fontColor('#ffffff')
        }
        .width('100%').height(220)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#000000')
        .borderRadius(CardStyles.RADIUS_ITEM)
      }
    }
    .width('100%')
    .height(220)
  }
}


@Component
export struct FaceSwapTaskCard {
  @Prop card: ChatCard

  onAction: (
    cardId: string,
    cardType: string,
    optionKey: string,
    text: string,
    fileId?: string
  ) => void = (
    cardId: string, cardType: string, optionKey: string,
    text: string, fileId?: string
  ) => {}

  onPlay: (url: string) => void = (url: string) => {}
  onSave: (url: string) => void = (url: string) => {}
  onShare: (url: string) => void = (url: string) => {}

  build() {
    Column({ space: CardStyles.GAP }) {
      Text(this.card.title)
        .fontSize(CardStyles.FONT_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(CardStyles.TEXT_PRIMARY)
        .width('100%')

      if (this.card.description) {
        Text(this.card.description)
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.TEXT_HINT)
          .width('100%')
      }

      if (this.card.tasks && this.card.tasks.length > 0) {
        ForEach(this.card.tasks, (t: FaceSwapTaskItem) => {
          this.renderTaskRow(t)
        }, (t: FaceSwapTaskItem) => `${t.task_id}_${t.status}_${t.progress}_${t.video_url ? 'V' : 'N'}_${t.duration_ms ?? 0}`)
      }

      if (this.card.buttons) {
        ForEach(this.card.buttons, (btn: ChatCardButton) => {
          Button(btn.label)
            .fontSize(CardStyles.FONT_BODY)
            .fontColor(CardStyles.TEXT_SECONDARY)
            .backgroundColor(CardStyles.BG_ITEM)
            .borderRadius(CardStyles.RADIUS_BTN)
            .width('100%')
            .height(36)
            .onClick(() => {
              this.onAction(this.card.card_id, this.card.card_type, btn.key, '')
            })
        }, (btn: ChatCardButton) => btn.key)
      }
    }
    .padding(CardStyles.PADDING_CARD)
    .backgroundColor(CardStyles.BG_CARD)
    .borderRadius(CardStyles.RADIUS_CARD)
    .border({ width: 1, color: CardStyles.BORDER })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  renderTaskRow(t: FaceSwapTaskItem) {
    Column({ space: 6 }) {
      // 标题行：名称 + 状态
      Row({ space: CardStyles.GAP_SMALL }) {
        Text(t.video_name)
          .fontSize(CardStyles.FONT_BODY)
          .fontColor(CardStyles.TEXT_PRIMARY)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.statusLabel(t))
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(this.statusColor(t))
      }
      .width('100%')

      if (t.status === 'done' && t.video_url && t.video_url.length > 0) {
        Column({ space: 8 }) {
          // ⭐ 内嵌视频播放器（本地缓存优先 + 加载进度）
          TaskVideoCell({
            videoUrl: t.video_url,
            taskId: t.task_id
          })

          // 文件信息行
          Row({ space: 6 }) {
            Text(this.formatSize(t.file_size))
              .fontSize(11)
              .fontColor(CardStyles.TEXT_HINT)

            // ⭐ 任务耗时
            if (t.duration_ms && t.duration_ms > 0) {
              Text('·').fontSize(11).fontColor(CardStyles.TEXT_HINT)
              Text(`耗时 ${(t.duration_ms / 1000).toFixed(1)}s`)
                .fontSize(11)
                .fontColor(CardStyles.TEXT_HINT)
            }

            Text('·').fontSize(11).fontColor(CardStyles.TEXT_HINT)
            Text(t.summary && t.summary.length > 0 ? t.summary : 'AI 生成视频')
              .fontSize(11)
              .fontColor(CardStyles.TEXT_HINT)
              .maxLines(1)
              .layoutWeight(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')

          // 保存 / 分享
          Row({ space: 8 }) {
            Button('保存')
              .fontSize(CardStyles.FONT_SMALL)
              .fontColor(CardStyles.PRIMARY)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: CardStyles.PRIMARY })
              .borderRadius(CardStyles.RADIUS_BTN)
              .layoutWeight(1)
              .height(32)
              .onClick(() => this.onSave(t.video_url!))

            Button('分享')
              .fontSize(CardStyles.FONT_SMALL)
              .fontColor(CardStyles.PRIMARY)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: CardStyles.PRIMARY })
              .borderRadius(CardStyles.RADIUS_BTN)
              .layoutWeight(1)
              .height(32)
              .onClick(() => this.onShare(t.video_url!))
          }
          .width('100%')
        }
        .padding(CardStyles.PADDING_ITEM)
        .width('100%')
        .backgroundColor('#F0F7FF')
        .borderRadius(CardStyles.RADIUS_ITEM)
      } else if (t.status === 'failed' || t.status === 'canceled') {
        Text(t.error && t.error.length > 0 ? t.error : '任务失败')
          .fontSize(CardStyles.FONT_SMALL)
          .fontColor(CardStyles.DANGER)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Row({ space: CardStyles.GAP }) {
          Progress({ value: t.progress, total: 100, type: ProgressType.Linear })
            .color(CardStyles.PRIMARY)
            .layoutWeight(1)
          Text(`${t.progress}%`)
            .fontSize(CardStyles.FONT_SMALL)
            .fontColor(CardStyles.TEXT_SECONDARY)
            .width(40)
            .textAlign(TextAlign.End)
        }
        .width('100%')
      }
    }
    .padding(CardStyles.PADDING_ITEM)
    .width('100%')
    .backgroundColor(CardStyles.BG_ITEM)
    .borderRadius(CardStyles.RADIUS_ITEM)
  }

  private statusLabel(t: FaceSwapTaskItem): string {
    if (t.status === 'done') return '已完成'
    if (t.status === 'failed') return '失败'
    if (t.status === 'canceled') return '已取消'
    if (t.status === 'running') return '处理中'
    return '排队中'
  }

  private statusColor(t: FaceSwapTaskItem): string {
    if (t.status === 'done') return CardStyles.PRIMARY
    if (t.status === 'failed' || t.status === 'canceled') return CardStyles.DANGER
    return CardStyles.TEXT_HINT
  }

  private formatSize(size?: number): string {
    if (!size || size <= 0) return '未知大小'
    if (size < 1024) return `${size} B`
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(0)} KB`
    return `${(size / 1024 / 1024).toFixed(1)} MB`
  }
}