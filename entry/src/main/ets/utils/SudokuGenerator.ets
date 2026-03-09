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
import { shuffle, createEmptyGrid, isValidPlacement, getAllFilledPositions, cloneGrid } from './Common'
import { countSolutions } from './SudokuSolver'
import { evaluateDifficulty } from './DifficultyEvaluator'

// ============================================================
// 对称模式
// ============================================================

export enum Symmetry {
  /** 无对称（完全随机挖洞，可产生最少线索） */
  NONE = 'none',
  /** 180° 旋转对称（经典数独美学） */
  ROTATIONAL_180 = 'rot180',
  /** 90° 旋转对称（4-way） */
  ROTATIONAL_90 = 'rot90',
  /** 水平+垂直镜像对称 */
  MIRROR = 'mirror',
}

// ============================================================
// 1. 生成完整终盘
// ============================================================

/**
 * 回溯法随机填充 9×9 棋盘。
 * board 需要传入一个全 0 的 9×9。
 * 返回 true 表示成功（board 已被填满）。
 */
function fillBoard(board: number[][]): boolean {
  for (let row = 0; row < GRID_SIZE; row++) {
    for (let col = 0; col < GRID_SIZE; col++) {
      if (board[row][col] === 0) {
        const numbers = shuffle([1, 2, 3, 4, 5, 6, 7, 8, 9])
        for (const num of numbers) {
          if (isValidPlacement(board, row, col, num)) {
            board[row][col] = num
            if (fillBoard(board)) return true
            board[row][col] = 0
          }
        }
        return false // 1-9 都不行 → 回溯
      }
    }
  }
  return true // 全部填满
}

/**
 * 生成一个随机的完整终盘（9×9，全部合法填满）
 */
export function generateFullBoard(): number[][] {
  const board = createEmptyGrid()
  fillBoard(board)
  return board
}

// ============================================================
// 2. 对称位置计算
// ============================================================

/**
 * 给定一个位置 [r, c]，返回其在指定对称模式下的所有对称位置（含自身）。
 * 去重后返回，中心格 [4,4] 在 180° 对称下只有自身。
 */
