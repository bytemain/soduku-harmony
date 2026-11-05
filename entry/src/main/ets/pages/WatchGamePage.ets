import { router } from '@kit.ArkUI'
import { worker, MessageEvents, ErrorEvent } from '@kit.ArkTS'
import { ColorsConfig, Difficulty, getThemeColors } from '../constants/GameConstants'
import { GRID_9x9, VariantType } from '../models/VariantConfig'
import { WatchGameSession, WatchNavigationParams, watchCellIndex, watchBoxIndex } from '../utils/WatchGameSession'
import { loadWatchGame, saveWatchGame } from '../utils/WatchStorage'
import { getLocalizedString } from '../utils/I18nHelper'

@Entry
@Component
struct WatchGamePage {
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('appInForeground') @Watch('onForegroundChanged') appInForeground: boolean = true
  @State private values: number[] = []
  @State private givens: number[] = []
  @State private notes: number[] = []
  @State private view: string = 'loading'
  @State private selectedBox: number = 0
  @State private selectedCell: number = -1
  @State private noteMode: boolean = false
  @State private seconds: number = 0
  @State private hints: number = 0
  @State private filled: number = 0
  @State private undoCount: number = 0
  @State private progress: number = 0
  @State private messageKey: string = ''
  @State private saveFailed: boolean = false
  private session: WatchGameSession = new WatchGameSession()
  private rows: number[] = [0, 1, 2]
  private difficulty: number = Difficulty.EASY
  private ready: boolean = false
  private pageVisible: boolean = true
  private activeWorker: worker.ThreadWorker | null = null
  private workerTimeout: number = -1
  private timer: number = -1
  private pausedView: string = 'overview'
  private saveRevision: number = 0

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  private text(key: string): string {
    return getLocalizedString(getContext(this), key, this.localeRevision)
  }

  aboutToAppear(): void {
    const params = router.getParams() as WatchNavigationParams | undefined
    if (params && Number.isInteger(params.difficulty) && params.difficulty >= Difficulty.EASY &&
      params.difficulty <= Difficulty.HARD) this.difficulty = params.difficulty
    if (params && params.resume) {
      const saved = loadWatchGame(getContext(this))
      const restored = saved ? WatchGameSession.restore(saved) : null
      if (restored) {
        this.session = restored
        this.ready = true
        this.syncState()
        this.view = restored.isComplete() ? 'complete' : 'paused'
      } else {
        this.view = 'error'
        this.messageKey = 'watch_no_save'
      }
    } else {
      this.generate()
    }
  }

  onPageShow(): void {
    this.pageVisible = true
    // A hidden page never resumes its timer automatically.
  }

  onPageHide(): void {
    this.pageVisible = false
    this.pause()
    this.stopWorker()
  }

  aboutToDisappear(): void {
    this.pageVisible = false
    this.stopTimer()
    this.stopWorker()
    this.persist()
  }

  private onForegroundChanged(): void {
    if (!this.appInForeground) this.pause()
  }

  onBackPress(): boolean {
    if (this.view === 'digits') this.view = 'box'
    else if (this.view === 'box') this.view = 'overview'
    else if (this.view === 'tools') this.view = this.selectedCell >= 0 ? 'digits' : 'overview'
    else if (this.view === 'overview') this.pause()
    else {
      this.stopTimer()
      this.stopWorker()
      this.persist()
      return false
    }
    return true
  }

  private syncState(): void {
    this.values = this.session.data.values.slice()
    this.givens = this.session.data.givens.slice()
    this.notes = this.session.data.notes.slice()
    this.seconds = this.session.data.seconds
    this.hints = this.session.data.hints
    this.filled = this.session.filledCount()
    this.undoCount = this.session.data.undo.length
  }

  private persist(): void {
    if (!this.ready) return
    const revision = ++this.saveRevision
    saveWatchGame(getContext(this), this.session.data).then((saved: boolean) => {
      if (revision === this.saveRevision && this.pageVisible) this.saveFailed = !saved
    })
  }

