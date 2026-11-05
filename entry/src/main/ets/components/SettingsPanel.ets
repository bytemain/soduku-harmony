/**
 * SettingsPanel.ets — 首页设置页及游戏内设置弹层。
 * 当前设置项：
 *   - 手动切换左/右手模式（覆盖自动检测）
 *   - 助手：输入验证（填错立即标红）
 *
 * 参考：Doc 05 §6 左右手自适应
 */
import { getLocalizedString } from '../utils/I18nHelper'
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'
import { applyTheme } from '../constants/GameConstants'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { router, promptAction } from '@kit.ArkUI'
import { initHandDetection } from '../utils/HandDetector'
import { saveSettings } from '../utils/SettingsStorage'
import { setAppLanguage } from '../utils/LanguagePreferences'
import { common, ConfigurationConstant } from '@kit.AbilityKit'

@Component
export struct SettingsPanel {
  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  @StorageLink('isLeftHand') isLeftHand: boolean = false
  @StorageLink('handModeManual') handModeManual: boolean = true
  @StorageLink('showCoordinates') showCoordinates: boolean = false
  @StorageLink('validateInput') validateInput: boolean = true
  @StorageLink('showAutoNotes') showAutoNotes: boolean = false
  @StorageLink('auxButtonsOnTop') auxButtonsOnTop: boolean = false
  @StorageLink('themeMode') themeMode: string = 'system'
  @StorageProp('languageMode') private languageMode: string = 'system'
  @StorageProp('languageRestartRequired') private languageRestartRequired: boolean = false
  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  @State private isLanguageChanging: boolean = false
  @Prop embedded: boolean = false
  context?: common.UIAbilityContext

  onClose: () => void = () => {}

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

  private showLanguageError(): void {
    promptAction.showToast({
      message: getLocalizedString(getContext(this), 'settings_language_error', this.localeRevision),
      duration: 3000
    })
  }

  /** 保留当前页面和棋局，仅更新应用语言；等待期间避免重复提交。 */
  private async switchLanguage(mode: string): Promise<void> {
    if (this.isLanguageChanging || mode === this.languageMode) return
    const context = this.context
    if (!context) {
      this.showLanguageError()
      return
    }
    this.isLanguageChanging = true
    try {
      const applied = await setAppLanguage(context, mode)
      if (!applied) this.showLanguageError()
    } catch (_) {
      this.showLanguageError()
    } finally {
      this.isLanguageChanging = false
    }
  }

