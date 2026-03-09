import { describe, it, expect } from '@ohos/hypium'
import {
  shuffle, createEmptyGrid, cloneGrid, flatToGrid, gridToFlat,
  isValidPlacement, digits1to9, getAllFilledPositions, findFirstEmpty
} from '../main/ets/utils/Common'

export default function commonTest() {
  describe('shuffle', () => {
    it('shuffle_length_unchanged', 0, () => {
      const arr = [1, 2, 3, 4, 5, 6, 7, 8, 9]
      shuffle(arr)
      expect(arr.length).assertEqual(9)
    })

    it('shuffle_preserves_elements', 0, () => {
      const arr = [1, 2, 3, 4, 5, 6, 7, 8, 9]
      shuffle(arr)
      const sorted = arr.slice().sort()
      for (let i = 0; i < 9; i++) {
        expect(sorted[i]).assertEqual(i + 1)
      }
    })

    it('returns_same_array_reference', 0, () => {
      const arr = [1, 2, 3]
      const result = shuffle(arr)
      // 引用相同（===），但 hypium 没有 assertStrictEqual，用 value check
      // 修改 result 也会影响 arr
      result[0] = 999
      expect(arr[0]).assertEqual(999)
    })

    it('empty_array_no_error', 0, () => {
      const arr: number[] = []
      shuffle(arr)
      expect(arr.length).assertEqual(0)
    })

    it('single_element_array_no_error', 0, () => {
      const arr = [42]
      shuffle(arr)
      expect(arr[0]).assertEqual(42)
    })
  })

  describe('createEmptyGrid', () => {
    it('creates_9x9_all_zero_grid', 0, () => {
      const grid = createEmptyGrid()
      expect(grid.length).assertEqual(9)
      for (let r = 0; r < 9; r++) {
        expect(grid[r].length).assertEqual(9)
        for (let c = 0; c < 9; c++) {
          expect(grid[r][c]).assertEqual(0)
        }
      }
    })
  })

  describe('cloneGrid', () => {
    it('deep_copy_same_content', 0, () => {
      const grid = createEmptyGrid()
      grid[0][0] = 5
      grid[4][4] = 9
      const copy = cloneGrid(grid)
      expect(copy[0][0]).assertEqual(5)
      expect(copy[4][4]).assertEqual(9)
    })

    it('modify_copy_does_not_affect_original', 0, () => {
      const grid = createEmptyGrid()
      grid[0][0] = 5
      const copy = cloneGrid(grid)
      copy[0][0] = 7
      expect(grid[0][0]).assertEqual(5) // 原棋盘不变
    })
  })

  describe('flatToGrid.gridToFlat', () => {
    it('roundtrip_conversion_consistent', 0, () => {
      const flat: number[] = []
      for (let i = 0; i < 81; i++) {
        flat.push(i)
      }
      const grid = flatToGrid(flat)
      expect(grid.length).assertEqual(9)
      expect(grid[0][0]).assertEqual(0)
      expect(grid[0][8]).assertEqual(8)
      expect(grid[1][0]).assertEqual(9)
      expect(grid[8][8]).assertEqual(80)

      const backToFlat = gridToFlat(grid)
      expect(backToFlat.length).assertEqual(81)
      for (let i = 0; i < 81; i++) {
        expect(backToFlat[i]).assertEqual(i)
      }
    })
  })

  describe('isValidPlacement', () => {
    it('empty_board_any_digit_valid', 0, () => {
      const board = createEmptyGrid()
      expect(isValidPlacement(board, 0, 0, 5)).assertTrue()
      expect(isValidPlacement(board, 8, 8, 9)).assertTrue()
    })

    it('same_row_duplicate_invalid', 0, () => {
      const board = createEmptyGrid()
      board[0][0] = 5
      expect(isValidPlacement(board, 0, 5, 5)).assertFalse() // 同行
    })

    it('same_col_duplicate_invalid', 0, () => {
      const board = createEmptyGrid()
      board[0][0] = 5
      expect(isValidPlacement(board, 5, 0, 5)).assertFalse() // 同列
    })

    it('same_box_duplicate_invalid', 0, () => {
      const board = createEmptyGrid()
      board[0][0] = 5
      expect(isValidPlacement(board, 1, 1, 5)).assertFalse() // 同宫
      expect(isValidPlacement(board, 2, 2, 5)).assertFalse() // 同宫
    })

    it('different_row_col_box_valid', 0, () => {
      const board = createEmptyGrid()
      board[0][0] = 5
      expect(isValidPlacement(board, 3, 3, 5)).assertTrue() // 不同宫
      expect(isValidPlacement(board, 5, 5, 5)).assertTrue()
    })
  })

  describe('digits1to9', () => {
    it('returns_1_to_9', 0, () => {
      const d = digits1to9()
      expect(d.length).assertEqual(9)
      for (let i = 0; i < 9; i++) {
        expect(d[i]).assertEqual(i + 1)
      }
    })
  })

  describe('getAllFilledPositions', () => {
    it('empty_board_returns_empty_array', 0, () => {
      const board = createEmptyGrid()
      expect(getAllFilledPositions(board).length).assertEqual(0)
    })

    it('returns_nonzero_positions', 0, () => {
      const board = createEmptyGrid()
      board[1][2] = 3
      board[7][8] = 6
      const positions = getAllFilledPositions(board)
      expect(positions.length).assertEqual(2)
      // 位置 [1,2]
      expect(positions[0][0]).assertEqual(1)
      expect(positions[0][1]).assertEqual(2)
      // 位置 [7,8]
      expect(positions[1][0]).assertEqual(7)
      expect(positions[1][1]).assertEqual(8)
    })
  })

  describe('findFirstEmpty', () => {
    it('full_board_returns_null', 0, () => {
      const board: number[][] = []
      for (let r = 0; r < 9; r++) {
        const row: number[] = []
        for (let c = 0; c < 9; c++) {
          row.push(1) // 全填 1（不管合法性）
        }
        board.push(row)
      }
      expect(findFirstEmpty(board)).assertNull()
    })

    it('empty_board_returns_0_0', 0, () => {
      const board = createEmptyGrid()
      const pos = findFirstEmpty(board)
      expect(pos !== null).assertTrue()
      expect(pos![0]).assertEqual(0)
      expect(pos![1]).assertEqual(0)
    })

    it('finds_first_empty_cell', 0, () => {
      const board: number[][] = []
      for (let r = 0; r < 9; r++) {
        const row: number[] = []
        for (let c = 0; c < 9; c++) {
          row.push(1)
        }
        board.push(row)
      }
      board[3][5] = 0 // 第一个空格
      board[7][1] = 0
      const pos = findFirstEmpty(board)
      expect(pos !== null).assertTrue()
      expect(pos![0]).assertEqual(3)
      expect(pos![1]).assertEqual(5)
    })
  })
}
