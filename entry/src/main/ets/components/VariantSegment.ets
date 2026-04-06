/**
 * VariantSegment.ets — 变种模式选择器（可折叠下拉式）
 *
 * 基于 CollapsibleSelector 的薄封装，提供变种模式专属的行内容：
 * 左侧图标 + 名称 + 描述。
 */
import { Colors } from '../constants/GameConstants'
import { VariantType } from '../models/VariantConfig'
import { CollapsibleSelector, SelectorOption } from './CollapsibleSelector'

class VariantOption implements SelectorOption {
  key: string
  enabled: boolean
  icon: string
  nameKey: string
  descKey: string
  type: VariantType

  constructor(type: VariantType, icon: string, nameKey: string, descKey: string, enabled: boolean) {
    this.key = type as string
    this.type = type
    this.icon = icon
    this.nameKey = nameKey
    this.descKey = descKey
    this.enabled = enabled
  }
}

const VARIANT_OPTIONS: VariantOption[] = [
  new VariantOption(VariantType.STANDARD, '🔢', 'variant_standard', 'variant_standard_desc', true),
  new VariantOption(VariantType.DIAGONAL, '╳', 'variant_diagonal', 'variant_diagonal_desc', true),
  new VariantOption(VariantType.JIGSAW, '🧩', 'variant_jigsaw', 'variant_jigsaw_desc', true),
  new VariantOption(VariantType.KILLER, '🗡️', 'variant_killer', 'variant_killer_desc', true),
]

@Component
export struct VariantSegment {
  @Link selectedVariant: VariantType
  onVariantChange?: (variant: VariantType) => void
  @State private selectedKey: string = ''
  @State private expanded: boolean = false

  aboutToAppear(): void {
    this.selectedKey = this.selectedVariant as string
  }

  @Builder
  variantRowBuilder(option: SelectorOption, _isSelected: boolean, _expanded: boolean) {
    Row() {
      // 左侧图标
      Text((option as VariantOption).icon)
        .fontSize(22)
        .width(32)
        .textAlign(TextAlign.Center)

      // 名称 + 描述
      Column() {
        Text(getContext(this).resourceManager.getStringByNameSync((option as VariantOption).nameKey))
          .fontSize(15)
          .fontColor(this.selectedKey === option.key ? Colors.titleText : Colors.subtitleText)
          .fontWeight(this.selectedKey === option.key ? FontWeight.Medium : FontWeight.Normal)
          .animation({ duration: 200, curve: Curve.EaseInOut })

        // 描述文字：展开态所有选项都显示，折叠态只有选中项显示
        if (!(option as VariantOption).enabled) {
          Text(getContext(this).resourceManager.getStringByNameSync('variant_coming_soon'))
            .fontSize(11)
            .fontColor(Colors.subtitleText)
            .margin({ top: 2 })
        } else {
          Text(getContext(this).resourceManager.getStringByNameSync((option as VariantOption).descKey))
            .fontSize(11)
            .fontColor(this.selectedKey === option.key ? Colors.primaryBtn : Colors.subtitleText)
            .margin({ top: 2 })
        }
      }
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    CollapsibleSelector({
      selectedKey: $selectedKey,
      options: VARIANT_OPTIONS,
      itemHeight: 56,
      onChange: (key: string) => {
        this.selectedVariant = key as VariantType
        if (this.onVariantChange) {
          this.onVariantChange(key as VariantType)
        }
      },
      onExpandChange: (expanded: boolean) => {
        this.expanded = expanded
      },
      rowBuilder: (option: SelectorOption, isSelected: boolean, expanded: boolean) => {
        this.variantRowBuilder(option, isSelected, expanded)
      },
    })
  }
}
