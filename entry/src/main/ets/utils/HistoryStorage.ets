/**
 * HistoryStorage.ets — 旧版结果摘要的迁移兼容存储
 *
 * 记录每局完成的游戏：种子、难度、对称模式、用时、步骤数、
 * 当时实际保留的操作快照。新版本完整棋局和分支使用 JournalStorage。
 *
 * 使用 @ohos.data.preferences 存储。
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { GameSaveData, isValidGameSave } from '../models/GameSaveData'
import { CellSnapshot } from '../models/GameHistory'

const STORE_NAME = 'sudoku_history'
const KEY_RECORDS = 'game_records'

// ============================================================
// 数据结构
// ============================================================

/** 一局游戏的完整记录 */
export class GameRecord {
  /** 种子 ID（格式：difficulty:symmetry:seed） */
  seedId: string = ''
  /** 保存原题及变种配置，不依赖种子格式或后续生成器版本。 */
  replaySave?: GameSaveData
  /** 种子值 */
  seed: number = 0
  /** 难度 (1-5) */
  difficulty: number = 0
  /** 对称模式 */
  symmetry: string = ''
  /** 用时（秒） */
  timeSeconds: number = 0
  /** 错误次数 */
  errors: number = 0
  /** 总步数 */
  stepCount: number = 0
  /** 是否胜利 */
  won: boolean = false
  /** 完成时间戳 */
  timestamp: number = 0
  /** 每一步操作快照（用于回放），每个条目是一组快照 */
  steps: CellSnapshot[][] = []

  constructor() {}
}

// ============================================================
// 存取方法
// ============================================================

function getStore(context: Context): preferences.Preferences {
  const options: preferences.Options = { name: STORE_NAME }
  return preferences.getPreferencesSync(context, options)
}

/**
 * 加载所有历史记录（最新在前）
 */
export function loadHistory(context: Context): GameRecord[] {
  try {
    const store = getStore(context)
    const json = store.getSync(KEY_RECORDS, '') as string
    if (!json) return []
    return JSON.parse(json) as GameRecord[]
  } catch (e) {
    console.error('[HistoryStorage] load failed:', JSON.stringify(e))
    return []
  }
}

/**
 * 保存历史记录列表
 */
async function saveHistory(context: Context, records: GameRecord[]): Promise<void> {
  try {
    const store = getStore(context)
    store.putSync(KEY_RECORDS, JSON.stringify(records))
    await store.flush()
  } catch (e) {
    console.error('[HistoryStorage] save failed:', JSON.stringify(e))
  }
}

/**
 * 兼容旧调用者；不再静默截断记录。新游戏写入 JournalStorage。
 */
export function addGameRecord(context: Context, record: GameRecord): void {
  const records = loadHistory(context)
  // 新记录插在最前面
  records.unshift(record)
  saveHistory(context, records)
}

/** 旧记录缺少原题，不能把一个不完整 seed 冒充为同题重玩。 */
export function getReplaySave(record: GameRecord): GameSaveData | null {
  return isValidGameSave(record.replaySave) ? record.replaySave! : null
}
