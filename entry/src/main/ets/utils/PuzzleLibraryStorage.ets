/**
 * PuzzleLibraryStorage.ets — 题库与进度持久化
 *
 * 使用 @ohos.data.preferences 管理：
 * - 题库索引 (puzzle_libraries)
 * - 每题库的题目列表 (lib_{id}_puzzles)
 * - 每题库的进度数据 (lib_{id}_progress)
 *
 * 参考：Doc 13 §5.2
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import {
  PuzzleLibrary,
  PuzzleEntry,
  PuzzleProgress,
  createDefaultProgress,
} from '../models/PuzzleLibrary'

const STORE_NAME = 'sudoku_puzzle_library'
const KEY_LIBRARIES = 'puzzle_libraries'

// ============================================================
// Preferences 实例获取
// ============================================================

function getStore(context: Context): preferences.Preferences {
  const options: preferences.Options = { name: STORE_NAME }
  return preferences.getPreferencesSync(context, options)
}

// ============================================================
// 题库索引 CRUD
// ============================================================

/**
 * 保存题库索引列表
 */
export async function saveLibraryIndex(
  context: Context,
  libraries: PuzzleLibrary[],
): Promise<void> {
  try {
    const store = getStore(context)
    store.putSync(KEY_LIBRARIES, JSON.stringify(libraries))
    await store.flush()
  } catch (e) {
    console.error('[PuzzleLibraryStorage] saveLibraryIndex failed:', JSON.stringify(e))
  }
}

/**
 * 加载题库索引列表
 */
export function loadLibraryIndex(context: Context): PuzzleLibrary[] {
  try {
    const store = getStore(context)
    const json = store.getSync(KEY_LIBRARIES, '') as string
    if (!json) return []
    return JSON.parse(json) as PuzzleLibrary[]
  } catch (e) {
    console.error('[PuzzleLibraryStorage] loadLibraryIndex failed:', JSON.stringify(e))
    return []
  }
}

/**
 * 添加一个题库到索引（去重）
 */
export async function addLibrary(
  context: Context,
  library: PuzzleLibrary,
): Promise<void> {
  const libraries = loadLibraryIndex(context)
  const existingIdx = libraries.findIndex((lib: PuzzleLibrary) => lib.id === library.id)
  if (existingIdx >= 0) {
    libraries[existingIdx] = library
  } else {
    libraries.push(library)
  }
  await saveLibraryIndex(context, libraries)
}

/**
 * 删除一个题库（连同题目和进度数据）
 */
export async function removeLibrary(
  context: Context,
  libraryId: string,
): Promise<void> {
  const libraries = loadLibraryIndex(context)
  const filtered = libraries.filter((lib: PuzzleLibrary) => lib.id !== libraryId)
  await saveLibraryIndex(context, filtered)
  // 清除题目和进度数据
  try {
    const store = getStore(context)
    store.deleteSync(puzzlesKey(libraryId))
    store.deleteSync(progressKey(libraryId))
    await store.flush()
  } catch (e) {
    console.error('[PuzzleLibraryStorage] removeLibrary cleanup failed:', JSON.stringify(e))
  }
}

// ============================================================
// 题目列表 CRUD
// ============================================================

function puzzlesKey(libraryId: string): string {
  return `lib_${libraryId}_puzzles`
}

/**
 * 保存题库的题目列表
 */
export async function saveLibraryPuzzles(
  context: Context,
  libraryId: string,
  puzzles: PuzzleEntry[],
): Promise<void> {
  try {
    const store = getStore(context)
    store.putSync(puzzlesKey(libraryId), JSON.stringify(puzzles))
    await store.flush()
  } catch (e) {
    console.error('[PuzzleLibraryStorage] saveLibraryPuzzles failed:', JSON.stringify(e))
  }
}

/**
 * 加载题库的题目列表
 */
export function loadLibraryPuzzles(
  context: Context,
  libraryId: string,
): PuzzleEntry[] {
  try {
    const store = getStore(context)
    const json = store.getSync(puzzlesKey(libraryId), '') as string
    if (!json) return []
    return JSON.parse(json) as PuzzleEntry[]
  } catch (e) {
    console.error('[PuzzleLibraryStorage] loadLibraryPuzzles failed:', JSON.stringify(e))
    return []
  }
}

// ============================================================
// 单题进度 CRUD
// ============================================================

function progressKey(libraryId: string): string {
  return `lib_${libraryId}_progress`
}

/** 进度映射的序列化结构 */
class ProgressMap {
  entries: ProgressMapEntry[] = []
  constructor() {}
}

class ProgressMapEntry {
  index: number = 0
  progress: PuzzleProgress = createDefaultProgress()
  constructor(index: number = 0, progress: PuzzleProgress = createDefaultProgress()) {
    this.index = index
    this.progress = progress
  }
}

/**
 * 保存单题进度
 */
export async function saveProgress(
  context: Context,
  libraryId: string,
  puzzleIndex: number,
  progress: PuzzleProgress,
): Promise<void> {
  try {
    const store = getStore(context)
    const json = store.getSync(progressKey(libraryId), '') as string
    let map: ProgressMap
    if (json) {
      map = JSON.parse(json) as ProgressMap
    } else {
      map = new ProgressMap()
    }
    // 更新或新增
    const existing = map.entries.findIndex((e: ProgressMapEntry) => e.index === puzzleIndex)
    if (existing >= 0) {
      map.entries[existing].progress = progress
    } else {
      const entry = new ProgressMapEntry(puzzleIndex, progress)
      map.entries.push(entry)
    }
    store.putSync(progressKey(libraryId), JSON.stringify(map))
    await store.flush()
  } catch (e) {
    console.error('[PuzzleLibraryStorage] saveProgress failed:', JSON.stringify(e))
  }
}

/**
 * 加载单题进度
 */
export function loadProgress(
  context: Context,
  libraryId: string,
  puzzleIndex: number,
): PuzzleProgress | null {
  try {
    const store = getStore(context)
    const json = store.getSync(progressKey(libraryId), '') as string
    if (!json) return null
    const map = JSON.parse(json) as ProgressMap
    const entry = map.entries.find((e: ProgressMapEntry) => e.index === puzzleIndex)
    return entry ? entry.progress : null
  } catch (e) {
    console.error('[PuzzleLibraryStorage] loadProgress failed:', JSON.stringify(e))
    return null
  }
}

/**
 * 批量加载题库所有进度
 */
export function batchLoadProgress(
  context: Context,
  libraryId: string,
): Map<number, PuzzleProgress> {
  const result = new Map<number, PuzzleProgress>()
  try {
    const store = getStore(context)
    const json = store.getSync(progressKey(libraryId), '') as string
    if (!json) return result
    const map = JSON.parse(json) as ProgressMap
    for (const entry of map.entries) {
      result.set(entry.index, entry.progress)
    }
  } catch (e) {
    console.error('[PuzzleLibraryStorage] batchLoadProgress failed:', JSON.stringify(e))
  }
  return result
}
