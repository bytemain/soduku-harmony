/**
 * GestureNumberPad.ets — 手势键盘
 *
 * 包含 GRID_SIZE 个 GestureKey，排列成网格。
 * 布局使用与宫格相同的 BOX_COLS × BOX_ROWS 排列（行列互换），
 * 使数字键盘始终与棋盘宫格布局匹配。
 *
 * 参考：Doc 05 §3
 */
import { GestureDirection, Sizes, DIGITS, BOX_COLS, BOX_ROWS,
  createInitialRemainingCounts } from '../constants/GameConstants'
import { GestureKey } from './GestureKey'

@Component
export struct GestureNumberPad {
  /** 各数字剩余计数 [_, count1, count2, ..., countN]，index 0 不用 */
  @Prop remainingCounts: number[] = createInitialRemainingCounts()
  onGesture: (digit: number, direction: GestureDirection) => void = () => {}
  onGestureDirectionChange: (direction: GestureDirection | null) => void = () => {}
  /** 高度变化回调，用于同步 AuxButtonGrid 高度 */
  onHeightChange: (height: number) => void = () => {}

  build() {
    Grid() {
      ForEach(DIGITS, (digit: number) => {
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
    .columnsTemplate('1fr '.repeat(BOX_ROWS).trim())
    .rowsTemplate('1fr '.repeat(BOX_COLS).trim())
    .aspectRatio(1)
    .layoutWeight(1)
    .onAreaChange((_oldArea, newArea) => {
      const h = newArea.height as number
      if (h > 0) {
        this.onHeightChange(h)
      }
    })
  }
}
