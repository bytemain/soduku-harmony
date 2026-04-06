/**
 * SudokuValidator.ets — 验证工具
 *
 * 负责：
 *   - 冲突检测（某格填入后与同行/列/宫是否重复）
 *   - Killer 笼子求和约束检测
 *   - 全局冲突扫描（高亮所有冲突格）
 *   - 完成判定（81 格全填满且无冲突）
 *
 * 参考：Doc 01 §1, Doc 03 任务 1.7
 */
import { CellData, CellFlags, hasFlag, setFlag, clearFlag } from '../models/CellData'
import { PEERS } from './Topology'
import { TOTAL_CELLS } from '../constants/GameConstants'
import { KillerCage } from '../models/VariantConfig'

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

// ============================================================
// Killer 笼子约束
// ============================================================

/**
 * 检查某个格子所在的笼子是否存在和约束错误。
 * 当笼子内全部填满后，总和必须等于 cage.sum。
 * 部分填入时不标记和约束错误（仅靠 peer/topology 检查重复）。
 */
function hasCageSumError(cells: CellData[], index: number, cages: KillerCage[],
  cageIndexByCell: number[]): boolean {
  const ci = cageIndexByCell[index]
  if (ci < 0) return false
  const cage = cages[ci]

  let allFilled = true
  let currentSum = 0
  for (const cellIdx of cage.cells) {
    if (cells[cellIdx].value === 0) {
      allFilled = false
      break
    }
    currentSum += cells[cellIdx].value
  }

  if (allFilled && currentSum !== cage.sum) {
    return true
  }
  return false
}

/**
 * 构建格子 → 笼子索引映射表。
 */
function buildCageIndexMap(cages: KillerCage[]): number[] {
  const map: number[] = new Array(TOTAL_CELLS).fill(-1)
  for (let i = 0; i < cages.length; i++) {
    for (const cellIdx of cages[i].cells) {
      if (cellIdx >= 0 && cellIdx < TOTAL_CELLS) {
        map[cellIdx] = i
      }
    }
  }
  return map
}

/**
 * 检查是否有有效的笼子数据。
 */
function hasActiveCages(cages: KillerCage[] | undefined): boolean {
  return cages !== undefined && cages.length > 0
}

/**
 * 扫描全部 81 格，更新每个格子的 ERROR 标志。
 * 应该在每次玩家操作后调用。
 *
 * 当提供 solution 时，还会将与答案不符的用户填入格标记为错误
 * （即使该格没有同行/列/宫的重复冲突）。
 *
 * 当提供 cages 时，还会检查笼子求和约束（填满后总和不等于目标和 → 错误）。
 *
 * 返回冲突格的数量（用于统计）。
 */
export function validateAllCells(cells: CellData[], solution?: number[], cages?: KillerCage[]): number {
  let errorCount = 0
  const cageIndexByCell = hasActiveCages(cages) ? buildCageIndexMap(cages!) : undefined

  for (let i = 0; i < TOTAL_CELLS; i++) {
    const hasPeerConflict = hasConflictWith(cells, i)
    // 若提供了答案，也检查用户填入的数字是否与答案不符
    const hasSolutionMismatch = solution !== undefined &&
      solution.length > i &&
      cells[i].value !== 0 &&
      !cells[i].isGiven &&
      cells[i].value !== solution[i]

    // 若提供了笼子，检查求和约束
    const hasCageError = cageIndexByCell !== undefined &&
      cells[i].value !== 0 &&
      hasCageSumError(cells, i, cages!, cageIndexByCell)

    if (hasPeerConflict || hasSolutionMismatch || hasCageError) {
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
 * 判断游戏是否完成（所有格子都填满且无冲突）。
 * 若提供了 cages，还需要所有笼子求和正确。
 */
export function isGameCompleted(cells: CellData[], cages?: KillerCage[]): boolean {
  for (let i = 0; i < TOTAL_CELLS; i++) {
    // 还有空格 → 未完成
    if (cells[i].value === 0) return false
    // 有冲突 → 未完成
    if (hasConflictWith(cells, i)) return false
  }

  // 若有笼子，检查所有笼子求和
  if (hasActiveCages(cages)) {
    for (const cage of cages!) {
      let sum = 0
      for (const cellIdx of cage.cells) {
        sum += cells[cellIdx].value
      }
      if (sum !== cage.sum) return false
    }
  }

  return true
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
