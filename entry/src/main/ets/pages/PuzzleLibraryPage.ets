/**
 * PuzzleLibraryPage.ets — 题库浏览页面
 *
 * 两级视图：题库列表 → 题目网格。
 * 支持内置/已导入题库浏览、进度展示、筛选功能。
 *
 * 参考：Doc 13 §5.8
 */
import { getLocalizedString } from '../utils/I18nHelper'
import { router } from '@kit.ArkUI'
import { ColorsConfig, getThemeColors, getDifficultyColor, Sizes, Difficulty, getDifficultyConfig } from '../constants/GameConstants'
import { computeStarDisplay } from '../utils/Common'
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
  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0

  @StorageProp('leftRectWidth') leftRectWidth: number = 0
  @StorageProp('rightRectWidth') rightRectWidth: number = 0
  @State private listWidth: number = 0

  @State private libraries: PuzzleLibrary[] = []
  @State private libraryStatsMap: Map<string, LibraryStats> = new Map()
  /** 当前查看的题库 ID（null = 显示题库列表） */
  @State private selectedLibraryId: string | null = null
  @State private selectedLibraryName: string = ''
  @State private puzzles: PuzzleEntry[] = []
  @State private currentFilter: FilterType = 'all'
  @State private isInitialized: boolean = false

  private getString(name: string): string {
    return getLocalizedString(getContext(this), name, this.localeRevision)
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

  /** 系统返回与可见返回按钮共用同一个层级规则。 */
  onBackPress(): boolean {
    this.navigateBack()
    return true
  }

  private navigateBack(): void {
    if (this.selectedLibraryId !== null) {
      this.backToLibraryList()
    } else {
      router.back({ url: 'pages/Index' })
    }
  }

  private backLabel(): string {
    return this.getString(this.selectedLibraryId !== null ? 'library_back_list' : 'library_back_home')
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
        resumeLibrary: true,
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
    if (!difficulty) return this.getPalette().subtitleText as string
    return getDifficultyColor(difficulty, this.isDarkMode)
  }

  /**
   * 获取状态图标
   */
  private getStatusIcon(status: PuzzleStatus): Resource {
    if (status === 'completed') return $r('app.media.paper_check')
    if (status === 'in_progress') return $r('app.media.paper_clock')
    return $r('app.media.paper_pencil')
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
            .fontColor(this.getPalette().subtitleText)
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
    .padding({ left: this.leftRectWidth, right: this.rightRectWidth })
    .backgroundColor(this.getPalette().pageBg)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  // ==================== 顶部导航栏 ====================
  @Builder
  buildTopBar() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          Image($r('app.media.paper_arrow_left'))
            .width(20)
            .height(20)
            .fillColor(this.getPalette().titleText)
            .accessibilityLevel('no')
          Text(this.backLabel())
            .fontSize(14)
            .fontColor(this.getPalette().titleText)
        }
        .alignItems(VerticalAlign.Center)
      }
      .height(44)
      .constraintSize({ minWidth: 44 })
      .padding({ left: 4, right: 8 })
      .borderRadius(4)
      .backgroundColor(Color.Transparent)
      .accessibilityText(this.backLabel())
      .onClick(() => { this.navigateBack() })

      Text(this.selectedLibraryId !== null ? this.selectedLibraryName : this.getString('library_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().titleText)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ maxWidth: 1040 })
    .height(64 + this.topRectHeight)
    .padding({ left: 16, right: 16, top: this.topRectHeight })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.getPalette().pageBg)
  }

  // ==================== 题库列表视图 ====================
  @Builder
  buildLibraryListView() {
    if (this.libraries.length === 0) {
      Column() {
        Image($r('app.media.paper_select'))
          .width(48)
          .height(48)
          .fillColor(this.getPalette().subtitleText)
          .accessibilityLevel('no')
        Text(this.getString('library_empty_hint'))
          .fontSize(14)
          .fontColor(this.getPalette().subtitleText)
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
        }, (library: PuzzleLibrary) => `${library.id}_${this.getLibraryProgressPercent(library)}`)
      }
      .width('100%')
      .constraintSize({ maxWidth: 1040 })
      .lanes(this.listWidth >= 720 ? 2 : 1, 12)
      .onAreaChange((_oldArea: Area, newArea: Area) => { this.listWidth = Number(newArea.width) })
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
              .fontColor(this.getPalette().titleText)

            if (library.difficulty) {
              Text(getLocalizedString(getContext(this),
                getDifficultyConfig(library.difficulty).name, this.localeRevision))
                .fontSize(11)
                .fontColor(this.getDifficultyColor(library.difficulty))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
                .backgroundColor(this.getPalette().secondaryBtn)
            }
          }

          Text(library.description)
            .fontSize(12)
            .fontColor(this.getPalette().subtitleText)
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
            .fontColor(this.getPalette().titleText)
          Text(`${this.getLibraryProgressPercent(library)}%`)
            .fontSize(11)
            .fontColor(this.getPalette().subtitleText)
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
        .backgroundColor(this.getPalette().secondaryBtn)
        .borderRadius(2)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.getPalette().secondaryBtn)
    .borderRadius(Sizes.btnRadius)
    .borderWidth(1)
    .borderColor(this.getPalette().secondaryBorder)
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
        }, (puzzle: PuzzleEntry) => `${puzzle.index}_${puzzle.progress.status}_${puzzle.progress.percentage}`)
      }
      .width('100%')
      .constraintSize({ maxWidth: 1040 })
      .lanes(this.listWidth >= 720 ? 2 : 1, 12)
      .onAreaChange((_oldArea: Area, newArea: Area) => { this.listWidth = Number(newArea.width) })
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: this.bottomRectHeight + 24 })
    }
    .width('100%')
    .layoutWeight(1)
  }

  // ==================== 筛选栏 ====================
  @Builder
  buildFilterBar() {
    Scroll() {
    Row({ space: 8 }) {
      this.buildFilterButton('all', this.getString('library_filter_all'))
      this.buildFilterButton('new', this.getString('library_filter_new'))
      this.buildFilterButton('in_progress', this.getString('library_filter_in_progress'))
      this.buildFilterButton('completed', this.getString('library_filter_completed'))
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .width('100%')
    .constraintSize({ maxWidth: 1040 })
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  buildFilterButton(filter: FilterType, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.currentFilter === filter ? this.getPalette().primaryText : this.getPalette().titleText)
      .backgroundColor(this.currentFilter === filter ? this.getPalette().primaryBtn : this.getPalette().secondaryBtn)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(8)
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
        Image(this.getStatusIcon(puzzle.progress.status))
          .width(20)
          .height(20)
          .fillColor(this.getPalette().primaryBtn)
          .accessibilityText(this.getString(`library_puzzle_${puzzle.progress.status}`))
        Text(`#${puzzle.index + 1}`)
          .fontSize(11)
          .fontColor(this.getPalette().subtitleText)
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
            .fontColor(this.getPalette().titleText)
        }

        if (puzzle.progress.status !== 'new') {
          Row({ space: 8 }) {
            Text(this.formatTime(puzzle.progress.elapsedSeconds))
              .fontSize(12)
              .fontColor(this.getPalette().subtitleText)
            if (puzzle.progress.errorCount > 0) {
              Row({ space: 3 }) {
                Image($r('app.media.paper_close'))
                  .width(12)
                  .height(12)
                  .fillColor(this.getPalette().textError)
                  .accessibilityLevel('no')
                Text(puzzle.progress.errorCount.toString())
                  .fontSize(12)
                  .fontColor(this.getPalette().textError)
              }
              .accessibilityText(`${this.getString('pause_info_errors')} ${puzzle.progress.errorCount}`)
            }
          }
          .margin({ top: 2 })
        } else {
          Text(this.getString('library_puzzle_new'))
            .fontSize(12)
            .fontColor(this.getPalette().subtitleText)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧进度
      if (puzzle.progress.status === 'in_progress') {
        Text(`${puzzle.progress.percentage}%`)
          .fontSize(14)
          .fontColor(this.getPalette().subtitleText)
      } else if (puzzle.progress.status === 'completed') {
        Text(this.getStarRating(puzzle.progress.elapsedSeconds, puzzle.progress.errorCount))
          .fontSize(16)
      }
    }
    .width('100%')
    .height(60)
    .padding({ left: 8, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.getPalette().secondaryBtn)
    .borderRadius(Sizes.btnRadius)
    .borderWidth(1)
    .borderColor(
      puzzle.progress.status === 'completed' ? this.getPalette().statsWonText :
        puzzle.progress.status === 'in_progress' ? this.getPalette().toolbarActive :
          this.getPalette().secondaryBorder
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
