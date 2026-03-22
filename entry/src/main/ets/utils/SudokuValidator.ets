/**
 * SudokuValidator.ets — 验证工具
 *
 * 负责：
 *   - 冲突检测（某格填入后与同行/列/宫是否重复）
 *   - 全局冲突扫描（高亮所有冲突格）
 *   - 完成判定（81 格全填满且无冲突）
 *
 * 参考：Doc 01 §1, Doc 03 任务 1.7
 */
import { CellData, CellFlags, hasFlag, setFlag, clearFlag } from '../models/CellData'
import { KillerCage } from '../models/VariantConfig'
import { PEERS } from './Topology'
import { TOTAL_CELLS } from '../constants/GameConstants'

// ============================================================
// 冲突检测
// ============================================================

/**
 * 检查指定格子是否与某个 peer 冲突。
 * 规则：两个格子的 value 都非 0 且相等 → 冲突。
 */
function hasConflictWith(cells: CellData[], index: number): boolean {
  const val = cells[index].value
  if (val === 0) return false

  for (const peer of PEERS[index]) {
    if (cells[peer].value === val) {
      return true
    }
  }
  return false
}

function collectCageSumErrors(cells: CellData[], cages?: KillerCage[]): boolean[] {
  const cageErrors: boolean[] = new Array(TOTAL_CELLS).fill(false)
  if (cages === undefined || cages.length === 0) {
    return cageErrors
  }

  for (const cage of cages) {
    if (cage.sum <= 0 || cage.cells.length === 0) {
      continue
    }

    let filledSum = 0
    let filledCount = 0
    const playerFilledCells: number[] = []
    const filledCells: number[] = []

    for (const cellIndex of cage.cells) {
      if (cellIndex < 0 || cellIndex >= TOTAL_CELLS) {
        continue
      }
      const cell = cells[cellIndex]
      if (cell.value === 0) {
        continue
      }
      filledSum += cell.value
      filledCount++
      filledCells.push(cellIndex)
      if (!cell.isGiven) {
        playerFilledCells.push(cellIndex)
      }
    }

    const exceedsTarget = filledSum > cage.sum
    const filledButWrongSum = filledCount === cage.cells.length && filledSum !== cage.sum
    if (!exceedsTarget && !filledButWrongSum) {
      continue
    }

    const targets = playerFilledCells.length > 0 ? playerFilledCells : filledCells
    for (const cellIndex of targets) {
      cageErrors[cellIndex] = true
    }
  }

  return cageErrors
}

function allCageSumsSatisfied(cells: CellData[], cages?: KillerCage[]): boolean {
  if (cages === undefined || cages.length === 0) {
    return true
  }

  for (const cage of cages) {
    if (cage.sum <= 0 || cage.cells.length === 0) {
      continue
    }

    let sum = 0
    for (const cellIndex of cage.cells) {
      if (cellIndex < 0 || cellIndex >= TOTAL_CELLS) {
        return false
      }
      const cell = cells[cellIndex]
      if (cell.value === 0) {
        return false
      }
      sum += cell.value
    }

    if (sum !== cage.sum) {
      return false
    }
  }

  return true
}

/**
 * 扫描全部 81 格，更新每个格子的 ERROR 标志。
 * 应该在每次玩家操作后调用。
 *
 * 当提供 solution 时，还会将与答案不符的用户填入格标记为错误
 * （即使该格没有同行/列/宫的重复冲突）。
 *
 * 返回冲突格的数量（用于统计）。
 */
export function validateAllCells(cells: CellData[], solution?: number[], cages?: KillerCage[]): number {
  let errorCount = 0
  const cageErrors = collectCageSumErrors(cells, cages)

  for (let i = 0; i < TOTAL_CELLS; i++) {
    const hasPeerConflict = hasConflictWith(cells, i)
    const hasCageSumConflict = cageErrors[i]
    // 若提供了答案，也检查用户填入的数字是否与答案不符
    const hasSolutionMismatch = solution !== undefined &&
      solution.length > i &&
      cells[i].value !== 0 &&
      !cells[i].isGiven &&
      cells[i].value !== solution[i]

    if (hasPeerConflict || hasSolutionMismatch || hasCageSumConflict) {
      cells[i].flags = setFlag(cells[i].flags, CellFlags.ERROR)
      errorCount++
    } else {
      cells[i].flags = clearFlag(cells[i].flags, CellFlags.ERROR)
    }
  }

  return errorCount
}

/**
 * 检查单个格子是否与答案匹配。
 * 用于"错误计数"模式——玩家填入的数字如果和 solution 不符就算一次错误。
 */
export function isCorrectValue(cells: CellData[], index: number, solution: number[]): boolean {
  return cells[index].value === solution[index]
}

// ============================================================
// 完成判定
// ============================================================

/**
 * 判断游戏是否完成（所有格子都填满且无冲突）
 */
export function isGameCompleted(cells: CellData[], cages?: KillerCage[]): boolean {
  for (let i = 0; i < TOTAL_CELLS; i++) {
    // 还有空格 → 未完成
    if (cells[i].value === 0) return false
    // 有冲突 → 未完成
    if (hasConflictWith(cells, i)) return false
  }
  return allCageSumsSatisfied(cells, cages)
}

/**
 * 判断游戏是否完成（对照答案版本，更严格）
 */
export function isGameCompletedWithSolution(cells: CellData[], solution: number[]): boolean {
  for (let i = 0; i < TOTAL_CELLS; i++) {
    if (cells[i].value !== solution[i]) return false
  }
  return true
}

// ============================================================
// 高亮辅助
// ============================================================

/**
 * 更新高亮状态：选中格 + 同行/列/宫 + 同数字。
 * 每次选中格变化时调用。
 *
 * @param cells 81 个格子
 * @param selectedIndex 选中格索引，-1 表示无选中
 */
export function updateHighlights(cells: CellData[], selectedIndex: number): void {
  // 先清除所有高亮和选中标志
  for (let i = 0; i < TOTAL_CELLS; i++) {
    cells[i].flags = clearFlag(cells[i].flags, CellFlags.SELECTED)
    cells[i].flags = clearFlag(cells[i].flags, CellFlags.HIGHLIGHTED)
  }

  if (selectedIndex < 0 || selectedIndex >= TOTAL_CELLS) return

  // 设置选中格
  cells[selectedIndex].flags = setFlag(cells[selectedIndex].flags, CellFlags.SELECTED)

  // 高亮 peers（同行/列/宫）
  for (const peer of PEERS[selectedIndex]) {
    cells[peer].flags = setFlag(cells[peer].flags, CellFlags.HIGHLIGHTED)
  }

  // 如果选中格有数字，高亮所有同数字格
  // （通过同数字高亮用 cellSameNumber 颜色覆盖 cellHighlight，
  //   在 SudokuCell 渲染时判断优先级）
  const val = cells[selectedIndex].value
  if (val !== 0) {
    for (let i = 0; i < TOTAL_CELLS; i++) {
      if (i !== selectedIndex && cells[i].value === val) {
        // 这里复用 HIGHLIGHTED flag，SudokuCell 渲染时根据 value 是否相同来区分颜色
        cells[i].flags = setFlag(cells[i].flags, CellFlags.HIGHLIGHTED)
      }
    }
  }
}
