import { GRID_SIZE, TOTAL_CELLS } from '../constants/GameConstants'
import { KillerCage } from './VariantConfig'

const KILLER_CAGE_BORDER_WIDTH = 1.5
const JIGSAW_REGION_BORDER_WIDTH = 2

/**
 * 单元格装饰边框配置。
 * 未来如需支持 Jigsaw / Thermo / Arrow 等变种，可继续扩展更多视觉层字段。
 */
export class CellDecorationBorder {
  left: number = 0
  top: number = 0
  right: number = 0
  bottom: number = 0

  constructor(left: number = 0, top: number = 0, right: number = 0, bottom: number = 0) {
    this.left = left
    this.top = top
    this.right = right
    this.bottom = bottom
  }
}

/**
 * 棋盘单元格的通用装饰模型。
 * 棋盘/格子组件只消费该抽象，不感知具体变种类型。
 */
export class BoardCellDecoration {
  topLeftLabel: string = ''
  border: CellDecorationBorder = new CellDecorationBorder()

  constructor(topLeftLabel: string = '', border: CellDecorationBorder = new CellDecorationBorder()) {
    this.topLeftLabel = topLeftLabel
    this.border = border
  }
}

/**
 * Killer 专用装饰实现。
 * 通过继承保留扩展点，未来其他变种可提供自己的装饰子类。
 */
export class KillerCellDecoration extends BoardCellDecoration {
  constructor(topLeftLabel: string = '', border: CellDecorationBorder = new CellDecorationBorder()) {
    super(topLeftLabel, border)
  }
}

export function createEmptyBoardCellDecoration(): BoardCellDecoration {
  return new BoardCellDecoration()
}

export function createEmptyBoardDecorations(totalCells: number = TOTAL_CELLS): BoardCellDecoration[] {
  const decorations: BoardCellDecoration[] = []
  for (let i = 0; i < totalCells; i++) {
    decorations.push(createEmptyBoardCellDecoration())
  }
  return decorations
}

function buildCageIndexByCell(cages: KillerCage[]): number[] {
  const cageIndexByCell: number[] = []
  for (let i = 0; i < TOTAL_CELLS; i++) {
    cageIndexByCell.push(-1)
  }

  for (let cageIndex = 0; cageIndex < cages.length; cageIndex++) {
    const cage = cages[cageIndex]
    for (const cellIndex of cage.cells) {
      if (cellIndex >= 0 && cellIndex < TOTAL_CELLS) {
        cageIndexByCell[cellIndex] = cageIndex
      }
    }
  }

  return cageIndexByCell
}

/**
 * 基于 Killer 笼子数据构建棋盘视觉装饰。
 * 组件层仅消费返回的通用装饰数组，不再直接依赖 Killer cage 结构。
 */
export function buildKillerBoardDecorations(cages: KillerCage[]): BoardCellDecoration[] {
  const decorations = createEmptyBoardDecorations()
  if (cages.length === 0) {
    return decorations
  }

  const cageIndexByCell = buildCageIndexByCell(cages)
  for (let cellIndex = 0; cellIndex < TOTAL_CELLS; cellIndex++) {
    const cageIndex = cageIndexByCell[cellIndex]
    if (cageIndex < 0) {
      continue
    }

    const cage = cages[cageIndex]
    const row = Math.floor(cellIndex / GRID_SIZE)
    const col = cellIndex % GRID_SIZE
    const left = col > 0 && cageIndexByCell[cellIndex - 1] === cageIndex ? 0 : KILLER_CAGE_BORDER_WIDTH
    const top = row > 0 && cageIndexByCell[cellIndex - GRID_SIZE] === cageIndex ? 0 : KILLER_CAGE_BORDER_WIDTH
    const right = col < GRID_SIZE - 1 && cageIndexByCell[cellIndex + 1] === cageIndex ? 0 : KILLER_CAGE_BORDER_WIDTH
    const bottom = row < GRID_SIZE - 1 && cageIndexByCell[cellIndex + GRID_SIZE] === cageIndex
      ? 0 : KILLER_CAGE_BORDER_WIDTH
    const border = new CellDecorationBorder(left, top, right, bottom)
    const label = cage.cells.length > 0 && cage.cells[0] === cellIndex && cage.sum > 0
      ? cage.sum.toString() : ''
    decorations[cellIndex] = new KillerCellDecoration(label, border)
  }

  return decorations
}

/**
 * 基于 Jigsaw regionMap 构建不规则宫边界装饰。
 */
export function buildJigsawBoardDecorations(regionMap: number[]): BoardCellDecoration[] {
  const decorations = createEmptyBoardDecorations()
  if (regionMap.length < TOTAL_CELLS) {
    return decorations
  }

  for (let cellIndex = 0; cellIndex < TOTAL_CELLS; cellIndex++) {
    const currentRegion = regionMap[cellIndex]
    const row = Math.floor(cellIndex / GRID_SIZE)
    const col = cellIndex % GRID_SIZE
    const left = col === 0 || regionMap[cellIndex - 1] !== currentRegion ? JIGSAW_REGION_BORDER_WIDTH : 0
    const top = row === 0 || regionMap[cellIndex - GRID_SIZE] !== currentRegion ? JIGSAW_REGION_BORDER_WIDTH : 0
    const right = col === GRID_SIZE - 1 || regionMap[cellIndex + 1] !== currentRegion ? JIGSAW_REGION_BORDER_WIDTH : 0
    const bottom = row === GRID_SIZE - 1 || regionMap[cellIndex + GRID_SIZE] !== currentRegion
      ? JIGSAW_REGION_BORDER_WIDTH : 0
    decorations[cellIndex] = new BoardCellDecoration('', new CellDecorationBorder(left, top, right, bottom))
  }

  return decorations
}
