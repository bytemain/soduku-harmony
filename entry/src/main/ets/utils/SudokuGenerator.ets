/**
 * SudokuGenerator.ets — 数独题目生成器
 *
 * 三步法：
 *   1. generateFullBoard() — 回溯法随机生成完整终盘
 *   2. digHoles() — 从终盘中挖洞，支持对称模式，保证唯一解
 *   3. 逻辑难度校验 — 用 LogicSolver 评估是否符合目标难度
 *
 * 参考：Doc 01 §3, Simon Tatham Solo
 */
import { GRID_SIZE } from '../constants/GameConstants'
import { Difficulty, getDifficultyConfig } from '../constants/GameConstants'
import {
  cloneGrid,
  createEmptyGrid,
  getAllFilledPositions,
  isValidPlacement,
  randomSeed,
  seededShuffle,
  SeededRandom,
} from './Common'
import { countSolutions } from './SudokuSolver'
import { evaluateDifficulty } from './DifficultyEvaluator'

export enum Symmetry {
  NONE = 'none',
  ROTATIONAL_180 = 'rot180',
  ROTATIONAL_90 = 'rot90',
  MIRROR = 'mirror',
}

export type GenerationProgressPhase =
  'generating_solution' |
  'digging_holes' |
  'evaluating_difficulty' |
  'retrying_generation' |
  'finalizing'

export type GenerationProgressCallback = (
  phase: GenerationProgressPhase,
  progress: number,
  attempt?: number,
  totalAttempts?: number,
) => void

function reportProgress(
  callback: GenerationProgressCallback | undefined,
  phase: GenerationProgressPhase,
  progress: number,
  attempt?: number,
  totalAttempts?: number,
): void {
  if (callback) {
    callback(phase, Math.max(0, Math.min(100, Math.round(progress))), attempt, totalAttempts)
  }
}

function fillBoard(board: number[][], rng: SeededRandom): boolean {
  for (let row = 0; row < GRID_SIZE; row++) {
    for (let col = 0; col < GRID_SIZE; col++) {
      if (board[row][col] === 0) {
        const numbers = seededShuffle([1, 2, 3, 4, 5, 6, 7, 8, 9], rng)
        for (const num of numbers) {
          if (isValidPlacement(board, row, col, num)) {
            board[row][col] = num
            if (fillBoard(board, rng)) {
              return true
            }
            board[row][col] = 0
          }
        }
        return false
      }
    }
  }
  return true
}

export function generateFullBoard(rng?: SeededRandom): number[][] {
  const board = createEmptyGrid()
  fillBoard(board, rng ?? new SeededRandom(randomSeed()))
  return board
}

function getSymmetricPositions(row: number, col: number, symmetry: Symmetry): number[][] {
  const positions: number[][] = [[row, col]]
  const last = GRID_SIZE - 1

  if (symmetry === Symmetry.ROTATIONAL_180 || symmetry === Symmetry.ROTATIONAL_90) {
    positions.push([last - row, last - col])
  }

  if (symmetry === Symmetry.ROTATIONAL_90) {
    positions.push([col, last - row])
    positions.push([last - col, row])
  }

  if (symmetry === Symmetry.MIRROR) {
    positions.push([row, last - col])
    positions.push([last - row, col])
    positions.push([last - row, last - col])
  }

  const seen = new Set<number>()
  const unique: number[][] = []
  for (const pos of positions) {
    const key = pos[0] * GRID_SIZE + pos[1]
    if (!seen.has(key)) {
      seen.add(key)
      unique.push(pos)
    }
  }
  return unique
}

