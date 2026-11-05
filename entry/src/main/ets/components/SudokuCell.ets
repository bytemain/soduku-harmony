/**
 * SudokuCell.ets — 单元格组件
 *
 * 按父棋盘分配的实际格子大小渲染，短横屏时文字随容器缩小。4 种显示模式：
 *   - 给定数字（深绿衬线墨印）
 *   - 用户填入（墨绿衬线）
 *   - 错误数字（红色）
 *   - 笔记（3×3 微型排列）
 *
 * 使用 @ObjectLink 引用 CellData，属性变化自动刷新。
 *
 * 参考：Doc 05 §② 单元格
 */
import { CellData, getNoteState, NoteState } from '../models/CellData'
import { BoardCellDecoration, createEmptyBoardCellDecoration } from '../models/BoardDecoration'
import { ColorsConfig, getThemeColors, Sizes, DIGITS, BOX_COLS, BOX_ROWS } from '../constants/GameConstants'
import { PEERS } from '../utils/Topology'
import { PAPER_DIGIT_FONT_FAMILY, PAPER_DIGIT_GIVEN_WEIGHT, PAPER_DIGIT_USER_WEIGHT } from '../constants/Typography'

@Component
export struct SudokuCell {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  @ObjectLink @Watch('onCellDataChanged') cellData: CellData
  /** 选中格的 value（用于同数字高亮判断） */
  @Prop selectedValue: number = 0
  @Prop showErrors: boolean = true
  /** 是否为当前提示目标格 */
  @Prop isHintTarget: boolean = false
  /** 变种棋盘装饰（如 Killer 笼子边界/角标），由外部策略预计算 */
  @Prop decoration: BoardCellDecoration = createEmptyBoardCellDecoration()
  /** 全部 81 个格子的引用，用于笔记冲突检测 */
  @Prop allCells: CellData[] = []
  onCellClick: () => void = () => {}
  /** 鼠标拖拽多选回调 action: 'start' | 'move' | 'end' */
  onMouseDragSelect: (action: string) => void = () => {}

  // 数字只做很轻的墨色收敛，不改变位置、大小或网格几何。
  @State private inkOpacity: number = 1
  private animationReady: boolean = false
  private boundCell: CellData | null = null
  private lastValue: number = 0

  aboutToAppear(): void {
    // 初次呈现/存档恢复直接显示，不能让已填数字同时播放入场动画。
    this.boundCell = this.cellData
    this.lastValue = this.cellData.value
    this.animationReady = true
  }

  aboutToDisappear(): void {
    this.animationReady = false
    this.boundCell = null
    // 无延迟任务或完成回调；节点销毁后不会继续写入组件状态。
  }

