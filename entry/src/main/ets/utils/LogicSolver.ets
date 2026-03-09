/**
 * LogicSolver.ets — 逻辑求解器
 *
 * 用人类技巧逐步求解数独，记录使用的每一步技巧。
 * 用途：
 *   1. 难度评估（根据所需最高技巧等级标定难度）
 *   2. 提示系统（告诉玩家下一步用什么技巧）
 *
 * 技巧按从简到难排列：
 *   - Naked Single（裸单数）
 *   - Hidden Single（隐性单数）
 *   - Naked Pair（裸对）
 *   - Pointing Pair（指向对）
 *   - Box/Line Reduction（宫行/宫列约简）
 *   - X-Wing
 *
 * 参考：Doc 01 §5-6, Simon Tatham Solo 难度模型
 */
import { GRID_SIZE, TOTAL_CELLS } from '../constants/GameConstants'
import { PEERS, UNITS_OF, ALL_UNITS, rowOf, colOf, boxOf, indexOf } from './Topology'

// ============================================================
// 技巧枚举与分值
// ============================================================

export enum Technique {
  NAKED_SINGLE = 'NakedSingle',
  HIDDEN_SINGLE = 'HiddenSingle',
  NAKED_PAIR = 'NakedPair',
  POINTING_PAIR = 'PointingPair',
  BOX_LINE_REDUCTION = 'BoxLineReduction',
  X_WING = 'XWing',
}

/** 每种技巧的权重分值 */
const TECHNIQUE_SCORE: Record<string, number> = {
  [Technique.NAKED_SINGLE]: 1,
  [Technique.HIDDEN_SINGLE]: 2,
  [Technique.NAKED_PAIR]: 4,
  [Technique.POINTING_PAIR]: 4,
  [Technique.BOX_LINE_REDUCTION]: 5,
  [Technique.X_WING]: 16,
}

/** 技巧的人类可读名称 */
const TECHNIQUE_NAME: Record<string, string> = {
  [Technique.NAKED_SINGLE]: '裸单数',
  [Technique.HIDDEN_SINGLE]: '隐性单数',
  [Technique.NAKED_PAIR]: '裸对',
  [Technique.POINTING_PAIR]: '指向对',
  [Technique.BOX_LINE_REDUCTION]: '宫行约简',
  [Technique.X_WING]: 'X-Wing',
}

// ============================================================
// 求解步骤记录
// ============================================================

/** 求解器执行的一个步骤 */
export class SolveStep {
  /** 使用的技巧 */
  technique: Technique
  /** 受影响的格子索引 */
  cellIndex: number
  /** 填入的数字（如果是 fill 操作）；0 表示仅消除候选 */
  digit: number
  /** 被消除候选的格子和数字列表 */
  eliminations: CandidateElimination[]
  /** 人类可读的描述 */
  description: string

  constructor(
    technique: Technique,
    cellIndex: number,
    digit: number,
    eliminations: CandidateElimination[],
    description: string
  ) {
    this.technique = technique
    this.cellIndex = cellIndex
    this.digit = digit
    this.eliminations = eliminations
    this.description = description
  }
}

/** 一次候选消除 */
export class CandidateElimination {
  cellIndex: number
  digit: number

  constructor(cellIndex: number, digit: number) {
    this.cellIndex = cellIndex
    this.digit = digit
  }
}

// ============================================================
// 逻辑求解结果
// ============================================================

export class LogicSolveResult {
  /** 是否成功解出 */
  solved: boolean
  /** 求解步骤列表 */
  steps: SolveStep[]
  /** 使用过的最高技巧 */
  maxTechnique: Technique | null
  /** 总分值 */
  totalScore: number

  constructor() {
    this.solved = false
    this.steps = []
    this.maxTechnique = null
    this.totalScore = 0
  }
}

// ============================================================
// 位图工具（与 SudokuSolver 一致）
// ============================================================

const ALL_CANDIDATES = (1 << GRID_SIZE) - 1

function bitOf(n: number): number {
  return 1 << (n - 1)
}

function countBits(bits: number): number {
  let count = 0
  let b = bits
  while (b > 0) {
    count += b & 1
    b >>= 1
  }
  return count
}

function getCandidates(bits: number): number[] {
  const result: number[] = []
  for (let n = 1; n <= 9; n++) {
    if ((bits & bitOf(n)) !== 0) {
      result.push(n)
    }
  }
  return result
}

