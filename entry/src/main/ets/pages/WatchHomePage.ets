import { getLocalizedString } from '../utils/I18nHelper'
import { router } from '@kit.ArkUI'
import { ColorsConfig, Difficulty, getThemeColors } from '../constants/GameConstants'
import { loadWatchGame } from '../utils/WatchStorage'
import { WatchGameSession, WatchNavigationParams } from '../utils/WatchGameSession'

@Entry
@Component
struct WatchHomePage {
  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @State private difficulty: number = Difficulty.EASY
  @State private hasSave: boolean = false
  @State private completed: boolean = false
  @State private view: string = 'home'

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  private text(key: string): string {
    return getLocalizedString(getContext(this), key, this.localeRevision)
  }

  onPageShow(): void {
    const saved = loadWatchGame(getContext(this))
    this.hasSave = saved !== null
    const session = saved ? WatchGameSession.restore(saved) : null
    this.completed = session ? session.isComplete() : false
  }

  onBackPress(): boolean {
    if (this.view === 'home') return false
    this.view = 'home'
    return true
  }

  private difficultyText(): string {
    if (this.difficulty === Difficulty.MEDIUM) return this.text('diff_medium')
    if (this.difficulty === Difficulty.HARD) return this.text('diff_hard')
    return this.text('diff_easy')
  }

  private openGame(resume: boolean): void {
    const params = new WatchNavigationParams()
    params.difficulty = this.difficulty
    params.resume = resume
    this.view = 'home'
    router.pushUrl({ url: 'pages/WatchGamePage', params: params })
  }

  @Builder
  action(label: string, action: () => void) {
    Button(label, { type: ButtonType.Normal })
      .width(150)
      .height(42)
      .fontSize(15)
      .fontColor(this.getPalette().titleText)
      .backgroundColor(this.getPalette().cardBg)
      .border({ width: 1, color: this.getPalette().cardBorder })
      .borderRadius(12)
      .onClick(action)
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        if (this.view === 'privacy') {
          Text(this.text('watch_privacy_title'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getPalette().titleText)
          Text(this.text('watch_privacy_body'))
            .fontSize(14)
            .lineHeight(21)
            .fontColor(this.getPalette().titleText)
          Text('support@oranix.cn')
            .fontSize(12)
            .fontColor(this.getPalette().subtitleText)
          Text('https://sudoku.oranix.cn/privacy/')
            .fontSize(12)
            .fontColor(this.getPalette().subtitleText)
          this.action(this.text('common_back'), () => { this.view = 'home' })
        } else if (this.view === 'confirm') {
          Text(this.text('watch_replace_title'))
            .fontSize(17)
            .fontColor(this.getPalette().titleText)
          Text(this.text('watch_replace_body'))
            .fontSize(14)
            .lineHeight(21)
            .fontColor(this.getPalette().subtitleText)
          this.action(this.text('watch_new_game'), () => this.openGame(false))
          this.action(this.text('common_back'), () => { this.view = 'home' })
        } else {
          Text($r('app.string.app_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getPalette().titleText)
            .textAlign(TextAlign.Center)
          Text(this.text('watch_home_subtitle'))
            .fontSize(12)
            .fontColor(this.getPalette().subtitleText)
          if (this.hasSave) {
            this.action(this.text(this.completed ? 'watch_view_result' : 'watch_continue'), () => this.openGame(true))
          }
          this.action(this.text('watch_new_game'), () => {
            if (this.hasSave && !this.completed) this.view = 'confirm'
            else this.openGame(false)
          })
          this.action(this.text('watch_difficulty') + ' · ' + this.difficultyText(), () => {
            this.difficulty = this.difficulty >= Difficulty.HARD ? Difficulty.EASY : this.difficulty + 1
          })
          Text(this.text('watch_how_to_play'))
            .fontSize(12)
            .lineHeight(18)
            .textAlign(TextAlign.Center)
            .fontColor(this.getPalette().subtitleText)
          this.action(this.text('watch_privacy_title'), () => { this.view = 'privacy' })
        }
      }
      .width(156)
      .padding({ top: 44, bottom: 44 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(this.getPalette().pageBg)
  }
}
