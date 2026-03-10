/**
 * SettingsPanel.ets — 设置面板（半模态弹窗）
 *
 * 游戏内和主页都可打开的设置面板。
 * 当前设置项：
 *   - 手动切换左/右手模式（覆盖自动检测）
 *   - 助手：输入验证（填错立即标红）
 *
 * 参考：Doc 05 §6 左右手自适应
 */
import { Colors } from '../constants/GameConstants'
import { applyTheme } from '../constants/GameConstants'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { saveSettings } from '../utils/SettingsStorage'
import { common, ConfigurationConstant } from '@kit.AbilityKit'

@Component
export struct SettingsPanel {
  @StorageLink('isLeftHand') isLeftHand: boolean = false
  @StorageLink('handModeManual') handModeManual: boolean = true
  @StorageLink('showCoordinates') showCoordinates: boolean = false
  @StorageLink('validateInput') validateInput: boolean = true
  @StorageLink('themeMode') themeMode: string = 'system'
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  context?: common.UIAbilityContext

  onClose: () => void = () => {}
  onAutoNotes: () => void = () => {}

  /**
   * 切换主题模式
   * 通过 setColorMode API 设置应用级颜色模式，
   * 系统会自动触发 onConfigurationUpdate 完成 applyTheme + AppStorage 更新。
   * 对于手动 light/dark，同时立即 applyTheme 确保即时生效。
   */
  private switchTheme(mode: string): void {
    if (mode === this.themeMode) return
    this.themeMode = mode
    hilog.info(0x0000, 'SettingsPanel', 'Switch theme to: %{public}s', mode)

    try {
      const appCtx = (this.context as common.UIAbilityContext).getApplicationContext()
      if (mode === 'light') {
        applyTheme(false)
        AppStorage.setOrCreate('isDarkMode', false)
        appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
      } else if (mode === 'dark') {
        applyTheme(true)
        AppStorage.setOrCreate('isDarkMode', true)
        appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
      } else {
        // 跟随系统
        appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
      }
    } catch (err) {
      hilog.error(0x0000, 'SettingsPanel', 'Failed to set colorMode: %{public}s', JSON.stringify(err))
    }

    if (this.context) {
      saveSettings(this.context)
    }
  }