  @Builder
  LanguageOption(mode: string, label: Resource) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Text(label)
          .fontSize(15)
          .fontColor(this.getPalette().titleText)
          .textAlign(TextAlign.Start)
          .layoutWeight(1)
        if (this.languageMode === mode) {
          Image($r('app.media.paper_check'))
            .width(18)
            .height(18)
            .fillColor(this.getPalette().toolbarActive)
            .accessibilityLevel('no')
        }
      }
      .width('100%')
    }
    .id('settings-language-' + mode)
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .borderRadius(3)
    .backgroundColor(this.languageMode === mode ? this.getPalette().cellHighlight : Color.Transparent)
    .border({ width: { bottom: 0.5 }, color: this.getPalette().cardBorder })
    .enabled(!this.isLanguageChanging)
    .accessibilityText(label)
    .accessibilityDescription(this.languageMode === mode ?
      getLocalizedString(getContext(this), 'home_selected', this.localeRevision) : '')
    .onClick(() => { this.switchLanguage(mode) })
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
      .fontColor(isError ? this.getPalette().textError : (isGiven ? this.getPalette().textGiven : this.getPalette().textUser))
      .backgroundColor(isError ? this.getPalette().cellError : this.getPalette().cellDefault)
      .border({ width: 0.5, color: this.getPalette().cellBorderThin })
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
          .fontColor(this.getPalette().settingsValidateOnText)
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
        .border({ width: 1, color: this.getPalette().cellBorderBold, radius: 2 })

        Text($r('app.string.settings_validate_input_on_hint'))
          .fontSize(9)
          .fontColor(this.getPalette().subtitleText)
          .textAlign(TextAlign.Center)
          .width(72)
      }
      .alignItems(HorizontalAlign.Center)

      // --- 右侧：关闭状态 ---
      Column({ space: 4 }) {
        Text($r('app.string.settings_validate_input_off'))
          .fontSize(10)
          .fontColor(this.getPalette().subtitleText)
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
        .border({ width: 1, color: this.getPalette().cellBorderBold, radius: 2 })

        Text($r('app.string.settings_validate_input_off_hint'))
          .fontSize(9)
          .fontColor(this.getPalette().subtitleText)
          .textAlign(TextAlign.Center)
          .width(72)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(this.getPalette().cardBg)
    .border({ width: 1, color: this.getPalette().cardBorder })
    .borderRadius(8)
    .margin({ top: 10 })
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text($r('app.string.settings_title'))
          .fontSize(this.embedded ? 22 : 20)
          .fontWeight(this.embedded ? FontWeight.Medium : FontWeight.Bold)
          .fontColor(this.getPalette().titleText)

        Blank()

        if (!this.embedded) {
          Button({ type: ButtonType.Normal }) {
            Image($r('app.media.paper_close'))
              .width(24)
              .height(24)
              .fillColor(this.getPalette().subtitleText)
              .accessibilityLevel('no')
          }
          .id('settings-close')
          .width(44)
          .height(44)
          .padding(10)
          .borderRadius(8)
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.a11y_close'))
          .onClick(() => this.onClose())
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 16 })

      // 分割线
      Divider().color(this.getPalette().divider).height(0.5)

      // 设置项列表（可滚动）
      Scroll() {
      Column() {
      // ====== 外观设置 ======
        Text($r('app.string.settings_section_appearance'))
          .fontSize(13)
          .fontColor(this.getPalette().subtitleText)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ top: 20, bottom: 8 })

        // 主题切换
        Row() {
          Column() {
            Text($r('app.string.settings_theme'))
              .fontSize(16)
              .fontColor(this.getPalette().titleText)
            Text($r('app.string.settings_theme_desc'))
              .fontSize(12)
              .fontColor(this.getPalette().subtitleText)
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
            .fontColor(this.themeMode === 'system' ? this.getPalette().primaryText : this.getPalette().titleText)
            .textAlign(TextAlign.Center)
            .height(34)
            .layoutWeight(1)
            .backgroundColor(this.themeMode === 'system' ? this.getPalette().primaryBtn : this.getPalette().settingsInactiveBg)
            .borderRadius({ topLeft: 8, bottomLeft: 8 })
            .onClick(() => this.switchTheme('system'))

          // 细分割线
          Divider().vertical(true).height(20).color(this.getPalette().divider)

          Text($r('app.string.settings_theme_light'))
            .fontSize(13)
            .fontColor(this.themeMode === 'light' ? this.getPalette().primaryText : this.getPalette().titleText)
            .textAlign(TextAlign.Center)
            .height(34)
            .layoutWeight(1)
            .backgroundColor(this.themeMode === 'light' ? this.getPalette().primaryBtn : this.getPalette().settingsInactiveBg)
            .onClick(() => this.switchTheme('light'))

          // 细分割线
          Divider().vertical(true).height(20).color(this.getPalette().divider)

          Text($r('app.string.settings_theme_dark'))
            .fontSize(13)
            .fontColor(this.themeMode === 'dark' ? this.getPalette().primaryText : this.getPalette().titleText)
            .textAlign(TextAlign.Center)
            .height(34)
            .layoutWeight(1)
            .backgroundColor(this.themeMode === 'dark' ? this.getPalette().primaryBtn : this.getPalette().settingsInactiveBg)
            .borderRadius({ topRight: 8, bottomRight: 8 })
            .onClick(() => this.switchTheme('dark'))
        }
        .width('100%')
        .margin({ top: 8 })
        .borderRadius(8)
        .border({ width: 1, color: this.getPalette().cardBorder })
        .clip(true)

        // 应用语言独立于系统语言，名称保留各语言的原生写法。
        Column({ space: 4 }) {
          Text($r('app.string.settings_language'))
            .fontSize(16)
            .fontColor(this.getPalette().titleText)
          Text($r('app.string.settings_language_desc'))
            .fontSize(12)
            .lineHeight(18)
            .fontColor(this.getPalette().subtitleText)
            .margin({ bottom: 6 })
          this.LanguageOption('system', $r('app.string.settings_language_system'))
          this.LanguageOption('zh-Hans', $r('app.string.settings_language_zh'))
          this.LanguageOption('en', $r('app.string.settings_language_en'))
          if (this.languageRestartRequired) {
            Text($r('app.string.settings_language_restart'))
              .fontSize(12)
              .lineHeight(18)
              .fontColor(this.getPalette().subtitleText)
              .width('100%')
              .margin({ top: 6 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 20 })

        // ====== 操作手设置 ======
        Text($r('app.string.settings_section_controls'))
          .fontSize(13)
          .fontColor(this.getPalette().subtitleText)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ top: 20, bottom: 8 })

        // 自动检测开关
        Row() {
          Column() {
            Text($r('app.string.settings_auto_hand'))
              .fontSize(16)
              .fontColor(this.getPalette().titleText)
            Text($r('app.string.settings_auto_hand_desc'))
              .fontSize(12)
              .fontColor(this.getPalette().subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: !this.handModeManual })
            .selectedColor(this.getPalette().primaryBtn)
            .switchStyle({ unselectedColor: this.getPalette().switchTrackOff })
            .onChange((isOn: boolean) => {
              this.handModeManual = !isOn
              initHandDetection()
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
              .fontColor(this.getPalette().titleText)
              .layoutWeight(1)

            Row({ space: 0 }) {
              // 左手按钮
              Text($r('app.string.settings_left_hand'))
                .fontSize(14)
                .fontColor(this.isLeftHand ? this.getPalette().primaryText : this.getPalette().titleText)
                .textAlign(TextAlign.Center)
                .height(36)
                .padding({ left: 16, right: 16 })
                .backgroundColor(this.isLeftHand ? this.getPalette().primaryBtn : this.getPalette().settingsInactiveBg)
                .borderRadius({ topLeft: 8, bottomLeft: 8 })
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
                .fontColor(!this.isLeftHand ? this.getPalette().primaryText : this.getPalette().titleText)
                .textAlign(TextAlign.Center)
                .height(36)
                .padding({ left: 16, right: 16 })
                .backgroundColor(!this.isLeftHand ? this.getPalette().primaryBtn : this.getPalette().settingsInactiveBg)
                .borderRadius({ topRight: 8, bottomRight: 8 })
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
          Image($r('app.media.paper_hand'))
            .width(20)
            .height(20)
            .fillColor(this.getPalette().primaryBtn)
            .margin({ right: 8 })
            .scale({ x: this.isLeftHand ? -1 : 1 })
            .accessibilityLevel('no')

            Text(this.isLeftHand ? $r('app.string.settings_current_left') : $r('app.string.settings_current_right'))
            .fontSize(14)
            .fontColor(this.getPalette().primaryBtn)
        }
        .width('100%')
        .padding(12)
        .margin({ top: 8 })
        .backgroundColor(this.getPalette().secondaryPress)
        .borderRadius(8)

        // 工具按钮置顶开关
        Row() {
          Column() {
            Text($r('app.string.settings_aux_buttons_on_top'))
              .fontSize(16)
              .fontColor(this.getPalette().titleText)
            Text($r('app.string.settings_aux_buttons_on_top_desc'))
              .fontSize(12)
              .fontColor(this.getPalette().subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.auxButtonsOnTop })
            .selectedColor(this.getPalette().primaryBtn)
            .switchStyle({ unselectedColor: this.getPalette().switchTrackOff })
            .onChange((isOn: boolean) => {
              this.auxButtonsOnTop = isOn
              hilog.info(0x0000, 'SettingsPanel', 'Aux buttons on top: %{public}s', isOn.toString())
              if (this.context) {
                saveSettings(this.context)
              }
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })

        // ====== 显示设置 ======
        Text($r('app.string.settings_section_display'))
          .fontSize(13)
          .fontColor(this.getPalette().subtitleText)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ top: 24, bottom: 8 })

        // 坐标轴开关
        Row() {
          Column() {
            Text($r('app.string.settings_show_coordinates'))
              .fontSize(16)
              .fontColor(this.getPalette().titleText)
            Text($r('app.string.settings_show_coordinates_desc'))
              .fontSize(12)
              .fontColor(this.getPalette().subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.showCoordinates })
            .selectedColor(this.getPalette().primaryBtn)
            .switchStyle({ unselectedColor: this.getPalette().switchTrackOff })
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
          .fontColor(this.getPalette().subtitleText)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ top: 24, bottom: 8 })

        // 输入验证开关
        Row() {
          Column() {
            Text($r('app.string.settings_validate_input'))
              .fontSize(16)
              .fontColor(this.getPalette().titleText)
            Text($r('app.string.settings_validate_input_desc'))
              .fontSize(12)
              .fontColor(this.getPalette().subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.validateInput })
            .selectedColor(this.getPalette().primaryBtn)
            .switchStyle({ unselectedColor: this.getPalette().switchTrackOff })
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

        // 自动候选数开关
        Row() {
          Column() {
            Text($r('app.string.settings_auto_notes'))
              .fontSize(16)
              .fontColor(this.getPalette().titleText)
            Text($r('app.string.settings_auto_notes_desc'))
              .fontSize(12)
              .fontColor(this.getPalette().subtitleText)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.showAutoNotes })
            .selectedColor(this.getPalette().primaryBtn)
            .switchStyle({ unselectedColor: this.getPalette().switchTrackOff })
            .onChange((isOn: boolean) => {
              this.showAutoNotes = isOn
              hilog.info(0x0000, 'SettingsPanel', 'Show auto notes: %{public}s', isOn.toString())
              if (this.context) {
                saveSettings(this.context)
              }
            })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        Divider().margin({ top: 20, bottom: 12 })
        Button($r('app.string.privacy_support_title'))
          .width('100%')
          .height(44)
          .backgroundColor(this.getPalette().settingsInactiveBg)
          .fontColor(this.getPalette().titleText)
          .onClick(() => {
            if (!this.embedded) this.onClose()
            router.pushUrl({ url: 'pages/PrivacyPage' })
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: this.embedded ? 24 : this.bottomRectHeight + 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height(this.embedded ? '100%' : undefined)
    .backgroundColor(this.embedded ? this.getPalette().pageBg : this.getPalette().boardBg)
    .borderRadius({ topLeft: this.embedded ? 0 : 16, topRight: this.embedded ? 0 : 16 })
  }
}
