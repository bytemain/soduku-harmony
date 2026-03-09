/**
 * SettingsPanel.ets — 设置面板（半模态弹窗）
 *
 * 游戏内和主页都可打开的设置面板。
 * 当前设置项：
 *   - 手动切换左/右手模式（覆盖自动检测）
 *
 * 参考：Doc 05 §6 左右手自适应
 */
import { Colors } from '../constants/GameConstants'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { saveSettings } from '../utils/SettingsStorage'
import { common } from '@kit.AbilityKit'

@Component
export struct SettingsPanel {
  @StorageLink('isLeftHand') isLeftHand: boolean = false
  @StorageLink('handModeManual') handModeManual: boolean = false
  @StorageLink('showCoordinates') showCoordinates: boolean = false
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  context?: common.UIAbilityContext

  onClose: () => void = () => {}

  build() {
    Column() {
      // 标题栏
      Row() {
        Text($r('app.string.settings_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.titleText)

        Blank()

        Text('✕')
          .fontSize(20)
          .fontColor(Colors.subtitleText)
          .onClick(() => this.onClose())
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 16 })

      // 分割线
      Divider().color('#E0E0E0').height(0.5)

      // 设置项列表
      Column() {
        // ====== 操作手设置 ======
        Text($r('app.string.settings_section_controls'))
          .fontSize(13)
          .fontColor(Colors.subtitleText)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ top: 20, bottom: 8 })

        // 自动检测开关
        Row() {
          Column() {
            Text($r('app.string.settings_auto_hand'))
              .fontSize(16)
              .fontColor(Colors.titleText)
            Text($r('app.string.settings_auto_hand_desc'))
              .fontSize(12)
              .fontColor(Colors.subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: !this.handModeManual })
            .selectedColor(Colors.primaryBtn)
            .onChange((isOn: boolean) => {
              this.handModeManual = !isOn
              hilog.info(0x0000, 'SettingsPanel', 'Auto-detect toggle: isOn=%{public}s, handModeManual=%{public}s',
                isOn.toString(), this.handModeManual.toString())
              if (this.context) {
                saveSettings(this.context)
              }
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })

        // 手动选择（仅手动模式显示）
        if (this.handModeManual) {
          Row() {
            Text($r('app.string.settings_hand_mode'))
              .fontSize(16)
              .fontColor(Colors.titleText)
              .layoutWeight(1)

            Row({ space: 0 }) {
              // 左手按钮
              Text($r('app.string.settings_left_hand'))
                .fontSize(14)
                .fontColor(this.isLeftHand ? Colors.primaryText : Colors.titleText)
                .textAlign(TextAlign.Center)
                .height(36)
                .padding({ left: 16, right: 16 })
                .backgroundColor(this.isLeftHand ? Colors.primaryBtn : '#F0F0F0')
                .borderRadius({ topLeft: 18, bottomLeft: 18 })
                .onClick(() => {
                  this.isLeftHand = true
                  hilog.info(0x0000, 'SettingsPanel', 'Manual select: LEFT, isLeftHand=%{public}s',
                    this.isLeftHand.toString())
                  if (this.context) {
                    saveSettings(this.context)
                  }
                })

              // 右手按钮
              Text($r('app.string.settings_right_hand'))
                .fontSize(14)
                .fontColor(!this.isLeftHand ? Colors.primaryText : Colors.titleText)
                .textAlign(TextAlign.Center)
                .height(36)
                .padding({ left: 16, right: 16 })
                .backgroundColor(!this.isLeftHand ? Colors.primaryBtn : '#F0F0F0')
                .borderRadius({ topRight: 18, bottomRight: 18 })
                .onClick(() => {
                  this.isLeftHand = false
                  hilog.info(0x0000, 'SettingsPanel', 'Manual select: RIGHT, isLeftHand=%{public}s',
                    this.isLeftHand.toString())
                  if (this.context) {
                    saveSettings(this.context)
                  }
                })
            }
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
        }

        // 当前模式预览
        Row() {
          Text('🖐️')
            .fontSize(18)
            .margin({ right: 8 })

          Text(this.isLeftHand ? $r('app.string.settings_current_left') : $r('app.string.settings_current_right'))
            .fontSize(14)
            .fontColor(Colors.primaryBtn)
        }
        .width('100%')
        .padding(12)
        .margin({ top: 8 })
        .backgroundColor(Colors.secondaryPress)
        .borderRadius(8)

        // ====== 显示设置 ======
        Text($r('app.string.settings_section_display'))
          .fontSize(13)
          .fontColor(Colors.subtitleText)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ top: 24, bottom: 8 })

        // 坐标轴开关
        Row() {
          Column() {
            Text($r('app.string.settings_show_coordinates'))
              .fontSize(16)
              .fontColor(Colors.titleText)
            Text($r('app.string.settings_show_coordinates_desc'))
              .fontSize(12)
              .fontColor(Colors.subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.showCoordinates })
            .selectedColor(Colors.primaryBtn)
            .onChange((isOn: boolean) => {
              this.showCoordinates = isOn
              hilog.info(0x0000, 'SettingsPanel', 'Show coordinates: %{public}s', isOn.toString())
              if (this.context) {
                saveSettings(this.context)
              }
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: this.bottomRectHeight + 24 })
    }
    .width('100%')
    .backgroundColor(Colors.boardBg)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}
