/**
 * DifficultySegment.ets — 难度选择器（可折叠下拉式）
 *
 * 默认折叠只显示当前选中的难度，点击展开显示全部选项，选择后自动折叠。
 * 每个难度一行，左侧色条 + 名称 + 右侧难度指示点。
 *
 * 参考：Doc 05 §④ 难度选择器
 */
import { Colors, Difficulty, DIFFICULTY_CONFIGS, DifficultyConfig, getDifficultyConfig } from '../constants/GameConstants'

@Component
export struct DifficultySegment {
  @Link selectedDifficulty: Difficulty
  @State expanded: boolean = false

  @Builder
  DifficultyRow(config: DifficultyConfig, isSelected: boolean) {
    Row() {
      // 左侧色条
      Column()
        .width(4)
        .height(isSelected ? 36 : 24)
        .borderRadius(2)
        .backgroundColor(config.color)
        .animation({ duration: 200, curve: Curve.EaseInOut })

      // 难度名称 + 技巧描述
      Column() {
        Text(getContext(this).resourceManager.getStringByNameSync(config.name))
          .fontSize(15)
          .fontColor(isSelected ? Colors.titleText : Colors.subtitleText)
          .fontWeight(isSelected ? FontWeight.Medium : FontWeight.Normal)
          .animation({ duration: 200, curve: Curve.EaseInOut })

        Text(getContext(this).resourceManager.getStringByNameSync(config.descName))
          .fontSize(11)
          .fontColor(config.color)
          .margin({ top: isSelected ? 2 : 0 })
          .height(isSelected ? 16 : 0)
          .opacity(isSelected ? 1 : 0)
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
            .fill((i as number) < config.level ? config.color : Colors.diffDotInactive)
        })
      }

      // 折叠状态下显示展开/收起箭头
      if (isSelected) {
        Text(this.expanded ? '▲' : '▼')
          .fontSize(10)
          .fontColor(Colors.subtitleText)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(isSelected ? Colors.segmentSelected : 'transparent')
    .borderRadius(12)
    .shadow(isSelected ? {
      radius: 4,
      color: Colors.shadowColor,
      offsetX: 0,
      offsetY: 1,
    } : {
      radius: 0,
      color: 'transparent',
      offsetX: 0,
      offsetY: 0,
    })
    .animation({ duration: 200, curve: Curve.EaseInOut })
  }

  build() {
    Column({ space: 0 }) {
      if (this.expanded) {
        // 展开状态：显示全部选项
        ForEach(DIFFICULTY_CONFIGS, (config: DifficultyConfig, index: number) => {
          Row() {
            this.DifficultyRow(config, this.selectedDifficulty === config.level)
          }
          .transition(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: -10 }))
              .animation({ duration: 250, curve: Curve.EaseInOut, delay: index * 30 })
          )
          .onClick(() => {
            animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
              this.selectedDifficulty = config.level
              this.expanded = false
            })
          })
        })
      } else {
        // 折叠状态：只显示选中项
        Row() {
          this.DifficultyRow(getDifficultyConfig(this.selectedDifficulty), true)
        }
        .transition(
          TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseInOut })
        )
        .onClick(() => {
          animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
            this.expanded = true
          })
        })
      }
    }
    .width('100%')
    .backgroundColor(Colors.segmentBg)
    .borderRadius(16)
    .padding(4)
    .animation({ duration: 250, curve: Curve.EaseInOut })
  }
}
