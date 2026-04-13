import { GRID_SIZE, TOTAL_CELLS } from '../constants/GameConstants'
import { KillerCage, VariantType } from '../models/VariantConfig'
import { SeededRandom, seededShuffle, shuffle } from './Common'

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
function getRandomCageSize(rng?: SeededRandom): number {
  const range = KILLER_CAGE_MAX_SIZE - KILLER_CAGE_MIN_SIZE + 1
  if (rng) {
    return KILLER_CAGE_MIN_SIZE + rng.nextInt(range)
  }
  return KILLER_CAGE_MIN_SIZE + Math.floor(Math.random() * range)
}

/**
 * 洗牌辅助：有 RNG 就用确定性洗牌，否则用 Math.random()。
 */
function shuffleArray<T>(arr: T[], rng?: SeededRandom): T[] {
  if (rng) {
    return seededShuffle(arr, rng)
  }
  return shuffle(arr)
}

/**
 * 后处理：将单格笼合并到相邻笼子中，消除所有只有一个格子的笼子。
 * 单格笼的 sum 等于该格数字本身，完全没有推理价值。
 *
 * 合并策略：
 *   - 找到单格笼的正交邻居所属笼子
 *   - 如果提供了 solution，优先选择不会导致笼内重复数字的邻居笼
 *   - 在合格候选中优先选择最小的笼子，保持笼子大小均衡
 *   - 将单格并入目标笼子，标记原笼子为空（后续过滤）
 *
 * @param cages 笼子列表（会被就地修改）
 * @param solution 可选的一维完整解答
 */
function mergeSingleCellCages(cages: KillerCage[], solution?: number[]): void {
  // 建立 cell → cage index 映射
  const cellToCage: number[] = new Array(TOTAL_CELLS).fill(-1)
  for (let ci = 0; ci < cages.length; ci++) {
    for (const cell of cages[ci].cells) {
      cellToCage[cell] = ci
    }
  }

  // 反复扫描合并，直到没有单格笼
  let changed = true
  while (changed) {
    changed = false
    for (let ci = 0; ci < cages.length; ci++) {
      if (cages[ci].cells.length !== 1) continue

      const cell = cages[ci].cells[0]
      const neighbors = getOrthogonalNeighbors(cell)

      // 收集相邻笼子（去重）
      const neighborCageIndices = new Set<number>()
      for (const nb of neighbors) {
        const nbCage = cellToCage[nb]
        if (nbCage !== -1 && nbCage !== ci) {
          neighborCageIndices.add(nbCage)
        }
      }

      if (neighborCageIndices.size === 0) continue

      // 筛选不会导致笼内重复数字的候选笼
      let bestCage = -1
      let bestSize = TOTAL_CELLS + 1 // 越小越好

      const candidateIndices: number[] = []
      neighborCageIndices.forEach((idx: number) => candidateIndices.push(idx))

      for (const targetIdx of candidateIndices) {
        const targetCage = cages[targetIdx]

        // 检查是否会导致笼内重复数字
        if (solution) {
          const digit = solution[cell]
          let hasDuplicate = false
          for (const tc of targetCage.cells) {
            if (solution[tc] === digit) {
              hasDuplicate = true
              break
            }
          }
          if (hasDuplicate) continue
        }

        // 优先选择最小的笼子
        if (targetCage.cells.length < bestSize) {
          bestSize = targetCage.cells.length
          bestCage = targetIdx
        }
      }

      // 如果没有不重复的候选，放宽限制（允许重复，选最小笼）
      if (bestCage === -1) {
        for (const targetIdx of candidateIndices) {
          if (cages[targetIdx].cells.length < bestSize) {
            bestSize = cages[targetIdx].cells.length
            bestCage = targetIdx
          }
        }
      }

      if (bestCage === -1) continue

      // 合并：将单格并入目标笼
      cages[bestCage].cells.push(cell)
      cellToCage[cell] = bestCage
      cages[ci].cells = []
      changed = true
    }
  }

  // 过滤掉空笼子
  let writeIdx = 0
  for (let i = 0; i < cages.length; i++) {
    if (cages[i].cells.length > 0) {
      if (writeIdx !== i) {
        cages[writeIdx] = cages[i]
      }
      writeIdx++
    }
  }
  cages.length = writeIdx
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
 *   6. 如果提供了 solution，则保证同一笼子内不会出现重复数字
 *   7. 如果 noSingleCellCages 为 true，后处理合并单格笼到相邻笼子
 *
 * @param solution 可选的一维完整解答，用于避免笼内重复数字
 * @param rng 可选的播种随机数生成器，用于确定性生成
 * @param noSingleCellCages 为 true 时合并单格笼（困难及以上使用）
 */
export function generateRandomCageLayout(solution?: number[], rng?: SeededRandom,
  noSingleCellCages?: boolean): KillerCage[] {
  if (GRID_SIZE !== SUPPORTED_KILLER_GRID_SIZE) {
    return []
  }

  const cages: KillerCage[] = []
  const assignment: number[] = new Array(TOTAL_CELLS).fill(-1)
  let cageId = 0

  // 随机种子顺序
  const order: number[] = []
  for (let i = 0; i < TOTAL_CELLS; i++) order.push(i)
  shuffleArray(order, rng)

  for (const startCell of order) {
    if (assignment[startCell] !== -1) continue

    // 开始新笼子
    const cells: number[] = [startCell]
    assignment[startCell] = cageId

    // 记录笼内已有数字，防止重复
    const usedDigits = new Set<number>()
    if (solution) {
      usedDigits.add(solution[startCell])
    }

    // 目标大小随机 [min, max]
    const targetSize = getRandomCageSize(rng)

    // BFS 式扩展：维护候选边界
    const frontier: number[] = []
    for (const nb of getOrthogonalNeighbors(startCell)) {
      if (assignment[nb] === -1) frontier.push(nb)
    }

    while (cells.length < targetSize && frontier.length > 0) {
      shuffleArray(frontier, rng)
      const next = frontier.pop()!
      if (assignment[next] !== -1) continue

      // 跳过会导致笼内重复数字的格子
      if (solution && usedDigits.has(solution[next])) {
        continue
      }

      cells.push(next)
      assignment[next] = cageId
      if (solution) {
        usedDigits.add(solution[next])
      }

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

  // 后处理：合并单格笼到相邻笼子（困难及以上难度使用）
  if (noSingleCellCages) {
    mergeSingleCellCages(cages, solution)
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
  const sourceLayout = layout ?? generateRandomCageLayout(solution)
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
