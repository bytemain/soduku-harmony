import { router } from '@kit.ArkUI'
import { StatsPanel } from '../components/StatsPanel'
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'

@Entry
@Component
struct StatsPage {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false
  @StorageProp('topRectHeight') private topRectHeight: number = 0
  @StorageProp('bottomRectHeight') private bottomRectHeight: number = 0
  @StorageProp('leftRectWidth') private leftRectWidth: number = 0
  @StorageProp('rightRectWidth') private rightRectWidth: number = 0

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  build() {
    Column() {
      StatsPanel({ onClose: () => { router.back() } })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topRectHeight, bottom: this.bottomRectHeight,
      left: this.leftRectWidth, right: this.rightRectWidth })
    .backgroundColor(this.getPalette().pageBg)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