  private startTimer(): void {
    this.stopTimer()
    if (!this.ready || !this.pageVisible || !this.appInForeground || this.session.isComplete()) return
    this.timer = setInterval(() => {
      if (!this.pageVisible || !this.appInForeground || this.view === 'paused' || this.session.isComplete()) return
      this.session.data.seconds++
      this.seconds = this.session.data.seconds
      if (this.seconds % 15 === 0) this.persist()
    }, 1000)
  }

  private stopTimer(): void {
    if (this.timer !== -1) clearInterval(this.timer)
    this.timer = -1
  }

  private pause(): void {
    this.stopTimer()
    if (this.view === 'loading') {
      this.stopWorker()
      this.view = 'error'
      this.messageKey = 'watch_generation_interrupted'
    } else if (this.ready && !this.session.isComplete() && this.view !== 'paused') {
      this.pausedView = this.view
      this.view = 'paused'
    }
    this.persist()
  }

  private resume(): void {
    if (!this.ready || !this.appInForeground) return
    this.view = this.session.isComplete() ? 'complete' : this.pausedView
    this.startTimer()
  }

  private stopWorker(): void {
    if (this.workerTimeout !== -1) clearTimeout(this.workerTimeout)
    this.workerTimeout = -1
    const previous = this.activeWorker
    this.activeWorker = null
    if (previous) {
      previous.onexit = (_code: number): void => {}
      previous.terminate()
    }
  }

  private resetWorkerTimeout(): void {
    if (this.workerTimeout !== -1) clearTimeout(this.workerTimeout)
    this.workerTimeout = setTimeout(() => this.generationFailed(), 60_000)
  }

  private generationFailed(): void {
    this.stopWorker()
    this.view = 'error'
    this.messageKey = 'watch_generation_failed'
  }

  private generate(): void {
    this.stopWorker()
    this.view = 'loading'
    this.progress = 0
    this.messageKey = ''
    let task: worker.ThreadWorker
    try {
      task = new worker.ThreadWorker('entry/ets/workers/PuzzleWorker.ets')
    } catch (_) {
      this.generationFailed()
      return
    }
    this.activeWorker = task
    this.resetWorkerTimeout()
    task.onmessage = (event: MessageEvents): void => {
      if (this.activeWorker !== task) return
      const result = event.data as Record<string, Object>
      const type = result['type'] as string
      if (type === 'progress') {
        this.progress = Math.max(this.progress, Math.min(100, result['progress'] as number))
        this.resetWorkerTimeout()
        return
      }
      if (type !== 'result') {
        this.generationFailed()
        return
      }
      const session = WatchGameSession.create(result['puzzle'] as number[][], result['solution'] as number[][],
        (result['actualDifficulty'] as number | undefined) ?? this.difficulty)
      if (!session) {
        this.generationFailed()
        return
      }
      this.stopWorker()
      this.session = session
      this.ready = true
      this.syncState()
      this.view = this.pageVisible && this.appInForeground ? 'overview' : 'paused'
      this.persist()
      if (this.view === 'overview') this.startTimer()
    }
    task.onerror = (_event: ErrorEvent): void => {
      if (this.activeWorker === task) this.generationFailed()
    }
    task.onexit = (_code: number): void => {
      if (this.activeWorker === task && this.view === 'loading') this.generationFailed()
    }
    try {
      task.postMessage({ type: 'generate', difficulty: this.difficulty,
        gridSize: GRID_9x9.gridSize, variantType: VariantType.STANDARD })
    } catch (_) {
      this.generationFailed()
    }
  }

  private finishAction(): void {
    this.syncState()
    this.persist()
    if (this.session.isComplete()) {
      this.stopTimer()
      this.view = 'complete'
    }
  }

