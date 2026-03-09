/**
 * DifficultyEvaluator.ets — 难度评估器
 *
 * 用 LogicSolver 对谜题进行逻辑求解，根据所需技巧加权评分，
 * 映射到 5 级难度。替代纯挖洞数判断。
 *
 * 参考：Doc 01 §5, Simon Tatham Solo 难度模型
 */
import { Difficulty } from '../constants/GameConstants'
import { logicSolve, LogicSolveResult, Technique } from './LogicSolver'
import { cloneGrid } from './Common'

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

/**
 * 评分 → 难度映射阈值
 *
 * 同时考虑分数和最高技巧：
 *   - EASY: 仅需 Naked Single
 *   - MEDIUM: 最高到 Hidden Single
 *   - HARD: 需要 Naked Pair / Pointing Pair
 *   - EXPERT: 需要 Box/Line Reduction / X-Wing
 *   - EVIL: 纯逻辑无法解出 或 分数极高
 */
export function evaluateDifficulty(board: number[][]): DifficultyGrade {
  const copy = cloneGrid(board)
  const result = logicSolve(copy)

  const grade: DifficultyGrade = {
    difficulty: Difficulty.EASY,
    score: result.totalScore,
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
  grade.difficulty = gradeDifficulty(result)

  return grade
}

/**
 * 根据逻辑求解结果判定难度
 */
function gradeDifficulty(result: LogicSolveResult): Difficulty {
  const maxTech = result.maxTechnique
  const score = result.totalScore

  // 如果只用了 Naked Single → 简单
  if (maxTech === Technique.NAKED_SINGLE) {
    return Difficulty.EASY
  }

  // Hidden Single → 中等（除非分数特别高）
  if (maxTech === Technique.HIDDEN_SINGLE) {
    if (score <= 100) return Difficulty.MEDIUM
    return Difficulty.HARD
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
