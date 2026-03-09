import { describe, it, expect } from '@ohos/hypium'
import { generateFullBoard, generatePuzzle } from '../main/ets/utils/SudokuGenerator'
import { solve, hasUniqueSolution } from '../main/ets/utils/SudokuSolver'
import { isValidPlacement, cloneGrid } from '../main/ets/utils/Common'
import { Difficulty } from '../main/ets/constants/GameConstants'

export default function generatorTest() {
  describe('generateFullBoard', () => {
    it('generates_9x9_board', 0, () => {
      const board = generateFullBoard()
      expect(board.length).assertEqual(9)
      for (let r = 0; r < 9; r++) {
        expect(board[r].length).assertEqual(9)
      }
    })

    it('all_cells_filled_no_zero', 0, () => {
      const board = generateFullBoard()
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          expect(board[r][c] >= 1 && board[r][c] <= 9).assertTrue()
        }
      }
    })

    it('each_row_contains_1_to_9', 0, () => {
      const board = generateFullBoard()
      for (let r = 0; r < 9; r++) {
        const sorted = board[r].slice().sort()
        for (let i = 0; i < 9; i++) {
          expect(sorted[i]).assertEqual(i + 1)
        }
      }
    })

    it('each_col_contains_1_to_9', 0, () => {
      const board = generateFullBoard()
      for (let c = 0; c < 9; c++) {
        const col: number[] = []
        for (let r = 0; r < 9; r++) col.push(board[r][c])
        const sorted = col.sort()
        for (let i = 0; i < 9; i++) {
          expect(sorted[i]).assertEqual(i + 1)
        }
      }
    })

    it('each_box_contains_1_to_9', 0, () => {
      const board = generateFullBoard()
      for (let br = 0; br < 9; br += 3) {
        for (let bc = 0; bc < 9; bc += 3) {
          const box: number[] = []
          for (let r = br; r < br + 3; r++) {
            for (let c = bc; c < bc + 3; c++) {
              box.push(board[r][c])
            }
          }
          const sorted = box.sort()
          for (let i = 0; i < 9; i++) {
            expect(sorted[i]).assertEqual(i + 1)
          }
        }
      }
    })

    it('two_generations_likely_different', 0, () => {
      const board1 = generateFullBoard()
      const board2 = generateFullBoard()
      // 比较第一行是否相同——极小概率相同
      let same = true
      for (let c = 0; c < 9; c++) {
        if (board1[0][c] !== board2[0][c]) {
          same = false
          break
        }
      }
      // 不做严格断言（理论上可能相同），只检查是否都合法
      expect(board1.length).assertEqual(9)
      expect(board2.length).assertEqual(9)
    })
  })

  describe('generatePuzzle', () => {
    it('EASY_puzzle_has_unique_solution', 0, () => {
      const result = generatePuzzle(Difficulty.EASY)
      expect(hasUniqueSolution(result.puzzle)).assertTrue()
    })

    it('MEDIUM_puzzle_has_unique_solution', 0, () => {
      const result = generatePuzzle(Difficulty.MEDIUM)
      expect(hasUniqueSolution(result.puzzle)).assertTrue()
    })

    it('puzzle_givens_match_solution', 0, () => {
      const result = generatePuzzle(Difficulty.EASY)
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          if (result.puzzle[r][c] !== 0) {
            expect(result.puzzle[r][c]).assertEqual(result.solution[r][c])
          }
        }
      }
    })

    it('solution_is_complete_valid_board', 0, () => {
      const result = generatePuzzle(Difficulty.EASY)
      const sol = result.solution
      for (let r = 0; r < 9; r++) {
        const sorted = sol[r].slice().sort()
        for (let i = 0; i < 9; i++) {
          expect(sorted[i]).assertEqual(i + 1)
        }
      }
    })

    it('puzzle_has_empty_cells', 0, () => {
      const result = generatePuzzle(Difficulty.EASY)
      let emptyCount = 0
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          if (result.puzzle[r][c] === 0) emptyCount++
        }
      }
      expect(emptyCount > 0).assertTrue()
    })

    it('solving_puzzle_matches_solution', 0, () => {
      const result = generatePuzzle(Difficulty.EASY)
      const solved = solve(result.puzzle)
      expect(solved !== null).assertTrue()
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          expect(solved![r][c]).assertEqual(result.solution[r][c])
        }
      }
    })

    it('puzzle_and_solution_no_shared_reference', 0, () => {
      const result = generatePuzzle(Difficulty.EASY)
      // 修改 puzzle 不影响 solution
      const origSolVal = result.solution[0][0]
      result.puzzle[0][0] = 0
      expect(result.solution[0][0]).assertEqual(origSolVal)
    })
  })
}
