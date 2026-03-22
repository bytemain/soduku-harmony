import { describe, it, expect } from '@ohos/hypium'
import { Difficulty } from '../main/ets/constants/GameConstants'
import {
  applyProgressMapToPuzzles,
  createPuzzleProgressData,
  getLibraryProgressKey,
  getLibraryPuzzlesKey,
  PuzzleProgressData,
} from '../main/ets/utils/PuzzleLibraryStorage'
import { createPuzzleEntry, PuzzleEntry } from '../main/ets/models/PuzzleLibrary'

function buildPuzzle(index: number, puzzle81: string): PuzzleEntry {
  return createPuzzleEntry(index, puzzle81, undefined, Difficulty.EASY)
}

export default function puzzleLibraryStorageTest() {
  describe('PuzzleLibraryStorage.Keys', () => {
    it('builds_library_specific_storage_keys', 0, () => {
      expect(getLibraryPuzzlesKey('builtin-easy-50')).assertEqual('library_builtin-easy-50_puzzles')
      expect(getLibraryProgressKey('builtin-easy-50')).assertEqual('library_builtin-easy-50_progress')
    })
  })

  describe('PuzzleLibraryStorage.ProgressData', () => {
    it('creates_default_progress_data_when_source_missing', 0, () => {
      const progress = createPuzzleProgressData()
      expect(progress.status).assertEqual('new')
      expect(progress.elapsedSeconds).assertEqual(0)
      expect(progress.errorCount).assertEqual(0)
      expect(progress.percentage).assertEqual(0)
    })

    it('copies_progress_fields', 0, () => {
      const source = new PuzzleProgressData()
      source.status = 'in_progress'
      source.startedAt = 123
      source.elapsedSeconds = 88
      source.errorCount = 2
      source.percentage = 41
      source.cellStates = 'cells-json'

      const copied = createPuzzleProgressData(source)
      expect(copied.status).assertEqual('in_progress')
      expect(copied.startedAt).assertEqual(123)
      expect(copied.elapsedSeconds).assertEqual(88)
      expect(copied.errorCount).assertEqual(2)
      expect(copied.percentage).assertEqual(41)
      expect(copied.cellStates).assertEqual('cells-json')
    })
  })

  describe('PuzzleLibraryStorage.ApplyProgressMap', () => {
    it('applies_progress_to_matching_puzzles_only', 0, () => {
      const puzzle0 = buildPuzzle(0, '003020600900305001001806400008102900700000008006708200002609500800203009005010300')
      const puzzle1 = buildPuzzle(1, '530070000600195000098000060800060003400803001700020006060000280000419005000080079')
      const puzzles: PuzzleEntry[] = [puzzle0, puzzle1]

      const progress0 = new PuzzleProgressData()
      progress0.status = 'completed'
      progress0.elapsedSeconds = 320
      progress0.percentage = 100

      const progressMap: Record<string, PuzzleProgressData> = {
        '0': progress0,
      }

      const result = applyProgressMapToPuzzles(puzzles, progressMap)
      expect(result.length).assertEqual(2)
      expect(result[0].progress.status).assertEqual('completed')
      expect(result[0].progress.elapsedSeconds).assertEqual(320)
      expect(result[0].progress.percentage).assertEqual(100)
      expect(result[1].progress.status).assertEqual('new')
      expect(result[1].progress.elapsedSeconds).assertEqual(0)
    })
  })
}
