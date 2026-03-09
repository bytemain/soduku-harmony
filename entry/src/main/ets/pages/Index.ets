/**
 * Index.ets — 主页（HomePage）
 *
 * 纵向居中布局：标题区 → 继续按钮 → 难度选择 → 开始按钮 → 底部入口。
 *
 * 参考：Doc 05 §一
 */
import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { Colors, Sizes, Difficulty, getDifficultyConfig } from '../constants/GameConstants'
import { DifficultySegment } from '../components/DifficultySegment'
import { SettingsPanel } from '../components/SettingsPanel'
import { hasSavedGame, clearSave, loadGame, GameSaveData } from '../utils/GameStorage'
import { Symmetry } from '../utils/SudokuGenerator'

class SymmetryOption {
  key: string = ''
  label: string = ''

  constructor(key: string, label: string) {
    this.key = key
    this.label = label
  }
}

const SYMMETRY_OPTIONS: SymmetryOption[] = [
  new SymmetryOption('auto', 'sym_auto'),
  new SymmetryOption(Symmetry.NONE, 'sym_none'),
  new SymmetryOption(Symmetry.ROTATIONAL_180, 'sym_rot180'),
  new SymmetryOption(Symmetry.ROTATIONAL_90, 'sym_rot90'),
  new SymmetryOption(Symmetry.MIRROR, 'sym_mirror'),
]

@Entry
@Component
struct Index {
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  @State selectedDifficulty: Difficulty = Difficulty.MEDIUM
  @State isStartPressed: boolean = false
  @State hasSave: boolean = false
  @State savedDifficulty: Difficulty = Difficulty.MEDIUM
  @State savedProgress: number = 0
  @State savedTime: string = '00:00'
  @State showSettings: boolean = false
  @State selectedSymmetry: string = 'auto'  // 'auto' | Symmetry values

  onPageShow(): void {
    this.hasSave = hasSavedGame(getContext(this))
    if (this.hasSave) {
      const saved = loadGame(getContext(this))
      if (saved) {
        this.savedDifficulty = saved.difficulty as Difficulty
        // Calculate progress: count filled cells / total non-given cells
        let filledCount = 0
        let totalEditable = 0
        for (const c of saved.cells) {
          const isGiven = (c.flags & 1) !== 0  // CellFlags.GIVEN = 1 << 0
          if (!isGiven) {
            totalEditable++
            if (c.value !== 0) {
              filledCount++
            }
          }
        }
        this.savedProgress = totalEditable > 0 ? Math.round((filledCount / totalEditable) * 100) : 0
        // Format time
        const m = Math.floor(saved.elapsedSeconds / 60)
        const s = saved.elapsedSeconds % 60
        this.savedTime = `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
      }
    }
  }

  @Builder
  settingsSheetBuilder() {
    SettingsPanel({
      context: getContext(this) as common.UIAbilityContext,
      onClose: () => {
        this.showSettings = false
      },
    })
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
      .margin({ top: this.topRectHeight + 40 })

      Blank()

      // ==================== ② 继续游戏卡片（有存档时显示） ====================
      if (this.hasSave) {
        Row() {
          // 左侧难度色条
          Column()
            .width(4)
            .height(36)
            .borderRadius(2)
            .backgroundColor(getDifficultyConfig(this.savedDifficulty).color)
            .margin({ right: 12 })

          // 中部信息
          Column() {
            Text($r('app.string.btn_continue'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.titleText)

            Row({ space: 8 }) {
              Text(getContext(this).resourceManager.getStringByNameSync(
                getDifficultyConfig(this.savedDifficulty).name
              ))
                .fontSize(12)
                .fontColor(getDifficultyConfig(this.savedDifficulty).color)

              Text('·')
                .fontSize(12)
                .fontColor(Colors.subtitleText)

              Text(`${this.savedProgress}%`)
                .fontSize(12)
                .fontColor(Colors.subtitleText)
            }
            .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 右侧时间
          Text(this.savedTime)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.subtitleText)
        }
        .width('100%')
        .height(Sizes.btnHeight + 8)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(Colors.secondaryBtn)
        .borderRadius(Sizes.btnRadius)
        .borderWidth(1.5)
        .borderColor(Colors.secondaryBorder)
        .onClick(() => {
          router.pushUrl({
            url: 'pages/GamePage',
            params: {
              difficulty: this.savedDifficulty,
            },
          })
        })
      }

      // ==================== ③ 难度选择器 ====================
      DifficultySegment({
        selectedDifficulty: $selectedDifficulty,
      })
        .margin({ top: Sizes.btnGap })

      // ==================== ③.5 对称模式选择 ====================
      Column() {
        Text($r('app.string.sym_section'))
          .fontSize(12)
          .fontColor(Colors.subtitleText)
          .margin({ bottom: 6 })

        Row({ space: 0 }) {
          ForEach(SYMMETRY_OPTIONS, (item: SymmetryOption) => {
            Text(getContext(this).resourceManager.getStringByNameSync(item.label))
              .fontSize(13)
              .fontColor(
                this.selectedSymmetry === item.key
                  ? Colors.primaryText
                  : Colors.subtitleText
              )
              .fontWeight(
                this.selectedSymmetry === item.key
                  ? FontWeight.Medium
                  : FontWeight.Normal
              )
              .backgroundColor(
                this.selectedSymmetry === item.key
                  ? Colors.primaryBtn
                  : 'transparent'
              )
              .borderRadius(8)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.selectedSymmetry = item.key
              })
          })
        }
        .width('100%')
        .backgroundColor(Colors.segmentBg)
        .borderRadius(12)
        .padding(3)
      }
      .width('100%')
      .margin({ top: 8 })

      // ==================== ④ 开始游戏按钮 ====================
      Button(this.hasSave ? $r('app.string.btn_new_game') : $r('app.string.btn_start'))
        .type(ButtonType.Capsule)
        .width('100%')
        .height(Sizes.btnHeight)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.primaryText)
        .backgroundColor(this.isStartPressed ? Colors.primaryPressed : Colors.primaryBtn)
        .margin({ top: Sizes.btnGap })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.isStartPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.isStartPressed = false
          }
        })
        .onClick(() => {
          if (this.hasSave) {
            clearSave(getContext(this))
          }
          router.pushUrl({
            url: 'pages/GamePage',
            params: {
              difficulty: this.selectedDifficulty,
              symmetry: this.selectedSymmetry === 'auto' ? undefined : this.selectedSymmetry,
            },
          })
        })

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
        .onClick(() => {
          router.pushUrl({ url: 'pages/StatsPage' })
        })

        Column() {
          Text('⚙️')
            .fontSize(Sizes.bottomIcon)
          Text($r('app.string.tab_settings'))
            .fontSize(Sizes.bottomText)
            .fontColor(Colors.bottomText)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .onClick(() => {
          this.showSettings = true
        })
      }
      .width('100%')
      .margin({ bottom: this.bottomRectHeight + 24 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: Sizes.pagePadding, right: Sizes.pagePadding })
    .backgroundColor(Colors.pageBg)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .bindSheet($$this.showSettings, this.settingsSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      backgroundColor: Colors.boardBg,
    })
  }
}