function lowestBit(bits: number): number {
  for (let n = 1; n <= 9; n++) {
    if ((bits & bitOf(n)) !== 0) return n
  }
  return 0
}

// ============================================================
// 候选集初始化
// ============================================================

/** 从 9×9 棋盘初始化候选集（不做约束传播，保持原始候选） */
function initCandidatesFromBoard(board: number[][]): number[] {
  const candidates: number[] = new Array(TOTAL_CELLS).fill(ALL_CANDIDATES)

  // 先标记已填数字
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      const d = board[r][c]
      if (d !== 0) {
        candidates[r * GRID_SIZE + c] = 0 // 已填的格子没有候选
      }
    }
  }

  // 从已填格子消除 peers 的候选
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      const d = board[r][c]
      if (d !== 0) {
        const idx = r * GRID_SIZE + c
        const bit = bitOf(d)
        for (const peer of PEERS[idx]) {
          candidates[peer] &= ~bit
        }
      }
    }
  }

  return candidates
}

// ============================================================
// 行/列 unit 索引（用于 X-Wing 等跨 unit 技巧）
// ============================================================

/** 行 unit 索引 (0-8) */
function getRowUnit(row: number): number[] {
  const unit: number[] = []
  for (let c = 0; c < GRID_SIZE; c++) {
    unit.push(row * GRID_SIZE + c)
  }
  return unit
}

/** 列 unit 索引 (0-8) */
function getColUnit(col: number): number[] {
  const unit: number[] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    unit.push(r * GRID_SIZE + col)
  }
  return unit
}

/** 宫 unit 索引 (0-8) */
function getBoxUnit(box: number): number[] {
  const br = Math.floor(box / 3) * 3
  const bc = (box % 3) * 3
  const unit: number[] = []
  for (let r = br; r < br + 3; r++) {
    for (let c = bc; c < bc + 3; c++) {
      unit.push(r * GRID_SIZE + c)
    }
  }
  return unit
}

// ============================================================
// 技巧实现
// ============================================================

/**
 * Naked Single：候选只剩 1 个的格子
 * 返回找到的第一个 step，或 null
 */
function findNakedSingle(candidates: number[]): SolveStep | null {
  for (let i = 0; i < TOTAL_CELLS; i++) {
    if (countBits(candidates[i]) === 1) {
      const d = lowestBit(candidates[i])
      const r = rowOf(i)
      const c = colOf(i)
      return new SolveStep(
        Technique.NAKED_SINGLE,
        i,
        d,
        [],
        `R${r + 1}C${c + 1} 只剩候选数 ${d}，直接填入`
      )
    }
  }
  return null
}

/**
 * Hidden Single：某个 unit 中某数字只有一个位置能放
 */
function findHiddenSingle(candidates: number[]): SolveStep | null {
  for (const unit of ALL_UNITS) {
    for (let d = 1; d <= 9; d++) {
      const bit = bitOf(d)
      let count = 0
      let place = -1
      for (const idx of unit) {
        if ((candidates[idx] & bit) !== 0) {
          count++
          place = idx
          if (count > 1) break
        }
      }
      if (count === 1) {
        // 确认这个格还没被确定
        if (countBits(candidates[place]) > 1) {
          const r = rowOf(place)
          const c = colOf(place)
          return new SolveStep(
            Technique.HIDDEN_SINGLE,
            place,
            d,
            [],
            `数字 ${d} 在其所在区域中只能放在 R${r + 1}C${c + 1}`
          )
        }
      }
    }
  }
  return null
}

/**
 * Naked Pair：同一 unit 中两个格子的候选集完全相同且只有 2 个候选
 * → 从该 unit 的其他格子中消除这两个候选
 */
