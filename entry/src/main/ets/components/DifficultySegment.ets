/**
 * DifficultySegment.ets — 5 段难度选择器
 *
 * 胶囊形分段按钮。选中项白底+阴影，未选中灰底。
 *
 * 参考：Doc 05 §④ 难度选择器
 */
import { Colors, Sizes, Difficulty, DIFFICULTY_CONFIGS, DifficultyConfig } from '../constants/GameConstants'

@Component
export struct DifficultySegment {
  @Link selectedDifficulty: Difficulty

  build() {
    Row() {
      ForEach(DIFFICULTY_CONFIGS, (config: DifficultyConfig) => {
        Column() {
          Text(getContext(this).resourceManager.getStringByNameSync(config.name))
            .fontSize(14)
            .fontColor(this.selectedDifficulty === config.level ? Colors.segmentActive : Colors.segmentText)
            .fontWeight(this.selectedDifficulty === config.level ? FontWeight.Medium : FontWeight.Normal)

          // 难度色标小点
          Circle()
            .width(6)
            .height(6)
            .fill(config.color)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.selectedDifficulty === config.level ? Colors.segmentSelected : 'transparent')
        .borderRadius(Sizes.segmentRadius)
        .shadow(this.selectedDifficulty === config.level ? {
          radius: 4,
          color: '#1A000000',
          offsetX: 0,
          offsetY: 2,
        } : {
          radius: 0,
          color: 'transparent',
          offsetX: 0,
          offsetY: 0,
        })
        .animation({ duration: 200, curve: Curve.EaseInOut })
        .onClick(() => {
          this.selectedDifficulty = config.level
        })
      })
    }
    .width('100%')
    .height(Sizes.segmentHeight)
    .backgroundColor(Colors.segmentBg)
    .borderRadius(Sizes.segmentRadius)
    .padding(3)
  }
}
