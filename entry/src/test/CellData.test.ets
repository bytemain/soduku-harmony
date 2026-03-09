import { describe, it, expect } from '@ohos/hypium'
import {
  CellFlags, NoteState,
  getNoteState, setNoteState, hasAnyNote, clearAllNotes,
  hasFlag, setFlag, clearFlag,
  CellData, createEmptyBoard, createBoardFromArray
} from '../main/ets/models/CellData'

export default function cellDataTest() {
  describe('CellFlags.BitOperations', () => {
    it('each_flag_occupies_independent_bit', 0, () => {
      // 5 个标志互不重叠
      const all = CellFlags.GIVEN | CellFlags.ERROR | CellFlags.SELECTED |
        CellFlags.HIGHLIGHTED | CellFlags.LOCKED
      expect(all).assertEqual(0b11111) // 31
    })

    it('setFlag_sets_flag', 0, () => {
      let flags = 0
      flags = setFlag(flags, CellFlags.GIVEN)
      expect(hasFlag(flags, CellFlags.GIVEN)).assertTrue()
      expect(hasFlag(flags, CellFlags.ERROR)).assertFalse()
    })

    it('clearFlag_clears_flag', 0, () => {
      let flags = setFlag(0, CellFlags.GIVEN)
      flags = setFlag(flags, CellFlags.ERROR)
      flags = clearFlag(flags, CellFlags.GIVEN)
      expect(hasFlag(flags, CellFlags.GIVEN)).assertFalse()
      expect(hasFlag(flags, CellFlags.ERROR)).assertTrue()
    })

    it('setting_multiple_flags_independently', 0, () => {
      let flags = 0
      flags = setFlag(flags, CellFlags.GIVEN)
      flags = setFlag(flags, CellFlags.HIGHLIGHTED)
      flags = setFlag(flags, CellFlags.LOCKED)
      expect(hasFlag(flags, CellFlags.GIVEN)).assertTrue()
      expect(hasFlag(flags, CellFlags.ERROR)).assertFalse()
      expect(hasFlag(flags, CellFlags.SELECTED)).assertFalse()
      expect(hasFlag(flags, CellFlags.HIGHLIGHTED)).assertTrue()
      expect(hasFlag(flags, CellFlags.LOCKED)).assertTrue()
    })

    it('setting_same_flag_again_is_idempotent', 0, () => {
      let flags = setFlag(0, CellFlags.GIVEN)
      const before = flags
      flags = setFlag(flags, CellFlags.GIVEN)
      expect(flags).assertEqual(before)
    })

    it('clearing_absent_flag_is_noop', 0, () => {
      let flags = setFlag(0, CellFlags.GIVEN)
      const before = flags
      flags = clearFlag(flags, CellFlags.ERROR)
      expect(flags).assertEqual(before)
    })
  })

  describe('NoteState.TwoBitNotes', () => {
    it('initial_notes_all_EMPTY', 0, () => {
      for (let n = 1; n <= 9; n++) {
        expect(getNoteState(0, n)).assertEqual(NoteState.EMPTY)
      }
    })

    it('set_single_digit_note_to_ACTIVE', 0, () => {
      let notes = 0
      notes = setNoteState(notes, 3, NoteState.ACTIVE)
      expect(getNoteState(notes, 3)).assertEqual(NoteState.ACTIVE)
      // 其他数字不受影响
      expect(getNoteState(notes, 1)).assertEqual(NoteState.EMPTY)
      expect(getNoteState(notes, 9)).assertEqual(NoteState.EMPTY)
    })

    it('set_digit_note_to_ELIMINATED', 0, () => {
      let notes = 0
      notes = setNoteState(notes, 7, NoteState.ELIMINATED)
      expect(getNoteState(notes, 7)).assertEqual(NoteState.ELIMINATED)
    })

    it('multiple_digits_different_note_states', 0, () => {
      let notes = 0
      notes = setNoteState(notes, 1, NoteState.ACTIVE)
      notes = setNoteState(notes, 5, NoteState.ELIMINATED)
      notes = setNoteState(notes, 9, NoteState.ACTIVE)

      expect(getNoteState(notes, 1)).assertEqual(NoteState.ACTIVE)
      expect(getNoteState(notes, 2)).assertEqual(NoteState.EMPTY)
      expect(getNoteState(notes, 5)).assertEqual(NoteState.ELIMINATED)
      expect(getNoteState(notes, 9)).assertEqual(NoteState.ACTIVE)
    })

    it('overwrite_existing_note_state', 0, () => {
      let notes = setNoteState(0, 4, NoteState.ACTIVE)
      notes = setNoteState(notes, 4, NoteState.ELIMINATED)
      expect(getNoteState(notes, 4)).assertEqual(NoteState.ELIMINATED)
      notes = setNoteState(notes, 4, NoteState.EMPTY)
      expect(getNoteState(notes, 4)).assertEqual(NoteState.EMPTY)
    })

    it('hasAnyNote_detection', 0, () => {
      let notes = 0
      expect(hasAnyNote(notes, NoteState.ACTIVE)).assertFalse()

      notes = setNoteState(notes, 6, NoteState.ACTIVE)
      expect(hasAnyNote(notes, NoteState.ACTIVE)).assertTrue()
      expect(hasAnyNote(notes, NoteState.ELIMINATED)).assertFalse()
    })

    it('clearAllNotes_returns_0', 0, () => {
      expect(clearAllNotes()).assertEqual(0)
    })

    it('all_9_digits_set_to_ACTIVE', 0, () => {
      let notes = 0
      for (let n = 1; n <= 9; n++) {
        notes = setNoteState(notes, n, NoteState.ACTIVE)
      }
      for (let n = 1; n <= 9; n++) {
        expect(getNoteState(notes, n)).assertEqual(NoteState.ACTIVE)
      }
      // 确保 18 bit 没有溢出
      expect(notes).assertEqual(0b01_01_01_01_01_01_01_01_01) // 每个数字 2bit 都是 01
    })
  })

  describe('CellData.Class', () => {
    it('constructor_initializes_correctly', 0, () => {
      const cell = new CellData(2, 5)
      expect(cell.row).assertEqual(2)
      expect(cell.col).assertEqual(5)
      expect(cell.value).assertEqual(0)
      expect(cell.flags).assertEqual(0)
      expect(cell.notes).assertEqual(0)
    })

    it('box_computed_correctly', 0, () => {
      // (0,0) → 宫0, (0,3) → 宫1, (3,0) → 宫3, (8,8) → 宫8
      expect(new CellData(0, 0).box).assertEqual(0)
      expect(new CellData(0, 3).box).assertEqual(1)
      expect(new CellData(0, 6).box).assertEqual(2)
      expect(new CellData(3, 0).box).assertEqual(3)
      expect(new CellData(4, 4).box).assertEqual(4)
      expect(new CellData(3, 6).box).assertEqual(5)
      expect(new CellData(6, 0).box).assertEqual(6)
      expect(new CellData(7, 4).box).assertEqual(7)
      expect(new CellData(8, 8).box).assertEqual(8)
    })

    it('index_computed_correctly', 0, () => {
      expect(new CellData(0, 0).index).assertEqual(0)
      expect(new CellData(0, 8).index).assertEqual(8)
      expect(new CellData(1, 0).index).assertEqual(9)
      expect(new CellData(8, 8).index).assertEqual(80)
    })

    it('flag_convenience_properties', 0, () => {
      const cell = new CellData()
      expect(cell.isGiven).assertFalse()

      cell.flags = setFlag(cell.flags, CellFlags.GIVEN)
      expect(cell.isGiven).assertTrue()

      cell.flags = setFlag(cell.flags, CellFlags.ERROR)
      expect(cell.isError).assertTrue()

      cell.flags = setFlag(cell.flags, CellFlags.SELECTED)
      expect(cell.isSelected).assertTrue()

      cell.flags = setFlag(cell.flags, CellFlags.HIGHLIGHTED)
      expect(cell.isHighlighted).assertTrue()

      cell.flags = setFlag(cell.flags, CellFlags.LOCKED)
      expect(cell.isLocked).assertTrue()
    })

    it('isEditable_not_GIVEN_not_LOCKED', 0, () => {
      const cell = new CellData()
      expect(cell.isEditable).assertTrue()

      cell.flags = setFlag(cell.flags, CellFlags.GIVEN)
      expect(cell.isEditable).assertFalse()

      cell.flags = clearFlag(cell.flags, CellFlags.GIVEN)
      cell.flags = setFlag(cell.flags, CellFlags.LOCKED)
      expect(cell.isEditable).assertFalse()
    })

    it('isEmpty_detects_empty_cell', 0, () => {
      const cell = new CellData()
      expect(cell.isEmpty).assertTrue()
      cell.value = 5
      expect(cell.isEmpty).assertFalse()
    })

    it('fillValue_fills_and_clears_notes', 0, () => {
      const cell = new CellData()
      cell.notes = setNoteState(0, 3, NoteState.ACTIVE)
      cell.fillValue(7)
      expect(cell.value).assertEqual(7)
      expect(cell.notes).assertEqual(0)
    })

    it('clear_clears_value_notes_ERROR', 0, () => {
      const cell = new CellData()
      cell.value = 5
      cell.notes = setNoteState(0, 2, NoteState.ACTIVE)
      cell.flags = setFlag(cell.flags, CellFlags.ERROR)
      cell.flags = setFlag(cell.flags, CellFlags.HIGHLIGHTED) // 这个不应被清除

      cell.clear()
      expect(cell.value).assertEqual(0)
      expect(cell.notes).assertEqual(0)
      expect(cell.isError).assertFalse()
      expect(cell.isHighlighted).assertTrue() // HIGHLIGHTED 保留
    })

    it('reset_fully_resets', 0, () => {
      const cell = new CellData()
      cell.value = 5
      cell.notes = 999
      cell.flags = 0b11111
      cell.reset()
      expect(cell.value).assertEqual(0)
      expect(cell.flags).assertEqual(0)
      expect(cell.notes).assertEqual(0)
    })
  })

  describe('createEmptyBoard', () => {
    it('creates_81_cells', 0, () => {
      const board = createEmptyBoard()
      expect(board.length).assertEqual(81)
    })

    it('each_cell_row_col_correct', 0, () => {
      const board = createEmptyBoard()
      expect(board[0].row).assertEqual(0)
      expect(board[0].col).assertEqual(0)
      expect(board[8].row).assertEqual(0)
      expect(board[8].col).assertEqual(8)
      expect(board[9].row).assertEqual(1)
      expect(board[9].col).assertEqual(0)
      expect(board[80].row).assertEqual(8)
      expect(board[80].col).assertEqual(8)
    })

    it('all_cells_zeroed', 0, () => {
      const board = createEmptyBoard()
      for (const cell of board) {
        expect(cell.value).assertEqual(0)
        expect(cell.flags).assertEqual(0)
        expect(cell.notes).assertEqual(0)
      }
    })
  })

  describe('createBoardFromArray', () => {
    it('from_array_nonzero_marked_GIVEN', 0, () => {
      const puzzle: number[][] = []
      for (let r = 0; r < 9; r++) {
        const row: number[] = []
        for (let c = 0; c < 9; c++) {
          row.push(0)
        }
        puzzle.push(row)
      }
      // 设几个已知数
      puzzle[0][0] = 5
      puzzle[4][4] = 9
      puzzle[8][8] = 1

      const board = createBoardFromArray(puzzle)
      expect(board.length).assertEqual(81)

      // 检查给定格
      expect(board[0].value).assertEqual(5)
      expect(board[0].isGiven).assertTrue()

      expect(board[4 * 9 + 4].value).assertEqual(9)
      expect(board[4 * 9 + 4].isGiven).assertTrue()

      expect(board[80].value).assertEqual(1)
      expect(board[80].isGiven).assertTrue()

      // 检查空格
      expect(board[1].value).assertEqual(0)
      expect(board[1].isGiven).assertFalse()
    })
  })
}
