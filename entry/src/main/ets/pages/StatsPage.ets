/**
 * StatsPage.ets — 统计页面
 *
 * 显示各难度的游戏统计数据：局数、胜率、最佳/平均用时、连胜等。
 */
import { router } from '@kit.ArkUI'
import { Colors, Sizes, DIFFICULTY_CONFIGS, DifficultyConfig } from '../constants/GameConstants'
import { loadStats, GameStats, DifficultyStats, formatTime } from '../utils/StatsStorage'

@Entry
@Component
struct StatsPage {
  @State private stats: GameStats = new GameStats()

  aboutToAppear(): void {
    this.stats = loadStats(getContext(this))
  }

  @Builder
  StatRow(label: ResourceStr, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(Colors.subtitleText)
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor(Colors.titleText)
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
          .fill(config.color)
          .margin({ right: 8 })
        Text(getContext(this).resourceManager.getStringByNameSync(config.name))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.titleText)
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 统计行
      this.StatRow($r('app.string.stats_games_played'), ds.gamesPlayed.toString())
      this.StatRow($r('app.string.stats_games_won'), ds.gamesWon.toString())
      this.StatRow($r('app.string.stats_win_rate'), `${ds.winRate}%`)
      this.StatRow($r('app.string.stats_best_time'), formatTime(ds.bestTimeSeconds))
      this.StatRow($r('app.string.stats_avg_time'), formatTime(ds.averageTimeSeconds))
      this.StatRow($r('app.string.stats_current_streak'), ds.currentStreak.toString())
      this.StatRow($r('app.string.stats_best_streak'), ds.bestStreak.toString())
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.cellDefault)
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: '#1A000000',
      offsetX: 0,
      offsetY: 2,
    })
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(Colors.titleText)
          .onClick(() => {
            router.back()
          })
          .padding({ right: 16 })

        Text($r('app.string.stats_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.titleText)

        Blank()
      }
      .width('100%')
      .height(48)
      .padding({ left: Sizes.pagePadding, right: Sizes.pagePadding })
      .alignItems(VerticalAlign.Center)

      // 总览卡片
      Row() {
        Column() {
          Text(this.stats.totalGamesPlayed.toString())
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.primaryBtn)
          Text($r('app.string.stats_total_played'))
            .fontSize(12)
            .fontColor(Colors.subtitleText)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(this.stats.totalGamesWon.toString())
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4CAF50')
          Text($r('app.string.stats_total_won'))
            .fontSize(12)
            .fontColor(Colors.subtitleText)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(this.stats.totalGamesPlayed > 0
            ? `${Math.round((this.stats.totalGamesWon / this.stats.totalGamesPlayed) * 100)}%`
            : '0%')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.diffHard)
          Text($r('app.string.stats_win_rate'))
            .fontSize(12)
            .fontColor(Colors.subtitleText)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding(16)
      .margin({ top: 8 })

      // 各难度统计
      Scroll() {
        Column({ space: 12 }) {
          ForEach(DIFFICULTY_CONFIGS, (config: DifficultyConfig) => {
            this.DifficultyStatsCard(config, this.stats.difficulties[config.level])
          })
        }
        .width('100%')
        .padding({ left: Sizes.pagePadding, right: Sizes.pagePadding, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.pageBg)
    .padding({ top: 12 })
  }
}
