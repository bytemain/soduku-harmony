/**
 * VariantConfig.ets — 变种数独配置模型
 *
 * 定义变种类型、棋盘几何、区域配置、笼子结构等。
 * 所有变种通过组合式配置描述，驱动动态拓扑构建。
 *
 * 设计原则：
 *   - 组合优于继承：hasDiagonals / regions / cages 独立开关
 *   - 标准数独是特例：type=STANDARD, 无额外字段
 *   - 配置驱动拓扑：Topology 根据 VariantConfig 动态构建 units/peers
 *
 * 参考：Doc 07-变种数独数据结构方案
 */

// ============================================================
// VariantType 枚举
// ============================================================

/**
 * 数独变种类型。
 * 使用 string enum 便于序列化和日志（与 Symmetry 风格一致）。
 */
export enum VariantType {
  /** 标准数独（9×9，3×3 宫） */
  STANDARD = 'standard',
  /** 对角线数独（Sudoku-X）：两条主对角线也须 1-N 不重复 */
  DIAGONAL = 'diagonal',
  /** 不规则宫数独（Jigsaw）：区域形状不规则 */
  JIGSAW = 'jigsaw',
  /** 杀手数独（Killer）：笼子内数字不重复 + 求和约束 */
  KILLER = 'killer',
}

// ============================================================
// GridConfig — 棋盘几何配置
// ============================================================

/**
 * 描述棋盘的几何属性。
 * 不同尺寸的数独（4×4, 6×6, 9×9, 12×12, 16×16）
 * 通过不同的 GridConfig 实例区分。
 */
export interface GridConfig {
  /** 棋盘边长（4 / 6 / 9 / 12 / 16） */
  gridSize: number
  /** 宫格行数（如 9×9 标准为 3，6×6 为 2） */
  boxRows: number
  /** 宫格列数（如 9×9 标准为 3，6×6 为 3） */
  boxCols: number
  /** 总格数 = gridSize × gridSize */
  totalCells: number
  /** 有效数字列表，如 [1, 2, ..., 9] */
  digits: number[]
}

// ============================================================
// 预设 GridConfig
// ============================================================

/** 4×4 入门棋盘（2×2 宫） */
export const GRID_4x4: GridConfig = {
  gridSize: 4,
  boxRows: 2,
  boxCols: 2,
  totalCells: 16,
  digits: [1, 2, 3, 4],
}

/** 6×6 简易棋盘（2×3 宫） */
export const GRID_6x6: GridConfig = {
  gridSize: 6,
  boxRows: 2,
  boxCols: 3,
  totalCells: 36,
  digits: [1, 2, 3, 4, 5, 6],
}

/** 9×9 标准棋盘（3×3 宫） */
export const GRID_9x9: GridConfig = {
  gridSize: 9,
  boxRows: 3,
  boxCols: 3,
  totalCells: 81,
  digits: [1, 2, 3, 4, 5, 6, 7, 8, 9],
}

/** 12×12 进阶棋盘（3×4 宫） */
export const GRID_12x12: GridConfig = {
  gridSize: 12,
  boxRows: 3,
  boxCols: 4,
  totalCells: 144,
  digits: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
}

/** 16×16 挑战棋盘（4×4 宫） */
export const GRID_16x16: GridConfig = {
  gridSize: 16,
  boxRows: 4,
  boxCols: 4,
  totalCells: 256,
  digits: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
}

/**
 * 根据棋盘边长获取对应的预设 GridConfig。
 * 集中管理 size → config 映射，避免各处硬编码。
 *
 * @param size 棋盘边长（4 / 6 / 9 / 12 / 16），默认返回 GRID_9x9
 */
export function getGridConfigBySize(size: number): GridConfig {
  switch (size) {
    case 4:
      return GRID_4x4
    case 6:
      return GRID_6x6
    case 12:
      return GRID_12x12
    case 16:
      return GRID_16x16
    case 9:
    default:
      return GRID_9x9
  }
}

// ============================================================
// RegionConfig — 区域定义（Jigsaw 用）
// ============================================================

/**
 * 描述不规则区域分布。
 * 标准数独的 regionMap 就是每格的 box 编号；
 * Jigsaw 数独由生成算法产出不规则的 regionMap。
 */
export interface RegionConfig {
  /** 区域数量（通常 = gridSize） */
  regionCount: number
  /**
   * 每个格子所属的区域 ID (0-based)。
   * 长度 = totalCells，regionMap[index] = regionId。
   *
   * 例如标准 9×9：regionMap[0] = 0（第一格属于第 0 宫）
   */
  regionMap: number[]
}

// ============================================================
// KillerCage — 笼子（Killer 用）
// ============================================================

