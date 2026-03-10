import { describe, it, expect } from '@ohos/hypium'
import { CellData, CellFlags, setFlag } from '../main/ets/models/CellData'
import { createEmptyBoard, createBoardFromArray } from '../main/ets/models/CellData'
import {
  validateAllCells, isCorrectValue,
  isGameCompleted, isGameCompletedWithSolution,
  updateHighlights
} from '../main/ets/utils/SudokuValidator'
import { PEERS } from '../main/ets/utils/Topology'

// 构建一个有效的完整终盘（用于测试完成判定）
function getCompleteSolution(): number[][] {
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

export default function validatorTest() {
  describe('validateAllCells.ConflictDetection', () => {
    it('empty_board_no_conflict', 0, () => {
      const cells = createEmptyBoard()
      const count = validateAllCells(cells)
      expect(count).assertEqual(0)
      for (let i = 0; i < 81; i++) {
        expect(cells[i].isError).assertFalse()
      }
    })

    it('partial_board_no_conflict', 0, () => {
      const cells = createEmptyBoard()
      cells[0].value = 1 // (0,0)=1
      cells[1].value = 2 // (0,1)=2
      cells[9].value = 3 // (1,0)=3
      const count = validateAllCells(cells)
      expect(count).assertEqual(0)
    })

    it('same_row_conflict_marks_both_cells', 0, () => {
      const cells = createEmptyBoard()
      cells[0].value = 5  // (0,0)
      cells[3].value = 5  // (0,3) — 同行
      const count = validateAllCells(cells)
      expect(count).assertEqual(2) // 两个冲突格
      expect(cells[0].isError).assertTrue()
      expect(cells[3].isError).assertTrue()
    })

    it('same_col_conflict', 0, () => {
      const cells = createEmptyBoard()
      cells[0].value = 7  // (0,0)
      cells[36].value = 7 // (4,0) — 同列
      const count = validateAllCells(cells)
      expect(count).assertEqual(2)
      expect(cells[0].isError).assertTrue()
      expect(cells[36].isError).assertTrue()
    })

    it('same_box_conflict', 0, () => {
      const cells = createEmptyBoard()
      cells[0].value = 3   // (0,0)
      cells[10].value = 3  // (1,1) — 同宫
      const count = validateAllCells(cells)
      expect(count).assertEqual(2)
    })

    it('fixing_conflict_clears_ERROR', 0, () => {
      const cells = createEmptyBoard()
      cells[0].value = 5
      cells[1].value = 5
      validateAllCells(cells) // 标记冲突
      expect(cells[0].isError).assertTrue()

      cells[1].value = 0 // 修复
      validateAllCells(cells)
      expect(cells[0].isError).assertFalse()
      expect(cells[1].isError).assertFalse()
    })

    it('complete_correct_board_no_conflict', 0, () => {
      const cells = createBoardFromArray(getCompleteSolution())
      const count = validateAllCells(cells)
      expect(count).assertEqual(0)
    })
  })

  describe('validateAllCells.SolutionMismatch', () => {
    it('wrong_value_without_peer_conflict_flagged_with_solution', 0, () => {
      // Fill a cell with a value that doesn't match the solution but causes no peer conflict
      const sol = getCompleteSolution()
      const flat: number[] = []
      for (const row of sol) {
        for (const v of row) flat.push(v)
      }
      const cells = createEmptyBoard()
      // Fill the correct values everywhere except index 0 (mark them GIVEN)
      for (let i = 1; i < 81; i++) {
        cells[i].value = flat[i]
        cells[i].flags = setFlag(cells[i].flags, CellFlags.GIVEN)
      }
      // Fill index 0 with a wrong value that has no peer with the same number
      // (all peer cells are GIVEN and have different values)
      const wrongVal = flat[0] === 9 ? 1 : 9 // pick a value != correct answer
      cells[0].value = wrongVal

      const count = validateAllCells(cells, flat)
      expect(cells[0].isError).assertTrue()
      expect(count).assertLargerOrEqual(1)
    })

    it('wrong_value_without_solution_not_flagged', 0, () => {
      // Without solution, only peer-conflict detection applies
      const sol = getCompleteSolution()
      const flat: number[] = []
      for (const row of sol) {
        for (const v of row) flat.push(v)
      }
      const cells = createEmptyBoard()
      for (let i = 1; i < 81; i++) {
        cells[i].value = flat[i]
        cells[i].flags = setFlag(cells[i].flags, CellFlags.GIVEN)
      }
      const wrongVal = flat[0] === 9 ? 1 : 9
      cells[0].value = wrongVal

      // No solution provided — only peer conflicts matter
      const count = validateAllCells(cells)
      // wrongVal doesn't appear in any peer → no error flagged
      expect(cells[0].isError).assertFalse()
      expect(count).assertEqual(0)
    })

    it('correct_value_with_solution_not_flagged', 0, () => {
      const sol = getCompleteSolution()
      const flat: number[] = []
      for (const row of sol) {
        for (const v of row) flat.push(v)
      }
      const cells = createEmptyBoard()
      cells[0].value = flat[0] // correct value
      const count = validateAllCells(cells, flat)
      expect(cells[0].isError).assertFalse()
      expect(count).assertEqual(0)
    })

    it('given_cell_not_flagged_by_solution_check', 0, () => {
      // GIVEN cells are never flagged by solution mismatch (they define the puzzle)
      const flat: number[] = []
      for (let i = 0; i < 81; i++) flat.push(1)
      const cells = createEmptyBoard()
      cells[0].value = 5
      cells[0].flags = setFlag(cells[0].flags, CellFlags.GIVEN) // mark as given
      const count = validateAllCells(cells, flat)
      expect(cells[0].isError).assertFalse()
      expect(count).assertEqual(0)
    })
  })

  describe('isCorrectValue', () => {
    it('correct_value_returns_true', 0, () => {
      const cells = createEmptyBoard()
      cells[0].value = 4
      const solution = [4, 8, 3, 9, 2, 1, 6, 5, 7] // 只要第一个对
      // 填充剩余避免越界
      for (let i = 1; i < 81; i++) solution.push(0)
      expect(isCorrectValue(cells, 0, solution)).assertTrue()
    })

    it('wrong_value_returns_false', 0, () => {
      const cells = createEmptyBoard()
      cells[0].value = 9 // 应该是 4
      const solution: number[] = []
      for (let i = 0; i < 81; i++) solution.push(i === 0 ? 4 : 0)
      expect(isCorrectValue(cells, 0, solution)).assertFalse()
    })
  })

  describe('isGameCompleted', () => {
    it('empty_board_not_completed', 0, () => {
      expect(isGameCompleted(createEmptyBoard())).assertFalse()
    })

    it('correct_complete_board_completed', 0, () => {
      const cells = createBoardFromArray(getCompleteSolution())
      expect(isGameCompleted(cells)).assertTrue()
    })

    it('has_empty_cells_not_completed', 0, () => {
      const sol = getCompleteSolution()
      sol[4][4] = 0
      const cells = createBoardFromArray(sol)
      expect(isGameCompleted(cells)).assertFalse()
    })

    it('full_but_conflicting_not_completed', 0, () => {
      const sol = getCompleteSolution()
      // 交换同行两个数 → 行正确但列/宫冲突
      const tmp = sol[0][0]
      sol[0][0] = sol[0][1]
      sol[0][1] = tmp
      const cells = createBoardFromArray(sol)
      expect(isGameCompleted(cells)).assertFalse()
    })
  })

  describe('isGameCompletedWithSolution', () => {
    it('matches_solution_returns_true', 0, () => {
      const sol = getCompleteSolution()
      const cells = createBoardFromArray(sol)
      const flat: number[] = []
      for (const row of sol) {
        for (const v of row) flat.push(v)
      }
      expect(isGameCompletedWithSolution(cells, flat)).assertTrue()
    })

    it('one_cell_differs_returns_false', 0, () => {
      const sol = getCompleteSolution()
      const cells = createBoardFromArray(sol)
      cells[0].value = 0 // 清掉一格
      const flat: number[] = []
      for (const row of sol) {
        for (const v of row) flat.push(v)
      }
      expect(isGameCompletedWithSolution(cells, flat)).assertFalse()
    })
  })

  describe('updateHighlights', () => {
    it('no_selection_no_highlight', 0, () => {
      const cells = createEmptyBoard()
      updateHighlights(cells, -1)
      for (let i = 0; i < 81; i++) {
        expect(cells[i].isSelected).assertFalse()
        expect(cells[i].isHighlighted).assertFalse()
      }
    })

    it('selected_cell_marked_SELECTED', 0, () => {
      const cells = createEmptyBoard()
      updateHighlights(cells, 40)
      expect(cells[40].isSelected).assertTrue()
    })

    it('peers_marked_HIGHLIGHTED', 0, () => {
      const cells = createEmptyBoard()
      updateHighlights(cells, 0)
      for (const peer of PEERS[0]) {
        expect(cells[peer].isHighlighted).assertTrue()
      }
    })

    it('non_peer_non_selected_no_mark', 0, () => {
      const cells = createEmptyBoard()
      updateHighlights(cells, 0)
      // index=80 (8,8) 不是 (0,0) 的 peer（不同行不同列不同宫）
      expect(cells[80].isSelected).assertFalse()
      expect(cells[80].isHighlighted).assertFalse()
    })

    it('same_digit_highlighted', 0, () => {
      const cells = createEmptyBoard()
      cells[0].value = 5    // (0,0)=5
      cells[40].value = 5   // (4,4)=5 — 不同行列宫
      updateHighlights(cells, 0)
      expect(cells[40].isHighlighted).assertTrue()
    })

    it('switching_selection_clears_old', 0, () => {
      const cells = createEmptyBoard()
      updateHighlights(cells, 0)
      expect(cells[0].isSelected).assertTrue()

      updateHighlights(cells, 40)
      expect(cells[0].isSelected).assertFalse()
      expect(cells[40].isSelected).assertTrue()
    })
  })
}