function findNakedPair(candidates: number[]): SolveStep | null {
  for (const unit of ALL_UNITS) {
    // 收集候选数恰好为 2 的格子
    const pairs: number[] = []
    for (const idx of unit) {
      if (countBits(candidates[idx]) === 2) {
        pairs.push(idx)
      }
    }

    // 检查是否有两个格子候选集相同
    for (let a = 0; a < pairs.length; a++) {
      for (let b = a + 1; b < pairs.length; b++) {
        if (candidates[pairs[a]] === candidates[pairs[b]]) {
          const pairBits = candidates[pairs[a]]
          const digits = getCandidates(pairBits)

          // 看其他格子是否有这些候选可以消除
          const eliminations: CandidateElimination[] = []
          for (const idx of unit) {
            if (idx === pairs[a] || idx === pairs[b]) continue
            for (const d of digits) {
              if ((candidates[idx] & bitOf(d)) !== 0) {
                eliminations.push(new CandidateElimination(idx, d))
              }
            }
          }

          if (eliminations.length > 0) {
            const r1 = rowOf(pairs[a])
            const c1 = colOf(pairs[a])
            const r2 = rowOf(pairs[b])
            const c2 = colOf(pairs[b])
            return new SolveStep(
              Technique.NAKED_PAIR,
              pairs[a],
              0,
              eliminations,
              `R${r1 + 1}C${c1 + 1} 和 R${r2 + 1}C${c2 + 1} 形成裸对 {${digits.join(',')}}`
            )
          }
        }
      }
    }
  }
  return null
}

/**
 * Pointing Pair：宫内某数字的所有候选位置都在同一行/列
 * → 该行/列的其他宫中消除该数字
 */
function findPointingPair(candidates: number[]): SolveStep | null {
  for (let box = 0; box < 9; box++) {
    const boxCells = getBoxUnit(box)

    for (let d = 1; d <= 9; d++) {
      const bit = bitOf(d)
      // 找出宫内所有能放 d 的位置
      const positions: number[] = []
      for (const idx of boxCells) {
        if ((candidates[idx] & bit) !== 0) {
          positions.push(idx)
        }
      }

      if (positions.length < 2 || positions.length > 3) continue

      // 检查是否都在同一行
      const rows = new Set<number>()
      const cols = new Set<number>()
      for (const idx of positions) {
        rows.add(rowOf(idx))
        cols.add(colOf(idx))
      }

      if (rows.size === 1) {
        // 都在同一行 → 消除该行其他宫的 d
        const row = rowOf(positions[0])
        const eliminations: CandidateElimination[] = []
        for (let c = 0; c < GRID_SIZE; c++) {
          const idx = indexOf(row, c)
          if (boxOf(idx) !== box && (candidates[idx] & bit) !== 0) {
            eliminations.push(new CandidateElimination(idx, d))
          }
        }
        if (eliminations.length > 0) {
          return new SolveStep(
            Technique.POINTING_PAIR,
            positions[0],
            0,
            eliminations,
            `宫${box + 1} 中数字 ${d} 只能在第 ${row + 1} 行 → 该行其他位置排除 ${d}`
          )
        }
      }

      if (cols.size === 1) {
        // 都在同一列 → 消除该列其他宫的 d
        const col = colOf(positions[0])
        const eliminations: CandidateElimination[] = []
        for (let r = 0; r < GRID_SIZE; r++) {
          const idx = indexOf(r, col)
          if (boxOf(idx) !== box && (candidates[idx] & bit) !== 0) {
            eliminations.push(new CandidateElimination(idx, d))
          }
        }
        if (eliminations.length > 0) {
          return new SolveStep(
            Technique.POINTING_PAIR,
            positions[0],
            0,
            eliminations,
            `宫${box + 1} 中数字 ${d} 只能在第 ${col + 1} 列 → 该列其他位置排除 ${d}`
          )
        }
      }
    }
  }
  return null
}

/**
 * Box/Line Reduction：某行/列中某数字的候选位置都在同一宫
 * → 该宫的其他行/列消除该数字
 */
