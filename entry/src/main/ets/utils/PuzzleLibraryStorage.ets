/**
 * PuzzleLibraryStorage.ets — 题库与关卡进度持久化
 *
 * 为后续“题库/选关”功能提供底层存储能力：
 * - 题库索引
 * - 题库题目列表
 * - 每道题的独立进度
 * - 当前活跃题（用于继续游玩）
 *
 * 存储方式与 GameStorage / StatsStorage 保持一致，均基于 Preferences。
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { PuzzleEntry, PuzzleLibrary, PuzzleProgress, createDefaultProgress } from '../models/PuzzleLibrary'

const STORE_NAME = 'sudoku_puzzle_library'
const KEY_LIBRARY_INDEX = 'puzzle_libraries'
const KEY_ACTIVE_PUZZLE = 'active_puzzle'

export class ActivePuzzlePointer {
  libraryId: string = ''
  puzzleIndex: number = 0

  constructor(libraryId: string = '', puzzleIndex: number = 0) {
    this.libraryId = libraryId
    this.puzzleIndex = puzzleIndex
  }
}

export class PuzzleProgressData implements PuzzleProgress {
  status: 'new' | 'in_progress' | 'completed' = 'new'
  startedAt?: number
  completedAt?: number
  elapsedSeconds: number = 0
  errorCount: number = 0
  cellStates?: string
  percentage: number = 0

  constructor(progress?: PuzzleProgress | null) {
    if (!progress) {
      return
    }
    this.status = progress.status
    this.startedAt = progress.startedAt
    this.completedAt = progress.completedAt
    this.elapsedSeconds = progress.elapsedSeconds
    this.errorCount = progress.errorCount
    this.cellStates = progress.cellStates
    this.percentage = progress.percentage
  }
}

function getStore(context: Context): preferences.Preferences {
  return preferences.getPreferencesSync(context, { name: STORE_NAME })
}

export function getLibraryPuzzlesKey(libraryId: string): string {
  return `library_${libraryId}_puzzles`
}

export function getLibraryProgressKey(libraryId: string): string {
  return `library_${libraryId}_progress`
}

export function createPuzzleProgressData(progress?: PuzzleProgress | null): PuzzleProgressData {
  if (!progress) {
    return new PuzzleProgressData(createDefaultProgress())
  }
  return new PuzzleProgressData(progress)
}

export function applyProgressMapToPuzzles(
  puzzles: PuzzleEntry[],
  progressMap: Record<string, PuzzleProgressData>,
): PuzzleEntry[] {
  return puzzles.map((puzzle: PuzzleEntry): PuzzleEntry => {
    const progress = progressMap[`${puzzle.index}`]
    if (!progress) {
      return puzzle
    }
    const updatedPuzzle: PuzzleEntry = {
      index: puzzle.index,
      puzzle81: puzzle.puzzle81,
      solution81: puzzle.solution81,
      difficulty: puzzle.difficulty,
      metadata: puzzle.metadata,
      progress: createPuzzleProgressData(progress),
    }
    return updatedPuzzle
  })
}

export async function saveLibraryIndex(context: Context, libraries: PuzzleLibrary[]): Promise<void> {
  try {
    const store = getStore(context)
    store.putSync(KEY_LIBRARY_INDEX, JSON.stringify(libraries))
    await store.flush()
  } catch (e) {
    console.error('[PuzzleLibraryStorage] saveLibraryIndex failed:', JSON.stringify(e))
  }
}

export function loadLibraryIndex(context: Context): PuzzleLibrary[] {
  try {
    const store = getStore(context)
    const json = store.getSync(KEY_LIBRARY_INDEX, '') as string
    if (!json) {
      return []
    }
    return JSON.parse(json) as PuzzleLibrary[]
  } catch (e) {
    console.error('[PuzzleLibraryStorage] loadLibraryIndex failed:', JSON.stringify(e))
    return []
  }
}

export async function saveLibraryPuzzles(
  context: Context,
  libraryId: string,
  puzzles: PuzzleEntry[],
): Promise<void> {
  try {
    const store = getStore(context)
    store.putSync(getLibraryPuzzlesKey(libraryId), JSON.stringify(puzzles))
    await store.flush()
  } catch (e) {
    console.error('[PuzzleLibraryStorage] saveLibraryPuzzles failed:', JSON.stringify(e))
  }
}

export function loadLibraryPuzzles(context: Context, libraryId: string): PuzzleEntry[] {
  try {
    const store = getStore(context)
    const json = store.getSync(getLibraryPuzzlesKey(libraryId), '') as string
    if (!json) {
      return []
    }
    return JSON.parse(json) as PuzzleEntry[]
  } catch (e) {
    console.error('[PuzzleLibraryStorage] loadLibraryPuzzles failed:', JSON.stringify(e))
    return []
  }
}

export async function savePuzzleProgress(
  context: Context,
  libraryId: string,
  puzzleIndex: number,
  progress: PuzzleProgress,
): Promise<void> {
  try {
    const store = getStore(context)
    const progressKey = getLibraryProgressKey(libraryId)
    const progressMap = loadLibraryProgressMap(context, libraryId)
    progressMap[`${puzzleIndex}`] = createPuzzleProgressData(progress)
    store.putSync(progressKey, JSON.stringify(progressMap))
    await store.flush()
  } catch (e) {
    console.error('[PuzzleLibraryStorage] savePuzzleProgress failed:', JSON.stringify(e))
  }
}

export function loadPuzzleProgress(
  context: Context,
  libraryId: string,
  puzzleIndex: number,
): PuzzleProgress | null {
  try {
    const progressMap = loadLibraryProgressMap(context, libraryId)
    const progress = progressMap[`${puzzleIndex}`]
    return progress ? createPuzzleProgressData(progress) : null
  } catch (e) {
    console.error('[PuzzleLibraryStorage] loadPuzzleProgress failed:', JSON.stringify(e))
    return null
  }
}

export function loadLibraryProgressMap(
  context: Context,
  libraryId: string,
): Record<string, PuzzleProgressData> {
  try {
    const store = getStore(context)
    const json = store.getSync(getLibraryProgressKey(libraryId), '') as string
    if (!json) {
      const emptyMap: Record<string, PuzzleProgressData> = {}
      return emptyMap
    }
    return JSON.parse(json) as Record<string, PuzzleProgressData>
  } catch (e) {
    console.error('[PuzzleLibraryStorage] loadLibraryProgressMap failed:', JSON.stringify(e))
    const emptyMap: Record<string, PuzzleProgressData> = {}
    return emptyMap
  }
}

export function loadLibraryPuzzlesWithProgress(context: Context, libraryId: string): PuzzleEntry[] {
  const puzzles = loadLibraryPuzzles(context, libraryId)
  const progressMap = loadLibraryProgressMap(context, libraryId)
  return applyProgressMapToPuzzles(puzzles, progressMap)
}

export async function saveActivePuzzle(
  context: Context,
  libraryId: string,
  puzzleIndex: number,
): Promise<void> {
  try {
    const store = getStore(context)
    const activePuzzle = new ActivePuzzlePointer(libraryId, puzzleIndex)
    store.putSync(KEY_ACTIVE_PUZZLE, JSON.stringify(activePuzzle))
    await store.flush()
  } catch (e) {
    console.error('[PuzzleLibraryStorage] saveActivePuzzle failed:', JSON.stringify(e))
  }
}

export function loadActivePuzzle(context: Context): ActivePuzzlePointer | null {
  try {
    const store = getStore(context)
    const json = store.getSync(KEY_ACTIVE_PUZZLE, '') as string
    if (!json) {
      return null
    }
    const parsed = JSON.parse(json) as ActivePuzzlePointer
    return new ActivePuzzlePointer(parsed.libraryId, parsed.puzzleIndex)
  } catch (e) {
    console.error('[PuzzleLibraryStorage] loadActivePuzzle failed:', JSON.stringify(e))
    return null
  }
}

export async function clearActivePuzzle(context: Context): Promise<void> {
  try {
    const store = getStore(context)
    store.deleteSync(KEY_ACTIVE_PUZZLE)
    await store.flush()
  } catch (e) {
    console.error('[PuzzleLibraryStorage] clearActivePuzzle failed:', JSON.stringify(e))
  }
}
