/**
 * Index.ets — 主页（HomePage）
 *
 * 先继续当前一局；新局、导入与高级配置按需展开。
 *
 * 参考：Doc 05 §一
 */
import { router, promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { pasteboard } from '@kit.BasicServicesKit'
import { ColorsConfig, getThemeColors, Difficulty, DifficultyConfig, DIFFICULTY_CONFIGS, getDifficultyConfig } from '../constants/GameConstants'
import { SettingsPanel } from '../components/SettingsPanel'
import { HistoryList } from '../components/HistoryList'
import { StatsPanel } from '../components/StatsPanel'
import { HomeDisclosureRow } from '../components/HomeDisclosureRow'
import { hasSavedGame, loadGame } from '../utils/GameStorage'
import { Symmetry, decodeSeedId } from '../utils/SudokuGenerator'
import { parseSudokuInput, ParseResult, countGivens, exportTo81String,
  getFormatDisplayNameKey } from '../utils/SudokuFormat'
import { formatStr, getLocalizedString } from '../utils/I18nHelper'
import { GridConfig, GRID_4x4, GRID_6x6, GRID_9x9, VariantType } from '../models/VariantConfig'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { computeHomeLayout, HomeLayoutPlan } from '../utils/AdaptiveLayout'

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

class GridSizeOption {
  config: GridConfig
  label: string = ''

  constructor(config: GridConfig, label: string) {
    this.config = config
    this.label = label
  }
}

const HOME_VARIANTS: VariantType[] = [VariantType.STANDARD, VariantType.DIAGONAL, VariantType.JIGSAW, VariantType.KILLER]

const PREVIEW_INDICES: number[] = GRID_9x9.digits.map((digit: number): number => digit - 1)

const GRID_SIZE_OPTIONS: GridSizeOption[] = [
  new GridSizeOption(GRID_4x4, 'grid_size_4x4'),
  new GridSizeOption(GRID_6x6, 'grid_size_6x6'),
  new GridSizeOption(GRID_9x9, 'grid_size_9x9'),
]

@Entry
@Component
struct Index {
  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  @StorageProp('leftRectWidth') leftRectWidth: number = 0
  @StorageProp('rightRectWidth') rightRectWidth: number = 0
  @State private viewportWidth: number = 0
  @State private viewportHeight: number = 0
  @State selectedDifficulty: Difficulty = Difficulty.MEDIUM
  @State hasSave: boolean = false
  @State savedDifficulty: Difficulty = Difficulty.MEDIUM
  @State savedProgress: number = 0
  @State savedTime: string = '00:00'
  @State private selectedTab: number = 0
  @State private pageRevision: number = 0
  private tabController: TabsController = new TabsController()
  @State private showNewGame: boolean = false
  @State private showAdvancedOptions: boolean = false
  @State private showImport: boolean = false
  @State private showDifficulty: boolean = false
  @State private showVariants: boolean = false
  @State selectedSymmetry: string = 'auto'  // 'auto' | Symmetry values
  @State selectedGridSize: number = GRID_9x9.gridSize
  @State selectedVariant: VariantType = VariantType.STANDARD
  @State seedInput: string = ''
  /** 导入解析结果 */
  @State importResult: ParseResult | null = null
  /** 当前选中的导入题索引（SDM 多题时） */
  @State importSelectedIndex: number = 0

  onPageShow(): void {
    this.pageRevision++
    // 回到首页先呈现当前局；用户的配置值保留，展开状态复位。
    this.showNewGame = false
    this.showAdvancedOptions = false
    this.showImport = false
    this.showDifficulty = false
    this.showVariants = false
    this.hasSave = hasSavedGame(getContext(this))
    if (this.hasSave) {
      const saved = loadGame(getContext(this))
      if (saved) {
        this.savedDifficulty = saved.difficulty as Difficulty
        // 仅统计玩家可填写的格子。
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
        // 恢复本局累计用时。
        const m = Math.floor(saved.elapsedSeconds / 60)
        const s = saved.elapsedSeconds % 60
        this.savedTime = `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
      }
    }
  }

  onBackPress(): boolean {
    if (this.selectedTab === 0) return false
    this.tabController.changeIndex(0)
    return true
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
    return getLocalizedString(getContext(this), name, this.localeRevision)
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
      ForEach(PREVIEW_INDICES, (r: number) => {
        Row({ space: 0 }) {
          ForEach(PREVIEW_INDICES, (c: number) => {
            Text(board[r][c] > 0 ? board[r][c].toString() : '')
              .width(16)
              .height(16)
              .fontSize(9)
              .textAlign(TextAlign.Center)
              .fontColor(this.getPalette().titleText)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(board[r][c] > 0 ? this.getPalette().cellDefault : this.getPalette().pageBg)
              .border({
                width: {
                  left: c % GRID_9x9.boxCols === 0 ? 1 : 0.3,
                  top: r % GRID_9x9.boxRows === 0 ? 1 : 0.3,
                  right: c === GRID_9x9.gridSize - 1 ? 1 : 0,
                  bottom: r === GRID_9x9.gridSize - 1 ? 1 : 0,
                },
                color: this.getPalette().cellBorderBold,
              })
          })
        }
      })
    }
    .borderRadius(3)
    .clip(true)
    .alignSelf(ItemAlign.Center)
  }

  private getHomeLayout(): HomeLayoutPlan {
    return computeHomeLayout(this.viewportWidth, this.viewportHeight)
  }

  private variantName(type: VariantType): string {
    switch (type) {
      case VariantType.DIAGONAL: return 'variant_diagonal'
      case VariantType.JIGSAW: return 'variant_jigsaw'
      case VariantType.KILLER: return 'variant_killer'
      default: return 'variant_standard'
    }
  }

  private configSummary(): string {
    let summary = `${this.getString(this.variantName(this.selectedVariant))} · ${this.selectedGridSize} × ${this.selectedGridSize}`
    if (this.selectedSymmetry !== 'auto') {
      const option = SYMMETRY_OPTIONS.find((item: SymmetryOption) => item.key === this.selectedSymmetry)
      if (option) summary += ` · ${this.getString(option.label)}`
    }
    return summary
  }

  /** 新局和导入共用覆盖确认，展开配置本身不会清除存档。 */
  private confirmNewPuzzle(start: () => void): void {
    if (!this.hasSave) {
      start()
      return
    }
    AlertDialog.show({
      title: this.getString('home_replace_title'),
      message: this.getString('home_replace_message'),
      primaryButton: {
        value: this.getString('home_keep_current'),
        action: () => {},
      },
      secondaryButton: {
        value: this.getString('home_replace_confirm'),
        action: start,
      },
    })
  }

  private startNewGame(): void {
    this.confirmNewPuzzle(() => {
      router.pushUrl({
        url: 'pages/GamePage',
        params: {
          difficulty: this.selectedDifficulty,
          symmetry: this.selectedSymmetry === 'auto' ? undefined : this.selectedSymmetry,
          gridSize: this.selectedGridSize,
          variantType: this.selectedVariant,
        },
      })
    })
  }

  /** 导入是独立动作，不让折叠区里残留的文本影响新题配置。 */
  private startImportedGame(): void {
    const trimmedInput = this.seedInput.trim()
    const decoded = decodeSeedId(trimmedInput)
    if (decoded !== null) {
      this.confirmNewPuzzle(() => {
        router.pushUrl({
          url: 'pages/GamePage',
          params: {
            difficulty: decoded.difficulty,
            seedId: trimmedInput,
            gridSize: this.selectedGridSize,
            variantType: this.selectedVariant,
          },
        })
      })
      return
    }
    const result = this.importResult
    if (result && result.success && result.puzzles.length > 0) {
      const puzzle81 = exportTo81String(result.puzzles[this.importSelectedIndex].board)
      this.confirmNewPuzzle(() => {
        // 导入题始终由 Worker 按标准 9×9 拓扑检查。
        router.pushUrl({ url: 'pages/GamePage', params: { importedPuzzle: puzzle81 } })
      })
    } else {
      promptAction.showToast({ message: $r('app.string.import_invalid'), duration: 2000 })
    }
  }

  private pastePuzzle(): void {
    try {
      const text = pasteboard.getSystemPasteboard().getDataSync().getPrimaryText()
      if (text) {
        this.seedInput = text
        this.tryParseInput(text)
      } else {
        promptAction.showToast({ message: $r('app.string.home_clipboard_empty'), duration: 2000 })
      }
    } catch (_e) {
      promptAction.showToast({ message: $r('app.string.home_clipboard_unavailable'), duration: 2000 })
    }
  }

  @Builder
  private HomeHeader() {
    Row({ space: 12 }) {
      Image($r('app.media.startIcon'))
        .width(64)
        .height(64)
        .objectFit(ImageFit.Contain)
        .accessibilityLevel('no')
      Column({ space: 3 }) {
        Text($r('app.string.app_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getPalette().titleText)
        Text($r('app.string.home_tagline'))
          .fontSize(13)
          .fontColor(this.getPalette().subtitleText)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ResumeSection() {
    Column({ space: 12 }) {
      Text($r('app.string.home_in_progress'))
        .fontSize(13)
        .fontColor(this.getPalette().subtitleText)
        .width('100%')
      Text(this.getString(getDifficultyConfig(this.savedDifficulty).name))
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getPalette().titleText)
        .width('100%')
      Row({ space: 12 }) {
        Text(formatStr(this.getString('home_progress'), `${this.savedProgress}%`))
          .fontSize(14)
          .fontColor(this.getPalette().subtitleText)
        Text('·')
          .fontSize(14)
          .fontColor(this.getPalette().subtitleText)
          .accessibilityLevel('no')
        Text(formatStr(this.getString('home_elapsed'), this.savedTime))
          .fontSize(14)
          .fontColor(this.getPalette().subtitleText)
      }
      .width('100%')
      Button($r('app.string.home_resume'), { type: ButtonType.Normal })
        .width('100%')
        .height(52)
        .borderRadius(6)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getPalette().primaryText)
        .backgroundColor(this.getPalette().primaryBtn)
        .margin({ top: 8 })
        .onClick(() => {
          router.pushUrl({
            url: 'pages/GamePage',
            params: { difficulty: this.savedDifficulty, resumeSave: true },
          })
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private DifficultyPicker() {
    Column() {
      Text($r('app.string.home_difficulty'))
        .fontSize(13)
        .fontColor(this.getPalette().subtitleText)
        .width('100%')
        .margin({ bottom: 4 })
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(this.getString(getDifficultyConfig(this.selectedDifficulty).name))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getPalette().titleText)
            Text(this.getString(getDifficultyConfig(this.selectedDifficulty).descName))
              .fontSize(12)
              .fontColor(this.getPalette().subtitleText)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Image($r('app.media.paper_arrow_right'))
            .width(18)
            .height(18)
            .fillColor(this.getPalette().subtitleText)
            .rotate({ angle: this.showDifficulty ? -90 : 90 })
            .accessibilityLevel('no')
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: 64 })
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .borderRadius(6)
      .backgroundColor(this.getPalette().cardBg)
      .border({ width: 1, color: this.getPalette().cardBorder })
      .accessibilityText(`${this.getString('home_difficulty')}，${this.getString(getDifficultyConfig(this.selectedDifficulty).name)}`)
      .accessibilityDescription(this.showDifficulty ? $r('app.string.home_expanded') : $r('app.string.home_collapsed'))
      .onClick(() => { this.showDifficulty = !this.showDifficulty })

      if (this.showDifficulty) {
        Column() {
          ForEach(DIFFICULTY_CONFIGS, (config: DifficultyConfig) => {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 8 }) {
                Column({ space: 3 }) {
                  Text(this.getString(config.name))
                    .fontSize(15)
                    .fontColor(this.getPalette().titleText)
                  Text(this.getString(config.descName))
                    .fontSize(12)
                    .fontColor(this.getPalette().subtitleText)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                if (this.selectedDifficulty === config.level) {
                  Image($r('app.media.paper_check'))
                    .width(18)
                    .height(18)
                    .fillColor(this.getPalette().toolbarActive)
                    .accessibilityLevel('no')
                }
              }
              .width('100%')
            }
            .width('100%')
            .constraintSize({ minHeight: 58 })
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(0)
            .backgroundColor(this.selectedDifficulty === config.level ? this.getPalette().segmentSelected : Color.Transparent)
            .accessibilityText(this.getString(config.name))
            .accessibilityDescription(this.selectedDifficulty === config.level ? this.getString('home_selected') : this.getString(config.descName))
            .onClick(() => {
              this.selectedDifficulty = config.level
              this.showDifficulty = false
            })
          }, (config: DifficultyConfig) => config.level.toString())
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
      }
    }
    .width('100%')
  }

  @Builder
  private AdvancedOptions() {
    Column({ space: 16 }) {
      Column() {
        Text($r('app.string.home_variant'))
          .fontSize(13)
          .fontColor(this.getPalette().subtitleText)
          .width('100%')
        HomeDisclosureRow({
          labelKey: this.variantName(this.selectedVariant),
          expanded: this.showVariants,
          onToggle: () => { this.showVariants = !this.showVariants },
        })
        if (this.showVariants) {
          ForEach(HOME_VARIANTS, (variant: VariantType) => {
            Button(this.getString(this.variantName(variant)), { type: ButtonType.Normal })
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontWeight(this.selectedVariant === variant ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.getPalette().titleText)
              .backgroundColor(this.selectedVariant === variant ? this.getPalette().segmentSelected : Color.Transparent)
              .borderRadius(0)
              .accessibilityDescription(this.selectedVariant === variant ? this.getString('home_selected') : '')
              .onClick(() => {
                this.selectedVariant = variant
                // 变种只能使用 9×9；标准模式允许选择小棋盘。
                if (variant !== VariantType.STANDARD) this.selectedGridSize = GRID_9x9.gridSize
                this.showVariants = false
              })
          }, (variant: VariantType) => variant)
        }
        Text(this.getString(`${this.variantName(this.selectedVariant)}_desc`))
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.getPalette().subtitleText)
          .width('100%')
      }
      .width('100%')

      if (this.selectedVariant === VariantType.STANDARD) {
        Column({ space: 6 }) {
          Text($r('app.string.grid_size_section'))
            .fontSize(13)
            .fontColor(this.getPalette().subtitleText)
            .width('100%')
          Row({ space: 8 }) {
            ForEach(GRID_SIZE_OPTIONS, (item: GridSizeOption) => {
              Button(this.getString(item.label), { type: ButtonType.Normal })
                .height(44)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor(this.getPalette().titleText)
                .backgroundColor(this.selectedGridSize === item.config.gridSize ? this.getPalette().segmentSelected : Color.Transparent)
                .borderRadius(4)
                .border({ width: { bottom: 1 }, color: this.selectedGridSize === item.config.gridSize ? this.getPalette().toolbarActive : this.getPalette().divider })
                .accessibilityDescription(this.selectedGridSize === item.config.gridSize ? this.getString('home_selected') : '')
                .onClick(() => { this.selectedGridSize = item.config.gridSize })
            }, (item: GridSizeOption) => item.config.gridSize.toString())
          }
          .width('100%')
        }
        .width('100%')
      }

      Column({ space: 6 }) {
        Text($r('app.string.sym_section'))
          .fontSize(13)
          .fontColor(this.getPalette().subtitleText)
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(SYMMETRY_OPTIONS, (item: SymmetryOption) => {
            Button(this.getString(item.label), { type: ButtonType.Normal })
              .height(44)
              .padding({ left: 12, right: 12 })
              .margin({ right: 6, bottom: 6 })
              .fontSize(14)
              .fontColor(this.getPalette().titleText)
              .backgroundColor(this.selectedSymmetry === item.key ? this.getPalette().segmentSelected : Color.Transparent)
              .borderRadius(4)
              .border({ width: { bottom: 1 }, color: this.selectedSymmetry === item.key ? this.getPalette().toolbarActive : this.getPalette().divider })
              .accessibilityDescription(this.selectedSymmetry === item.key ? this.getString('home_selected') : '')
              .onClick(() => { this.selectedSymmetry = item.key })
          }, (item: SymmetryOption) => item.key)
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
    .padding({ bottom: 16 })
  }

  @Builder
  private NewGameSection() {
    Column({ space: 12 }) {
      if (!this.hasSave) {
        Text($r('app.string.home_start_heading'))
          .fontSize(26)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().titleText)
          .width('100%')
          .margin({ bottom: 6 })
      }
      Text($r('app.string.home_random_source'))
        .fontSize(13)
        .fontColor(this.getPalette().subtitleText)
        .width('100%')
      this.DifficultyPicker()
      Text(this.configSummary())
        .fontSize(13)
        .fontColor(this.getPalette().subtitleText)
        .width('100%')
      Button($r('app.string.home_start_new'), { type: ButtonType.Normal })
        .width('100%')
        .height(52)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.hasSave ? this.getPalette().titleText : this.getPalette().primaryText)
        .backgroundColor(this.hasSave ? Color.Transparent : this.getPalette().primaryBtn)
        .border({ width: this.hasSave ? 1 : 0, color: this.getPalette().cellBorderBold })
        .borderRadius(6)
        .onClick(() => { this.startNewGame() })
      Column() {
        HomeDisclosureRow({
          labelKey: 'home_advanced',
          expanded: this.showAdvancedOptions,
          onToggle: () => { this.showAdvancedOptions = !this.showAdvancedOptions },
        })
        if (this.showAdvancedOptions) {
          this.AdvancedOptions()
        }
      }
      .width('100%')
      Divider().color(this.getPalette().divider)
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Text($r('app.string.home_library_source'))
            .fontSize(16)
            .fontColor(this.getPalette().titleText)
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
          Image($r('app.media.paper_arrow_right'))
            .width(18)
            .height(18)
            .fillColor(this.getPalette().subtitleText)
            .accessibilityLevel('no')
        }
        .width('100%')
      }
      .width('100%')
      .height(48)
      .padding(0)
      .borderRadius(0)
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.home_library_source'))
      .onClick(() => { router.pushUrl({ url: 'pages/PuzzleLibraryPage' }) })
      Column() {
        HomeDisclosureRow({
          labelKey: 'home_import',
          expanded: this.showImport,
          onToggle: () => { this.showImport = !this.showImport },
        })
        if (this.showImport) {
          this.ImportSection()
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ bottom: 4 })
  }

  @Builder
  private ImportPreview() {
    if (this.importResult !== null && this.importResult.success && this.importResult.format !== 'seed') {
      Column({ space: 12 }) {
        Row({ space: 6 }) {
          Image($r('app.media.paper_check'))
            .width(16)
            .height(16)
            .fillColor(this.getPalette().toolbarActive)
            .accessibilityLevel('no')
          Text(this.getString(getFormatDisplayNameKey(this.importResult.format)))
            .fontSize(13)
            .fontColor(this.getPalette().titleText)
          if (this.importResult.puzzles.length > 1) {
            Text(formatStr(this.getString('import_puzzle_count'), this.importResult.puzzles.length))
              .fontSize(13)
              .fontColor(this.getPalette().subtitleText)
          }
        }
        .width('100%')
        if (this.importResult.puzzles.length > 1) {
          Row({ space: 12 }) {
            Button({ type: ButtonType.Normal }) {
              Image($r('app.media.paper_arrow_left'))
                .width(18)
                .height(18)
                .fillColor(this.getPalette().titleText)
            }
            .width(44)
            .height(44)
            .backgroundColor(Color.Transparent)
            .enabled(this.importSelectedIndex > 0)
            .accessibilityText($r('app.string.home_previous_puzzle'))
            .onClick(() => { if (this.importSelectedIndex > 0) this.importSelectedIndex-- })
            Text(`${this.importSelectedIndex + 1} / ${this.importResult.puzzles.length}`)
              .fontSize(14)
              .fontColor(this.getPalette().titleText)
            Button({ type: ButtonType.Normal }) {
              Image($r('app.media.paper_arrow_right'))
                .width(18)
                .height(18)
                .fillColor(this.getPalette().titleText)
            }
            .width(44)
            .height(44)
            .backgroundColor(Color.Transparent)
            .enabled(this.importSelectedIndex < this.importResult.puzzles.length - 1)
            .accessibilityText($r('app.string.home_next_puzzle'))
            .onClick(() => {
              if (this.importResult !== null && this.importSelectedIndex < this.importResult.puzzles.length - 1) {
                this.importSelectedIndex++
              }
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        if (this.importResult.puzzles.length > 0) {
          this.MiniPreview(this.importResult.puzzles[this.importSelectedIndex].board)
          Text(formatStr(this.getString('import_givens_count'), countGivens(this.importResult.puzzles[this.importSelectedIndex].board)))
            .fontSize(12)
            .fontColor(this.getPalette().subtitleText)
          if (this.importResult.puzzles[this.importSelectedIndex].metadata?.description) {
            Text(this.importResult.puzzles[this.importSelectedIndex].metadata!.description!)
              .fontSize(13)
              .fontColor(this.getPalette().subtitleText)
              .width('100%')
          }
          if (this.importResult.puzzles[this.importSelectedIndex].metadata?.author) {
            Text(`— ${this.importResult.puzzles[this.importSelectedIndex].metadata!.author!}`)
              .fontSize(12)
              .fontColor(this.getPalette().subtitleText)
              .width('100%')
          }
        }
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })
    } else if (decodeSeedId(this.seedInput.trim()) !== null) {
      Text($r('app.string.home_seed_ready'))
        .fontSize(13)
        .fontColor(this.getPalette().toolbarActive)
        .width('100%')
    } else if (this.importResult !== null && !this.importResult.success && this.seedInput.trim().length > 0) {
      Text(this.resolveErrorMessage(this.importResult.error) ?? this.getString('import_format_unknown'))
        .fontSize(13)
        .fontColor(this.getPalette().textError)
        .width('100%')
    }
  }

  @Builder
  private ImportSection() {
    Column({ space: 12 }) {
      Text($r('app.string.home_import_help'))
        .fontSize(13)
        .lineHeight(20)
        .fontColor(this.getPalette().subtitleText)
        .width('100%')
      TextInput({ text: this.seedInput, placeholder: $r('app.string.import_placeholder') })
        .width('100%')
        .height(48)
        .fontSize(14)
        .fontColor(this.getPalette().titleText)
        .placeholderColor(this.getPalette().subtitleText)
        .backgroundColor(this.getPalette().cardBg)
        .border({ width: 1, color: this.getPalette().cardBorder })
        .borderRadius(6)
        .padding({ left: 12, right: 12 })
        .accessibilityText($r('app.string.home_import_input'))
        .onChange((value: string) => {
          this.seedInput = value
          this.tryParseInput(value)
        })
      Row({ space: 8 }) {
        Button($r('app.string.home_paste'), { type: ButtonType.Normal })
          .height(44)
          .fontSize(14)
          .fontColor(this.getPalette().toolbarActive)
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 12 })
          .onClick(() => { this.pastePuzzle() })
        if (this.seedInput.length > 0) {
          Button($r('app.string.home_clear'), { type: ButtonType.Normal })
            .height(44)
            .fontSize(14)
            .fontColor(this.getPalette().subtitleText)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.seedInput = ''
              this.importResult = null
              this.importSelectedIndex = 0
            })
        }
      }
      .width('100%')
      this.ImportPreview()
      Button($r('app.string.home_start_import'), { type: ButtonType.Normal })
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontColor(this.getPalette().titleText)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: this.getPalette().cellBorderBold })
        .borderRadius(6)
        .enabled(this.seedInput.trim().length > 0)
        .onClick(() => { this.startImportedGame() })
    }
    .width('100%')
    .padding({ bottom: 20 })
  }

  @Builder
  private PlayTab() {
    Scroll() {
      if (this.getHomeLayout().measured) {
        // 宽窗保留舒适阅读宽度；主操作始终先于折叠配置。
        Column() {
          Column() {
            this.HomeHeader()
            Column() {
              if (this.hasSave) {
                this.ResumeSection()
                Divider().color(this.getPalette().divider).margin({ top: 28 })
                HomeDisclosureRow({
                  labelKey: 'home_new_game',
                  expanded: this.showNewGame,
                  onToggle: () => { this.showNewGame = !this.showNewGame },
                })
                if (this.showNewGame) {
                  this.NewGameSection()
                }
              } else {
                this.NewGameSection()
              }
              Divider().color(this.getPalette().divider)
            }
            .width('100%')
            .margin({ top: 32 })
          }
          .width('100%')
        }
        .width(Math.min(this.getHomeLayout().contentWidth, 520))
        .constraintSize({ minHeight: Math.max(0, this.viewportHeight - 48) })
        .justifyContent(FlexAlign.Start)
        .padding({ top: 24, bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width)
      const height = Number(newArea.height)
      if (Math.abs(width - this.viewportWidth) > 0.5) this.viewportWidth = width
      if (Math.abs(height - this.viewportHeight) > 0.5) this.viewportHeight = height
    })
  }

  @Builder
  private PageTab(icon: Resource, label: Resource, index: number) {
    Column({ space: 5 }) {
      Row({ space: 5 }) {
        Image(icon)
          .width(16)
          .height(16)
          .fillColor(this.selectedTab === index ? this.getPalette().titleText : this.getPalette().bottomText)
          .displayPriority(1)
          .accessibilityLevel('no')
        Text(label)
          .fontSize(14)
          .fontWeight(this.selectedTab === index ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.selectedTab === index ? this.getPalette().titleText : this.getPalette().bottomText)
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .displayPriority(2)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      Divider()
        .width(22)
        .strokeWidth(2)
        .color(this.selectedTab === index ? this.getPalette().tabUnderline : Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .id('main-tab-' + index)
    .accessibilityGroup(true)
    .accessibilityText(label)
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, controller: this.tabController }) {
        TabContent() { this.PlayTab() }
          .tabBar(this.PageTab($r('app.media.paper_home'), $r('app.string.tab_home'), 0))
        TabContent() {
          HistoryList({ active: this.selectedTab === 1, refreshVersion: this.pageRevision })
        }
          .tabBar(this.PageTab($r('app.media.paper_clock'), $r('app.string.history_title'), 1))
        TabContent() {
          StatsPanel({ embedded: true, active: this.selectedTab === 2, refreshVersion: this.pageRevision })
        }
          .tabBar(this.PageTab($r('app.media.paper_stats'), $r('app.string.tab_stats'), 2))
        TabContent() {
          Column() {
            SettingsPanel({ embedded: true, context: getContext(this) as common.UIAbilityContext })
          }
          .width('100%')
          .constraintSize({ maxWidth: 760 })
          .height('100%')
        }
          .tabBar(this.PageTab($r('app.media.paper_settings'), $r('app.string.tab_settings'), 3))
      }
      .width('100%')
      .height('100%')
      .barHeight(52)
      .barMode(BarMode.Fixed)
      .barBackgroundColor(this.getPalette().pageBg)
      .divider({ strokeWidth: 0.5, color: this.getPalette().divider, startMargin: 24, endMargin: 24 })
      .scrollable(false)
      .onChange((index: number) => { this.selectedTab = index })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topRectHeight, bottom: this.bottomRectHeight,
      left: this.leftRectWidth, right: this.rightRectWidth })
    .backgroundColor(this.getPalette().pageBg)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
