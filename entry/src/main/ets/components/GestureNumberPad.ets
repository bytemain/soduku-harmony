/**
 * GestureNumberPad.ets — 3×3 手势键盘
 *
 * 包含 9 个 GestureKey，排列成 3×3 网格。
 * 每个键显示数字(1-9)和剩余计数。
 *
 * 参考：Doc 05 §3
 */
import { GestureDirection, Sizes } from '../constants/GameConstants'
import { GestureKey } from './GestureKey'

@Component
export struct GestureNumberPad {
  /** 各数字剩余计数 [_, count1, count2, ..., count9]，index 0 不用 */
  @Prop remainingCounts: number[] = [0, 9, 9, 9, 9, 9, 9, 9, 9, 9]
  onGesture: (digit: number, direction: GestureDirection) => void = () => {}
  onGestureDirectionChange: (direction: GestureDirection | null) => void = () => {}

  build() {
    Grid() {
      ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], (digit: number) => {
        GridItem() {
          GestureKey({
            digit: digit,
            remaining: this.remainingCounts[digit],
            isComplete: this.remainingCounts[digit] <= 0,
            onGesture: this.onGesture,
            onGestureDirectionChange: this.onGestureDirectionChange,
          })
        }
        .padding(3)
      })
    }
    .columnsTemplate('1fr 1fr 1fr')
    .rowsTemplate('1fr 1fr 1fr')
    .aspectRatio(1)
    .layoutWeight(1)
  }
}
