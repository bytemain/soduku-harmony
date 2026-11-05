/**
 * GameConstants.ets — 全局常量（配色、尺寸、难度配置）
 *
 * 所有魔法数字都定义在这里，任何组件不应出现硬编码的颜色或尺寸。
 * 深色模式通过 applyTheme(isDark) 切换 Colors 对象。
 *
 * 参考：Doc 05 §三/四, Doc 01 §五
 */
import { GridConfig } from '../models/VariantConfig'

// ============================================================
// 难度枚举 & 配置
// ============================================================

export enum Difficulty {
  EASY = 1,
  MEDIUM = 2,
  HARD = 3,
  EXPERT = 4,
  EVIL = 5,
}

export interface DifficultyConfig {
  level: Difficulty
  name: string
  /** 技巧描述的 i18n key */
  descName: string
  minClues: number
  maxClues: number
  holesToDig: number
  color: string
}

export const DIFFICULTY_CONFIGS: DifficultyConfig[] = [
  { level: Difficulty.EASY, name: 'diff_easy', descName: 'diff_easy_desc', minClues: 36, maxClues: 45, holesToDig: 40, color: '#4CAF50' },
  { level: Difficulty.MEDIUM, name: 'diff_medium', descName: 'diff_medium_desc', minClues: 32, maxClues: 35, holesToDig: 48, color: '#2196F3' },
  { level: Difficulty.HARD, name: 'diff_hard', descName: 'diff_hard_desc', minClues: 28, maxClues: 31, holesToDig: 52, color: '#FF9800' },
  { level: Difficulty.EXPERT, name: 'diff_expert', descName: 'diff_expert_desc', minClues: 24, maxClues: 27, holesToDig: 56, color: '#F57C00' },
  { level: Difficulty.EVIL, name: 'diff_evil', descName: 'diff_evil_desc', minClues: 17, maxClues: 23, holesToDig: 62, color: '#F44336' },
]

/** 根据枚举值获取对应配置 */
export function getDifficultyConfig(level: Difficulty): DifficultyConfig {
  return DIFFICULTY_CONFIGS[level - 1]
}

// ============================================================
// 手势方向（手势键盘用）
// ============================================================

export enum GestureDirection {
  TAP,    // 点击 → 填数
  UP,     // 上滑 → 笔记
  RIGHT,  // 右滑 → 删除线
  LEFT,   // 左滑 → 擦除笔记
  DOWN,   // 下滑 → 保留
}

// ============================================================
// 统一配色方案
// ============================================================

export interface ColorsConfig {
  cardBg: string
  cardBorder: string
  accent: string
  pageBg: string
  titleText: string
  subtitleText: string
  systemBarContent: string
  primaryBtn: string
  primaryPressed: string
  primaryText: string
  secondaryBtn: string
  secondaryBorder: string
  secondaryText: string
  secondaryPress: string
  boardBg: string
  cellBorderThin: string
  cellBorderBold: string
  cellDefault: string
  cellDiagonal: string
  cellDiagonalHighlight: string
  cellSelected: string
  cellHighlight: string
  cellSameNumber: string
  cellError: string
  textGiven: string
  textUser: string
  textError: string
  textNote: string
  textNoteHighlight: string
  textNoteElim: string
  noteHighlightBg: string
  keyBg: string
  keyText: string
  keyDisabled: string
  keyDisabledText: string
  toolbarIcon: string
  toolbarActive: string
  indicatorNote: string
  indicatorElim: string
  indicatorErase: string
  indicatorText: string
  diffEasy: string
  diffMedium: string
  diffHard: string
  diffExpert: string
  diffEvil: string
  killerCageBorder: string
  killerCageLabel: string
  segmentBg: string
  segmentSelected: string
  segmentText: string
  segmentActive: string
  bottomIcon: string
  bottomText: string
  tabUnderline: string
  switchTrackOff: string

