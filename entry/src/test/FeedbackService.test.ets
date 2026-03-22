import { describe, it, expect } from '@ohos/hypium'
import {
  FeedbackType,
  getFeedbackRawFileName,
  getFeedbackVolume,
  getFeedbackVibrationDuration,
  shouldVibrateForFeedback
} from '../main/ets/services/FeedbackService'

export default function feedbackServiceTest() {
  describe('FeedbackService.mapping', () => {
    it('raw_files_are_stable_for_each_feedback_type', 0, () => {
      expect(getFeedbackRawFileName(FeedbackType.FILL)).assertEqual('feedback_fill.wav')
      expect(getFeedbackRawFileName(FeedbackType.NOTE)).assertEqual('feedback_note.wav')
      expect(getFeedbackRawFileName(FeedbackType.ERROR)).assertEqual('feedback_error.wav')
      expect(getFeedbackRawFileName(FeedbackType.COMPLETE)).assertEqual('feedback_complete.wav')
    })

    it('note_feedback_is_quieter_than_error_and_complete', 0, () => {
      expect(getFeedbackVolume(FeedbackType.NOTE) < getFeedbackVolume(FeedbackType.FILL)).assertTrue()
      expect(getFeedbackVolume(FeedbackType.ERROR) > getFeedbackVolume(FeedbackType.NOTE)).assertTrue()
      expect(getFeedbackVolume(FeedbackType.COMPLETE)).assertEqual(1)
    })

    it('only_note_error_and_complete_vibrate', 0, () => {
      expect(shouldVibrateForFeedback(FeedbackType.FILL)).assertFalse()
      expect(shouldVibrateForFeedback(FeedbackType.NOTE)).assertTrue()
      expect(shouldVibrateForFeedback(FeedbackType.ERROR)).assertTrue()
      expect(shouldVibrateForFeedback(FeedbackType.COMPLETE)).assertTrue()
    })

    it('error_and_complete_use_stronger_vibration_patterns', 0, () => {
      expect(getFeedbackVibrationDuration(FeedbackType.FILL)).assertEqual(0)
      expect(getFeedbackVibrationDuration(FeedbackType.NOTE)).assertEqual(20)
      expect(getFeedbackVibrationDuration(FeedbackType.ERROR)).assertEqual(120)
      expect(getFeedbackVibrationDuration(FeedbackType.COMPLETE)).assertEqual(180)
    })
  })
}
