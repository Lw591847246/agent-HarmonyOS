import { AuthViewModel } from '../../features/auth/AuthViewModel'
import { RegisterParams } from '../../domain/repositories/IUserRepository'

@Component
export struct LoginPage {
  onLoginSuccess: () => void = () => {}
  private username: string = ''
  private password: string = ''
  private realName: string = ''
  private phone: string = ''
  private email: string = ''
  private confirmPassword: string = ''

  @State isRegister: boolean = false
  @State loading: boolean = false
  @State message: string = ''

  private vm = new AuthViewModel()

  build() {
    Column() {
      Column() {
        Text('AI 智能助手').fontSize(28).fontWeight(FontWeight.Bold).margin({ bottom: 40 })
        Text(this.isRegister ? '注册新账号' : '登录').fontSize(20).margin({ bottom: 24 })

        TextInput({ placeholder: '用户名' })
          .width('100%').height(48).margin({ bottom: 12 })
          .onChange((v: string) => { this.username = v })

        if (this.isRegister) {
          TextInput({ placeholder: '真实姓名' })
            .width('100%').height(48).margin({ bottom: 12 })
            .onChange((v: string) => { this.realName = v })
          TextInput({ placeholder: '手机号' })
            .width('100%').height(48).type(InputType.PhoneNumber).margin({ bottom: 12 })
            .onChange((v: string) => { this.phone = v })
          TextInput({ placeholder: '邮箱（选填）' })
            .width('100%').height(48).type(InputType.Email).margin({ bottom: 12 })
            .onChange((v: string) => { this.email = v })
        }

        TextInput({ placeholder: '密码' })
          .width('100%').height(48).type(InputType.Password)
          .margin({ bottom: this.isRegister ? 12 : 20 })
          .onChange((v: string) => { this.password = v })

        if (this.isRegister) {
          TextInput({ placeholder: '确认密码' })
            .width('100%').height(48).type(InputType.Password).margin({ bottom: 20 })
            .onChange((v: string) => { this.confirmPassword = v })
        }

        Button(this.loading ? '请稍候...' : (this.isRegister ? '注册' : '登录'))
          .width('100%').height(48).enabled(!this.loading)
          .onClick(() => this.submit())

        if (this.message.length > 0) {
          Text(this.message).fontSize(13).fontColor('#e74c3c').margin({ top: 12 })
        }

        Row() {
          Text(this.isRegister ? '已有账号？' : '还没有账号？').fontSize(13).fontColor('#666')
          Text(this.isRegister ? '去登录' : '去注册').fontSize(13).fontColor('#3478f6')
            .margin({ left: 4 })
            .onClick(() => { this.isRegister = !this.isRegister; this.message = '' })
        }.margin({ top: 20 })
      }
      .width('85%').padding(24).backgroundColor(Color.White).borderRadius(16)
      .shadow({ radius: 20, color: '#00000015', offsetY: 4 })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
    .backgroundColor('#f5f6fa')
  }

  async submit(): Promise<void> {
    if (!this.username.trim() || !this.password) {
      this.message = '请填写用户名和密码'; return
    }
    if (this.isRegister) {
      if (!this.realName.trim()) { this.message = '请填写真实姓名'; return }
      if (!this.phone.trim()) { this.message = '请填写手机号'; return }
      if (this.password !== this.confirmPassword) { this.message = '两次密码不一致'; return }
    }
    this.loading = true
    this.message = ''
    try {
      if (this.isRegister) {
        const params: RegisterParams = {
          username: this.username.trim(),
          realName: this.realName.trim(),
          phone: this.phone.trim(),
          email: this.email.trim(),
          password: this.password,
          confirmPassword: this.confirmPassword
        }
        const r = await this.vm.register(params)
        if (r.ok) {
          this.message = '注册成功，请登录'
          this.isRegister = false
        } else {
          this.message = r.msg || '注册失败'
        }
      } else {
        const r = await this.vm.login(this.username.trim(), this.password)
        if (r.ok) this.onLoginSuccess()
        else this.message = r.msg || '登录失败'
      }
    } finally {
      this.loading = false
    }
  }
}