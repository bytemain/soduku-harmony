/**
 * GamePage.ets — 游戏页面
 *
 * 组装所有组件：TopBar + SudokuBoard + GestureModeIndicator + 操作区。
 * 管理游戏核心逻辑：选中、填数、笔记、冲突检测、完成判定。
 *
 * 参考：Doc 05 §二, Doc 03 任务 1.17/1.19
 */
import { router } from '@kit.ArkUI'
import { CellData, CellFlags, setFlag, clearFlag, hasFlag,
  getNoteState, setNoteState, NoteState, createBoardFromArray } from '../models/CellData'
import { GameState } from '../models/GameState'
import { Colors, Sizes, Difficulty, GestureDirection,
  getDifficultyConfig, GRID_SIZE, TOTAL_CELLS, DIGITS } from '../constants/GameConstants'
import { generatePuzzle, GeneratedPuzzle } from '../utils/SudokuGenerator'
import { validateAllCells, updateHighlights, isGameCompleted } from '../utils/SudokuValidator'
import { SudokuBoard, ArrayWrapper } from '../components/SudokuBoard'
import { TopBar } from '../components/TopBar'
import { GestureNumberPad } from '../components/GestureNumberPad'
import { GestureModeIndicator } from '../components/GestureModeIndicator'
import { AuxButtonGrid } from '../components/AuxButtonGrid'

interface GamePageParams {
  difficulty?: Difficulty
}

@Entry
@Component
struct GamePage {
  @State private gameState: GameState = new GameState()
  @State private cellsWrapper: ArrayWrapper = new ArrayWrapper([])
  @State private gestureDirection: GestureDirection | null = null
  @State private remainingCounts: number[] = [0, 9, 9, 9, 9, 9, 9, 9, 9, 9]
  private timerId: number = -1

