import { CellSnapshot } from './GameHistory'

/** 序列化后的格子数据 */
export class CellSerialized {
  row: number = 0
  col: number = 0
  value: number = 0
  flags: number = 0
  notes: number = 0

  constructor(row: number = 0, col: number = 0, value: number = 0,
    flags: number = 0, notes: number = 0) {
    this.row = row
    this.col = col
    this.value = value
    this.flags = flags
    this.notes = notes
  }
}

/** 序列化后的笼子数据 */
export class CageSerialized {
  cells: number[] = []
  sum: number = 0

  constructor(cells: number[] = [], sum: number = 0) {
    this.cells = cells
    this.sum = sum
  }
}

/** 完整的存档结构 */
export class GameSaveData {
  /** 手机端分支日志指针；旧存档缺少这些字段仍可正常迁移。 */
  journalSessionId: string = ''
  journalNodeId: string = ''
  journalBranchId: string = ''
  cells: CellSerialized[] = []
  solution: number[] = []
  difficulty: number = 0
  elapsedSeconds: number = 0
  errorCount: number = 0
  isChallengeFailed: boolean = false
  selectedIndex: number = -1
  undoStack: CellSnapshot[][] = []
  redoStack: CellSnapshot[][] = []
  timestamp: number = 0
  seed: number = 0
  symmetry: string = ''
  /** 生成参数与实际评级分开保存，保证种子重现。 */
  generationDifficulty: number = 0
  libraryId: string = ''
  puzzleIndex: number = -1
  /** 棋盘大小（4/6/9），默认 9 */
  gridSize: number = 9
  /** 变种类型（standard/diagonal/jigsaw/killer），默认 standard */
  variantType: string = 'standard'
  /** Killer 笼子数据（仅 Killer 模式使用） */
  killerCages: CageSerialized[] = []
  /** Jigsaw 区域图（仅 Jigsaw 模式使用），长度 81 */
  jigsawRegionMap: number[] = []

  constructor() {}
}

/** 校验存档，不依赖上一局遗留的全局棋盘尺寸。 */
export function isValidGameSave(data: GameSaveData | null | undefined): boolean {
  if (!data || !Array.isArray(data.cells) || !Array.isArray(data.solution)) return false
  const size = data.gridSize ?? 9
  if (size !== 4 && size !== 6 && size !== 9) return false
  const total = size * size
  if (data.cells.length !== total || data.solution.length !== total) return false
  if (!Number.isInteger(data.selectedIndex) || data.selectedIndex < -1 || data.selectedIndex >= total) return false
  if (!Number.isInteger(data.difficulty) || data.difficulty < 1 || data.difficulty > 5) return false
  if (!Number.isFinite(data.elapsedSeconds) || data.elapsedSeconds < 0 ||
    !Number.isInteger(data.errorCount) || data.errorCount < 0) return false
  const variant = data.variantType ?? 'standard'
  if (variant !== 'standard' && variant !== 'diagonal' && variant !== 'jigsaw' && variant !== 'killer') return false
  if (variant !== 'standard' && size !== 9) return false
  let clues = 0
  for (let i = 0; i < total; i++) {
    const cell = data.cells[i]
    const solution = data.solution[i]
    if (!cell || cell.row !== Math.floor(i / size) || cell.col !== i % size) return false
    if (!Number.isInteger(solution) || solution < 1 || solution > size ||
      !Number.isInteger(cell.value) || cell.value < 0 || cell.value > size ||
      !Number.isInteger(cell.flags) || cell.flags < 0 ||
      !Number.isInteger(cell.notes) || cell.notes < 0 || cell.notes >= Math.pow(2, size * 2)) return false
    if ((cell.flags & 1) !== 0) {
      clues++
      if (cell.value !== solution) return false
    }
  }
  if (clues === 0) return false
  for (let r = 0; r < size; r++) {
    const row = new Set<number>()
    const col = new Set<number>()
    for (let c = 0; c < size; c++) {
      row.add(data.solution[r * size + c])
      col.add(data.solution[c * size + r])
    }
    if (row.size !== size || col.size !== size) return false
  }
  if (variant === 'jigsaw') {
    if (!Array.isArray(data.jigsawRegionMap) || data.jigsawRegionMap.length !== total) return false
    for (let region = 0; region < size; region++) {
      const digits = new Set<number>()
      let count = 0
      for (let i = 0; i < total; i++) {
        const id = data.jigsawRegionMap[i]
        if (!Number.isInteger(id) || id < 0 || id >= size) return false
        if (id === region) { digits.add(data.solution[i]); count++ }
      }
      if (count !== size || digits.size !== size) return false
    }
  } else {
    const boxRows = size === 9 ? 3 : 2
    const boxCols = size / boxRows
    for (let r = 0; r < size; r += boxRows) {
      for (let c = 0; c < size; c += boxCols) {
        const digits = new Set<number>()
        for (let dr = 0; dr < boxRows; dr++) {
          for (let dc = 0; dc < boxCols; dc++) digits.add(data.solution[(r + dr) * size + c + dc])
        }
        if (digits.size !== size) return false
      }
    }
  }
  if (variant === 'diagonal') {
    const main = new Set<number>()
    const anti = new Set<number>()
    for (let i = 0; i < size; i++) {
      main.add(data.solution[i * size + i])
      anti.add(data.solution[i * size + size - i - 1])
    }
    if (main.size !== size || anti.size !== size) return false
  }
  if (variant === 'killer') {
    if (!Array.isArray(data.killerCages) || data.killerCages.length === 0) return false
    const covered = new Set<number>()
    for (const cage of data.killerCages) {
      if (!cage || !Array.isArray(cage.cells) || cage.cells.length === 0) return false
      const digits = new Set<number>()
      let sum = 0
      for (const index of cage.cells) {
        if (!Number.isInteger(index) || index < 0 || index >= total || covered.has(index)) return false
        covered.add(index)
        digits.add(data.solution[index])
        sum += data.solution[index]
      }
      if (digits.size !== cage.cells.length || sum !== cage.sum) return false
    }
    if (covered.size !== total) return false
  }
  return true
}
