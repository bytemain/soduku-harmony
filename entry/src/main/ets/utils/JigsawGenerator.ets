/**
 * JigsawGenerator.ets — 随机不规则区域生成器
 *
 * 基于 BFS 区域生长算法生成 gridSize 个连通区域，
 * 每个区域恰好包含 gridSize 个格子。
 *
 * 算法概述：
 *   1. 按随机顺序放置区域种子点
 *   2. 每个区域从种子出发 BFS 扩展至 gridSize 个格子
 *   3. 所有格子恰好分配到一个区域，每个区域连通且大小相等
 *   4. 支持 SeededRandom 实现确定性生成（同 seed → 同 regionMap）
 *
 * 参考：Doc 07-变种数独数据结构方案, Doc 13 §2.7
 */
import { SeededRandom, seededShuffle, shuffle } from './Common'

const JIGSAW_GRID_SIZE = 9
const JIGSAW_TOTAL_CELLS = JIGSAW_GRID_SIZE * JIGSAW_GRID_SIZE

/** 最大重试次数：区域生长有可能因拓扑死角而失败，需要重试 */
const MAX_GENERATION_ATTEMPTS = 50

/**
 * 获取正交邻居（上下左右），返回一维索引列表。
 */
function getOrthogonalNeighbors(cellIndex: number): number[] {
  const row = Math.floor(cellIndex / JIGSAW_GRID_SIZE)
  const col = cellIndex % JIGSAW_GRID_SIZE
  const neighbors: number[] = []
  if (row > 0) neighbors.push(cellIndex - JIGSAW_GRID_SIZE)
  if (row < JIGSAW_GRID_SIZE - 1) neighbors.push(cellIndex + JIGSAW_GRID_SIZE)
  if (col > 0) neighbors.push(cellIndex - 1)
  if (col < JIGSAW_GRID_SIZE - 1) neighbors.push(cellIndex + 1)
  return neighbors
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
 * 检查将格子移除后，所有未分配格子是否仍然连通。
 * 用于避免区域生长切断剩余格子的可达性，导致后续区域无法达到目标大小。
 *
 * @param assignment 当前格子分配状态（-1 表示未分配）
 * @param excludeCell 假设该格子被分配后，检查剩余连通性
 * @returns true 表示剩余格子仍连通（或剩余格子为空）
 */
function isRemainingConnected(assignment: number[], excludeCell: number): boolean {
  // 找到第一个未分配且非 excludeCell 的格子作为 BFS 起点
  let startCell = -1
  let unassignedCount = 0
  for (let i = 0; i < JIGSAW_TOTAL_CELLS; i++) {
    if (assignment[i] === -1 && i !== excludeCell) {
      unassignedCount++
      if (startCell === -1) {
        startCell = i
      }
    }
  }

  // 如果没有剩余未分配格子，不需要检查
  if (unassignedCount === 0) return true

  // BFS 从 startCell 开始，计数可达的未分配格子
  const visited = new Set<number>()
  const queue: number[] = [startCell]
  visited.add(startCell)

  while (queue.length > 0) {
    const current = queue.shift()!
    const neighbors = getOrthogonalNeighbors(current)
    for (const nb of neighbors) {
      if (!visited.has(nb) && assignment[nb] === -1 && nb !== excludeCell) {
        visited.add(nb)
        queue.push(nb)
      }
    }
  }

  return visited.size === unassignedCount
}

/**
 * 尝试一次区域生长，生成完整的 regionMap。
 *
 * @param rng 可选播种随机数生成器
 * @returns 成功时返回 regionMap，失败返回 null
 */
function tryGenerateRegionMap(rng?: SeededRandom): number[] | null {
  const assignment: number[] = new Array(JIGSAW_TOTAL_CELLS).fill(-1)
  const regionSize = JIGSAW_GRID_SIZE // 每个区域包含的格子数

  for (let regionId = 0; regionId < JIGSAW_GRID_SIZE; regionId++) {
    // 收集所有未分配格子作为种子候选
    const candidates: number[] = []
    for (let i = 0; i < JIGSAW_TOTAL_CELLS; i++) {
      if (assignment[i] === -1) {
        candidates.push(i)
      }
    }

    if (candidates.length === 0) break

    // 随机选一个种子
    shuffleArray(candidates, rng)
    const seed = candidates[0]

    // BFS 扩展区域
    const regionCells: number[] = [seed]
    assignment[seed] = regionId

    // 优先队列：正交邻居中未分配的格子
    let frontier: number[] = []
    for (const nb of getOrthogonalNeighbors(seed)) {
      if (assignment[nb] === -1) {
        frontier.push(nb)
      }
    }

    while (regionCells.length < regionSize && frontier.length > 0) {
      shuffleArray(frontier, rng)

      let foundNext = false
      for (let fi = frontier.length - 1; fi >= 0; fi--) {
        const next = frontier[fi]
        if (assignment[next] !== -1) {
          // 已被其他路径分配，移除
          frontier.splice(fi, 1)
          continue
        }

        // 连通性检查：确保将 next 分配给当前区域后，
        // 剩余未分配格子仍然连通
        if (!isRemainingConnected(assignment, next)) {
          continue
        }

        // 分配格子
        assignment[next] = regionId
        regionCells.push(next)
        frontier.splice(fi, 1)

        // 添加新邻居到 frontier
        for (const nb of getOrthogonalNeighbors(next)) {
          if (assignment[nb] === -1 && frontier.indexOf(nb) === -1) {
            frontier.push(nb)
          }
        }

        foundNext = true
        break
      }

      if (!foundNext) {
        // 所有 frontier 候选都不满足连通性约束 → 生成失败
        return null
      }
    }

    if (regionCells.length < regionSize) {
      // 无法达到目标大小 → 生成失败
      return null
    }
  }

  // 验证：所有格子都已分配
  for (let i = 0; i < JIGSAW_TOTAL_CELLS; i++) {
    if (assignment[i] === -1) return null
  }

  return assignment
}

/**
 * 生成随机不规则区域布局。
 *
 * 生成 9 个大小相等（每个 9 格）的连通区域，覆盖全部 81 格。
 * 使用 BFS 区域生长 + 连通性检查确保每个区域连通、
 * 每个区域大小恰好为 gridSize，且所有格子恰好分配一次。
 *
 * 算法会自动重试，保证一定能返回有效的 regionMap。
 *
 * @param rng 可选的播种随机数生成器，用于确定性生成（seed 复现）
 * @returns 长度为 81 的区域 ID 数组
 */
export function generateRandomRegionMap(rng?: SeededRandom): number[] {
  for (let attempt = 0; attempt < MAX_GENERATION_ATTEMPTS; attempt++) {
    const result = tryGenerateRegionMap(rng)
    if (result !== null) {
      return result
    }
  }

  // 极端情况回退：返回默认布局（理论上不应到达这里）
  return [
    0, 0, 0, 1, 1, 1, 2, 2, 3,
    0, 0, 1, 1, 1, 2, 2, 2, 3,
    0, 0, 0, 0, 1, 2, 2, 4, 3,
    5, 5, 5, 1, 1, 2, 4, 4, 3,
    5, 5, 5, 5, 5, 2, 4, 4, 3,
    6, 6, 5, 4, 4, 4, 4, 7, 3,
    6, 6, 7, 7, 7, 7, 7, 7, 3,
    6, 6, 6, 7, 8, 8, 8, 7, 3,
    6, 6, 8, 8, 8, 8, 8, 8, 3,
  ]
}

/**
 * 验证 regionMap 是否合法。
 * - 每个区域恰好包含 gridSize 个格子
 * - 每个区域内部连通（通过正交邻居）
 * - 所有格子都已分配
 */
export function isValidRegionMap(regionMap: number[]): boolean {
  if (regionMap.length !== JIGSAW_TOTAL_CELLS) return false

  // 检查每个区域大小
  const regionCells: Map<number, number[]> = new Map()
  for (let i = 0; i < regionMap.length; i++) {
    const rid = regionMap[i]
    if (rid < 0 || rid >= JIGSAW_GRID_SIZE) return false
    if (!regionCells.has(rid)) {
      regionCells.set(rid, [])
    }
    regionCells.get(rid)!.push(i)
  }

  // 检查区域数量
  if (regionCells.size !== JIGSAW_GRID_SIZE) return false

  // 检查每个区域大小和连通性
  const entries: Array<[number, number[]]> = []
  regionCells.forEach((cells: number[], rid: number) => {
    entries.push([rid, cells])
  })

  for (const entry of entries) {
    const cells = entry[1]

    // 大小检查
    if (cells.length !== JIGSAW_GRID_SIZE) return false

    // 连通性检查：从第一个格子 BFS
    const cellSet = new Set<number>(cells)
    const visited = new Set<number>()
    const queue: number[] = [cells[0]]
    visited.add(cells[0])

    while (queue.length > 0) {
      const current = queue.shift()!
      const neighbors = getOrthogonalNeighbors(current)
      for (const nb of neighbors) {
        if (cellSet.has(nb) && !visited.has(nb)) {
          visited.add(nb)
          queue.push(nb)
        }
      }
    }

    if (visited.size !== cells.length) return false
  }

  return true
}
