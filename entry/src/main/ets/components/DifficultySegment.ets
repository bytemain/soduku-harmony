/**
 * DifficultySegment.ets — 难度选择器
 *
 * 竖向难度卡片列表，每个难度一行，左侧色条 + 名称 + 右侧难度指示点。
 * 选中项突出显示，未选中项灰色。
 *
 * 参考：Doc 05 §④ 难度选择器
 */
import { Colors, Difficulty, DIFFICULTY_CONFIGS, DifficultyConfig } from '../constants/GameConstants'

@Component
export struct DifficultySegment {
  @Link selectedDifficulty: Difficulty

  build() {
    Column({ space: 0 }) {
      ForEach(DIFFICULTY_CONFIGS, (config: DifficultyConfig) => {
        Row() {
          // 左侧色条
          Column()
            .width(4)
            .height(this.selectedDifficulty === config.level ? 36 : 24)
            .borderRadius(2)
            .backgroundColor(config.color)
            .animation({ duration: 200, curve: Curve.EaseInOut })

          // 难度名称 + 技巧描述
          Column() {
            Text(getContext(this).resourceManager.getStringByNameSync(config.name))
              .fontSize(15)
              .fontColor(this.selectedDifficulty === config.level ? Colors.titleText : Colors.subtitleText)
              .fontWeight(this.selectedDifficulty === config.level ? FontWeight.Medium : FontWeight.Normal)
              .animation({ duration: 200, curve: Curve.EaseInOut })

            Text(getContext(this).resourceManager.getStringByNameSync(config.descName))
              .fontSize(11)
              .fontColor(config.color)
              .margin({ top: this.selectedDifficulty === config.level ? 2 : 0 })
              .height(this.selectedDifficulty === config.level ? 16 : 0)
              .opacity(this.selectedDifficulty === config.level ? 1 : 0)
              .animation({ duration: 200, curve: Curve.EaseInOut })
          }
          .margin({ left: 12 })
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 右侧难度指示点（根据难度级别显示 1-5 个点）
          Row({ space: 3 }) {
            ForEach(Array.from({ length: 5 }), (_: undefined, i: number) => {
              Circle()
                .width(6)
                .height(6)
                .fill((i as number) < config.level ? config.color : '#E0E0E0')
            })
          }
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 10, bottom: 10 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.selectedDifficulty === config.level ? Colors.segmentSelected : 'transparent')
        .borderRadius(12)
        .shadow(this.selectedDifficulty === config.level ? {
          radius: 4,
          color: '#1A000000',
          offsetX: 0,
          offsetY: 1,
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
    .backgroundColor(Colors.segmentBg)
    .borderRadius(16)
    .padding(4)
  }
}
