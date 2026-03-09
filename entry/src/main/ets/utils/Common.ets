/**
 * Common.ets — 通用工具函数
 *
 * 放一些到处都要用的小工具：数组洗牌、棋盘拷贝、随机数等。
 * 纯函数，无状态，方便测试。
 *
 * 参考：Doc 01 §3, Doc 03 任务 1.4
 */
import { GRID_SIZE } from '../constants/GameConstants'

// ============================================================
// 可播种伪随机数生成器（Mulberry32）
// ============================================================

/**
 * Mulberry32 — 高质量 32-bit PRNG，周期 2^32。
 * 相同 seed 保证产生完全相同的随机序列，
 * 用于从 seed 重现同一道数独题。
 */
export class SeededRandom {
  private state: number

  constructor(seed: number) {
    this.state = seed | 0
  }

  /** 返回 [0, 1) */
  next(): number {
    this.state = (this.state + 0x6D2B79F5) | 0
    let t = Math.imul(this.state ^ (this.state >>> 15), 1 | this.state)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }

  /** 返回 [0, max) 整数 */
  nextInt(max: number): number {
    return Math.floor(this.next() * max)
  }
}

/**
 * 生成一个随机种子（用于首次生成）
 */
export function randomSeed(): number {
  return Math.floor(Math.random() * 0x7FFFFFFF)
}

// ============================================================
// Fisher-Yates 洗牌 — 原地打乱数组
// ============================================================

/**
 * Fisher-Yates shuffle，O(n) 原地洗牌。
 * 返回同一个数组引用（方便链式调用）。
 *
 * 为什么不用 sort(() => Math.random() - 0.5)？
 * 因为那个方法的分布不均匀，某些元素出现在前面的概率更高。
 * Fisher-Yates 保证完美均匀。
 */
export function shuffle<T>(arr: T[]): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    const temp = arr[i]
    arr[i] = arr[j]
    arr[j] = temp
  }
  return arr
}

/**
 * 带种子的 Fisher-Yates shuffle。
 * 使用 SeededRandom 代替 Math.random()，保证可复现。
 */
export function seededShuffle<T>(arr: T[], rng: SeededRandom): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = rng.nextInt(i + 1)
    const temp = arr[i]
    arr[i] = arr[j]
    arr[j] = temp
  }
  return arr
}

// ============================================================
// 棋盘操作
// ============================================================

/** 创建空的 9×9 棋盘（全 0） */
export function createEmptyGrid(): number[][] {
  const grid: number[][] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    const row: number[] = []
    for (let c = 0; c < GRID_SIZE; c++) {
      row.push(0)
    }
    grid.push(row)
  }
  return grid
}

/** 深拷贝 9×9 棋盘 */
export function cloneGrid(grid: number[][]): number[][] {
  const copy: number[][] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    const row: number[] = []
    for (let c = 0; c < GRID_SIZE; c++) {
      row.push(grid[r][c])
    }
    copy.push(row)
  }
  return copy
}

/** 一维数组(81) → 二维数组(9×9) */
export function flatToGrid(flat: number[]): number[][] {
  const grid: number[][] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    const row: number[] = []
    for (let c = 0; c < GRID_SIZE; c++) {
      row.push(flat[r * GRID_SIZE + c])
    }
    grid.push(row)
  }
  return grid
}

/** 二维数组(9×9) → 一维数组(81) */
export function gridToFlat(grid: number[][]): number[] {
  const flat: number[] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      flat.push(grid[r][c])
    }
  }
  return flat
}

// ============================================================
// 验证工具
// ============================================================

/**
 * 检查在 board[row][col] 填入 num 是否合法
 * （同行、同列、同宫不能有重复）
 */
export function isValidPlacement(board: number[][], row: number, col: number, num: number): boolean {
  // 检查行
  for (let c = 0; c < GRID_SIZE; c++) {
    if (board[row][c] === num) return false
  }
  // 检查列
  for (let r = 0; r < GRID_SIZE; r++) {
    if (board[r][col] === num) return false
  }
  // 检查宫
  const br = Math.floor(row / 3) * 3
  const bc = Math.floor(col / 3) * 3
  for (let r = br; r < br + 3; r++) {
    for (let c = bc; c < bc + 3; c++) {
      if (board[r][c] === num) return false
    }
  }
  return true
}

// ============================================================
// 数组工具
// ============================================================

/** 生成 [1, 2, ..., 9] */
export function digits1to9(): number[] {
  return [1, 2, 3, 4, 5, 6, 7, 8, 9]
}

/** 获取所有已填数字位置的 [row, col] 列表 */
export function getAllFilledPositions(board: number[][]): number[][] {
  const positions: number[][] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      if (board[r][c] !== 0) {
        positions.push([r, c])
      }
    }
  }
  return positions
}

/** 查找第一个空格 [row, col]，没有则返回 null */
export function findFirstEmpty(board: number[][]): number[] | null {
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      if (board[r][c] === 0) {
        return [r, c]
      }
    }
  }
  return null
}
