/**
 * Index.ets — 主页（HomePage）
 *
 * 纵向居中布局：标题区 → 继续按钮 → 难度选择 → 开始按钮 → 底部入口。
 *
 * 参考：Doc 05 §一
 */
import { router, promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { pasteboard } from '@kit.BasicServicesKit'
import { Colors, Sizes, Difficulty, getDifficultyConfig, GRID_INDICES, BOX_SIZE, GRID_SIZE } from '../constants/GameConstants'
import { DifficultySegment } from '../components/DifficultySegment'
import { SettingsPanel } from '../components/SettingsPanel'
import { hasSavedGame, clearSave, loadGame, GameSaveData } from '../utils/GameStorage'
import { Symmetry, decodeSeedId } from '../utils/SudokuGenerator'
import { parseSudokuInput, ParseResult, countGivens, exportTo81String,
  getFormatDisplayNameKey, SudokuFormatType } from '../utils/SudokuFormat'
import { formatStr } from '../utils/I18nHelper'
import { evaluateDifficulty } from '../utils/DifficultyEvaluator'
import { hilog } from '@kit.PerformanceAnalysisKit'

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
  @StorageProp('isDarkMode') isDarkMode: boolean = false
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
  @State seedInput: string = ''
  /** 导入解析结果 */
  @State importResult: ParseResult | null = null
  /** 当前选中的导入题索引（SDM 多题时） */
  @State importSelectedIndex: number = 0

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

  /**
   * 尝试解析输入内容，更新 importResult 预览
   */
  private tryParseInput(value: string): void {
    const trimmed = value.trim()
    if (trimmed.length === 0) {
      this.importResult = null
      this.importSelectedIndex = 0
      return
    }

    // 种子 ID 不走 import 预览流程
    if (decodeSeedId(trimmed) !== null) {
      this.importResult = null
      return
    }

    try {
      const result = parseSudokuInput(trimmed)
      this.importResult = result
      this.importSelectedIndex = 0
      if (result.success) {
        hilog.info(0x0000, 'Index', 'Import parsed: format=%{public}s, count=%{public}d',
          result.format, result.puzzles.length)
      }
    } catch (e) {
      this.importResult = {
        success: false,
        format: 'unknown',
        puzzles: [],
        error: String(e)
      }
    }
  }

  /**
   * 迷你棋盘预览（9×9 缩略图）
   */

  private getString(name: string): string {
    return getContext(this).resourceManager.getStringByNameSync(name)
  }

  /**
   * 解析错误消息的 i18n key，返回本地化文本。
   * 错误格式为 "key" 或 "key:param1:param2..."
   */
  private resolveErrorMessage(error: string | undefined): string | undefined {
    if (!error) return undefined
    const parts = error.split(':')
    const key = parts[0]
    try {
      const template = this.getString(key)
      if (template === key) return error // 不是 resource key，原样返回
      const params = parts.slice(1)
      let result = template
      for (const p of params) {
        result = result.replace(/%[ds]/, p)
      }
      return result
    } catch (_e) {
      return error // 回退到原始文本
    }
  }

  @Builder
  MiniPreview(board: number[][]) {
    Column({ space: 0 }) {
      ForEach(GRID_INDICES, (r: number) => {
        Row({ space: 0 }) {
          ForEach(GRID_INDICES, (c: number) => {
            Text(board[r][c] > 0 ? board[r][c].toString() : '')
              .width(16)
              .height(16)
              .fontSize(9)
              .textAlign(TextAlign.Center)
              .fontColor(Colors.titleText)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(board[r][c] > 0 ? Colors.cellDefault : Colors.pageBg)
              .border({
                width: {
                  left: c % BOX_SIZE === 0 ? 1 : 0.3,
                  top: r % BOX_SIZE === 0 ? 1 : 0.3,
                  right: c === GRID_SIZE - 1 ? 1 : 0,
                  bottom: r === GRID_SIZE - 1 ? 1 : 0,
                },
                color: Colors.cellBorderBold,
              })
          })
        }
      })
    }
    .borderRadius(3)
    .clip(true)
    .alignSelf(ItemAlign.Center)
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

      // ==================== ② 继续游戏卡片（有存档时显示） ======================================
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

      // ==================== ③.6 谜题输入（种子 / 导入） ====================
      Row({ space: 8 }) {
        TextInput({ text: this.seedInput, placeholder: $r('app.string.import_placeholder') })
          .fontSize(13)
          .fontColor(Colors.titleText)
          .placeholderColor(Colors.subtitleText)
          .placeholderFont({ size: 12 })
          .backgroundColor(Colors.cellDefault)
          .borderRadius(8)
          .height(36)
          .layoutWeight(1)
          .padding({ left: 10, right: 10 })
          .onChange((value: string) => {
            this.seedInput = value
            this.tryParseInput(value)
          })

        Text('📋')
          .fontSize(20)
          .onClick(() => {
            const pb = pasteboard.getSystemPasteboard()
            const data = pb.getDataSync()
            const text = data.getPrimaryText()
            if (text) {
              this.seedInput = text
              this.tryParseInput(text)
            }
          })

        if (this.seedInput.length > 0) {
          Text('✕')
            .fontSize(16)
            .fontColor(Colors.subtitleText)
            .onClick(() => {
              this.seedInput = ''
              this.importResult = null
              this.importSelectedIndex = 0
            })
        }
      }
      .width('100%')
      .margin({ top: 8 })

      // ==================== 导入预览卡片 ====================
      if (this.importResult !== null && this.importResult.success && this.importResult.format !== 'seed') {
        Column({ space: 6 }) {
          // 格式 + 题数信息
          Row() {
            Text(`✅ ${this.getString(getFormatDisplayNameKey(this.importResult.format))}`)
              .fontSize(12)
              .fontColor(Colors.primaryBtn)
              .fontWeight(FontWeight.Medium)

            if (this.importResult.puzzles.length > 1) {
              Text(formatStr(this.getString('import_puzzle_count'), this.importResult.puzzles.length))
                .fontSize(12)
                .fontColor(Colors.subtitleText)
            }

            Blank()

            // 给定数计数
            if (this.importResult.puzzles.length > 0) {
              Text(formatStr(this.getString('import_givens_count'), countGivens(this.importResult.puzzles[this.importSelectedIndex].board)))
                .fontSize(11)
                .fontColor(Colors.subtitleText)
            }
          }
          .width('100%')

          // SDM 多题选择器
          if (this.importResult.puzzles.length > 1) {
            Row({ space: 4 }) {
              Text('◀')
                .fontSize(14)
                .fontColor(this.importSelectedIndex > 0 ? Colors.titleText : Colors.subtitleText)
                .onClick(() => {
                  if (this.importSelectedIndex > 0) this.importSelectedIndex--
                })

              Text(`#${this.importSelectedIndex + 1}`)
                .fontSize(13)
                .fontColor(Colors.titleText)
                .fontWeight(FontWeight.Medium)

              Text('▶')
                .fontSize(14)
                .fontColor(
                  this.importResult !== null && this.importSelectedIndex < this.importResult.puzzles.length - 1
                    ? Colors.titleText : Colors.subtitleText
                )
                .onClick(() => {
                  if (this.importResult !== null && this.importSelectedIndex < this.importResult.puzzles.length - 1) {
                    this.importSelectedIndex++
                  }
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }

          // 3x3 迷你预览
          if (this.importResult.puzzles.length > 0) {
            this.MiniPreview(this.importResult.puzzles[this.importSelectedIndex].board)
          }

          // 元数据显示
          if (this.importResult.puzzles.length > 0 &&
            this.importResult.puzzles[this.importSelectedIndex].metadata) {
            Column({ space: 2 }) {
              if (this.importResult.puzzles[this.importSelectedIndex].metadata?.description) {
                Text(this.importResult.puzzles[this.importSelectedIndex].metadata!.description!)
                  .fontSize(11)
                  .fontColor(Colors.subtitleText)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              if (this.importResult.puzzles[this.importSelectedIndex].metadata?.author) {
                Text(`— ${this.importResult.puzzles[this.importSelectedIndex].metadata!.author!}`)
                  .fontSize(10)
                  .fontColor(Colors.subtitleText)
                  .fontStyle(FontStyle.Italic)
              }
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Colors.secondaryBtn)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Colors.secondaryBorder)
        .margin({ top: 8 })
      } else if (this.importResult !== null && !this.importResult.success) {
        // 解析失败提示
        if (this.seedInput.trim().length > 0 && !decodeSeedId(this.seedInput.trim())) {
          Text(this.resolveErrorMessage(this.importResult.error) ?? this.getString('import_format_unknown'))
            .fontSize(11)
            .fontColor(Colors.textError)
            .width('100%')
            .margin({ top: 4 })
        }
      }

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
          if (this.seedInput.length > 0) {
            const trimmedInput = this.seedInput.trim()

            // 先试种子 ID
            const decoded = decodeSeedId(trimmedInput)
            if (decoded !== null) {
              if (this.hasSave) clearSave(getContext(this))
              router.pushUrl({
                url: 'pages/GamePage',
                params: {
                  difficulty: decoded.difficulty,
                  seedId: trimmedInput,
                },
              })
              return
            }

            // 再试标准格式导入
            const result = this.importResult
            if (result && result.success && result.puzzles.length > 0) {
              const puzzle = result.puzzles[this.importSelectedIndex]
              const puzzle81 = exportTo81String(puzzle.board)

              // 自动评估难度
              let diff: Difficulty = this.selectedDifficulty
              try {
                const grade = evaluateDifficulty(puzzle.board)
                diff = grade.difficulty
              } catch (_e) {
                // 评估失败时用选择的难度
              }

              if (this.hasSave) clearSave(getContext(this))
              router.pushUrl({
                url: 'pages/GamePage',
                params: {
                  importedPuzzle: puzzle81,
                  importedDifficulty: diff,
                },
              })
            } else {
              promptAction.showToast({ message: $r('app.string.import_invalid'), duration: 2000 })
            }
          } else {
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
          }
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
