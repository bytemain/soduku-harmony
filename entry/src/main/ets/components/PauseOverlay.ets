/**
 * 暂停页：完整纸色背景、统一列表操作、固定的继续按钮。
 * 题目编号与复制工具默认收起；Escape 恢复，其他按键交由按钮处理。
 */
import { getLocalizedString } from '../utils/I18nHelper'
import { KeyCode } from '@kit.InputKit'
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'
import { PAPER_DIGIT_FONT_FAMILY, PAPER_DIGIT_USER_WEIGHT } from '../constants/Typography'

@Component
export struct PauseOverlay {
  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') private isDarkMode: boolean = false
  @StorageProp('topRectHeight') private topRectHeight: number = 0
  @StorageProp('bottomRectHeight') private bottomRectHeight: number = 0
  @StorageProp('leftRectWidth') private leftRectWidth: number = 0
  @StorageProp('rightRectWidth') private rightRectWidth: number = 0
  @State private showPuzzleInfo: boolean = false

  @Prop seedId: string = '-'
  @Prop puzzle81: string = ''
  @Prop difficultyLabel: string = '-'
  @Prop symmetryLabel: string = '-'
  @Prop displayTime: string = '00:00'

  onCopySeed: () => void = () => {}
  onCopyPuzzle: () => void = () => {}
  onResume: () => void = () => {}
  onRestart: () => void = () => {}
  onHelp: () => void = () => {}
  onQuit: () => void = () => {}

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  private getString(name: string): string {
    return getLocalizedString(getContext(this), name, this.localeRevision)
  }

  @Builder
  menuItem(icon: Resource, label: Resource, controlId: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        Image(icon)
          .width(23)
          .height(23)
          .fillColor(this.getPalette().toolbarIcon)
          .accessibilityLevel('no')
        Text(label)
          .fontSize(16)
          .fontColor(this.getPalette().titleText)
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        Image($r('app.media.paper_arrow_right'))
          .width(17)
          .height(17)
          .fillColor(this.getPalette().subtitleText)
          .accessibilityLevel('no')
      }
      .width('100%')
    }
    .id(controlId)
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ top: 18, bottom: 18 })
    .borderRadius(0)
    .border({ width: { bottom: 0.5 }, color: this.getPalette().divider })
    .backgroundColor(Color.Transparent)
    .accessibilityText(label)
    .onClick(() => action())
  }

  @Builder
  copyItem(label: Resource, value: string, controlId: string, action: () => void) {
    Column({ space: 8 }) {
      Text(value)
        .fontSize(12)
        .lineHeight(19)
        .fontColor(this.getPalette().subtitleText)
        .width('100%')
        .wordBreak(WordBreak.BREAK_ALL)
      Button({ type: ButtonType.Normal }) {
        Row({ space: 7 }) {
          Image($r('app.media.paper_copy'))
            .width(16)
            .height(16)
            .fillColor(this.getPalette().toolbarActive)
            .accessibilityLevel('no')
          Text(label)
            .fontSize(13)
            .fontColor(this.getPalette().toolbarActive)
        }
      }
      .id(controlId)
      .constraintSize({ minHeight: 44 })
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor(Color.Transparent)
      .border({ width: 0.5, color: this.getPalette().cardBorder })
      .borderRadius(6)
      .accessibilityText(label)
      .onClick(() => action())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Column() {
        // 页面内容可滚动，横屏或大字体不会把“继续游戏”挤出屏幕。
        Scroll() {
          Column() {
            Column({ space: 12 }) {
              Text($r('app.string.pause_title'))
                .fontSize(24)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getPalette().titleText)
              Text(this.displayTime)
                .id('pause-time')
                .fontFamily(PAPER_DIGIT_FONT_FAMILY)
                .fontFeature('"lnum" 1, "tnum" 1')
                .fontSize(42)
                .fontWeight(PAPER_DIGIT_USER_WEIGHT, { enableVariableFontWeight: true })
                .fontColor(this.getPalette().titleText)
                .accessibilityDescription($r('app.string.pause_info_time'))
              Text(this.difficultyLabel)
                .fontSize(14)
                .fontColor(this.getPalette().subtitleText)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: 8, bottom: 28 })
            .border({ width: { bottom: 1 }, color: this.getPalette().divider })

            this.menuItem($r('app.media.paper_undo'), $r('app.string.pause_restart'),
              'pause-restart', () => this.onRestart())
            this.menuItem($r('app.media.paper_help'), $r('app.string.pause_help'),
              'pause-help', () => this.onHelp())
            this.menuItem($r('app.media.paper_arrow_left'), $r('app.string.pause_quit'),
              'pause-quit', () => this.onQuit())

            Button({ type: ButtonType.Normal }) {
              Row({ space: 12 }) {
                Text($r('app.string.pause_info_title'))
                  .fontSize(14)
                  .fontColor(this.getPalette().subtitleText)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Start)
                Image($r('app.media.paper_arrow_right'))
                  .width(17)
                  .height(17)
                  .fillColor(this.getPalette().subtitleText)
                  .rotate({ angle: this.showPuzzleInfo ? 90 : 0 })
                  .accessibilityLevel('no')
              }
              .width('100%')
            }
            .id('pause-info-toggle')
            .width('100%')
            .constraintSize({ minHeight: 52 })
            .padding({ top: 16, bottom: 16 })
            .borderRadius(0)
            .backgroundColor(Color.Transparent)
            .accessibilityText(this.showPuzzleInfo ? $r('app.string.pause_info_hide') : $r('app.string.pause_info_show'))
            .onClick(() => { this.showPuzzleInfo = !this.showPuzzleInfo })

            if (this.showPuzzleInfo) {
              Column({ space: 18 }) {
                Text(`${this.getString('pause_info_symmetry')}: ${this.symmetryLabel}`)
                  .fontSize(12)
                  .fontColor(this.getPalette().subtitleText)
                  .width('100%')
                if (this.seedId !== '-') {
                  this.copyItem($r('app.string.a11y_copy_seed'),
                    `${this.getString('pause_info_seed')}: ${this.seedId}`,
                    'pause-copy-seed', () => this.onCopySeed())
                }
                if (this.puzzle81.length > 0) {
                  this.copyItem($r('app.string.a11y_copy_puzzle'),
                    `${this.getString('format_81string')}: ${this.puzzle81}`,
                    'pause-copy-puzzle', () => this.onCopyPuzzle())
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 4, bottom: 20 })
            }
          }
          .width('100%')
        }
        .id('pause-scroll')
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.None)

        Column() {
          Button($r('app.string.pause_resume'))
            .id('pause-resume')
            .type(ButtonType.Normal)
            .borderRadius(8)
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.getPalette().primaryBtn)
            .fontColor(this.getPalette().primaryText)
            .defaultFocus(true)
            .onClick(() => this.onResume())
        }
        .width('100%')
        .padding({ top: 16, bottom: 4 })
        .border({ width: { top: 0.5 }, color: this.getPalette().divider })
        .backgroundColor(this.getPalette().pageBg)
      }
      .constraintSize({ maxWidth: 600 })
      .width('100%')
      .height('100%')
      .padding({ left: this.leftRectWidth + 24, right: this.rightRectWidth + 24,
        top: this.topRectHeight + 16, bottom: this.bottomRectHeight + 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBg)
    .focusable(true)
    .onKeyEvent((event: KeyEvent) => {
      // 不捕获 Enter/Space，保留各按钮与展开控件的原生键盘激活行为。
      if (event.type === KeyType.Down && event.keyCode === KeyCode.KEYCODE_ESCAPE) {
        this.onResume()
        event.stopPropagation()
      }
    })
  }
}
