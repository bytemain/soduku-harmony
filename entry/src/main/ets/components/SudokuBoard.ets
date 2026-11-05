/**
 * SudokuBoard.ets — 棋盘组件（9×9 网格）
 *
 * 3×3 宫格嵌套 3×3 单元格。
 * 宫格粗线 2vp，单元格细线 0.5vp。
 *
 * 参考：Doc 05 §② 棋盘
 */
import { CellData } from '../models/CellData'
import { BoardCellDecoration, createEmptyBoardCellDecoration } from '../models/BoardDecoration'
import { VariantType } from '../models/VariantConfig'
import { ColorsConfig, getThemeColors, Sizes, BOX_ROWS, BOX_COLS, BOX_COUNT_COLS, BOX_COUNT_ROWS,
  GRID_SIZE, DIGITS, BOX_INDICES, BOX_CELL_INDICES } from '../constants/GameConstants'
import { SudokuCell } from './SudokuCell'
import { COORDINATE_GUTTER, hitTestBoardCell } from '../utils/AdaptiveLayout'

@Component
export struct SudokuBoard {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  @ObjectLink cells: ArrayWrapper
  @Prop selectedValue: number = 0
  @Prop showErrors: boolean = true
  @Prop hintFocusIndex: number = -1
  @Prop showCoordinates: boolean = false
  @Prop boardDecorations: BoardCellDecoration[] = []
  @Prop currentVariantType: VariantType = VariantType.STANDARD
  onCellClick: (index: number) => void = () => {}
  /** 鼠标拖拽多选：action = 'start' | 'move' | 'end' */
  onMouseDragSelect: (index: number, action: string) => void = () => {}
  /** 触摸长按拖拽多选：action = 'start' | 'move' | 'end' */
  onTouchDragSelect: (index: number, action: string) => void = () => {}
  /** 长按多选期间由外层暂停滚动，避免拖选和 Scroll 同时消费移动。 */
  onDragSelectionActiveChange: (active: boolean) => void = () => {}
  onKeyboardInput: (keyCode: number) => void = () => {}

  @State private boardHeight: number = 0
  @State private boardWidth: number = 0
  /** 触摸长按计时器 */
  private touchTimerId: number = -1
  /** 是否已触发长按 */
  private isTouchLongPressed: boolean = false
  /** 触摸起始格索引 */
  private touchStartIndex: number = -1
  /** 上一次触摸命中的格索引（避免重复回调） */
  private lastTouchCellIndex: number = -1

  aboutToDisappear(): void {
    this.finishBoardTouch()
  }

