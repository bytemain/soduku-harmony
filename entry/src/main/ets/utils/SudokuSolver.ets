/**
 * SudokuSolver.ets — 暴力求解器
 *
 * Norvig 风格：约束传播 + DFS + MRV 启发式。
 * 用于：生成终盘验证唯一解、"自动解题"功能。
 * 不用于提示（提示需要逻辑求解器，Phase 2）。
 *
 * 内部用一维 candidates 数组（位图），每个格子 9 bit 表示候选数。
 * bit 0 = 数字 1，bit 8 = 数字 9。
 *
 * 参考：Doc 01 §4, Doc 04 §3-5
 */
import { GRID_SIZE, TOTAL_CELLS } from '../constants/GameConstants'
import { PEERS, UNITS_OF } from './Topology'
import { SeededRandom } from './Common'

// ============================================================
// 位图候选集工具
// ============================================================

/** 全部候选位图：根据当前 GRID_SIZE 动态计算，6×6 → 63，9×9 → 511 */
function allCandidatesMask(): number {
  return (1 << GRID_SIZE) - 1
}

/** 数字 n(1-9) 对应的 bit mask */
function bitOf(n: number): number {
  return 1 << (n - 1)
}

/** 候选集中有多少个候选 */
function countBits(bits: number): number {
  let count = 0
  let b = bits
  while (b > 0) {
    count += b & 1
    b >>= 1
  }
  return count
}

/** 获取候选集中最小的候选数字，没有返回 0 */
function lowestBit(bits: number): number {
  for (let n = 1; n <= GRID_SIZE; n++) {
    if ((bits & bitOf(n)) !== 0) return n
  }
  return 0
}

/** 候选集迭代器：返回所有候选数字 */
function getCandidates(bits: number): number[] {
  const result: number[] = []
  for (let n = 1; n <= GRID_SIZE; n++) {
    if ((bits & bitOf(n)) !== 0) {
      result.push(n)
    }
  }
  return result
}

// ============================================================
// 约束传播
// ============================================================

/**
 * 从格子 s 的候选中消除数字 d，并传播后果。
 * 返回 false 表示产生矛盾（无解分支）。
 *
 * 内部同时检查两条策略：
 *   1. Naked Single：候选只剩 1 个 → 从 peers 中消除
 *   2. Hidden Single：某 unit 中某数字只有 1 个位置 → 填入
 */
function eliminate(candidates: number[], s: number, d: number): boolean {
  const bit = bitOf(d)

  // d 已不在候选中，无需操作
  if ((candidates[s] & bit) === 0) {
    return true
  }

  // 移除候选
  candidates[s] &= ~bit
  const remaining = candidates[s]

  // ❌ 候选清空 → 矛盾
  if (remaining === 0) {
    return false
  }

  // --- 策略 1：Naked Single ---
  if (countBits(remaining) === 1) {
    const d2 = lowestBit(remaining)
    for (const peer of PEERS[s]) {
      if (!eliminate(candidates, peer, d2)) {
        return false
      }
    }
  }

  // --- 策略 2：Hidden Single ---
  for (const unit of UNITS_OF[s]) {
    // d 在这个 unit 还有哪些位置能放？
    let count = 0
    let place = -1
    for (const sq of unit) {
      if ((candidates[sq] & bit) !== 0) {
        count++
        place = sq
        if (count > 1) break  // 超过 1 个就不用看了
      }
    }

    if (count === 0) {
      return false  // ❌ d 在此 unit 无处可放
    }
    if (count === 1) {
      // d 只有一个位置 → 填入
      if (!fill(candidates, place, d)) {
        return false
      }
    }
  }

  return true
}

/**
 * 在格子 s 填入数字 d = 消除 s 的所有其他候选
 */
function fill(candidates: number[], s: number, d: number): boolean {
  const others = getCandidates(candidates[s] & ~bitOf(d))
  for (const d2 of others) {
    if (!eliminate(candidates, s, d2)) {
      return false
    }
  }
  return true
}

// ============================================================
// 从 9×9 棋盘初始化候选集
// ============================================================

/**
 * 把 board 转化为约束传播后的 candidates。
 * 返回 null 表示题目本身有矛盾。
 */
function initCandidates(board: number[][]): number[] | null {
  // 所有格子初始为全候选
  const candidates: number[] = new Array(TOTAL_CELLS).fill(allCandidatesMask())

  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      const d = board[r][c]
      if (d !== 0) {
        if (!fill(candidates, r * GRID_SIZE + c, d)) {
          return null // 题目矛盾
        }
      }
    }
  }

  return candidates
}

// ============================================================
// DFS 搜索
// ============================================================

/**
 * 深度优先搜索，带 MRV 启发式。
 * 返回解出的 candidates，或 null 表示无解。
 */
function search(candidates: number[]): number[] | null {
  // 检查是否全部确定
  let allDetermined = true
  let minCount = 10
  let minIndex = -1

  for (let i = 0; i < TOTAL_CELLS; i++) {
    const cnt = countBits(candidates[i])
    if (cnt > 1) {
      allDetermined = false
      if (cnt < minCount) {
        minCount = cnt
        minIndex = i
      }
    }
  }

  if (allDetermined) {
    return candidates // 🎉 全部确定
  }

  // MRV：选候选最少的格子
  const nums = getCandidates(candidates[minIndex])

  for (const d of nums) {
    // 浅拷贝候选（number[] 拷贝是安全的）
    const copy = candidates.slice()
    if (fill(copy, minIndex, d)) {
      const result = search(copy)
      if (result !== null) {
        return result
      }
    }
  }

  return null // 所有候选都试过了，此路不通
}

