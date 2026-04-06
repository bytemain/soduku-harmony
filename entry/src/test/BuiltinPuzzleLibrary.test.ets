import { describe, it, expect } from '@ohos/hypium'
import { getBuiltinPuzzleEntries, getBuiltinPuzzleLibraries } from '../main/ets/utils/BuiltinPuzzleLibrary'

export default function builtinPuzzleLibraryTest() {
  describe('BuiltinPuzzleLibrary', () => {
    it('returns_builtin_library_index', 0, () => {
      const libraries = getBuiltinPuzzleLibraries()
      expect(libraries.length > 0).assertTrue()
      expect(libraries[0].id).assertEqual('builtin-starter')
      expect(libraries[0].puzzleCount).assertEqual(3)
    })

    it('returns_builtin_puzzle_entries', 0, () => {
      const puzzles = getBuiltinPuzzleEntries('builtin-starter')
      expect(puzzles.length).assertEqual(3)
      expect(puzzles[0].puzzle81.length).assertEqual(81)
      expect(puzzles[1].puzzle81.length).assertEqual(81)
      expect(puzzles[2].puzzle81.length).assertEqual(81)
    })

    it('returns_empty_list_for_unknown_library', 0, () => {
      const puzzles = getBuiltinPuzzleEntries('unknown')
      expect(puzzles.length).assertEqual(0)
    })
  })
}

