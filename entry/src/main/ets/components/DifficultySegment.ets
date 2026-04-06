/**
 * DifficultySegment.ets — 难度选择器（可折叠下拉式）
 *
 * 基于 CollapsibleSelector 的薄封装，提供难度专属的行内容：
 * 左侧色条 + 名称 + 技巧描述 + 右侧难度指示点。
 *
 * 参考：Doc 05 §④ 难度选择器
 */
import { Colors, Difficulty, DIFFICULTY_CONFIGS, DifficultyConfig } from '../constants/GameConstants'
import { CollapsibleSelector, SelectorOption } from './CollapsibleSelector'

/** 将 DifficultyConfig 适配为 SelectorOption */
class DifficultyOption implements SelectorOption {
  key: string
  enabled: boolean = true
  config: DifficultyConfig

  constructor(config: DifficultyConfig) {
    this.key = config.level.toString()
    this.config = config
  }
}

const DIFFICULTY_OPTIONS: DifficultyOption[] =
  DIFFICULTY_CONFIGS.map(c => new DifficultyOption(c))

@Component
export struct DifficultySegment {
  @Link selectedDifficulty: Difficulty
  // 内部桥接用的 string key，与 selectedDifficulty 双向同步
  @State private selectedKey: string = ''
  @State private expanded: boolean = false

  aboutToAppear(): void {
    this.selectedKey = this.selectedDifficulty.toString()
  }

  @Builder
  difficultyRowBuilder(option: SelectorOption, _isSelected: boolean, _expanded: boolean) {
    Row() {
      // 左侧色条
      Column()
        .width(4)
        .height(this.selectedKey === option.key ? 36 : 24)
        .borderRadius(2)
        .backgroundColor((option as DifficultyOption).config.color)
        .animation({ duration: 200, curve: Curve.EaseInOut })

      // 难度名称 + 技巧描述
      Column() {
        Text(getContext(this).resourceManager.getStringByNameSync((option as DifficultyOption).config.name))
          .fontSize(15)
          .fontColor(this.selectedKey === option.key ? Colors.titleText : Colors.subtitleText)
          .fontWeight(this.selectedKey === option.key ? FontWeight.Medium : FontWeight.Normal)
          .animation({ duration: 200, curve: Curve.EaseInOut })

        Text(getContext(this).resourceManager.getStringByNameSync((option as DifficultyOption).config.descName))
          .fontSize(11)
          .fontColor((option as DifficultyOption).config.color)
          .margin({ top: 2 })
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
            .fill((i as number) < (option as DifficultyOption).config.level
              ? (option as DifficultyOption).config.color
              : Colors.diffDotInactive)
        })
      }
    }
    .layoutWeight(1)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    CollapsibleSelector({
      selectedKey: $selectedKey,
      options: DIFFICULTY_OPTIONS,
      itemHeight: 56,
      onChange: (key: string) => {
        this.selectedDifficulty = Number(key) as Difficulty
      },
      onExpandChange: (expanded: boolean) => {
        this.expanded = expanded
      },
      rowBuilder: (option: SelectorOption, isSelected: boolean, expanded: boolean) => {
        this.difficultyRowBuilder(option, isSelected, expanded)
      },
    })
  }
}
