/**
 * GestureKey.ets — 单个手势键
 *
 * 支持：点击(填数)、上滑(笔记)、右滑(删除线)、左滑(擦除)。
 * 用 PanGesture 检测滑动方向，用 atan2 判定。
 *
 * 参考：Doc 05 §3 手势键盘
 */
import { Colors, Sizes, GestureDirection } from '../constants/GameConstants'

@Component
export struct GestureKey {
  /** 这个键代表的数字 (1-9) */
  digit: number = 1
  /** 这个数字的剩余计数（9 - 已填数量） */
  remaining: number = 9
  /** 是否已满 9 个 */
  isComplete: boolean = false
  /** 手势回调 */
  onGesture: (digit: number, direction: GestureDirection) => void = () => {}
  /** 当前手势方向指示回调（用于实时更新提示条） */
  onGestureDirectionChange: (direction: GestureDirection | null) => void = () => {}

  @State private isPressed: boolean = false
  @State private currentDirection: GestureDirection | null = null

  /**
   * 根据当前滑动方向返回键背景色
   */
  private getKeyBgColor(): ResourceColor {
    if (this.isComplete) return Colors.keyDisabled

    if (this.currentDirection !== null) {
      switch (this.currentDirection) {
        case GestureDirection.UP: return Colors.indicatorNote
        case GestureDirection.RIGHT: return Colors.indicatorElim
        case GestureDirection.LEFT: return Colors.indicatorErase
        case GestureDirection.DOWN: return Colors.indicatorErase
        default: return Colors.keyBg
      }
    }

    return Colors.keyBg
  }

  /**
   * 获取滑动方向的文字提示
   */
  private getDirectionLabel(): string {
    switch (this.currentDirection) {
      case GestureDirection.UP: return '笔记'
      case GestureDirection.RIGHT: return '删除线'
      case GestureDirection.LEFT: return '擦除'
      case GestureDirection.DOWN: return '↓'
      default: return ''
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        // 数字
        Text(this.digit.toString())
          .fontSize(Sizes.keyFont)
          .fontColor(this.isComplete ? Colors.keyDisabledText : Colors.keyText)
          .fontWeight(FontWeight.Medium)

        // 剩余计数
        Text(this.remaining.toString())
          .fontSize(Sizes.keyCountFont)
          .fontColor(Colors.subtitleText)
          .margin({ top: 2 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 滑动方向文字提示
      if (this.currentDirection !== null && this.currentDirection !== GestureDirection.TAP) {
        Text(this.getDirectionLabel())
          .fontSize(10)
          .fontColor(Colors.indicatorText)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(Sizes.keyRadius)
    .backgroundColor(this.getKeyBgColor())
    .opacity(this.isComplete ? 0.5 : 1)
    .scale({
      x: this.isPressed ? 0.92 : 1,
      y: this.isPressed ? 0.92 : 1,
    })
    .animation({ duration: 100 })
    .gesture(
      PanGesture({ distance: 1 })
        .onActionStart(() => {
          this.isPressed = true
          this.currentDirection = null
        })
        .onActionUpdate((event: GestureEvent) => {
          if (event) {
            const dir = this.resolveDirection(event.offsetX, event.offsetY)
            if (dir !== this.currentDirection) {
              this.currentDirection = dir
              this.onGestureDirectionChange(dir)
            }
          }
        })
        .onActionEnd((event: GestureEvent) => {
          this.isPressed = false
          if (event) {
            const direction = this.resolveGesture(event.offsetX, event.offsetY)
            this.onGesture(this.digit, direction)
          }
          this.currentDirection = null
          this.onGestureDirectionChange(null)
        })
    )
    .onClick(() => {
      // 短点击也要触发（PanGesture 可能不触发 onActionEnd）
      // 用 TAP 作为点击操作
      if (!this.isComplete) {
        this.onGesture(this.digit, GestureDirection.TAP)
      }
    })
  }

  /**
   * 手势判定：atan2 + 角度划分（阈值内视为 TAP）
   */
  private resolveGesture(dx: number, dy: number): GestureDirection {
    const dist = Math.sqrt(dx * dx + dy * dy)
    if (dist < Sizes.gestureThreshold) {
      return GestureDirection.TAP
    }
    return this.resolveDirection(dx, dy)
  }

  /**
   * 纯方向判定（不含 TAP）
   */
  private resolveDirection(dx: number, dy: number): GestureDirection {
    const dist = Math.sqrt(dx * dx + dy * dy)
    if (dist < Sizes.gestureThreshold) {
      return GestureDirection.TAP
    }

    // atan2(-dy, dx)：y 轴翻转（屏幕向下为正）
    const angle = Math.atan2(-dy, dx) * 180 / Math.PI

    if (angle > 45 && angle <= 135) return GestureDirection.UP
    if (angle > -45 && angle <= 45) return GestureDirection.RIGHT
    if (angle > -135 && angle <= -45) return GestureDirection.DOWN
    return GestureDirection.LEFT
  }
}
