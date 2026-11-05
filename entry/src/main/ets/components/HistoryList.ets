/** 棋局历史列表；宿主页提供系统安全区与返回后的刷新信号。 */
import { router } from '@kit.ArkUI'
import { ColorsConfig, getThemeColors, getDifficultyConfig } from '../constants/GameConstants'
import { JournalSession } from '../models/GameJournal'
import { listSessions } from '../utils/JournalStorage'
import { formatStr, getLocalizedString } from '../utils/I18nHelper'

const HISTORY_PAGE_SIZE: number = 30

@Component
export struct HistoryList {
  @Prop @Watch('refreshIfActive') active: boolean = true
  @Prop @Watch('refreshIfActive') refreshVersion: number = 0
  @Prop showBack: boolean = false
  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') private isDarkMode: boolean = false
  @State private sessions: JournalSession[] = []
  @State private loading: boolean = false
  @State private failed: boolean = false
  @State private hasMore: boolean = true
  private requestSerial: number = 0
  private retryFromStart: boolean = true

  private getPalette(): ColorsConfig { return getThemeColors(this.isDarkMode) }
  private text(key: string): string { return getLocalizedString(getContext(this), key, this.localeRevision) }

  aboutToAppear(): void { this.refreshIfActive() }
  aboutToDisappear(): void { this.requestSerial++ }

  private refreshIfActive(): void {
    if (this.active) this.loadSessions(true)
  }

  private async loadSessions(reset: boolean): Promise<void> {
    if (this.loading && !reset) return
    const serial = ++this.requestSerial
    this.loading = true
    this.failed = false
    try {
      const offset = reset ? 0 : this.sessions.length
      const entries = await listSessions(getContext(this), HISTORY_PAGE_SIZE, offset)
      if (serial !== this.requestSerial) return
      this.sessions = reset ? entries : [...this.sessions, ...entries]
      this.hasMore = entries.length === HISTORY_PAGE_SIZE
    } catch (_error) {
      if (serial === this.requestSerial) {
        this.retryFromStart = reset
        this.failed = true
      }
    } finally {
      if (serial === this.requestSerial) this.loading = false
    }
  }

  private title(session: JournalSession): string {
    const difficulty = session.puzzle.difficulty
    return difficulty >= 1 && difficulty <= 5 ? this.text(getDifficultyConfig(difficulty).name) : this.text('history_unknown_difficulty')
  }

  private variant(session: JournalSession): string {
    const type = session.puzzle.variantType
    if (type === 'diagonal' || type === 'jigsaw' || type === 'killer') return this.text(`variant_${type}`)
    return this.text('variant_standard')
  }

  private status(session: JournalSession): string {
    if (session.outcome === 'won') return this.text('history_status_completed')
    if (session.outcome === 'completed_failed') return this.text('history_status_ended')
    return this.text('history_status_active')
  }

  private date(timestamp: number): string {
    if (timestamp <= 0) return this.text('journal_time_unknown')
    const date = new Date(timestamp)
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }

  private elapsed(seconds: number): string {
    const total = Math.max(0, Math.floor(seconds))
    return `${Math.floor(total / 60).toString().padStart(2, '0')}:${(total % 60).toString().padStart(2, '0')}`
  }

  @Builder
  private SessionRow(session: JournalSession) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          Text(`${this.title(session)} · ${this.variant(session)}`)
            .fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor(this.getPalette().titleText)
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.status(session))
            .fontSize(12)
            .fontColor(this.getPalette().toolbarActive)
        }
        .width('100%')
        Text(session.kind === 'legacy' ? this.text('journal_legacy') :
          formatStr(this.text('history_session_details'), session.puzzle.gridSize, session.puzzle.gridSize,
            this.elapsed(session.scoreElapsedSeconds), session.nodeCount))
          .fontSize(13).fontColor(this.getPalette().subtitleText)
          .width('100%')
        Text(this.date(session.updatedAt))
          .fontSize(12).fontColor(this.getPalette().subtitleText)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .constraintSize({ minHeight: 100 })
    .padding({ left: 0, right: 0, top: 16, bottom: 16 })
    .borderRadius(0)
    .border({ width: { bottom: 0.5 }, color: this.getPalette().divider })
    .backgroundColor(Color.Transparent)
    .accessibilityText(`${this.title(session)}, ${this.variant(session)}, ${this.status(session)}, ${this.date(session.updatedAt)}`)
    .onClick(() => {
      router.pushUrl({ url: 'pages/HistoryPage', params: { journalSessionId: session.id, returnToCaller: true } })
    })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        if (this.showBack) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 6 }) {
              Image($r('app.media.paper_arrow_left'))
                .width(20).height(20)
                .fillColor(this.getPalette().titleText)
                .accessibilityLevel('no')
              Text($r('app.string.library_back_home'))
                .fontSize(14).fontColor(this.getPalette().titleText)
            }
          }
          .height(44)
          .padding({ left: 0, right: 8 })
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.library_back_home'))
          .onClick(() => { router.back() })
        }
        Text($r('app.string.history_title'))
          .fontSize(23).fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().titleText)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ bottom: 12 })
      Text($r('app.string.history_intro'))
        .fontSize(13).lineHeight(20)
        .fontColor(this.getPalette().subtitleText)
        .width('100%')
        .margin({ bottom: 12 })
      if (this.sessions.length === 0 && !this.loading && !this.failed) {
        Column({ space: 10 }) {
          Text($r('app.string.history_empty'))
            .fontSize(18).fontColor(this.getPalette().titleText)
          Text($r('app.string.history_empty_detail'))
            .fontSize(14).lineHeight(22).fontColor(this.getPalette().subtitleText)
            .textAlign(TextAlign.Center)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.sessions, (session: JournalSession) => {
            ListItem() { this.SessionRow(session) }
          }, (session: JournalSession) => session.id + ':' + session.updatedAt.toString())
          ListItem() {
            Column({ space: 10 }) {
              if (this.loading) {
                LoadingProgress().width(36).height(36)
              } else if (this.failed) {
                Text($r('app.string.journal_load_failed'))
                  .fontSize(13).fontColor(this.getPalette().textError)
                Button($r('app.string.journal_reload'), { type: ButtonType.Normal })
                  .height(44).fontSize(14).backgroundColor(Color.Transparent).fontColor(this.getPalette().toolbarActive)
                  .onClick(() => { this.loadSessions(this.retryFromStart) })
              } else if (this.hasMore) {
                Button($r('app.string.history_load_more'), { type: ButtonType.Normal })
                  .height(48).fontSize(14).backgroundColor(Color.Transparent).fontColor(this.getPalette().toolbarActive)
                  .onClick(() => { this.loadSessions(false) })
              }
            }
            .width('100%')
            .padding({ top: 12, bottom: 20 })
          }
        }
        .width('100%').layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%').height('100%')
    .constraintSize({ maxWidth: 760 })
    .padding({ top: 12, bottom: 16, left: 24, right: 24 })
  }
}
