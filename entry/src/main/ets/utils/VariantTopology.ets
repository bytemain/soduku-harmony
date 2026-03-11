/**
 * VariantTopology.ets — 数独拓扑构建器（统一抽象）
 *
 * 根据 VariantConfig 动态构建 units 和 peers。
 * 支持：标准宫 / 对角线 / 不规则宫 / 笼子（Killer）/ 任意尺寸。
 *
 * 这是所有拓扑构建的唯一入口：
 *   - 标准 9×9 拓扑由 Topology.ets 通过本模块预计算并导出全局常量
 *   - 变种模式同样通过本模块构建，产出相同结构的 VariantTopology 实例
 *   - Solver/Validator 统一依赖 peers/unitsOf 数据，无需关心变种类型
 *
 * 参考：Doc 07-变种数独数据结构方案 §四
 */
import { VariantConfig, getRegionMap } from '../models/VariantConfig'

// ============================================================
// VariantTopology — 拓扑数据容器
// ============================================================

/**
 * 拓扑数据容器。
 * 标准 9×9 和所有变种共用同一结构，由 buildVariantTopology() 构建。
 */
export class VariantTopology {
  /** 所有 units（行 + 列 + 区域 + 对角线 + 笼子） */
  allUnits: number[][]
  /** 每个格子所属的 units 列表 */
  unitsOf: number[][][]
  /** 每个格子的 peers 列表 */
  peers: number[][]
  /** 棋盘边长 */
  gridSize: number
  /** 总格数 */
  totalCells: number

  constructor(allUnits: number[][], unitsOf: number[][][], peers: number[][],
    gridSize: number, totalCells: number) {
    this.allUnits = allUnits
    this.unitsOf = unitsOf
    this.peers = peers
    this.gridSize = gridSize
    this.totalCells = totalCells
  }
}

// ============================================================
// 构建行/列 units
// ============================================================

function buildRowUnits(gridSize: number): number[][] {
  const units: number[][] = []
  for (let row = 0; row < gridSize; row++) {
    const unit: number[] = []
    for (let col = 0; col < gridSize; col++) {
      unit.push(row * gridSize + col)
    }
    units.push(unit)
  }
  return units
}

function buildColUnits(gridSize: number): number[][] {
  const units: number[][] = []
  for (let col = 0; col < gridSize; col++) {
    const unit: number[] = []
    for (let row = 0; row < gridSize; row++) {
      unit.push(row * gridSize + col)
    }
    units.push(unit)
  }
  return units
}

// ============================================================
// 构建区域 units（标准 box 或自定义 region）
// ============================================================

function buildRegionUnits(config: VariantConfig): number[][] {
  const regionMap = getRegionMap(config)
  const gridSize = config.grid.gridSize
  const regionCount = config.regions !== null
    ? config.regions.regionCount
    : gridSize

  const units: number[][] = []

  for (let regionId = 0; regionId < regionCount; regionId++) {
    const unit: number[] = []
    for (let i = 0; i < regionMap.length; i++) {
      if (regionMap[i] === regionId) {
        unit.push(i)
      }
    }
    units.push(unit)
  }

  return units
}

// ============================================================
// 构建对角线 units
// ============================================================

function buildDiagonalUnits(gridSize: number): number[][] {
  const units: number[][] = []

  // 主对角线：(0,0), (1,1), ..., (n-1, n-1)
  const mainDiag: number[] = []
  for (let i = 0; i < gridSize; i++) {
    mainDiag.push(i * gridSize + i)
  }
  units.push(mainDiag)

  // 副对角线：(0, n-1), (1, n-2), ..., (n-1, 0)
  const antiDiag: number[] = []
  for (let i = 0; i < gridSize; i++) {
    antiDiag.push(i * gridSize + (gridSize - 1 - i))
  }
  units.push(antiDiag)

  return units
}

// ============================================================
// 构建笼子 units（Killer）
// ============================================================

function buildCageUnits(config: VariantConfig): number[][] {
  if (config.cages === null) {
    return []
  }
  const units: number[][] = []
  for (const cage of config.cages) {
    // 笼子内数字不能重复 → 形成一个 unit
    units.push(cage.cells.slice())
  }
  return units
}

// ============================================================
// 构建 unitsOf（每格所属 units）
// ============================================================

