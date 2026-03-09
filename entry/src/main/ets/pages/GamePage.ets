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
import { PEERS } from '../utils/Topology'
import { SudokuBoard, ArrayWrapper } from '../components/SudokuBoard'
import { TopBar } from '../components/TopBar'
import { GestureNumberPad } from '../components/GestureNumberPad'
import { GestureModeIndicator } from '../components/GestureModeIndicator'
import { AuxButtonGrid } from '../components/AuxButtonGrid'
import { saveGame, loadGame, clearSave, GameSaveData, CellSerialized } from '../utils/GameStorage'
import { recordGameStarted, recordGameWon } from '../utils/StatsStorage'

interface GamePageParams {
  difficulty?: Difficulty
}

@Entry
@Component
struct GamePage {
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
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
  private gameStartRecorded: boolean = false

  aboutToAppear(): void {
    // 从路由参数获取难度
    const params = router.getParams() as GamePageParams | null
    const difficulty = params?.difficulty ?? Difficulty.EASY

    // 尝试恢复存档
    const saved = loadGame(getContext(this))
    if (saved && saved.cells.length === 81) {
      this.restoreFromSave(saved)
      this.gameStartRecorded = true  // 恢复的游戏已经计数过了
    } else {
      // 生成新题
      const puzzle: GeneratedPuzzle = generatePuzzle(difficulty)
      this.gameState.initGame(puzzle.puzzle, puzzle.solution, difficulty)
      this.cellsWrapper = new ArrayWrapper(this.gameState.cells)
      // 记录游戏开始
      recordGameStarted(getContext(this), difficulty)
      this.gameStartRecorded = true
    }

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
    // 保存游戏状态（已完成的不保存）
    if (!this.gameState.isCompleted) {
      this.saveCurrentGame()
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

  /**
   * 从存档恢复游戏
   */
  private restoreFromSave(saved: GameSaveData): void {
    // 恢复 cells
    const cells = this.gameState.cells
    for (let i = 0; i < 81; i++) {
      const s = saved.cells[i]
      cells[i].row = s.row
      cells[i].col = s.col
      cells[i].value = s.value
      cells[i].flags = s.flags
      cells[i].notes = s.notes
    }
    // 恢复 solution
    this.gameState.solution = saved.solution
    // 恢复其他状态
    this.gameState.difficulty = saved.difficulty as Difficulty
    this.gameState.elapsedSeconds = saved.elapsedSeconds
    this.gameState.errorCount = saved.errorCount
    this.gameState.selectedIndex = saved.selectedIndex
    this.gameState.isCompleted = false
    this.gameState.isPaused = false

    this.cellsWrapper = new ArrayWrapper(this.gameState.cells)

    // 恢复历史
    this.history.undoStack = saved.undoStack ?? []
    this.history.redoStack = saved.redoStack ?? []
  }

  /**
   * 保存当前游戏状态
   */
  private saveCurrentGame(): void {
    const data = new GameSaveData()
    const serializedCells: CellSerialized[] = []
    for (const c of this.gameState.cells) {
      serializedCells.push(new CellSerialized(c.row, c.col, c.value, c.flags, c.notes))
    }
    data.cells = serializedCells
    data.solution = this.gameState.solution
    data.difficulty = this.gameState.difficulty
    data.elapsedSeconds = this.gameState.elapsedSeconds
    data.errorCount = this.gameState.errorCount
    data.selectedIndex = this.gameState.selectedIndex
    data.undoStack = this.history.undoStack
    data.redoStack = this.history.redoStack
    data.timestamp = Date.now()
    saveGame(getContext(this), data)
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
    const snapshot = new CellSnapshot(
      cell.index, cell.value, cell.value,
      cell.notes, cell.notes, cell.flags, cell.flags
    )

    let filledIndex: number | undefined = undefined

    switch (direction) {
      case GestureDirection.TAP:
        this.handleFillDigit(cell, digit)
        // 如果填入了数字（非擦除），记录索引用于自动清除 peers 笔记
        if (cell.value !== 0) {
          filledIndex = cell.index
        }
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

    this.afterAction(filledIndex)
  }

  /**
   * 每次操作后的统一处理
   * @param filledIndex 如果是填数操作，传入填数的格子索引，用于自动清除 peers 笔记
   */
  private afterAction(filledIndex?: number): void {

    // 自动清除 peers 的候选数字（仅在填数时）
    this.autoClearPeerNotes(filledIndex)

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
      clearSave(getContext(this))
      // 记录胜利统计
      recordGameWon(
        getContext(this),
        this.gameState.difficulty,
        this.gameState.elapsedSeconds,
        this.gameState.errorCount
      )
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
   * 自动清除 peers 中的候选数字。
   * 仅当指定格子填入数字时，清除其 peers 的对应笔记。
   */
  private autoClearPeerNotes(filledIndex?: number): void {
    if (filledIndex === undefined) return
    const cells = this.gameState.cells
    const val = cells[filledIndex].value
    if (val === 0) return
    for (const peerIdx of PEERS[filledIndex]) {
      const peer = cells[peerIdx]
      if (peer.value !== 0) continue
      const noteState = getNoteState(peer.notes, val)
      if (noteState === NoteState.ACTIVE || noteState === NoteState.ELIMINATED) {
        peer.notes = setNoteState(peer.notes, val, NoteState.EMPTY)
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
    const snapshot = new CellSnapshot(
      cell.index, cell.value, 0,
      cell.notes, 0, cell.flags, cell.flags
    )

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
    const snapshot = new CellSnapshot(
      cell.index, cell.value, correctValue,
      cell.notes, 0, cell.flags, cell.flags
    )

    cell.fillValue(correctValue)

    snapshot.newFlags = cell.flags
    this.history.push(snapshot)

    this.afterAction(cell.index)
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
    const ctx = getContext(this)
    const congrats = ctx.resourceManager.getStringByNameSync('dialog_congrats_title')
    const timeLabel = ctx.resourceManager.getStringByNameSync('dialog_congrats_time')
    const errLabel = ctx.resourceManager.getStringByNameSync('dialog_congrats_errors')
    const unit = ctx.resourceManager.getStringByNameSync('dialog_congrats_unit')
    const backHome = ctx.resourceManager.getStringByNameSync('dialog_back_home')
    const msg = `${timeLabel}: ${this.gameState.formattedTime}, ${errLabel}: ${this.gameState.errorCount}${unit ? ' ' + unit : ''}`
    AlertDialog.show({
      title: congrats,
      message: msg,
      confirm: {
        value: backHome,
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
        .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })

      // 手势提示条
      GestureModeIndicator({
        currentDirection: this.gestureDirection,
      })
        .margin({ top: 8 })

      // ③ 操作区
      Row({ space: 8 }) {
        // 左：辅助按钮（窄列）
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

        // 右：手势键盘（正方形）
        GestureNumberPad({
          remainingCounts: this.remainingCounts,
          onGesture: (digit: number, direction: GestureDirection) => {
            this.onGesture(digit, direction)
          },
          onGestureDirectionChange: (direction: GestureDirection | null) => {
            this.gestureDirection = direction
          },
        })
      }
      .width('100%')
      .layoutWeight(1)
      .margin({ top: 8 })
      .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.pageBg)
    .padding({ top: this.topRectHeight + 12, bottom: this.bottomRectHeight + 12 })
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
