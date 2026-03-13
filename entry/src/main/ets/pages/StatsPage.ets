/**
 * StatsPage.ets — 统计页面
 *
 * 使用 Tabs 组件实现统计总览 + 历史记录两个 Tab，不可左右滑动。
 * 统计：各难度的游戏次数、胜率、最佳/平均用时、连胜等。
 * 历史：最近完成的游戏，显示难度、对称、用时、步数、错误，支持重玩。
 */
import { router, promptAction } from '@kit.ArkUI'
import { pasteboard } from '@kit.BasicServicesKit'
import { Colors, Sizes, DIFFICULTY_CONFIGS, DifficultyConfig, getDifficultyConfig, Difficulty } from '../constants/GameConstants'
import { loadStats, GameStats, DifficultyStats, formatTime } from '../utils/StatsStorage'
import { loadHistory, GameRecord } from '../utils/HistoryStorage'

@Entry
@Component
struct StatsPage {
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  @State private stats: GameStats = new GameStats()
  @State private history: GameRecord[] = []
  @State private activeTab: number = 0   // 0=统计, 1=历史

  aboutToAppear(): void {
    this.stats = loadStats(getContext(this))
    this.history = loadHistory(getContext(this))
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
    .backgroundColor(Colors.cellDefault)
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: Colors.shadowColor,
      offsetX: 0,
      offsetY: 2,
    })
  }

  @Builder
  TabBarItem(title: ResourceStr, index: number) {
    Text(title)
      .fontSize(14)
      .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.activeTab === index ? Colors.primaryText : Colors.subtitleText)
      .backgroundColor(this.activeTab === index ? Colors.primaryBtn : 'transparent')
      .borderRadius(8)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .width('50%')
      .textAlign(TextAlign.Center)
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

      // 使用 Tabs 组件，禁用左右滑动
      Tabs({ index: this.activeTab, barPosition: BarPosition.Start }) {
        // ==================== Tab 0: 统计总览 ====================
        TabContent() {
          Column() {
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
                  .fontColor(Colors.statsWonText)
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
          }
          .width('100%')
          .height('100%')
        }
        .tabBar(this.TabBarItem($r('app.string.stats_tab_overview'), 0))

        // ==================== Tab 1: 历史记录 ====================
        TabContent() {
          if (this.history.length === 0) {
            Column() {
              Blank()
              Text($r('app.string.stats_no_history'))
                .fontSize(16)
                .fontColor(Colors.subtitleText)
              Blank()
            }
            .width('100%')
            .height('100%')
          } else {
            Scroll() {
              Column({ space: 8 }) {
                ForEach(this.history, (record: GameRecord, index: number) => {
                  this.HistoryCard(record, index as number)
                })
              }
              .width('100%')
              .padding({ left: Sizes.pagePadding, right: Sizes.pagePadding, top: 8, bottom: 24 })
            }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
          }
        }
        .tabBar(this.TabBarItem($r('app.string.stats_tab_history'), 1))
      }
      .scrollable(false)
      .barMode(BarMode.Fixed)
      .barBackgroundColor(Colors.segmentBg)
      .animationDuration(200)
      .onChange((index: number) => {
        this.activeTab = index
      })
      .layoutWeight(1)
      .margin({ left: Sizes.pagePadding, right: Sizes.pagePadding, top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.pageBg)
    .padding({ top: this.topRectHeight + 12, bottom: this.bottomRectHeight })
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  HistoryCard(record: GameRecord, _index: number) {
    Column() {
      // 顶部行：难度 + 结果 + 日期
      Row() {
        // 左侧难度色条
        Column()
          .width(4)
          .height('100%')
          .borderRadius(2)
          .backgroundColor(
            record.difficulty >= 1 && record.difficulty <= 5
              ? getDifficultyConfig(record.difficulty as Difficulty).color
              : Colors.subtitleText
          )

        // 难度名 + 结果标记
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(record.difficulty >= 1 && record.difficulty <= 5
              ? getContext(this).resourceManager.getStringByNameSync(
                getDifficultyConfig(record.difficulty as Difficulty).name)
              : '?')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.titleText)

            Text(record.won ? '✅' : '❌')
              .fontSize(13)
          }

          // 种子 ID（点击复制）
          Text(`🔑 ${record.seedId}`)
            .fontSize(11)
            .fontColor(Colors.primaryBtn)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .decoration({ type: TextDecorationType.Underline, color: Colors.primaryBtn })
            .onClick(() => {
              const pbData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, record.seedId)
              pasteboard.getSystemPasteboard().setDataSync(pbData)
              promptAction.showToast({
                message: getContext(this).resourceManager.getStringByNameSync('seed_id_copied'),
                duration: 1500
              })
            })
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 右侧日期
        Text(this.formatDate(record.timestamp))
          .fontSize(11)
          .fontColor(Colors.subtitleText)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 分隔线
      Divider()
        .color(Colors.divider)
        .margin({ top: 8, bottom: 8 })

      // 详细信息行：用时 + 步数 + 错误 + 对称
      Row() {
        Text(`⏱ ${formatTime(record.timeSeconds)}`)
          .fontSize(12)
          .fontColor(Colors.subtitleText)

        Text(`📝 ${record.stepCount}`)
          .fontSize(12)
          .fontColor(Colors.subtitleText)
          .margin({ left: 12 })

        if (record.errors > 0) {
          Text(`❌ ${record.errors}`)
            .fontSize(12)
            .fontColor(Colors.textError)
            .margin({ left: 12 })
        }

        if (record.symmetry) {
          Text(`🔄 ${this.getSymmetryLabel(record.symmetry)}`)
            .fontSize(12)
            .fontColor(Colors.subtitleText)
            .margin({ left: 12 })
        }

        Blank()

        // 重玩按钮
        if (record.seedId) {
          Text($r('app.string.stats_replay'))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.primaryBtn)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .borderRadius(12)
            .borderWidth(1)
            .borderColor(Colors.primaryBtn)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/GamePage',
                params: {
                  difficulty: record.difficulty,
                  seedId: record.seedId,
                },
              })
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Colors.cellDefault)
    .borderRadius(12)
    .shadow({
      radius: 2,
      color: Colors.shadowColorLight,
      offsetX: 0,
      offsetY: 1,
    })
  }

  private getSymmetryLabel(symmetry: string): string {
    const key = `sym_${symmetry}`
    try {
      return getContext(this).resourceManager.getStringByNameSync(key)
    } catch (_e) {
      return symmetry
    }
  }

  private formatDate(timestamp: number): string {
    if (timestamp <= 0) return ''
    const d = new Date(timestamp)
    const month = (d.getMonth() + 1).toString().padStart(2, '0')
    const day = d.getDate().toString().padStart(2, '0')
    const hour = d.getHours().toString().padStart(2, '0')
    const min = d.getMinutes().toString().padStart(2, '0')
    return `${month}-${day} ${hour}:${min}`
  }
}
