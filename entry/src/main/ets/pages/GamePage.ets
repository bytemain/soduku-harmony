/**
 * GamePage.ets — 游戏页面
 *
 * 组装所有组件：TopBar + SudokuBoard + GestureModeIndicator + 操作区。
 * 管理游戏核心逻辑：选中、填数、笔记、冲突检测、完成判定。
 *
 * 参考：Doc 05 §二, Doc 03 任务 1.17/1.19
 */
import { router, promptAction } from '@kit.ArkUI'
import { KeyCode } from '@kit.InputKit'
import { pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { worker, MessageEvents, ErrorEvent } from '@kit.ArkTS'
import { CellData, CellFlags, setFlag, clearFlag,
  getNoteState, setNoteState, NoteState } from '../models/CellData'
import { GameState } from '../models/GameState'
import { GameHistory, CellSnapshot } from '../models/GameHistory'
import { Colors, Sizes, Difficulty, GestureDirection, getDifficultyConfig } from '../constants/GameConstants'
import { decodeSeedId, Symmetry, encodeSeedId } from '../utils/SudokuGenerator'
import { validateAllCells, updateHighlights, isGameCompleted } from '../utils/SudokuValidator'
import { PEERS } from '../utils/Topology'
import { SudokuBoard, ArrayWrapper } from '../components/SudokuBoard'
import { TopBar } from '../components/TopBar'
import { GestureNumberPad } from '../components/GestureNumberPad'
import { GestureModeIndicator } from '../components/GestureModeIndicator'
import { AuxButtonGrid } from '../components/AuxButtonGrid'
import { SettingsPanel } from '../components/SettingsPanel'
import { GestureGuideOverlay } from '../components/GestureGuideOverlay'
import { getNextHint, getTechniqueNameKey, SolveStep } from '../utils/LogicSolver'
import { formatStr } from '../utils/I18nHelper'
import { solve } from '../utils/SudokuSolver'
import { parse81String, exportTo81String } from '../utils/SudokuFormat'
import { saveGame, loadGame, clearSave, GameSaveData, CellSerialized } from '../utils/GameStorage'
import { recordGameStarted, recordGameWon } from '../utils/StatsStorage'
import { addGameRecord, GameRecord } from '../utils/HistoryStorage'
import { hilog } from '@kit.PerformanceAnalysisKit'

interface GamePageParams {
  difficulty?: Difficulty
  symmetry?: string
  seedId?: string
  /** 导入的 81 字符串谜题 */
  importedPuzzle?: string
  /** 导入谜题的难度标签（来自元数据或自动评估） */
  importedDifficulty?: Difficulty
}

@Entry
@Component
struct GamePage {
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  @StorageProp('isLeftHand') isLeftHand: boolean = false
  @StorageProp('validateInput') validateInput: boolean = true
  @State private gameState: GameState = new GameState()
  @State private cellsWrapper: ArrayWrapper = new ArrayWrapper([])
  @State private gestureDirection: GestureDirection | null = null
  @State private remainingCounts: number[] = [0, 9, 9, 9, 9, 9, 9, 9, 9, 9]
  @State private displayTime: string = '00:00'
  @State private displayErrors: number = 0
  @State private canUndo: boolean = false
  @State private canRedo: boolean = false
  @State private showSettings: boolean = false
  // Coach sheet removed: ArkUI不支持同一组件绑多个bindSheet
  @State private showPauseOverlay: boolean = false
  @State private showGestureGuide: boolean = false
  @StorageProp('gestureGuideShown') gestureGuideShown: boolean = false
  @State private showCoordinates: boolean = false
  @State private isHintLoading: boolean = false
  @State private hintFocusIndex: number = -1
  @State private boardScale: number = 0.92
  @State private boardOpacity: number = 0
  @State private completionScale: number = 1.0
  @State private numPadHeight: number = 0
  @State private isLoading: boolean = true
  @State private isMultiSelectMode: boolean = false
  @State private multiSelectCount: number = 0
  private multiSelectIndices: Set<number> = new Set()
  /** 鼠标是否正在拖拽选择 */
  private isMouseDragging: boolean = false
  /** 鼠标按下的起始格子索引 */
  private mouseDragStartIndex: number = -1
  private timerId: number = -1
  private history: GameHistory = new GameHistory()
  private gameStartRecorded: boolean = false
  /** Worker 线程实例（用于异步生成谜题） */
  private puzzleWorker: worker.ThreadWorker | null = null

  aboutToAppear(): void {
    this.showCoordinates = AppStorage.get<boolean>('showCoordinates') ?? false
    hilog.info(0x0000, 'GamePage', 'aboutToAppear: isLeftHand=%{public}s, handModeManual=%{public}s',
      String(this.isLeftHand), String(AppStorage.get<boolean>('handModeManual')))
    // 从路由参数获取难度
    const params = router.getParams() as GamePageParams | null
    const difficulty = params?.difficulty ?? Difficulty.EASY
    const symmetryParam = params?.symmetry as Symmetry | undefined
    const seedIdParam = params?.seedId
    const importedPuzzle = params?.importedPuzzle
    const importedDifficulty = params?.importedDifficulty

    // 尝试恢复存档（种子模式不恢复存档）
    const saved = !seedIdParam ? loadGame(getContext(this)) : null
    if (saved && saved.cells.length === 81) {
      this.restoreFromSave(saved)
      this.gameStartRecorded = true
      this.finishInit()
    } else {
      // Worker 线程异步生成，不阻塞 UI（Loading 动画可流畅转动）
      this.isLoading = true
      this.startPuzzleWorker(difficulty, symmetryParam, seedIdParam, importedPuzzle, importedDifficulty)
    }
  }

  /**
   * 启动 Worker 线程生成谜题
   */
  private startPuzzleWorker(
    difficulty: Difficulty,
    symmetryParam: Symmetry | undefined,
    seedIdParam: string | undefined,
    importedPuzzle: string | undefined,
    importedDifficulty: Difficulty | undefined,
  ): void {
    const w = new worker.ThreadWorker('entry/ets/workers/PuzzleWorker.ets')
    this.puzzleWorker = w

    w.onmessage = (e: MessageEvents): void => {
      const msg = e.data as Record<string, Object>
      const type = msg['type'] as string

      if (type === 'result') {
        const action = msg['action'] as string
        const puzzle = msg['puzzle'] as number[][]
        const solution = msg['solution'] as number[][]
        const msgDifficulty = msg['difficulty'] as number as Difficulty

        if (action === 'import') {
          this.gameState.initGame(puzzle, solution, msgDifficulty)
          this.gameState.seed = 0
          this.gameState.symmetry = 'imported'
        } else {
          const seed = msg['seed'] as number
          const symmetry = msg['symmetry'] as string
          const actualDifficulty = seedIdParam
            ? (decodeSeedId(seedIdParam)?.difficulty ?? difficulty)
            : difficulty
          this.gameState.initGame(puzzle, solution, actualDifficulty)
          this.gameState.seed = seed
          this.gameState.symmetry = symmetry
        }

        this.cellsWrapper = new ArrayWrapper(this.gameState.cells)
        recordGameStarted(getContext(this), this.gameState.difficulty)
        this.gameStartRecorded = true
        this.finishInit()
      } else if (type === 'error') {
        const errorMsg = msg['message'] as string
        hilog.error(0x0000, 'GamePage', 'Worker error: %{public}s', errorMsg)
        if (errorMsg === 'puzzle_no_solution') {
          promptAction.showToast({ message: this.getString('puzzle_no_solution'), duration: 2000 })
        } else {
          promptAction.showToast({ message: formatStr(this.getString('import_failed'), errorMsg), duration: 2000 })
        }
        router.back()
      }

      this.terminateWorker()
    }

    w.onerror = (e: ErrorEvent): void => {
      hilog.error(0x0000, 'GamePage', 'Worker onerror: %{public}s', e.message)
      promptAction.showToast({ message: this.getString('generation_failed'), duration: 2000 })
      this.terminateWorker()
      router.back()
    }

    // 发送任务到 Worker
    if (importedPuzzle) {
      w.postMessage({
        type: 'import',
        puzzle81: importedPuzzle,
        difficulty: importedDifficulty ?? null,
      })
    } else if (seedIdParam) {
      w.postMessage({
        type: 'generateFromSeed',
        seedId: seedIdParam,
      })
    } else {
      w.postMessage({
        type: 'generate',
        difficulty: difficulty,
        symmetry: symmetryParam ?? null,
      })
    }
  }

  /**
   * 安全销毁 Worker
   */
  private terminateWorker(): void {
    if (this.puzzleWorker) {
      this.puzzleWorker.terminate()
      this.puzzleWorker = null
    }
  }

  /**
   * 初始化完成后的通用逻辑（验证、计时器、动画）
   */
  private finishInit(): void {
    validateAllCells(this.gameState.cells, this.validateInput ? this.gameState.solution : undefined)
    this.updateRemainingCounts()
    this.syncDisplayState()
    this.isLoading = false

    // 启动计时器
    this.timerId = setInterval(() => {
      this.gameState.tick()
      this.displayTime = this.gameState.formattedTime
    }, 1000)

    // 棋盘入场动画
    setTimeout(() => {
      animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.boardScale = 1.0
        this.boardOpacity = 1.0
      })
    }, 100)

    // 首次使用手势引导
    if (!this.gestureGuideShown) {
      setTimeout(() => {
        this.showGestureGuide = true
      }, 600)
    }
  }

  onPageHide(): void {
    // 页面隐藏时保存（含切后台），确保 flush() 有时间写入磁盘
    if (!this.gameState.isCompleted) {
      this.saveCurrentGame()
    }
  }

  aboutToDisappear(): void {
    this.terminateWorker()
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
    this.gameState.seed = saved.seed ?? 0
    this.gameState.symmetry = saved.symmetry ?? ''

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
    data.seed = this.gameState.seed
    data.symmetry = this.gameState.symmetry
    saveGame(getContext(this), data)
  }

  // ================================================================
  // 暂停 / 恢复 / 重新开始
  // ================================================================

  /**
   * 切换暂停/恢复
   */
  private togglePause(): void {
    if (this.gameState.isCompleted) return
    if (this.gameState.isPaused) {
      // 恢复
      this.gameState.isPaused = false
      this.showPauseOverlay = false
    } else {
      // 暂停
      this.gameState.isPaused = true
      this.showPauseOverlay = true
    }
  }

  private getString(name: string): string {
    return getContext(this).resourceManager.getStringByNameSync(name)
  }

  private getCurrentSeedId(): string {
    if (this.gameState.seed <= 0 || this.gameState.symmetry.length === 0) {
      return '-'
    }
    return encodeSeedId(this.gameState.difficulty, this.gameState.symmetry as Symmetry, this.gameState.seed)
  }

  /**
   * 获取当前谜题的 81 字符串（原始题面，不含玩家填入）
   */
  private getPuzzle81String(): string {
    const board: number[][] = []
    for (let r = 0; r < 9; r++) {
      const row: number[] = []
      for (let c = 0; c < 9; c++) {
        const cell = this.gameState.cells[r * 9 + c]
        row.push(cell.isGiven ? cell.value : 0)
      }
      board.push(row)
    }
    return exportTo81String(board)
  }

  private getCurrentDifficultyLabel(): string {
    return this.getString(getDifficultyConfig(this.gameState.difficulty).name)
  }

  private getCurrentSymmetryLabel(): string {
    switch (this.gameState.symmetry) {
      case Symmetry.NONE:
        return this.getString('sym_none')
      case Symmetry.ROTATIONAL_180:
        return this.getString('sym_rot180')
      case Symmetry.ROTATIONAL_90:
        return this.getString('sym_rot90')
      case Symmetry.MIRROR:
        return this.getString('sym_mirror')
      default:
        return '-'
    }
  }

  /**
   * 重新开始当前局（保留同一题目，清除玩家输入）
   */
  private restartGame(): void {
    const ctx = getContext(this)
    const title = ctx.resourceManager.getStringByNameSync('restart_confirm_title')
    const msg = ctx.resourceManager.getStringByNameSync('restart_confirm_msg')
    const yes = ctx.resourceManager.getStringByNameSync('restart_confirm_yes')
    const no = ctx.resourceManager.getStringByNameSync('restart_confirm_no')
    AlertDialog.show({
      title: title,
      message: msg,
      primaryButton: {
        value: no,
        action: () => {
          // 取消 — 不做任何事
        },
      },
      secondaryButton: {
        value: yes,
        action: () => {
          this.gameState.resetGame()
          this.history = new GameHistory()
          this.cellsWrapper = new ArrayWrapper(this.gameState.cells)
          validateAllCells(this.gameState.cells, this.validateInput ? this.gameState.solution : undefined)
          this.updateRemainingCounts()
          this.syncDisplayState()
          this.gameState.isPaused = false
          this.showPauseOverlay = false
          // 重启计时器
          if (this.timerId !== -1) {
            clearInterval(this.timerId)
          }
          this.timerId = setInterval(() => {
            this.gameState.tick()
            this.displayTime = this.gameState.formattedTime
          }, 1000)
        },
      },
    })
  }

  /**
   * 退出游戏（保存并返回主页）
   */
  private quitGame(): void {
    this.gameState.isPaused = false
    this.showPauseOverlay = false
    router.back()
  }

  // ================================================================
  // 核心交互逻辑
  // ================================================================

  /**
   * 点击棋盘格子
   */
  private onCellClick(index: number): void {
    if (this.gameState.isPaused) return

    if (this.isMultiSelectMode) {
      // 多选模式下：切换格子的多选状态
      this.toggleMultiSelect(index)
      return
    }

    this.gameState.selectCell(index)
    updateHighlights(this.gameState.cells, this.gameState.selectedIndex)
  }

  /**
   * 键盘输入回调 — 支持方向键切换格子、数字键填数、Delete/Backspace 擦除
   */
  private handleKeyboardInput(keyCode: number): void {
    if (this.gameState.isCompleted) return
    if (this.gameState.isPaused) return

    const sel = this.gameState.selectedIndex

    // --- 方向键导航 ---
    if (keyCode === KeyCode.KEYCODE_DPAD_UP || keyCode === KeyCode.KEYCODE_DPAD_DOWN ||
      keyCode === KeyCode.KEYCODE_DPAD_LEFT || keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
      // 如果当前无选中格，默认从中心 (4,4) 开始
      let row = sel >= 0 ? Math.floor(sel / 9) : 4
      let col = sel >= 0 ? sel % 9 : 4
      switch (keyCode) {
        case KeyCode.KEYCODE_DPAD_UP:
          row = row > 0 ? row - 1 : 8
          break
        case KeyCode.KEYCODE_DPAD_DOWN:
          row = row < 8 ? row + 1 : 0
          break
        case KeyCode.KEYCODE_DPAD_LEFT:
          col = col > 0 ? col - 1 : 8
          break
        case KeyCode.KEYCODE_DPAD_RIGHT:
          col = col < 8 ? col + 1 : 0
          break
      }
      const newIndex = row * 9 + col
      // 退出多选模式（如果在多选中）
      if (this.isMultiSelectMode) {
        this.exitMultiSelect()
      }
      this.gameState.selectedIndex = newIndex
      updateHighlights(this.gameState.cells, this.gameState.selectedIndex)
      return
    }

    // --- 数字键 1-9 填数（等同于 TAP 手势）---
    const digitMap: Map<number, number> = new Map([
      [KeyCode.KEYCODE_1, 1], [KeyCode.KEYCODE_2, 2], [KeyCode.KEYCODE_3, 3],
      [KeyCode.KEYCODE_4, 4], [KeyCode.KEYCODE_5, 5], [KeyCode.KEYCODE_6, 6],
      [KeyCode.KEYCODE_7, 7], [KeyCode.KEYCODE_8, 8], [KeyCode.KEYCODE_9, 9],
      [KeyCode.KEYCODE_NUMPAD_1, 1], [KeyCode.KEYCODE_NUMPAD_2, 2], [KeyCode.KEYCODE_NUMPAD_3, 3],
      [KeyCode.KEYCODE_NUMPAD_4, 4], [KeyCode.KEYCODE_NUMPAD_5, 5], [KeyCode.KEYCODE_NUMPAD_6, 6],
      [KeyCode.KEYCODE_NUMPAD_7, 7], [KeyCode.KEYCODE_NUMPAD_8, 8], [KeyCode.KEYCODE_NUMPAD_9, 9],
    ])
    if (digitMap.has(keyCode)) {
      const digit = digitMap.get(keyCode)!
      this.onGesture(digit, GestureDirection.TAP)
      return
    }

    // --- Delete / Backspace / 数字0 → 擦除 ---
    if (keyCode === KeyCode.KEYCODE_DEL || keyCode === KeyCode.KEYCODE_FORWARD_DEL ||
      keyCode === KeyCode.KEYCODE_0 || keyCode === KeyCode.KEYCODE_NUMPAD_0) {
      this.onErase()
      return
    }

    // --- Z = 撤销, Y = 重做 ---
    if (keyCode === KeyCode.KEYCODE_Z) {
      this.onUndo()
      return
    }
    if (keyCode === KeyCode.KEYCODE_Y) {
      this.onRedo()
      return
    }
  }

  /**
   * 触摸长按拖拽多选处理（手机端）
   * start: 长按 400ms 触发，进入多选模式
   * move: 手指滑动经过新格子，自动加入多选
   * end: 手指抬起，保持多选模式等待笔记输入
   */
  private onTouchDragSelect(index: number, action: string): void {
    if (this.gameState.isPaused) return
    if (this.gameState.isCompleted) return
    if (index < 0 || index >= 81) return

    const cell = this.gameState.cells[index]

    if (action === 'start') {
      if (cell.isGiven) return

      // 进入多选模式
      this.isMultiSelectMode = true
      this.multiSelectIndices.clear()
      this.multiSelectIndices.add(index)

      this.gameState.selectedIndex = index
      this.updateMultiSelectFlags()
    } else if (action === 'move') {
      // 滑动经过新格子
      if (cell.isGiven) return
      if (!this.multiSelectIndices.has(index)) {
        this.multiSelectIndices.add(index)
        this.updateMultiSelectFlags()
      }
    } else if (action === 'end') {
      // 手指抬起：如果只选了一个格子，退出多选（视为普通长按选中）
      if (this.multiSelectIndices.size <= 1) {
        this.exitMultiSelect()
        if (index >= 0 && index < 81) {
          this.gameState.selectCell(index)
          updateHighlights(this.gameState.cells, this.gameState.selectedIndex)
        }
      }
      // 否则保持多选模式，等待用户输入笔记
    }
  }

  /**
   * 切换某格的多选状态
   */
  private toggleMultiSelect(index: number): void {
    const cell = this.gameState.cells[index]
    if (cell.isGiven) return

    if (this.multiSelectIndices.has(index)) {
      this.multiSelectIndices.delete(index)
      if (this.multiSelectIndices.size === 0) {
        // 最后一个也取消了，退出多选模式
        this.exitMultiSelect()
        return
      }
    } else {
      this.multiSelectIndices.add(index)
    }

    this.gameState.selectedIndex = index
    this.updateMultiSelectFlags()
  }

  /**
   * 更新多选状态的 flags 显示
   */
  private updateMultiSelectFlags(): void {
    const cells = this.gameState.cells
    // 清除所有 SELECTED / HIGHLIGHTED / MULTI_SELECTED
    for (let i = 0; i < 81; i++) {
      cells[i].flags = clearFlag(cells[i].flags, CellFlags.SELECTED)
      cells[i].flags = clearFlag(cells[i].flags, CellFlags.HIGHLIGHTED)
      cells[i].flags = clearFlag(cells[i].flags, CellFlags.MULTI_SELECTED)
    }
    // 设置多选标志
    this.multiSelectIndices.forEach((idx) => {
      cells[idx].flags = setFlag(cells[idx].flags, CellFlags.MULTI_SELECTED)
    })
    this.multiSelectCount = this.multiSelectIndices.size
  }

  /**
   * 退出多选模式
   */
  private exitMultiSelect(): void {
    const cells = this.gameState.cells
    for (let i = 0; i < 81; i++) {
      cells[i].flags = clearFlag(cells[i].flags, CellFlags.MULTI_SELECTED)
    }
    this.multiSelectIndices.clear()
    this.isMultiSelectMode = false
    this.multiSelectCount = 0
    this.isMouseDragging = false
    this.mouseDragStartIndex = -1
    updateHighlights(cells, this.gameState.selectedIndex)
  }

  /**
   * 鼠标拖拽多选处理
   * 按下左键记录起始格，移动到其他格时进入多选模式，
   * 释放后保持多选模式等待笔记输入。
   * 如果没有拖到其他格就释放，视为普通点击（不进入多选）。
   */
  private onMouseDragSelect(index: number, action: string): void {
    if (this.gameState.isPaused) return
    if (this.gameState.isCompleted) return

    const cell = this.gameState.cells[index]

    if (action === 'start') {
      // 鼠标按下：记录起始位置，暂不进入多选
      this.isMouseDragging = true
      this.mouseDragStartIndex = index
    } else if (action === 'move' && this.isMouseDragging) {
      // 拖拽中：鼠标滑入新格子
      if (cell.isGiven) return
      if (index === this.mouseDragStartIndex && !this.isMultiSelectMode) return

      // 首次拖到不同格：进入多选模式，把起始格也加入
      if (!this.isMultiSelectMode) {
        const startCell = this.gameState.cells[this.mouseDragStartIndex]
        this.isMultiSelectMode = true
        this.multiSelectIndices.clear()
        if (!startCell.isGiven && this.mouseDragStartIndex >= 0) {
          this.multiSelectIndices.add(this.mouseDragStartIndex)
        }
      }

      if (!this.multiSelectIndices.has(index)) {
        this.multiSelectIndices.add(index)
        this.updateMultiSelectFlags()
      }
    } else if (action === 'end') {
      this.isMouseDragging = false
      this.mouseDragStartIndex = -1
      // 如果多选中只选了一个格子（几乎没拖动），退出多选
      if (this.isMultiSelectMode && this.multiSelectIndices.size <= 1) {
        this.exitMultiSelect()
      }
    }
  }

  /**
   * 手势键盘回调
   */
  private onGesture(digit: number, direction: GestureDirection): void {
    if (this.gameState.isCompleted) return
    if (this.gameState.isPaused) return

    // 多选模式：对所有选中格子执行操作
    if (this.isMultiSelectMode && this.multiSelectIndices.size > 0) {
      this.onGestureMultiSelect(digit, direction)
      return
    }

    const cell = this.gameState.selectedCell
    if (cell === null) return
    if (cell.isGiven) return

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
   * 多选模式下的手势操作 — 对所有选中格子批量执行
   * 仅支持笔记相关操作（上滑笔记、右滑删除线、左滑擦除笔记），不支持填数
   */
  private onGestureMultiSelect(digit: number, direction: GestureDirection): void {
    if (direction === GestureDirection.TAP) {
      // 多选模式下点击数字 → 视为笔记操作（最常见的多选用途）
      // 改为笔记模式
    }

    const actualDirection = direction === GestureDirection.TAP ? GestureDirection.UP : direction

    let anyChanged = false
    this.multiSelectIndices.forEach((idx) => {
      const cell = this.gameState.cells[idx]
      if (cell.isGiven) return

      const snapshot = new CellSnapshot(
        cell.index, cell.value, cell.value,
        cell.notes, cell.notes, cell.flags, cell.flags
      )

      switch (actualDirection) {
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

      snapshot.newValue = cell.value
      snapshot.newNotes = cell.notes
      snapshot.newFlags = cell.flags

      if (snapshot.oldValue !== snapshot.newValue ||
        snapshot.oldNotes !== snapshot.newNotes) {
        this.history.push(snapshot)
        anyChanged = true
      }
    })

    if (anyChanged) {
      this.afterAction()
      // 操作完成后重新更新多选标志（afterAction 会清除 flags）
      this.updateMultiSelectFlags()
    }
  }

  /**
   * 每次操作后的统一处理
   * @param filledIndex 如果是填数操作，传入填数的格子索引，用于自动清除 peers 笔记
   */
  private afterAction(filledIndex?: number): void {

    // 自动清除 peers 的候选数字（仅在填数时）
    this.autoClearPeerNotes(filledIndex)

    // 操作后更新冲突 + 高亮 + 剩余计数
    validateAllCells(this.gameState.cells, this.validateInput ? this.gameState.solution : undefined)
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
      // 记录到历史记录（含种子和每步操作）
      const record = new GameRecord()
      record.seedId = encodeSeedId(
        this.gameState.difficulty,
        this.gameState.symmetry as Symmetry,
        this.gameState.seed
      )
      record.seed = this.gameState.seed
      record.difficulty = this.gameState.difficulty
      record.symmetry = this.gameState.symmetry
      record.timeSeconds = this.gameState.elapsedSeconds
      record.errors = this.gameState.errorCount
      record.stepCount = this.history.undoStack.length
      record.won = true
      record.timestamp = Date.now()
      record.steps = this.history.undoStack.slice() // 复制一份
      addGameRecord(getContext(this), record)
      // 完成庆祝动画：棋盘弹跳 → 弹窗
      this.playCompletionAnimation()
      return // 游戏完成，已 clearSave，不再持久化
    }

    // 每次操作后持久化，防止闪退丢数据
    this.saveCurrentGame()
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
      // 检查是否与答案不符 → 计数错误（无论助手开关，均记录）
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
   * 提示 — 用 LogicSolver 分析下一步，显示技巧名称后填入
   */
  private onHint(): void {
    if (this.gameState.isCompleted) return
    if (this.isHintLoading) return

    // 第一步：如果有错误填入，先擦除错误格子
    const errorCell = this.findFirstErrorCell()
    if (errorCell !== null) {
      this.eraseErrorCell(errorCell)
      return
    }

    // 第二步：无错误，尝试逻辑提示
    this.isHintLoading = true
    setTimeout(() => {
      try {
        const board = this.buildCurrentBoard()
        const hint = getNextHint(board)

        if (hint !== null && hint.digit !== 0) {
          this.applyLogicHint(hint)
          return
        }

        this.applyDirectHint()
      } finally {
        this.isHintLoading = false
      }
    }, 60)
  }

  /**
   * 找到第一个错误填入的格子
   */
  private findFirstErrorCell(): CellData | null {
    // 优先选中格
    const selected = this.gameState.selectedCell
    if (selected !== null && !selected.isGiven && selected.value !== 0 &&
      this.gameState.solution.length > selected.index &&
      selected.value !== this.gameState.solution[selected.index]) {
      return selected
    }
    // 遍历找第一个错误格
    for (const cell of this.gameState.cells) {
      if (!cell.isGiven && cell.value !== 0 &&
        this.gameState.solution.length > cell.index &&
        cell.value !== this.gameState.solution[cell.index]) {
        return cell
      }
    }
    return null
  }

  /**
   * 擦除错误格子并提示用户
   */
  private eraseErrorCell(cell: CellData): void {
    this.focusHintCell(cell.index)

    const snapshot = new CellSnapshot(
      cell.index, cell.value, 0,
      cell.notes, 0, cell.flags, cell.flags
    )
    cell.clear()
    snapshot.newFlags = cell.flags
    this.history.push(snapshot)

    this.afterAction(cell.index)
    this.showHintToast(`💡 ${this.formatCellLabel(cell.index)} ${this.getString('hint_error_erased')}`)
  }

  private formatCellLabel(index: number): string {
    const row = Math.floor(index / 9) + 1
    const col = (index % 9) + 1
    return formatStr(this.getString('cell_label'), row, col)
  }

  private focusHintCell(index: number): void {
    this.hintFocusIndex = index
    this.gameState.selectedIndex = index
    updateHighlights(this.gameState.cells, this.gameState.selectedIndex)
    setTimeout(() => {
      if (this.hintFocusIndex === index) {
        this.hintFocusIndex = -1
      }
    }, 1800)
  }

  private findDirectHintCellIndex(): number {
    const selected = this.gameState.selectedCell
    if (selected !== null && !selected.isGiven && this.gameState.solution[selected.index] !== selected.value) {
      return selected.index
    }

    for (const cell of this.gameState.cells) {
      if (!cell.isGiven && this.gameState.solution.length > cell.index && this.gameState.solution[cell.index] !== cell.value) {
        return cell.index
      }
    }

    return -1
  }

  /** 构建当前棋盘状态（已填的用 value，未填的为 0）
   *  错误填入的格子视为空格，确保 solver 在干净棋盘上分析
   */
  private buildCurrentBoard(): number[][] {
    const board: number[][] = []
    for (let r = 0; r < 9; r++) {
      const row: number[] = []
      for (let c = 0; c < 9; c++) {
        const cell = this.gameState.cells[r * 9 + c]
        // 跳过错误填入：用户填了但和答案不符的格子视为空
        if (cell.value !== 0 && !cell.isGiven &&
          this.gameState.solution.length > cell.index &&
          cell.value !== this.gameState.solution[cell.index]) {
          row.push(0)
        } else {
          row.push(cell.value)
        }
      }
      board.push(row)
    }
    return board
  }

  /** 应用逻辑提示：显示技巧名 + 高亮 + 填数 */
  private applyLogicHint(hint: SolveStep): void {
    const cell = this.gameState.cells[hint.cellIndex]
    if (cell.isGiven) return

    const techniqueName = this.getString(getTechniqueNameKey(hint.technique))

    // 选中并高亮目标格子
    this.focusHintCell(hint.cellIndex)

    // 记录到历史
    const snapshot = new CellSnapshot(
      cell.index, cell.value, hint.digit,
      cell.notes, 0, cell.flags, cell.flags
    )

    cell.fillValue(hint.digit)

    snapshot.newFlags = cell.flags
    this.history.push(snapshot)

    this.afterAction(cell.index)

    // 显示技巧名称的 Toast
    this.showHintToast(`💡 ${techniqueName}：${this.formatCellLabel(hint.cellIndex)} ${this.getString('hint_fill')} ${hint.digit}`)
  }

  /** 直接提示：填入正确答案（无逻辑步骤可用时的回退） */
  private applyDirectHint(): void {
    const targetIndex = this.findDirectHintCellIndex()
    if (targetIndex < 0) return
    const cell = this.gameState.cells[targetIndex]
    if (cell.isGiven) return
    if (this.gameState.solution.length === 0) return

    const correctValue = this.gameState.solution[cell.index]
    if (correctValue === 0) return
    if (cell.value === correctValue) return

    this.focusHintCell(cell.index)

    const snapshot = new CellSnapshot(
      cell.index, cell.value, correctValue,
      cell.notes, 0, cell.flags, cell.flags
    )

    cell.fillValue(correctValue)

    snapshot.newFlags = cell.flags
    this.history.push(snapshot)

    this.afterAction(cell.index)
    this.showHintToast(`💡 ${this.getString('hint_direct_algorithm')}：${this.formatCellLabel(cell.index)} ${this.getString('hint_fill')} ${correctValue}`)
  }

  /** 显示提示 Toast */
  private showHintToast(message: string): void {
    try {
      promptAction.showToast({
        message: message,
        duration: 3000,
        bottom: 200,
      })
    } catch (e) {
      hilog.warn(0x0000, 'GamePage', 'showHintToast failed: %{public}s', String(e))
    }
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
   * 完成庆祝动画：棋盘弹跳缩放 → 延迟弹窗
   */
  private playCompletionAnimation(): void {
    // Phase 1: 缩小
    animateTo({ duration: 150, curve: Curve.EaseIn }, () => {
      this.completionScale = 0.95
    })
    // Phase 2: 弹大
    setTimeout(() => {
      animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
        this.completionScale = 1.06
      })
    }, 150)
    // Phase 3: 回弹到正常
    setTimeout(() => {
      animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
        this.completionScale = 1.0
      })
    }, 400)
    // Phase 4: 弹窗
    setTimeout(() => {
      this.showCompletionDialog()
    }, 700)
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

  @Builder
  settingsSheetBuilder() {
    SettingsPanel({
      context: getContext(this) as common.UIAbilityContext,
      onClose: () => {
        this.showCoordinates = AppStorage.get<boolean>('showCoordinates') ?? false
        this.showSettings = false
      },
    })
  }



  build() {
    Column() {
      if (this.isLoading) {
        // 加载中
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(Colors.primaryBtn)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
      // === 主游戏内容 ===
      Column() {
        // ① 顶部信息栏
        TopBar({
          difficulty: this.gameState.difficulty,
          formattedTime: this.displayTime,
          errorCount: this.displayErrors,
          isPaused: this.gameState.isPaused,
          onPause: () => this.togglePause(),
        })

        // ② 棋盘
        SudokuBoard({
          cells: this.cellsWrapper,
          selectedValue: this.gameState.selectedCell?.value ?? 0,
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
            this.handleKeyboardInput(keyCode)
          },
        })
          .margin({ top: 12 })
          .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
          .scale({ x: this.boardScale * this.completionScale, y: this.boardScale * this.completionScale })
          .opacity(this.boardOpacity)

        // 多选模式提示条
        if (this.isMultiSelectMode) {
          Row({ space: 8 }) {
            Text(`🔲 ${this.getString('multi_select_hint')}（${this.multiSelectCount}）`)
              .fontSize(13)
              .fontColor(Colors.primaryBtn)
            Text('✕')
              .fontSize(14)
              .fontColor(Colors.subtitleText)
              .onClick(() => this.exitMultiSelect())
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 4, bottom: 4 })
          .margin({ top: 4 })
          .backgroundColor(Colors.multiSelectBar)
          .borderRadius(8)
          .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
        }

        // 手势提示条
        GestureModeIndicator({
          currentDirection: this.gestureDirection,
        })
          .margin({ top: 8 })

        // ③ 操作区（左右手模式镜像）
        Row({ space: 8 }) {
          if (!this.isLeftHand) {
            // 右手模式：辅助按钮在左，键盘在右
            AuxButtonGrid({
              onUndo: () => { this.onUndo() },
              onRedo: () => { this.onRedo() },
              onErase: () => { this.onErase() },
              onHint: () => { this.onHint() },
              onSettings: () => { this.showSettings = true },
              undoDisabled: !this.canUndo,
              redoDisabled: !this.canRedo,
              eraseDisabled: this.gameState.selectedCell === null ||
                this.gameState.selectedCell!.isGiven ||
                (this.gameState.selectedCell!.isEmpty && this.gameState.selectedCell!.notes === 0),
              hintDisabled: this.gameState.isCompleted,
              hintLoading: this.isHintLoading,
              gridHeight: this.numPadHeight,
            })

            GestureNumberPad({
              remainingCounts: this.remainingCounts,
              onGesture: (digit: number, direction: GestureDirection) => {
                this.onGesture(digit, direction)
              },
              onGestureDirectionChange: (direction: GestureDirection | null) => {
                this.gestureDirection = direction
              },
              onHeightChange: (h: number) => { this.numPadHeight = h },
            })
          } else {
            // 左手模式：键盘在左，辅助按钮在右
            GestureNumberPad({
              remainingCounts: this.remainingCounts,
              onGesture: (digit: number, direction: GestureDirection) => {
                this.onGesture(digit, direction)
              },
              onGestureDirectionChange: (direction: GestureDirection | null) => {
                this.gestureDirection = direction
              },
              onHeightChange: (h: number) => { this.numPadHeight = h },
            })

            AuxButtonGrid({
              onUndo: () => { this.onUndo() },
              onRedo: () => { this.onRedo() },
              onErase: () => { this.onErase() },
              onHint: () => { this.onHint() },
              onSettings: () => { this.showSettings = true },
              undoDisabled: !this.canUndo,
              redoDisabled: !this.canRedo,
              eraseDisabled: this.gameState.selectedCell === null ||
                this.gameState.selectedCell!.isGiven ||
                (this.gameState.selectedCell!.isEmpty && this.gameState.selectedCell!.notes === 0),
              hintDisabled: this.gameState.isCompleted,
              hintLoading: this.isHintLoading,
              gridHeight: this.numPadHeight,
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 8 })
        .padding({ left: Sizes.gamePagePadding, right: Sizes.gamePagePadding })
      }
      .width('100%')
      .height('100%')

      // === 暂停遮罩 ===
      if (this.showPauseOverlay) {
        Column() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Colors.pauseOverlayBg)
            .opacity(0.6)
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .justifyContent(FlexAlign.Center)

        Column({ space: 16 }) {
          Text($r('app.string.pause_title'))
            .fontSize(24)
            .fontColor(Colors.pauseOverlayText)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 16 })

          Column({ space: 8 }) {
            Row({ space: 4 }) {
              Text(`${this.getString('pause_info_seed')}: ${this.getCurrentSeedId()}`)
                .fontSize(13)
                .fontColor(Colors.pauseOverlayText)
              Text('📋')
                .fontSize(12)
            }
            .onClick(() => {
              const seedId = this.getCurrentSeedId()
              if (seedId !== '-') {
                const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, seedId)
                const clipboard = pasteboard.getSystemPasteboard()
                clipboard.setData(pasteData)
                promptAction.showToast({ message: this.getString('seed_copied'), duration: 1500 })
              }
            })

            // 导出 81 字符串
            Row({ space: 4 }) {
              Text(`81: ${this.getPuzzle81String().substring(0, 18)}...`)
                .fontSize(13)
                .fontColor(Colors.pauseOverlayText)
                .maxLines(1)
              Text('📋')
                .fontSize(12)
            }
            .onClick(() => {
              const puzzle81 = this.getPuzzle81String()
              const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, puzzle81)
              const clipboard = pasteboard.getSystemPasteboard()
              clipboard.setData(pasteData)
              promptAction.showToast({ message: this.getString('puzzle_copied'), duration: 1500 })
            })
            Text(`${this.getString('pause_info_difficulty')}: ${this.getCurrentDifficultyLabel()}`)
              .fontSize(13)
              .fontColor(Colors.pauseOverlayText)
            Text(`${this.getString('pause_info_symmetry')}: ${this.getCurrentSymmetryLabel()}`)
              .fontSize(13)
              .fontColor(Colors.pauseOverlayText)
            Text(`${this.getString('pause_info_time')}: ${this.displayTime}`)
              .fontSize(13)
              .fontColor(Colors.pauseOverlayText)
            Text(`${this.getString('pause_info_errors')}: ${this.displayErrors}/3`)
              .fontSize(13)
              .fontColor(Colors.pauseOverlayText)
          }
          .width(280)
          .padding(16)
          .borderRadius(16)
          .backgroundColor(Colors.pauseInfoCardBg)
          .margin({ bottom: 8 })

          // 继续
          Button($r('app.string.pause_resume'))
            .type(ButtonType.Capsule)
            .width(220)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Colors.primaryBtn)
            .fontColor(Colors.primaryText)
            .onClick(() => this.togglePause())

          // 重新开始
          Button($r('app.string.pause_restart'))
            .type(ButtonType.Capsule)
            .width(220)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Colors.pauseRestartBtn)
            .fontColor(Colors.pauseOverlayText)
            .onClick(() => this.restartGame())

          // 退出
          Button($r('app.string.pause_quit'))
            .type(ButtonType.Capsule)
            .width(220)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Colors.pauseQuitBtn)
            .fontColor(Colors.pauseOverlayText)
            .onClick(() => this.quitGame())
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .justifyContent(FlexAlign.Center)
      }

      // === 首次手势引导遮罩 ===
      if (this.showGestureGuide) {
        GestureGuideOverlay({
          onDismiss: () => {
            this.showGestureGuide = false
          },
        })
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
      }
      } // end else (not loading)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.pageBg)
    .padding({ top: this.topRectHeight + 12, bottom: this.bottomRectHeight + 12 })
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .bindSheet($$this.showSettings, this.settingsSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      backgroundColor: Colors.boardBg,
      onDisappear: () => {
        this.showCoordinates = AppStorage.get<boolean>('showCoordinates') ?? false
      },
    })

  }
}