function buildUnitsOfFromAllUnits(allUnits: number[][], totalCells: number): number[][][] {
  const unitsOf: number[][][] = []
  for (let i = 0; i < totalCells; i++) {
    const myUnits: number[][] = []
    for (const unit of allUnits) {
      if (unit.indexOf(i) !== -1) {
        myUnits.push(unit)
      }
    }
    unitsOf.push(myUnits)
  }
  return unitsOf
}

// ============================================================
// 构建 peers（每格约束关联格）
// ============================================================

function buildPeersFromUnitsOf(unitsOf: number[][][], totalCells: number): number[][] {
  const peers: number[][] = []
  for (let i = 0; i < totalCells; i++) {
    const peerSet = new Set<number>()
    for (const unit of unitsOf[i]) {
      for (const idx of unit) {
        if (idx !== i) {
          peerSet.add(idx)
        }
      }
    }
    peers.push(Array.from(peerSet))
  }
  return peers
}

// ============================================================
// 对外接口
// ============================================================

/**
 * 根据 VariantConfig 构建完整拓扑。
 *
 * 这是变种数独的核心入口：
 *   VariantConfig → VariantTopology → { allUnits, unitsOf, peers }
 *
 * Solver/Validator 使用返回的 peers/unitsOf 进行约束检查，
 * 无需知道变种类型的具体细节。
 *
 * @param config 变种配置
 * @returns 构建好的拓扑数据
 */
export function buildVariantTopology(config: VariantConfig): VariantTopology {
  const gridSize = config.grid.gridSize
  const totalCells = config.grid.totalCells

  // 1. 收集所有 units
  const allUnits: number[][] = []

  // 行 units
  const rowUnits = buildRowUnits(gridSize)
  for (const u of rowUnits) {
    allUnits.push(u)
  }

  // 列 units
  const colUnits = buildColUnits(gridSize)
  for (const u of colUnits) {
    allUnits.push(u)
  }

  // 区域 units（标准 box 或自定义 region）
  const regionUnits = buildRegionUnits(config)
  for (const u of regionUnits) {
    allUnits.push(u)
  }

  // 对角线 units（Sudoku-X）
  if (config.hasDiagonals) {
    const diagUnits = buildDiagonalUnits(gridSize)
    for (const u of diagUnits) {
      allUnits.push(u)
    }
  }

  // 笼子 units（Killer）
  const cageUnits = buildCageUnits(config)
  for (const u of cageUnits) {
    allUnits.push(u)
  }

  // 2. 构建 unitsOf 和 peers
  const unitsOf = buildUnitsOfFromAllUnits(allUnits, totalCells)
  const peers = buildPeersFromUnitsOf(unitsOf, totalCells)

  return new VariantTopology(allUnits, unitsOf, peers, gridSize, totalCells)
}

// ============================================================
// 辅助查询函数
// ============================================================

/** 由一维索引得到行号 */
export function rowOfVariant(index: number, gridSize: number): number {
  return Math.floor(index / gridSize)
}

/** 由一维索引得到列号 */
export function colOfVariant(index: number, gridSize: number): number {
  return index % gridSize
}

/** 由行列得到一维索引 */
export function indexOfVariant(row: number, col: number, gridSize: number): number {
  return row * gridSize + col
}

/**
 * 检查两个相邻格子是否属于不同区域。
 * 用于 UI 渲染时判断是否在两格之间画粗分界线。
 *
 * @param index1 第一个格子索引
 * @param index2 第二个格子索引
 * @param regionMap 每格的区域 ID
 * @returns true 表示属于不同区域，应画粗线
 */
export function isDifferentRegion(index1: number, index2: number, regionMap: number[]): boolean {
  return regionMap[index1] !== regionMap[index2]
}

/**
 * 检查一个格子是否在主对角线上。
 * @param index 格子一维索引
 * @param gridSize 棋盘边长
 */
export function isOnMainDiagonal(index: number, gridSize: number): boolean {
  const row = Math.floor(index / gridSize)
  const col = index % gridSize
  return row === col
}

/**
 * 检查一个格子是否在副对角线上。
 * @param index 格子一维索引
 * @param gridSize 棋盘边长
 */
export function isOnAntiDiagonal(index: number, gridSize: number): boolean {
  const row = Math.floor(index / gridSize)
  const col = index % gridSize
  return row + col === gridSize - 1
}

/**
 * 检查一个格子是否在任意对角线上。
 * @param index 格子一维索引
 * @param gridSize 棋盘边长
 */
export function isOnDiagonal(index: number, gridSize: number): boolean {
  return isOnMainDiagonal(index, gridSize) || isOnAntiDiagonal(index, gridSize)
}
