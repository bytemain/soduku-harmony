/**
 * GameMainContent.ets — 游戏页主内容区
 */
import { Difficulty, GestureDirection, Sizes } from '../constants/GameConstants'
import { ArrayWrapper, SudokuBoard } from './SudokuBoard'
import { TopBar } from './TopBar'
import { MultiSelectBanner } from './MultiSelectBanner'
import { GestureModeIndicator } from './GestureModeIndicator'
import { GameActionPanel } from './GameActionPanel'

@Component
export struct GameMainContent {
  @Prop difficulty: Difficulty = Difficulty.EASY
  @Prop formattedTime: string = '00:00'
  @Prop errorCount: number = 0
  @Prop isPaused: boolean = false
  @ObjectLink cells: ArrayWrapper
  @Prop selectedValue: number = 0
  @Prop hintFocusIndex: number = -1
  @Prop showCoordinates: boolean = false
  @Prop boardScale: number = 1
  @Prop completionScale: number = 1
  @Prop boardOpacity: number = 1
  @Prop isMultiSelectMode: boolean = false
  @Prop multiSelectHint: string = ''
  @Prop multiSelectCount: number = 0
  @Prop currentDirection: GestureDirection | null = null
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

  onBlankAreaClick: () => void = () => {}
  onPause: () => void = () => {}
  onCellClick: (index: number) => void = () => {}
  onMouseDragSelect: (index: number, action: string) => void = () => {}
  onTouchDragSelect: (index: number, action: string) => void = () => {}
  onKeyboardInput: (keyCode: number) => void = () => {}
  onExitMultiSelect: () => void = () => {}
  onUndo: () => void = () => {}
  onRedo: () => void = () => {}
  onErase: () => void = () => {}
  onHint: () => void = () => {}
  onSettings: () => void = () => {}
  onAutoNotes: () => void = () => {}
  onGesture: (digit: number, direction: GestureDirection) => void = () => {}
  onGestureDirectionChange: (direction: GestureDirection | null) => void = () => {}
  onHeightChange: (height: number) => void = () => {}

  build() {
    Column() {
      TopBar({
        difficulty: this.difficulty,
        formattedTime: this.formattedTime,
        errorCount: this.errorCount,
        isPaused: this.isPaused,
        onPause: () => this.onPause(),
      })

      SudokuBoard({
        cells: this.cells,
        selectedValue: this.selectedValue,
        hintFocusIndex: this.hintFocusIndex,
        showCoordinates: this.showCoordinates,
        onCellClick: (index: number) => {
          this.onCellClick(index)
        },
        onMouseDragSelect: (index: number, action: string) => {
          this.onMouseDragSelect(index, action)
        },
        onTouchDragSelect: (index: number, action: string) => {
          this.onTouchDragSelect(index, action)
        },
        onKeyboardInput: (keyCode: number) => {
          this.onKeyboardInput(keyCode)
        },
      })
        .margin({ top: 12 })
        .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
        .scale({ x: this.boardScale * this.completionScale, y: this.boardScale * this.completionScale })
        .opacity(this.boardOpacity)

      if (this.isMultiSelectMode) {
        MultiSelectBanner({
          hintText: this.multiSelectHint,
          count: this.multiSelectCount,
          onClose: () => this.onExitMultiSelect(),
        })
          .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
      }

      GestureModeIndicator({
        currentDirection: this.currentDirection,
      })
        .margin({ top: 8 })

      GameActionPanel({
        isLeftHand: this.isLeftHand,
        remainingCounts: this.remainingCounts,
        undoDisabled: this.undoDisabled,
        redoDisabled: this.redoDisabled,
        eraseDisabled: this.eraseDisabled,
        hintDisabled: this.hintDisabled,
        hintLoading: this.hintLoading,
        autoNotesDisabled: this.autoNotesDisabled,
        autoNotesVisible: this.autoNotesVisible,
        gridHeight: this.gridHeight,
        onUndo: () => { this.onUndo() },
        onRedo: () => { this.onRedo() },
        onErase: () => { this.onErase() },
        onHint: () => { this.onHint() },
        onSettings: () => { this.onSettings() },
        onAutoNotes: () => { this.onAutoNotes() },
        onGesture: (digit: number, direction: GestureDirection) => {
          this.onGesture(digit, direction)
        },
        onGestureDirectionChange: (direction: GestureDirection | null) => {
          this.onGestureDirectionChange(direction)
        },
        onHeightChange: (height: number) => { this.onHeightChange(height) },
      })
      .width('100%')
      .layoutWeight(1)
      .margin({ top: 8 })
      .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.onBlankAreaClick()
    })
  }
}
