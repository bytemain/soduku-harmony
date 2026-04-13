/**
 * PuzzleWorker.ets — 独立线程生成数独谜题
 *
 * 将 CPU 密集的 generatePuzzle / generatePuzzleFromSeed / solve
 * 放到 Worker 线程执行，避免阻塞 UI 渲染（Loading 动画卡顿）。
 */
import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS'
import {
  decodeSeedId,
  generatePuzzle,
  generatePuzzleFromSeed,
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

function postProgress(phase: string, progress: number, attempt?: number, totalAttempts?: number): void {
  // Throttle: only send when phase changes or progress changes by >= 1 point
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
    // 进度消息发送失败不影响生成主流程，交由后续 result/error 消息兜底。
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

function generateVariantPuzzle(difficulty: Difficulty, variantType: string, symmetry?: Symmetry) {
  const progressCallback = createProgressCallback()
  const maxAttempts = variantType === VariantType.STANDARD ? STANDARD_MAX_ATTEMPTS : VARIANT_MAX_ATTEMPTS
  return generatePuzzle(difficulty, symmetry, progressCallback, maxAttempts)
}

function generateVariantPuzzleFromSeed(seed: number, difficulty: Difficulty, symmetry: Symmetry) {
  const progressCallback = createProgressCallback()
  return generatePuzzleFromSeed(seed, difficulty, symmetry, progressCallback)
}

workerPort.onmessage = (e: MessageEvents): void => {
  const msg = e.data as Record<string, Object>
  const type = msg['type'] as string

  // Reset throttle state for each new generation request
  lastSentPhase = ''
  lastSentProgress = -1

  // Apply grid config if provided (for variant sizes)
  const gridSize = msg['gridSize'] as number | undefined
  const variantTypeRaw = (msg['variantType'] as string | undefined) ?? VariantType.STANDARD
  const variantType = normalizeVariantType(variantTypeRaw)
  if (gridSize !== undefined) {
    const cfg = getGridConfigBySize(gridSize)
    applyGridConfig(cfg)
  }
  // 根据变种类型构建拓扑（无论是否指定 gridSize 都需要应用）
  // Killer 模式先用标准拓扑生成题面，再叠加笼子拓扑
  // Jigsaw 模式使用随机生成的不规则区域
  let jigsawRegionMapData: number[] | null = null
  if (variantType === VariantType.DIAGONAL) {
    applyTopology(createDiagonalConfig())
  } else if (variantType === VariantType.JIGSAW) {
    const regionMap = generateRandomRegionMap()
    jigsawRegionMapData = regionMap
    applyTopology(createJigsawConfig(regionMap))
  } else if (gridSize !== undefined) {
    const cfg = getGridConfigBySize(gridSize)
    applyTopology(createSizedConfig(cfg.gridSize, cfg.boxRows, cfg.boxCols))
  }

  try {
    if (type === 'generate') {
      const difficulty = msg['difficulty'] as number as Difficulty
      const symmetryStr = msg['symmetry'] as string | undefined
      const symmetry = symmetryStr ? symmetryStr as Symmetry : undefined
      const result = generateVariantPuzzle(difficulty, variantType, symmetry)

      // Killer 模式：生成随机笼子并叠加拓扑
      let killerCagesData: object[] | null = null
      if (variantType === VariantType.KILLER) {
        const flatSolution: number[] = []
        for (const row of result.solution) {
          for (const v of row) flatSolution.push(v)
        }
        const cageRng = new SeededRandom(result.seed)
        const noSingleCell = difficulty >= Difficulty.HARD
        const layout = generateRandomCageLayout(flatSolution, cageRng, noSingleCell)
        const cages = buildKillerCagesFromSolution(flatSolution, layout)
        applyTopology(createKillerConfig(cages))
        killerCagesData = cages.map(c => {
          const cage: KillerCage = { cells: c.cells, sum: c.sum }
          return cage
        })
      }

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
        killerCages: killerCagesData,
        jigsawRegionMap: jigsawRegionMapData,
      })
    } else if (type === 'generateFromSeed') {
      const seedId = msg['seedId'] as string
      const decoded = decodeSeedId(seedId)
      if (decoded !== null) {
        const result = generateVariantPuzzleFromSeed(decoded.seed, decoded.difficulty, decoded.symmetry)

        let killerCagesData: object[] | null = null
        if (variantType === VariantType.KILLER) {
          const flatSolution: number[] = []
          for (const row of result.solution) {
            for (const v of row) flatSolution.push(v)
          }
          const cageRng = new SeededRandom(decoded.seed)
          const noSingleCell = decoded.difficulty >= Difficulty.HARD
          const layout = generateRandomCageLayout(flatSolution, cageRng, noSingleCell)
          const cages = buildKillerCagesFromSolution(flatSolution, layout)
          applyTopology(createKillerConfig(cages))
          killerCagesData = cages.map(c => {
            const cage: KillerCage = { cells: c.cells, sum: c.sum }
            return cage
          })
        }

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
          killerCages: killerCagesData,
          jigsawRegionMap: jigsawRegionMapData,
        })
      } else {
        workerPort.postMessage({ type: 'error', message: 'Invalid seed ID' })
      }
    } else if (type === 'import') {
      const puzzle81 = msg['puzzle81'] as string
      postProgress('importing_puzzle', 15, 1, 1)
      const parsed = parse81String(puzzle81)
      const puzzleBoard = parsed.board

      postProgress('solving_puzzle', 55, 1, 1)
      const solution = solve(puzzleBoard)

      if (solution) {
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
      } else {
        workerPort.postMessage({ type: 'error', message: 'puzzle_no_solution' })
      }
    } else {
      workerPort.postMessage({ type: 'error', message: `Unknown message type: ${type}` })
    }
  } catch (e) {
    workerPort.postMessage({ type: 'error', message: String(e) })
  }
}

workerPort.onerror = (_e: ErrorEvent): void => {
}
