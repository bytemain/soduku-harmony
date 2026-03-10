/**
 * CellData.ets — 单元格数据模型
 *
 * 数独 App 最核心的数据结构。
 * 用位标志（bit flags）管理格子状态，用 2-bit 位图管理笔记。
 *
 * 参考：Doc 01 §2.2
 */

// ============================================================
// CellFlags — 状态标志位
// ============================================================

/**
 * 每个 bit 代表一个布尔状态，用位运算操作。
 *
 * 用法：
 *   flags |= CellFlags.GIVEN         // 设置
 *   flags &= ~CellFlags.ERROR        // 清除
 *   (flags & CellFlags.GIVEN) !== 0   // 检查
 */
export interface CellFlagsConfig {
  GIVEN: number
  ERROR: number
  SELECTED: number
  HIGHLIGHTED: number
  LOCKED: number
  MULTI_SELECTED: number
}

export const CellFlags: CellFlagsConfig = {
  /** bit 0: 题目给定的数字（不可修改、不可擦除） */
  GIVEN: 1 << 0,
  /** bit 1: 存在冲突（同行/列/宫有重复） */
  ERROR: 1 << 1,
  /** bit 2: 当前被玩家选中 */
  SELECTED: 1 << 2,
  /** bit 3: 高亮（同行/列/宫/同数字） */
  HIGHLIGHTED: 1 << 3,
  /** bit 4: 提示系统填入的（不可撤销） */
  LOCKED: 1 << 4,
  /** bit 5: 多选模式下被选中 */
  MULTI_SELECTED: 1 << 5,
}

// ============================================================
// NoteState — 笔记三态（每个数字占 2 bit）
// ============================================================

/**
 * 每个数字(1-9)的笔记有三种状态：
 *   EMPTY      = 0b00  未标记（不显示）
 *   ACTIVE     = 0b01  激活（正常显示）
 *   ELIMINATED = 0b10  已排除（显示 + 删除线）
 *
 * 9 个数字 × 2 bit = 18 bit，一个 number 完全够用。
 * 数字 n 占 bit[(n-1)*2 ... (n-1)*2+1]
 */
export interface NoteStateConfig {
  EMPTY: number
  ACTIVE: number
  ELIMINATED: number
}

export const NoteState: NoteStateConfig = {
  EMPTY: 0b00,
  ACTIVE: 0b01,
  ELIMINATED: 0b10,
}

/**
 * 获取数字 n(1-9) 的笔记状态
 */
export function getNoteState(notes: number, n: number): number {
  return (notes >> ((n - 1) * 2)) & 0b11
}

/**
 * 设置数字 n(1-9) 的笔记状态，返回新 notes（不修改原值）
 */
export function setNoteState(notes: number, n: number, state: number): number {
  const shift = (n - 1) * 2
  return (notes & ~(0b11 << shift)) | (state << shift)
}

/**
 * 检查 notes 中是否有任何处于指定状态的数字
 */
export function hasAnyNote(notes: number, state: number): boolean {
  for (let n = 1; n <= 9; n++) {
    if (getNoteState(notes, n) === state) {
      return true
    }
  }
  return false
}

/**
 * 清空所有笔记
 */
export function clearAllNotes(): number {
  return 0
}

// ============================================================
// CellFlags 辅助函数
// ============================================================

/** 检查是否有指定标志 */
export function hasFlag(flags: number, flag: number): boolean {
  return (flags & flag) !== 0
}

/** 设置标志 */
export function setFlag(flags: number, flag: number): number {
  return flags | flag
}

/** 清除标志 */
export function clearFlag(flags: number, flag: number): number {
  return flags & ~flag
}

// ============================================================
// CellData — 可观察的单元格类
// ============================================================

/**
 * 用 @Observed 标记，让 @ObjectLink 能检测到属性变化。
 *
 * 为什么用 class 不用 interface？
 * 因为 ArkUI 的 @Observed 只能装饰 class，不能装饰 interface。
 * 我们需要 81 个 CellData 实例，每个都能被 SudokuCell 组件通过 @ObjectLink 引用，
 * 改了 value/flags/notes 就自动刷新那个格子的 UI。
 */
@Observed
export class CellData {
  row: number
  col: number
  value: number
  flags: number
  notes: number

  constructor(row: number = 0, col: number = 0) {
    this.row = row
    this.col = col
    this.value = 0
    this.flags = 0
    this.notes = 0
  }

  /** 当前格的宫格编号 (0-8) */
  get box(): number {
    return Math.floor(this.row / 3) * 3 + Math.floor(this.col / 3)
  }

  /** 一维索引 (0-80) */
  get index(): number {
    return this.row * 9 + this.col
  }

  // --- flags 便捷方法 ---

  get isGiven(): boolean {
    return hasFlag(this.flags, CellFlags.GIVEN)
  }

  get isError(): boolean {
    return hasFlag(this.flags, CellFlags.ERROR)
  }

  get isSelected(): boolean {
    return hasFlag(this.flags, CellFlags.SELECTED)
  }

  get isHighlighted(): boolean {
    return hasFlag(this.flags, CellFlags.HIGHLIGHTED)
  }

  get isLocked(): boolean {
    return hasFlag(this.flags, CellFlags.LOCKED)
  }

  get isMultiSelected(): boolean {
    return hasFlag(this.flags, CellFlags.MULTI_SELECTED)
  }

  /** 是否可编辑（非给定、非锁定） */
  get isEditable(): boolean {
    return !this.isGiven && !this.isLocked
  }

  /** 是否为空格 */
  get isEmpty(): boolean {
    return this.value === 0
  }

  // --- 操作方法 ---

  /** 填入数字（清空笔记） */
  fillValue(value: number): void {
    this.value = value
    this.notes = 0
  }

  /** 清空格子内容（value + notes 全清） */
  clear(): void {
    this.value = 0
    this.notes = 0
    this.flags = clearFlag(this.flags, CellFlags.ERROR)
  }

  /** 重置为初始状态 */
  reset(): void {
    this.value = 0
    this.flags = 0
    this.notes = 0
  }
}

/**
 * 创建 9×9 CellData 数组（81 个）
 */
export function createEmptyBoard(): CellData[] {
  const cells: CellData[] = []
  for (let row = 0; row < 9; row++) {
    for (let col = 0; col < 9; col++) {
      cells.push(new CellData(row, col))
    }
  }
  return cells
}

/**
 * 从 number[][] 棋盘初始化 CellData 数组
 * givenBoard 中非 0 的数字标记为 GIVEN
 */
export function createBoardFromArray(givenBoard: number[][]): CellData[] {
  const cells = createEmptyBoard()
  for (let row = 0; row < 9; row++) {
    for (let col = 0; col < 9; col++) {
      const val = givenBoard[row][col]
      if (val !== 0) {
        const cell = cells[row * 9 + col]
        cell.value = val
        cell.flags = setFlag(cell.flags, CellFlags.GIVEN)
      }
    }
  }
  return cells
}
