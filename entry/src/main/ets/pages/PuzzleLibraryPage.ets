import { router } from '@kit.ArkUI'
import { Colors, Sizes, getDifficultyConfig, Difficulty } from '../constants/GameConstants'
import { computeLibraryStats, LibraryStats, PuzzleEntry, PuzzleLibrary, PuzzleStatus } from '../models/PuzzleLibrary'
import { getBuiltinPuzzleEntriesWithProgress, getBuiltinPuzzleLibraries } from '../utils/BuiltinPuzzleLibrary'
import { clearSave, hasSavedGame } from '../utils/GameStorage'
import { loadActivePuzzle, saveActivePuzzle, ActivePuzzlePointer } from '../utils/PuzzleLibraryStorage'

@Entry
@Component
struct PuzzleLibraryPage {
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  @State private libraries: PuzzleLibrary[] = []
  @State private selectedLibraryId: string = ''
  @State private puzzles: PuzzleEntry[] = []
  @State private activePuzzle: ActivePuzzlePointer | null = null
  @State private libraryStats: LibraryStats = computeLibraryStats([])

  aboutToAppear(): void {
    this.libraries = getBuiltinPuzzleLibraries()
    this.activePuzzle = loadActivePuzzle(getContext(this))
    if (this.libraries.length > 0) {
      this.switchLibrary(this.libraries[0].id)
    }
  }

  private getString(name: string): string {
    return getContext(this).resourceManager.getStringByNameSync(name)
  }

  private switchLibrary(libraryId: string): void {
    this.selectedLibraryId = libraryId
    this.puzzles = getBuiltinPuzzleEntriesWithProgress(getContext(this), libraryId)
    this.libraryStats = computeLibraryStats(this.puzzles)
  }

  private getSelectedLibrary(): PuzzleLibrary | null {
    for (const library of this.libraries) {
      if (library.id === this.selectedLibraryId) {
        return library
      }
    }
    return null
  }

  private getPuzzleStatusLabel(status: PuzzleStatus): string {
    if (status === 'completed') {
      return this.getString('library_status_completed')
    }
    if (status === 'in_progress') {
      return this.getString('library_status_in_progress')
    }
    return this.getString('library_status_new')
  }

  private startPuzzle(puzzle: PuzzleEntry): void {
    if (hasSavedGame(getContext(this))) {
      clearSave(getContext(this))
    }
    saveActivePuzzle(getContext(this), this.selectedLibraryId, puzzle.index)
    router.pushUrl({
      url: 'pages/GamePage',
      params: {
        importedPuzzle: puzzle.puzzle81,
        importedDifficulty: puzzle.difficulty,
      },
    })
  }

  private isActivePuzzle(puzzle: PuzzleEntry): boolean {
    return this.activePuzzle !== null &&
      this.activePuzzle.libraryId === this.selectedLibraryId &&
      this.activePuzzle.puzzleIndex === puzzle.index
  }

  @Builder
  LibraryChip(library: PuzzleLibrary) {
    const isActive = this.selectedLibraryId === library.id
    Column({ space: 4 }) {
      Text(library.name)
        .fontSize(14)
        .fontWeight(isActive ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(isActive ? Colors.primaryText : Colors.titleText)
      Text(`${library.puzzleCount} ${this.getString('library_count_suffix')}`)
        .fontSize(11)
        .fontColor(isActive ? Colors.primaryText : Colors.subtitleText)
    }
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .borderRadius(12)
    .backgroundColor(isActive ? Colors.primaryBtn : Colors.secondaryBtn)
    .borderWidth(1)
    .borderColor(isActive ? Colors.primaryBtn : Colors.secondaryBorder)
    .onClick(() => {
      this.switchLibrary(library.id)
    })
  }

  @Builder
  PuzzleCard(puzzle: PuzzleEntry) {
    const isActivePuzzle = this.isActivePuzzle(puzzle)
    const difficulty = puzzle.difficulty ?? Difficulty.EASY
    const difficultyConfig = getDifficultyConfig(difficulty)
    Row() {
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(`#${puzzle.index + 1}`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.titleText)

          Text(this.getString(difficultyConfig.name))
            .fontSize(11)
            .fontColor(difficultyConfig.color)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(999)
            .backgroundColor(Colors.segmentBg)
        }

        Row({ space: 8 }) {
          Text(this.getPuzzleStatusLabel(puzzle.progress.status))
            .fontSize(12)
            .fontColor(Colors.subtitleText)

          Text(`${puzzle.progress.percentage}%`)
            .fontSize(12)
            .fontColor(Colors.subtitleText)

          if (isActivePuzzle) {
            Text(this.getString('library_active_badge'))
              .fontSize(11)
              .fontColor(Colors.primaryBtn)
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('→')
        .fontSize(18)
        .fontColor(Colors.subtitleText)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Colors.cellDefault)
    .borderRadius(12)
    .borderWidth(1)
    .borderColor(Colors.divider)
    .onClick(() => {
      this.startPuzzle(puzzle)
    })
  }

  build() {
    const selectedLibrary = this.getSelectedLibrary()
    const stats = this.libraryStats

    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(Colors.titleText)
          .padding({ right: 16 })
          .onClick(() => {
            router.back()
          })

        Column({ space: 2 }) {
          Text($r('app.string.library_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.titleText)

          Text($r('app.string.library_subtitle'))
            .fontSize(12)
            .fontColor(Colors.subtitleText)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()
      }
      .width('100%')
      .padding({ top: this.topRectHeight + 12, bottom: 12 })

      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.libraries, (library: PuzzleLibrary) => {
            this.LibraryChip(library)
          })
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')

      if (selectedLibrary !== null) {
        Column({ space: 8 }) {
          Text(selectedLibrary.description)
            .fontSize(13)
            .fontColor(Colors.subtitleText)
            .width('100%')

          Row({ space: 12 }) {
            Text(`${stats.completed}/${stats.total} ${this.getString('library_completed_summary')}`)
              .fontSize(12)
              .fontColor(Colors.titleText)
            Text(`${stats.inProgress} ${this.getString('library_in_progress_summary')}`)
              .fontSize(12)
              .fontColor(Colors.subtitleText)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Colors.secondaryBtn)
        .borderRadius(14)
        .borderWidth(1)
        .borderColor(Colors.secondaryBorder)
        .margin({ top: 12 })
      }

      Column({ space: 10 }) {
        Row() {
          Text($r('app.string.library_level_section'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.titleText)
          Blank()
          Text(`${this.puzzles.length}`)
            .fontSize(12)
            .fontColor(Colors.subtitleText)
        }
        .width('100%')

        if (this.puzzles.length === 0) {
          Text($r('app.string.library_empty'))
            .fontSize(13)
            .fontColor(Colors.subtitleText)
            .width('100%')
            .padding({ top: 20, bottom: 20 })
        } else {
          List({ space: 10 }) {
            ForEach(this.puzzles, (puzzle: PuzzleEntry) => {
              ListItem() {
                this.PuzzleCard(puzzle)
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.None)
        }
      }
      .width('100%')
      .margin({ top: 16, bottom: this.bottomRectHeight + 16 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: Sizes.pagePadding, right: Sizes.pagePadding })
    .backgroundColor(Colors.pageBg)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
