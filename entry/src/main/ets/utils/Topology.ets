/**
 * Topology.ets — 拓扑结构预计算
 *
 * 数独的核心约束来自行、列、宫（统称 units）。
 * 每个格子与 20 个 peers 互相约束。
 * 这些关系在整局游戏中不会变，启动时算一次，后续全部查表。
 *
 * 内部基于 VariantTopology + VariantConfig 统一构建，
 * 标准 9×9 拓扑作为默认配置的预计算实例导出。
 *
 * 参考：Doc 04 §2.3, Doc 07 §四
 */
import { GRID_SIZE, BOX_SIZE } from '../constants/GameConstants'
import { createStandardConfig } from '../models/VariantConfig'
import { buildVariantTopology } from './VariantTopology'

// ============================================================
// 行、列、宫索引查询（保持原有签名，基于 GRID_SIZE 常量）
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
// 预计算结果（模块加载时通过 VariantTopology 构建标准 9×9 拓扑）
// ============================================================

const _standardTopology = buildVariantTopology(createStandardConfig())

/** 27 个 units */
export const ALL_UNITS: number[][] = _standardTopology.allUnits

/** 每个格子所属的 3 个 units，unitsOf[i] 是一个包含 3 个 number[] 的数组 */
export const UNITS_OF: number[][][] = _standardTopology.unitsOf

/** 每个格子的 20 个 peers，PEERS[i] 是一个 number[] */
export const PEERS: number[][] = _standardTopology.peers