// ============================================================
// 对外接口
// ============================================================

/**
 * 求解数独。返回解（9×9），或 null 表示无解。
 */
export function solve(board: number[][]): number[][] | null {
  const candidates = initCandidates(board)
  if (candidates === null) return null

  const result = search(candidates)
  if (result === null) return null

  // candidates → 9×9 棋盘
  const solution: number[][] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    const row: number[] = []
    for (let c = 0; c < GRID_SIZE; c++) {
      row.push(lowestBit(result[r * GRID_SIZE + c]))
    }
    solution.push(row)
  }
  return solution
}

/**
 * DFS helper for countSolutions — extracted to module level (arkts-no-nested-funcs).
 * counter[0] tracks solution count, counter[1] is maxCount limit.
 */
function countDfs(cands: number[], counter: number[]): void {
  if (counter[0] >= counter[1]) return

  // 找候选最少的未确定格
  let minCount = 10
  let minIndex = -1

  for (let i = 0; i < TOTAL_CELLS; i++) {
    const cnt = countBits(cands[i])
    if (cnt === 0) return // 矛盾
    if (cnt > 1) {
      if (cnt < minCount) {
        minCount = cnt
        minIndex = i
      }
    }
  }

  if (minIndex === -1) {
    // 全部确定 → 找到一个解
    counter[0]++
    return
  }

  const nums = getCandidates(cands[minIndex])
  for (const d of nums) {
    if (counter[0] >= counter[1]) return
    const copy = cands.slice()
    if (fill(copy, minIndex, d)) {
      countDfs(copy, counter)
    }
  }
}

/**
 * 计算解的数量（最多数到 maxCount 就停）。
 * 用于验证唯一解：countSolutions(board, 2)，返回 1 则唯一。
 */
export function countSolutions(board: number[][], maxCount: number = 2): number {
  const candidates = initCandidates(board)
  if (candidates === null) return 0

  const counter: number[] = [0, maxCount]
  countDfs(candidates, counter)
  return counter[0]
}

/**
 * 检查棋盘是否有解
 */
export function hasSolution(board: number[][]): boolean {
  return solve(board) !== null
}

/**
 * 检查是否唯一解
 */
export function hasUniqueSolution(board: number[][]): boolean {
  return countSolutions(board, 2) === 1
}

// ============================================================
// 随机终盘生成（Norvig 约束传播 + 随机 DFS）
// ============================================================

/**
 * 随机搜索：约束传播 + DFS + MRV，候选尝试顺序随机化。
 * 用于生成随机完整终盘，比 fillBoard 的朴素回溯快 10-100 倍。
 *
 * 与 search() 的唯一区别：每次分支时对候选数字做 Fisher-Yates 洗牌，
 * 从而每次调用产生不同的随机终盘。
 */
function randomSearch(candidates: number[], rng: SeededRandom): number[] | null {
  let allDetermined = true
  let minCount = 10
  let minIndex = -1

  for (let i = 0; i < TOTAL_CELLS; i++) {
    const cnt = countBits(candidates[i])
    if (cnt > 1) {
      allDetermined = false
      if (cnt < minCount) {
        minCount = cnt
        minIndex = i
      }
    }
  }

  if (allDetermined) {
    return candidates
  }

  // MRV：选候选最少的格子，随机打乱候选顺序
  const nums = getCandidates(candidates[minIndex])
  // Fisher-Yates shuffle with seeded RNG
  for (let i = nums.length - 1; i > 0; i--) {
    const j = rng.nextInt(i + 1)
    const tmp = nums[i]
    nums[i] = nums[j]
    nums[j] = tmp
  }

  for (const d of nums) {
    const copy = candidates.slice()
    if (fill(copy, minIndex, d)) {
      const result = randomSearch(copy, rng)
      if (result !== null) {
        return result
      }
    }
  }

  return null
}

/**
 * 使用 Norvig 约束传播 + 随机 DFS 生成随机完整终盘。
 *
 * 核心优势：
 *   - 约束传播（Naked Single + Hidden Single）在每次"猜测"后自动连锁推导，
 *     大幅减少搜索空间。标准数独通常 0-5 次猜测即可填满。
 *   - MRV 启发式选择候选最少的格子优先猜测，搜索树规模从指数级降到线性。
 *   - 对 Jigsaw 等不规则拓扑尤其有效：朴素回溯可能需要数万次回退，
 *     而约束传播利用 PEERS/UNITS_OF 一次性消除大量候选，通常 <100ms 完成。
 *
 * @param rng 可播种随机数生成器，保证同 seed 生成同一终盘
 * @returns 完整终盘（9×9 二维数组）
 */
export function generateRandomSolution(rng: SeededRandom): number[][] | null {
  // 全空棋盘 → 所有格子都是全候选
  const candidates: number[] = new Array(TOTAL_CELLS).fill(allCandidatesMask())

  const result = randomSearch(candidates, rng)
  if (result === null) return null

  // candidates → 二维数组
  const board: number[][] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    const row: number[] = []
    for (let c = 0; c < GRID_SIZE; c++) {
      row.push(lowestBit(result[r * GRID_SIZE + c]))
    }
    board.push(row)
  }
  return board
}