  private selectCell(offset: number): void {
    const cell = watchCellIndex(this.selectedBox, offset)
    if (this.givens[cell] !== 0) {
      this.messageKey = 'watch_given_cell'
      return
    }
    this.selectedCell = cell
    this.messageKey = ''
    this.view = 'digits'
  }

  private enterDigit(digit: number): void {
    if (!this.session.input(this.selectedCell, digit, this.noteMode)) return
    this.messageKey = ''
    if (!this.noteMode) this.view = 'box'
    this.finishAction()
  }

  private undo(): void {
    if (!this.session.undo()) return
    this.messageKey = 'watch_undone'
    this.view = 'overview'
    this.finishAction()
    this.startTimer()
  }

  private hint(): void {
    const cell = this.session.hint(this.selectedCell)
    if (cell < 0) return
    this.selectedCell = cell
    this.selectedBox = watchBoxIndex(cell)
    this.messageKey = 'watch_hint_filled'
    this.view = 'box'
    this.finishAction()
  }

  private leave(): void {
    this.stopTimer()
    this.stopWorker()
    this.persist()
    router.back()
  }

  private timeText(): string {
    return Math.floor(this.seconds / 60).toString() + ':' + (this.seconds % 60).toString().padStart(2, '0')
  }

  private cellText(index: number, overview: boolean): string {
    const value = this.values[index] || 0
    if (value !== 0) return value.toString()
    if (overview) return this.notes[index] ? '·' : ''
    const mask = this.notes[index] || 0
    if (mask === 0) return ''
    let label = ''
    for (const digit of GRID_9x9.digits) {
      label += (mask & (1 << (digit - 1))) !== 0 ? digit.toString() : ' '
      if (digit % GRID_9x9.boxCols === 0 && digit < GRID_9x9.gridSize) label += '\n'
    }
    return label
  }

  private cellColor(index: number): string {
    if (this.givens[index]) return this.getPalette().textGiven
    if (this.values[index] && this.session.data.solution[index] !== this.values[index]) {
      return this.getPalette().textError
    }
    return this.values[index] ? this.getPalette().textUser : this.getPalette().textNote
  }

  private selectedLabel(): string {
    if (this.selectedCell < 0) return this.text('watch_choose_box')
    return this.text('watch_row') + (Math.floor(this.selectedCell / GRID_9x9.gridSize) + 1).toString() +
      ' ' + this.text('watch_column') + (this.selectedCell % GRID_9x9.gridSize + 1).toString()
  }

  private digitActive(digit: number): boolean {
    return this.noteMode ? ((this.notes[this.selectedCell] || 0) & (1 << (digit - 1))) !== 0 :
      this.values[this.selectedCell] === digit
  }

  @Builder
  menuButton(label: string, action: () => void) {
    Button(label, { type: ButtonType.Normal })
      .width(150).height(42).fontSize(15).borderRadius(12)
      .fontColor(this.getPalette().titleText)
      .backgroundColor(this.getPalette().cardBg)
      .border({ width: 1, color: this.getPalette().cardBorder })
      .onClick(action)
  }

  @Builder
  compactButton(label: string, action: () => void) {
    Button(label, { type: ButtonType.Normal })
      .width(52).height(30).padding(0).fontSize(12).borderRadius(10)
      .fontColor(this.getPalette().titleText)
      .backgroundColor(this.getPalette().cardBg)
      .border({ width: 1, color: this.getPalette().cardBorder })
      .onClick(action)
  }

