/**
 * GestureGuideOverlay.ets — 首次使用手势引导遮罩
 *
 * 全屏半透明遮罩，在 3×3 键盘上方叠加手势操作图示：
 * 点击→填数、上滑→笔记、右滑→删除线、左滑→擦笔记。
 *
 * 仅首次进入游戏页时展示，点击"知道了"后不再出现。
 *
 * 参考：Doc 05 §3 首次引导, Doc 03 任务 1.20
 */
import { Colors } from '../constants/GameConstants'
import { saveSettings } from '../utils/SettingsStorage'
import { common } from '@kit.AbilityKit'

@Component
export struct GestureGuideOverlay {
  onDismiss: () => void = () => {}

  @Builder
  guideItem(emoji: string, label: ResourceStr, bgColor: string) {
    Row({ space: 12 }) {
      Text(emoji)
        .fontSize(28)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor(bgColor)
        .borderRadius(10)
      Text(label)
        .fontSize(16)
        .fontColor(Colors.titleText)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  build() {
    Column() {
      Column({ space: 20 }) {
        Text($r('app.string.guide_title'))
          .fontSize(22)
          .fontColor(Colors.titleText)
          .fontWeight(FontWeight.Bold)

        Column({ space: 4 }) {
          Text('⬆')
            .fontSize(24)
            .fontColor(Colors.diffMedium)
            .margin({ bottom: 2 })

          Row({ space: 4 }) {
            Text('⬅')
              .fontSize(24)
              .fontColor(Colors.diffExpert)

            Column() {
              Text('5')
                .fontSize(28)
                .fontColor(Colors.keyText)
                .fontWeight(FontWeight.Bold)
            }
            .width(56)
            .height(56)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(Colors.keyBg)
            .borderRadius(12)
            .shadow({ radius: 4, color: Colors.shadowColorLight, offsetX: 0, offsetY: 2 })

            Text('➡')
              .fontSize(24)
              .fontColor(Colors.diffHard)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)

          Text('👆')
            .fontSize(20)
            .margin({ top: 2 })
        }
        .margin({ top: 4, bottom: 8 })

        Column({ space: 14 }) {
          this.guideItem('👆', $r('app.string.guide_tap'), Colors.diffEasy)
          this.guideItem('⬆', $r('app.string.guide_up'), Colors.diffMedium)
          this.guideItem('➡', $r('app.string.guide_right'), Colors.diffHard)
          this.guideItem('⬅', $r('app.string.guide_left'), Colors.diffExpert)
        }
        .padding({ left: 24, right: 24 })

        Button($r('app.string.guide_got_it'))
          .type(ButtonType.Capsule)
          .width(200)
          .height(44)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(Colors.primaryBtn)
          .fontColor(Colors.primaryText)
          .margin({ top: 12 })
          .onClick(() => {
            AppStorage.setOrCreate('gestureGuideShown', true)
            saveSettings(getContext(this) as common.UIAbilityContext)
            this.onDismiss()
          })
      }
      .width('88%')
      .padding(28)
      .borderRadius(20)
      .backgroundColor(Colors.boardBg)
      .shadow({ radius: 20, color: Colors.shadowColor, offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Colors.modalOverlayMask)
  }
}
