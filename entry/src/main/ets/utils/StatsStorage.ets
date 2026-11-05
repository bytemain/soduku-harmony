/**
 * StatsStorage.ets — 游戏统计持久化
 *
 * 记录每个难度的：游戏次数、胜利次数、最佳用时、平均用时。
 * 使用 @ohos.data.preferences 存储。
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { loadJournalStatsSnapshot } from './JournalStorage'
import { JournalStatsSnapshot, JournalStatsFact } from '../models/GameJournal'

const STORE_NAME = 'sudoku_stats'
const KEY_STATS = 'game_stats'

/** 单个难度的统计数据 */
export class DifficultyStats {
  gamesPlayed: number = 0
  gamesWon: number = 0
  bestTimeSeconds: number = 0      // 0 表示尚无记录
  totalTimeSeconds: number = 0     // 累计用时（用于算平均）
  totalErrors: number = 0
  currentStreak: number = 0        // 当前连胜
  bestStreak: number = 0           // 最佳连胜

  constructor() {}

  /** 平均用时（秒） */
  get averageTimeSeconds(): number {
    if (this.gamesWon === 0) return 0
    return Math.floor(this.totalTimeSeconds / this.gamesWon)
  }

  /** 胜率百分比 */
  get winRate(): number {
    if (this.gamesPlayed === 0) return 0
    return Math.round((this.gamesWon / this.gamesPlayed) * 100)
  }
}

/** 全局统计（包含所有难度） */
export class GameStats {
  /** index 0 不用，1-5 对应 Difficulty.EASY ~ EVIL */
  difficulties: DifficultyStats[] = []
  totalGamesPlayed: number = 0
  totalGamesWon: number = 0
  /** 仅保留旧格式兼容；新统计由 journal 重算，不无限累加回执。 */
  settlementSessionIds: string[] = []

  constructor() {
    // 初始化 6 个（index 0 占位）
    for (let i = 0; i < 6; i++) {
      this.difficulties.push(new DifficultyStats())
    }
  }
}

/**
 * 获取 preferences 实例
 */
function getStatsStore(context: Context): preferences.Preferences {
  const options: preferences.Options = { name: STORE_NAME }
  return preferences.getPreferencesSync(context, options)
}

/**
 * 加载统计数据
 */
export function loadStats(context: Context): GameStats {
  try {
    const store = getStatsStore(context)
    const json = store.getSync(KEY_STATS, '') as string
    if (!json) return new GameStats()
    const parsed = JSON.parse(json) as GameStats
    // 确保 difficulties 数组长度正确
    if (!parsed.difficulties || parsed.difficulties.length < 6) {
      return new GameStats()
    }
    return parsed
  } catch (e) {
    console.error('[StatsStorage] load failed:', JSON.stringify(e))
    return new GameStats()
  }
}

/**
 * 保存统计数据
 */
export async function saveStats(context: Context, stats: GameStats): Promise<void> {
  const store = getStatsStore(context)
  store.putSync(KEY_STATS, JSON.stringify(stats))
  await store.flush()
}

class JournalStatEvent {
  fact: JournalStatsFact
  kind: 'start' | 'won' | 'lost'
  timestamp: number
  constructor(fact: JournalStatsFact, kind: 'start' | 'won' | 'lost', timestamp: number) {
    this.fact = fact
    this.kind = kind
    this.timestamp = timestamp
  }
}

function baselineCounter(value: number | undefined): number {
  if (value === undefined) return 0
  if (!Number.isFinite(value) || value < 0) throw new Error('Invalid legacy statistics baseline')
  return value
}

