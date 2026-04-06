/**
 * BuiltinPuzzleLibrary.ets — 内置题库演示数据
 *
 * 先提供最小可见的题库 / 选关闭环：
 * - 首页进入题库页
 * - 题库页浏览少量内置关卡
 * - 选中关卡后沿用 importedPuzzle 流程进入 GamePage
 */
import { Context } from '@kit.AbilityKit'
import { Difficulty } from '../constants/GameConstants'
import { PuzzleEntry, PuzzleLibrary, createPuzzleEntry, createPuzzleLibrary } from '../models/PuzzleLibrary'
import { applyProgressMapToPuzzles, loadLibraryProgressMap } from './PuzzleLibraryStorage'

const BUILTIN_LIBRARY_ID = 'builtin-starter'

function createBuiltinStarterLibrary(): PuzzleLibrary {
  const options: { difficulty?: Difficulty; tags?: string[] } = {
    difficulty: Difficulty.EASY,
    tags: ['builtin', 'starter'],
  }
  return createPuzzleLibrary(
    BUILTIN_LIBRARY_ID,
    '入门题库',
    '先用少量内置关卡打通主页选关流程。',
    'builtin',
    '81string',
    3,
    options,
  )
}

export function getBuiltinPuzzleLibraries(): PuzzleLibrary[] {
  const libraries: PuzzleLibrary[] = []
  const starterLibrary = createBuiltinStarterLibrary()
  libraries.push(starterLibrary)
  return libraries
}

export function getBuiltinPuzzleEntries(libraryId: string): PuzzleEntry[] {
  if (libraryId !== BUILTIN_LIBRARY_ID) {
    const emptyEntries: PuzzleEntry[] = []
    return emptyEntries
  }

  const entries: PuzzleEntry[] = []
  const entry0 = createPuzzleEntry(
    0,
    '003020600900305001001806400008102900700000008006708200002609500800203009005010300',
    undefined,
    Difficulty.EASY,
  )
  const entry1 = createPuzzleEntry(
    1,
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    undefined,
    Difficulty.EASY,
  )
  const entry2 = createPuzzleEntry(
    2,
    '200080300060070084030500209000105408000000000402706000301007040720040060004010003',
    undefined,
    Difficulty.MEDIUM,
  )
  entries.push(entry0)
  entries.push(entry1)
  entries.push(entry2)
  return entries
}

export function getBuiltinPuzzleEntriesWithProgress(context: Context, libraryId: string): PuzzleEntry[] {
  const entries = getBuiltinPuzzleEntries(libraryId)
  const progressMap = loadLibraryProgressMap(context, libraryId)
  return applyProgressMapToPuzzles(entries, progressMap)
}

