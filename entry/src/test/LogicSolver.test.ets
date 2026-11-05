import { describe, it, expect } from '@ohos/hypium'
import { logicSolve, getNextHint, Technique, getTechniqueNameKey, setActiveCages, clearActiveCages } from '../main/ets/utils/LogicSolver'
import { evaluateDifficulty } from '../main/ets/utils/DifficultyEvaluator'
import { generatePuzzle } from '../main/ets/utils/SudokuGenerator'
import { Difficulty } from '../main/ets/constants/GameConstants'
import { cloneGrid, createEmptyGrid } from '../main/ets/utils/Common'
import { createDefaultJigsawConfig, createStandardConfig, createKillerConfig, KillerCage } from '../main/ets/models/VariantConfig'
import { applyTopology } from '../main/ets/utils/Topology'

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
  describe('LogicSolver.VariantConstraints', () => {
    it('jigsaw_logic_never_eliminates_the_unique_solution', 0, () => {
      const puzzle = '790510000000760500000007004050400010034006751000200970009000480000004005400001006'
      const solution = '796513842142769538325897164657482319834926751561248973219635487983174625478351296'
      const board: number[][] = []
      for (let row = 0; row < 9; row++) {
        board.push(puzzle.slice(row * 9, row * 9 + 9).split('').map(value => Number.parseInt(value)))
      }
      applyTopology(createDefaultJigsawConfig())
      try {
        const result = logicSolve(board)
        expect(result.steps.length > 0).assertTrue()
        for (const step of result.steps) {
          if (step.digit > 0) {
            expect(step.digit).assertEqual(Number.parseInt(solution.charAt(step.cellIndex)))
          }
          for (const elimination of step.eliminations) {
            expect(elimination.digit !== Number.parseInt(solution.charAt(elimination.cellIndex))).assertTrue()
          }
        }
      } finally {
        applyTopology(createStandardConfig())
      }
    })

    it('single_cell_killer_cage_uses_its_sum_not_a_hidden_single', 0, () => {
      const cages: KillerCage[] = [{ cells: [0], sum: 5 }]
      applyTopology(createKillerConfig(cages))
      setActiveCages(cages)
      try {
        const hint = getNextHint(createEmptyGrid())
        expect(hint !== null).assertTrue()
        expect(hint!.technique).assertEqual(Technique.CAGE_SUM)
        expect(hint!.cellIndex).assertEqual(0)
        expect(hint!.digit).assertEqual(5)
      } finally {
        clearActiveCages()
        applyTopology(createStandardConfig())
      }
    })
  })

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
        expect(step.descriptionKey.length > 0).assertTrue()
        expect(step.descriptionKey.startsWith('step_')).assertTrue()
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

    it('hint_has_descriptionKey_and_params', 0, () => {
      const board = getEasyPuzzle()
      const hint = getNextHint(board)
      expect(hint !== null).assertTrue()
      expect(hint!.descriptionKey.length > 0).assertTrue()
      expect(hint!.descriptionKey.startsWith('step_')).assertTrue()
      expect(hint!.descriptionParams.length > 0).assertTrue()
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
