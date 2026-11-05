/**
 * AuxButtonGrid.ets — 辅助按钮区（2×3 网格）
 *
 * 撤销、重做、擦除、提示、设置、自动候选数。
 *
 * 参考：Doc 05 §③ 操作区
 *
 * 注意：不使用 @Builder 传 disabled 参数，因为 @Builder 会在首次渲染时
 * 按值捕获参数，后续 @Prop 变化不会反映到 @Builder 内部。
 * 改用 @Component AuxButton，通过 @Prop disabled 实现响应式更新。
 */
import { ColorsConfig, getThemeColors, Sizes } from '../constants/GameConstants'

@Component
struct AuxButton {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  @Prop compact: boolean = false
  @Prop icon: Resource = $r('app.media.paper_help')
  @Prop showIcon: boolean = true
  @Prop label: ResourceStr = ''
  @Prop disabled: boolean = false
  @Prop loading: boolean = false
  onTap: () => void = () => {}

  build() {
    Column() {
      Stack() {
        if (this.loading) {
          Text('…')
            .fontSize(this.compact ? 20 : Sizes.auxIcon)
            .fontColor(this.getPalette().toolbarIcon)
        } else if (this.showIcon) {
          Image(this.icon)
            .width(this.compact ? 20 : Sizes.auxIcon)
            .height(this.compact ? 20 : Sizes.auxIcon)
            .fillColor(this.getPalette().toolbarIcon)
            .accessibilityLevel('no')
        }
      }
      .width('100%')
      .height('58%')
      Text(this.label)
        .fontSize(this.compact ? 11 : Sizes.auxText)
        .minFontSize(1)
        .maxFontSize(this.compact ? 11 : Sizes.auxText)
        .maxLines(1)
        .heightAdaptivePolicy(TextHeightAdaptivePolicy.LAYOUT_CONSTRAINT_FIRST)
        .width('100%')
        .height('34%')
        .textAlign(TextAlign.Center)
        .fontColor((this.disabled || this.loading) ? this.getPalette().subtitleText : this.getPalette().toolbarIcon)
        .margin({ top: 1 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(3)
    .borderRadius(0)
    .backgroundColor(Color.Transparent)
    .clip(true)
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
  /** 是否使用横排布局（一行 6 个按钮，置于键盘上方） */
  @Prop horizontal: boolean = false
  @Prop compactTools: boolean = false
  /** 横排布局时的行高 */
  @Prop rowHeight: number = 56

  build() {
    if (this.horizontal) {
      // 横排布局：一行 5~6 个按钮（autoNotesVisible 时为 6），置于键盘上方。
      // 与 2×3 模式不同，这里按可见按钮数动态调整列数，避免出现空占位。
      Grid() {
        GridItem() {
          AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_undo'), label: $r('app.string.aux_undo'), disabled: this.undoDisabled, onTap: () => this.onUndo() })
        }
        GridItem() {
          AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_redo'), label: $r('app.string.aux_redo'), disabled: this.redoDisabled, onTap: () => this.onRedo() })
        }
        GridItem() {
          AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_erase'), label: $r('app.string.aux_erase'), disabled: this.eraseDisabled, onTap: () => this.onErase() })
        }
        GridItem() {
          AuxButton({ compact: this.compactTools,
            icon: $r('app.media.paper_help'),
            label: this.hintLoading ? $r('app.string.aux_hint_loading') : $r('app.string.aux_hint'),
            disabled: this.hintDisabled,
            loading: this.hintLoading,
            onTap: () => this.onHint()
          })
        }
        GridItem() {
          AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_settings'), label: $r('app.string.aux_settings'), disabled: false, onTap: () => this.onSettings() })
        }
        if (this.autoNotesVisible) {
          GridItem() {
            AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_pencil'), label: $r('app.string.aux_auto_notes'), disabled: this.autoNotesDisabled, onTap: () => this.onAutoNotes() })
          }
        }
      }
      .columnsTemplate(this.compactTools ? '1fr 1fr 1fr' :
        (this.autoNotesVisible ? '1fr 1fr 1fr 1fr 1fr 1fr' : '1fr 1fr 1fr 1fr 1fr'))
      .rowsTemplate(this.compactTools ? '1fr 1fr' : '1fr')
      .columnsGap(4)
      .rowsGap(this.compactTools ? 4 : 0)
      .width('100%')
      .height(this.compactTools ? 100 : this.rowHeight)
    } else {
      Grid() {
        GridItem() {
          AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_undo'), label: $r('app.string.aux_undo'), disabled: this.undoDisabled, onTap: () => this.onUndo() })
        }
        GridItem() {
          AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_redo'), label: $r('app.string.aux_redo'), disabled: this.redoDisabled, onTap: () => this.onRedo() })
        }
        GridItem() {
          AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_erase'), label: $r('app.string.aux_erase'), disabled: this.eraseDisabled, onTap: () => this.onErase() })
        }
        GridItem() {
          AuxButton({ compact: this.compactTools,
            icon: $r('app.media.paper_help'),
            label: this.hintLoading ? $r('app.string.aux_hint_loading') : $r('app.string.aux_hint'),
            disabled: this.hintDisabled,
            loading: this.hintLoading,
            onTap: () => this.onHint()
          })
        }
        if (this.compactTools && !this.autoNotesVisible) {
          GridItem() {
            AuxButton({ compact: true, icon: $r('app.media.paper_settings'), label: $r('app.string.aux_settings'), disabled: false, onTap: () => this.onSettings() })
          }.columnStart(0).columnEnd(1)
        } else {
          GridItem() {
            AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_settings'), label: $r('app.string.aux_settings'), disabled: false, onTap: () => this.onSettings() })
          }
          GridItem() {
            if (this.autoNotesVisible) {
              AuxButton({ compact: this.compactTools, icon: $r('app.media.paper_pencil'), label: $r('app.string.aux_auto_notes'), disabled: this.autoNotesDisabled, onTap: () => this.onAutoNotes() })
            }
          }
        }
      }
      .columnsTemplate('1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr')
      .columnsGap(4)
      .rowsGap(4)
      .width(this.compactTools ? 92 : (this.gridHeight > 0 ? this.gridHeight * 2 / 3 : 0))
      .height(this.gridHeight > 0 ? this.gridHeight : 0)
    }
  }
}