  // === 分割线 & 阴影 ===
  divider: string
  shadowColor: string
  shadowColorLight: string
  modalOverlayMask: string

  // === 暂停遮罩 ===
  pauseOverlayBg: string
  pauseOverlayText: string
  pauseInfoCardBg: string
  pauseInfoText: string
  pauseRestartBtn: string
  pauseHelpBtn: string
  pauseQuitBtn: string

  // === 多选提示条 ===
  multiSelectBar: string

  // === TopBar 暂停背景 ===
  topBarPausedBg: string

  // === 设置面板 ===
  settingsInactiveBg: string
  settingsValidateOnText: string

  // === 难度指示点（未激活） ===
  diffDotInactive: string

  // === 聊天气泡 ===
  chatBubbleBg: string
  chatInputBg: string
  chatQuickBtnBg: string
  chatDisabledBtn: string

  // === 统计页胜率 ===
  statsWonText: string
}

export const LightColors: ColorsConfig = {
  accent: '#C4DE85',
  cardBorder: '#D4DDD2',
  cardBg: '#FFFEF8',
  // === 页面级 ===
  pageBg: '#F8F7F1',

  // === 标题 ===
  titleText: '#153E39',
  subtitleText: '#5E716B',
  systemBarContent: '#153E39',

  // === 主按钮（开始游戏） ===
  primaryBtn: '#153E39',
  primaryPressed: '#0E302A',
  primaryText: '#FFFEF8',

  // === 次按钮（继续游戏） ===
  secondaryBtn: '#FFFEF8',
  secondaryBorder: '#D4DDD2',
  secondaryText: '#16796F',
  secondaryPress: '#DFEDDF',

  // === 棋盘 ===
  boardBg: '#FFFEF8',
  cellBorderThin: '#C3CFC5',
  cellBorderBold: '#58776D',

  // === 格子背景（高亮系统） ===
  cellDefault: '#FFFEF8',
  cellDiagonal: '#F0EEE0',
  cellDiagonalHighlight: '#E3DFC4',
  cellSelected: '#D9E8B7',
  cellHighlight: '#EAF1E5',
  cellSameNumber: '#D5E8DE',
  cellError: '#F8DEDA',

  // === 文字颜色 ===
  textGiven: '#153E39',
  textUser: '#12685F',
  textError: '#A3322D',
  textNote: '#4F6259',
  textNoteHighlight: '#245C47',
  textNoteElim: '#4F6259',
  noteHighlightBg: '#D5E8DE',

  // === 手势键盘 ===
  keyBg: '#FFFEF8',
  keyText: '#153E39',
  keyDisabled: '#E4E8DE',
  keyDisabledText: '#7A8A80',

  // === 工具栏 ===
  toolbarIcon: '#45675B',
  toolbarActive: '#16796F',

  // === 手势提示条 ===
  indicatorNote: '#DFEDDF',
  indicatorElim: '#EFE5D5',
  indicatorErase: '#EEEDE5',
  indicatorText: '#153E39',

  // === 难度色标 ===
  diffEasy: '#36735C',
  diffMedium: '#267A79',
  diffHard: '#936B2E',
  diffExpert: '#96502E',
  diffEvil: '#A3433D',
  killerCageBorder: '#A5793C',
  killerCageLabel: '#815B22',

  // === 分段按钮 ===
  segmentBg: '#EDF0E7',
  segmentSelected: '#FFFEF8',
  segmentText: '#5E716B',
  segmentActive: '#153E39',

  // === 底部入口 ===
  bottomIcon: '#45675B',
  bottomText: '#5E716B',
  tabUnderline: '#708449',

  // === Switch 开关 ===
  switchTrackOff: '#A9BAAA',

  // === 分割线 & 阴影 ===
  divider: '#D4DDD2',
  shadowColor: '#10153E39',
  shadowColorLight: '#08153E39',
  modalOverlayMask: '#99102C26',

  // === 暂停遮罩 ===
  pauseOverlayBg: '#F8F7F1',
  pauseOverlayText: '#153E39',
  pauseInfoCardBg: '#FFFEF8',
  pauseInfoText: '#5E716B',
  pauseRestartBtn: '#E9EDD9',
  pauseHelpBtn: '#DFEDDF',
  pauseQuitBtn: '#EFEEE6',

  // === 多选提示条 ===
  multiSelectBar: '#DFEDDF',

  // === TopBar 暂停背景 ===
  topBarPausedBg: '#DFEDDF',

  // === 设置面板 ===
  settingsInactiveBg: '#EDF0E7',
  settingsValidateOnText: '#36735C',

  // === 难度指示点（未激活） ===
  diffDotInactive: '#D4DDD2',

  // === 聊天气泡 ===
  chatBubbleBg: '#EDF0E7',
  chatInputBg: '#FFFEF8',
  chatQuickBtnBg: '#DFEDDF',
  chatDisabledBtn: '#D4DDD2',

  // === 统计页胜率 ===
  statsWonText: '#36735C',
}

