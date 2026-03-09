/**
 * Topology.ets — 拓扑结构预计算
 *
 * 数独的核心约束来自行、列、宫（统称 units）。
 * 每个格子与 20 个 peers 互相约束。
 * 这些关系在整局游戏中不会变，启动时算一次，后续全部查表。
 *
 * 参考：Doc 04 §2.3
 */
import { GRID_SIZE, BOX_SIZE, TOTAL_CELLS } from '../constants/GameConstants'

// ============================================================
// 27 个 units（9行 + 9列 + 9宫），每个 unit 包含 9 个格子的索引
// ============================================================

function buildAllUnits(): number[][] {
  const units: number[][] = []

  // 9 行
  for (let row = 0; row < GRID_SIZE; row++) {
    const unit: number[] = []
    for (let col = 0; col < GRID_SIZE; col++) {
      unit.push(row * GRID_SIZE + col)
    }
    units.push(unit)
  }

  // 9 列
  for (let col = 0; col < GRID_SIZE; col++) {
    const unit: number[] = []
    for (let row = 0; row < GRID_SIZE; row++) {
      unit.push(row * GRID_SIZE + col)
    }
    units.push(unit)
  }

  // 9 宫
  for (let br = 0; br < GRID_SIZE; br += BOX_SIZE) {
    for (let bc = 0; bc < GRID_SIZE; bc += BOX_SIZE) {
      const unit: number[] = []
      for (let r = br; r < br + BOX_SIZE; r++) {
        for (let c = bc; c < bc + BOX_SIZE; c++) {
          unit.push(r * GRID_SIZE + c)
        }
      }
      units.push(unit)
    }
  }

  return units
}

// ============================================================
// 每个格子所属的 3 个 units
// ============================================================

function buildUnitsOf(allUnits: number[][]): number[][][] {
  const unitsOf: number[][][] = []
  for (let i = 0; i < TOTAL_CELLS; i++) {
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
// 每个格子的 20 个 peers（同行+同列+同宫，去重去自己）
// ============================================================

function buildPeers(unitsOf: number[][][]): number[][] {
  const peers: number[][] = []
  for (let i = 0; i < TOTAL_CELLS; i++) {
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
// 行、列、宫索引查询
// ============================================================

/** 由一维索引得到行号 (0-8) */
export function rowOf(index: number): number {
  return Math.floor(index / GRID_SIZE)
}

/** 由一维索引得到列号 (0-8) */
export function colOf(index: number): number {
  return index % GRID_SIZE
}

/** 由一维索引得到宫号 (0-8) */
export function boxOf(index: number): number {
  const r = Math.floor(index / GRID_SIZE)
  const c = index % GRID_SIZE
  return Math.floor(r / BOX_SIZE) * BOX_SIZE + Math.floor(c / BOX_SIZE)
}

/** 由行列得到一维索引 */
export function indexOf(row: number, col: number): number {
  return row * GRID_SIZE + col
}

// ============================================================
// 预计算结果（模块加载时执行一次）
// ============================================================

/** 27 个 units */
export const ALL_UNITS: number[][] = buildAllUnits()

/** 每个格子所属的 3 个 units，unitsOf[i] 是一个包含 3 个 number[] 的数组 */
export const UNITS_OF: number[][][] = buildUnitsOf(ALL_UNITS)

/** 每个格子的 20 个 peers，PEERS[i] 是一个 number[] */
export const PEERS: number[][] = buildPeers(UNITS_OF)
