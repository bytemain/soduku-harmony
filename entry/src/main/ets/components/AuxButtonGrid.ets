/**
 * AuxButtonGrid.ets — 辅助按钮区（2×3 网格）
 *
 * 撤销、前进、擦除、提示、设置、自动候选数。
 *
 * 参考：Doc 05 §③ 操作区
 *
 * 注意：不使用 @Builder 传 disabled 参数，因为 @Builder 会在首次渲染时
 * 按值捕获参数，后续 @Prop 变化不会反映到 @Builder 内部。
 * 改用 @Component AuxButton，通过 @Prop disabled 实现响应式更新。
 */
import { Colors, Sizes } from '../constants/GameConstants'

@Component
struct AuxButton {
  icon: string = ''
  label: ResourceStr = ''
  @Prop disabled: boolean = false
  @Prop loading: boolean = false
  onTap: () => void = () => {}

  build() {
    Column() {
      Text(this.loading ? '⏳' : this.icon)
        .fontSize(Sizes.auxIcon)
      Text(this.label)
        .fontSize(Sizes.auxText)
        .fontColor((this.disabled || this.loading) ? Colors.subtitleText : Colors.toolbarIcon)
        .margin({ top: 1 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(Sizes.auxRadius)
    .backgroundColor(Colors.keyBg)
    .opacity((this.disabled || this.loading) ? 0.4 : 1)
    .onClick(() => {
      if (!this.disabled && !this.loading) {
        this.onTap()
      }
    })
  }
}

@Component
export struct AuxButtonGrid {
  onUndo: () => void = () => {}
  onRedo: () => void = () => {}
  onErase: () => void = () => {}
  onHint: () => void = () => {}
  onSettings: () => void = () => {}
  onAutoNotes: () => void = () => {}

  @Prop undoDisabled: boolean = true
  @Prop redoDisabled: boolean = true
  @Prop eraseDisabled: boolean = true
  @Prop hintDisabled: boolean = false
  @Prop hintLoading: boolean = false
  @Prop autoNotesDisabled: boolean = false
  @Prop autoNotesVisible: boolean = false
  @Prop gridHeight: number = 0

  build() {
    Grid() {
      GridItem() {
        AuxButton({ icon: '↩️', label: $r('app.string.aux_undo'), disabled: this.undoDisabled, onTap: () => this.onUndo() })
      }
      GridItem() {
        AuxButton({ icon: '↪️', label: $r('app.string.aux_redo'), disabled: this.redoDisabled, onTap: () => this.onRedo() })
      }
      GridItem() {
        AuxButton({ icon: '🗑️', label: $r('app.string.aux_erase'), disabled: this.eraseDisabled, onTap: () => this.onErase() })
      }
      GridItem() {
        AuxButton({
          icon: '💡',
          label: this.hintLoading ? $r('app.string.aux_hint_loading') : $r('app.string.aux_hint'),
          disabled: this.hintDisabled,
          loading: this.hintLoading,
          onTap: () => this.onHint()
        })
      }
      GridItem() {
        AuxButton({ icon: '⚙️', label: $r('app.string.aux_settings'), disabled: false, onTap: () => this.onSettings() })
      }
      GridItem() {
        if (this.autoNotesVisible) {
          AuxButton({ icon: '✏️', label: $r('app.string.aux_auto_notes'), disabled: this.autoNotesDisabled, onTap: () => this.onAutoNotes() })
        } else {
          AuxButton({ icon: '', label: '', disabled: true })
        }
      }
    }
    .columnsTemplate('1fr 1fr')
    .rowsTemplate('1fr 1fr 1fr')
    .columnsGap(4)
    .rowsGap(4)
    .width(this.gridHeight > 0 ? this.gridHeight * 2 / 3 : 0)
    .height(this.gridHeight > 0 ? this.gridHeight : 0)
  }
}