export const DarkColors: ColorsConfig = {
  accent: '#C4DE85',
  cardBorder: '#486357',
  cardBg: '#1C342E',
  // === 页面级 ===
  pageBg: '#142723',

  // === 标题 ===
  titleText: '#F4F3E8',
  subtitleText: '#AAC0B4',
  systemBarContent: '#FFFFFF',

  // === 主按钮（开始游戏） ===
  primaryBtn: '#C4DE85',
  primaryPressed: '#ADC86D',
  primaryText: '#153E39',

  // === 次按钮（继续游戏） ===
  secondaryBtn: '#1C342E',
  secondaryBorder: '#486357',
  secondaryText: '#9CD5BE',
  secondaryPress: '#294C40',

  // === 棋盘 ===
  boardBg: '#1A302A',
  cellBorderThin: '#426052',
  cellBorderBold: '#A2B9AA',

  // === 格子背景（高亮系统） ===
  cellDefault: '#1A302A',
  cellDiagonal: '#34392C',
  cellDiagonalHighlight: '#414933',
  cellSelected: '#2F503E',
  cellHighlight: '#243E33',
  cellSameNumber: '#314B3D',
  cellError: '#5B302C',

  // === 文字颜色 ===
  textGiven: '#F4F3E8',
  textUser: '#99D5BB',
  textError: '#FFAFA3',
  textNote: '#AAC0B4',
  textNoteHighlight: '#D4EBB3',
  textNoteElim: '#AAC0B4',
  noteHighlightBg: '#3C5742',

  // === 手势键盘 ===
  keyBg: '#203B32',
  keyText: '#F4F3E8',
  keyDisabled: '#202F2A',
  keyDisabledText: '#81978A',

  // === 工具栏 ===
  toolbarIcon: '#BAD0C0',
  toolbarActive: '#C4DE85',

  // === 手势提示条 ===
  indicatorNote: '#294C40',
  indicatorElim: '#493E2B',
  indicatorErase: '#2C3C33',
  indicatorText: '#F4F3E8',

  // === 难度色标 ===
  diffEasy: '#9DC9A2',
  diffMedium: '#8BCABC',
  diffHard: '#D8B671',
  diffExpert: '#E7AF85',
  diffEvil: '#EDA599',
  killerCageBorder: '#D8B671',
  killerCageLabel: '#E3C68F',

  // === 分段按钮 ===
  segmentBg: '#203A31',
  segmentSelected: '#2D4C3E',
  segmentText: '#AAC0B4',
  segmentActive: '#F4F3E8',

  // === 底部入口 ===
  bottomIcon: '#BAD0C0',
  bottomText: '#AAC0B4',
  tabUnderline: '#B1C987',

  // === Switch 开关 ===
  switchTrackOff: '#607A69',

  // === 分割线 & 阴影 ===
  divider: '#3D574A',
  shadowColor: '#240A1F18',
  shadowColorLight: '#120A1F18',
  modalOverlayMask: '#B3091B16',

  // === 暂停遮罩 ===
  pauseOverlayBg: '#142723',
  pauseOverlayText: '#F4F3E8',
  pauseInfoCardBg: '#1C342E',
  pauseInfoText: '#AAC0B4',
  pauseRestartBtn: '#294235',
  pauseHelpBtn: '#223D34',
  pauseQuitBtn: '#20372F',

  // === 多选提示条 ===
  multiSelectBar: '#294C40',

  // === TopBar 暂停背景 ===
  topBarPausedBg: '#294C40',

  // === 设置面板 ===
  settingsInactiveBg: '#203A31',
  settingsValidateOnText: '#9DC9A2',

  // === 难度指示点（未激活） ===
  diffDotInactive: '#486357',

  // === 聊天气泡 ===
  chatBubbleBg: '#203A31',
  chatInputBg: '#1C342E',
  chatQuickBtnBg: '#294C40',
  chatDisabledBtn: '#486357',

  // === 统计页胜率 ===
  statsWonText: '#9DC9A2',
}

