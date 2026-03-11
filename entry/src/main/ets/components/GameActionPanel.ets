/**
 * GameActionPanel.ets — 游戏页底部操作区
 */
import { GestureDirection } from '../constants/GameConstants'
import { AuxButtonGrid } from './AuxButtonGrid'
import { GestureNumberPad } from './GestureNumberPad'

@Component
export struct GameActionPanel {
  @Prop isLeftHand: boolean = false
  @Prop remainingCounts: number[] = [0, 9, 9, 9, 9, 9, 9, 9, 9, 9]
  @Prop undoDisabled: boolean = true
  @Prop redoDisabled: boolean = true
  @Prop eraseDisabled: boolean = true
  @Prop hintDisabled: boolean = false
  @Prop hintLoading: boolean = false
  @Prop autoNotesDisabled: boolean = false
  @Prop autoNotesVisible: boolean = false
  @Prop gridHeight: number = 0

  onUndo: () => void = () => {}
  onRedo: () => void = () => {}
  onErase: () => void = () => {}
  onHint: () => void = () => {}
  onSettings: () => void = () => {}
  onAutoNotes: () => void = () => {}
  onGesture: (digit: number, direction: GestureDirection) => void = () => {}
  onGestureDirectionChange: (direction: GestureDirection | null) => void = () => {}
  onHeightChange: (height: number) => void = () => {}

  @Builder
  private buildAuxButtons() {
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
    })
  }

  @Builder
  private buildNumberPad() {
    GestureNumberPad({
      remainingCounts: this.remainingCounts,
      onGesture: (digit: number, direction: GestureDirection) => {
        this.onGesture(digit, direction)
      },
      onGestureDirectionChange: (direction: GestureDirection | null) => {
        this.onGestureDirectionChange(direction)
      },
      onHeightChange: (height: number) => {
        this.onHeightChange(height)
      },
    })
  }

  build() {
    Row({ space: 8 }) {
      if (this.isLeftHand) {
        this.buildNumberPad()
        this.buildAuxButtons()
      } else {
        this.buildAuxButtons()
        this.buildNumberPad()
      }
    }
    .width('100%')
  }
}
