/**
 * Topology.ets — 拓扑结构预计算
 *
 * 数独的核心约束来自行、列、宫（统称 units）。
 * 每个格子与 20 个 peers 互相约束。
 * 这些关系在整局游戏中不会变，启动时算一次，后续全部查表。
 *
 * 内部基于 VariantTopology + VariantConfig 统一构建，
 * 标准 9×9 拓扑作为默认配置的预计算实例导出。
 * 可通过 applyTopology() 在运行时切换到不同尺寸的拓扑。
 *
 * 参考：Doc 04 §2.3, Doc 07 §四
 */
import { GRID_SIZE, BOX_ROWS, BOX_COLS, BOX_COUNT_COLS } from '../constants/GameConstants'
import { VariantConfig, createStandardConfig } from '../models/VariantConfig'
import { buildVariantTopology, VariantTopology } from './VariantTopology'

// ============================================================
// 行、列、宫索引查询（动态使用 GRID_SIZE / BOX_ROWS / BOX_COLS）
// ============================================================

/** 由一维索引得到行号 */
export function rowOf(index: number): number {
  return Math.floor(index / GRID_SIZE)
}

/** 由一维索引得到列号 */
export function colOf(index: number): number {
  return index % GRID_SIZE
}

/** 由一维索引得到宫号（按阅读顺序编号：先行后列） */
export function boxOf(index: number): number {
  const r = Math.floor(index / GRID_SIZE)
  const c = index % GRID_SIZE
  // BOX_COUNT_COLS = 水平方向宫格数 = GRID_SIZE / BOX_COLS
  // 例如 6×6 (2×3 宫)：BOX_COUNT_COLS=2，宫按 0-1 / 2-3 / 4-5 排列
  return Math.floor(r / BOX_ROWS) * BOX_COUNT_COLS + Math.floor(c / BOX_COLS)
}

/** 由行列得到一维索引 */
export function indexOf(row: number, col: number): number {
  return row * GRID_SIZE + col
}

// ============================================================
// 预计算结果（可由 applyTopology 动态切换）
// ============================================================

const _standardTopology = buildVariantTopology(createStandardConfig())

/** 所有 units（标准 9×9 有 27 个） */
export let ALL_UNITS: number[][] = _standardTopology.allUnits

/** 每个格子所属的 units 列表 */
export let UNITS_OF: number[][][] = _standardTopology.unitsOf

/** 每个格子的 peers 列表（标准 9×9 每格 20 个） */
export let PEERS: number[][] = _standardTopology.peers

/**
 * 根据 VariantConfig 重新构建拓扑并替换全局 ALL_UNITS / UNITS_OF / PEERS。
 * 在 applyGridConfig() 之后调用。
 */
export function applyTopology(config: VariantConfig): void {
  const topo: VariantTopology = buildVariantTopology(config)
  ALL_UNITS = topo.allUnits
  UNITS_OF = topo.unitsOf
  PEERS = topo.peers
}
