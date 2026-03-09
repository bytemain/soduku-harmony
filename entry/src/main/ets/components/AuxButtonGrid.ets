/**
 * AuxButtonGrid.ets — 辅助按钮区（2×3 网格）
 *
 * 撤销、前进、擦除、提示、设置、预留。
 *
 * 参考：Doc 05 §③ 操作区
 */
import { Colors, Sizes } from '../constants/GameConstants'

export interface AuxButtonConfig {
  icon: string
  label: string
  disabled: boolean
  onTap: () => void
}

@Component
export struct AuxButtonGrid {
  onUndo: () => void = () => {}
  onRedo: () => void = () => {}
  onErase: () => void = () => {}
  onHint: () => void = () => {}
  onSettings: () => void = () => {}

  @Prop undoDisabled: boolean = true
  @Prop redoDisabled: boolean = true
  @Prop eraseDisabled: boolean = true
  @Prop hintDisabled: boolean = false

  @Builder
  AuxButton(icon: string, label: string, disabled: boolean, onTap: () => void) {
    Column() {
      Text(icon)
        .fontSize(Sizes.auxIcon)
      Text(label)
        .fontSize(Sizes.auxText)
        .fontColor(disabled ? Colors.subtitleText : Colors.toolbarIcon)
        .margin({ top: 2 })
    }
    .width(Sizes.auxColWidth)
    .height(Sizes.auxColWidth)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(Sizes.auxRadius)
    .backgroundColor(Colors.keyBg)
    .opacity(disabled ? 0.4 : 1)
    .onClick(() => {
      if (!disabled) {
        onTap()
      }
    })
  }

  build() {
    Grid() {
      GridItem() {
        this.AuxButton('↩️', '撤销', this.undoDisabled, this.onUndo)
      }

      GridItem() {
        this.AuxButton('↪️', '前进', this.redoDisabled, this.onRedo)
      }

      GridItem() {
        this.AuxButton('🗑️', '擦除', this.eraseDisabled, this.onErase)
      }

      GridItem() {
        this.AuxButton('💡', '提示', this.hintDisabled, this.onHint)
      }

      GridItem() {
        this.AuxButton('⚙️', '设置', false, this.onSettings)
      }

      GridItem() {
        // 预留
        this.AuxButton('', '', true, () => {})
      }
    }
    .columnsTemplate('1fr 1fr')
    .rowsTemplate('1fr 1fr 1fr')
    .columnsGap(6)
    .rowsGap(6)
    .width(Sizes.auxColWidth * 2 + 6)
    .height('100%')
  }
}
