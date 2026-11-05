/** 历史节点的只读棋盘，不使用当前游戏的全局拓扑或输入事件。 */
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'
import { PAPER_DIGIT_FONT_FAMILY, PAPER_DIGIT_GIVEN_WEIGHT, PAPER_DIGIT_USER_WEIGHT } from '../constants/Typography'
import { GameSaveData, CellSerialized, CageSerialized } from '../models/GameSaveData'

@Component
export struct JournalBoardPreview {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false
  @Prop save: GameSaveData = new GameSaveData()
  @State private boardWidth: number = 280

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  private gridSize(): number {
    return this.save.gridSize === 4 || this.save.gridSize === 6 ? this.save.gridSize : 9
  }

  private boxRows(): number { return this.gridSize() === 9 ? 3 : 2 }
  private boxCols(): number { return this.gridSize() / this.boxRows() }

  private digits(): number[] {
    const digits: number[] = []
    for (let digit = 1; digit <= this.gridSize(); digit++) digits.push(digit)
    return digits
  }

  private region(index: number): number {
    if (this.save.variantType === 'jigsaw' && this.save.jigsawRegionMap.length === this.save.cells.length) {
      return this.save.jigsawRegionMap[index]
    }
    return Math.floor(Math.floor(index / this.gridSize()) / this.boxRows()) * this.boxRows() +
      Math.floor((index % this.gridSize()) / this.boxCols())
  }

  private rightBorder(index: number): number {
    return (index + 1) % this.gridSize() === 0 || this.region(index) !== this.region(index + 1) ? 1 : 0.4
  }

  private bottomBorder(index: number): number {
    return index >= this.save.cells.length - this.gridSize() || this.region(index) !== this.region(index + this.gridSize()) ? 1 : 0.4
  }

  private cageIndex(index: number): number {
    return this.save.killerCages.findIndex((cage: CageSerialized): boolean => cage.cells.includes(index))
  }

  private cageSum(index: number): string {
    for (const cage of this.save.killerCages) {
      let first = this.save.cells.length
      for (const cellIndex of cage.cells) first = Math.min(first, cellIndex)
      if (first === index) return cage.sum.toString()
    }
    return ''
  }

  private sameCage(index: number, other: number): boolean {
    if (other < 0 || other >= this.save.cells.length) return false
    const cage = this.cageIndex(index)
    return cage >= 0 && cage === this.cageIndex(other)
  }

  private diagonal(index: number): boolean {
    const row = Math.floor(index / this.gridSize())
    const col = index % this.gridSize()
    return this.save.variantType === 'diagonal' && (row === col || row + col === this.gridSize() - 1)
  }

  @Builder
  private PreviewCell(cell: CellSerialized, index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      if (cell.value > 0) {
        Text(cell.value.toString())
          .width('100%')
          .height('100%')
          .textAlign(TextAlign.Center)
          .fontFamily(PAPER_DIGIT_FONT_FAMILY)
          .fontFeature('"lnum" 1, "tnum" 1')
          .fontSize(Math.min(30, this.boardWidth / this.gridSize() * 0.58))
          .fontWeight((cell.flags & 1) !== 0 ? PAPER_DIGIT_GIVEN_WEIGHT : PAPER_DIGIT_USER_WEIGHT,
            { enableVariableFontWeight: true })
          .fontColor((cell.flags & 1) !== 0 ? this.getPalette().textGiven : this.getPalette().textUser)
      } else {
        Grid() {
          ForEach(this.digits(), (digit: number) => {
            GridItem() {
              Text(((cell.notes >> ((digit - 1) * 2)) & 3) !== 0 ? digit.toString() : '')
                .fontSize(Math.max(6, Math.min(10, this.boardWidth / this.gridSize() / this.boxCols() * 0.7)))
                .fontColor(this.getPalette().textNote)
                .decoration({ type: ((cell.notes >> ((digit - 1) * 2)) & 3) === 2 ? TextDecorationType.LineThrough : TextDecorationType.None })
            }
          }, (digit: number) => digit.toString())
        }
        .columnsTemplate('1fr '.repeat(this.boxCols()).trim())
        .rowsTemplate('1fr '.repeat(this.boxRows()).trim())
        .width('100%')
        .height('100%')
        .padding(2)
      }
      if (this.save.variantType === 'killer') {
        Column() {}
          .width('100%')
          .height('100%')
          .border({ width: {
            left: index % this.gridSize() === 0 || !this.sameCage(index, index - 1) ? 0.7 : 0,
            right: (index + 1) % this.gridSize() === 0 || !this.sameCage(index, index + 1) ? 0.7 : 0,
            top: !this.sameCage(index, index - this.gridSize()) ? 0.7 : 0,
            bottom: !this.sameCage(index, index + this.gridSize()) ? 0.7 : 0,
          }, color: this.getPalette().subtitleText, style: BorderStyle.Dashed })
          .padding(2)
        Text(this.cageSum(index))
          .fontSize(Math.max(6, Math.min(9, this.boardWidth / this.gridSize() * 0.24)))
          .fontColor(this.getPalette().titleText)
          .margin({ left: 2, top: 1 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.diagonal(index) ? this.getPalette().cellDiagonal : this.getPalette().boardBg)
    .border({ width: {
      left: index % this.gridSize() === 0 ? 1 : 0,
      top: index < this.gridSize() ? 1 : 0,
      right: this.rightBorder(index), bottom: this.bottomBorder(index),
    }, color: this.getPalette().cellBorderBold })
    .accessibilityText($r('app.string.journal_preview_cell', cell.row + 1, cell.col + 1, cell.value > 0 ? cell.value.toString() : ''))
  }

  build() {
    Grid() {
      ForEach(this.save.cells, (cell: CellSerialized, index: number) => {
        GridItem() { this.PreviewCell(cell, index) }
      }, (cell: CellSerialized) => `${cell.row}:${cell.col}`)
    }
    .columnsTemplate('1fr '.repeat(this.gridSize()).trim())
    .rowsTemplate('1fr '.repeat(this.gridSize()).trim())
    .width('100%')
    .aspectRatio(1)
    .onAreaChange((_oldArea: Area, area: Area) => { this.boardWidth = Number(area.width) })
  }
}