/**
 * 当前生效的颜色方案（可被 applyTheme 切换）
 */
export let Colors: ColorsConfig = LightColors

/** UI组件传入响应式 isDarkMode，直接建立每个颜色节点的主题依赖。 */
export function getThemeColors(isDark: boolean): ColorsConfig {
  return isDark ? DarkColors : LightColors
}

/** 难度配色独立于难度生成参数，并随界面主题更新。 */
export function getDifficultyColor(level: Difficulty, isDark: boolean): string {
  const palette = getThemeColors(isDark)
  switch (level) {
    case Difficulty.EASY: return palette.diffEasy
    case Difficulty.MEDIUM: return palette.diffMedium
    case Difficulty.HARD: return palette.diffHard
    case Difficulty.EXPERT: return palette.diffExpert
    default: return palette.diffEvil
  }
}

/**
 * 切换主题色
 * @param isDark 是否深色模式
 */
export function applyTheme(isDark: boolean): void {
  Colors = isDark ? DarkColors : LightColors
}

// ============================================================
// 尺寸规范（基准 360vp 宽度手机）
// ============================================================

export interface SizesConfig {
  pagePadding: number
  appIcon: number
  titleFont: number
  subtitleFont: number
  btnHeight: number
  btnRadius: number
  btnGap: number
  segmentHeight: number
  segmentRadius: number
  bottomIcon: number
  bottomText: number
  gamePagePadding: number
  topBarHeight: number
  boardSize: number
  cellSize: number
  cellBorderBold: number
  cellBorderThin: number
  killerCageInset: number
  givenFont: number
  userFont: number
  noteFont: number
  indicatorHeight: number
  indicatorDuration: number
  auxColWidth: number
  auxIcon: number
  auxText: number
  auxRadius: number
  keyFont: number
  keyCountFont: number
  keyRadius: number
  gestureThreshold: number
}

export const Sizes: SizesConfig = {
  // === 主页 ===
  pagePadding: 24,
  appIcon: 48,
  titleFont: 32,
  subtitleFont: 14,
  btnHeight: 52,
  btnRadius: 8,
  btnGap: 12,
  segmentHeight: 44,
  segmentRadius: 8,
  bottomIcon: 22,
  bottomText: 12,

  // === 游戏页 ===
  gamePagePadding: 8,
  topBarHeight: 44,
  boardSize: 328,          // 仅在少数场景用作回退
  cellSize: 36,            // ≈ 328 / 9
  cellBorderBold: 1.25,
  cellBorderThin: 0.5,
  killerCageInset: 1,
  givenFont: 22,
  userFont: 22,
  noteFont: 10,

  // === 手势提示条 ===
  indicatorHeight: 28,
  indicatorDuration: 150,  // 动画时长 ms

  // === 辅助按钮 ===
  auxColWidth: 48,
  auxIcon: 22,
  auxText: 12,
  auxRadius: 8,

  // === 手势键 ===
  keyFont: 22,
  keyCountFont: 10,
  keyRadius: 8,
  gestureThreshold: 30,    // 滑动判定阈值 vp
}

