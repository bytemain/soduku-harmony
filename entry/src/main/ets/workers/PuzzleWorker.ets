/**
 * PuzzleWorker.ets — 独立线程生成数独谜题
 *
 * 将 CPU 密集的 generatePuzzle / generatePuzzleFromSeed / solve
 * 放到 Worker 线程执行，避免阻塞 UI 渲染（Loading 动画卡顿）。
 */
import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS'
import { generatePuzzle, generatePuzzleFromSeed, decodeSeedId, Symmetry } from '../utils/SudokuGenerator'
import { solve } from '../utils/SudokuSolver'
import { parse81String } from '../utils/SudokuFormat'
import { evaluateDifficulty } from '../utils/DifficultyEvaluator'
import { Difficulty } from '../constants/GameConstants'

const workerPort: ThreadWorkerGlobalScope = worker.workerPort

/**
 * 消息类型定义：
 *
 * 1. 普通生成:
 *    { type: 'generate', difficulty: number, symmetry?: string }
 *
 * 2. 种子生成:
 *    { type: 'generateFromSeed', seedId: string }
 *
 * 3. 导入谜题:
 *    { type: 'import', puzzle81: string, difficulty?: number }
 */
workerPort.onmessage = (e: MessageEvents): void => {
  const msg = e.data as Record<string, Object>
  const type = msg['type'] as string

  try {
    if (type === 'generate') {
      const difficulty = msg['difficulty'] as number as Difficulty
      const symmetryStr = msg['symmetry'] as string | undefined
      const symmetry = symmetryStr ? symmetryStr as Symmetry : undefined
      const result = generatePuzzle(difficulty, symmetry)

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
        const result = generatePuzzleFromSeed(decoded.seed, decoded.difficulty, decoded.symmetry)
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
      const parsed = parse81String(puzzle81)
      const puzzleBoard = parsed.board
      const solution = solve(puzzleBoard)

      if (solution) {
        // 尝试评估难度
        let difficulty = msg['difficulty'] as number | undefined
        if (difficulty === undefined || difficulty === null) {
          try {
            const grade = evaluateDifficulty(puzzleBoard)
            difficulty = grade.difficulty
          } catch (_e) {
            difficulty = Difficulty.MEDIUM
          }
        }

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

workerPort.onerror = (e: ErrorEvent): void => {
  // Worker 内部异常
}
