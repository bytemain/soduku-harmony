/**
 * MultiSelectBanner.ets — 多选模式提示条
 */
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'

@Component
export struct MultiSelectBanner {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  hintText: string = ''
  @Prop count: number = 0
  onClose: () => void = () => {}

  build() {
    Row({ space: 8 }) {
      Image($r('app.media.paper_select'))
        .width(16)
        .height(16)
        .fillColor(this.getPalette().primaryBtn)
        .accessibilityLevel('no')
      Text(`${this.hintText}（${this.count}）`)
        .fontSize(13)
        .fontColor(this.getPalette().primaryBtn)
      Image($r('app.media.paper_close'))
        .width(18)
        .height(18)
        .fillColor(this.getPalette().subtitleText)
        .accessibilityText($r('app.string.a11y_close'))
        .onClick(() => this.onClose())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 4, bottom: 4 })
    .margin({ top: 4 })
    .backgroundColor(this.getPalette().multiSelectBar)
    .borderRadius(8)
  }
}