function digHoles(
  fullBoard: number[][],
  holesToDig: number,
  symmetry: Symmetry = Symmetry.NONE,
  rng?: SeededRandom,
  progressCallback?: GenerationProgressCallback,
  attempt?: number,
  totalAttempts?: number,
): number[][] {
  const board = cloneGrid(fullBoard)
  const random = rng ?? new SeededRandom(randomSeed())

  if (symmetry === Symmetry.NONE) {
    return digHolesRandom(board, holesToDig, random, progressCallback, attempt, totalAttempts)
  }

  const visited = new Set<number>()
  const groups: number[][][] = []
  const allPositions = seededShuffle(getAllFilledPositions(board), random)

  for (const pos of allPositions) {
    const key = pos[0] * GRID_SIZE + pos[1]
    if (visited.has(key)) {
      continue
    }

    const symPositions = getSymmetricPositions(pos[0], pos[1], symmetry)
    for (const item of symPositions) {
      visited.add(item[0] * GRID_SIZE + item[1])
    }
    groups.push(symPositions)
  }

  seededShuffle(groups, random)

  const totalGroups = Math.max(groups.length, 1)
  let holesRemaining = holesToDig
  for (let groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    if (holesRemaining <= 0) {
      break
    }

    const group = groups[groupIndex]
    const toRemove: number[][] = []
    for (const pos of group) {
      if (board[pos[0]][pos[1]] !== 0) {
        toRemove.push(pos)
      }
    }
    if (toRemove.length === 0) {
      reportProgress(progressCallback, 'digging_holes', 25 + ((groupIndex + 1) / totalGroups) * 50, attempt, totalAttempts)
      continue
    }

    const backups: number[] = []
    for (const pos of toRemove) {
      backups.push(board[pos[0]][pos[1]])
      board[pos[0]][pos[1]] = 0
    }

    if (countSolutions(board, 2) === 1) {
      holesRemaining -= toRemove.length
    } else {
      for (let i = 0; i < toRemove.length; i++) {
        board[toRemove[i][0]][toRemove[i][1]] = backups[i]
      }
    }

    reportProgress(progressCallback, 'digging_holes', 25 + ((groupIndex + 1) / totalGroups) * 50, attempt, totalAttempts)
  }

  return board
}

function digHolesRandom(
  board: number[][],
  holesToDig: number,
  rng: SeededRandom,
  progressCallback?: GenerationProgressCallback,
  attempt?: number,
  totalAttempts?: number,
): number[][] {
  const positions = seededShuffle(getAllFilledPositions(board), rng)
  const totalPositions = Math.max(positions.length, 1)
  let remaining = holesToDig

  for (let i = 0; i < positions.length; i++) {
    if (remaining <= 0) {
      break
    }

    const row = positions[i][0]
    const col = positions[i][1]
    const backup = board[row][col]
    board[row][col] = 0

    if (countSolutions(board, 2) === 1) {
      remaining--
    } else {
      board[row][col] = backup
    }

    reportProgress(progressCallback, 'digging_holes', 25 + ((i + 1) / totalPositions) * 50, attempt, totalAttempts)
  }

  return board
}

function pickSymmetry(difficulty: Difficulty, rng: SeededRandom): Symmetry {
  if (difficulty <= Difficulty.EASY) {
    const choices: Symmetry[] = [Symmetry.ROTATIONAL_90, Symmetry.MIRROR]
    return choices[rng.nextInt(choices.length)]
  }
  if (difficulty <= Difficulty.MEDIUM) {
    return Symmetry.ROTATIONAL_180
  }
  if (difficulty <= Difficulty.HARD) {
    return rng.next() < 0.5 ? Symmetry.ROTATIONAL_180 : Symmetry.NONE
  }
  return Symmetry.NONE
}

export interface GeneratedPuzzle {
  puzzle: number[][]
  solution: number[][]
  seed: number
  symmetry: Symmetry
  actualDifficulty: Difficulty
  score: number
}

export function encodeSeedId(difficulty: Difficulty, symmetry: Symmetry, seed: number): string {
  return `${difficulty}:${symmetry}:${seed}`
}

export class DecodedSeed {
  difficulty: Difficulty
  symmetry: Symmetry
  seed: number

  constructor(difficulty: Difficulty, symmetry: Symmetry, seed: number) {
    this.difficulty = difficulty
    this.symmetry = symmetry
    this.seed = seed
  }
}

export function decodeSeedId(seedId: string): DecodedSeed | null {
  const parts = seedId.split(':')
  if (parts.length !== 3) {
    return null
  }

  const difficulty = parseInt(parts[0]) as Difficulty
  if (difficulty < 1 || difficulty > 5) {
    return null
  }

  const symmetry = parts[1] as Symmetry
  const seed = parseInt(parts[2])
  if (isNaN(seed)) {
    return null
  }

  return new DecodedSeed(difficulty, symmetry, seed)
}

