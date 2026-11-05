/** 统计汇总组件；历史记录由独立历史页面负责。 */
import { getLocalizedString } from '../utils/I18nHelper'
import { ColorsConfig, getThemeColors, getDifficultyColor, DIFFICULTY_CONFIGS, DifficultyConfig } from '../constants/GameConstants'
import { loadStats, GameStats, DifficultyStats, formatTime, reconcileJournalStats } from '../utils/StatsStorage'

@Component
export struct StatsPanel {
  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @State private stats: GameStats = new GameStats()
  @Prop embedded: boolean = false
  @Prop @Watch('refreshIfVisible') active: boolean = true
  @Prop @Watch('refreshIfVisible') refreshVersion: number = 0
  onClose: () => void = () => {}
  private alive: boolean = false

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  aboutToAppear(): void {
    this.alive = true
    this.refreshIfVisible()
  }

  private refreshIfVisible(): void {
    if (!this.active || !this.alive) return
    const context = getContext(this)
    this.stats = loadStats(context)
    reconcileJournalStats(context).then(() => {
      if (this.alive) this.stats = loadStats(context)
    }).catch(() => { /* 已保存的统计仍可查看，下次打开时重试投影。 */ })
  }

  aboutToDisappear(): void { this.alive = false }

  @Builder
  StatRow(label: ResourceStr, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.getPalette().subtitleText)
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor(this.getPalette().titleText)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  DifficultyStatsCard(config: DifficultyConfig, ds: DifficultyStats) {
    Column() {
      // 难度标题
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(getDifficultyColor(config.level, this.isDarkMode))
          .margin({ right: 8 })
        Text(getLocalizedString(getContext(this), config.name, this.localeRevision))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().titleText)
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 统计行
      this.StatRow($r('app.string.stats_games_played'), ds.gamesPlayed.toString())
      this.StatRow($r('app.string.stats_games_won'), ds.gamesWon.toString())
      this.StatRow($r('app.string.stats_win_rate'),
        `${ds.gamesPlayed > 0 ? Math.round((ds.gamesWon / ds.gamesPlayed) * 100) : 0}%`)
      this.StatRow($r('app.string.stats_best_time'), formatTime(ds.bestTimeSeconds))
      this.StatRow($r('app.string.stats_avg_time'),
        formatTime(ds.gamesWon > 0 ? Math.floor(ds.totalTimeSeconds / ds.gamesWon) : 0))
      this.StatRow($r('app.string.stats_current_streak'), ds.currentStreak.toString())
      this.StatRow($r('app.string.stats_best_streak'), ds.bestStreak.toString())
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius(8)
    .border({ width: 1, color: this.getPalette().cardBorder })
  }

  @Builder
  private SummaryItem(value: string, label: Resource) {
    Column({ space: 6 }) {
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getPalette().titleText)
      Text(label)
        .fontSize(12)
        .fontColor(this.getPalette().subtitleText)
    }
    .layoutWeight(1)
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        if (!this.embedded) {
          Button({ type: ButtonType.Normal }) {
            Image($r('app.media.paper_arrow_left'))
              .width(22)
              .height(22)
              .fillColor(this.getPalette().titleText)
              .accessibilityLevel('no')
          }
          .id('stats-back')
          .width(44)
          .height(44)
          .padding(10)
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.common_back'))
          .onClick(() => this.onClose())
        }
        Text($r('app.string.stats_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().titleText)
      }
      .width('100%')
      .padding({ left: this.embedded ? 24 : 12, right: 24, top: this.embedded ? 20 : 8, bottom: 12 })

      Scroll() {
        Column({ space: 16 }) {
          Row() {
            this.SummaryItem(this.stats.totalGamesPlayed.toString(), $r('app.string.stats_total_played'))
            this.SummaryItem(this.stats.totalGamesWon.toString(), $r('app.string.stats_total_won'))
            this.SummaryItem(this.stats.totalGamesPlayed > 0 ?
              `${Math.round(this.stats.totalGamesWon / this.stats.totalGamesPlayed * 100)}%` : '0%',
              $r('app.string.stats_win_rate'))
          }
          .width('100%')
          .padding({ top: 16, bottom: 24 })
          .border({ width: { bottom: 0.5 }, color: this.getPalette().divider })
          ForEach(DIFFICULTY_CONFIGS, (config: DifficultyConfig) => {
            this.DifficultyStatsCard(config, this.stats.difficulties[config.level])
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: 760 })
        .padding({ left: 24, right: 24, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBg)
  }
}
