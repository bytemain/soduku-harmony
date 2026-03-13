/**
 * PuzzleLibrary.ets — 题库数据模型
 *
 * 定义题库、题目条目、进度追踪的数据结构。
 * 用于内置题库和外部导入题库的管理。
 *
 * 参考：Doc 11-内置题库下载与进度追踪方案
 */
import { Difficulty } from '../constants/GameConstants'
import { PuzzleMetadata } from '../utils/SudokuFormat'

// ============================================================
// 题库来源
// ============================================================

/** 题库来源类型 */
export type LibrarySource = 'builtin' | 'url' | 'file' | 'clipboard'

// ============================================================
// 题目进度
// ============================================================

/** 题目状态 */
export type PuzzleStatus = 'new' | 'in_progress' | 'completed'

/**
 * 单道题目的进度数据。
 * 支持断点续玩：cellStates 保存完整格子状态。
 */
export interface PuzzleProgress {
  /** 完成状态 */
  status: PuzzleStatus
  /** 开始时间戳 */
  startedAt?: number
  /** 完成时间戳 */
  completedAt?: number
  /** 累计用时（秒） */
  elapsedSeconds: number
  /** 错误次数 */
  errorCount: number
  /**
   * 序列化的格子状态（JSON 字符串）。
   * 用于断点续玩，保存每个格子的 value/flags/notes。
   * undefined 表示尚未开始或已重置。
   */
  cellStates?: string
  /** 完成百分比 (0-100) */
  percentage: number
}

// ============================================================
// 题目条目
// ============================================================

/**
 * 题库中的单道题目。
 * puzzle81 存储标准化的 81 字符串格式。
 */
export interface PuzzleEntry {
  /** 在题库中的序号（0-based） */
  index: number
  /** 81 字符串格式的谜题 */
  puzzle81: string
  /** 81 字符串格式的答案（可选，延迟计算） */
  solution81?: string
  /** 评估难度 */
  difficulty?: Difficulty
  /** 元数据（作者、描述等） */
  metadata?: PuzzleMetadata
  /** 完成进度 */
  progress: PuzzleProgress
}

// ============================================================
// 题库
// ============================================================

/**
 * 题库索引信息（不含具体题目数据）。
 * 题目列表通过 PuzzleLibraryStorage 按需加载。
 */
export interface PuzzleLibrary {
  /** 唯一标识（如 "builtin-easy-50"） */
  id: string
  /** 显示名称（i18n key 或直接文本） */
  name: string
  /** 题库描述 */
  description: string
  /** 来源类型 */
  source: LibrarySource
  /** 原始下载 URL（url 来源时） */
  sourceUrl?: string
  /** 原始格式 */
  format: string
  /** 题目总数 */
  puzzleCount: number
  /** 整体难度（可选） */
  difficulty?: Difficulty
  /** 标签 */
  tags: string[]
  /** 导入时间 */
  createdAt: number
  /** 最后更新时间 */
  updatedAt: number
}

// ============================================================
// 工厂函数
// ============================================================

/**
 * 创建默认进度
 */
export function createDefaultProgress(): PuzzleProgress {
  return {
    status: 'new',
    elapsedSeconds: 0,
    errorCount: 0,
    percentage: 0,
  }
}

/**
 * 创建题目条目
 */
export function createPuzzleEntry(
  index: number,
  puzzle81: string,
  metadata?: PuzzleMetadata,
  difficulty?: Difficulty,
): PuzzleEntry {
  return {
    index,
    puzzle81,
    difficulty,
    metadata,
    progress: createDefaultProgress(),
  }
}

/**
 * 创建题库索引
 */
export function createPuzzleLibrary(
  id: string,
  name: string,
  description: string,
  source: LibrarySource,
  format: string,
  puzzleCount: number,
  options?: {
    sourceUrl?: string
    difficulty?: Difficulty
    tags?: string[]
  },
): PuzzleLibrary {
  const now = Date.now()
  return {
    id,
    name,
    description,
    source,
    format,
    puzzleCount,
    sourceUrl: options?.sourceUrl,
    difficulty: options?.difficulty,
    tags: options?.tags ?? [],
    createdAt: now,
    updatedAt: now,
  }
}

// ============================================================
// 统计辅助
// ============================================================

/**
 * 计算题库完成统计
 */
export interface LibraryStats {
  /** 已完成题目数 */
  completed: number
  /** 进行中题目数 */
  inProgress: number
  /** 未开始题目数 */
  notStarted: number
  /** 总题目数 */
  total: number
  /** 整体完成百分比 */
  overallPercentage: number
}

/**
 * 从题目列表计算统计数据
 */
export function computeLibraryStats(puzzles: PuzzleEntry[]): LibraryStats {
  let completed = 0
  let inProgress = 0
  for (const p of puzzles) {
    if (p.progress.status === 'completed') {
      completed++
    } else if (p.progress.status === 'in_progress') {
      inProgress++
    }
  }
  const total = puzzles.length
  const notStarted = total - completed - inProgress
  const overallPercentage = total > 0 ? Math.round((completed / total) * 100) : 0
  return { completed, inProgress, notStarted, total, overallPercentage }
}
