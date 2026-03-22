import { describe, it, expect, afterEach } from '@ohos/hypium'
import { applyTheme, Colors, LightColors, DarkColors } from '../main/ets/constants/GameConstants'

export default function gameConstantsTest() {
  describe('GameConstants.ThemeColors', () => {
    afterEach(() => {
      applyTheme(false)
    })

    it('applyTheme_light_uses_light_tokens', 0, () => {
      applyTheme(false)
      expect(Colors.boardBg).assertEqual(LightColors.boardBg)
      expect(Colors.modalOverlayMask).assertEqual(LightColors.modalOverlayMask)
      expect(Colors.systemBarContent).assertEqual(LightColors.systemBarContent)
    })

    it('applyTheme_dark_uses_dark_tokens', 0, () => {
      applyTheme(true)
      expect(Colors.boardBg).assertEqual(DarkColors.boardBg)
      expect(Colors.modalOverlayMask).assertEqual(DarkColors.modalOverlayMask)
      expect(Colors.systemBarContent).assertEqual(DarkColors.systemBarContent)
      expect(Colors.cellBorderThin).assertEqual(DarkColors.cellBorderThin)
      expect(Colors.killerCageBorder).assertEqual(DarkColors.killerCageBorder)
      expect(Colors.killerCageLabel).assertEqual(DarkColors.killerCageLabel)
    })

    it('dark_variant_colors_keep_contrast_against_board', 0, () => {
      expect(DarkColors.cellBorderThin === DarkColors.boardBg).assertFalse()
      expect(DarkColors.cellBorderBold === DarkColors.boardBg).assertFalse()
      expect(DarkColors.killerCageBorder === DarkColors.boardBg).assertFalse()
      expect(DarkColors.killerCageLabel === DarkColors.boardBg).assertFalse()
      expect(DarkColors.systemBarContent === DarkColors.boardBg).assertFalse()
    })
  })
}
