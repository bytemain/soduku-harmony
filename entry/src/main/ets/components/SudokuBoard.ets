/**
 * SudokuBoard.ets — 棋盘组件（9×9 网格）
 *
 * 3×3 宫格嵌套 3×3 单元格。
 * 宫格粗线 2vp，单元格细线 0.5vp。
 *
 * 参考：Doc 05 §② 棋盘
 */
import { CellData } from '../models/CellData'
import { Colors, Sizes, BOX_SIZE, GRID_SIZE } from '../constants/GameConstants'
import { SudokuCell } from './SudokuCell'

@Component
export struct SudokuBoard {
  @ObjectLink cells: ArrayWrapper
  selectedValue: number = 0
  onCellClick: (index: number) => void = () => {}

  build() {
    Column() {
      Grid() {
        // 9 个宫格（0-8）
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (boxIndex: number) => {
          GridItem() {
            this.BoxGrid(boxIndex)
          }
          .borderWidth(Sizes.cellBorderBold / 2)
          .borderColor(Colors.cellBorderBold)
        })
      }
      .columnsTemplate('1fr 1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr')
      .width(Sizes.boardSize)
      .height(Sizes.boardSize)
      .backgroundColor(Colors.cellBorderBold)
      .borderWidth(Sizes.cellBorderBold)
      .borderColor(Colors.cellBorderBold)
    }
  }

  @Builder
  BoxGrid(boxIndex: number) {
    Grid() {
      ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (cellInBox: number) => {
        GridItem() {
          SudokuCell({
            cellData: this.cells.data[this.getCellIndex(
              Math.floor(boxIndex / BOX_SIZE) * BOX_SIZE,
              (boxIndex % BOX_SIZE) * BOX_SIZE,
              cellInBox
            )],
            selectedValue: this.selectedValue,
            onCellClick: () => {
              this.onCellClick(this.getCellIndex(
                Math.floor(boxIndex / BOX_SIZE) * BOX_SIZE,
                (boxIndex % BOX_SIZE) * BOX_SIZE,
                cellInBox
              ))
            },
          })
        }
        .borderWidth(Sizes.cellBorderThin)
        .borderColor(Colors.cellBorderThin)
      })
    }
    .columnsTemplate('1fr 1fr 1fr')
    .rowsTemplate('1fr 1fr 1fr')
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.boardBg)
  }

  /**
   * 由宫左上角 (boxRow, boxCol) + 宫内偏移 cellInBox(0-8) 算出一维索引
   */
  private getCellIndex(boxRow: number, boxCol: number, cellInBox: number): number {
    const r = boxRow + Math.floor(cellInBox / BOX_SIZE)
    const c = boxCol + (cellInBox % BOX_SIZE)
    return r * GRID_SIZE + c
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
