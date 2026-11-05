/**
 * 四步交互教学，使用真实手势键与独立练习数据。
 * 关闭通知归页面所有；本组件不写设置、不修改正式游戏或存档。
 */
import { KeyCode } from '@kit.InputKit'
import { ColorsConfig, GestureDirection, getThemeColors } from '../constants/GameConstants'
import { PAPER_DIGIT_FONT_FAMILY, PAPER_DIGIT_GIVEN_WEIGHT } from '../constants/Typography'
import { GestureKey } from './GestureKey'
import { formatStr, getLocalizedString } from '../utils/I18nHelper'
import { TUTORIAL_GRID, TUTORIAL_FIRST_CELL, TUTORIAL_NOTE_CELL, TUTORIAL_FINAL_CELL,
  createTutorialValues, createTutorialNotes, fillTutorialCandidates, fillTutorialDigit } from './GestureTutorialModel'

const TUTORIAL_STEPS: number = 4
function tutorialCellIndices(): number[] {
  const indices: number[] = []
  for (let index = 0; index < TUTORIAL_GRID.totalCells; index++) indices.push(index)
  return indices
}
const TUTORIAL_CELLS: number[] = tutorialCellIndices()

@Component
export struct GestureGuideOverlay {
  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') private isDarkMode: boolean = false
  @StorageProp('topRectHeight') private topRectHeight: number = 0
  @StorageProp('bottomRectHeight') private bottomRectHeight: number = 0
  @StorageProp('leftRectWidth') private leftRectWidth: number = 0
  @StorageProp('rightRectWidth') private rightRectWidth: number = 0
  @State private showKeyboard: boolean = false
  @State private step: number = 0
  @State private stepDone: boolean = false
  @State private values: number[] = createTutorialValues()
  @State private notes: number[][] = createTutorialNotes()
  @State private selectedCell: number = TUTORIAL_FIRST_CELL
  @State private clearedCells: number[] = []
  @State private feedbackKey: string = ''
  @State private gestureActive: boolean = false
  @State private contentWidth: number = 0
  @State private contentHeight: number = 0

  onDismiss: () => void = () => {}

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  private text(key: string): string {
    return getLocalizedString(getContext(this), key, this.localeRevision)
  }

  private boardSize(): number {
    return this.contentWidth < 520 && this.contentHeight > 0 && this.contentHeight < 430 ? 152 : 184
  }

  private enterStep(step: number): void {
    this.step = step
    this.stepDone = false
    this.feedbackKey = ''
    this.clearedCells = []
    this.gestureActive = false
    const values = createTutorialValues()
    if (step > 0) values[TUTORIAL_FIRST_CELL] = 1
    const notes = step >= 3 ? fillTutorialCandidates(values) : createTutorialNotes()
    if (step === 2) notes[TUTORIAL_NOTE_CELL] = [3]
    this.values = values
    this.notes = notes
    this.selectedCell = step === 0 ? TUTORIAL_FIRST_CELL : (step === 3 ? TUTORIAL_FINAL_CELL : TUTORIAL_NOTE_CELL)
  }

  private nextStep(): void {
    if (this.step < TUTORIAL_STEPS - 1) this.enterStep(this.step + 1)
    else this.onDismiss()
  }

  private handleGesture(digit: number, direction: GestureDirection): void {
    if (this.stepDone) return
    if (this.step === 0) {
      if (digit !== 1 || direction !== GestureDirection.TAP) {
        this.feedbackKey = 'tutorial_try_tap_one'
        return
      }
      const result = fillTutorialDigit(this.values, this.notes, TUTORIAL_FIRST_CELL, digit)
      this.values = result.values
      this.notes = result.notes
      this.stepDone = true
      this.feedbackKey = 'tutorial_tap_done'
    } else if (this.step === 1) {
      if (digit !== 3 || direction !== GestureDirection.UP) {
        this.feedbackKey = 'tutorial_try_swipe_three'
        return
      }
      const notes = createTutorialNotes()
      notes[TUTORIAL_NOTE_CELL] = [3]
      this.notes = notes
      this.stepDone = true
      this.feedbackKey = 'tutorial_note_done'
    } else if (this.step === 3) {
      if (digit !== 3 || direction !== GestureDirection.TAP) {
        this.feedbackKey = 'tutorial_try_tap_three'
        return
      }
      const result = fillTutorialDigit(this.values, this.notes, TUTORIAL_FINAL_CELL, digit)
      this.values = result.values
      this.notes = result.notes
      this.clearedCells = result.clearedCells
      this.stepDone = true
      this.feedbackKey = 'tutorial_clear_done'
    }
  }

