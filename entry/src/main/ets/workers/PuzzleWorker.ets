/**
 * PuzzleWorker.ets — 独立线程生成数独谜题
 *
 * 将 CPU 密集的 generatePuzzle / generatePuzzleFromSeed / solve
 * 放到 Worker 线程执行，避免阻塞 UI 渲染（Loading 动画卡顿）。
 *
 * 设计模式：
 *   - 策略分离：变种拓扑初始化通过 applyVariantTopology() 统一处理
 *   - 消息路由：onmessage 中按 type 路由到独立处理函数
 *   - 笼子生成复用：buildKillerCagesForResult() 消除重复逻辑
 */
import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS'
import {
  decodeSeedId,
  generatePuzzle,
  generatePuzzleFromSeed,
  GeneratedPuzzle,
  GenerationProgressCallback,
  GenerationProgressPhase,
  Symmetry,
} from '../utils/SudokuGenerator'
import { solve } from '../utils/SudokuSolver'
import { parse81String } from '../utils/SudokuFormat'
import { evaluateDifficulty } from '../utils/DifficultyEvaluator'
import { Difficulty, applyGridConfig } from '../constants/GameConstants'
import {
  getGridConfigBySize,
  createSizedConfig,
  VariantType,
  createDiagonalConfig,
  createJigsawConfig,
  createKillerConfig,
  KillerCage,
} from '../models/VariantConfig'
import { normalizeVariantType, generateRandomCageLayout, buildKillerCagesFromSolution } from '../utils/KillerSudoku'
import { generateRandomRegionMap } from '../utils/JigsawGenerator'
import { applyTopology } from '../utils/Topology'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { SeededRandom } from '../utils/Common'

const workerPort: ThreadWorkerGlobalScope = worker.workerPort

let lastSentPhase: string = ''
let lastSentProgress: number = -1

/** 变种模式的最大尝试次数（变种拓扑使求解更慢，减少重试以避免长时间卡住） */
const VARIANT_MAX_ATTEMPTS = 5
/** 标准模式的最大尝试次数 */
const STANDARD_MAX_ATTEMPTS = 20

// ============================================================
// 进度上报
// ============================================================

function postProgress(phase: string, progress: number, attempt?: number, totalAttempts?: number): void {
  if (phase === lastSentPhase && Math.abs(progress - lastSentProgress) < 1) {
    return
  }

  lastSentPhase = phase
  lastSentProgress = progress

  try {
    workerPort.postMessage({
      type: 'progress',
      phase: phase,
      progress: progress,
      attempt: attempt ?? null,
      totalAttempts: totalAttempts ?? null,
    })
  } catch (_e) {
    hilog.warn(0x0000, 'PuzzleWorker', 'progress postMessage failed')
  }
}

function createProgressCallback(): GenerationProgressCallback {
  return (
    phase: GenerationProgressPhase,
    progress: number,
    attempt?: number,
    totalAttempts?: number,
  ): void => {
    postProgress(phase, progress, attempt, totalAttempts)
  }
}

// ============================================================
// 变种拓扑策略（统一入口，替代分散的 if-chain）
// ============================================================

/**
 * 变种拓扑初始化的结果。
 * 携带 Jigsaw regionMap 等附加数据，供后续消息返回给主线程。
 */
class VariantTopologyResult {
  jigsawRegionMap: number[] | null = null
}

/**
 * 根据变种类型应用拓扑。
 * Killer 模式先用标准拓扑生成题面，后续叠加笼子拓扑。
 */
function applyVariantTopology(
  variantType: string,
  gridSize: number | undefined,
): VariantTopologyResult {
  const result = new VariantTopologyResult()

  switch (variantType) {
    case VariantType.DIAGONAL:
      applyTopology(createDiagonalConfig())
      break

    case VariantType.JIGSAW: {
      const regionMap = generateRandomRegionMap()
      result.jigsawRegionMap = regionMap
      applyTopology(createJigsawConfig(regionMap))
      break
    }

    case VariantType.KILLER:
      // Killer 先用标准拓扑生成终盘，笼子在生成后叠加
      break

    default:
      if (gridSize !== undefined) {
        const cfg = getGridConfigBySize(gridSize)
        applyTopology(createSizedConfig(cfg.gridSize, cfg.boxRows, cfg.boxCols))
      }
      break
  }

  return result
}

// ============================================================
// Killer 笼子生成（消除重复）
// ============================================================

/**
 * 为 Killer 模式生成随机笼子布局并叠加拓扑。
 *
 * @param solution 二维解答棋盘
 * @param seed 随机种子
 * @param difficulty 难度等级（用于决定是否合并单格笼）
 * @returns 序列化后的笼子数据，非 Killer 模式返回 null
 */
function buildKillerCagesForResult(
  variantType: string,
  solution: number[][],
  seed: number,
  difficulty: Difficulty,
): KillerCage[] | null {
  if (variantType !== VariantType.KILLER) {
    return null
  }

  const flatSolution: number[] = []
  for (const row of solution) {
    for (const v of row) flatSolution.push(v)
  }

  const cageRng = new SeededRandom(seed)
  const noSingleCell = difficulty >= Difficulty.HARD
  const layout = generateRandomCageLayout(flatSolution, cageRng, noSingleCell)
  const cages = buildKillerCagesFromSolution(flatSolution, layout)
  applyTopology(createKillerConfig(cages))
  return cages
}

