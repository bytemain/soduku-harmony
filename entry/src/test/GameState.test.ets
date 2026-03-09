import { describe, it, expect } from '@ohos/hypium'
import { GameState } from '../main/ets/models/GameState'
import { CellData, CellFlags, setFlag } from '../main/ets/models/CellData'
import { Difficulty } from '../main/ets/constants/GameConstants'

function getTestPuzzle(): number[][] {
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

export default function gameStateTest() {
  describe('GameState.ConstructionAndInit', () => {
    it('default_constructor_values_correct', 0, () => {
      const gs = new GameState()
      expect(gs.cells.length).assertEqual(81)
      expect(gs.solution.length).assertEqual(0)
      expect(gs.selectedIndex).assertEqual(-1)
      expect(gs.difficulty).assertEqual(Difficulty.EASY)
      expect(gs.elapsedSeconds).assertEqual(0)
      expect(gs.errorCount).assertEqual(0)
      expect(gs.isCompleted).assertFalse()
      expect(gs.isPaused).assertFalse()
    })

    it('initGame_initializes_correctly', 0, () => {
      const gs = new GameState()
      gs.initGame(getTestPuzzle(), getTestSolution(), Difficulty.HARD)

      expect(gs.difficulty).assertEqual(Difficulty.HARD)
      expect(gs.cells.length).assertEqual(81)
      expect(gs.solution.length).assertEqual(81)
      expect(gs.selectedIndex).assertEqual(-1)
      expect(gs.elapsedSeconds).assertEqual(0)
      expect(gs.errorCount).assertEqual(0)

      // 检查 solution 转一维
      expect(gs.solution[0]).assertEqual(4)  // (0,0)
      expect(gs.solution[80]).assertEqual(2) // (8,8)

      // 检查 GIVEN 标记
      expect(gs.cells[2].value).assertEqual(3)   // puzzle[0][2]=3
      expect(gs.cells[2].isGiven).assertTrue()

      expect(gs.cells[0].value).assertEqual(0)   // puzzle[0][0]=0
      expect(gs.cells[0].isGiven).assertFalse()
    })
  })

  describe('GameState.SelectedCell', () => {
    it('selectedCell_returns_null_when_none', 0, () => {
      const gs = new GameState()
      expect(gs.selectedCell).assertNull()
    })

    it('selectCell_selects', 0, () => {
      const gs = new GameState()
      gs.selectCell(40)
      expect(gs.selectedIndex).assertEqual(40)
      expect(gs.selectedCell !== null).assertTrue()
      expect(gs.selectedCell!.index).assertEqual(40)
    })

    it('selectCell_same_cell_toggles_off', 0, () => {
      const gs = new GameState()
      gs.selectCell(40)
      expect(gs.selectedIndex).assertEqual(40)
      gs.selectCell(40)
      expect(gs.selectedIndex).assertEqual(-1)
      expect(gs.selectedCell).assertNull()
    })

    it('selectCell_switches_to_different_cell', 0, () => {
      const gs = new GameState()
      gs.selectCell(10)
      expect(gs.selectedIndex).assertEqual(10)
      gs.selectCell(20)
      expect(gs.selectedIndex).assertEqual(20)
    })

    it('clearSelection_clears_selection', 0, () => {
      const gs = new GameState()
      gs.selectCell(10)
      gs.clearSelection()
      expect(gs.selectedIndex).assertEqual(-1)
    })

    it('selectedCell_out_of_bounds_returns_null', 0, () => {
      const gs = new GameState()
      gs.selectedIndex = 81
      expect(gs.selectedCell).assertNull()
      gs.selectedIndex = -2
      expect(gs.selectedCell).assertNull()
    })
  })

  describe('GameState.Timer', () => {
    it('formattedTime_formats_correctly', 0, () => {
      const gs = new GameState()
      expect(gs.formattedTime).assertEqual('00:00')

      gs.elapsedSeconds = 5
      expect(gs.formattedTime).assertEqual('00:05')

      gs.elapsedSeconds = 65
      expect(gs.formattedTime).assertEqual('01:05')

      gs.elapsedSeconds = 600
      expect(gs.formattedTime).assertEqual('10:00')

      gs.elapsedSeconds = 3599
      expect(gs.formattedTime).assertEqual('59:59')
    })

    it('tick_normal_timing', 0, () => {
      const gs = new GameState()
      gs.tick()
      expect(gs.elapsedSeconds).assertEqual(1)
      gs.tick()
      expect(gs.elapsedSeconds).assertEqual(2)
    })

    it('tick_paused_no_timing', 0, () => {
      const gs = new GameState()
      gs.isPaused = true
      gs.tick()
      expect(gs.elapsedSeconds).assertEqual(0)
    })

    it('tick_completed_no_timing', 0, () => {
      const gs = new GameState()
      gs.isCompleted = true
      gs.tick()
      expect(gs.elapsedSeconds).assertEqual(0)
    })
  })

  describe('GameState.HelperMethods', () => {
    it('countDigit_counts_digit_occurrences', 0, () => {
      const gs = new GameState()
      gs.initGame(getTestPuzzle(), getTestSolution(), Difficulty.EASY)

      // puzzle 中数字 3 出现了几次？数一下：
      // (0,2)=3, (1,3)=3 → 至少 2 次
      const count3 = gs.countDigit(3)
      expect(count3 >= 2).assertTrue()
    })

    it('isDigitComplete_when_digit_reaches_9', 0, () => {
      const gs = new GameState()
      // 手动填满 9 个 5
      for (let i = 0; i < 9; i++) {
        gs.cells[i].value = 5
      }
      expect(gs.isDigitComplete(5)).assertTrue()
      expect(gs.isDigitComplete(1)).assertFalse()
    })
  })

  describe('GameState.resetGame', () => {
    it('resetGame_preserves_GIVEN_clears_user_input', 0, () => {
      const gs = new GameState()
      gs.initGame(getTestPuzzle(), getTestSolution(), Difficulty.EASY)

      // 模拟用户填写
      gs.cells[0].value = 4 // (0,0) 是空格
      gs.elapsedSeconds = 100
      gs.errorCount = 2
      gs.selectedIndex = 10

      gs.resetGame()

      // GIVEN 格保留
      expect(gs.cells[2].value).assertEqual(3)
      expect(gs.cells[2].isGiven).assertTrue()

      // 用户填写被清除
      expect(gs.cells[0].value).assertEqual(0)

      // 状态重置
      expect(gs.elapsedSeconds).assertEqual(0)
      expect(gs.errorCount).assertEqual(0)
      expect(gs.selectedIndex).assertEqual(-1)
      expect(gs.isCompleted).assertFalse()
    })
  })
}
