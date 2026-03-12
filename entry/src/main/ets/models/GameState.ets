/**
 * GameState.ets — 游戏状态模型
 *
 * 管理一局游戏的全部状态：棋盘、答案、计时、错误数等。
 * 用 @Observed 标记以便全局响应式。
 *
 * 参考：Doc 03 任务 1.2
 */
import { CellData, createBoardFromArray, createEmptyBoard } from './CellData'
import { Difficulty, GRID_SIZE, TOTAL_CELLS } from '../constants/GameConstants'

@Observed
export class GameState {
  /** TOTAL_CELLS 个单元格（一维数组，index = row * GRID_SIZE + col） */
  cells: CellData[]
  /** 完整解答（TOTAL_CELLS 个数字，用于验证和提示） */
  solution: number[]
  /** 当前选中格的一维索引，-1 表示未选中 */
  selectedIndex: number
  /** 难度 */
  difficulty: Difficulty
  /** 已用秒数 */
  elapsedSeconds: number
  /** 错误次数 */
  errorCount: number
  /** 游戏是否已完成 */
  isCompleted: boolean
  /** 游戏是否暂停 */
  isPaused: boolean
  /** 生成种子（用于复现/分享同一题） */
  seed: number
  /** 对称模式 */
  symmetry: string

  constructor() {
    this.cells = createEmptyBoard()
    this.solution = []
    this.selectedIndex = -1
    this.difficulty = Difficulty.EASY
    this.elapsedSeconds = 0
    this.errorCount = 0
    this.isCompleted = false
    this.isPaused = false
    this.seed = 0
    this.symmetry = ''
  }

  // --- 选中格 ---

  /** 获取当前选中的 CellData，没选中返回 null */
  get selectedCell(): CellData | null {
    if (this.selectedIndex < 0 || this.selectedIndex >= TOTAL_CELLS) {
      return null
    }
    return this.cells[this.selectedIndex]
  }

  /** 选中指定格（再次点击同一格取消选中） */
  selectCell(index: number): void {
    if (index === this.selectedIndex) {
      this.selectedIndex = -1 // 取消选中
    } else {
      this.selectedIndex = index
    }
  }

  /** 取消选中 */
  clearSelection(): void {
    this.selectedIndex = -1
  }

  // --- 初始化 ---

  /**
   * 用生成的题目和答案初始化
   * @param puzzle 谜题（GRID_SIZE×GRID_SIZE, 0 表示空格）
   * @param solution 完整解答（GRID_SIZE×GRID_SIZE, 全部填满）
   * @param difficulty 难度
   */
  initGame(puzzle: number[][], solution: number[][], difficulty: Difficulty): void {
    this.cells = createBoardFromArray(puzzle)
    // solution 二维 → 一维
    this.solution = []
    for (let row = 0; row < GRID_SIZE; row++) {
      for (let col = 0; col < GRID_SIZE; col++) {
        this.solution.push(solution[row][col])
      }
    }
    this.difficulty = difficulty
    this.selectedIndex = -1
    this.elapsedSeconds = 0
    this.errorCount = 0
    this.isCompleted = false
    this.isPaused = false
  }

  /** 重置当前局（保留题目，清除玩家输入） */
  resetGame(): void {
    for (const cell of this.cells) {
      if (!cell.isGiven) {
        cell.reset()
      }
    }
    this.selectedIndex = -1
    this.elapsedSeconds = 0
    this.errorCount = 0
    this.isCompleted = false
  }

  // --- 计时 ---

  /** 格式化时间 mm:ss */
  get formattedTime(): string {
    const m = Math.floor(this.elapsedSeconds / 60)
    const s = this.elapsedSeconds % 60
    const mm = m < 10 ? `0${m}` : `${m}`
    const ss = s < 10 ? `0${s}` : `${s}`
    return `${mm}:${ss}`
  }

  tick(): void {
    if (!this.isPaused && !this.isCompleted) {
      this.elapsedSeconds++
    }
  }

  // --- 辅助 ---

  /** 统计某个数字在棋盘上已填入的个数 */
  countDigit(digit: number): number {
    let count = 0
    for (const cell of this.cells) {
      if (cell.value === digit) {
        count++
      }
    }
    return count
  }

  /** 某个数字是否已填满 GRID_SIZE 个 */
  isDigitComplete(digit: number): boolean {
    return this.countDigit(digit) >= GRID_SIZE
  }
}