  aboutToAppear(): void {
    // 从路由参数获取难度
    const params = router.getParams() as GamePageParams | null
    const difficulty = params?.difficulty ?? Difficulty.EASY

    // 生成新题
    const puzzle: GeneratedPuzzle = generatePuzzle(difficulty)
    this.gameState.initGame(puzzle.puzzle, puzzle.solution, difficulty)
    this.cellsWrapper = new ArrayWrapper(this.gameState.cells)

    // 初始验证 + 高亮
    validateAllCells(this.gameState.cells)
    this.updateRemainingCounts()

    // 启动计时器
    this.timerId = setInterval(() => {
      this.gameState.tick()
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  // ================================================================
  // 核心交互逻辑
  // ================================================================

  /**
   * 点击棋盘格子
   */
  private onCellClick(index: number): void {
    this.gameState.selectCell(index)
    updateHighlights(this.gameState.cells, this.gameState.selectedIndex)
  }

  /**
   * 手势键盘回调
   */
  private onGesture(digit: number, direction: GestureDirection): void {
    const cell = this.gameState.selectedCell
    if (cell === null) return
    if (cell.isGiven) return
    if (this.gameState.isCompleted) return

    switch (direction) {
      case GestureDirection.TAP:
        this.handleFillDigit(cell, digit)
        break
      case GestureDirection.UP:
        this.handleToggleNote(cell, digit)
        break
      case GestureDirection.RIGHT:
        this.handleToggleEliminated(cell, digit)
        break
      case GestureDirection.LEFT:
        this.handleEraseNote(cell, digit)
        break
      default:
        break
    }

    // 操作后更新冲突 + 高亮 + 剩余计数
    validateAllCells(this.gameState.cells)
    updateHighlights(this.gameState.cells, this.gameState.selectedIndex)
    this.updateRemainingCounts()

    // 检查是否完成
    if (isGameCompleted(this.gameState.cells)) {
      this.gameState.isCompleted = true
      if (this.timerId !== -1) {
        clearInterval(this.timerId)
        this.timerId = -1
      }
      this.showCompletionDialog()
    }
  }

  /**
   * 填数（点击）— Doc 05 §4.1
   */
  private handleFillDigit(cell: CellData, digit: number): void {
    if (cell.value === digit) {
      // toggle：再次点击同一数字 → 擦除
      cell.value = 0
    } else {
      cell.fillValue(digit)
      // 检查是否与答案不符 → 计数错误
      const idx = cell.index
      if (this.gameState.solution.length > 0 && this.gameState.solution[idx] !== digit) {
        this.gameState.errorCount++
      }
    }
  }

  /**
   * 笔记（上滑）— Doc 05 §4.2
   */
  private handleToggleNote(cell: CellData, digit: number): void {
    if (cell.value !== 0) {
      cell.value = 0 // 先清空数字，转为笔记模式
    }
    const current = getNoteState(cell.notes, digit)
    switch (current) {
      case NoteState.EMPTY:
        cell.notes = setNoteState(cell.notes, digit, NoteState.ACTIVE)
        break
      case NoteState.ACTIVE:
        cell.notes = setNoteState(cell.notes, digit, NoteState.EMPTY)
        break
      case NoteState.ELIMINATED:
        cell.notes = setNoteState(cell.notes, digit, NoteState.ACTIVE)
        break
    }
  }

  /**
   * 删除线（右滑）— Doc 05 §4.3
   */
  private handleToggleEliminated(cell: CellData, digit: number): void {
    const current = getNoteState(cell.notes, digit)
    switch (current) {
      case NoteState.EMPTY:
        cell.notes = setNoteState(cell.notes, digit, NoteState.ELIMINATED)
        break
      case NoteState.ACTIVE:
        cell.notes = setNoteState(cell.notes, digit, NoteState.ELIMINATED)
        break
      case NoteState.ELIMINATED:
        cell.notes = setNoteState(cell.notes, digit, NoteState.EMPTY)
        break
    }
  }

  /**
   * 擦除笔记（左滑）— Doc 05 §4.4
   */
  private handleEraseNote(cell: CellData, digit: number): void {
    cell.notes = setNoteState(cell.notes, digit, NoteState.EMPTY)
  }

  /**
   * 擦除按钮 — Doc 05 §4.5
   */
  private onErase(): void {
    const cell = this.gameState.selectedCell
    if (cell === null || cell.isGiven) return
    cell.clear()
    validateAllCells(this.gameState.cells)
    updateHighlights(this.gameState.cells, this.gameState.selectedIndex)
    this.updateRemainingCounts()
  }

  /**
   * 更新各数字剩余计数
   */
  private updateRemainingCounts(): void {
    const counts: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    for (const cell of this.gameState.cells) {
      if (cell.value >= 1 && cell.value <= 9) {
        counts[cell.value]++
      }
    }
    const remaining: number[] = [0, 9, 9, 9, 9, 9, 9, 9, 9, 9]
    for (let d = 1; d <= 9; d++) {
      remaining[d] = 9 - counts[d]
    }
    this.remainingCounts = remaining
  }

  /**
   * 完成弹窗
   */
  private showCompletionDialog(): void {
    AlertDialog.show({
      title: '🎉 恭喜！',
      message: `用时 ${this.gameState.formattedTime}，错误 ${this.gameState.errorCount} 次`,
      confirm: {
        value: '返回主页',
        action: () => {
          router.back()
        },
      },
    })
  }

  // ================================================================
  // UI 布局
  // ================================================================

  build() {
    Column() {
      // ① 顶部信息栏
      TopBar({
        difficulty: this.gameState.difficulty,
        formattedTime: this.gameState.formattedTime,
        errorCount: this.gameState.errorCount,
      })

      // ② 棋盘
      SudokuBoard({
        cells: this.cellsWrapper,
        selectedValue: this.gameState.selectedCell?.value ?? 0,
        onCellClick: (index: number) => {
          this.onCellClick(index)
        },
      })
        .margin({ top: 12 })

      // 手势提示条
      GestureModeIndicator({
        currentDirection: this.gestureDirection,
      })
        .margin({ top: 8 })

      // ③ 操作区
      Row() {
        // 左：辅助按钮
        AuxButtonGrid({
          onUndo: () => {}, // TODO: Phase 2
          onRedo: () => {}, // TODO: Phase 2
          onErase: () => { this.onErase() },
          onHint: () => {}, // TODO: Phase 2
          onSettings: () => {},
          undoDisabled: true,
          redoDisabled: true,
          eraseDisabled: this.gameState.selectedCell === null ||
            this.gameState.selectedCell!.isGiven ||
            (this.gameState.selectedCell!.isEmpty && this.gameState.selectedCell!.notes === 0),
        })

        // 右：手势键盘
        GestureNumberPad({
          remainingCounts: this.remainingCounts,
          onGesture: (digit: number, direction: GestureDirection) => {
            this.onGesture(digit, direction)
          },
          onGestureDirectionChange: (direction: GestureDirection | null) => {
            this.gestureDirection = direction
          },
        })
          .layoutWeight(1)
          .height(180)
      }
      .width('100%')
      .height(180)
      .margin({ top: 12 })
      .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.pageBg)
    .padding({ top: 12 })
  }
}
