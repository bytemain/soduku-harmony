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

@Entry
@Component
struct Index {
  @State selectedDifficulty: Difficulty = Difficulty.MEDIUM
  @State isStartPressed: boolean = false

  build() {
    Column() {
      // ==================== ① 标题区 ====================
      Column() {
        Text('🔢')
          .fontSize(Sizes.appIcon)

        Text('数  独')
          .fontSize(Sizes.titleFont)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.titleText)
          .margin({ top: 12 })

        Text('S U D O K U')
          .fontSize(Sizes.subtitleFont)
          .fontColor(Colors.subtitleText)
          .letterSpacing(4)
          .margin({ top: 4 })
      }
      .margin({ top: 80 })

      Blank()

      // ==================== ② 开始游戏按钮 ====================
      Button('▶  开始游戏')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(Sizes.btnHeight)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.primaryText)
        .backgroundColor(this.isStartPressed ? Colors.primaryPressed : Colors.primaryBtn)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.isStartPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.isStartPressed = false
          }
        })
        .onClick(() => {
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
          Text('统计')
            .fontSize(Sizes.bottomText)
            .fontColor(Colors.bottomText)
            .margin({ top: 2 })
        }
        .layoutWeight(1)

        Column() {
          Text('⚙️')
            .fontSize(Sizes.bottomIcon)
          Text('设置')
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
