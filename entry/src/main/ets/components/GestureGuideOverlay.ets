/**
 * GestureGuideOverlay.ets — 首次使用手势引导遮罩
 *
 * 全屏半透明遮罩，展示手势操作图示 + 键盘快捷键说明：
 * 点击→填数、上滑→笔记、右滑→删除线、左滑→擦笔记。
 * 键盘：方向键导航、N 笔记、H 提示、ESC 暂停等。
 *
 * 仅首次进入游戏页时展示，点击"知道了"后不再出现。
 * 键盘支持：ESC / Enter / Space 关闭引导
 *
 * 参考：Doc 05 §3 首次引导, Doc 03 任务 1.20
 */
import { KeyCode } from '@kit.InputKit'
import { Colors } from '../constants/GameConstants'
import { saveSettings } from '../utils/SettingsStorage'
import { common } from '@kit.AbilityKit'

@Component
export struct GestureGuideOverlay {
  onDismiss: () => void = () => {}

  private dismiss(): void {
    AppStorage.setOrCreate('gestureGuideShown', true)
    saveSettings(getContext(this) as common.UIAbilityContext)
    this.onDismiss()
  }

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

  @Builder
  keyItem(key: string, label: ResourceStr) {
    Row({ space: 10 }) {
      Text(key)
        .fontSize(12)
        .fontColor(Colors.keyText)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(Colors.keyBg)
        .borderRadius(6)
        .shadow({ radius: 2, color: Colors.shadowColorLight, offsetX: 0, offsetY: 1 })
      Text(label)
        .fontSize(14)
        .fontColor(Colors.subtitleText)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
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
          .margin({ top: 4, bottom: 4 })

          Column({ space: 14 }) {
            this.guideItem('👆', $r('app.string.guide_tap'), Colors.diffEasy)
            this.guideItem('⬆', $r('app.string.guide_up'), Colors.diffMedium)
            this.guideItem('➡', $r('app.string.guide_right'), Colors.diffHard)
            this.guideItem('⬅', $r('app.string.guide_left'), Colors.diffExpert)
          }
          .padding({ left: 24, right: 24 })

          // 键盘快捷键区域
          Column({ space: 4 }) {
            Divider()
              .color(Colors.cellBorderThin)
              .margin({ top: 4, bottom: 8 })

            Text($r('app.string.guide_keyboard_title'))
              .fontSize(18)
              .fontColor(Colors.titleText)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 4 })
          }

          Column({ space: 10 }) {
            this.keyItem('↑↓←→', $r('app.string.guide_key_arrows'))
            this.keyItem('1-9', $r('app.string.guide_key_digits'))
            this.keyItem('Del/0', $r('app.string.guide_key_delete'))
            this.keyItem('N/Tab', $r('app.string.guide_key_note'))
            this.keyItem('Z / Y', $r('app.string.guide_key_undo_redo'))
            this.keyItem('H', $r('app.string.guide_key_hint'))
            this.keyItem('Space/P', $r('app.string.guide_key_pause'))
            this.keyItem('ESC', $r('app.string.guide_key_esc'))
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
            .margin({ top: 8 })
            .onClick(() => {
              this.dismiss()
            })
        }
        .width('88%')
        .padding(28)
        .borderRadius(20)
        .backgroundColor(Colors.boardBg)
        .shadow({ radius: 20, color: Colors.shadowColor, offsetX: 0, offsetY: 8 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .constraintSize({ maxHeight: '90%' })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Colors.modalOverlayMask)
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      if (event.type === KeyType.Down) {
        // ESC / Enter / Space → 关闭引导
        if (event.keyCode === KeyCode.KEYCODE_ESCAPE ||
          event.keyCode === KeyCode.KEYCODE_ENTER ||
          event.keyCode === KeyCode.KEYCODE_NUMPAD_ENTER ||
          event.keyCode === KeyCode.KEYCODE_SPACE) {
          this.dismiss()
        }
      }
    })
  }
}
