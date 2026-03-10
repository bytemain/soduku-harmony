/**
 * CoachSheet.ets — AI 教练对话 Sheet
 *
 * 半屏 Sheet，显示对话消息列表、快捷按钮和输入框。
 * 支持流式输出（逐字显示 AI 回复）。
 *
 * 参考：Doc 06 §3 UI 设计
 */
import { Colors } from '../constants/GameConstants'
import { CellData } from '../models/CellData'
import { CoachService, ChatMessage } from '../services/CoachService'

@Component
export struct CoachSheet {
  /** 当前棋盘 cells（由 GamePage 传入） */
  cells: CellData[] = []
  onClose: () => void = () => {}

  @State private messages: ChatMessage[] = []
  @State private inputText: string = ''
  @State private isLoading: boolean = false
  @State private initStatus: string = ''  // '', 'loading', 'ready', 'failed'
  private coachService: CoachService = new CoachService()
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.initStatus = 'loading'
    this.coachService.init().then((ok) => {
      this.initStatus = ok ? 'ready' : 'failed'
    })
  }

  private sendMessage(text: string): void {
    if (!text.trim() || this.isLoading) return

    // Add user message
    const userMsg = new ChatMessage('user', text.trim())
    this.messages = [...this.messages, userMsg]
    this.inputText = ''
    this.isLoading = true

    // Add placeholder for coach response
    const coachMsg = new ChatMessage('coach', '', true)
    this.messages = [...this.messages, coachMsg]
    this.scrollToBottom()

    this.coachService.chat(
      this.cells,
      text.trim(),
      (fullText: string) => {
        // Update streaming message
        const updated = [...this.messages]
        updated[updated.length - 1] = new ChatMessage('coach', fullText, true)
        this.messages = updated
        this.scrollToBottom()
      },
      (fullText: string) => {
        // Finish
        const updated = [...this.messages]
        updated[updated.length - 1] = new ChatMessage('coach', fullText, false)
        this.messages = updated
        this.isLoading = false
        this.scrollToBottom()
      },
      (errorMsg: string) => {
        // Error
        const updated = [...this.messages]
        updated[updated.length - 1] = new ChatMessage('coach', `⚠️ ${errorMsg}`, false)
        this.messages = updated
        this.isLoading = false
      }
    )
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 50)
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Text('🤖 数独教练')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.titleText)

        Blank()

        if (this.initStatus === 'loading') {
          Text('初始化中...')
            .fontSize(12)
            .fontColor(Colors.subtitleText)
        }

        Text('✕')
          .fontSize(20)
          .fontColor(Colors.subtitleText)
          .margin({ left: 12 })
          .onClick(() => this.onClose())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      Divider().color(Colors.divider).height(0.5)

      // Messages area
      if (this.messages.length === 0) {
        // Empty state
        Column() {
          Text('🎓')
            .fontSize(48)
            .margin({ bottom: 12 })
          Text('我是你的数独教练')
            .fontSize(16)
            .fontColor(Colors.titleText)
            .fontWeight(FontWeight.Medium)
          Text('我会引导你思考，但不会直接告诉你答案')
            .fontSize(13)
            .fontColor(Colors.subtitleText)
            .margin({ top: 4 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // Message list
        List({ scroller: this.scroller }) {
          ForEach(this.messages, (msg: ChatMessage, index: number) => {
            ListItem() {
              if (msg.role === 'user') {
                // User message — right aligned
                Row() {
                  Blank()
                  Text(msg.content)
                    .fontSize(15)
                    .fontColor(Colors.primaryText)
                    .backgroundColor(Colors.primaryBtn)
                    .borderRadius(16)
                    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                    .constraintSize({ maxWidth: '75%' })
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 6, bottom: 6 })
              } else {
                // Coach message — left aligned
                Row() {
                  Text('🤖')
                    .fontSize(20)
                    .margin({ right: 8, top: 2 })
                  Text(msg.content + (msg.isStreaming ? ' ●' : ''))
                    .fontSize(15)
                    .fontColor(Colors.titleText)
                    .backgroundColor(Colors.chatBubbleBg)
                    .borderRadius(16)
                    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                    .constraintSize({ maxWidth: '70%' })

                  Blank()
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 6, bottom: 6 })
                .alignItems(VerticalAlign.Top)
              }
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
      }

      Divider().color(Colors.divider).height(0.5)

      // Quick action buttons
      Row({ space: 8 }) {
        this.quickButton('🔍 分析局面', '帮我分析一下当前局面')
        this.quickButton('💡 下一步', '我卡住了，下一步怎么走？')
        this.quickButton('📚 教我技巧', '教我一个数独解题技巧')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: 6 })

      // Input area
      Row({ space: 8 }) {
        TextInput({ text: this.inputText, placeholder: '输入你的问题...' })
          .layoutWeight(1)
          .height(40)
          .borderRadius(20)
          .backgroundColor(Colors.chatInputBg)
          .onChange((value: string) => {
            this.inputText = value
          })
          .onSubmit(() => {
            this.sendMessage(this.inputText)
          })

        Button('发送')
          .fontSize(14)
          .fontColor(Colors.primaryText)
          .backgroundColor(this.inputText.trim() && !this.isLoading ? Colors.primaryBtn : Colors.chatDisabledBtn)
          .height(40)
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .enabled(!!this.inputText.trim() && !this.isLoading)
          .onClick(() => {
            this.sendMessage(this.inputText)
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 6, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.boardBg)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  @Builder
  quickButton(label: string, prompt: string) {
    Text(label)
      .fontSize(13)
      .fontColor(Colors.primaryBtn)
      .backgroundColor(Colors.chatQuickBtnBg)
      .borderRadius(16)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .onClick(() => {
        if (!this.isLoading) {
          this.sendMessage(prompt)
        }
      })
      .opacity(this.isLoading ? 0.5 : 1)
  }
}
