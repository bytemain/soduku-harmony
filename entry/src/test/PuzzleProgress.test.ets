import { describe, it, expect } from '@ohos/hypium'
import { createDefaultProgress, mergePuzzleProgress } from '../main/ets/models/PuzzleLibrary'
import { GameSaveData } from '../main/ets/models/GameSaveData'

export default function puzzleProgressTest() {
  describe('PuzzleProgress.ReleaseRegression', () => {
    it('interrupted_replay_preserves_completion_and_current_save', 0, () => {
      const completed = createDefaultProgress()
      completed.status = 'completed'
      completed.elapsedSeconds = 120
      completed.completedAt = 1234
      completed.percentage = 100
      const replay = createDefaultProgress()
      replay.status = 'in_progress'
      replay.elapsedSeconds = 10
      replay.percentage = 20
      replay.gameSave = new GameSaveData()
      const merged = mergePuzzleProgress(completed, replay)
      expect(merged.status).assertEqual('completed')
      expect(merged.elapsedSeconds).assertEqual(120)
      expect(merged.completedAt).assertEqual(1234)
      expect(merged.percentage).assertEqual(100)
      expect(merged.gameSave !== undefined).assertTrue()
    })
    it('winning_replay_preserves_best_result_and_clears_resume', 0, () => {
      const best = createDefaultProgress()
      best.status = 'completed'
      best.elapsedSeconds = 100
      const slower = createDefaultProgress()
      slower.status = 'completed'
      slower.elapsedSeconds = 200
      const merged = mergePuzzleProgress(best, slower)
      expect(merged.elapsedSeconds).assertEqual(100)
      expect(merged.gameSave === undefined).assertTrue()
      slower.elapsedSeconds = 80
      expect(mergePuzzleProgress(best, slower).elapsedSeconds).assertEqual(80)
    })
    it('first_session_can_be_saved_without_completion', 0, () => {
      const current = createDefaultProgress()
      current.status = 'in_progress'
      expect(mergePuzzleProgress(null, current).status).assertEqual('in_progress')
    })
  })
}
