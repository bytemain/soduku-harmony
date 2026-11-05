/**
 * GestureModeIndicator.ets — 手势模式提示条
 *
 * 位于操作区已有的工具槽内，不使用跨组件绝对坐标。
 * 高度固定，仅切换透明度；提示出现和消失不改变数字键位置。
 *
 * 参考：Doc 05 §手势模式提示条
 */
import { ColorsConfig, getThemeColors, Sizes, GestureDirection } from '../constants/GameConstants'

@Component
export struct GestureModeIndicator {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  /** 当前手势方向，null 表示隐藏 */
  @Prop currentDirection: GestureDirection | null = null

  private isVisible(): boolean {
    return this.currentDirection !== null && this.currentDirection !== GestureDirection.TAP
  }

  private getIndicatorText(): ResourceStr {
    switch (this.currentDirection) {
      case GestureDirection.UP: return $r('app.string.indicator_note')
      case GestureDirection.RIGHT: return $r('app.string.indicator_eliminate')
      case GestureDirection.LEFT: return $r('app.string.indicator_erase')
      case GestureDirection.DOWN: return $r('app.string.indicator_reserved')
      default: return ''
    }
  }

  private getIndicatorBgColor(): ResourceColor {
    switch (this.currentDirection) {
      case GestureDirection.UP: return this.getPalette().indicatorNote
      case GestureDirection.RIGHT: return this.getPalette().indicatorElim
      case GestureDirection.LEFT: return this.getPalette().indicatorErase
      case GestureDirection.DOWN: return this.getPalette().indicatorErase
      default: return 'transparent'
    }
  }

  build() {
    Row() {
      Text(this.getIndicatorText())
        .fontSize(13)
        .minFontSize(12)
        .maxFontSize(13)
        .maxLines(2)
        .lineHeight(16)
        .textAlign(TextAlign.Center)
        .heightAdaptivePolicy(TextHeightAdaptivePolicy.LAYOUT_CONSTRAINT_FIRST)
        .width('100%')
        .fontColor(this.getPalette().indicatorText)
    }
    .width('100%')
    .height(48)
    .padding({ left: 6, right: 6 })
    .justifyContent(FlexAlign.Center)
    .hitTestBehavior(HitTestMode.None)
    .backgroundColor(this.getIndicatorBgColor())
    .borderRadius(6)
    .opacity(this.isVisible() ? 1 : 0)
    .accessibilityLevel(this.isVisible() ? 'auto' : 'no-hide-descendants')
    .animation({
      duration: Sizes.indicatorDuration,
      curve: Curve.EaseOut,
    })
    .clip(true)
  }
}
