/**
 * PauseOverlay.ets — 游戏暂停遮罩
 */
import { Colors } from '../constants/GameConstants'

@Component
export struct PauseOverlay {
  seedId: string = '-'
  puzzle81: string = ''
  difficultyLabel: string = '-'
  symmetryLabel: string = '-'
  displayTime: string = '00:00'
  @Prop errorCount: number = 0
  @Prop maxErrors: number = 3

  onCopySeed: () => void = () => {}
  onCopyPuzzle: () => void = () => {}
  onResume: () => void = () => {}
  onRestart: () => void = () => {}
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
        .opacity(0.6)

      Column({ space: 16 }) {
        Text($r('app.string.pause_title'))
          .fontSize(24)
          .fontColor(Colors.pauseOverlayText)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 16 })

        Column({ space: 8 }) {
          Row({ space: 4 }) {
            Text(`${this.getString('pause_info_seed')}: ${this.seedId}`)
              .fontSize(13)
              .fontColor(Colors.pauseOverlayText)
            Text('📋')
              .fontSize(12)
          }
          .onClick(() => this.onCopySeed())

          Row({ space: 4 }) {
            Text(`81: ${this.getPuzzlePreview()}`)
              .fontSize(13)
              .fontColor(Colors.pauseOverlayText)
              .maxLines(1)
            Text('📋')
              .fontSize(12)
          }
          .onClick(() => this.onCopyPuzzle())

          Text(`${this.getString('pause_info_difficulty')}: ${this.difficultyLabel}`)
            .fontSize(13)
            .fontColor(Colors.pauseOverlayText)
          Text(`${this.getString('pause_info_symmetry')}: ${this.symmetryLabel}`)
            .fontSize(13)
            .fontColor(Colors.pauseOverlayText)
          Text(`${this.getString('pause_info_time')}: ${this.displayTime}`)
            .fontSize(13)
            .fontColor(Colors.pauseOverlayText)
          Text(`${this.getString('pause_info_errors')}: ${this.errorCount}/${this.maxErrors}`)
            .fontSize(13)
            .fontColor(Colors.pauseOverlayText)
        }
        .width(280)
        .padding(16)
        .borderRadius(16)
        .backgroundColor(Colors.pauseInfoCardBg)
        .margin({ bottom: 8 })

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
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }
}