export function generatePuzzle(
  difficulty: Difficulty,
  preferredSymmetry?: Symmetry,
  progressCallback?: GenerationProgressCallback,
): GeneratedPuzzle {
  const config = getDifficultyConfig(difficulty)
  const maxAttempts = 20

  // Wrap callback to produce globally monotonic progress across retries.
  // Uses exponential decay so early attempts get more progress range.
  const DECAY = 0.5
  const TOTAL_RANGE = 95 // reserve 5% for finalizing
  let maxProgressSent = 0

  const globalCallback: GenerationProgressCallback | undefined = progressCallback ? (
    phase: GenerationProgressPhase,
    progress: number,
    attempt?: number,
    _totalAttempts?: number,
  ): void => {
    const a = (attempt ?? 1) - 1
    const rangeStart = TOTAL_RANGE * (1 - Math.pow(DECAY, a))
    const rangeEnd = TOTAL_RANGE * (1 - Math.pow(DECAY, a + 1))
    let globalProgress = rangeStart + (progress / 100) * (rangeEnd - rangeStart)

    if (globalProgress > maxProgressSent) {
      maxProgressSent = globalProgress
    } else {
      globalProgress = maxProgressSent
    }

    progressCallback!(phase, Math.max(0, Math.min(TOTAL_RANGE, Math.round(globalProgress))), attempt, _totalAttempts)
  } : undefined

  let bestPuzzle: GeneratedPuzzle | null = null
  let bestDiff = 999

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const attemptNumber = attempt + 1
    const seed = randomSeed()
    const rng = new SeededRandom(seed)

    reportProgress(globalCallback, 'generating_solution', 10, attemptNumber, maxAttempts)
    const solution = generateFullBoard(rng)

    const symmetry = preferredSymmetry ?? pickSymmetry(difficulty, rng)
    reportProgress(globalCallback, 'digging_holes', 25, attemptNumber, maxAttempts)
    const puzzle = digHoles(solution, config.holesToDig, symmetry, rng, globalCallback, attemptNumber, maxAttempts)

    reportProgress(globalCallback, 'evaluating_difficulty', 85, attemptNumber, maxAttempts)
    const grade = evaluateDifficulty(puzzle)

    const candidate: GeneratedPuzzle = {
      puzzle: puzzle,
      solution: cloneGrid(solution),
      seed: seed,
      symmetry: symmetry,
      actualDifficulty: grade.difficulty,
      score: grade.score,
    }

    if (grade.difficulty === difficulty) {
      reportProgress(progressCallback, 'finalizing', 100, attemptNumber, maxAttempts)
      return candidate
    }

    const diff = Math.abs(grade.difficulty - difficulty)
    if (diff < bestDiff) {
      bestDiff = diff
      bestPuzzle = candidate
    }

    reportProgress(globalCallback, 'retrying_generation', 95, attemptNumber, maxAttempts)
  }

  reportProgress(progressCallback, 'finalizing', 100, maxAttempts, maxAttempts)
  return bestPuzzle!
}

export function generatePuzzleFromSeed(
  seed: number,
  difficulty: Difficulty,
  symmetry: Symmetry,
  progressCallback?: GenerationProgressCallback,
): GeneratedPuzzle {
  const config = getDifficultyConfig(difficulty)
  const rng = new SeededRandom(seed)

  reportProgress(progressCallback, 'generating_solution', 10, 1, 1)
  const solution = generateFullBoard(rng)

  reportProgress(progressCallback, 'digging_holes', 25, 1, 1)
  const puzzle = digHoles(solution, config.holesToDig, symmetry, rng, progressCallback, 1, 1)

  reportProgress(progressCallback, 'evaluating_difficulty', 85, 1, 1)
  const grade = evaluateDifficulty(puzzle)

  const result: GeneratedPuzzle = {
    puzzle: puzzle,
    solution: cloneGrid(solution),
    seed: seed,
    symmetry: symmetry,
    actualDifficulty: grade.difficulty,
    score: grade.score,
  }

  reportProgress(progressCallback, 'finalizing', 100, 1, 1)
  return result
}
