/**
 * GestureKey.ets — 单个手势键
 *
 * 支持：点击(填数)、上滑(笔记)、右滑(删除线)、左滑(擦除)。
 * 用 PanGesture 检测滑动方向，用 atan2 判定。
 *
 * 参考：Doc 05 §3 手势键盘
 */
import { ColorsConfig, getThemeColors, Sizes, GestureDirection } from '../constants/GameConstants'
import { PAPER_DIGIT_FONT_FAMILY, PAPER_DIGIT_USER_WEIGHT } from '../constants/Typography'

@Component
export struct GestureKey {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  /** 这个键代表的数字 (1-9) */
  digit: number = 1
  @Prop fontSize: number = Sizes.keyFont
  /** 这个数字的剩余计数（9 - 已填数量） */
  @Prop remaining: number = 9
  /** 是否已满 9 个 */
  @Prop isComplete: boolean = false
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
    if (this.isComplete) return this.getPalette().keyDisabled

    if (this.currentDirection !== null) {
      switch (this.currentDirection) {
        case GestureDirection.UP: return this.getPalette().indicatorNote
        case GestureDirection.RIGHT: return this.getPalette().indicatorElim
        case GestureDirection.LEFT: return this.getPalette().indicatorErase
        case GestureDirection.DOWN: return this.getPalette().indicatorErase
        default: return this.getPalette().cellHighlight
      }
    }

    return this.isPressed ? this.getPalette().cellHighlight : this.getPalette().keyBg
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        // 数字
        Text(this.digit.toString())
          .fontFamily(PAPER_DIGIT_FONT_FAMILY)
          .fontFeature('"lnum" 1, "tnum" 1')
          .fontSize(this.fontSize)
          .fontColor(this.isComplete ? this.getPalette().keyDisabledText : this.getPalette().keyText)
          .fontWeight(PAPER_DIGIT_USER_WEIGHT, { enableVariableFontWeight: true })

      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 剩余数量保留为角标，主数字位置不随计数变化。
      Text(this.remaining.toString())
        .fontSize(10)
        .fontColor(this.getPalette().subtitleText)
        .fontWeight(FontWeight.Normal)
        .position({ right: 3, bottom: 4 })
        .accessibilityLevel('no')

      // 完整手势说明显示在工具区浮层，避免单排数字键中长文案挤压数字。
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
    // 每个数字独立成纸签：保留四边纸缘，底边略重；按压靠纸色和收起阴影反馈。
    .borderRadius(3)
    .backgroundColor(this.getKeyBgColor())
    .border({ width: { top: 0.6, left: 0.6, right: 0.6, bottom: 1 },
      color: this.isPressed ? this.getPalette().toolbarActive : this.getPalette().cardBorder })
    .shadow({ radius: this.isPressed || this.isComplete ? 0 : 2,
      color: this.getPalette().shadowColorLight, offsetX: 0, offsetY: this.isPressed ? 0 : 1 })
    .accessibilityText($r('app.string.key_remaining_a11y', this.digit, this.remaining))
    .opacity(this.isComplete ? 0.64 : 1)
    .animation({ duration: 90, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false
      }
    })
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
            // 已填满的数字禁止重复填入；候选标记/擦除手势仍可用于整理笔记。
            if (!this.isComplete || direction !== GestureDirection.TAP) {
              this.onGesture(this.digit, direction)
            }
          }
          this.currentDirection = null
          this.onGestureDirectionChange(null)
        })
        .onActionCancel(() => {
          this.isPressed = false
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