  build() {
    Column() {
      // 顶部列号 — 坐标轴开启时显示
      if (this.showCoordinates) {
        Row() {
          Blank().width(COORDINATE_GUTTER)
          ForEach(DIGITS, (index: number) => {
            Text(index.toString())
              .fontSize(11)
              .fontColor(this.getPalette().subtitleText)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
          })
        }
        .width('100%')
        .height(16)
      }

      Row() {
        // 左侧行号
        if (this.showCoordinates) {
          Column() {
            ForEach(DIGITS, (index: number) => {
              Row() {
                Text(index.toString())
                  .fontSize(11)
                  .fontColor(this.getPalette().subtitleText)
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
            })
          }
          .width(COORDINATE_GUTTER)
          .height(this.boardHeight > 0 ? this.boardHeight : undefined)
        }

        // 棋盘主体
        Grid() {
          ForEach(BOX_INDICES, (boxIndex: number) => {
            GridItem() {
              this.BoxGrid(boxIndex)
            }
            .borderWidth(this.getBoxBorderWidth())
            .borderColor(this.getBoxBorderColor())
          })
        }
        .columnsTemplate('1fr '.repeat(BOX_COUNT_COLS).trim())
        .rowsTemplate('1fr '.repeat(BOX_COUNT_ROWS).trim())
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.getInnerGridBorderColor())
        .borderWidth(Sizes.cellBorderBold)
        .borderColor(this.getPalette().cellBorderBold)
        .onAreaChange((_old, newArea) => {
          const width = Number(newArea.width)
          const height = Number(newArea.height)
          // 折叠/旋转期间取消旧坐标系上的长按；新触摸只使用最终 Grid 的实测大小。
          if (Math.abs(width - this.boardWidth) > 0.5 || Math.abs(height - this.boardHeight) > 0.5) {
            this.finishBoardTouch()
            this.boardHeight = height
            this.boardWidth = width
          }
        })
        .onTouch((event: TouchEvent) => {
          this.handleBoardTouch(event)
        })
      }
    }
    .width('100%')
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      if (event.type === KeyType.Down) {
        this.onKeyboardInput(event.keyCode)
      }
    })
  }

  @Builder
  BoxGrid(boxIndex: number) {
    Grid() {
      ForEach(BOX_CELL_INDICES, (cellInBox: number) => {
        GridItem() {
          SudokuCell({
            showErrors: this.showErrors,
            cellData: this.cells.data[this.getBoxCellIndex(boxIndex, cellInBox)],
            selectedValue: this.selectedValue,
            isHintTarget: this.hintFocusIndex === this.getBoxCellIndex(boxIndex, cellInBox),
            decoration: this.getCellDecoration(this.getBoxCellIndex(boxIndex, cellInBox)),
            allCells: this.cells.data,
            onCellClick: () => {
              this.onCellClick(this.getBoxCellIndex(boxIndex, cellInBox))
            },
            onMouseDragSelect: (action: string) => {
              this.onMouseDragSelect(this.getBoxCellIndex(boxIndex, cellInBox), action)
            },
          })
        }
      })
    }
    .columnsTemplate('1fr '.repeat(BOX_COLS).trim())
    .rowsTemplate('1fr '.repeat(BOX_ROWS).trim())
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().boardBg)
  }

  /**
   * 由宫左上角 (boxRow, boxCol) + 宫内偏移 cellInBox 算出一维索引
   */
  private getCellIndex(boxRow: number, boxCol: number, cellInBox: number): number {
    const r = boxRow + Math.floor(cellInBox / BOX_COLS)
    const c = boxCol + (cellInBox % BOX_COLS)
    return r * GRID_SIZE + c
  }

  private getBoxCellIndex(boxIndex: number, cellInBox: number): number {
    return this.getCellIndex(
      Math.floor(boxIndex / BOX_COUNT_COLS) * BOX_ROWS,
      (boxIndex % BOX_COUNT_COLS) * BOX_COLS,
      cellInBox
    )
  }

  /**
   * 取指定格子的预计算装饰。
   * 未来其他变种只需替换装饰生成策略，无需修改棋盘组件。
   */
  private getCellDecoration(index: number): BoardCellDecoration {
    if (index >= 0 && index < this.boardDecorations.length) {
      return this.boardDecorations[index]
    }
    return createEmptyBoardCellDecoration()
  }

  private getBoxBorderWidth(): number {
    if (this.currentVariantType === VariantType.JIGSAW) {
      return Sizes.cellBorderThin / 2
    }
    return Sizes.cellBorderBold / 2
  }

  private getBoxBorderColor(): string {
    if (this.currentVariantType === VariantType.JIGSAW) {
      return this.getPalette().cellBorderThin
    }
    return this.getPalette().cellBorderBold
  }

  private getInnerGridBorderColor(): string {
    if (this.currentVariantType === VariantType.JIGSAW) {
      return this.getPalette().cellBorderThin
    }
    return this.getPalette().cellBorderBold
  }

  /**
   * 根据触摸坐标（相对于 Grid）计算命中的格子索引
   * 返回 -1 表示超出棋盘范围
   */
  private hitTestCellIndex(x: number, y: number): number {
    return hitTestBoardCell(x, y, this.boardWidth, this.boardHeight, GRID_SIZE, Sizes.cellBorderBold)
  }

  private finishBoardTouch(): void {
    if (this.touchTimerId !== -1) {
      clearTimeout(this.touchTimerId)
      this.touchTimerId = -1
    }
    if (this.isTouchLongPressed && this.lastTouchCellIndex >= 0) {
      this.onTouchDragSelect(this.lastTouchCellIndex, 'end')
    }
    if (this.isTouchLongPressed) this.onDragSelectionActiveChange(false)
    this.isTouchLongPressed = false
    this.touchStartIndex = -1
    this.lastTouchCellIndex = -1
  }

  /**
   * 处理棋盘触摸事件 — 实现长按拖拽多选
   * Down: 记录起始格，启动 400ms 长按计时
   * Move: 长按触发后，经过的格子自动加入多选
   * Up/Cancel: 清理状态
   */
  private handleBoardTouch(event: TouchEvent): void {
    // Up/Cancel 可能没有 touches；必须先清理，否则滚动/折叠会留下长按计时器。
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.finishBoardTouch()
      return
    }
    const touch = event.touches[0]
    if (touch === undefined) return

    if (event.type === TouchType.Down) {
      this.finishBoardTouch()
      const index = this.hitTestCellIndex(touch.x, touch.y)
      if (index < 0) return
      this.touchStartIndex = index
      this.lastTouchCellIndex = index
      this.isTouchLongPressed = false

      // 启动长按计时器
      this.touchTimerId = setTimeout(() => {
        this.touchTimerId = -1
        this.isTouchLongPressed = true
        if (this.touchStartIndex >= 0) {
          this.onDragSelectionActiveChange(true)
          this.onTouchDragSelect(this.touchStartIndex, 'start')
          this.lastTouchCellIndex = this.touchStartIndex
        }
      }, 400) as number

    } else if (event.type === TouchType.Move) {
      const index = this.hitTestCellIndex(touch.x, touch.y)

      if (!this.isTouchLongPressed) {
        // 长按还没触发，如果移动距离太远就取消长按
        if (index !== this.touchStartIndex) {
          clearTimeout(this.touchTimerId)
          this.touchTimerId = -1
        }
        return
      }

      // 长按已触发，滑动到新格子时加入多选
      if (index >= 0 && index !== this.lastTouchCellIndex) {
        this.lastTouchCellIndex = index
        this.onTouchDragSelect(index, 'move')
      }

    }
  }
}

/**
 * 包装 CellData[] 以便 @Observed + @ObjectLink 能检测数组变化。
 * ArkUI 的 @ObjectLink 只能接收 @Observed class 的实例，
 * 不能直接接收原始数组。
 */
@Observed
export class ArrayWrapper {
  data: CellData[]

  constructor(data: CellData[]) {
    this.data = data
  }
}