  private onCellDataChanged(): void {
    const value = this.cellData.value
    // ForEach 复用格子但换成另一盘数据时，也应直接显示。
    if (!this.animationReady || this.boundCell !== this.cellData) {
      this.boundCell = this.cellData
      this.lastValue = value
      this.inkOpacity = 1
      return
    }
    // flags/notes/高亮会频繁变化，只有本格 value 变化才响应。
    if (value === this.lastValue) return
    this.lastValue = value

    const animateInk = value !== 0 && !this.cellData.isGiven
    const uiContext = this.getUIContext()
    // 零时长重置上一笔，不追加定时器；快速覆盖数字也不会排队弹跳。
    uiContext.animateTo({ duration: 0 }, () => {
      this.inkOpacity = animateInk ? 0.88 : 1
    })
    if (animateInk) {
      uiContext.animateTo({ duration: 90, curve: Curve.EaseOut }, () => {
        this.inkOpacity = 1
      })
    }
  }

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
      return this.getPalette().cellSelected
    }
    // 2. 错误格 → 浅红
    if (this.showErrors && this.cellData.isError) {
      return this.getPalette().cellError
    }
    // 3. 同数字 → 浅绿（棋盘上所有与 selectedValue 相同数字的格子）
    if (this.cellData.value !== 0
      && this.selectedValue !== 0 && this.cellData.value === this.selectedValue) {
      return this.getPalette().cellSameNumber
    }
    // 4. 同行列宫 / 变种约束高亮
    if (this.cellData.isHighlighted) {
      if (this.decoration.highlightBackgroundColor.length > 0) {
        return this.decoration.highlightBackgroundColor
      }
      return this.getPalette().cellHighlight
    }
    // 5. 变种底纹（如 Sudoku-X 对角线）
    if (this.decoration.backgroundColor.length > 0) {
      return this.decoration.backgroundColor
    }
    // 6. 默认白色
    return this.getPalette().cellDefault
  }

  /**
   * 数字的文字颜色
   */
  private getTextColor(): ResourceColor {
    if (this.showErrors && this.cellData.isError) return this.getPalette().textError
    if (this.cellData.isGiven) return this.getPalette().textGiven
    return this.getPalette().textUser
  }

  /**
   * 构建笔记 3×3 微型排列
   */
  @Builder
  NotesGrid() {
    Grid() {
      ForEach(DIGITS, (n: number) => {
        GridItem() {
          Text(this.getNoteText(n))
            .fontSize(Sizes.noteFont)
            .minFontSize(1)
            .maxFontSize(Sizes.noteFont)
            .maxLines(1)
            .heightAdaptivePolicy(TextHeightAdaptivePolicy.LAYOUT_CONSTRAINT_FIRST)
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
    .columnsTemplate('1fr '.repeat(BOX_COLS).trim())
    .rowsTemplate('1fr '.repeat(BOX_ROWS).trim())
    .width('100%')
    .height('100%')
    // Killer 角标占据顶部区域，候选数从角标下方开始。
    .padding({ top: this.decoration.topLeftLabel.length > 0 ? '28%' : 0 })
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
    if (state === NoteState.EMPTY) return this.getPalette().textNote
    if (state === NoteState.ELIMINATED) return this.getPalette().textNoteElim
    // Check if this note conflicts with a peer's filled value
    if (this.showErrors && this.isNoteConflicting(n)) return this.getPalette().textError
    // Highlight note digit matching the selected cell's value
    if (this.selectedValue !== 0 && n === this.selectedValue) return this.getPalette().textNoteHighlight
    return this.getPalette().textNote
  }

  private getNoteDecoration(n: number): TextDecorationOptions {
    const state = getNoteState(this.cellData.notes, n)
    if (state === NoteState.ELIMINATED) {
      return { type: TextDecorationType.LineThrough, color: this.getPalette().textNoteElim }
    }
    return { type: TextDecorationType.None }
  }

  /**
   * 笔记数字的背景色（同数字高亮用背景色更醒目）
   */
  private getNoteBackgroundColor(n: number): ResourceColor {
    const state = getNoteState(this.cellData.notes, n)
    // 只有 ACTIVE 笔记才需要背景高亮，ELIMINATED（划线划掉的）不需要
    if (state !== NoteState.ACTIVE) return Color.Transparent
    if (this.selectedValue !== 0 && n === this.selectedValue) return this.getPalette().noteHighlightBg
    return Color.Transparent
  }

  build() {
    Stack() {
      // 背景层：所有 cell 统一画网格线（gridBorder=-1 的边画灰线，=0 的边不画）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.getCellBgColor())
        .border({
          width: {
            left: this.decoration.gridBorder.left < 0 ? Sizes.cellBorderThin : 0,
            top: this.decoration.gridBorder.top < 0 ? Sizes.cellBorderThin : 0,
            right: this.decoration.gridBorder.right < 0 ? Sizes.cellBorderThin : 0,
            bottom: this.decoration.gridBorder.bottom < 0 ? Sizes.cellBorderThin : 0,
          },
          color: this.getPalette().cellBorderThin,
        })

      // 装饰边框层：在网格线之上叠加 cage/region 的彩色边框
      if (this.hasKillerBorder()) {
        Column() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.getCellBgColor())
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.getPalette().killerCageBorder)
        .padding({
          left: this.decoration.border.left,
          top: this.decoration.border.top,
          right: this.decoration.border.right,
          bottom: this.decoration.border.bottom,
        })
      }

      // L 形内凹角补丁：两个正交方向都是同组但对角不是时，
      // padding 无法覆盖角落缝隙，用小方块填补
      if (this.decoration.cornerPatches.topLeft) {
        Stack() {
          Column()
            .width(this.getCornerPatchSize())
            .height(this.getCornerPatchSize())
            .backgroundColor(this.getPalette().killerCageBorder)
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.TopStart)
        .hitTestBehavior(HitTestMode.None)
      }
      if (this.decoration.cornerPatches.topRight) {
        Stack() {
          Column()
            .width(this.getCornerPatchSize())
            .height(this.getCornerPatchSize())
            .backgroundColor(this.getPalette().killerCageBorder)
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.TopEnd)
        .hitTestBehavior(HitTestMode.None)
      }
      if (this.decoration.cornerPatches.bottomLeft) {
        Stack() {
          Column()
            .width(this.getCornerPatchSize())
            .height(this.getCornerPatchSize())
            .backgroundColor(this.getPalette().killerCageBorder)
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.BottomStart)
        .hitTestBehavior(HitTestMode.None)
      }
      if (this.decoration.cornerPatches.bottomRight) {
        Stack() {
          Column()
            .width(this.getCornerPatchSize())
            .height(this.getCornerPatchSize())
            .backgroundColor(this.getPalette().killerCageBorder)
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.BottomEnd)
        .hitTestBehavior(HitTestMode.None)
      }

      if (this.decoration.topLeftLabel.length > 0) {
        Text(this.decoration.topLeftLabel)
          .fontSize(8)
          .minFontSize(1)
          .maxFontSize(8)
          .maxLines(1)
          .heightAdaptivePolicy(TextHeightAdaptivePolicy.LAYOUT_CONSTRAINT_FIRST)
          .fontColor(this.getPalette().killerCageLabel)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Start)
          .width('50%')
          .height('25%')
          .position({ x: '5%', y: '3%' })
          .backgroundColor(this.getPalette().boardBg)
          .hitTestBehavior(HitTestMode.None)
      }

      // 保持同一个文字节点，首次填入和覆盖已有数字使用相同反馈。
      Text(this.cellData.value !== 0 ? this.cellData.value.toString() : '')
        .fontFamily(PAPER_DIGIT_FONT_FAMILY)
        .fontFeature('"lnum" 1, "tnum" 1')
        .fontSize(Sizes.givenFont)
        .minFontSize(1)
        .maxFontSize(Sizes.givenFont)
        .maxLines(1)
        .heightAdaptivePolicy(TextHeightAdaptivePolicy.LAYOUT_CONSTRAINT_FIRST)
        // 数字尺寸固定，保留格内留白供字形与边框呼吸。
        .width('86%')
        .height('86%')
        .fontColor(this.getTextColor())
        .fontWeight(this.cellData.isGiven ? PAPER_DIGIT_GIVEN_WEIGHT : PAPER_DIGIT_USER_WEIGHT,
          { enableVariableFontWeight: true })
        .textAlign(TextAlign.Center)
        .opacity(this.inkOpacity)
      if (this.cellData.value === 0 && this.cellData.notes !== 0) {
        // 显示笔记
        this.NotesGrid()
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
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
  }

  private hasKillerBorder(): boolean {
    return this.decoration.border.left > 0 || this.decoration.border.top > 0 ||
      this.decoration.border.right > 0 || this.decoration.border.bottom > 0
  }

  /**
   * 角落补丁尺寸：取 decoration border 各方向的最大值。
   * 对于 Killer 是 1.5vp，Jigsaw 是 2vp。
   */
  private getCornerPatchSize(): number {
    return Math.max(
      this.decoration.border.left,
      this.decoration.border.top,
      this.decoration.border.right,
      this.decoration.border.bottom
    )
  }

}
