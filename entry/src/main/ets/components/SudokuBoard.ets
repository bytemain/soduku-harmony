/**
 * SudokuBoard.ets — 棋盘组件（9×9 网格）
 *
 * 3×3 宫格嵌套 3×3 单元格。
 * 宫格粗线 2vp，单元格细线 0.5vp。
 *
 * 参考：Doc 05 §② 棋盘
 */
import { CellData } from '../models/CellData'
import { Colors, Sizes, BOX_ROWS, BOX_COLS, BOX_COUNT_COLS, BOX_COUNT_ROWS,
  GRID_SIZE, DIGITS, GRID_INDICES, BOX_INDICES, BOX_CELL_INDICES } from '../constants/GameConstants'
import { SudokuCell } from './SudokuCell'

@Component
export struct SudokuBoard {
  @ObjectLink cells: ArrayWrapper
  @Prop selectedValue: number = 0
  @Prop hintFocusIndex: number = -1
  @Prop showCoordinates: boolean = false
  onCellClick: (index: number) => void = () => {}
  /** 鼠标拖拽多选：action = 'start' | 'move' | 'end' */
  onMouseDragSelect: (index: number, action: string) => void = () => {}
  /** 触摸长按拖拽多选：action = 'start' | 'move' | 'end' */
  onTouchDragSelect: (index: number, action: string) => void = () => {}
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

  build() {
    Column() {
      // 顶部列号 — 坐标轴开启时显示
      if (this.showCoordinates) {
        Row() {
          Blank().width(18)
          ForEach(DIGITS, (index: number) => {
            Text(index.toString())
              .fontSize(11)
              .fontColor(Colors.subtitleText)
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
                  .fontColor(Colors.subtitleText)
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
            })
          }
          .width(18)
          .height(this.boardHeight > 0 ? this.boardHeight : undefined)
        }

        // 棋盘主体
        Grid() {
          ForEach(BOX_INDICES, (boxIndex: number) => {
            GridItem() {
              this.BoxGrid(boxIndex)
            }
            .borderWidth(Sizes.cellBorderBold / 2)
            .borderColor(Colors.cellBorderBold)
          })
        }
        .columnsTemplate('1fr '.repeat(BOX_COUNT_COLS).trim())
        .rowsTemplate('1fr '.repeat(BOX_COUNT_ROWS).trim())
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(Colors.cellBorderBold)
        .borderWidth(Sizes.cellBorderBold)
        .borderColor(Colors.cellBorderBold)
        .onAreaChange((_old, newArea) => {
          this.boardHeight = newArea.height as number
          this.boardWidth = newArea.width as number
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
            cellData: this.cells.data[this.getCellIndex(
              Math.floor(boxIndex / BOX_COUNT_COLS) * BOX_ROWS,
              (boxIndex % BOX_COUNT_COLS) * BOX_COLS,
              cellInBox
            )],
            selectedValue: this.selectedValue,
            isHintTarget: this.hintFocusIndex === this.getCellIndex(
              Math.floor(boxIndex / BOX_COUNT_COLS) * BOX_ROWS,
              (boxIndex % BOX_COUNT_COLS) * BOX_COLS,
              cellInBox
            ),
            allCells: this.cells.data,
            onCellClick: () => {
              this.onCellClick(this.getCellIndex(
                Math.floor(boxIndex / BOX_COUNT_COLS) * BOX_ROWS,
                (boxIndex % BOX_COUNT_COLS) * BOX_COLS,
                cellInBox
              ))
            },
            onMouseDragSelect: (action: string) => {
              this.onMouseDragSelect(this.getCellIndex(
                Math.floor(boxIndex / BOX_COUNT_COLS) * BOX_ROWS,
                (boxIndex % BOX_COUNT_COLS) * BOX_COLS,
                cellInBox
              ), action)
            },
          })
        }
        .borderWidth(Sizes.cellBorderThin)
        .borderColor(Colors.cellBorderThin)
      })
    }
    .columnsTemplate('1fr '.repeat(BOX_COLS).trim())
    .rowsTemplate('1fr '.repeat(BOX_ROWS).trim())
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.boardBg)
  }

  /**
   * 由宫左上角 (boxRow, boxCol) + 宫内偏移 cellInBox 算出一维索引
   */
  private getCellIndex(boxRow: number, boxCol: number, cellInBox: number): number {
    const r = boxRow + Math.floor(cellInBox / BOX_COLS)
    const c = boxCol + (cellInBox % BOX_COLS)
    return r * GRID_SIZE + c
  }

  /**
   * 根据触摸坐标（相对于 Grid）计算命中的格子索引
   * 返回 -1 表示超出棋盘范围
   */
  private hitTestCellIndex(x: number, y: number): number {
    if (this.boardWidth <= 0 || this.boardHeight <= 0) return -1
    const cellW = this.boardWidth / GRID_SIZE
    const cellH = this.boardHeight / GRID_SIZE
    const col = Math.floor(x / cellW)
    const row = Math.floor(y / cellH)
    if (row < 0 || row >= GRID_SIZE || col < 0 || col >= GRID_SIZE) return -1
    return row * GRID_SIZE + col
  }

  /**
   * 处理棋盘触摸事件 — 实现长按拖拽多选
   * Down: 记录起始格，启动 400ms 长按计时
   * Move: 长按触发后，经过的格子自动加入多选
   * Up/Cancel: 清理状态
   */
  private handleBoardTouch(event: TouchEvent): void {
    const touch = event.touches[0]
    if (touch === undefined) return

    if (event.type === TouchType.Down) {
      const index = this.hitTestCellIndex(touch.x, touch.y)
      this.touchStartIndex = index
      this.lastTouchCellIndex = index
      this.isTouchLongPressed = false

      // 启动长按计时器
      this.touchTimerId = setTimeout(() => {
        this.isTouchLongPressed = true
        if (this.touchStartIndex >= 0) {
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

    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      // 清理计时器
      if (this.touchTimerId !== -1) {
        clearTimeout(this.touchTimerId)
        this.touchTimerId = -1
      }

      if (this.isTouchLongPressed) {
        this.onTouchDragSelect(this.lastTouchCellIndex, 'end')
      }

      this.isTouchLongPressed = false
      this.touchStartIndex = -1
      this.lastTouchCellIndex = -1
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
