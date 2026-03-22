import { GRID_SIZE } from '../constants/GameConstants'
import { KillerCage, VariantType } from '../models/VariantConfig'

/**
 * 固定笼子宽度模式：
 * - 仅在单行内切分，提供稳定的 Killer 装饰边界；
 * - 通过 2/3/4、3/2/4、4/2/3 轮换，让笼子边界有一定变化，避免整盘过于单调；
 * - 当前仅用于展示，不承载 Killer 去重/求和玩法约束。
 */
const KILLER_ROW_PATTERNS: number[][] = [
  [2, 3, 4],
  [3, 2, 4],
  [4, 2, 3],
]

const SUPPORTED_KILLER_GRID_SIZE = 9

export function normalizeVariantType(raw: string | undefined): VariantType {
  if (raw === VariantType.DIAGONAL) {
    return VariantType.DIAGONAL
  }
  if (raw === VariantType.JIGSAW) {
    return VariantType.JIGSAW
  }
  if (raw === VariantType.KILLER) {
    return VariantType.KILLER
  }
  return VariantType.STANDARD
}

/**
 * 生成默认的 Killer 笼子布局。
 * 当前只为 9×9 棋盘提供固定横向笼子分区：
 * 每行按 2/3/4、3/2/4、4/2/3 循环切分，保证覆盖全部 81 格且互不重叠。
 */
export function createDefaultKillerLayout(): KillerCage[] {
  const cages: KillerCage[] = []
  if (GRID_SIZE !== SUPPORTED_KILLER_GRID_SIZE) {
    return cages
  }

  for (let row = 0; row < GRID_SIZE; row++) {
    const pattern = KILLER_ROW_PATTERNS[row % KILLER_ROW_PATTERNS.length]
    let colStart = 0
    for (const width of pattern) {
      const cells: number[] = []
      for (let offset = 0; offset < width; offset++) {
        cells.push(row * GRID_SIZE + colStart + offset)
      }
      const cage: KillerCage = {
        cells: cells,
        sum: 0,
      }
      cages.push(cage)
      colStart += width
    }
  }

  return cages
}

/**
 * 根据完整解答计算默认 Killer 布局的笼子和数标签。
 * 这些 sum 当前仅用于 UI 左上角展示，不参与求解或校验。
 * @param solution 一维完整解答（长度应为 81）
 * @returns 与默认布局同结构、但每个笼子 sum 已按解答累计好的笼子列表
 */
export function buildKillerCagesFromSolution(solution: number[]): KillerCage[] {
  const layout = createDefaultKillerLayout()
  const cages: KillerCage[] = []

  for (const cage of layout) {
    let sum = 0
    for (const cellIndex of cage.cells) {
      if (cellIndex < solution.length) {
        sum += solution[cellIndex]
      }
    }
    const solvedCage: KillerCage = {
      cells: cage.cells.slice(),
      sum: sum,
    }
    cages.push(solvedCage)
  }

  return cages
}
