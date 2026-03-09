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
  @Prop maxErrors: number = 3

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
      Text(getDifficultyConfig(this.difficulty).name)
        .fontSize(14)
        .fontColor(this.getDifficultyColor())
        .fontWeight(FontWeight.Medium)

      // 中：计时器
      Text(this.formattedTime)
        .fontSize(18)
        .fontColor(Colors.titleText)
        .fontWeight(FontWeight.Medium)

      // 右：错误计数
      Text(`✕ ${this.errorCount}/${this.maxErrors}`)
        .fontSize(14)
        .fontColor(this.getErrorColor())
    }
    .width('100%')
    .height(Sizes.topBarHeight)
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
  }
}