  @Builder
  overview() {
    // 233vp round screen: height 196vp; outer footer corner radius 112.38vp < 116.5vp.
    Column({ space: 2 }) {
      Text(this.timeText() + ' · ' + this.filled.toString() + '/' + GRID_9x9.totalCells.toString())
        .width(100).height(18).fontSize(12).maxLines(1).textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.getPalette().subtitleText)
      Column() {
        ForEach(this.rows, (boxRow: number) => {
          Row() {
            ForEach(this.rows, (boxCol: number) => {
              Button({ type: ButtonType.Normal }) {
                Column() {
                  ForEach(this.rows, (row: number) => {
                    Row() {
                      ForEach(this.rows, (col: number) => {
                        Text(this.cellText(watchCellIndex(boxRow * 3 + boxCol, row * 3 + col), true))
                          .width(15).height(15).fontSize(11)
                          .textAlign(TextAlign.Center)
                          .fontColor(this.cellColor(watchCellIndex(boxRow * 3 + boxCol, row * 3 + col)))
                      }, (col: number) => col.toString())
                    }
                  }, (row: number) => row.toString())
                }
              }
              .width(48).height(48).padding(1).borderRadius(0)
              .backgroundColor(this.getPalette().boardBg)
              .border({ width: 0.5, color: this.getPalette().cellBorderBold })
              .accessibilityText(this.text('watch_box') + (boxRow * 3 + boxCol + 1).toString())
              .onClick(() => {
                this.selectedBox = boxRow * 3 + boxCol
                this.selectedCell = -1
                this.messageKey = ''
                this.view = 'box'
              })
            }, (boxCol: number) => boxCol.toString())
          }
        }, (boxRow: number) => boxRow.toString())
      }
      Row({ space: 6 }) {
        this.compactButton(this.text('watch_tools'), () => { this.view = 'tools' })
        this.compactButton(this.text('watch_pause'), () => this.pause())
      }
    }
  }

  @Builder
  boxView() {
    Column({ space: 5 }) {
      Text(this.messageKey ? this.text(this.messageKey) : this.text('watch_box') + (this.selectedBox + 1).toString())
        .width(100).height(18).fontSize(12).maxLines(1).textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.getPalette().subtitleText)
      Column({ space: 2 }) {
        ForEach(this.rows, (row: number) => {
          Row({ space: 2 }) {
            ForEach(this.rows, (col: number) => {
              Button({ type: ButtonType.Normal }) {
                Text(this.cellText(watchCellIndex(this.selectedBox, row * 3 + col), false))
                  .width(42).height(40).textAlign(TextAlign.Center)
                  .fontSize(this.values[watchCellIndex(this.selectedBox, row * 3 + col)] ? 24 : 11)
                  .lineHeight(this.values[watchCellIndex(this.selectedBox, row * 3 + col)] ? 28 : 12)
                  .maxLines(3)
                  .fontColor(this.cellColor(watchCellIndex(this.selectedBox, row * 3 + col)))
              }
                .width(44).height(44).padding(0).borderRadius(3)
                .backgroundColor(watchCellIndex(this.selectedBox, row * 3 + col) === this.selectedCell ?
                  this.getPalette().cellSelected : this.getPalette().boardBg)
                .border({ width: 0.5, color: this.getPalette().cellBorderThin })
                .onClick(() => this.selectCell(row * 3 + col))
            }, (col: number) => col.toString())
          }
        }, (row: number) => row.toString())
      }
      Row({ space: 6 }) {
        this.compactButton(this.text('watch_overview'), () => { this.view = 'overview' })
        this.compactButton(this.text('watch_tools'), () => { this.view = 'tools' })
      }
    }
  }

  @Builder
  digitsView() {
    Column({ space: 5 }) {
      Text(this.selectedLabel() + (this.noteMode ? ' · ' + this.text('watch_notes') : ''))
        .width(100).height(18).fontSize(12).maxLines(1).textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor(this.getPalette().subtitleText)
      Column({ space: 2 }) {
        ForEach(this.rows, (row: number) => {
          Row({ space: 2 }) {
            ForEach(this.rows, (col: number) => {
              Button((row * 3 + col + 1).toString(), { type: ButtonType.Normal })
                .width(44).height(44).padding(0).fontSize(24).borderRadius(8)
                .fontColor(this.digitActive(row * 3 + col + 1) ? this.getPalette().primaryText : this.getPalette().keyText)
                .backgroundColor(this.digitActive(row * 3 + col + 1) ? this.getPalette().primaryBtn : this.getPalette().keyBg)
                .border({ width: 1, color: this.getPalette().cardBorder })
                .onClick(() => this.enterDigit(row * 3 + col + 1))
            }, (col: number) => col.toString())
          }
        }, (row: number) => row.toString())
      }
      Row({ space: 6 }) {
        this.compactButton(this.text('common_back'), () => { this.view = 'box' })
        this.compactButton(this.text('watch_tools'), () => { this.view = 'tools' })
      }
    }
  }

  @Builder
  menuView() {
    Scroll() {
      Column({ space: 10 }) {
        if (this.view === 'tools') {
          Text(this.selectedLabel()).fontSize(14).fontColor(this.getPalette().subtitleText)
          this.menuButton(this.text(this.noteMode ? 'watch_notes_on' : 'watch_notes_off'), () => {
            this.noteMode = !this.noteMode
            this.view = this.selectedCell >= 0 ? 'digits' : 'overview'
          })
          if (this.selectedCell >= 0) {
            this.menuButton(this.text('watch_erase'), () => {
              if (this.session.erase(this.selectedCell)) this.finishAction()
              this.view = 'box'
            })
          }
          if (this.undoCount > 0) {
            this.menuButton(this.text('watch_undo'), () => this.undo())
          }
          this.menuButton(this.text('watch_hint'), () => this.hint())
          Text(this.text('watch_hint_description')).fontSize(12).lineHeight(18)
            .fontColor(this.getPalette().subtitleText).textAlign(TextAlign.Center)
          this.menuButton(this.text('watch_overview'), () => { this.view = 'overview' })
          this.menuButton(this.text('watch_pause'), () => this.pause())
        } else if (this.view === 'paused') {
          Text(this.text('watch_paused')).fontSize(18).fontColor(this.getPalette().titleText)
          Text(this.timeText()).fontSize(16).fontColor(this.getPalette().subtitleText)
          this.menuButton(this.text('watch_continue'), () => this.resume())
          this.menuButton(this.text('watch_save_exit'), () => this.leave())
        } else if (this.view === 'complete') {
          Text(this.text('watch_complete')).fontSize(21).fontWeight(FontWeight.Bold)
            .fontColor(this.getPalette().titleText)
          Text(this.timeText()).fontSize(20).fontColor(this.getPalette().textUser)
          Text(this.text('watch_hints_used') + ' ' + this.hints.toString()).fontSize(14)
            .fontColor(this.getPalette().subtitleText)
          this.menuButton(this.text('watch_home'), () => this.leave())
        } else {
          Text(this.messageKey ? this.text(this.messageKey) : '').fontSize(14).lineHeight(21).textAlign(TextAlign.Center)
            .fontColor(this.getPalette().titleText)
          this.menuButton(this.text('watch_retry'), () => this.generate())
          this.menuButton(this.text('watch_home'), () => this.leave())
        }
        if (this.saveFailed) {
          Text(this.text('watch_save_failed')).fontSize(12).lineHeight(18)
            .fontColor(this.getPalette().textError)
          this.menuButton(this.text('watch_retry_save'), () => this.persist())
        }
      }
      .width(156).padding({ top: 44, bottom: 44 })
    }
    .width('100%').height('100%').scrollBar(BarState.Off)
  }

  build() {
    Stack() {
      if (this.view === 'loading') {
        Column({ space: 12 }) {
          Text(this.text('watch_generating')).fontSize(15).fontColor(this.getPalette().titleText)
          Text(this.progress.toString() + '%').fontSize(22).fontColor(this.getPalette().textUser)
          this.menuButton(this.text('common_back'), () => this.leave())
        }.width(156)
      } else if (this.view === 'overview') {
        this.overview()
      } else if (this.view === 'box') {
        this.boxView()
      } else if (this.view === 'digits') {
        this.digitsView()
      } else {
        this.menuView()
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.getPalette().pageBg)
  }
}
