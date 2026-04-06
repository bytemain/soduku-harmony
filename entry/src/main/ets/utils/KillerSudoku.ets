import { GRID_SIZE, TOTAL_CELLS } from '../constants/GameConstants'
import { KillerCage, VariantType } from '../models/VariantConfig'
import { shuffle } from './Common'

/** Killer 笼子最小格数 */
const KILLER_CAGE_MIN_SIZE = 2
/** Killer 笼子最大格数 */
const KILLER_CAGE_MAX_SIZE = 5

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
 * 获取某个格子的正交邻居（上下左右），返回一维索引列表。
 */
function getOrthogonalNeighbors(cellIndex: number): number[] {
  const row = Math.floor(cellIndex / GRID_SIZE)
  const col = cellIndex % GRID_SIZE
  const neighbors: number[] = []
  if (row > 0) neighbors.push(cellIndex - GRID_SIZE)
  if (row < GRID_SIZE - 1) neighbors.push(cellIndex + GRID_SIZE)
  if (col > 0) neighbors.push(cellIndex - 1)
  if (col < GRID_SIZE - 1) neighbors.push(cellIndex + 1)
  return neighbors
}

/**
 * 随机生成笼子大小（在 [KILLER_CAGE_MIN_SIZE, KILLER_CAGE_MAX_SIZE] 范围内）。
 */
function getRandomCageSize(): number {
  return KILLER_CAGE_MIN_SIZE +
    Math.floor(Math.random() * (KILLER_CAGE_MAX_SIZE - KILLER_CAGE_MIN_SIZE + 1))
}

/**
 * 随机生成连通笼子分区，覆盖全部格子。
 *
 * 算法：
 *   1. 随机打乱所有格子作为种子顺序
 *   2. 从未分配的格子开始一个新笼子
 *   3. 通过 BFS 式扩展向正交邻居随机生长
 *   4. 笼子大小在 [KILLER_CAGE_MIN_SIZE, KILLER_CAGE_MAX_SIZE] 范围内
 *   5. 确保每个格子恰好属于一个笼子
 */
export function generateRandomCageLayout(): KillerCage[] {
  if (GRID_SIZE !== SUPPORTED_KILLER_GRID_SIZE) {
    return []
  }

  const cages: KillerCage[] = []
  const assignment: number[] = new Array(TOTAL_CELLS).fill(-1)
  let cageId = 0

  // 随机种子顺序
  const order: number[] = []
  for (let i = 0; i < TOTAL_CELLS; i++) order.push(i)
  shuffle(order)

  for (const startCell of order) {
    if (assignment[startCell] !== -1) continue

    // 开始新笼子
    const cells: number[] = [startCell]
    assignment[startCell] = cageId

    // 目标大小随机 [min, max]
    const targetSize = getRandomCageSize()

    // BFS 式扩展：维护候选边界
    const frontier: number[] = []
    for (const nb of getOrthogonalNeighbors(startCell)) {
      if (assignment[nb] === -1) frontier.push(nb)
    }

    while (cells.length < targetSize && frontier.length > 0) {
      shuffle(frontier)
      const next = frontier.pop()!
      if (assignment[next] !== -1) continue

      cells.push(next)
      assignment[next] = cageId

      // 添加新邻居到边界
      for (const nb of getOrthogonalNeighbors(next)) {
        if (assignment[nb] === -1 && frontier.indexOf(nb) === -1) {
          frontier.push(nb)
        }
      }
    }

    cages.push({ cells: cells, sum: 0 })
    cageId++
  }

  return cages
}

/**
 * 根据完整解答和笼子布局计算各笼目标和。
 * 返回新的笼子列表，每个笼子的 sum 按解答累加。
 *
 * @param solution 一维完整解答（长度应为 TOTAL_CELLS）
 * @param layout 笼子布局（通常由 generateRandomCageLayout 产出）
 * @returns 带正确 sum 的笼子列表
 */
export function buildKillerCagesFromSolution(solution: number[], layout?: KillerCage[]): KillerCage[] {
  const sourceLayout = layout ?? generateRandomCageLayout()
  const cages: KillerCage[] = []

  for (const cage of sourceLayout) {
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