  /**
   * 迷你数独演示格——用于图示说明助手功能
   * @param num 显示的数字
   * @param isError 是否标红（错误状态）
   * @param isGiven 是否为题目给定数字
   */
  @Builder
  MiniCell(num: string, isError: boolean, isGiven: boolean) {
    Text(num)
      .width(22)
      .height(22)
      .textAlign(TextAlign.Center)
      .fontSize(11)
      .fontWeight(isGiven ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(isError ? Colors.textError : (isGiven ? Colors.textGiven : Colors.textUser))
      .backgroundColor(isError ? Colors.cellError : Colors.cellDefault)
      .border({ width: 0.5, color: Colors.cellBorderThin })
  }

  /**
   * 助手功能图示——对比「开启」与「关闭」两种效果
   */
  @Builder
  AssistantIllustration() {
    Row({ space: 16 }) {
      // --- 左侧：开启状态 ---
      Column({ space: 4 }) {
        Text($r('app.string.settings_validate_input_on'))
          .fontSize(10)
          .fontColor(Colors.settingsValidateOnText)
          .fontWeight(FontWeight.Medium)

        // 3×3 mini grid：位置 (1,2) 填了错误的数字 7
        Column() {
          Row() {
            this.MiniCell('5', false, true)
            this.MiniCell('3', false, true)
            this.MiniCell(' ', false, false)
          }
          Row() {
            this.MiniCell('6', false, true)
            this.MiniCell(' ', false, false)
            this.MiniCell(' ', false, false)
          }
          Row() {
            this.MiniCell(' ', false, false)
            this.MiniCell('9', false, true)
            this.MiniCell('7', true, false)  // 错误格（填错 7，标红）
          }
        }
        .border({ width: 1, color: Colors.cellBorderBold, radius: 2 })

        Text($r('app.string.settings_validate_input_on_hint'))
          .fontSize(9)
          .fontColor(Colors.subtitleText)
          .textAlign(TextAlign.Center)
          .width(72)
      }
      .alignItems(HorizontalAlign.Center)

      // --- 右侧：关闭状态 ---
      Column({ space: 4 }) {
        Text($r('app.string.settings_validate_input_off'))
          .fontSize(10)
          .fontColor(Colors.subtitleText)
          .fontWeight(FontWeight.Medium)

        // 3×3 mini grid：同样填了 7，但不标红
        Column() {
          Row() {
            this.MiniCell('5', false, true)
            this.MiniCell('3', false, true)
            this.MiniCell(' ', false, false)
          }
          Row() {
            this.MiniCell('6', false, true)
            this.MiniCell(' ', false, false)
            this.MiniCell(' ', false, false)
          }
          Row() {
            this.MiniCell(' ', false, false)
            this.MiniCell('9', false, true)
            this.MiniCell('7', false, false)  // 同样填了 7，但不标红
          }
        }
        .border({ width: 1, color: Colors.cellBorderBold, radius: 2 })

        Text($r('app.string.settings_validate_input_off_hint'))
          .fontSize(9)
          .fontColor(Colors.subtitleText)
          .textAlign(TextAlign.Center)
          .width(72)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(Colors.pageBg)
    .borderRadius(8)
    .margin({ top: 10 })
  }

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
      Divider().color(Colors.divider).height(0.5)

      // 设置项列表（可滚动）
      Scroll() {
      Column() {
      // ====== 外观设置 ======
        Text($r('app.string.settings_section_appearance'))
          .fontSize(13)
          .fontColor(Colors.subtitleText)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ top: 20, bottom: 8 })

        // 主题切换
        Row() {
          Column() {
            Text($r('app.string.settings_theme'))
              .fontSize(16)
              .fontColor(Colors.titleText)
            Text($r('app.string.settings_theme_desc'))
              .fontSize(12)
              .fontColor(Colors.subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 12, bottom: 4 })

        // 三段式切换按钮
        Row({ space: 0 }) {
          Text($r('app.string.settings_theme_system'))
            .fontSize(13)
            .fontColor(this.themeMode === 'system' ? Colors.primaryText : Colors.titleText)
            .textAlign(TextAlign.Center)
            .height(34)
            .layoutWeight(1)
            .backgroundColor(this.themeMode === 'system' ? Colors.primaryBtn : Colors.settingsInactiveBg)
            .borderRadius({ topLeft: 17, bottomLeft: 17 })
            .onClick(() => this.switchTheme('system'))

          // 细分割线
          Divider().vertical(true).height(20).color(Colors.divider)

          Text($r('app.string.settings_theme_light'))
            .fontSize(13)
            .fontColor(this.themeMode === 'light' ? Colors.primaryText : Colors.titleText)
            .textAlign(TextAlign.Center)
            .height(34)
            .layoutWeight(1)
            .backgroundColor(this.themeMode === 'light' ? Colors.primaryBtn : Colors.settingsInactiveBg)
            .onClick(() => this.switchTheme('light'))

          // 细分割线
          Divider().vertical(true).height(20).color(Colors.divider)

          Text($r('app.string.settings_theme_dark'))
            .fontSize(13)
            .fontColor(this.themeMode === 'dark' ? Colors.primaryText : Colors.titleText)
            .textAlign(TextAlign.Center)
            .height(34)
            .layoutWeight(1)
            .backgroundColor(this.themeMode === 'dark' ? Colors.primaryBtn : Colors.settingsInactiveBg)
            .borderRadius({ topRight: 17, bottomRight: 17 })
            .onClick(() => this.switchTheme('dark'))
        }
        .width('100%')
        .margin({ top: 8 })
        .borderRadius(17)
        .clip(true)

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
            .switchStyle({ unselectedColor: Colors.switchTrackOff })
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
                .backgroundColor(this.isLeftHand ? Colors.primaryBtn : Colors.settingsInactiveBg)
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
                .backgroundColor(!this.isLeftHand ? Colors.primaryBtn : Colors.settingsInactiveBg)
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
            .switchStyle({ unselectedColor: Colors.switchTrackOff })
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

        // ====== 助手设置 ======
        Text($r('app.string.settings_section_assistant'))
          .fontSize(13)
          .fontColor(Colors.subtitleText)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ top: 24, bottom: 8 })

        // 输入验证开关
        Row() {
          Column() {
            Text($r('app.string.settings_validate_input'))
              .fontSize(16)
              .fontColor(Colors.titleText)
            Text($r('app.string.settings_validate_input_desc'))
              .fontSize(12)
              .fontColor(Colors.subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.validateInput })
            .selectedColor(Colors.primaryBtn)
            .switchStyle({ unselectedColor: Colors.switchTrackOff })
            .onChange((isOn: boolean) => {
              this.validateInput = isOn
              hilog.info(0x0000, 'SettingsPanel', 'Validate input: %{public}s', isOn.toString())
              if (this.context) {
                saveSettings(this.context)
              }
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })

        // 图示说明
        this.AssistantIllustration()

        // 自动候选数按钮
        Row() {
          Column() {
            Text($r('app.string.settings_auto_notes'))
              .fontSize(16)
              .fontColor(Colors.titleText)
            Text($r('app.string.settings_auto_notes_desc'))
              .fontSize(12)
              .fontColor(Colors.subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button($r('app.string.settings_auto_notes'))
            .fontSize(13)
            .fontColor(Colors.primaryText)
            .backgroundColor(Colors.primaryBtn)
            .height(34)
            .borderRadius(17)
            .onClick(() => {
              this.onAutoNotes()
              this.onClose()
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: this.bottomRectHeight + 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .backgroundColor(Colors.boardBg)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}
