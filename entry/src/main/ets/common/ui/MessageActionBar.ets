import { MessageAction } from './MessageAction'

@Component
export struct MessageActionBar {
  @Prop actions: MessageAction[] = []
  onAction: (type: string) => void = () => {}

  build() {
    Row({ space: 16 }) {
      ForEach(this.actions, (action: MessageAction) => {
        Image(action.icon)
          .width(16).height(16).objectFit(ImageFit.Contain)
          .opacity(0.6)
          .onClick(() => this.onAction(action.type))
      }, (action: MessageAction) => action.type)
    }
    .margin({ top: 6 })
  }
}