/**
 * CollapsibleSelector.ets — 通用可折叠单选器
 *
 * 提供折叠/展开动画的壳子，行内容通过 @BuilderParam 由外部自定义。
 *
 * 动画设计：
 * - 始终渲染全部行，选中项节点永不销毁，保持连续可见。
 * - 非选中项通过 height 0↔itemHeight + opacity 0↔1 实现展开/折叠。
 * - 展开时从选中项中心向两端扩散（stagger delay）。
 * - 收起时先切高亮（200ms），再折叠（300ms）。
 */
import { Colors } from '../constants/GameConstants'

/** 选项数据的通用接口 */
export interface SelectorOption {
  /** 唯一标识（用于判断选中态） */
  key: string
  /** 是否可选 */
  enabled: boolean
}

/** 非选中行展开后的默认高度 */
const DEFAULT_ITEM_HEIGHT = 44

@Component
export struct CollapsibleSelector {
  /** 当前选中项的 key */
  @Link selectedKey: string
  /** 全部选项列表 */
  options: SelectorOption[] = []
  /** 非选中行展开后的高度，可由外部覆盖 */
  itemHeight: number = DEFAULT_ITEM_HEIGHT
  /** 选中变化时的回调 */
  onChange?: (key: string) => void
  /** 展开/折叠状态变化回调 */
  onExpandChange?: (expanded: boolean) => void
  /** 行内容构建器，由外部提供。参数：(option, isSelected, expanded) */
  @BuilderParam rowBuilder: (option: SelectorOption, isSelected: boolean, expanded: boolean) => void
  @State expanded: boolean = false

  private getSelectedIndex(): number {
    return this.options.findIndex(o => o.key === this.selectedKey)
  }

  build() {
    Column({ space: 0 }) {
      ForEach(this.options, (option: SelectorOption, index: number) => {
        Column() {
          // 行内容：左侧自定义内容 + 右侧箭头包在一个 Row 里
          Row() {
            // 外部提供的自定义行内容
            this.rowBuilder(option, this.selectedKey === option.key, this.expanded)

            Blank()

            // 选中项显示展开/收起箭头
            if (this.selectedKey === option.key) {
              Text(this.expanded ? '▲' : '▼')
                .fontSize(10)
                .fontColor(Colors.subtitleText)
                .margin({ left: 8 })
            }
          }
          .width('100%')
          .padding({ left: 12, right: 16, top: 10, bottom: 10 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor(this.selectedKey === option.key ? Colors.segmentSelected : 'transparent')
          .borderRadius(12)
          .opacity(option.enabled ? 1.0 : 0.5)
          .shadow(this.selectedKey === option.key ? {
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
        .width('100%')
        .height(
          this.selectedKey === option.key
            ? undefined
            : (this.expanded ? this.itemHeight : 0)
        )
        .opacity(
          this.selectedKey === option.key
            ? 1
            : (this.expanded ? 1 : 0)
        )
        .clip(true)
        .animation({
          duration: this.selectedKey === option.key
            ? 300
            : (this.expanded ? 250 : 150),
          curve: Curve.EaseInOut,
          delay: this.expanded
            ? Math.abs(index - this.getSelectedIndex()) * 40
            : 0,
        })
        .onClick(() => {
          if (this.expanded) {
            if (!option.enabled) return
            // 展开态：先切高亮，再折叠
            if (this.onExpandChange) {
              this.onExpandChange(false)
            }
            animateTo({
              duration: 200, curve: Curve.EaseOut,
              onFinish: () => {
                animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
                  this.expanded = false
                })
              }
            }, () => {
              this.selectedKey = option.key
              if (this.onChange) {
                this.onChange(option.key)
              }
            })
          } else if (this.selectedKey === option.key) {
            // 折叠态：点击选中项 → 展开
            if (this.onExpandChange) {
              this.onExpandChange(true)
            }
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