function findBoxLineReduction(candidates: number[]): SolveStep | null {
  // 检查行
  for (let row = 0; row < GRID_SIZE; row++) {
    for (let d = 1; d <= 9; d++) {
      const bit = bitOf(d)
      const positions: number[] = []
      for (let c = 0; c < GRID_SIZE; c++) {
        const idx = indexOf(row, c)
        if ((candidates[idx] & bit) !== 0) {
          positions.push(idx)
        }
      }
      if (positions.length < 2 || positions.length > 3) continue

      const boxes = new Set<number>()
      for (const idx of positions) {
        boxes.add(boxOf(idx))
      }

      if (boxes.size === 1) {
        const box = boxOf(positions[0])
        const boxCells = getBoxUnit(box)
        const eliminations: CandidateElimination[] = []
        for (const idx of boxCells) {
          if (rowOf(idx) !== row && (candidates[idx] & bit) !== 0) {
            eliminations.push(new CandidateElimination(idx, d))
          }
        }
        if (eliminations.length > 0) {
          return new SolveStep(
            Technique.BOX_LINE_REDUCTION,
            positions[0],
            0,
            eliminations,
            `第 ${row + 1} 行中数字 ${d} 只在宫${box + 1} → 宫内其他行排除 ${d}`
          )
        }
      }
    }
  }

  // 检查列
  for (let col = 0; col < GRID_SIZE; col++) {
    for (let d = 1; d <= 9; d++) {
      const bit = bitOf(d)
      const positions: number[] = []
      for (let r = 0; r < GRID_SIZE; r++) {
        const idx = indexOf(r, col)
        if ((candidates[idx] & bit) !== 0) {
          positions.push(idx)
        }
      }
      if (positions.length < 2 || positions.length > 3) continue

      const boxes = new Set<number>()
      for (const idx of positions) {
        boxes.add(boxOf(idx))
      }

      if (boxes.size === 1) {
        const box = boxOf(positions[0])
        const boxCells = getBoxUnit(box)
        const eliminations: CandidateElimination[] = []
        for (const idx of boxCells) {
          if (colOf(idx) !== col && (candidates[idx] & bit) !== 0) {
            eliminations.push(new CandidateElimination(idx, d))
          }
        }
        if (eliminations.length > 0) {
          return new SolveStep(
            Technique.BOX_LINE_REDUCTION,
            positions[0],
            0,
            eliminations,
            `第 ${col + 1} 列中数字 ${d} 只在宫${box + 1} → 宫内其他列排除 ${d}`
          )
        }
      }
    }
  }

  return null
}

/**
 * X-Wing：某数字在两行中各只有两个候选列，且列编号相同
 * → 这两列的其他行消除该数字
 */
function findXWing(candidates: number[]): SolveStep | null {
  for (let d = 1; d <= 9; d++) {
    const bit = bitOf(d)

    // --- 行方向 X-Wing ---
    // 对每行记录 d 的候选列
    const rowPositions: number[][] = []
    for (let r = 0; r < GRID_SIZE; r++) {
      const cols: number[] = []
      for (let c = 0; c < GRID_SIZE; c++) {
        if ((candidates[indexOf(r, c)] & bit) !== 0) {
          cols.push(c)
        }
      }
      rowPositions.push(cols)
    }

    // 找两行候选列完全相同且恰好 2 列
    for (let r1 = 0; r1 < GRID_SIZE; r1++) {
      if (rowPositions[r1].length !== 2) continue
      for (let r2 = r1 + 1; r2 < GRID_SIZE; r2++) {
        if (rowPositions[r2].length !== 2) continue
        if (rowPositions[r1][0] === rowPositions[r2][0] &&
            rowPositions[r1][1] === rowPositions[r2][1]) {
          const c1 = rowPositions[r1][0]
          const c2 = rowPositions[r1][1]

          // 消除这两列中其他行的 d
          const eliminations: CandidateElimination[] = []
          for (let r = 0; r < GRID_SIZE; r++) {
            if (r === r1 || r === r2) continue
            for (const c of [c1, c2]) {
              const idx = indexOf(r, c)
              if ((candidates[idx] & bit) !== 0) {
                eliminations.push(new CandidateElimination(idx, d))
              }
            }
          }

          if (eliminations.length > 0) {
            return new SolveStep(
              Technique.X_WING,
              indexOf(r1, c1),
              0,
              eliminations,
              `数字 ${d} 在第 ${r1 + 1},${r2 + 1} 行形成 X-Wing (列 ${c1 + 1},${c2 + 1})`
            )
          }
        }
      }
    }

    // --- 列方向 X-Wing ---
    const colPositions: number[][] = []
    for (let c = 0; c < GRID_SIZE; c++) {
      const rows: number[] = []
      for (let r = 0; r < GRID_SIZE; r++) {
        if ((candidates[indexOf(r, c)] & bit) !== 0) {
          rows.push(r)
        }
      }
      colPositions.push(rows)
    }

    for (let c1 = 0; c1 < GRID_SIZE; c1++) {
      if (colPositions[c1].length !== 2) continue
      for (let c2 = c1 + 1; c2 < GRID_SIZE; c2++) {
        if (colPositions[c2].length !== 2) continue
        if (colPositions[c1][0] === colPositions[c2][0] &&
            colPositions[c1][1] === colPositions[c2][1]) {
          const r1 = colPositions[c1][0]
          const r2 = colPositions[c1][1]

          const eliminations: CandidateElimination[] = []
          for (let c = 0; c < GRID_SIZE; c++) {
            if (c === c1 || c === c2) continue
            for (const r of [r1, r2]) {
              const idx = indexOf(r, c)
              if ((candidates[idx] & bit) !== 0) {
                eliminations.push(new CandidateElimination(idx, d))
              }
            }
          }

          if (eliminations.length > 0) {
            return new SolveStep(
              Technique.X_WING,
              indexOf(r1, c1),
              0,
              eliminations,
              `数字 ${d} 在第 ${c1 + 1},${c2 + 1} 列形成 X-Wing (行 ${r1 + 1},${r2 + 1})`
            )
          }
        }
      }
    }
  }

  return null
}

