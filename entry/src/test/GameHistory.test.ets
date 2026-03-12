import { describe, it, expect } from '@ohos/hypium'
import { GameHistory, CellSnapshot } from '../main/ets/models/GameHistory'

export default function gameHistoryTest() {
  describe('GameHistory.push', () => {
    it('single_push_creates_group_of_one', 0, () => {
      const h = new GameHistory()
      h.push(new CellSnapshot(0, 0, 5, 0, 0, 0, 0))
      expect(h.undoStack.length).assertEqual(1)
      expect(h.undoStack[0].length).assertEqual(1)
      expect(h.undoStack[0][0].newValue).assertEqual(5)
    })

    it('push_clears_redo_stack', 0, () => {
      const h = new GameHistory()
      h.push(new CellSnapshot(0, 0, 5, 0, 0, 0, 0))
      h.popUndo() // move to redo
      expect(h.redoStack.length).assertEqual(1)
      h.push(new CellSnapshot(1, 0, 3, 0, 0, 0, 0))
      expect(h.redoStack.length).assertEqual(0)
    })
  })

  describe('GameHistory.pushBatch', () => {
    it('batch_push_creates_single_group', 0, () => {
      const h = new GameHistory()
      const batch: CellSnapshot[] = [
        new CellSnapshot(0, 0, 0, 0, 10, 0, 0),
        new CellSnapshot(1, 0, 0, 0, 20, 0, 0),
        new CellSnapshot(2, 0, 0, 0, 30, 0, 0),
      ]
      h.pushBatch(batch)
      expect(h.undoStack.length).assertEqual(1)
      expect(h.undoStack[0].length).assertEqual(3)
    })

    it('empty_batch_is_ignored', 0, () => {
      const h = new GameHistory()
      h.pushBatch([])
      expect(h.undoStack.length).assertEqual(0)
    })

    it('batch_push_clears_redo_stack', 0, () => {
      const h = new GameHistory()
      h.push(new CellSnapshot(0, 0, 5, 0, 0, 0, 0))
      h.popUndo()
      expect(h.redoStack.length).assertEqual(1)
      h.pushBatch([new CellSnapshot(1, 0, 0, 0, 20, 0, 0)])
      expect(h.redoStack.length).assertEqual(0)
    })
  })

  describe('GameHistory.popUndo', () => {
    it('returns_null_when_empty', 0, () => {
      const h = new GameHistory()
      expect(h.popUndo()).assertNull()
    })

    it('returns_single_snapshot_group', 0, () => {
      const h = new GameHistory()
      h.push(new CellSnapshot(5, 0, 7, 0, 0, 0, 0))
      const group = h.popUndo()
      expect(group).not().assertNull()
      expect(group!.length).assertEqual(1)
      expect(group![0].index).assertEqual(5)
      expect(group![0].newValue).assertEqual(7)
    })

    it('returns_full_batch_group', 0, () => {
      const h = new GameHistory()
      h.pushBatch([
        new CellSnapshot(0, 0, 0, 0, 10, 0, 0),
        new CellSnapshot(1, 0, 0, 0, 20, 0, 0),
        new CellSnapshot(2, 0, 0, 0, 30, 0, 0),
      ])
      const group = h.popUndo()
      expect(group).not().assertNull()
      expect(group!.length).assertEqual(3)
      expect(group![0].newNotes).assertEqual(10)
      expect(group![1].newNotes).assertEqual(20)
      expect(group![2].newNotes).assertEqual(30)
    })

    it('moves_group_to_redo_stack', 0, () => {
      const h = new GameHistory()
      h.pushBatch([
        new CellSnapshot(0, 0, 0, 0, 10, 0, 0),
        new CellSnapshot(1, 0, 0, 0, 20, 0, 0),
      ])
      h.popUndo()
      expect(h.undoStack.length).assertEqual(0)
      expect(h.redoStack.length).assertEqual(1)
      expect(h.redoStack[0].length).assertEqual(2)
    })
  })

  describe('GameHistory.popRedo', () => {
    it('returns_null_when_empty', 0, () => {
      const h = new GameHistory()
      expect(h.popRedo()).assertNull()
    })

    it('returns_batch_group_from_redo', 0, () => {
      const h = new GameHistory()
      h.pushBatch([
        new CellSnapshot(0, 0, 0, 0, 10, 0, 0),
        new CellSnapshot(1, 0, 0, 0, 20, 0, 0),
      ])
      h.popUndo() // move to redo
      const group = h.popRedo()
      expect(group).not().assertNull()
      expect(group!.length).assertEqual(2)
      expect(h.undoStack.length).assertEqual(1)
      expect(h.redoStack.length).assertEqual(0)
    })
  })

  describe('GameHistory.canUndo_canRedo', () => {
    it('initially_false', 0, () => {
      const h = new GameHistory()
      expect(h.canUndo).assertFalse()
      expect(h.canRedo).assertFalse()
    })

    it('canUndo_true_after_push', 0, () => {
      const h = new GameHistory()
      h.push(new CellSnapshot(0, 0, 5, 0, 0, 0, 0))
      expect(h.canUndo).assertTrue()
      expect(h.canRedo).assertFalse()
    })

    it('canRedo_true_after_undo', 0, () => {
      const h = new GameHistory()
      h.push(new CellSnapshot(0, 0, 5, 0, 0, 0, 0))
      h.popUndo()
      expect(h.canUndo).assertFalse()
      expect(h.canRedo).assertTrue()
    })
  })

  describe('GameHistory.clear', () => {
    it('clears_both_stacks', 0, () => {
      const h = new GameHistory()
      h.push(new CellSnapshot(0, 0, 5, 0, 0, 0, 0))
      h.pushBatch([new CellSnapshot(1, 0, 0, 0, 10, 0, 0)])
      h.popUndo()
      expect(h.undoStack.length).assertEqual(1)
      expect(h.redoStack.length).assertEqual(1)
      h.clear()
      expect(h.undoStack.length).assertEqual(0)
      expect(h.redoStack.length).assertEqual(0)
      expect(h.canUndo).assertFalse()
      expect(h.canRedo).assertFalse()
    })
  })

  describe('GameHistory.mixed_single_and_batch', () => {
    it('undo_redo_preserves_group_integrity', 0, () => {
      const h = new GameHistory()
      // Single op
      h.push(new CellSnapshot(0, 0, 5, 0, 0, 0, 0))
      // Batch op (e.g. auto-notes filling 3 cells)
      h.pushBatch([
        new CellSnapshot(10, 0, 0, 0, 100, 0, 0),
        new CellSnapshot(20, 0, 0, 0, 200, 0, 0),
        new CellSnapshot(30, 0, 0, 0, 300, 0, 0),
      ])
      // Another single op
      h.push(new CellSnapshot(5, 0, 9, 0, 0, 0, 0))

      expect(h.undoStack.length).assertEqual(3) // 3 operations

      // Undo last single op
      const g1 = h.popUndo()
      expect(g1!.length).assertEqual(1)
      expect(g1![0].index).assertEqual(5)

      // Undo batch op — all 3 snapshots come back as one group
      const g2 = h.popUndo()
      expect(g2!.length).assertEqual(3)
      expect(g2![0].index).assertEqual(10)
      expect(g2![1].index).assertEqual(20)
      expect(g2![2].index).assertEqual(30)

      // Undo first single op
      const g3 = h.popUndo()
      expect(g3!.length).assertEqual(1)
      expect(g3![0].index).assertEqual(0)

      // All in redo now
      expect(h.undoStack.length).assertEqual(0)
      expect(h.redoStack.length).assertEqual(3)

      // Redo first single op
      const r1 = h.popRedo()
      expect(r1!.length).assertEqual(1)
      expect(r1![0].index).assertEqual(0)

      // Redo batch op
      const r2 = h.popRedo()
      expect(r2!.length).assertEqual(3)
    })
  })
}
