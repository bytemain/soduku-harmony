/**
 * SudokuGenerator.ets — 数独题目生成器
 *
 * 两步法：
 *   1. generateFullBoard() — 回溯法随机生成完整终盘
 *   2. digHoles() — 从终盘中挖洞，保证唯一解
 *
 * 参考：Doc 01 §3
 */
import { GRID_SIZE } from '../constants/GameConstants'
import { Difficulty, getDifficultyConfig } from '../constants/GameConstants'
import { shuffle, createEmptyGrid, isValidPlacement, getAllFilledPositions, cloneGrid } from './Common'
import { countSolutions } from './SudokuSolver'

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
// 2. 挖洞
// ============================================================

/**
 * 从完整终盘中挖洞，生成谜题。
 * 保证唯一解。
 *
 * @param fullBoard 完整终盘（不会被修改）
 * @param holesToDig 期望挖洞数
 * @returns 挖好洞的谜题棋盘
 */
function digHoles(fullBoard: number[][], holesToDig: number): number[][] {
  const board = cloneGrid(fullBoard)
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
// 对外接口
// ============================================================

export interface GeneratedPuzzle {
  puzzle: number[][]
  solution: number[][]
}

/**
 * 生成指定难度的数独题目
 *
 * @param difficulty 难度等级
 * @returns 谜题 + 答案
 */
export function generatePuzzle(difficulty: Difficulty): GeneratedPuzzle {
  const config = getDifficultyConfig(difficulty)
  const solution = generateFullBoard()
  const puzzle = digHoles(solution, config.holesToDig)

  return {
    puzzle: puzzle,
    solution: cloneGrid(solution),
  }
}
