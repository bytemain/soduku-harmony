/**
 * GestureModeIndicator.ets — 手势模式提示条
 *
 * 位于棋盘和操作区之间。
 * 平时隐藏（高度 0），滑动时滑出（高度 28vp），松手后 150ms 淡出。
 *
 * 参考：Doc 05 §手势模式提示条
 */
import { Colors, Sizes, GestureDirection } from '../constants/GameConstants'

@Component
export struct GestureModeIndicator {
  /** 当前手势方向，null 表示隐藏 */
  currentDirection: GestureDirection | null = null

  private getIndicatorText(): string {
    switch (this.currentDirection) {
      case GestureDirection.UP: return '✏️ 笔记模式'
      case GestureDirection.RIGHT: return '～～ 删除线模式'
      case GestureDirection.LEFT: return '🧹 擦除笔记'
      case GestureDirection.DOWN: return '⬇️ 预留功能'
      default: return ''
    }
  }

  private getIndicatorBgColor(): ResourceColor {
    switch (this.currentDirection) {
      case GestureDirection.UP: return Colors.indicatorNote
      case GestureDirection.RIGHT: return Colors.indicatorElim
      case GestureDirection.LEFT: return Colors.indicatorErase
      case GestureDirection.DOWN: return Colors.indicatorErase
      default: return 'transparent'
    }
  }

  build() {
    Row() {
      Text(this.getIndicatorText())
        .fontSize(13)
        .fontColor(Colors.indicatorText)
    }
    .width('100%')
    .height(this.currentDirection !== null ? Sizes.indicatorHeight : 0)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.getIndicatorBgColor())
    .borderRadius(6)
    .animation({
      duration: Sizes.indicatorDuration,
      curve: Curve.EaseOut,
    })
    .clip(true)
  }
}
