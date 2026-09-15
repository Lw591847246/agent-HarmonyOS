export enum MessageActionType {
  COPY = 'copy',
  REGENERATE = 'regenerate',
  SHARE = 'share'
}

export class MessageAction {
  type: MessageActionType = MessageActionType.COPY
  icon: Resource | null = null
  label: string = ''
}

export function buildUserActions(): MessageAction[] {
  const copy = new MessageAction()
  copy.type = MessageActionType.COPY
  copy.icon = $r('app.media.icon_copy')

  const regen = new MessageAction()
  regen.type = MessageActionType.REGENERATE
  regen.icon = $r('app.media.icon_refresh')

  return [copy, regen]
}

export function buildAssistantActions(): MessageAction[] {
  const copy = new MessageAction()
  copy.type = MessageActionType.COPY
  copy.icon = $r('app.media.icon_copy')
  return [copy]
}