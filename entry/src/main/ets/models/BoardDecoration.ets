import { Colors, GRID_SIZE, TOTAL_CELLS } from '../constants/GameConstants'
import { KillerCage } from './VariantConfig'
import { isOnAntiDiagonal, isOnMainDiagonal } from '../utils/VariantTopology'

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
 * L 形拐角补丁标记。
 * 当 cage/region 在某个 cell 形成 L 形拐角时，对角位置会出现断裂缝隙。
 * 通过在该 cell 的对应角落绘制小方块来填补。
 */
export class CellCornerPatches {
  topLeft: boolean = false
  topRight: boolean = false
  bottomLeft: boolean = false
  bottomRight: boolean = false

  constructor(topLeft: boolean = false, topRight: boolean = false,
    bottomLeft: boolean = false, bottomRight: boolean = false) {
    this.topLeft = topLeft
    this.topRight = topRight
    this.bottomLeft = bottomLeft
    this.bottomRight = bottomRight
  }

  hasAny(): boolean {
    return this.topLeft || this.topRight || this.bottomLeft || this.bottomRight
  }
}

/**
 * 棋盘单元格的通用装饰模型。
 * 棋盘/格子组件只消费该抽象，不感知具体变种类型。
 */
export class BoardCellDecoration {
  topLeftLabel: string = ''
  border: CellDecorationBorder = new CellDecorationBorder()
  /**
   * 控制单元格网格线的每边宽度。
   * -1 表示使用默认网格线宽度（cellBorderThin），0 表示隐藏该边网格线。
   * 用于在同一笼子/宫内的相邻格子之间隐藏多余的网格线。
   */
  gridBorder: CellDecorationBorder = new CellDecorationBorder(-1, -1, -1, -1)
  /**
   * L 形拐角补丁。在 cage/region 形成 L 形拐角的位置标记需要补色的角落。
   */
  cornerPatches: CellCornerPatches = new CellCornerPatches()
  backgroundColor: string = ''
  highlightBackgroundColor: string = ''

  constructor(topLeftLabel: string = '', border: CellDecorationBorder = new CellDecorationBorder(),
    backgroundColor: string = '', highlightBackgroundColor: string = '',
    gridBorder: CellDecorationBorder = new CellDecorationBorder(-1, -1, -1, -1),
    cornerPatches: CellCornerPatches = new CellCornerPatches()) {
    this.topLeftLabel = topLeftLabel
    this.border = border
    this.backgroundColor = backgroundColor
    this.highlightBackgroundColor = highlightBackgroundColor
    this.gridBorder = gridBorder
    this.cornerPatches = cornerPatches
  }
}

/**
 * Killer 专用装饰实现。
 * 通过继承保留扩展点，未来其他变种可提供自己的装饰子类。
 */
