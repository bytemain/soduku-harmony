/**
 * MultiSelectBanner.ets — 多选模式提示条
 */
import { Colors } from '../constants/GameConstants'

@Component
export struct MultiSelectBanner {
  hintText: string = ''
  @Prop count: number = 0
  onClose: () => void = () => {}

  build() {
    Row({ space: 8 }) {
      Text(`🔲 ${this.hintText}（${this.count}）`)
        .fontSize(13)
        .fontColor(Colors.primaryBtn)
      Text('✕')
        .fontSize(14)
        .fontColor(Colors.subtitleText)
        .onClick(() => this.onClose())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 4, bottom: 4 })
    .margin({ top: 4 })
    .backgroundColor(Colors.multiSelectBar)
    .borderRadius(8)
  }
}
