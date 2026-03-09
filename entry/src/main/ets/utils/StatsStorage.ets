/**
 * StatsStorage.ets — 游戏统计持久化
 *
 * 记录每个难度的：游戏次数、胜利次数、最佳用时、平均用时。
 * 使用 @ohos.data.preferences 存储。
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'

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
  try {
    const store = getStatsStore(context)
    const json = JSON.stringify(stats)
    store.putSync(KEY_STATS, json)
    await store.flush()
  } catch (e) {
    console.error('[StatsStorage] save failed:', JSON.stringify(e))
  }
}

/**
 * 记录一局游戏开始（增加 gamesPlayed）
 */
export function recordGameStarted(context: Context, difficulty: number): void {
  const stats = loadStats(context)
  if (difficulty >= 1 && difficulty <= 5) {
    stats.difficulties[difficulty].gamesPlayed++
    stats.totalGamesPlayed++
    saveStats(context, stats)
  }
}

/**
 * 记录一局游戏胜利
 */
export function recordGameWon(context: Context, difficulty: number, timeSeconds: number, errors: number): void {
  const stats = loadStats(context)
  if (difficulty < 1 || difficulty > 5) return

  const ds = stats.difficulties[difficulty]
  ds.gamesWon++
  ds.totalTimeSeconds += timeSeconds
  ds.totalErrors += errors

  // 更新最佳用时
  if (ds.bestTimeSeconds === 0 || timeSeconds < ds.bestTimeSeconds) {
    ds.bestTimeSeconds = timeSeconds
  }

  // 更新连胜
  ds.currentStreak++
  if (ds.currentStreak > ds.bestStreak) {
    ds.bestStreak = ds.currentStreak
  }

  stats.totalGamesWon++
  saveStats(context, stats)
}

/**
 * 记录一局游戏失败/放弃（中断连胜）
 */
export function recordGameLost(context: Context, difficulty: number): void {
  const stats = loadStats(context)
  if (difficulty >= 1 && difficulty <= 5) {
    stats.difficulties[difficulty].currentStreak = 0
    saveStats(context, stats)
  }
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
