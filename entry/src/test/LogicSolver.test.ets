import { describe, it, expect } from '@ohos/hypium'
import { logicSolve, getNextHint, Technique, getTechniqueNameKey } from '../main/ets/utils/LogicSolver'
import { evaluateDifficulty } from '../main/ets/utils/DifficultyEvaluator'
import { generatePuzzle } from '../main/ets/utils/SudokuGenerator'
import { Difficulty } from '../main/ets/constants/GameConstants'
import { cloneGrid } from '../main/ets/utils/Common'

// 一道已知只需 Naked Single 的简单题
function getEasyPuzzle(): number[][] {
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

export default function logicSolverTest() {
  describe('LogicSolver.logicSolve', () => {
    it('solves_easy_puzzle_completely', 0, () => {
      const board = getEasyPuzzle()
      const result = logicSolve(board)
      expect(result.solved).assertTrue()
      expect(result.steps.length > 0).assertTrue()
    })

    it('records_steps_with_techniques', 0, () => {
      const board = getEasyPuzzle()
      const result = logicSolve(board)
      for (const step of result.steps) {
        expect(step.technique.length > 0).assertTrue()
        expect(step.description.length > 0).assertTrue()
      }
    })

    it('total_score_is_positive', 0, () => {
      const board = getEasyPuzzle()
      const result = logicSolve(board)
      expect(result.totalScore > 0).assertTrue()
    })

    it('max_technique_is_not_null_when_solved', 0, () => {
      const board = getEasyPuzzle()
      const result = logicSolve(board)
      expect(result.maxTechnique !== null).assertTrue()
    })

    it('solved_board_is_fully_filled', 0, () => {
      const board = getEasyPuzzle()
      const result = logicSolve(board)
      if (result.solved) {
        for (let r = 0; r < 9; r++) {
          for (let c = 0; c < 9; c++) {
            expect(board[r][c] >= 1 && board[r][c] <= 9).assertTrue()
          }
        }
      }
    })

    it('solved_board_rows_valid', 0, () => {
      const board = getEasyPuzzle()
      const result = logicSolve(board)
      if (result.solved) {
        for (let r = 0; r < 9; r++) {
          const sorted = board[r].slice().sort()
          for (let i = 0; i < 9; i++) {
            expect(sorted[i]).assertEqual(i + 1)
          }
        }
      }
    })
  })

  describe('LogicSolver.getNextHint', () => {
    it('returns_a_hint_for_unsolved_puzzle', 0, () => {
      const board = getEasyPuzzle()
      const hint = getNextHint(board)
      expect(hint !== null).assertTrue()
    })

    it('hint_has_technique_and_description', 0, () => {
      const board = getEasyPuzzle()
      const hint = getNextHint(board)
      expect(hint !== null).assertTrue()
      expect(hint!.technique.length > 0).assertTrue()
      expect(hint!.description.length > 0).assertTrue()
    })
  })

  describe('LogicSolver.getTechniqueNameKey', () => {
    it('returns_resource_key_for_naked_single', 0, () => {
      const key = getTechniqueNameKey(Technique.NAKED_SINGLE)
      expect(key).assertEqual('technique_naked_single')
    })

    it('returns_resource_key_for_x_wing', 0, () => {
      const key = getTechniqueNameKey(Technique.X_WING)
      expect(key).assertEqual('technique_x_wing')
    })
  })

  describe('DifficultyEvaluator', () => {
    it('evaluates_easy_puzzle', 0, () => {
      const board = getEasyPuzzle()
      const grade = evaluateDifficulty(board)
      expect(grade.solvableByLogic).assertTrue()
      expect(grade.stepCount > 0).assertTrue()
      // 这道经典题应该是简单或中等
      expect(grade.difficulty <= Difficulty.HARD).assertTrue()
    })

    it('evaluates_generated_easy_puzzle', 0, () => {
      const result = generatePuzzle(Difficulty.EASY)
      const grade = evaluateDifficulty(result.puzzle)
      expect(grade.solvableByLogic).assertTrue()
    })

    it('generated_puzzle_has_metadata', 0, () => {
      const result = generatePuzzle(Difficulty.MEDIUM)
      expect(result.symmetry.length > 0).assertTrue()
      expect(result.actualDifficulty >= Difficulty.EASY).assertTrue()
      expect(result.actualDifficulty <= Difficulty.EVIL).assertTrue()
    })
  })
}
