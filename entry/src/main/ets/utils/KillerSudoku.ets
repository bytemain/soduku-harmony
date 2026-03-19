import { GRID_SIZE } from '../constants/GameConstants'
import { KillerCage, VariantType } from '../models/VariantConfig'

const KILLER_ROW_PATTERNS: number[][] = [
  [2, 3, 4],
  [3, 2, 4],
  [4, 2, 3],
]

export function normalizeVariantType(raw: string | undefined): VariantType {
  if (raw === VariantType.DIAGONAL) {
    return VariantType.DIAGONAL
  }
  if (raw === VariantType.KILLER) {
    return VariantType.KILLER
  }
  return VariantType.STANDARD
}

export function createDefaultKillerLayout(gridSize: number = GRID_SIZE): KillerCage[] {
  const cages: KillerCage[] = []
  if (gridSize !== 9) {
    return cages
  }

  for (let row = 0; row < gridSize; row++) {
    const pattern = KILLER_ROW_PATTERNS[row % KILLER_ROW_PATTERNS.length]
    let colStart = 0
    for (const width of pattern) {
      const cells: number[] = []
      for (let offset = 0; offset < width; offset++) {
        cells.push(row * gridSize + colStart + offset)
      }
      const cage: KillerCage = {
        cells: cells,
        sum: 0,
      }
      cages.push(cage)
      colStart += width
    }
  }

  return cages
}

export function buildKillerCagesFromSolution(solution: number[]): KillerCage[] {
  const layout = createDefaultKillerLayout()
  const cages: KillerCage[] = []

  for (const cage of layout) {
    let sum = 0
    for (const cellIndex of cage.cells) {
      if (cellIndex < solution.length) {
        sum += solution[cellIndex]
      }
    }
    const solvedCage: KillerCage = {
      cells: cage.cells.slice(),
      sum: sum,
    }
    cages.push(solvedCage)
  }

  return cages
}
