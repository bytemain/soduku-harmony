/**
 * GameStorage.ets — 游戏状态持久化
 *
 * 使用 @ohos.data.preferences 在退出时保存当前局面，
 * 下次进入时恢复。
 *
 * ArkTS 要求所有对象字面量必须对应 class，
 * 因此序列化/反序列化使用 class 实例。
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { CellSnapshot } from '../models/GameHistory'

const STORE_NAME = 'sudoku_game'
const KEY_SAVE = 'saved_game'

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

/** 完整的存档结构 */
export class GameSaveData {
  cells: CellSerialized[] = []
  solution: number[] = []
  difficulty: number = 0
  elapsedSeconds: number = 0
  errorCount: number = 0
  selectedIndex: number = -1
  undoStack: CellSnapshot[][] = []
  redoStack: CellSnapshot[][] = []
  timestamp: number = 0
  seed: number = 0
  symmetry: string = ''

  constructor() {}
}

/**
 * 获取 preferences 实例
 */
function getStore(context: Context): preferences.Preferences {
  const options: preferences.Options = { name: STORE_NAME }
  return preferences.getPreferencesSync(context, options)
}

/**
 * 保存游戏状态到 Preferences
 */
export async function saveGame(context: Context, data: GameSaveData): Promise<void> {
  try {
    const store = getStore(context)
    const json = JSON.stringify(data)
    store.putSync(KEY_SAVE, json)
    await store.flush()
  } catch (e) {
    console.error('[GameStorage] save failed:', JSON.stringify(e))
  }
}

/**
 * 读取保存的游戏状态
 * @returns 存档数据，没有存档返回 null
 */
export function loadGame(context: Context): GameSaveData | null {
  try {
    const store = getStore(context)
    const json = store.getSync(KEY_SAVE, '') as string
    if (!json) return null
    return JSON.parse(json) as GameSaveData
  } catch (e) {
    console.error('[GameStorage] load failed:', JSON.stringify(e))
    return null
  }
}

/**
 * 清除存档（游戏完成后调用）
 */
export async function clearSave(context: Context): Promise<void> {
  try {
    const store = getStore(context)
    store.deleteSync(KEY_SAVE)
    await store.flush()
  } catch (e) {
    console.error('[GameStorage] clear failed:', JSON.stringify(e))
  }
}

/**
 * 检查是否有存档
 */
export function hasSavedGame(context: Context): boolean {
  try {
    const store = getStore(context)
    const json = store.getSync(KEY_SAVE, '') as string
    return json.length > 0
  } catch (e) {
    return false
  }
}