  private completeCandidates(): void {
    this.notes = fillTutorialCandidates(this.values)
    this.stepDone = true
    this.feedbackKey = 'tutorial_candidates_done'
  }

  private remaining(digit: number): number {
    return TUTORIAL_GRID.gridSize - this.values.filter((value: number): boolean => value === digit).length
  }

  private cellLabel(index: number): string {
    const row = Math.floor(index / TUTORIAL_GRID.gridSize) + 1
    const col = index % TUTORIAL_GRID.gridSize + 1
    const content = this.values[index] > 0 ? this.values[index].toString() :
      (this.notes[index].length > 0 ? formatStr(this.text('tutorial_cell_notes'), this.notes[index].join(', ')) : this.text('tutorial_cell_empty'))
    return formatStr(this.text('tutorial_cell_label'), row, col, content) +
      (this.selectedCell === index ? this.text('tutorial_cell_selected') : '')
  }

  private feedback(): string {
    if (this.feedbackKey === 'tutorial_clear_done') {
      return formatStr(this.text(this.feedbackKey), this.clearedCells.length)
    }
    return this.feedbackKey ? this.text(this.feedbackKey) : this.text('tutorial_practice_safe')
  }

  @Builder
  private DemoBoard() {
    Column({ space: 8 }) {
      Grid() {
        ForEach(TUTORIAL_CELLS, (index: number) => {
          GridItem() {
            Stack() {
              if (this.values[index] > 0) {
                Text(this.values[index].toString())
                  .fontFamily(PAPER_DIGIT_FONT_FAMILY)
                  .fontFeature('"lnum" 1, "tnum" 1')
                  .fontWeight(PAPER_DIGIT_GIVEN_WEIGHT, { enableVariableFontWeight: true })
                  .fontSize(27)
                  .fontColor(this.getPalette().titleText)
              } else {
                Grid() {
                  ForEach(TUTORIAL_GRID.digits, (digit: number) => {
                    GridItem() {
                      Text(this.notes[index].includes(digit) ? digit.toString() : '')
                        .fontSize(12)
                        .fontColor(this.getPalette().textNote)
                    }
                  }, (digit: number) => digit.toString())
                }
                .columnsTemplate('1fr '.repeat(TUTORIAL_GRID.boxCols).trim())
                .rowsTemplate('1fr '.repeat(TUTORIAL_GRID.boxRows).trim())
                .padding(5)
                .width('100%')
                .height('100%')
              }
            }
            .width('100%')
            .height('100%')
            .backgroundColor(this.selectedCell === index ? this.getPalette().cellSelected :
              (this.clearedCells.includes(index) ? this.getPalette().cellHighlight : this.getPalette().boardBg))
            .border({
              width: {
                left: index % TUTORIAL_GRID.gridSize === 0 ? 1 : 0,
                top: index < TUTORIAL_GRID.gridSize ? 1 : 0,
                right: (index % TUTORIAL_GRID.gridSize + 1) % TUTORIAL_GRID.boxCols === 0 ? 1 : 0.5,
                bottom: (Math.floor(index / TUTORIAL_GRID.gridSize) + 1) % TUTORIAL_GRID.boxRows === 0 ? 1 : 0.5,
              },
              color: this.getPalette().cellBorderBold,
            })
            .accessibilityText(this.cellLabel(index))
          }
        }, (index: number) => index.toString())
      }
      .columnsTemplate('1fr '.repeat(TUTORIAL_GRID.gridSize).trim())
      .rowsTemplate('1fr '.repeat(TUTORIAL_GRID.gridSize).trim())
      .width(this.boardSize())
      .height(this.boardSize())
      Text($r('app.string.tutorial_board_caption'))
        .fontSize(12)
        .fontColor(this.getPalette().subtitleText)
    }
    .width(this.boardSize())
  }

