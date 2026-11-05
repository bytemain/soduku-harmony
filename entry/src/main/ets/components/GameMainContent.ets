/**
 * GameMainContent.ets — 游戏页主内容区
 */
import { BoardCellDecoration, createEmptyBoardDecorations } from '../models/BoardDecoration'
import { Difficulty, GestureDirection, GRID_SIZE, createInitialRemainingCounts, getThemeColors, ColorsConfig } from '../constants/GameConstants'
import { VariantType } from '../models/VariantConfig'
import { ArrayWrapper, SudokuBoard } from './SudokuBoard'
import { TopBar } from './TopBar'
import { MultiSelectBanner } from './MultiSelectBanner'
import { GameActionPanel } from './GameActionPanel'
import { computeGameLayout, GameLayoutPlan } from '../utils/AdaptiveLayout'

@Component
export struct GameMainContent {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false
  @Prop difficulty: Difficulty = Difficulty.EASY
  @Prop formattedTime: string = '00:00'
  @Prop errorCount: number = 0
  @Prop showErrors: boolean = true
  @Prop isPaused: boolean = false
  @ObjectLink cells: ArrayWrapper
  @Prop selectedValue: number = 0
  @Prop hintFocusIndex: number = -1
  @Prop showCoordinates: boolean = false
  @Prop boardDecorations: BoardCellDecoration[] = createEmptyBoardDecorations()
  @Prop currentVariantType: VariantType = VariantType.STANDARD
  @Prop boardScale: number = 1
  @Prop completionScale: number = 1
  @Prop boardOpacity: number = 1
  @Prop isMultiSelectMode: boolean = false
  @Prop multiSelectHint: string = ''
  @Prop multiSelectCount: number = 0
  @Prop currentDirection: GestureDirection | null = null
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
  @Prop auxButtonsOnTop: boolean = false

  onBlankAreaClick: () => void = () => {}
  onPause: () => void = () => {}
  onJournal: () => void = () => {}
  @Prop practiceMode: boolean = false
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

  @State private bodyWidth: number = 0
  @State private bodyHeight: number = 0
  @State private boardDragSelectionActive: boolean = false

  private getLayout(): GameLayoutPlan {
    return computeGameLayout(this.bodyWidth, this.bodyHeight, this.showCoordinates,
      this.isMultiSelectMode, this.auxButtonsOnTop, GRID_SIZE)
  }

  private getPalette(): ColorsConfig { return getThemeColors(this.isDarkMode) }

  private getBoardDisplayScale(): number {
    if (this.getLayout().wide) return this.boardScale * this.completionScale
    // 竖屏释放外扩预留；完成动效只在0.97至1之间收放，始终不超出棋盘框。
    return Math.min(1, this.boardScale) * Math.min(1, 0.4 + 0.6 * this.completionScale)
  }

  @Builder
  private BoardContent() {
    Column() {
      SudokuBoard({
        showErrors: this.showErrors,
        cells: this.cells,
        selectedValue: this.selectedValue,
        hintFocusIndex: this.hintFocusIndex,
        showCoordinates: this.showCoordinates,
        boardDecorations: this.boardDecorations,
        currentVariantType: this.currentVariantType,
        onCellClick: (index: number) => {
          this.onCellClick(index)
        },
        onMouseDragSelect: (index: number, action: string) => {
          this.onMouseDragSelect(index, action)
        },
        onTouchDragSelect: (index: number, action: string) => {
          this.onTouchDragSelect(index, action)
        },
        onDragSelectionActiveChange: (active: boolean) => {
          this.boardDragSelectionActive = active
        },
        onKeyboardInput: (keyCode: number) => {
          this.onKeyboardInput(keyCode)
        },
      })
        .width(this.getLayout().boardWidth)
        .scale({ x: this.getBoardDisplayScale(), y: this.getBoardDisplayScale() })
        .opacity(this.boardOpacity)

    }
    .width(this.getLayout().boardFrameWidth)
    .height(this.getLayout().boardFrameHeight)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ControlsContent() {
    Column() {
      if (this.isMultiSelectMode) {
        MultiSelectBanner({
          hintText: this.multiSelectHint,
          count: this.multiSelectCount,
          onClose: () => this.onExitMultiSelect(),
        })
          .margin({ bottom: 4 })
      }

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
        gridHeight: this.getLayout().actionHeight,
        auxButtonsOnTop: this.getLayout().toolsHorizontal,
        keypadColumns: this.getLayout().keypadColumns,
        keypadRows: this.getLayout().keypadRows,
        stackedKeypadWidth: this.getLayout().stackedKeypadWidth,
        compactKeypad: this.getLayout().compactKeypad,
        keyFontSize: this.getLayout().keyFontSize,
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
      .height(this.getLayout().actionHeight)
      .opacity(this.boardOpacity)
      .scale({ x: this.boardScale, y: this.boardScale })
    }
    .width(this.getLayout().controlWidth)
  }

  build() {
    Column() {
      TopBar({
        difficulty: this.difficulty,
        formattedTime: this.formattedTime,
        errorCount: this.errorCount,
        showErrors: this.showErrors,
        isPaused: this.isPaused,
        onPause: () => this.onPause(),
        onJournal: () => this.onJournal(),
      })
      .width(this.bodyWidth > 0 ? this.getLayout().contentWidth : '100%')

      if (this.practiceMode) {
        Text($r('app.string.journal_practice_banner'))
          .fontSize(12)
          .height(24)
          .fontColor(this.getPalette().subtitleText)
      }

      Stack() {
        if (this.getLayout().measured) {
          if (this.getLayout().wide) {
            Row({ space: this.getLayout().gap }) {
              Column() {
                this.BoardContent()
              }
              .width(this.getLayout().contentWidth - this.getLayout().controlWidth - this.getLayout().gap)
              .height('100%')
              .justifyContent(FlexAlign.Center)

              Scroll() {
                Column() {
                  this.ControlsContent()
                }
                .width(this.getLayout().controlWidth)
                // 留足可视高度时让操作区贴近底部；短窗按内容自然增高并保留滚动。
                .constraintSize({ minHeight: this.bodyHeight })
                .justifyContent(FlexAlign.End)
              }
              .width(this.getLayout().controlWidth)
              .height('100%')
              .scrollBar(BarState.Auto)
              .align(Alignment.Top)
            }
            .width(this.getLayout().contentWidth)
            .height('100%')
            .alignItems(VerticalAlign.Top)
          } else {
            Scroll() {
              Column({ space: this.getLayout().gap }) {
                this.BoardContent()
                this.ControlsContent()
              }
              .width(this.getLayout().contentWidth)
              .constraintSize({ minHeight: this.bodyHeight })
              .justifyContent(FlexAlign.SpaceBetween)
              .padding({ top: 2, bottom: 2 })
            }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Auto)
            .align(Alignment.Top)
            .scrollable(this.boardDragSelectionActive ? ScrollDirection.None : ScrollDirection.Vertical)
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const width = Number(newArea.width)
        const height = Number(newArea.height)
        if (Math.abs(width - this.bodyWidth) > 0.5) this.bodyWidth = width
        if (Math.abs(height - this.bodyHeight) > 0.5) this.bodyHeight = height
      })
    }
    .width('100%')
    .height('100%')
    .onClick(() => { this.onBlankAreaClick() })
  }
}
