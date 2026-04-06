/**
 * PuzzleLibraryPage.ets — 题库浏览页面
 *
 * 两级视图：题库列表 → 题目网格。
 * 支持内置/已导入题库浏览、进度展示、筛选功能。
 *
 * 参考：Doc 13 §5.8
 */
import { router } from '@kit.ArkUI'
import { Colors, Sizes, Difficulty, getDifficultyConfig } from '../constants/GameConstants'
import {
  PuzzleLibrary,
  PuzzleEntry,
  PuzzleProgress,
  PuzzleStatus,
  LibraryStats,
  computeLibraryStats,
} from '../models/PuzzleLibrary'
import {
  loadLibraryIndex,
  loadLibraryPuzzles,
  batchLoadProgress,
} from '../utils/PuzzleLibraryStorage'
import { initBuiltinLibraries } from '../utils/BuiltinPuzzleLibrary'

// ============================================================
// 筛选类型
// ============================================================
type FilterType = 'all' | 'new' | 'in_progress' | 'completed'

// ============================================================
// 页面组件
// ============================================================

@Entry
@Component
struct PuzzleLibraryPage {
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0

  @State private libraries: PuzzleLibrary[] = []
  @State private libraryStatsMap: Map<string, LibraryStats> = new Map()
  /** 当前查看的题库 ID（null = 显示题库列表） */
  @State private selectedLibraryId: string | null = null
  @State private selectedLibraryName: string = ''
  @State private puzzles: PuzzleEntry[] = []
  @State private currentFilter: FilterType = 'all'
  @State private isInitialized: boolean = false

  private getString(name: string): string {
    return getContext(this).resourceManager.getStringByNameSync(name)
  }

  aboutToAppear(): void {
    this.loadData()
  }

  onPageShow(): void {
    // 从 GamePage 返回时刷新进度
    if (this.isInitialized) {
      this.refreshCurrentView()
    }
  }

  /**
   * 初始化加载数据：确保内置题库已注册，然后加载索引
   */
  private async loadData(): Promise<void> {
    await initBuiltinLibraries(getContext(this))
    this.libraries = loadLibraryIndex(getContext(this))
    this.computeAllStats()
    this.isInitialized = true
  }

  /**
   * 刷新当前视图数据
   */
  private refreshCurrentView(): void {
    this.libraries = loadLibraryIndex(getContext(this))
    this.computeAllStats()
    if (this.selectedLibraryId) {
      this.loadPuzzlesForLibrary(this.selectedLibraryId)
    }
  }

  /**
   * 计算所有题库的统计数据
   */
  private computeAllStats(): void {
    const statsMap = new Map<string, LibraryStats>()
    for (const lib of this.libraries) {
      const puzzles = loadLibraryPuzzles(getContext(this), lib.id)
      const progressMap = batchLoadProgress(getContext(this), lib.id)
      // 将进度合并到题目上
      for (const puzzle of puzzles) {
        const progress = progressMap.get(puzzle.index)
        if (progress) {
          puzzle.progress = progress
        }
      }
      const stats = computeLibraryStats(puzzles)
      statsMap.set(lib.id, stats)
    }
    this.libraryStatsMap = statsMap
  }

  /**
   * 加载指定题库的题目列表
   */
  private loadPuzzlesForLibrary(libraryId: string): void {
    const puzzles = loadLibraryPuzzles(getContext(this), libraryId)
    const progressMap = batchLoadProgress(getContext(this), libraryId)
    for (const puzzle of puzzles) {
      const progress = progressMap.get(puzzle.index)
      if (progress) {
        puzzle.progress = progress
      }
    }
    this.puzzles = puzzles
  }

  /**
   * 进入题库详情
   */
  private enterLibrary(library: PuzzleLibrary): void {
    this.selectedLibraryId = library.id
    this.selectedLibraryName = library.name
    this.currentFilter = 'all'
    this.loadPuzzlesForLibrary(library.id)
  }

  /**
   * 返回题库列表
   */
  private backToLibraryList(): void {
    this.selectedLibraryId = null
    this.selectedLibraryName = ''
    this.puzzles = []
    this.computeAllStats()
  }

  /**
   * 选择某道题目，跳转到 GamePage
   */
  private selectPuzzle(puzzle: PuzzleEntry): void {
    router.pushUrl({
      url: 'pages/GamePage',
      params: {
        importedPuzzle: puzzle.puzzle81,
        importedDifficulty: puzzle.difficulty,
        libraryId: this.selectedLibraryId,
        puzzleIndex: puzzle.index,
      },
    })
  }

