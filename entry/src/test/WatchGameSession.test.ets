import { describe, it, expect } from '@ohos/hypium'
import { applyGridConfig, Difficulty } from '../main/ets/constants/GameConstants'
import { GRID_4x4, GRID_9x9 } from '../main/ets/models/VariantConfig'
import { WatchGameSession, WatchSaveData, isValidWatchSave, watchBoxIndex,
  watchCellIndex } from '../main/ets/utils/WatchGameSession'

function fixture(): WatchGameSession {
  const size = GRID_9x9.gridSize
  const box = GRID_9x9.boxRows
  const solution: number[][] = []
  const puzzle: number[][] = []
  for (let row = 0; row < size; row++) {
    const answerRow: number[] = []
    const puzzleRow: number[] = []
    for (let col = 0; col < size; col++) {
      const value = (row * box + Math.floor(row / box) + col) % size + 1
      answerRow.push(value)
      puzzleRow.push(row === 0 ? value : 0)
    }
    solution.push(answerRow)
    puzzle.push(puzzleRow)
  }
  return WatchGameSession.create(puzzle, solution, Difficulty.EASY) as WatchGameSession
}

export default function watchGameSessionTest() {
  describe('WatchGameSession', () => {
    it('covers_all_cells_with_large_box_selection', 0, () => {
      const indices: number[] = []
      for (let box = 0; box < GRID_9x9.gridSize; box++) {
        for (let offset = 0; offset < GRID_9x9.gridSize; offset++) {
          const cell = watchCellIndex(box, offset)
          expect(watchBoxIndex(cell)).assertEqual(box)
          expect(indices.includes(cell)).assertFalse()
          indices.push(cell)
        }
      }
      expect(indices.length).assertEqual(GRID_9x9.totalCells)
    })
    it('does_not_depend_on_the_phone_grid_configuration', 0, () => {
      applyGridConfig(GRID_4x4)
      const session = fixture()
      expect(isValidWatchSave(session.data)).assertTrue()
      expect(session.input(80, 9, false)).assertTrue()
      expect(session.data.values.length).assertEqual(GRID_9x9.totalCells)
      applyGridConfig(GRID_9x9)
    })
    it('protects_givens_and_rejects_invalid_digits', 0, () => {
      const session = fixture()
      expect(session.input(0, 9, false)).assertFalse()
      expect(session.erase(0)).assertFalse()
      expect(session.input(9, 0, false)).assertFalse()
      expect(session.input(9, 10, false)).assertFalse()
      expect(session.input(-1, 1, false)).assertFalse()
      expect(session.data.undo.length).assertEqual(0)
    })
    it('undo_restores_peer_notes_removed_by_a_digit', 0, () => {
      const session = fixture()
      session.input(10, 4, true)
      expect(session.data.notes[10]).assertEqual(8)
      session.input(9, 4, false)
      expect(session.data.notes[10]).assertEqual(0)
      expect(session.undo()).assertTrue()
      expect(session.data.notes[10]).assertEqual(8)
      expect(session.data.values[9]).assertEqual(0)
    })
    it('toggles_notes_and_restores_erase_atomically', 0, () => {
      const session = fixture()
      session.input(9, 2, true)
      session.input(9, 4, true)
      expect(session.data.notes[9]).assertEqual(10)
      session.input(9, 2, true)
      expect(session.data.notes[9]).assertEqual(8)
      session.erase(9)
      expect(session.data.notes[9]).assertEqual(0)
      session.undo()
      expect(session.data.notes[9]).assertEqual(8)
    })
    it('hint_corrects_the_selected_cell_and_is_undoable', 0, () => {
      const session = fixture()
      session.input(9, 1, false)
      expect(session.hint(9)).assertEqual(9)
      expect(session.data.values[9]).assertEqual(session.data.solution[9])
      expect(session.data.hints).assertEqual(1)
      session.undo()
      expect(session.data.values[9]).assertEqual(1)
      expect(session.data.hints).assertEqual(1)
    })
    it('restores_serialized_values_notes_timer_and_undo', 0, () => {
      const session = fixture()
      session.input(9, 4, true)
      session.input(10, 5, false)
      session.data.seconds = 75
      const saved = JSON.parse(JSON.stringify(session.data)) as WatchSaveData
      const restored = WatchGameSession.restore(saved) as WatchGameSession
      expect(restored.data.seconds).assertEqual(75)
      expect(restored.data.notes[9]).assertEqual(8)
      expect(restored.data.values[10]).assertEqual(5)
      restored.undo()
      expect(restored.data.values[10]).assertEqual(0)
      expect(saved.values[10]).assertEqual(5)
      expect(isValidWatchSave(restored.data)).assertTrue()
    })
    it('rejects_damaged_or_foreign_saves', 0, () => {
      const session = fixture()
      const saved = JSON.parse(JSON.stringify(session.data)) as WatchSaveData
      saved.solution[9] = saved.solution[10]
      expect(WatchGameSession.restore(saved)).assertNull()
      expect(WatchGameSession.restore(new WatchSaveData())).assertNull()
      session.data.notes[9] = 512
      expect(isValidWatchSave(session.data)).assertFalse()
    })
    it('requires_the_correct_solution_for_completion', 0, () => {
      const session = fixture()
      for (let i = GRID_9x9.gridSize; i < GRID_9x9.totalCells; i++) {
        session.input(i, session.data.solution[i], false)
      }
      expect(session.isComplete()).assertTrue()
      expect(session.input(80, 1, false)).assertFalse()
      expect(session.erase(80)).assertFalse()
      expect(session.undo()).assertTrue()
      expect(session.isComplete()).assertFalse()
      expect(session.hint(80)).assertEqual(80)
      expect(session.isComplete()).assertTrue()
    })
  })
}
