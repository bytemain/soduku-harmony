/**
 * 教学专用4×4棋盘：不使用正式局的全局拓扑、GameState或存档。
 * 候选由行、列、宫约束计算；填数只清理相关格中的同值候选。
 */
import { GRID_4x4 } from '../models/VariantConfig'

export const TUTORIAL_GRID = GRID_4x4
export const TUTORIAL_FIRST_CELL: number = 0
export const TUTORIAL_NOTE_CELL: number = 8
export const TUTORIAL_FINAL_CELL: number = 4

export function createTutorialValues(): number[] {
  return [0, 2, 3, 4, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
}

export function createTutorialNotes(): number[][] {
  const notes: number[][] = []
  for (let index = 0; index < TUTORIAL_GRID.totalCells; index++) {
    notes.push([])
  }
  return notes
}

export function tutorialPeers(index: number): number[] {
  const row = Math.floor(index / TUTORIAL_GRID.gridSize)
  const col = index % TUTORIAL_GRID.gridSize
  const peers: number[] = []
  for (let other = 0; other < TUTORIAL_GRID.totalCells; other++) {
    if (other === index) continue
    const otherRow = Math.floor(other / TUTORIAL_GRID.gridSize)
    const otherCol = other % TUTORIAL_GRID.gridSize
    if (row === otherRow || col === otherCol ||
      (Math.floor(row / TUTORIAL_GRID.boxRows) === Math.floor(otherRow / TUTORIAL_GRID.boxRows) &&
      Math.floor(col / TUTORIAL_GRID.boxCols) === Math.floor(otherCol / TUTORIAL_GRID.boxCols))) {
      peers.push(other)
    }
  }
  return peers
}

export function tutorialCandidates(values: number[], index: number): number[] {
  if (values[index] !== 0) return []
  const used = new Set<number>()
  for (const peer of tutorialPeers(index)) {
    if (values[peer] !== 0) used.add(values[peer])
  }
  return TUTORIAL_GRID.digits.filter((digit: number): boolean => !used.has(digit))
}

export function fillTutorialCandidates(values: number[]): number[][] {
  return values.map((_value: number, index: number): number[] => tutorialCandidates(values, index))
}

export class TutorialFillResult {
  values: number[]
  notes: number[][]
  clearedCells: number[]

  constructor(values: number[], notes: number[][], clearedCells: number[]) {
    this.values = values
    this.notes = notes
    this.clearedCells = clearedCells
  }
}

export function fillTutorialDigit(values: number[], notes: number[][],
  index: number, digit: number): TutorialFillResult {
  const nextValues = values.slice()
  const nextNotes = notes.map((items: number[]): number[] => items.slice())
  const cleared: number[] = []
  if (!tutorialCandidates(values, index).includes(digit)) {
    return new TutorialFillResult(nextValues, nextNotes, cleared)
  }
  nextValues[index] = digit
  nextNotes[index] = []
  for (const peer of tutorialPeers(index)) {
    if (nextValues[peer] === 0 && nextNotes[peer].includes(digit)) {
      nextNotes[peer] = nextNotes[peer].filter((candidate: number): boolean => candidate !== digit)
      cleared.push(peer)
    }
  }
  return new TutorialFillResult(nextValues, nextNotes, cleared)
}
