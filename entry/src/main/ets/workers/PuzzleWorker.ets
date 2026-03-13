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
  GenerationProgressPhase,
  Symmetry,
} from '../utils/SudokuGenerator'
import { solve } from '../utils/SudokuSolver'
import { parse81String } from '../utils/SudokuFormat'
import { evaluateDifficulty } from '../utils/DifficultyEvaluator'
import { Difficulty, applyGridConfig } from '../constants/GameConstants'
import { getGridConfigBySize, createSizedConfig } from '../models/VariantConfig'
import { applyTopology } from '../utils/Topology'

const workerPort: ThreadWorkerGlobalScope = worker.workerPort

let lastSentPhase: string = ''
let lastSentProgress: number = -1

function postProgress(phase: string, progress: number, attempt?: number, totalAttempts?: number): void {
  // Throttle: only send when phase changes or progress changes by >= 2 points
  if (phase === lastSentPhase && Math.abs(progress - lastSentProgress) < 2) {
    return
  }

  lastSentPhase = phase
  lastSentProgress = progress

  workerPort.postMessage({
    type: 'progress',
    phase: phase,
    progress: progress,
    attempt: attempt ?? null,
    totalAttempts: totalAttempts ?? null,
  })
}

workerPort.onmessage = (e: MessageEvents): void => {
  const msg = e.data as Record<string, Object>
  const type = msg['type'] as string

  // Reset throttle state for each new generation request
  lastSentPhase = ''
  lastSentProgress = -1

  // Apply grid config if provided (for variant sizes)
  const gridSize = msg['gridSize'] as number | undefined
  if (gridSize !== undefined) {
    const cfg = getGridConfigBySize(gridSize)
    applyGridConfig(cfg)
    applyTopology(createSizedConfig(cfg.gridSize, cfg.boxRows, cfg.boxCols))
  }

  try {
    if (type === 'generate') {
      const difficulty = msg['difficulty'] as number as Difficulty
      const symmetryStr = msg['symmetry'] as string | undefined
      const symmetry = symmetryStr ? symmetryStr as Symmetry : undefined
      const result = generatePuzzle(difficulty, symmetry, (
        phase: GenerationProgressPhase,
        progress: number,
        attempt?: number,
        totalAttempts?: number,
      ): void => {
        postProgress(phase, progress, attempt, totalAttempts)
      })

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
      })
    } else if (type === 'generateFromSeed') {
      const seedId = msg['seedId'] as string
      const decoded = decodeSeedId(seedId)
      if (decoded !== null) {
        const result = generatePuzzleFromSeed(
          decoded.seed,
          decoded.difficulty,
          decoded.symmetry,
          (phase: GenerationProgressPhase, progress: number, attempt?: number, totalAttempts?: number): void => {
            postProgress(phase, progress, attempt, totalAttempts)
          },
        )

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