  @Builder
  private PracticeControls() {
    Column({ space: 12 }) {
      if (this.step === 2) {
        Button($r('app.string.tutorial_fill_candidates'), { type: ButtonType.Normal })
          .id('tutorial-auto-candidates')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontColor(this.getPalette().primaryText)
          .backgroundColor(this.getPalette().primaryBtn)
          .borderRadius(6)
          .enabled(!this.stepDone)
          .onClick(() => { this.completeCandidates() })
        Text($r('app.string.tutorial_candidates_setting'))
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.getPalette().subtitleText)
          .width('100%')
      } else {
        Row({ space: 4 }) {
          ForEach(TUTORIAL_GRID.digits, (digit: number) => {
            Column() {
              GestureKey({
                digit: digit,
                remaining: this.remaining(digit),
                isComplete: false,
                onGesture: (value: number, direction: GestureDirection) => { this.handleGesture(value, direction) },
                onGestureDirectionChange: (direction: GestureDirection | null) => { this.gestureActive = direction !== null },
              })
            }
            .id(`tutorial-key-${digit}`)
            .layoutWeight(1)
            .height(64)
          }, (digit: number) => digit.toString())
        }
        .width('100%')
        if (this.step === 1 && !this.stepDone) {
          // 读屏用户可用等价按钮练习同一个候选动作，手势演示仍优先可见。
          Button($r('app.string.tutorial_note_alternative'), { type: ButtonType.Normal })
            .height(44)
            .fontSize(13)
            .fontColor(this.getPalette().subtitleText)
            .backgroundColor(Color.Transparent)
            .onClick(() => { this.handleGesture(3, GestureDirection.UP) })
        }
      }
      Text(this.feedback())
        .id('tutorial-feedback')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(this.stepDone ? this.getPalette().toolbarActive : this.getPalette().subtitleText)
        .width('100%')
      if (this.step === 3 && this.stepDone) {
        Row({ space: 8 }) {
          Text('2 3 4')
            .fontSize(16)
            .fontColor(this.getPalette().subtitleText)
          Image($r('app.media.paper_arrow_right'))
            .width(18)
            .height(18)
            .fillColor(this.getPalette().toolbarActive)
            .accessibilityLevel('no')
          Text(this.notes[TUTORIAL_NOTE_CELL].join(' '))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getPalette().titleText)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .accessibilityText($r('app.string.tutorial_candidate_change'))
      }
    }
    .width('100%')
  }

  @Builder
  private KeyItem(key: string, label: ResourceStr) {
    Row({ space: 12 }) {
      Text(key)
        .fontSize(12)
        .fontColor(this.getPalette().keyText)
        .width(84)
      Text(label)
        .fontSize(13)
        .fontColor(this.getPalette().subtitleText)
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  private MoreControls() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Text($r('app.string.tutorial_more_controls'))
          .fontSize(13)
          .fontColor(this.getPalette().subtitleText)
          .layoutWeight(1)
        Image($r('app.media.paper_arrow_right'))
          .width(16)
          .height(16)
          .fillColor(this.getPalette().subtitleText)
          .rotate({ angle: this.showKeyboard ? 90 : 0 })
          .accessibilityLevel('no')
      }
      .width('100%')
    }
    .id('guide-keyboard-toggle')
    .width('100%')
    .height(48)
    .padding(0)
    .borderRadius(0)
    .backgroundColor(Color.Transparent)
    .accessibilityText(this.showKeyboard ? $r('app.string.guide_keyboard_hide') : $r('app.string.guide_keyboard_show'))
    .onClick(() => { this.showKeyboard = !this.showKeyboard })
    if (this.showKeyboard) {
      Column({ space: 12 }) {
        Text($r('app.string.tutorial_more_gestures'))
          .fontSize(13)
          .lineHeight(20)
          .fontColor(this.getPalette().subtitleText)
          .width('100%')
        this.KeyItem('↑ ↓ ← →', $r('app.string.guide_key_arrows'))
        this.KeyItem('1–9', $r('app.string.guide_key_digits'))
        this.KeyItem('Del / 0', $r('app.string.guide_key_delete'))
        this.KeyItem('N / Tab', $r('app.string.guide_key_note'))
        this.KeyItem('Z / Y', $r('app.string.guide_key_undo_redo'))
        this.KeyItem('H', $r('app.string.guide_key_hint'))
        this.KeyItem('Space / P', $r('app.string.guide_key_pause'))
        this.KeyItem('Esc', $r('app.string.guide_key_esc'))
      }
      .width('100%')
      .padding({ bottom: 16 })
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 3 }) {
          Text($r('app.string.tutorial_title'))
            .fontSize(21)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getPalette().titleText)
          Text(`${this.step + 1} / ${TUTORIAL_STEPS}`)
            .fontSize(12)
            .fontColor(this.getPalette().subtitleText)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button($r('app.string.tutorial_skip'), { type: ButtonType.Normal })
          .id('tutorial-skip')
          .defaultFocus(true)
          .height(44)
          .fontSize(14)
          .fontColor(this.getPalette().subtitleText)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.onDismiss())
      }
      .width('100%')
      .padding({ bottom: 12 })

      // 练习位于说明开头；只滚动内容，关闭和下一步始终留在屏幕内。
      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Text(this.text(`tutorial_step_${this.step + 1}_title`))
              .fontSize(19)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getPalette().titleText)
              .width('100%')
            Text(this.text(`tutorial_step_${this.step + 1}_body`))
              .fontSize(14)
              .lineHeight(21)
              .fontColor(this.getPalette().subtitleText)
              .width('100%')
          }
          .width('100%')
          if (this.contentWidth >= 520) {
            Row({ space: 24 }) {
              this.DemoBoard()
              Column() { this.PracticeControls() }
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          } else {
            this.DemoBoard()
            this.PracticeControls()
          }
          this.MoreControls()
        }
        .width('100%')
        .padding({ top: 4, bottom: 8 })
      }
      .id('guide-scroll')
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .scrollable(this.gestureActive ? ScrollDirection.None : ScrollDirection.Vertical)
      .edgeEffect(EdgeEffect.None)
      .onAreaChange((_oldArea: Area, area: Area) => {
        this.contentWidth = Number(area.width)
        this.contentHeight = Number(area.height)
      })

      Row({ space: 12 }) {
        Button($r('app.string.tutorial_previous'), { type: ButtonType.Normal })
          .width(84)
          .height(48)
          .fontSize(14)
          .fontColor(this.getPalette().subtitleText)
          .backgroundColor(Color.Transparent)
          .enabled(this.step > 0)
          .onClick(() => { if (this.step > 0) this.enterStep(this.step - 1) })
        Button(this.text(this.step === TUTORIAL_STEPS - 1 ? 'tutorial_finish' : 'tutorial_next'), { type: ButtonType.Normal })
          .id('guide-dismiss')
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.getPalette().primaryBtn)
          .fontColor(this.getPalette().primaryText)
          .borderRadius(6)
          .enabled(this.stepDone)
          .onClick(() => this.nextStep())
      }
      .width('100%')
      .padding({ top: 12, bottom: 4 })
      .border({ width: { top: 0.5 }, color: this.getPalette().divider })
    }
    .constraintSize({ maxWidth: 760 })
    .width('100%')
    .height('100%')
    .padding({ left: this.leftRectWidth + 24, right: this.rightRectWidth + 24,
      top: this.topRectHeight + 12, bottom: this.bottomRectHeight + 12 })
    .backgroundColor(this.getPalette().pageBg)
    .focusable(true)
    .onAppear(() => {
      this.getUIContext().getFocusController().requestFocus('tutorial-skip')
    })
    .onKeyEvent((event: KeyEvent) => {
      if (event.type !== KeyType.Down) return
      if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
        this.onDismiss()
        event.stopPropagation()
      } else if (event.keyCode >= KeyCode.KEYCODE_1 && event.keyCode <= KeyCode.KEYCODE_4) {
        this.handleGesture(event.keyCode - KeyCode.KEYCODE_1 + 1, GestureDirection.TAP)
        event.stopPropagation()
      }
    })
  }
}
