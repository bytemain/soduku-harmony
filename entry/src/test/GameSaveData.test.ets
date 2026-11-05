import { describe, it, expect } from '@ohos/hypium'
import { CellSerialized, GameSaveData, isValidGameSave } from '../main/ets/models/GameSaveData'

function fixture(size: number = 9): GameSaveData {
  const data = new GameSaveData()
  data.gridSize = size
  data.difficulty = 2
  const boxRows = size === 9 ? 3 : 2
  const boxCols = size / boxRows
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      const value = (r * boxCols + Math.floor(r / boxRows) + c) % size + 1
      data.solution.push(value)
      data.cells.push(new CellSerialized(r, c, r === 0 ? value : 0, r === 0 ? 1 : 0))
    }
  }
  return data
}

export default function gameSaveDataTest() {
  describe('GameSaveData.ReleaseRegression', () => {
    it('rejects_uninitialized_board_and_empty_solution', 0, () => {
      const empty = new GameSaveData()
      expect(isValidGameSave(empty)).assertFalse()
      const data = fixture()
      data.solution = []
      expect(isValidGameSave(data)).assertFalse()
    })
    it('accepts_supported_sizes_without_global_configuration', 0, () => {
      expect(isValidGameSave(fixture(4))).assertTrue()
      expect(isValidGameSave(fixture(6))).assertTrue()
      expect(isValidGameSave(fixture(9))).assertTrue()
    })
    it('rejects_clue_that_does_not_match_solution', 0, () => {
      const data = fixture()
      data.cells[0].value = 9
      expect(isValidGameSave(data)).assertFalse()
    })
    it('rejects_duplicate_solution_digits', 0, () => {
      const data = fixture()
      data.solution[9] = data.solution[10]
      expect(isValidGameSave(data)).assertFalse()
    })
    it('rejects_missing_variant_configuration', 0, () => {
      const data = fixture()
      data.variantType = 'killer'
      expect(isValidGameSave(data)).assertFalse()
      data.variantType = 'jigsaw'
      expect(isValidGameSave(data)).assertFalse()
    })
    it('preserves_library_identity_and_generation_difficulty', 0, () => {
      const data = fixture()
      data.libraryId = 'builtin-easy'
      data.puzzleIndex = 3
      data.generationDifficulty = 4
      const restored = JSON.parse(JSON.stringify(data)) as GameSaveData
      expect(isValidGameSave(restored)).assertTrue()
      expect(restored.libraryId).assertEqual('builtin-easy')
      expect(restored.puzzleIndex).assertEqual(3)
      expect(restored.generationDifficulty).assertEqual(4)
    })
  })
}
