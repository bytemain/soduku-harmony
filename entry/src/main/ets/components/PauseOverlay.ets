/**
 * PauseOverlay.ets — 游戏暂停遮罩
 *
 * 键盘支持：ESC / Enter / Space 恢复游戏
 */
import { KeyCode } from '@kit.InputKit'
import { Colors } from '../constants/GameConstants'

@Component
export struct PauseOverlay {
  seedId: string = '-'
  puzzle81: string = ''
  difficultyLabel: string = '-'
  symmetryLabel: string = '-'
  displayTime: string = '00:00'

  onCopySeed: () => void = () => {}
  onCopyPuzzle: () => void = () => {}
  onResume: () => void = () => {}
  onRestart: () => void = () => {}
  onHelp: () => void = () => {}
  onQuit: () => void = () => {}

  private getString(name: string): string {
    return getContext(this).resourceManager.getStringByNameSync(name)
  }

  private getPuzzlePreview(): string {
    if (this.puzzle81.length <= 18) {
      return this.puzzle81
    }
    return `${this.puzzle81.substring(0, 18)}...`
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Colors.pauseOverlayBg)
        .opacity(0.85)

      Column() {
        // 上方弹性间距
        Blank()

        // 中部：标题 + 操作按钮
        Column({ space: 16 }) {
          Text('⏸')
            .fontSize(40)
            .margin({ bottom: 4 })
          Text($r('app.string.pause_title'))
            .fontSize(24)
            .fontColor(Colors.pauseOverlayText)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 20 })

          Button($r('app.string.pause_resume'))
            .type(ButtonType.Capsule)
            .width(220)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Colors.primaryBtn)
            .fontColor(Colors.primaryText)
            .onClick(() => this.onResume())

          Button($r('app.string.pause_restart'))
            .type(ButtonType.Capsule)
            .width(220)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Colors.pauseRestartBtn)
            .fontColor(Colors.pauseOverlayText)
            .onClick(() => this.onRestart())

          Button($r('app.string.pause_help'))
            .type(ButtonType.Capsule)
            .width(220)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Colors.pauseHelpBtn)
            .fontColor(Colors.pauseOverlayText)
            .onClick(() => this.onHelp())

          Button($r('app.string.pause_quit'))
            .type(ButtonType.Capsule)
            .width(220)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Colors.pauseQuitBtn)
            .fontColor(Colors.pauseOverlayText)
            .onClick(() => this.onQuit())
        }
        .alignItems(HorizontalAlign.Center)

        // 下方弹性间距
        Blank()

        // 底部：游戏信息（无卡片背景）
        Column({ space: 6 }) {
          Row({ space: 4 }) {
            Text(`${this.getString('pause_info_seed')}: ${this.seedId}`)
              .fontSize(12)
              .fontColor(Colors.pauseInfoText)
            Text('📋')
              .fontSize(11)
          }
          .onClick(() => this.onCopySeed())

          Row({ space: 4 }) {
            Text(`${this.getString('format_81string')}: ${this.getPuzzlePreview()}`)
              .fontSize(12)
              .fontColor(Colors.pauseInfoText)
              .maxLines(1)
            Text('📋')
              .fontSize(11)
          }
          .onClick(() => this.onCopyPuzzle())

          Text(`${this.getString('pause_info_difficulty')}: ${this.difficultyLabel}  |  ${this.getString('pause_info_symmetry')}: ${this.symmetryLabel}`)
            .fontSize(12)
            .fontColor(Colors.pauseInfoText)
          Text(`${this.getString('pause_info_time')}: ${this.displayTime}`)
            .fontSize(12)
            .fontColor(Colors.pauseInfoText)
        }
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      if (event.type === KeyType.Down) {
        // ESC / Enter / Space → 恢复游戏
        if (event.keyCode === KeyCode.KEYCODE_ESCAPE ||
          event.keyCode === KeyCode.KEYCODE_ENTER ||
          event.keyCode === KeyCode.KEYCODE_NUMPAD_ENTER ||
          event.keyCode === KeyCode.KEYCODE_SPACE) {
          this.onResume()
        }
      }
    })
  }
}