/** 纯投影：从不可变旧基线出发，每次完整重算，不依赖上次写入是否成功。 */
export function projectJournalStats(snapshot: JournalStatsSnapshot): GameStats {
  const stats = new GameStats()
  let previousReceipts: string[] = []
  if (snapshot.legacyJson !== '') {
    const baseline = JSON.parse(snapshot.legacyJson) as GameStats
    if (!Array.isArray(baseline.difficulties) || baseline.difficulties.length < 6) {
      throw new Error('Invalid legacy statistics baseline')
    }
    stats.totalGamesPlayed = baselineCounter(baseline.totalGamesPlayed)
    stats.totalGamesWon = baselineCounter(baseline.totalGamesWon)
    previousReceipts = baseline.settlementSessionIds ?? []
    for (let index = 0; index < 6; index++) {
      const old = baseline.difficulties[index]
      if (!old) throw new Error('Invalid legacy statistics difficulty')
      const target = stats.difficulties[index]
      target.gamesPlayed = baselineCounter(old.gamesPlayed)
      target.gamesWon = baselineCounter(old.gamesWon)
      target.bestTimeSeconds = baselineCounter(old.bestTimeSeconds)
      target.totalTimeSeconds = baselineCounter(old.totalTimeSeconds)
      target.totalErrors = baselineCounter(old.totalErrors)
      target.currentStreak = baselineCounter(old.currentStreak)
      target.bestStreak = baselineCounter(old.bestStreak)
    }
  }
  const events: JournalStatEvent[] = []
  for (const fact of snapshot.facts) {
    if (fact.difficulty < 1 || fact.difficulty > 5 || previousReceipts.includes(fact.id)) continue
    if (!fact.startedInLegacyStats) events.push(new JournalStatEvent(fact, 'start', fact.createdAt))
    // 当前自由模式没有错误失败。只保留已经真正完成的旧政策失败记录。
    if (fact.errorLimit > 0 && fact.settled && fact.outcome === 'completed_failed') {
      events.push(new JournalStatEvent(fact, 'lost', fact.challengeFailedAt || fact.settledAt))
    }
    if (fact.settled && fact.outcome === 'won') events.push(new JournalStatEvent(fact, 'won', fact.settledAt))
  }
  events.sort((first: JournalStatEvent, second: JournalStatEvent): number => {
    if (first.timestamp !== second.timestamp) return first.timestamp - second.timestamp
    if (first.kind === 'start' && second.kind !== 'start') return -1
    if (second.kind === 'start' && first.kind !== 'start') return 1
    return first.fact.id.localeCompare(second.fact.id)
  })
  for (const event of events) {
    const ds = stats.difficulties[event.fact.difficulty]
    if (event.kind === 'start') {
      ds.gamesPlayed++
      stats.totalGamesPlayed++
    } else if (event.kind === 'lost') {
      ds.currentStreak = 0
    } else {
      ds.gamesWon++
      stats.totalGamesWon++
      ds.totalTimeSeconds += event.fact.elapsedSeconds
      ds.totalErrors += event.fact.errorCount
      if (ds.bestTimeSeconds === 0 || event.fact.elapsedSeconds < ds.bestTimeSeconds) ds.bestTimeSeconds = event.fact.elapsedSeconds
      ds.currentStreak++
      ds.bestStreak = Math.max(ds.bestStreak, ds.currentStreak)
    }
  }
  return stats
}

let projectionTail: Promise<void> = Promise.resolve()

/** 先补齐中断的 journal 结算，再按时间有序投影；失败继续向调用方报告。 */
export function reconcileJournalStats(context: Context): Promise<void> {
  const result = projectionTail.then(async (): Promise<void> => {
    const snapshot = await loadJournalStatsSnapshot(context)
    await saveStats(context, projectJournalStats(snapshot))
  })
  projectionTail = result.then((): void => {}, (): void => {})
  return result
}

/**
 * 格式化秒数为 mm:ss
 */
export function formatTime(seconds: number): string {
  if (seconds <= 0) return '--:--'
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  const mm = m < 10 ? `0${m}` : `${m}`
  const ss = s < 10 ? `0${s}` : `${s}`
  return `${mm}:${ss}`
}