// ============================================================
// 消息路由 — 按类型分发到独立处理函数
// ============================================================

function generateVariantPuzzle(difficulty: Difficulty, variantType: string, symmetry?: Symmetry): GeneratedPuzzle {
  const progressCallback = createProgressCallback()
  const maxAttempts = variantType === VariantType.STANDARD ? STANDARD_MAX_ATTEMPTS : VARIANT_MAX_ATTEMPTS
  return generatePuzzle(difficulty, symmetry, progressCallback, maxAttempts)
}

function generateVariantPuzzleFromSeed(seed: number, difficulty: Difficulty, symmetry: Symmetry): GeneratedPuzzle {
  const progressCallback = createProgressCallback()
  return generatePuzzleFromSeed(seed, difficulty, symmetry, progressCallback)
}

/** 处理 'generate' 消息 */
function handleGenerate(msg: Record<string, Object>, variantType: string, topoResult: VariantTopologyResult): void {
  const difficulty = msg['difficulty'] as number as Difficulty
  const symmetryStr = msg['symmetry'] as string | undefined
  const symmetry = symmetryStr ? symmetryStr as Symmetry : undefined
  const result = generateVariantPuzzle(difficulty, variantType, symmetry)

  const killerCages = buildKillerCagesForResult(variantType, result.solution, result.seed, difficulty)

  workerPort.postMessage({
    type: 'result',
    action: 'generate',
    puzzle: result.puzzle,
    solution: result.solution,
    seed: result.seed,
    symmetry: result.symmetry,
    actualDifficulty: result.actualDifficulty,
    score: result.score,
    difficulty: difficulty,
    killerCages: killerCages,
    jigsawRegionMap: topoResult.jigsawRegionMap,
  })
}

/** 处理 'generateFromSeed' 消息 */
function handleGenerateFromSeed(msg: Record<string, Object>, variantType: string, topoResult: VariantTopologyResult): void {
  const seedId = msg['seedId'] as string
  const decoded = decodeSeedId(seedId)
  if (decoded === null) {
    workerPort.postMessage({ type: 'error', message: 'Invalid seed ID' })
    return
  }

  const result = generateVariantPuzzleFromSeed(decoded.seed, decoded.difficulty, decoded.symmetry)
  const killerCages = buildKillerCagesForResult(variantType, result.solution, decoded.seed, decoded.difficulty)

  workerPort.postMessage({
    type: 'result',
    action: 'generateFromSeed',
    puzzle: result.puzzle,
    solution: result.solution,
    seed: result.seed,
    symmetry: result.symmetry,
    actualDifficulty: result.actualDifficulty,
    score: result.score,
    difficulty: decoded.difficulty,
    killerCages: killerCages,
    jigsawRegionMap: topoResult.jigsawRegionMap,
  })
}

/** 处理 'import' 消息 */
function handleImport(msg: Record<string, Object>): void {
  const puzzle81 = msg['puzzle81'] as string
  postProgress('importing_puzzle', 15, 1, 1)
  const parsed = parse81String(puzzle81)
  const puzzleBoard = parsed.board

  postProgress('solving_puzzle', 55, 1, 1)
  const solution = solve(puzzleBoard)

  if (!solution) {
    workerPort.postMessage({ type: 'error', message: 'puzzle_no_solution' })
    return
  }

  let difficulty = msg['difficulty'] as number | undefined
  if (difficulty === undefined || difficulty === null) {
    try {
      postProgress('evaluating_difficulty', 85, 1, 1)
      const grade = evaluateDifficulty(puzzleBoard)
      difficulty = grade.difficulty
    } catch (_e) {
      difficulty = Difficulty.MEDIUM
    }
  }

  postProgress('finalizing', 100, 1, 1)
  workerPort.postMessage({
    type: 'result',
    action: 'import',
    puzzle: puzzleBoard,
    solution: solution,
    difficulty: difficulty,
  })
}

// ============================================================
// Worker 主入口
// ============================================================

workerPort.onmessage = (e: MessageEvents): void => {
  const msg = e.data as Record<string, Object>
  const type = msg['type'] as string

  // 重置节流状态
  lastSentPhase = ''
  lastSentProgress = -1

  // 应用棋盘尺寸配置
  const gridSize = msg['gridSize'] as number | undefined
  const variantTypeRaw = (msg['variantType'] as string | undefined) ?? VariantType.STANDARD
  const variantType = normalizeVariantType(variantTypeRaw)
  if (gridSize !== undefined) {
    const cfg = getGridConfigBySize(gridSize)
    applyGridConfig(cfg)
  }

  // 统一应用变种拓扑
  const topoResult = applyVariantTopology(variantType, gridSize)

  try {
    switch (type) {
      case 'generate':
        handleGenerate(msg, variantType, topoResult)
        break
      case 'generateFromSeed':
        handleGenerateFromSeed(msg, variantType, topoResult)
        break
      case 'import':
        handleImport(msg)
        break
      default:
        workerPort.postMessage({ type: 'error', message: `Unknown message type: ${type}` })
        break
    }
  } catch (e) {
    workerPort.postMessage({ type: 'error', message: String(e) })
  }
}

workerPort.onerror = (_e: ErrorEvent): void => {
}
