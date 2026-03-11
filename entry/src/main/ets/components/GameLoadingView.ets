/**
 * GameLoadingView.ets — 游戏页加载态
 */
import { Colors } from '../constants/GameConstants'

@Component
export struct GameLoadingView {
  build() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(Colors.primaryBtn)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
