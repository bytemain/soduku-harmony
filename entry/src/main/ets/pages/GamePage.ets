/**
 * GamePage.ets — 游戏页面
 *
 * 组装所有组件：TopBar + SudokuBoard + GestureModeIndicator + 操作区。
 * 管理游戏核心逻辑：选中、填数、笔记、冲突检测、完成判定。
 *
 * 参考：Doc 05 §二, Doc 03 任务 1.17/1.19
 */
import { router } from '@kit.ArkUI'
import { CellData,
  getNoteState, setNoteState, NoteState } from '../models/CellData'
import { GameState } from '../models/GameState'
import { GameHistory, CellSnapshot } from '../models/GameHistory'
import { Colors, Sizes, Difficulty, GestureDirection } from '../constants/GameConstants'
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
  @State private displayTime: string = '00:00'
  @State private displayErrors: number = 0
  @State private canUndo: boolean = false
  @State private canRedo: boolean = false
  private timerId: number = -1
  private history: GameHistory = new GameHistory()

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
    this.syncDisplayState()

    // 启动计时器
    this.timerId = setInterval(() => {
      this.gameState.tick()
      this.displayTime = this.gameState.formattedTime
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /**
   * 同步显示状态（从 gameState 到 @State 变量）
   */
  private syncDisplayState(): void {
    this.displayTime = this.gameState.formattedTime
    this.displayErrors = this.gameState.errorCount
    this.canUndo = this.history.canUndo
    this.canRedo = this.history.canRedo
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

    // 记录操作前状态
    const snapshot: CellSnapshot = {
      index: cell.index,
      oldValue: cell.value,
      newValue: cell.value,
      oldNotes: cell.notes,
      newNotes: cell.notes,
      oldFlags: cell.flags,
      newFlags: cell.flags,
    }

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

    // 记录操作后状态
    snapshot.newValue = cell.value
    snapshot.newNotes = cell.notes
    snapshot.newFlags = cell.flags

    // 只有真正发生变化时才入栈
    if (snapshot.oldValue !== snapshot.newValue ||
        snapshot.oldNotes !== snapshot.newNotes) {
      this.history.push(snapshot)
    }

    this.afterAction()
  }

  /**
   * 每次操作后的统一处理
   */
  private afterAction(): void {

    // 操作后更新冲突 + 高亮 + 剩余计数
    validateAllCells(this.gameState.cells)
    updateHighlights(this.gameState.cells, this.gameState.selectedIndex)
    this.updateRemainingCounts()
    this.syncDisplayState()

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

    // 记录到历史
    const snapshot: CellSnapshot = {
      index: cell.index,
      oldValue: cell.value,
      newValue: 0,
      oldNotes: cell.notes,
      newNotes: 0,
      oldFlags: cell.flags,
      newFlags: cell.flags,
    }

    cell.clear()

    snapshot.newFlags = cell.flags
    if (snapshot.oldValue !== 0 || snapshot.oldNotes !== 0) {
      this.history.push(snapshot)
    }

    this.afterAction()
  }

  /**
   * 撤销
   */
  private onUndo(): void {
    const snap = this.history.popUndo()
    if (snap === null) return

    const cell = this.gameState.cells[snap.index]
    cell.value = snap.oldValue
    cell.notes = snap.oldNotes

    this.gameState.selectCell(snap.index)
    if (this.gameState.selectedIndex !== snap.index) {
      this.gameState.selectCell(snap.index)
    }

    this.afterAction()
  }

  /**
   * 前进（重做）
   */
  private onRedo(): void {
    const snap = this.history.popRedo()
    if (snap === null) return

    const cell = this.gameState.cells[snap.index]
    cell.value = snap.newValue
    cell.notes = snap.newNotes

    this.gameState.selectCell(snap.index)
    if (this.gameState.selectedIndex !== snap.index) {
      this.gameState.selectCell(snap.index)
    }

    this.afterAction()
  }

  /**
   * 提示 — 填入选中格的正确答案
   */
  private onHint(): void {
    const cell = this.gameState.selectedCell
    if (cell === null || cell.isGiven || this.gameState.isCompleted) return
    if (this.gameState.solution.length === 0) return

    const correctValue = this.gameState.solution[cell.index]
    if (correctValue === 0) return

    // 已经填对了，无需提示
    if (cell.value === correctValue) return

    // 记录到历史
    const snapshot: CellSnapshot = {
      index: cell.index,
      oldValue: cell.value,
      newValue: correctValue,
      oldNotes: cell.notes,
      newNotes: 0,
      oldFlags: cell.flags,
      newFlags: cell.flags,
    }

    cell.fillValue(correctValue)

    snapshot.newFlags = cell.flags
    this.history.push(snapshot)

    this.afterAction()
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
        formattedTime: this.displayTime,
        errorCount: this.displayErrors,
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

      // ③ 操作区 — 占满剩余空间
      Row() {
        // 左：辅助按钮
        AuxButtonGrid({
          onUndo: () => { this.onUndo() },
          onRedo: () => { this.onRedo() },
          onErase: () => { this.onErase() },
          onHint: () => { this.onHint() },
          onSettings: () => {},
          undoDisabled: !this.canUndo,
          redoDisabled: !this.canRedo,
          eraseDisabled: this.gameState.selectedCell === null ||
            this.gameState.selectedCell!.isGiven ||
            (this.gameState.selectedCell!.isEmpty && this.gameState.selectedCell!.notes === 0),
          hintDisabled: this.gameState.selectedCell === null ||
            this.gameState.selectedCell!.isGiven ||
            this.gameState.isCompleted,
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
      }
      .width('100%')
      .layoutWeight(1)
      .margin({ top: 12 })
      .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.pageBg)
    .padding({ top: 12, bottom: 12 })
  }
}