/**
 * Killer 数独的笼子定义。
 * 笼子内格子数字不能重复（形成一个 unit），且总和必须等于 sum。
 */
export interface KillerCage {
  /** 笼子内格子的一维索引列表 */
  cells: number[]
  /** 笼子的目标和 */
  sum: number
}

// ============================================================
// VariantConfig — 变种完整配置
// ============================================================

/**
 * 描述一个数独变种的完整配置。
 * 组合式设计：hasDiagonals / regions / cages 是独立开关，可自由组合。
 *
 * 标准数独对应：
 *   { type: STANDARD, grid: GRID_9x9, hasDiagonals: false, regions: null, cages: null }
 */
export interface VariantConfig {
  /** 变种类型标识 */
  type: VariantType
  /** 棋盘几何配置 */
  grid: GridConfig
  /** 是否启用对角线约束（Sudoku-X） */
  hasDiagonals: boolean
  /** 自定义区域（Jigsaw 用）。null 表示使用标准 box 分区 */
  regions: RegionConfig | null
  /** 笼子列表（Killer 用）。null 表示无笼子 */
  cages: KillerCage[] | null
}

// ============================================================
// 工厂函数 — 创建预设配置
// ============================================================

/**
 * 创建标准 9×9 数独配置。
 * 等价于当前 App 的默认行为。
 */
export function createStandardConfig(): VariantConfig {
  return {
    type: VariantType.STANDARD,
    grid: GRID_9x9,
    hasDiagonals: false,
    regions: null,
    cages: null,
  }
}

/**
 * 创建 Sudoku-X（对角线数独）配置。
 * 在标准 9×9 基础上增加两条对角线约束。
 */
export function createDiagonalConfig(): VariantConfig {
  return {
    type: VariantType.DIAGONAL,
    grid: GRID_9x9,
    hasDiagonals: true,
    regions: null,
    cages: null,
  }
}

/**
 * 创建 Jigsaw（不规则宫）数独配置。
 * regionMap 由调用方提供（通常由区域生成算法产出）。
 *
 * @param regionMap 每格所属区域 ID，长度 81
 */
export function createJigsawConfig(regionMap: number[]): VariantConfig {
  return {
    type: VariantType.JIGSAW,
    grid: GRID_9x9,
    hasDiagonals: false,
    regions: {
      regionCount: GRID_9x9.gridSize,
      regionMap: regionMap,
    },
    cages: null,
  }
}

/**
 * 创建 Killer（杀手数独）配置。
 * cages 由调用方提供（通常由笼子生成算法产出）。
 *
 * @param cages 笼子列表
 */
export function createKillerConfig(cages: KillerCage[]): VariantConfig {
  return {
    type: VariantType.KILLER,
    grid: GRID_9x9,
    hasDiagonals: false,
    regions: null,
    cages: cages,
  }
}

/**
 * 创建任意尺寸的标准数独配置。
 *
 * @param gridSize 棋盘边长
 * @param boxRows 宫格行数
 * @param boxCols 宫格列数
 */
export function createSizedConfig(gridSize: number, boxRows: number, boxCols: number): VariantConfig {
  const digits: number[] = []
  for (let i = 1; i <= gridSize; i++) {
    digits.push(i)
  }

  return {
    type: VariantType.STANDARD,
    grid: {
      gridSize: gridSize,
      boxRows: boxRows,
      boxCols: boxCols,
      totalCells: gridSize * gridSize,
      digits: digits,
    },
    hasDiagonals: false,
    regions: null,
    cages: null,
  }
}

// ============================================================
// 标准配置常量
// ============================================================

/** 标准 9×9 配置（默认值） */
export const STANDARD_CONFIG: VariantConfig = createStandardConfig()

// ============================================================
// 辅助函数
// ============================================================

/**
 * 为标准 box 分区生成 regionMap。
 * 用于拓扑构建时将标准宫转为 regionMap 格式。
 */
export function buildStandardRegionMap(grid: GridConfig): number[] {
  const map: number[] = []
  for (let row = 0; row < grid.gridSize; row++) {
    for (let col = 0; col < grid.gridSize; col++) {
      const boxRow = Math.floor(row / grid.boxRows)
      const boxCol = Math.floor(col / grid.boxCols)
      const regionId = boxRow * (grid.gridSize / grid.boxCols) + boxCol
      map.push(regionId)
    }
  }
  return map
}

/**
 * 获取配置的最终 regionMap。
 * 如果有自定义 regions 则用 regionMap，否则按标准 box 计算。
 */
export function getRegionMap(config: VariantConfig): number[] {
  if (config.regions !== null) {
    return config.regions.regionMap
  }
  return buildStandardRegionMap(config.grid)
}
