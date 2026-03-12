/**
 * SudokuCell.ets — 单元格组件
 *
 * 负责渲染一个 36vp 正方形格子。4 种显示模式：
 *   - 给定数字（黑色 Bold）
 *   - 用户填入（蓝色）
 *   - 错误数字（红色）
 *   - 笔记（3×3 微型排列）
 *
 * 使用 @ObjectLink 引用 CellData，属性变化自动刷新。
 *
 * 参考：Doc 05 §② 单元格
 */
import { CellData, CellFlags, hasFlag, getNoteState, NoteState } from '../models/CellData'
import { Colors, Sizes } from '../constants/GameConstants'
import { PEERS } from '../utils/Topology'

@Component
export struct SudokuCell {
  @ObjectLink cellData: CellData
  /** 选中格的 value（用于同数字高亮判断） */
  @Prop selectedValue: number = 0
  /** 是否为当前提示目标格 */
  @Prop isHintTarget: boolean = false
  /** 全部 81 个格子的引用，用于笔记冲突检测 */
  allCells: CellData[] = []
  onCellClick: () => void = () => {}
  /** 鼠标拖拽多选回调 action: 'start' | 'move' | 'end' */
  onMouseDragSelect: (action: string) => void = () => {}

  // --- 动画状态 ---
  @State private fillScale: number = 1.0
  @State private errorShakeX: number = 0
  /** 上一次渲染的 value，用于检测变化 */
  private lastValue: number = 0
  /** 上一次的 error 状态 */
  private lastError: boolean = false

  /**
   * 决定格子背景色（按优先级从高到低）
   */
  private getCellBgColor(): ResourceColor {
    if (this.isHintTarget) {
      return $r('app.color.current_hint_bg')
    }
    // 0. 多选模式选中 → 浅紫
    if (this.cellData.isMultiSelected) {
      return $r('app.color.multi_select_bg')
    }
    // 1. 选中格 → 浅蓝
    if (this.cellData.isSelected) {
      return Colors.cellSelected
    }
    // 2. 错误格 → 浅红
    if (this.cellData.isError) {
      return Colors.cellError
    }
    // 3. 同数字 → 浅绿（棋盘上所有与 selectedValue 相同数字的格子）
    if (this.cellData.value !== 0
      && this.selectedValue !== 0 && this.cellData.value === this.selectedValue) {
      return Colors.cellSameNumber
    }
    // 4. 同行列宫 → 极浅蓝
    if (this.cellData.isHighlighted) {
      return Colors.cellHighlight
    }
    // 5. 默认白色
    return Colors.cellDefault
  }

  /**
   * 数字的文字颜色
   */
  private getTextColor(): ResourceColor {
    if (this.cellData.isError) return Colors.textError
    if (this.cellData.isGiven) return Colors.textGiven
    return Colors.textUser
  }

  /**
   * 构建笔记 3×3 微型排列
   */
  @Builder
  NotesGrid() {
    Grid() {
      ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], (n: number) => {
        GridItem() {
          Text(this.getNoteText(n))
            .fontSize(Sizes.noteFont)
            .fontColor(this.getNoteColor(n))
            .textAlign(TextAlign.Center)
            .decoration(this.getNoteDecoration(n))
            .width('100%')
            .height('100%')
            .backgroundColor(this.getNoteBackgroundColor(n))
            .borderRadius(2)
        }
      })
    }
    .columnsTemplate('1fr 1fr 1fr')
    .rowsTemplate('1fr 1fr 1fr')
    .width('100%')
    .height('100%')
  }

  /**
   * Check if note digit n conflicts with any peer's filled value
   */
  private isNoteConflicting(n: number): boolean {
    if (this.allCells.length === 0) return false
    const idx = this.cellData.index
    for (const peerIdx of PEERS[idx]) {
      if (this.allCells[peerIdx].value === n) {
        return true
      }
    }
    return false
  }

  private getNoteText(n: number): string {
    const state = getNoteState(this.cellData.notes, n)
    if (state === NoteState.EMPTY) return ''
    return n.toString()
  }

  private getNoteColor(n: number): ResourceColor {
    const state = getNoteState(this.cellData.notes, n)
    if (state === NoteState.EMPTY) return Colors.textNote
    if (state === NoteState.ELIMINATED) return Colors.textNoteElim
    // Check if this note conflicts with a peer's filled value
    if (this.isNoteConflicting(n)) return Colors.textError
    // Highlight note digit matching the selected cell's value
    if (this.selectedValue !== 0 && n === this.selectedValue) return Colors.textNoteHighlight
    return Colors.textNote
  }

  private getNoteDecoration(n: number): TextDecorationOptions {
    const state = getNoteState(this.cellData.notes, n)
    if (state === NoteState.ELIMINATED) {
      return { type: TextDecorationType.LineThrough, color: Colors.textNoteElim }
    }
    return { type: TextDecorationType.None }
  }

  /**
   * 笔记数字的背景色（同数字高亮用背景色更醒目）
   */
  private getNoteBackgroundColor(n: number): ResourceColor {
    const state = getNoteState(this.cellData.notes, n)
    if (state === NoteState.EMPTY) return Color.Transparent
    if (this.selectedValue !== 0 && n === this.selectedValue) return Colors.noteHighlightBg
    return Color.Transparent
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.getCellBgColor())
        .animation({ duration: 150 })

      if (this.cellData.value !== 0) {
        // 显示数字
        Text(this.cellData.value.toString())
          .fontSize(Sizes.givenFont)
          .fontColor(this.getTextColor())
          .fontWeight(this.cellData.isGiven ? FontWeight.Bold : FontWeight.Normal)
          .textAlign(TextAlign.Center)
          .scale({ x: this.fillScale, y: this.fillScale })
          .translate({ x: this.errorShakeX })
          .onAppear(() => {
            this.triggerFillAnimation()
          })
      } else if (this.cellData.notes !== 0) {
        // 显示笔记
        this.NotesGrid()
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.onCellClick()
    })
    .onMouse((event: MouseEvent) => {
      if (event.button === MouseButton.Left || event.button === MouseButton.None) {
        if (event.action === MouseAction.Press) {
          this.onMouseDragSelect('start')
        } else if (event.action === MouseAction.Move) {
          this.onMouseDragSelect('move')
        } else if (event.action === MouseAction.Release) {
          this.onMouseDragSelect('end')
        }
      }
    })
    .onAppear(() => {
      this.lastValue = this.cellData.value
      this.lastError = this.cellData.isError
    })
  }

  /**
   * 填数弹跳动画：先放大再回弹
   */
  private triggerFillAnimation(): void {
    // 只在新填入数字时触发（非初始加载）
    if (this.cellData.isGiven) return

    this.fillScale = 0.5
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.fillScale = 1.15
    })
    setTimeout(() => {
      animateTo({ duration: 150, curve: Curve.EaseInOut }, () => {
        this.fillScale = 1.0
      })
    }, 200)
  }

  /**
   * 错误抖动动画
   */
  triggerErrorShake(): void {
    const shakeSequence: number[] = [6, -6, 4, -4, 2, -2, 0]
    let delay = 0
    for (const offset of shakeSequence) {
      setTimeout(() => {
        animateTo({ duration: 50, curve: Curve.Linear }, () => {
          this.errorShakeX = offset
        })
      }, delay)
      delay += 50
    }
  }
}
