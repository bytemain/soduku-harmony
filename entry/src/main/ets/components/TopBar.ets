/**
 * TopBar.ets — 顶部信息栏
 *
 * 显示：难度标签 | 计时器 | 错误计数
 *
 * 参考：Doc 05 §① 顶部信息栏
 */
import { Colors, Sizes, Difficulty, getDifficultyConfig } from '../constants/GameConstants'

@Component
export struct TopBar {
  @Prop difficulty: Difficulty = Difficulty.EASY
  @Prop formattedTime: string = '00:00'
  @Prop errorCount: number = 0
  @Prop isPaused: boolean = false
  onPause: () => void = () => {}

  private getDifficultyColor(): ResourceColor {
    return getDifficultyConfig(this.difficulty).color
  }

  private getErrorColor(): ResourceColor {
    if (this.errorCount >= 3) return Colors.textError
    if (this.errorCount >= 2) return Colors.diffHard
    if (this.errorCount >= 1) return Colors.textError
    return Colors.titleText
  }

  build() {
    Row() {
      // 左：难度标签
      Text(getContext(this).resourceManager.getStringByNameSync(getDifficultyConfig(this.difficulty).name))
        .fontSize(14)
        .fontColor(this.getDifficultyColor())
        .fontWeight(FontWeight.Medium)

      // 中：计时器（可点击暂停/恢复）
      Row({ space: 6 }) {
        Text(this.isPaused ? '▶' : '⏸')
          .fontSize(14)
          .fontColor(Colors.primaryBtn)
        Text(this.formattedTime)
          .fontSize(18)
          .fontColor(this.isPaused ? Colors.subtitleText : Colors.titleText)
          .fontWeight(FontWeight.Medium)
      }
      .onClick(() => this.onPause())
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(8)
      .backgroundColor(this.isPaused ? Colors.topBarPausedBg : Color.Transparent)

      // 右：错误计数
      Text(`✕ ${this.errorCount}`)
        .fontSize(14)
        .fontColor(this.getErrorColor())
    }
    .width('100%')
    .height(Sizes.topBarHeight)
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
  }
}
