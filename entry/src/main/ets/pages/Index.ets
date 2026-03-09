/**
 * Index.ets — 主页（HomePage）
 *
 * 纵向居中布局：标题区 → 开始按钮 → 难度选择 → 底部入口。
 *
 * 参考：Doc 05 §一
 */
import { router } from '@kit.ArkUI'
import { Colors, Sizes, Difficulty } from '../constants/GameConstants'
import { DifficultySegment } from '../components/DifficultySegment'
import { hasSavedGame, clearSave } from '../utils/GameStorage'

@Entry
@Component
struct Index {
  @State selectedDifficulty: Difficulty = Difficulty.MEDIUM
  @State isStartPressed: boolean = false
  @State hasSave: boolean = false

  onPageShow(): void {
    this.hasSave = hasSavedGame(getContext(this))
  }

  build() {
    Column() {
      // ==================== ① 标题区 ====================
      Column() {
        Text('🔢')
          .fontSize(Sizes.appIcon)

        Text($r('app.string.app_title'))
          .fontSize(Sizes.titleFont)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.titleText)
          .margin({ top: 12 })

        Text($r('app.string.app_subtitle'))
          .fontSize(Sizes.subtitleFont)
          .fontColor(Colors.subtitleText)
          .letterSpacing(4)
          .margin({ top: 4 })
      }
      .margin({ top: 80 })

      Blank()

      // ==================== ② 继续游戏按钮 ====================
      if (this.hasSave) {
        Button($r('app.string.btn_continue'))
          .type(ButtonType.Capsule)
          .width('100%')
          .height(Sizes.btnHeight)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.primaryText)
          .backgroundColor(Colors.primaryBtn)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/GamePage',
              params: {
                difficulty: this.selectedDifficulty,
              },
            })
          })
      }

      // ==================== ③ 开始游戏按钮 ====================
      Button(this.hasSave ? $r('app.string.btn_new_game') : $r('app.string.btn_start'))
        .type(ButtonType.Capsule)
        .width('100%')
        .height(Sizes.btnHeight)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.hasSave ? Colors.toolbarIcon : Colors.primaryText)
        .backgroundColor(this.hasSave ? Colors.keyBg : (this.isStartPressed ? Colors.primaryPressed : Colors.primaryBtn))
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.isStartPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.isStartPressed = false
          }
        })
        .onClick(() => {
          // 新游戏时清除存档
          if (this.hasSave) {
            clearSave(getContext(this))
          }
          router.pushUrl({
            url: 'pages/GamePage',
            params: {
              difficulty: this.selectedDifficulty,
            },
          })
        })

      // ==================== ④ 难度选择器 ====================
      DifficultySegment({
        selectedDifficulty: $selectedDifficulty,
      })
        .margin({ top: Sizes.btnGap })

      Blank()

      // ==================== ⑤ 底部入口 ====================
      Row() {
        Column() {
          Text('📊')
            .fontSize(Sizes.bottomIcon)
          Text($r('app.string.tab_stats'))
            .fontSize(Sizes.bottomText)
            .fontColor(Colors.bottomText)
            .margin({ top: 2 })
        }
        .layoutWeight(1)

        Column() {
          Text('⚙️')
            .fontSize(Sizes.bottomIcon)
          Text($r('app.string.tab_settings'))
            .fontSize(Sizes.bottomText)
            .fontColor(Colors.bottomText)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: Sizes.pagePadding, right: Sizes.pagePadding })
    .backgroundColor(Colors.pageBg)
  }
}
