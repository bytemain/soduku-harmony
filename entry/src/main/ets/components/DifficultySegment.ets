/**
 * DifficultySegment.ets — 难度选择器（可折叠下拉式）
 *
 * 默认折叠只显示当前选中的难度，点击展开显示全部选项，选择后自动折叠。
 * 每个难度一行，左侧色条 + 名称 + 右侧难度指示点。
 *
 * 动画设计（不使用 if/else 切换，而是始终渲染全部 5 行）：
 * - 选中项的 DOM 节点永远不销毁，所以能保持始终亮着、连续可见。
 * - 非选中项通过 height 0↔auto + opacity 0↔1 实现展开/折叠。
 * - 展开时：选中项上方的行先展开，造成选中项被"推下来"的感觉；
 *   然后下方的行依次展开。延迟随距离递增，从中心向两端扩散。
 * - 收起时：非选中项快速缩高+淡出，选中项随布局自然滑到顶部。
 *
 * 参考：Doc 05 §④ 难度选择器
 */
import { Colors, Difficulty, DIFFICULTY_CONFIGS, DifficultyConfig } from '../constants/GameConstants'

/** 非选中行展开后的高度（padding top 10 + bottom 10 + content ~24） */
const ITEM_HEIGHT = 44

@Component
export struct DifficultySegment {
  @Link selectedDifficulty: Difficulty
  @State expanded: boolean = false

  /**
   * 获取当前选中难度在 DIFFICULTY_CONFIGS 中的索引（0-based）。
   */
  private getSelectedIndex(): number {
    return this.selectedDifficulty - 1
  }

  @Builder
  DifficultyRow(config: DifficultyConfig) {
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
            .fill((i as number) < config.level ? config.color : Colors.diffDotInactive)
        })
      }

      // 折叠状态下显示展开/收起箭头
      if (this.selectedDifficulty === config.level) {
        Text(this.expanded ? '▲' : '▼')
          .fontSize(10)
          .fontColor(Colors.subtitleText)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.selectedDifficulty === config.level ? Colors.segmentSelected : 'transparent')
    .borderRadius(12)
    .shadow(this.selectedDifficulty === config.level ? {
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
      // 始终渲染全部 5 行，非选中项通过 height/opacity 控制展开折叠。
      // 选中项节点永不销毁，始终亮着，位置随布局自然变化。
      ForEach(DIFFICULTY_CONFIGS, (config: DifficultyConfig, index: number) => {
        Column() {
          this.DifficultyRow(config)
        }
        .width('100%')
        .height(
          // 选中项始终可见；非选中项展开时显示，折叠时高度为 0
          this.selectedDifficulty === config.level
            ? undefined  // 选中项：自适应高度，始终可见
            : (this.expanded ? ITEM_HEIGHT : 0)
        )
        .opacity(
          this.selectedDifficulty === config.level
            ? 1  // 选中项：始终不透明
            : (this.expanded ? 1 : 0)
        )
        .clip(true)  // 高度为 0 时裁剪掉内容
        .animation({
          duration: this.selectedDifficulty === config.level
            ? 300  // 选中项：跟随布局位移的时长
            : (this.expanded ? 250 : 150),  // 非选中项：展开慢一点，收起快一点
          curve: Curve.EaseInOut,
          // 展开时：离选中项越远延迟越大，从中心向两端扩散
          // 收起时：无延迟，快速收起
          delay: this.expanded
            ? Math.abs(index - this.getSelectedIndex()) * 40
            : 0,
        })
        .onClick(() => {
          if (this.expanded) {
            // 展开态：选了某个选项 → 先切高亮，再折叠
            // 第一步：快速切换选中态高亮（200ms），让用户看到高亮转移
            animateTo({ duration: 200, curve: Curve.EaseOut,
              onFinish: () => {
                // 第二步：高亮切换完成后，驱动折叠动画
                animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
                  this.expanded = false
                })
              }
            }, () => {
              this.selectedDifficulty = config.level
            })
          } else if (this.selectedDifficulty === config.level) {
            // 折叠态：点击选中项 → 展开
            animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
              this.expanded = true
            })
          }
        })
      })
    }
    .width('100%')
    .backgroundColor(Colors.segmentBg)
    .borderRadius(16)
    .padding(4)
  }
}
