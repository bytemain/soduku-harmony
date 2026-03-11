/**
 * GameLoadingView.ets — 游戏页加载态
 */
import { Colors } from '../constants/GameConstants'

@Component
export struct GameLoadingView {
  @Prop title: string = ''
  @Prop message: string = ''
  @Prop progress: number = 0

  build() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(Colors.primaryBtn)

      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.titleText)

      Text(this.message)
        .fontSize(14)
        .fontColor(Colors.subtitleText)

      Text(`${Math.max(0, Math.min(100, Math.round(this.progress)))}%`)
        .fontSize(13)
        .fontColor(Colors.primaryBtn)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24 })
  }
}