// ============================================================
// 网格常量（可由 applyGridConfig 动态切换）
// ============================================================

/** 数独边长 */
export let GRID_SIZE = 9
/** 宫格行数（每个宫格跨几行） */
export let BOX_ROWS = 3
/** 宫格列数（每个宫格跨几列） */
export let BOX_COLS = 3
/** 宫格边长（方形宫时 = BOX_ROWS = BOX_COLS；非方形宫取 BOX_ROWS） */
export let BOX_SIZE = 3
/** 水平方向宫格数 = GRID_SIZE / BOX_COLS */
export let BOX_COUNT_COLS = 3
/** 垂直方向宫格数 = GRID_SIZE / BOX_ROWS */
export let BOX_COUNT_ROWS = 3
/** 总宫格数 = GRID_SIZE（与之前 BOX_COUNT = GRID_SIZE/BOX_SIZE 兼容） */
export let BOX_COUNT = 9
/** 总格数 */
export let TOTAL_CELLS = 81
/** 有效数字 1-N */
export let DIGITS: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
/** 行/列索引 0..GRID_SIZE-1（用于 ForEach 遍历行/列） */
export let GRID_INDICES: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
/**
 * 宫格索引 0..BOX_COUNT-1（用于 ForEach 遍历宫格）。
 * 对标准 9×9，为 [0..8]。对 6×6，为 [0..5]。
 */
export let BOX_INDICES: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
/**
 * 宫内格子索引 0..BOX_ROWS*BOX_COLS-1（用于 ForEach 遍历宫格内的格子）。
 * 对标准 9×9 (3×3 宫)，为 [0..8]。对 6×6 (2×3 宫)，为 [0..5]。
 */
export let BOX_CELL_INDICES: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8]

/**
 * 应用新的棋盘几何配置，更新所有网格常量。
 * 与 applyTheme() 对颜色的切换方式一致。
 *
 * @param config 新的 GridConfig（如 GRID_6x6, GRID_9x9）
 */
export function applyGridConfig(config: GridConfig): void {
  GRID_SIZE = config.gridSize
  BOX_ROWS = config.boxRows
  BOX_COLS = config.boxCols
  BOX_SIZE = config.boxRows // 保持向后兼容
  BOX_COUNT_COLS = config.gridSize / config.boxCols
  BOX_COUNT_ROWS = config.gridSize / config.boxRows
  BOX_COUNT = BOX_COUNT_COLS * BOX_COUNT_ROWS
  TOTAL_CELLS = config.totalCells
  DIGITS = config.digits.slice()
  GRID_INDICES = Array.from({ length: config.gridSize }, (_: void, i: number) => i)
  BOX_INDICES = Array.from({ length: BOX_COUNT }, (_: void, i: number) => i)
  BOX_CELL_INDICES = Array.from({ length: config.boxRows * config.boxCols }, (_: void, i: number) => i)
}

/**
 * 获取当前活跃的 GridConfig 对象。
 */
export function getActiveGridConfig(): GridConfig {
  return {
    gridSize: GRID_SIZE,
    boxRows: BOX_ROWS,
    boxCols: BOX_COLS,
    totalCells: TOTAL_CELLS,
    digits: DIGITS.slice(),
  }
}

/**
 * 创建剩余计数初始数组。
 * index 0 不用，index 1..GRID_SIZE 各为 GRID_SIZE。
 */
export function createInitialRemainingCounts(): number[] {
  const counts: number[] = [0]
  for (let i = 0; i < GRID_SIZE; i++) {
    counts.push(GRID_SIZE)
  }
  return counts
}
