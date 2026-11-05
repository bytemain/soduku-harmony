/**
 * TopBar.ets — 顶部信息栏
 *
 * 显示：难度标签 | 计时器 | 错误计数
 *
 * 参考：Doc 05 §① 顶部信息栏
 */
import { ColorsConfig, getThemeColors, getDifficultyColor, Sizes, Difficulty, getDifficultyConfig } from '../constants/GameConstants'
import { getLocalizedString } from '../utils/I18nHelper'

@Component
export struct TopBar {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false
  @StorageProp('localeRevision') private localeRevision: number = 0

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  @Prop difficulty: Difficulty = Difficulty.EASY
  @Prop formattedTime: string = '00:00'
  @Prop errorCount: number = 0
  @Prop showErrors: boolean = true
  @Prop isPaused: boolean = false
  onPause: () => void = () => {}
  onJournal: () => void = () => {}

  private getDifficultyColor(): ResourceColor {
    return getDifficultyColor(this.difficulty, this.isDarkMode)
  }

  private getErrorColor(): ResourceColor {
    return this.getPalette().subtitleText
  }

  build() {
    Row() {
      // 左：难度标签
      Text(getLocalizedString(getContext(this), getDifficultyConfig(this.difficulty).name, this.localeRevision))
        .fontSize(14)
        .fontColor(this.getDifficultyColor())
        .fontWeight(FontWeight.Medium)

      // 中：计时器（可点击暂停/恢复）
      Row({ space: 6 }) {
        Image(this.isPaused ? $r('app.media.paper_play') : $r('app.media.paper_pause'))
          .width(16)
          .height(16)
          .fillColor(this.getPalette().primaryBtn)
          .accessibilityLevel('no')
        Text(this.formattedTime)
          .fontSize(18)
          .fontColor(this.isPaused ? this.getPalette().subtitleText : this.getPalette().titleText)
          .fontWeight(FontWeight.Medium)
      }
      .onClick(() => this.onPause())
      .height(44)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(8)
      .backgroundColor(this.isPaused ? this.getPalette().topBarPausedBg : Color.Transparent)
      .accessibilityText(this.isPaused ? $r('app.string.pause_resume') : $r('app.string.pause_title'))
      .accessibilityDescription(this.formattedTime)

      // 错误只提供反馈，不限制这一局可尝试的次数。
      if (this.showErrors) {
        Row({ space: 4 }) {
          Image($r('app.media.paper_close'))
            .width(14)
            .height(14)
            .fillColor(this.getErrorColor())
            .accessibilityLevel('no')
          Text(this.errorCount.toString())
            .fontSize(14)
            .fontColor(this.getErrorColor())
        }
        .accessibilityDescription($r('app.string.pause_info_errors'))
      }

      Button({ type: ButtonType.Normal }) {
        Image($r('app.media.paper_checkpoint'))
          .width(24).height(24)
          .fillColor(this.getPalette().titleText)
          .accessibilityLevel('no')
      }
        .id('game-journal-open')
        .width(44).height(44)
        .backgroundColor(Color.Transparent)
        .padding(10)
        .borderRadius(6)
        .accessibilityText($r('app.string.journal_open'))
        .onClick(() => this.onJournal())
    }
    .width('100%')
    .height(Sizes.topBarHeight)
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
  }
}