  /**
   * 获取筛选后的题目列表
   */
  private getFilteredPuzzles(): PuzzleEntry[] {
    if (this.currentFilter === 'all') return this.puzzles
    return this.puzzles.filter((p: PuzzleEntry): boolean => {
      return p.progress.status === this.currentFilter as PuzzleStatus
    })
  }

  /**
   * 获取难度颜色
   */
  private getDifficultyColor(difficulty: Difficulty | undefined): string {
    if (!difficulty) return Colors.subtitleText as string
    return getDifficultyConfig(difficulty).color
  }

  /**
   * 获取状态图标
   */
  private getStatusIcon(status: PuzzleStatus): string {
    if (status === 'completed') return '✅'
    if (status === 'in_progress') return '🔄'
    return '⬜'
  }

  /**
   * 格式化用时
   */
  private formatTime(seconds: number): string {
    if (seconds <= 0) return '--:--'
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
  }

  // ============================================================
  // 构建 UI
  // ============================================================

  build() {
    Column() {
      // ==================== 顶部导航栏 ====================
      this.buildTopBar()

      if (!this.isInitialized) {
        // 加载中
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
          Text(this.getString('library_empty_hint'))
            .fontSize(14)
            .fontColor(Colors.subtitleText)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.selectedLibraryId !== null) {
        // ==================== 题目列表视图 ====================
        this.buildPuzzleListView()
      } else {
        // ==================== 题库列表视图 ====================
        this.buildLibraryListView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.pageBg)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  // ==================== 顶部导航栏 ====================
  @Builder
  buildTopBar() {
    Row() {
      if (this.selectedLibraryId !== null) {
        // 返回按钮
        Text('←')
          .fontSize(24)
          .fontColor(Colors.titleText)
          .padding({ right: 12 })
          .onClick(() => {
            this.backToLibraryList()
          })
      }
      Text(this.selectedLibraryId !== null ? this.selectedLibraryName : this.getString('library_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.titleText)
        .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16, top: this.topRectHeight })
    .alignItems(VerticalAlign.Center)
  }

  // ==================== 题库列表视图 ====================
  @Builder
  buildLibraryListView() {
    if (this.libraries.length === 0) {
      Column() {
        Text('📚')
          .fontSize(48)
        Text(this.getString('library_empty_hint'))
          .fontSize(14)
          .fontColor(Colors.subtitleText)
          .margin({ top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 12 }) {
        ForEach(this.libraries, (library: PuzzleLibrary) => {
          ListItem() {
            this.buildLibraryCard(library)
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: this.bottomRectHeight + 24 })
    }
  }

  // ==================== 题库卡片 ====================
  @Builder
  buildLibraryCard(library: PuzzleLibrary) {
    Column() {
      Row() {
        // 难度色条
        Column()
          .width(4)
          .height(40)
          .borderRadius(2)
          .backgroundColor(this.getDifficultyColor(library.difficulty))
          .margin({ right: 12 })

        // 题库信息
        Column() {
          Row({ space: 8 }) {
            Text(library.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.titleText)

            if (library.difficulty) {
              Text(getContext(this).resourceManager.getStringByNameSync(
                getDifficultyConfig(library.difficulty).name
              ))
                .fontSize(11)
                .fontColor(this.getDifficultyColor(library.difficulty))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
                .backgroundColor(Colors.secondaryBtn)
            }
          }

          Text(library.description)
            .fontSize(12)
            .fontColor(Colors.subtitleText)
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 进度信息
        Column() {
          Text(this.getLibraryProgressText(library))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.titleText)
          Text(`${this.getLibraryProgressPercent(library)}%`)
            .fontSize(11)
            .fontColor(Colors.subtitleText)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 进度条
      Progress({ value: this.getLibraryProgressPercent(library), total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(4)
        .margin({ top: 8 })
        .color(this.getDifficultyColor(library.difficulty))
        .backgroundColor(Colors.secondaryBtn)
        .borderRadius(2)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.secondaryBtn)
    .borderRadius(Sizes.btnRadius)
    .borderWidth(1)
    .borderColor(Colors.secondaryBorder)
    .onClick(() => {
      this.enterLibrary(library)
    })
  }

  private getLibraryProgressText(library: PuzzleLibrary): string {
    const stats = this.libraryStatsMap.get(library.id)
    const completed = stats ? stats.completed : 0
    return `${completed}/${library.puzzleCount}`
  }

  private getLibraryProgressPercent(library: PuzzleLibrary): number {
    const stats = this.libraryStatsMap.get(library.id)
    return stats ? stats.overallPercentage : 0
  }

  // ==================== 题目列表视图 ====================
  @Builder
  buildPuzzleListView() {
    Column() {
      // 筛选栏
      this.buildFilterBar()

      // 题目网格
      List({ space: 8 }) {
        ForEach(this.getFilteredPuzzles(), (puzzle: PuzzleEntry) => {
          ListItem() {
            this.buildPuzzleCard(puzzle)
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: this.bottomRectHeight + 24 })
    }
    .width('100%')
    .layoutWeight(1)
  }

  // ==================== 筛选栏 ====================
  @Builder
  buildFilterBar() {
    Row({ space: 8 }) {
      this.buildFilterButton('all', this.getString('library_filter_all'))
      this.buildFilterButton('new', this.getString('library_filter_new'))
      this.buildFilterButton('in_progress', this.getString('library_filter_in_progress'))
      this.buildFilterButton('completed', this.getString('library_filter_completed'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  buildFilterButton(filter: FilterType, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.currentFilter === filter ? '#FFFFFF' : Colors.titleText)
      .backgroundColor(this.currentFilter === filter ? Colors.primaryBtn : Colors.secondaryBtn)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(() => {
        this.currentFilter = filter
      })
  }

  // ==================== 题目卡片 ====================
  @Builder
  buildPuzzleCard(puzzle: PuzzleEntry) {
    Row() {
      // 左侧序号和状态图标
      Column() {
        Text(this.getStatusIcon(puzzle.progress.status))
          .fontSize(20)
        Text(`#${puzzle.index + 1}`)
          .fontSize(11)
          .fontColor(Colors.subtitleText)
          .margin({ top: 2 })
      }
      .width(48)
      .alignItems(HorizontalAlign.Center)

      // 中部信息
      Column() {
        Row({ space: 6 }) {
          Text(`${this.getString('library_title')} #${puzzle.index + 1}`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.titleText)
        }

        if (puzzle.progress.status !== 'new') {
          Row({ space: 8 }) {
            Text(this.formatTime(puzzle.progress.elapsedSeconds))
              .fontSize(12)
              .fontColor(Colors.subtitleText)
            if (puzzle.progress.errorCount > 0) {
              Text(`${puzzle.progress.errorCount} ❌`)
                .fontSize(12)
                .fontColor('#F44336')
            }
          }
          .margin({ top: 2 })
        } else {
          Text(this.getString('library_puzzle_new'))
            .fontSize(12)
            .fontColor(Colors.subtitleText)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧进度
      if (puzzle.progress.status === 'in_progress') {
        Text(`${puzzle.progress.percentage}%`)
          .fontSize(14)
          .fontColor(Colors.subtitleText)
      } else if (puzzle.progress.status === 'completed') {
        Text(this.getStarRating(puzzle.progress.elapsedSeconds, puzzle.progress.errorCount))
          .fontSize(16)
      }
    }
    .width('100%')
    .height(60)
    .padding({ left: 8, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Colors.secondaryBtn)
    .borderRadius(Sizes.btnRadius)
    .borderWidth(1)
    .borderColor(
      puzzle.progress.status === 'completed' ? '#4CAF50' :
        puzzle.progress.status === 'in_progress' ? '#2196F3' :
          Colors.secondaryBorder
    )
    .onClick(() => {
      this.selectPuzzle(puzzle)
    })
  }

  /**
   * 根据用时和错误数计算星级评价
   */
  private getStarRating(elapsedSeconds: number, errorCount: number): string {
    return computeStarDisplay(elapsedSeconds, errorCount)
  }
}

/**
 * 计算星级评价（3 星制）
 * 规则：
 * - 3 星：用时 < 5 分钟且错误 < 2
 * - 2 星：用时 < 10 分钟且错误 < 5
 * - 1 星：完成即得
 */
export function computeStarCount(elapsedSeconds: number, errorCount: number): number {
  if (elapsedSeconds < 300 && errorCount < 2) return 3
  if (elapsedSeconds < 600 && errorCount < 5) return 2
  return 1
}

/**
 * 星级评价显示
 */
export function computeStarDisplay(elapsedSeconds: number, errorCount: number): string {
  const stars = computeStarCount(elapsedSeconds, errorCount)
  if (stars === 3) return '★★★'
  if (stars === 2) return '★★☆'
  return '★☆☆'
}
