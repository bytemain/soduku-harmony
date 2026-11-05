/**
 * GameActionPanel.ets — 游戏页底部操作区
 */
import { GestureDirection, createInitialRemainingCounts } from '../constants/GameConstants'
import { AuxButtonGrid } from './AuxButtonGrid'
import { GestureNumberPad } from './GestureNumberPad'
import { GestureModeIndicator } from './GestureModeIndicator'

@Component
export struct GameActionPanel {
  @Prop isLeftHand: boolean = false
  @Prop remainingCounts: number[] = createInitialRemainingCounts()
  @Prop undoDisabled: boolean = true
  @Prop redoDisabled: boolean = true
  @Prop eraseDisabled: boolean = true
  @Prop hintDisabled: boolean = false
  @Prop hintLoading: boolean = false
  @Prop autoNotesDisabled: boolean = false
  @Prop autoNotesVisible: boolean = false
  @Prop gridHeight: number = 0
  /** 工具按钮是否横排显示在键盘上方 */
  @Prop auxButtonsOnTop: boolean = false
  @Prop keypadColumns: number = 3
  @Prop keypadRows: number = 3
  @Prop stackedKeypadWidth: number = 0
  @Prop compactKeypad: boolean = false
  @Prop keyFontSize: number = 22
  // 只由数字键实际手势更新；不复用键盘 N/Tab 的持久笔记模式。
  @State private gestureHintDirection: GestureDirection | null = null

  onUndo: () => void = () => {}
  onRedo: () => void = () => {}
  onErase: () => void = () => {}
  onHint: () => void = () => {}
  onSettings: () => void = () => {}
  onAutoNotes: () => void = () => {}
  onGesture: (digit: number, direction: GestureDirection) => void = () => {}
  onGestureDirectionChange: (direction: GestureDirection | null) => void = () => {}
  onHeightChange: (height: number) => void = () => {}

  private isGestureHintVisible(): boolean {
    return this.gestureHintDirection !== null && this.gestureHintDirection !== GestureDirection.TAP
  }

  @Builder
  private buildAuxButtons() {
    // 横排时提示在数字键上方，侧排时在数字键旁；沿用工具槽宽高，避免挤动棋盘。
    Stack({ alignContent: Alignment.Center }) {
      AuxButtonGrid({
        onUndo: () => this.onUndo(),
        onRedo: () => this.onRedo(),
        onErase: () => this.onErase(),
        onHint: () => this.onHint(),
        onSettings: () => this.onSettings(),
        onAutoNotes: () => this.onAutoNotes(),
        undoDisabled: this.undoDisabled,
        redoDisabled: this.redoDisabled,
        eraseDisabled: this.eraseDisabled,
        hintDisabled: this.hintDisabled,
        hintLoading: this.hintLoading,
        autoNotesDisabled: this.autoNotesDisabled,
        autoNotesVisible: this.autoNotesVisible,
        gridHeight: this.gridHeight,
        horizontal: this.auxButtonsOnTop,
        compactTools: this.compactKeypad,
        rowHeight: 48,
      })
        .opacity(this.isGestureHintVisible() ? 0 : 1)
        .enabled(!this.isGestureHintVisible())
        .accessibilityLevel(this.isGestureHintVisible() ? 'no-hide-descendants' : 'auto')
      if (this.isGestureHintVisible()) {
        GestureModeIndicator({ currentDirection: this.gestureHintDirection })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width(this.auxButtonsOnTop ? '100%' : (this.compactKeypad ? 92 : this.gridHeight * 2 / 3))
    .height(this.auxButtonsOnTop ? (this.compactKeypad ? 100 : 48) : this.gridHeight)
    .clip(true)
  }

  @Builder
  private buildNumberPad() {
    GestureNumberPad({
      columns: this.keypadColumns,
      rows: this.keypadRows,
      edgeAligned: this.compactKeypad,
      keyFontSize: this.keyFontSize,
      remainingCounts: this.remainingCounts,
      onGesture: (digit: number, direction: GestureDirection) => {
        this.onGesture(digit, direction)
      },
      onGestureDirectionChange: (direction: GestureDirection | null) => {
        this.gestureHintDirection = direction
        this.onGestureDirectionChange(direction)
      },
      onHeightChange: (height: number) => {
        this.onHeightChange(height)
      },
    })
  }

  build() {
    if (this.auxButtonsOnTop) {
      if (this.compactKeypad) {
        // 极窄窗口保留48vp数字键；横向滚动使整组工具和数字仍可到达。
        Scroll() {
          Column({ space: 6 }) {
            this.buildAuxButtons()
            Column() {
              this.buildNumberPad()
            }
            .width(this.stackedKeypadWidth)
            .height(this.stackedKeypadWidth)
          }
          .width(this.stackedKeypadWidth)
          .height(this.gridHeight)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Auto)
        .align(Alignment.Center)
      } else {
        // 横屏工具位于数字键上方，左右手使用相同的横排。
        Column({ space: 6 }) {
          this.buildAuxButtons()
          Column() {
            this.buildNumberPad()
          }
          .width(this.stackedKeypadWidth)
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)
      }
    } else {
      // 使用 direction 切换左右手布局，避免 if/else 触发 ArkUI 默认滑入过渡效果
      Column() {
        Row({ space: 8 }) {
          this.buildAuxButtons()
          if (this.compactKeypad) {
            Column() {
              this.buildNumberPad()
            }
            .width(this.stackedKeypadWidth)
            .height(this.gridHeight)
          } else {
            this.buildNumberPad()
          }
        }
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .width(this.compactKeypad ? this.stackedKeypadWidth + 100 : '100%')
        .direction(this.isLeftHand ? Direction.Rtl : Direction.Ltr)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
  }
}
