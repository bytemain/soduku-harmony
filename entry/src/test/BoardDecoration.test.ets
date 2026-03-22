import { describe, it, expect } from '@ohos/hypium'
import { Colors } from '../main/ets/constants/GameConstants'
import { buildDiagonalBoardDecorations } from '../main/ets/models/BoardDecoration'

export default function boardDecorationTest() {
  describe('BoardDecoration.Diagonal', () => {
    it('diagonal_cells_have_base_marker', 0, () => {
      const decorations = buildDiagonalBoardDecorations()
      expect(decorations[0].backgroundColor).assertEqual(Colors.cellDiagonal)
      expect(decorations[8].backgroundColor).assertEqual(Colors.cellDiagonal)
      expect(decorations[40].backgroundColor).assertEqual(Colors.cellDiagonal)
      expect(decorations[1].backgroundColor).assertEqual('')
    })

    it('main_diagonal_selection_highlights_main_only', 0, () => {
      const decorations = buildDiagonalBoardDecorations(0)
      expect(decorations[40].highlightBackgroundColor).assertEqual(Colors.cellDiagonalHighlight)
      expect(decorations[80].highlightBackgroundColor).assertEqual(Colors.cellDiagonalHighlight)
      expect(decorations[8].highlightBackgroundColor).assertEqual('')
    })

    it('center_selection_highlights_both_diagonals', 0, () => {
      const decorations = buildDiagonalBoardDecorations(40)
      expect(decorations[0].highlightBackgroundColor).assertEqual(Colors.cellDiagonalHighlight)
      expect(decorations[8].highlightBackgroundColor).assertEqual(Colors.cellDiagonalHighlight)
      expect(decorations[72].highlightBackgroundColor).assertEqual(Colors.cellDiagonalHighlight)
    })
  })
}