export class KillerCellDecoration extends BoardCellDecoration {
  constructor(topLeftLabel: string = '', border: CellDecorationBorder = new CellDecorationBorder(),
    gridBorder: CellDecorationBorder = new CellDecorationBorder(-1, -1, -1, -1),
    cornerPatches: CellCornerPatches = new CellCornerPatches()) {
    super(topLeftLabel, border, '', '', gridBorder, cornerPatches)
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
 * 计算 L 形拐角补丁。
 * 规则：当 cell 的某条边有 border（cage 边界），且垂直方向的邻居是同 group，
 * 但对角方向的邻居不是同 group 时，对角位置会出现缝隙，需要在当前 cell 补丁。
 *
 * 例：cell 有 right border，bottom 方向是同 cage（无 border），但右下对角 cell 不在 cage 中
 * → cell 的 bottomRight 角需要补丁。
 */
function computeCornerPatches(cellIndex: number, groupByCell: number[], borderWidth: number): CellCornerPatches {
  const myGroup = groupByCell[cellIndex]
  if (myGroup < 0) {
    return new CellCornerPatches()
  }

  const row = Math.floor(cellIndex / GRID_SIZE)
  const col = cellIndex % GRID_SIZE

  // 邻居是否同组的快速判断
  const hasLeft = col > 0 && groupByCell[cellIndex - 1] === myGroup
  const hasRight = col < GRID_SIZE - 1 && groupByCell[cellIndex + 1] === myGroup
  const hasTop = row > 0 && groupByCell[cellIndex - GRID_SIZE] === myGroup
  const hasBottom = row < GRID_SIZE - 1 && groupByCell[cellIndex + GRID_SIZE] === myGroup

  // 对角邻居是否同组
  const hasTopLeft = row > 0 && col > 0 && groupByCell[cellIndex - GRID_SIZE - 1] === myGroup
  const hasTopRight = row > 0 && col < GRID_SIZE - 1 && groupByCell[cellIndex - GRID_SIZE + 1] === myGroup
  const hasBottomLeft = row < GRID_SIZE - 1 && col > 0 && groupByCell[cellIndex + GRID_SIZE - 1] === myGroup
  const hasBottomRight = row < GRID_SIZE - 1 && col < GRID_SIZE - 1 &&
    groupByCell[cellIndex + GRID_SIZE + 1] === myGroup

  // 内凹角补丁：两个正交方向都是同组（无 border），但对角方向不是同组时，
  // padding 无法覆盖角落的对角缝隙，需要补丁。
  // 例：cell 的上方、右方都是同 cage，但右上对角不是 → 右上角需要补丁。
  const topLeft = !hasTopLeft && hasTop && hasLeft
  const topRight = !hasTopRight && hasTop && hasRight
  const bottomLeft = !hasBottomLeft && hasBottom && hasLeft
  const bottomRight = !hasBottomRight && hasBottom && hasRight

  return new CellCornerPatches(topLeft, topRight, bottomLeft, bottomRight)
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
    // 笼子格的所有边都隐藏网格线：
    // - 同笼相邻（border=0）：不需要任何分隔线
    // - 笼子边界（border>0）：装饰边框替代网格线，不应叠加
    const gridBorder = new CellDecorationBorder(0, 0, 0, 0)
    const cornerPatches = computeCornerPatches(cellIndex, cageIndexByCell, KILLER_CAGE_BORDER_WIDTH)
    const label = cage.cells.length > 0 && cage.cells[0] === cellIndex && cage.sum > 0
      ? cage.sum.toString() : ''
    decorations[cellIndex] = new KillerCellDecoration(label, border, gridBorder, cornerPatches)
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
    // 宫格内所有边都隐藏网格线：装饰边框替代网格线
    const gridBorder = new CellDecorationBorder(0, 0, 0, 0)
    const cornerPatches = computeCornerPatches(cellIndex, regionMap, JIGSAW_REGION_BORDER_WIDTH)
    decorations[cellIndex] = new BoardCellDecoration('', new CellDecorationBorder(left, top, right, bottom),
      '', '', gridBorder, cornerPatches)
  }

  return decorations
}

/**
 * 基于 Sudoku-X 对角线规则构建棋盘视觉装饰。
 * 对角线格提供淡色底纹；当选中的格位于对角线上时，整条关联对角线使用更强高亮。
 */
export function buildDiagonalBoardDecorations(selectedIndex: number = -1): BoardCellDecoration[] {
  const decorations = createEmptyBoardDecorations()
  const hasSelectedCell = selectedIndex >= 0 && selectedIndex < TOTAL_CELLS
  const selectedOnMain = hasSelectedCell && isOnMainDiagonal(selectedIndex, GRID_SIZE)
  const selectedOnAnti = hasSelectedCell && isOnAntiDiagonal(selectedIndex, GRID_SIZE)

  for (let cellIndex = 0; cellIndex < TOTAL_CELLS; cellIndex++) {
    const onMain = isOnMainDiagonal(cellIndex, GRID_SIZE)
    const onAnti = isOnAntiDiagonal(cellIndex, GRID_SIZE)
    if (!onMain && !onAnti) {
      continue
    }

    const isActive = (selectedOnMain && onMain) || (selectedOnAnti && onAnti)
    decorations[cellIndex] = new BoardCellDecoration(
      '',
      new CellDecorationBorder(),
      Colors.cellDiagonal,
      isActive ? Colors.cellDiagonalHighlight : ''
    )
  }

  return decorations
}
