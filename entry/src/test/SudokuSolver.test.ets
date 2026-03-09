import { describe, it, expect } from '@ohos/hypium'
import { solve, countSolutions, hasSolution, hasUniqueSolution } from '../main/ets/utils/SudokuSolver'
import { createEmptyGrid } from '../main/ets/utils/Common'

// 一道标准数独题（来自 Norvig 的测试用例之一）
function getTestPuzzle(): number[][] {
  // 0 表示空格
  return [
    [0, 0, 3, 0, 2, 0, 6, 0, 0],
    [9, 0, 0, 3, 0, 5, 0, 0, 1],
    [0, 0, 1, 8, 0, 6, 4, 0, 0],
    [0, 0, 8, 1, 0, 2, 9, 0, 0],
    [7, 0, 0, 0, 0, 0, 0, 0, 8],
    [0, 0, 6, 7, 0, 8, 2, 0, 0],
    [0, 0, 2, 6, 0, 9, 5, 0, 0],
    [8, 0, 0, 2, 0, 3, 0, 0, 9],
    [0, 0, 5, 0, 1, 0, 3, 0, 0],
  ]
}

// 已知答案
function getTestSolution(): number[][] {
  return [
    [4, 8, 3, 9, 2, 1, 6, 5, 7],
    [9, 6, 7, 3, 4, 5, 8, 2, 1],
    [2, 5, 1, 8, 7, 6, 4, 9, 3],
    [5, 4, 8, 1, 3, 2, 9, 7, 6],
    [7, 2, 9, 5, 6, 4, 1, 3, 8],
    [1, 3, 6, 7, 9, 8, 2, 4, 5],
    [3, 7, 2, 6, 8, 9, 5, 1, 4],
    [8, 1, 4, 2, 5, 3, 7, 6, 9],
    [6, 9, 5, 4, 1, 7, 3, 8, 2],
  ]
}

export default function solverTest() {
  describe('SudokuSolver.solve', () => {
    it('solves_standard_puzzle_correctly', 0, () => {
      const puzzle = getTestPuzzle()
      const expected = getTestSolution()
      const result = solve(puzzle)

      expect(result !== null).assertTrue()
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          expect(result![r][c]).assertEqual(expected[r][c])
        }
      }
    })

    it('solution_preserves_givens', 0, () => {
      const puzzle = getTestPuzzle()
      const result = solve(puzzle)
      expect(result !== null).assertTrue()

      // 原题非 0 的位置在解中应一样
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          if (puzzle[r][c] !== 0) {
            expect(result![r][c]).assertEqual(puzzle[r][c])
          }
        }
      }
    })

    it('each_row_contains_1_to_9', 0, () => {
      const result = solve(getTestPuzzle())
      expect(result !== null).assertTrue()

      for (let r = 0; r < 9; r++) {
        const sorted = result![r].slice().sort()
        for (let i = 0; i < 9; i++) {
          expect(sorted[i]).assertEqual(i + 1)
        }
      }
    })

    it('each_col_contains_1_to_9', 0, () => {
      const result = solve(getTestPuzzle())
      expect(result !== null).assertTrue()

      for (let c = 0; c < 9; c++) {
        const col: number[] = []
        for (let r = 0; r < 9; r++) {
          col.push(result![r][c])
        }
        const sorted = col.sort()
        for (let i = 0; i < 9; i++) {
          expect(sorted[i]).assertEqual(i + 1)
        }
      }
    })

    it('each_box_contains_1_to_9', 0, () => {
      const result = solve(getTestPuzzle())
      expect(result !== null).assertTrue()

      for (let br = 0; br < 9; br += 3) {
        for (let bc = 0; bc < 9; bc += 3) {
          const box: number[] = []
          for (let r = br; r < br + 3; r++) {
            for (let c = bc; c < bc + 3; c++) {
              box.push(result![r][c])
            }
          }
          const sorted = box.sort()
          for (let i = 0; i < 9; i++) {
            expect(sorted[i]).assertEqual(i + 1)
          }
        }
      }
    })

    it('contradiction_returns_null', 0, () => {
      // 第一行放两个 5 → 矛盾
      const board = createEmptyGrid()
      board[0][0] = 5
      board[0][1] = 5
      expect(solve(board)).assertNull()
    })

    it('empty_board_can_be_solved', 0, () => {
      const board = createEmptyGrid()
      const result = solve(board)
      expect(result !== null).assertTrue()
      // 验证每行 1-9
      for (let r = 0; r < 9; r++) {
        const sorted = result![r].slice().sort()
        for (let i = 0; i < 9; i++) {
          expect(sorted[i]).assertEqual(i + 1)
        }
      }
    })
  })

  describe('SudokuSolver.countSolutions', () => {
    it('unique_solution_returns_1', 0, () => {
      expect(countSolutions(getTestPuzzle(), 2)).assertEqual(1)
    })

    it('contradiction_returns_0', 0, () => {
      const board = createEmptyGrid()
      board[0][0] = 5
      board[0][1] = 5
      expect(countSolutions(board, 2)).assertEqual(0)
    })

    it('empty_board_multiple_solutions', 0, () => {
      const board = createEmptyGrid()
      expect(countSolutions(board, 2)).assertEqual(2) // 最多数到 2
    })

    it('almost_complete_board_1_hole_still_unique', 0, () => {
      const solution = getTestSolution()
      solution[0][0] = 0 // 只挖一个洞
      expect(countSolutions(solution, 2)).assertEqual(1)
    })
  })

  describe('SudokuSolver.hasSolution.hasUniqueSolution', () => {
    it('hasSolution_true_for_valid_puzzle', 0, () => {
      expect(hasSolution(getTestPuzzle())).assertTrue()
    })

    it('hasSolution_false_for_contradiction', 0, () => {
      const board = createEmptyGrid()
      board[0][0] = 5
      board[0][1] = 5
      expect(hasSolution(board)).assertFalse()
    })

    it('hasUniqueSolution_true_for_standard_puzzle', 0, () => {
      expect(hasUniqueSolution(getTestPuzzle())).assertTrue()
    })

    it('hasUniqueSolution_false_for_empty_board', 0, () => {
      expect(hasUniqueSolution(createEmptyGrid())).assertFalse()
    })
  })
}
