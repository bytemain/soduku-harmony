/**
 * GameLoadingView.ets — 游戏页加载态
 */
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'

@Component
export struct GameLoadingView {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  @Prop title: string = ''
  @Prop message: string = ''
  @Prop progress: number = 0

  build() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(this.getPalette().primaryBtn)

      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getPalette().titleText)

      Text(this.message)
        .fontSize(14)
        .fontColor(this.getPalette().subtitleText)

      Text(`${Math.max(0, Math.min(100, Math.round(this.progress)))}%`)
        .fontSize(13)
        .fontColor(this.getPalette().primaryBtn)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24 })
  }
}
