/**
 * DifficultyEvaluator.ets — 难度评估器
 *
 * 用 LogicSolver 对谜题进行逻辑求解，根据所需技巧加权评分，
 * 映射到 5 级难度。替代纯挖洞数判断。
 *
 * 设计模式：
 *   - 数据驱动的规则表（Table-Driven）：将技巧 → 难度映射声明为规则表，
 *     用查找替代 if-chain，新技巧只需追加一行配置。
 *   - 分数段兜底规则：未命中技巧规则时，按分数段查表。
 *   - Killer 笼约束加成：通过 computeCageComplexityBonus() 插件式附加分值。
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

// ============================================================
// 技巧 → 难度映射规则表（Table-Driven 模式）
// ============================================================

/**
 * 技巧分级规则。
 *
 * 按"从简到难"排列，第一个匹配的规则生效。
 * - techniques: 该规则匹配的技巧列表
 * - scoreThresholds: 分数阈值（升序），score ≤ threshold → 对应 difficulty
 * - fallbackDifficulty: 超出所有阈值时使用的难度
 */
class TechniqueGradeRule {
  techniques: Technique[]
  scoreThresholds: number[]
  scoreDifficulties: Difficulty[]
  fallbackDifficulty: Difficulty

  constructor(
    techniques: Technique[],
    scoreThresholds: number[],
    scoreDifficulties: Difficulty[],
    fallbackDifficulty: Difficulty,
  ) {
    this.techniques = techniques
    this.scoreThresholds = scoreThresholds
    this.scoreDifficulties = scoreDifficulties
    this.fallbackDifficulty = fallbackDifficulty
  }
}

/**
 * 技巧分级规则表（按从简到难排列）。
 *
 * 新增技巧只需在此追加一行，无需修改 gradeDifficulty 逻辑。
 */
const TECHNIQUE_GRADE_RULES: TechniqueGradeRule[] = [
  // Naked Single → 简单
  new TechniqueGradeRule(
    [Technique.NAKED_SINGLE],
    [], [],
    Difficulty.EASY,
  ),
  // Hidden Single → 中等（高分则困难）
  new TechniqueGradeRule(
    [Technique.HIDDEN_SINGLE],
    [100], [Difficulty.MEDIUM],
    Difficulty.HARD,
  ),
  // Cage Sum → 中等/困难/专家（笼约束推理需要额外思考）
  new TechniqueGradeRule(
    [Technique.CAGE_SUM],
    [80, 180], [Difficulty.MEDIUM, Difficulty.HARD],
    Difficulty.EXPERT,
  ),
  // Naked Pair / Pointing Pair → 困难（高分则专家）
  new TechniqueGradeRule(
    [Technique.NAKED_PAIR, Technique.POINTING_PAIR],
    [200], [Difficulty.HARD],
    Difficulty.EXPERT,
  ),
  // Box/Line Reduction / X-Wing → 专家
  new TechniqueGradeRule(
    [Technique.BOX_LINE_REDUCTION, Technique.X_WING],
    [], [],
    Difficulty.EXPERT,
  ),
]

/** 分数兜底规则：未命中技巧规则时，按分数段查表 */
const SCORE_FALLBACK_THRESHOLDS: number[] = [50, 100, 200, 400]
const SCORE_FALLBACK_DIFFICULTIES: Difficulty[] = [
  Difficulty.EASY,
  Difficulty.MEDIUM,
  Difficulty.HARD,
  Difficulty.EXPERT,
]

// ============================================================
// Killer 笼约束复杂度
// ============================================================

/** Killer 笼子复杂度加成的基础权重 */
const CAGE_COMPLEXITY_BASE_BONUS = 10
/** 大笼子（>= 4 格）的额外加分倍率 */
const LARGE_CAGE_BONUS_MULTIPLIER = 3
/** CAGE_SUM 技巧每次使用的额外加分 */
const CAGE_SUM_STEP_BONUS = 2

// ============================================================
// 对外接口
// ============================================================

/**
 * 评估谜题难度。
 *
 * 流程：logicSolve → 笼约束加成 → 规则表查找
 *
 * @param board 谜题棋盘
 * @param cages 可选 Killer 笼子（用于笼约束复杂度加成）
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
    grade.difficulty = Difficulty.EVIL
    return grade
  }

  grade.difficulty = gradeDifficulty(result.maxTechnique, adjustedScore)
  return grade
}

/**
 * 判断谜题是否满足目标难度。
 * 用于生成器循环：生成 → 评估 → 符合就用，不符合就重来。
 */
export function matchesDifficulty(board: number[][], target: Difficulty): boolean {
  const grade = evaluateDifficulty(board)
  return grade.difficulty === target
}

// ============================================================
// 内部实现
// ============================================================

/**
 * 根据最高技巧和分数判定难度。
 *
 * 算法：
 *   1. 在 TECHNIQUE_GRADE_RULES 中查找第一个匹配的规则
 *   2. 按规则的分数阈值段确定具体难度
 *   3. 未匹配任何规则时，按 SCORE_FALLBACK 分数段兜底
 */
function gradeDifficulty(maxTechnique: Technique | null, score: number): Difficulty {
  // 规则表查找
  for (const rule of TECHNIQUE_GRADE_RULES) {
    if (matchesTechnique(rule.techniques, maxTechnique)) {
      return resolveByScoreThresholds(score, rule.scoreThresholds, rule.scoreDifficulties, rule.fallbackDifficulty)
    }
  }

  // 兜底：按分数段判定
  return resolveByScoreThresholds(score, SCORE_FALLBACK_THRESHOLDS, SCORE_FALLBACK_DIFFICULTIES, Difficulty.EVIL)
}

/** 检查 maxTechnique 是否在 techniques 列表中 */
function matchesTechnique(techniques: Technique[], maxTechnique: Technique | null): boolean {
  if (maxTechnique === null) return false
  return techniques.indexOf(maxTechnique) !== -1
}

/**
 * 按分数阈值表确定难度。
 *
 * thresholds 与 difficulties 一一对应（升序排列）：
 *   score ≤ thresholds[i] → difficulties[i]
 * 全部超出 → fallback
 */
function resolveByScoreThresholds(
  score: number,
  thresholds: number[],
  difficulties: Difficulty[],
  fallback: Difficulty,
): Difficulty {
  for (let i = 0; i < thresholds.length; i++) {
    if (score <= thresholds[i]) {
      return difficulties[i]
    }
  }
  return fallback
}

/**
 * 计算 Killer 笼约束复杂度加成分数。
 *
 * 三维因子叠加：
 *   1. 笼子数量：笼子越多，约束交互越复杂
 *   2. 大笼子比例：>= 4 格的笼子推理难度更高
 *   3. CAGE_SUM 技巧使用次数：实际求解中用到的笼推理步数
 */
function computeCageComplexityBonus(cages: KillerCage[], result: LogicSolveResult): number {
  // 基础加成：笼子数量 × 基础权重
  const cageCountBonus = Math.floor(cages.length / 3) * CAGE_COMPLEXITY_BASE_BONUS

  // 大笼子加成
  let largeCageCount = 0
  for (const cage of cages) {
    if (cage.cells.length >= 4) {
      largeCageCount++
    }
  }

  // CAGE_SUM 技巧使用次数加成
  let cageSumSteps = 0
  for (const step of result.steps) {
    if (step.technique === Technique.CAGE_SUM) {
      cageSumSteps++
    }
  }

  return cageCountBonus
    + largeCageCount * LARGE_CAGE_BONUS_MULTIPLIER
    + cageSumSteps * CAGE_SUM_STEP_BONUS
}
