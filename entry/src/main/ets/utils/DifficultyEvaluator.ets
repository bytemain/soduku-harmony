/**
 * DifficultyEvaluator.ets — 难度评估器
 *
 * 用 LogicSolver 对谜题进行逻辑求解，根据所需技巧加权评分，
 * 映射到 5 级难度。替代纯挖洞数判断。
 *
 * Killer 模式额外考虑笼约束复杂度：
 *   - 笼子数量越多、平均大小越大 → 难度加成
 *   - CAGE_SUM 技巧使用次数 → 额外加分
 *
 * 参考：Doc 01 §5, Simon Tatham Solo 难度模型
 */
import { Difficulty } from '../constants/GameConstants'
import { logicSolve, LogicSolveResult, Technique } from './LogicSolver'
import { cloneGrid } from './Common'
import { KillerCage } from '../models/VariantConfig'

// ============================================================
// 难度等级映射
// ============================================================

export interface DifficultyGrade {
  /** 评估出的难度等级 */
  difficulty: Difficulty
  /** 总分 */
  score: number
  /** 使用的最高技巧 */
  maxTechnique: Technique | null
  /** 求解步骤数 */
  stepCount: number
  /** 是否可以纯逻辑解出（无需猜测） */
  solvableByLogic: boolean
}

/** Killer 笼子复杂度加成的基础权重 */
const CAGE_COMPLEXITY_BASE_BONUS = 10
/** 大笼子（>= 4 格）的额外加分倍率 */
const LARGE_CAGE_BONUS_MULTIPLIER = 3
/** CAGE_SUM 技巧每次使用的额外加分 */
const CAGE_SUM_STEP_BONUS = 2

/**
 * 评分 → 难度映射阈值
 *
 * 同时考虑分数和最高技巧：
 *   - EASY: 仅需 Naked Single
 *   - MEDIUM: 最高到 Hidden Single
 *   - HARD: 需要 Naked Pair / Pointing Pair / 多笼约束
 *   - EXPERT: 需要 Box/Line Reduction / X-Wing
 *   - EVIL: 纯逻辑无法解出 或 分数极高
 */
export function evaluateDifficulty(board: number[][], cages?: KillerCage[]): DifficultyGrade {
  const copy = cloneGrid(board)
  const result = logicSolve(copy)

  // 计算笼约束复杂度加成
  const cageBonus = cages !== undefined && cages.length > 0
    ? computeCageComplexityBonus(cages, result)
    : 0
  const adjustedScore = result.totalScore + cageBonus

  const grade: DifficultyGrade = {
    difficulty: Difficulty.EASY,
    score: adjustedScore,
    maxTechnique: result.maxTechnique,
    stepCount: result.steps.length,
    solvableByLogic: result.solved,
  }

  if (!result.solved) {
    // 纯逻辑无法解出 → 地狱
    grade.difficulty = Difficulty.EVIL
    return grade
  }

  // 基于最高技巧和总分综合判定
  grade.difficulty = gradeDifficulty(result, adjustedScore)

  return grade
}

/**
 * 计算 Killer 笼约束复杂度加成分数。
 *
 * 考虑因素：
 *   - 笼子数量：笼子越多，约束交互越复杂
 *   - 大笼子比例：>= 4 格的笼子推理难度更高
 *   - CAGE_SUM 技巧使用次数：实际求解中用到的笼推理步数
 */
function computeCageComplexityBonus(cages: KillerCage[], result: LogicSolveResult): number {
  let bonus = 0

  // 基础加成：笼子数量 × 基础权重
  bonus += Math.floor(cages.length / 3) * CAGE_COMPLEXITY_BASE_BONUS

  // 大笼子加成
  let largeCageCount = 0
  for (const cage of cages) {
    if (cage.cells.length >= 4) {
      largeCageCount++
    }
  }
  bonus += largeCageCount * LARGE_CAGE_BONUS_MULTIPLIER

  // CAGE_SUM 技巧使用次数加成
  let cageSumSteps = 0
  for (const step of result.steps) {
    if (step.technique === Technique.CAGE_SUM) {
      cageSumSteps++
    }
  }
  bonus += cageSumSteps * CAGE_SUM_STEP_BONUS

  return bonus
}

/**
 * 根据逻辑求解结果判定难度
 */
function gradeDifficulty(result: LogicSolveResult, adjustedScore?: number): Difficulty {
  const maxTech = result.maxTechnique
  const score = adjustedScore ?? result.totalScore

  // 如果只用了 Naked Single → 简单
  if (maxTech === Technique.NAKED_SINGLE) {
    return Difficulty.EASY
  }

  // Hidden Single → 中等（除非分数特别高）
  if (maxTech === Technique.HIDDEN_SINGLE) {
    if (score <= 100) return Difficulty.MEDIUM
    return Difficulty.HARD
  }

  // Cage Sum → 至少中等（笼约束推理需要额外思考）
  if (maxTech === Technique.CAGE_SUM) {
    if (score <= 80) return Difficulty.MEDIUM
    if (score <= 180) return Difficulty.HARD
    return Difficulty.EXPERT
  }

  // Naked Pair / Pointing Pair → 困难
  if (maxTech === Technique.NAKED_PAIR ||
      maxTech === Technique.POINTING_PAIR) {
    if (score <= 200) return Difficulty.HARD
    return Difficulty.EXPERT
  }

  // Box/Line Reduction / X-Wing → 专家
  if (maxTech === Technique.BOX_LINE_REDUCTION ||
      maxTech === Technique.X_WING) {
    return Difficulty.EXPERT
  }

  // 默认按分数判
  if (score <= 50) return Difficulty.EASY
  if (score <= 100) return Difficulty.MEDIUM
  if (score <= 200) return Difficulty.HARD
  if (score <= 400) return Difficulty.EXPERT
  return Difficulty.EVIL
}

/**
 * 判断谜题是否满足目标难度。
 * 用于生成器循环：生成 → 评估 → 符合就用，不符合就重来。
 */
export function matchesDifficulty(board: number[][], target: Difficulty): boolean {
  const grade = evaluateDifficulty(board)
  return grade.difficulty === target
}
