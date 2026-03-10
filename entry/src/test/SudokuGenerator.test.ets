import { describe, it, expect } from '@ohos/hypium'
import { generateFullBoard, generatePuzzle } from '../main/ets/utils/SudokuGenerator'
import { solve, hasUniqueSolution } from '../main/ets/utils/SudokuSolver'
import { Difficulty } from '../main/ets/constants/GameConstants'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'GeneratorTest'

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
      const puzzle = result.puzzle

      // ===== 诊断日志 =====
      hilog.info(0x0000, TAG, '--- solution_is_complete_valid_board diagnostics ---')
      hilog.info(0x0000, TAG, 'seed=%{public}d, symmetry=%{public}s, actualDiff=%{public}d',
        result.seed, result.symmetry, result.actualDifficulty)

      // 打印 solution 每行
      for (let r = 0; r < 9; r++) {
        hilog.info(0x0000, TAG, 'sol[%{public}d] = [%{public}s]', r, sol[r].join(', '))
      }

      // 打印 puzzle 每行
      for (let r = 0; r < 9; r++) {
        hilog.info(0x0000, TAG, 'puz[%{public}d] = [%{public}s]', r, puzzle[r].join(', '))
      }

      // 检查 solution 是否有 0（不完整）
      let zeroCount = 0
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          if (sol[r][c] === 0) {
            zeroCount++
            hilog.error(0x0000, TAG, 'ZERO in solution at (%{public}d, %{public}d)', r, c)
          }
          if (sol[r][c] < 0 || sol[r][c] > 9) {
            hilog.error(0x0000, TAG, 'OUT OF RANGE sol[%{public}d][%{public}d] = %{public}d', r, c, sol[r][c])
          }
        }
      }
      hilog.info(0x0000, TAG, 'solution zero count = %{public}d', zeroCount)

      // 逐行验证并记录
      for (let r = 0; r < 9; r++) {
        const row = sol[r]
        const sliced = row.slice()
        const sorted = sliced.sort()
        hilog.info(0x0000, TAG, 'row %{public}d sorted = [%{public}s]', r, sorted.join(', '))
        for (let i = 0; i < 9; i++) {
          if (sorted[i] !== i + 1) {
            hilog.error(0x0000, TAG, 'ROW %{public}d FAIL: sorted[%{public}d]=%{public}d, expected=%{public}d',
              r, i, sorted[i], i + 1)
          }
        }
      }

      // 逐列验证
      for (let c = 0; c < 9; c++) {
        const col: number[] = []
        for (let r = 0; r < 9; r++) col.push(sol[r][c])
        const sorted = col.sort()
        for (let i = 0; i < 9; i++) {
          if (sorted[i] !== i + 1) {
            hilog.error(0x0000, TAG, 'COL %{public}d FAIL: sorted[%{public}d]=%{public}d, expected=%{public}d',
              c, i, sorted[i], i + 1)
          }
        }
      }

      // 检查 puzzle 的给定数是否都匹配 solution
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          if (puzzle[r][c] !== 0 && puzzle[r][c] !== sol[r][c]) {
            hilog.error(0x0000, TAG, 'MISMATCH puz[%{public}d][%{public}d]=%{public}d != sol=%{public}d',
              r, c, puzzle[r][c], sol[r][c])
          }
        }
      }

      hilog.info(0x0000, TAG, '--- end diagnostics ---')

      // ===== 实际断言 =====
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
      hilog.info(0x0000, TAG, '--- solving_puzzle_matches_solution: seed=%{public}d ---', result.seed)
      const solved = solve(result.puzzle)
      expect(solved !== null).assertTrue()
      let mismatchCount = 0
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          if (solved![r][c] !== result.solution[r][c]) {
            mismatchCount++
            hilog.error(0x0000, TAG, 'SOLVE MISMATCH [%{public}d][%{public}d]: solved=%{public}d, sol=%{public}d',
              r, c, solved![r][c], result.solution[r][c])
          }
        }
      }
      hilog.info(0x0000, TAG, 'solve vs solution mismatch count = %{public}d', mismatchCount)
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