function getSymmetricPositions(row: number, col: number, symmetry: Symmetry): number[][] {
  const positions: number[][] = [[row, col]]
  const last = GRID_SIZE - 1

  if (symmetry === Symmetry.ROTATIONAL_180 || symmetry === Symmetry.ROTATIONAL_90) {
    // 180° 旋转: (r,c) → (8-r, 8-c)
    positions.push([last - row, last - col])
  }

  if (symmetry === Symmetry.ROTATIONAL_90) {
    // 额外两个 90° 旋转位置: (r,c) → (c, 8-r), (8-c, r)
    positions.push([col, last - row])
    positions.push([last - col, row])
  }

  if (symmetry === Symmetry.MIRROR) {
    // 水平镜像: (r,c) → (r, 8-c)
    positions.push([row, last - col])
    // 垂直镜像: (r,c) → (8-r, c)
    positions.push([last - row, col])
    // 对角: (r,c) → (8-r, 8-c)
    positions.push([last - row, last - col])
  }

  // 去重
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

// ============================================================
// 3. 挖洞（支持对称）
// ============================================================

/**
 * 从完整终盘中挖洞，生成谜题。
 * 保证唯一解。支持对称挖洞。
 *
 * @param fullBoard 完整终盘（不会被修改）
 * @param holesToDig 期望挖洞数
 * @param symmetry 对称模式
 * @returns 挖好洞的谜题棋盘
 */
function digHoles(fullBoard: number[][], holesToDig: number, symmetry: Symmetry = Symmetry.NONE): number[][] {
  const board = cloneGrid(fullBoard)

  if (symmetry === Symmetry.NONE) {
    // 无对称：经典随机挖洞
    return digHolesRandom(board, holesToDig)
  }

  // 对称挖洞：把所有位置分组，每组是一组对称位置
  const visited = new Set<number>()
  const groups: number[][][] = []

  // 用随机顺序遍历所有位置
  const allPositions = shuffle(getAllFilledPositions(board))

  for (const pos of allPositions) {
    const key = pos[0] * GRID_SIZE + pos[1]
    if (visited.has(key)) continue

    const symPositions = getSymmetricPositions(pos[0], pos[1], symmetry)
    for (const sp of symPositions) {
      visited.add(sp[0] * GRID_SIZE + sp[1])
    }
    groups.push(symPositions)
  }

  // 随机打乱分组顺序
  shuffle(groups)

  let holesRemaining = holesToDig
  for (const group of groups) {
    if (holesRemaining <= 0) break

    // 只挖还有数字的位置
    const toRemove: number[][] = []
    for (const pos of group) {
      if (board[pos[0]][pos[1]] !== 0) {
        toRemove.push(pos)
      }
    }
    if (toRemove.length === 0) continue

    // 尝试挖掉这组
    const backups: number[] = []
    for (const pos of toRemove) {
      backups.push(board[pos[0]][pos[1]])
      board[pos[0]][pos[1]] = 0
    }

    if (countSolutions(board, 2) === 1) {
      holesRemaining -= toRemove.length
    } else {
      // 多解 → 全部放回
      for (let i = 0; i < toRemove.length; i++) {
        board[toRemove[i][0]][toRemove[i][1]] = backups[i]
      }
    }
  }

  return board
}

/** 无对称随机挖洞（原始实现） */
function digHolesRandom(board: number[][], holesToDig: number): number[][] {
  const positions = shuffle(getAllFilledPositions(board))

  let remaining = holesToDig

  for (const pos of positions) {
    if (remaining <= 0) break

    const row = pos[0]
    const col = pos[1]
    const backup = board[row][col]
    board[row][col] = 0

    if (countSolutions(board, 2) === 1) {
      remaining-- // 唯一解 → 挖洞成功
    } else {
      board[row][col] = backup // 多解 → 放回去
    }
  }

  return board
}

// ============================================================
// 4. 选择对称模式
// ============================================================

/** 根据难度选择合适的对称模式 */
function pickSymmetry(difficulty: Difficulty): Symmetry {
  // 简单/中等用对称（美观）；困难以上用不对称（允许更少线索）
  if (difficulty <= Difficulty.EASY) {
    // 简单题：90° 旋转对称（最美观）
    const choices: Symmetry[] = [Symmetry.ROTATIONAL_90, Symmetry.MIRROR]
    return choices[Math.floor(Math.random() * choices.length)]
  }
  if (difficulty <= Difficulty.MEDIUM) {
    // 中等题：180° 旋转对称
    return Symmetry.ROTATIONAL_180
  }
  if (difficulty <= Difficulty.HARD) {
    // 困难题：180° 或无对称
    return Math.random() < 0.5 ? Symmetry.ROTATIONAL_180 : Symmetry.NONE
  }
  // 专家/地狱：无对称（允许最少线索）
  return Symmetry.NONE
}

// ============================================================
// 5. 对外接口
// ============================================================

export interface GeneratedPuzzle {
  puzzle: number[][]
  solution: number[][]
  /** 实际使用的对称模式 */
  symmetry: Symmetry
  /** 逻辑评估出的实际难度（可能与请求不同） */
  actualDifficulty: Difficulty
  /** 难度评分 */
  score: number
}

/**
 * 生成指定难度的数独题目。
 *
 * 新流程（参考 Simon Tatham Solo）：
 *   1. 生成完整终盘
 *   2. 选择对称模式，挖洞
 *   3. 用 LogicSolver 评估难度
 *   4. 如果不匹配目标难度，重试（最多 MAX_ATTEMPTS 次）
 *   5. 超过次数仍未匹配，返回最接近目标难度的一个
 *
 * @param difficulty 目标难度等级
 * @param preferredSymmetry 可选，玩家指定的对称模式（不传则自动选择）
 * @returns 谜题 + 答案 + 元信息
 */
export function generatePuzzle(difficulty: Difficulty, preferredSymmetry?: Symmetry): GeneratedPuzzle {
  const config = getDifficultyConfig(difficulty)
  const MAX_ATTEMPTS = 20

  let bestPuzzle: GeneratedPuzzle | null = null
  let bestDiff = 999 // 与目标难度的差距

  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const solution = generateFullBoard()
    const symmetry = preferredSymmetry ?? pickSymmetry(difficulty)
    const puzzle = digHoles(solution, config.holesToDig, symmetry)

    // 用 LogicSolver 评估实际难度
    const grade = evaluateDifficulty(puzzle)

    const candidate: GeneratedPuzzle = {
      puzzle: puzzle,
      solution: cloneGrid(solution),
      symmetry: symmetry,
      actualDifficulty: grade.difficulty,
      score: grade.score,
    }

    // 完全匹配 → 直接返回
    if (grade.difficulty === difficulty) {
      return candidate
    }

    // 记录最接近的
    const diff = Math.abs(grade.difficulty - difficulty)
    if (diff < bestDiff) {
      bestDiff = diff
      bestPuzzle = candidate
    }
  }

  // 没有完美匹配，返回最接近的
  return bestPuzzle!
}