// ============================================================
// 应用步骤到候选集
// ============================================================

/**
 * 将一个填数步骤应用到候选集和 board 上
 */
function applyStep(
  candidates: number[],
  board: number[][],
  step: SolveStep
): void {
  if (step.digit !== 0) {
    // 填数操作
    const r = rowOf(step.cellIndex)
    const c = colOf(step.cellIndex)
    board[r][c] = step.digit
    candidates[step.cellIndex] = 0

    // 从 peers 中消除该数字
    const bit = bitOf(step.digit)
    for (const peer of PEERS[step.cellIndex]) {
      candidates[peer] &= ~bit
    }
  }

  // 应用消除
  for (const elim of step.eliminations) {
    candidates[elim.cellIndex] &= ~bitOf(elim.digit)
  }
}

// ============================================================
// 主求解循环
// ============================================================

/** 技巧查找函数列表（按从简到难排序） */
type TechniqueFinder = (candidates: number[]) => SolveStep | null

const TECHNIQUE_FINDERS: TechniqueFinder[] = [
  findNakedSingle,
  findHiddenSingle,
  findNakedPair,
  findPointingPair,
  findBoxLineReduction,
  findXWing,
]

/**
 * 逻辑求解器主函数。
 *
 * 按从简到难的顺序尝试技巧，找到就应用并回到最简技巧重新尝试。
 * 如果所有技巧都用尽仍有空格 → solved = false（需要猜测/回溯）。
 *
 * @param board 9×9 棋盘（0 表示空格）—— 会被修改
 * @returns 求解结果（步骤列表、最高技巧、总分）
 */
export function logicSolve(board: number[][]): LogicSolveResult {
  const result = new LogicSolveResult()
  const candidates = initCandidatesFromBoard(board)

  let maxIter = 1000 // 防止死循环
  while (maxIter-- > 0) {
    // 检查是否已解完
    let allFilled = true
    for (let r = 0; r < GRID_SIZE; r++) {
      for (let c = 0; c < GRID_SIZE; c++) {
        if (board[r][c] === 0) {
          allFilled = false
          break
        }
      }
      if (!allFilled) break
    }
    if (allFilled) {
      result.solved = true
      break
    }

    // 按顺序尝试技巧
    let found = false
    for (const finder of TECHNIQUE_FINDERS) {
      const step = finder(candidates)
      if (step !== null) {
        applyStep(candidates, board, step)
        result.steps.push(step)
        result.totalScore += TECHNIQUE_SCORE[step.technique] || 0

        // 更新最高技巧
        if (result.maxTechnique === null ||
            TECHNIQUE_SCORE[step.technique] > TECHNIQUE_SCORE[result.maxTechnique]) {
          result.maxTechnique = step.technique
        }

        found = true
        break // 回到最简技巧重新开始
      }
    }

    if (!found) {
      // 所有技巧用尽，仍有空格
      break
    }
  }

  return result
}

/**
 * 获取下一步提示。
 * 返回下一个可用的求解步骤，不修改棋盘。
 */
export function getNextHint(board: number[][]): SolveStep | null {
  const candidates = initCandidatesFromBoard(board)

  for (const finder of TECHNIQUE_FINDERS) {
    const step = finder(candidates)
    if (step !== null) {
      return step
    }
  }

  return null
}

/**
 * 获取技巧的人类可读名称
 */
export function getTechniqueName(technique: Technique): string {
  return TECHNIQUE_NAME[technique] || technique
}

/**
 * 获取技巧的分值
 */
export function getTechniqueScore(technique: Technique): number {
  return TECHNIQUE_SCORE[technique] || 0
}
