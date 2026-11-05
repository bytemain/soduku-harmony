import { Difficulty } from '../constants/GameConstants'
import { GRID_9x9 } from '../models/VariantConfig'

const SIZE = GRID_9x9.gridSize
const CELLS = GRID_9x9.totalCells
const BOX = GRID_9x9.boxRows
const NOTE_MASK = (1 << SIZE) - 1
const MAX_UNDO = 100

export class WatchNavigationParams {
  difficulty: number = Difficulty.EASY
  resume: boolean = false
}

/** Watch sessions deliberately do not use the phone's mutable grid/topology. */
export class WatchSnapshot {
  values: number[] = []
  notes: number[] = []
}

export class WatchSaveData {
  version: number = 1
  givens: number[] = []
  solution: number[] = []
  values: number[] = []
  notes: number[] = []
  difficulty: number = Difficulty.EASY
  seconds: number = 0
  hints: number = 0
  undo: WatchSnapshot[] = []
}

function validNumbers(values: number[], min: number, max: number): boolean {
  return Array.isArray(values) && values.length === CELLS &&
    values.every((value: number) => Number.isInteger(value) && value >= min && value <= max)
}

function validBoard(values: number[], notes: number[], givens: number[]): boolean {
  if (!validNumbers(values, 0, SIZE) || !validNumbers(notes, 0, NOTE_MASK)) return false
  for (let i = 0; i < CELLS; i++) {
    if (givens[i] !== 0 && values[i] !== givens[i]) return false
    if (values[i] !== 0 && notes[i] !== 0) return false
  }
  return true
}

export function isValidWatchSave(data: WatchSaveData): boolean {
  if (!data || data.version !== 1 || !validNumbers(data.givens, 0, SIZE) ||
    !validNumbers(data.solution, 1, SIZE)) return false
  if (!Number.isInteger(data.difficulty) || data.difficulty < Difficulty.EASY ||
    data.difficulty > Difficulty.EVIL || !Number.isInteger(data.seconds) || data.seconds < 0 ||
    !Number.isInteger(data.hints) || data.hints < 0) return false
  for (let unit = 0; unit < SIZE; unit++) {
    let rowMask = 0, colMask = 0, boxMask = 0
    for (let offset = 0; offset < SIZE; offset++) {
      rowMask |= 1 << (data.solution[unit * SIZE + offset] - 1)
      colMask |= 1 << (data.solution[offset * SIZE + unit] - 1)
      const row = Math.floor(unit / BOX) * BOX + Math.floor(offset / BOX)
      const col = (unit % BOX) * BOX + offset % BOX
      boxMask |= 1 << (data.solution[row * SIZE + col] - 1)
    }
    if (rowMask !== NOTE_MASK || colMask !== NOTE_MASK || boxMask !== NOTE_MASK) return false
  }
  for (let i = 0; i < CELLS; i++) {
    if (data.givens[i] !== 0 && data.givens[i] !== data.solution[i]) return false
  }
  if (!validBoard(data.values, data.notes, data.givens) || !Array.isArray(data.undo) ||
    data.undo.length > MAX_UNDO) return false
  return data.undo.every((snapshot: WatchSnapshot) => snapshot !== null && snapshot !== undefined &&
    validBoard(snapshot.values, snapshot.notes, data.givens))
}

export function watchCellIndex(box: number, offset: number): number {
  const row = Math.floor(box / BOX) * BOX + Math.floor(offset / BOX)
  const col = (box % BOX) * BOX + offset % BOX
  return row * SIZE + col
}

export function watchBoxIndex(index: number): number {
  return Math.floor(Math.floor(index / SIZE) / BOX) * BOX + Math.floor((index % SIZE) / BOX)
}

export class WatchGameSession {
  data: WatchSaveData = new WatchSaveData()

  static create(puzzle: number[][], solution: number[][], difficulty: number): WatchGameSession | null {
    if (!Array.isArray(puzzle) || !Array.isArray(solution) || puzzle.length !== SIZE || solution.length !== SIZE) {
      return null
    }
    const data = new WatchSaveData()
    for (let row = 0; row < SIZE; row++) {
      if (!Array.isArray(puzzle[row]) || !Array.isArray(solution[row]) ||
        puzzle[row].length !== SIZE || solution[row].length !== SIZE) return null
      for (let col = 0; col < SIZE; col++) {
        data.givens.push(puzzle[row][col])
        data.values.push(puzzle[row][col])
        data.solution.push(solution[row][col])
        data.notes.push(0)
      }
    }
    data.difficulty = difficulty
    return WatchGameSession.restore(data)
  }

  static restore(data: WatchSaveData): WatchGameSession | null {
    if (!isValidWatchSave(data)) return null
    const session = new WatchGameSession()
    // JSON round trips produce plain data; no saved object methods are called.
    session.data = JSON.parse(JSON.stringify(data)) as WatchSaveData
    return session
  }

  private editable(index: number): boolean {
    return Number.isInteger(index) && index >= 0 && index < CELLS &&
      this.data.values.length === CELLS && this.data.givens[index] === 0
  }

  private remember(): void {
    const snapshot = new WatchSnapshot()
    snapshot.values = this.data.values.slice()
    snapshot.notes = this.data.notes.slice()
    this.data.undo.push(snapshot)
    if (this.data.undo.length > MAX_UNDO) this.data.undo.shift()
  }

  private isPeer(first: number, second: number): boolean {
    return Math.floor(first / SIZE) === Math.floor(second / SIZE) || first % SIZE === second % SIZE ||
      watchBoxIndex(first) === watchBoxIndex(second)
  }

  input(index: number, digit: number, noteMode: boolean): boolean {
    if (!this.editable(index) || !Number.isInteger(digit) || digit < 1 || digit > SIZE || this.isComplete()) return false
    if (noteMode) {
      if (this.data.values[index] !== 0) return false
      this.remember()
      this.data.notes[index] ^= 1 << (digit - 1)
    } else {
      if (this.data.values[index] === digit) return false
      this.remember()
      this.data.values[index] = digit
      this.data.notes[index] = 0
      for (let peer = 0; peer < CELLS; peer++) {
        if (peer !== index && this.isPeer(index, peer)) this.data.notes[peer] &= ~(1 << (digit - 1))
      }
    }
    return true
  }

  erase(index: number): boolean {
    if (!this.editable(index) || (this.data.values[index] === 0 && this.data.notes[index] === 0) || this.isComplete()) {
      return false
    }
    this.remember()
    this.data.values[index] = 0
    this.data.notes[index] = 0
    return true
  }

  undo(): boolean {
    const snapshot = this.data.undo.pop()
    if (!snapshot) return false
    this.data.values = snapshot.values.slice()
    this.data.notes = snapshot.notes.slice()
    return true
  }

  /** A hint explicitly fills a correct digit. It remains a normal undoable move. */
  hint(preferred: number): number {
    let index = preferred
    if (!this.editable(index) || this.data.values[index] === this.data.solution[index]) {
      index = this.data.values.findIndex((value: number, cell: number) => value !== this.data.solution[cell])
    }
    if (index < 0 || !this.input(index, this.data.solution[index], false)) return -1
    this.data.hints++
    return index
  }

  isComplete(): boolean {
    return this.data.values.length === CELLS &&
      this.data.values.every((value: number, index: number) => value === this.data.solution[index])
  }

  filledCount(): number {
    return this.data.values.filter((value: number) => value !== 0).length
  }
}
