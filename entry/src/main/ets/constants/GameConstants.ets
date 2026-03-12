/**
 * GameConstants.ets — 全局常量（配色、尺寸、难度配置）
 *
 * 所有魔法数字都定义在这里，任何组件不应出现硬编码的颜色或尺寸。
 * 深色模式通过 applyTheme(isDark) 切换 Colors 对象。
 *
 * 参考：Doc 05 §三/四, Doc 01 §五
 */

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
  pageBg: string
  titleText: string
  subtitleText: string
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
  segmentBg: string
  segmentSelected: string
  segmentText: string
  segmentActive: string
  bottomIcon: string
  bottomText: string
  switchTrackOff: string

  // === 分割线 & 阴影 ===
  divider: string
  shadowColor: string
  shadowColorLight: string

  // === 暂停遮罩 ===
  pauseOverlayBg: string
  pauseOverlayText: string
  pauseInfoCardBg: string
  pauseInfoText: string
  pauseRestartBtn: string
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
  // === 页面级 ===
  pageBg: '#F5F5F5',

  // === 标题 ===
  titleText: '#212121',
  subtitleText: '#9E9E9E',

  // === 主按钮（开始游戏） ===
  primaryBtn: '#1976D2',
  primaryPressed: '#1565C0',
  primaryText: '#FFFFFF',

  // === 次按钮（继续游戏） ===
  secondaryBtn: '#FFFFFF',
  secondaryBorder: '#1976D2',
  secondaryText: '#1976D2',
  secondaryPress: '#E3F2FD',

  // === 棋盘 ===
  boardBg: '#FFFFFF',
  cellBorderThin: '#BDBDBD',
  cellBorderBold: '#212121',

  // === 格子背景（高亮系统） ===
  cellDefault: '#FFFFFF',
  cellSelected: '#BBDEFB',
  cellHighlight: '#E3F2FD',
  cellSameNumber: '#C8E6C9',
  cellError: '#FFCDD2',

  // === 文字颜色 ===
  textGiven: '#212121',
  textUser: '#1976D2',
  textError: '#D32F2F',
  textNote: '#757575',
  textNoteHighlight: '#388E3C',
  textNoteElim: '#BDBDBD',
  noteHighlightBg: '#C8E6C9',

  // === 手势键盘 ===
  keyBg: '#FFFFFF',
  keyText: '#212121',
  keyDisabled: '#E0E0E0',
  keyDisabledText: '#9E9E9E',

  // === 工具栏 ===
  toolbarIcon: '#616161',
  toolbarActive: '#1976D2',

  // === 手势提示条 ===
  indicatorNote: '#E3F2FD',
  indicatorElim: '#FFF3E0',
  indicatorErase: '#F5F5F5',
  indicatorText: '#424242',

  // === 难度色标 ===
  diffEasy: '#4CAF50',
  diffMedium: '#2196F3',
  diffHard: '#FF9800',
  diffExpert: '#F57C00',
  diffEvil: '#F44336',

  // === 分段按钮 ===
  segmentBg: '#E8E8E8',
  segmentSelected: '#FFFFFF',
  segmentText: '#616161',
  segmentActive: '#212121',

  // === 底部入口 ===
  bottomIcon: '#616161',
  bottomText: '#757575',

  // === Switch 开关 ===
  switchTrackOff: '#BDBDBD',

  // === 分割线 & 阴影 ===
  divider: '#E0E0E0',
  shadowColor: '#1A000000',
  shadowColorLight: '#0D000000',

  // === 暂停遮罩 ===
  pauseOverlayBg: '#1B2838',
  pauseOverlayText: '#FFFFFF',
  pauseInfoCardBg: '#FFFFFF00',
  pauseInfoText: '#B0BEC5',
  pauseRestartBtn: '#FF7043',
  pauseQuitBtn: '#546E7A',

  // === 多选提示条 ===
  multiSelectBar: '#E3F2FD',

  // === TopBar 暂停背景 ===
  topBarPausedBg: '#F0F0F0',

  // === 设置面板 ===
  settingsInactiveBg: '#F0F0F0',
  settingsValidateOnText: '#4CAF50',

  // === 难度指示点（未激活） ===
  diffDotInactive: '#E0E0E0',

  // === 聊天气泡 ===
  chatBubbleBg: '#F0F0F0',
  chatInputBg: '#F5F5F5',
  chatQuickBtnBg: '#F0F4FF',
  chatDisabledBtn: '#CCCCCC',

  // === 统计页胜率 ===
  statsWonText: '#4CAF50',
}

export const DarkColors: ColorsConfig = {
  // === 页面级 ===
  pageBg: '#121212',

  // === 标题 ===
  titleText: '#E0E0E0',
  subtitleText: '#9E9E9E',

  // === 主按钮（开始游戏） ===
  primaryBtn: '#42A5F5',
  primaryPressed: '#1E88E5',
  primaryText: '#121212',

  // === 次按钮（继续游戏） ===
  secondaryBtn: '#1E1E1E',
  secondaryBorder: '#42A5F5',
  secondaryText: '#42A5F5',
  secondaryPress: '#1A237E',

  // === 棋盘 ===
  boardBg: '#1E1E1E',
  cellBorderThin: '#424242',
  cellBorderBold: '#9E9E9E',

  // === 格子背景（高亮系统） ===
  cellDefault: '#1E1E1E',
  cellSelected: '#1A3A5C',
  cellHighlight: '#1A2332',
  cellSameNumber: '#1B3B2A',
  cellError: '#3E1A1A',

  // === 文字颜色 ===
  textGiven: '#E0E0E0',
  textUser: '#64B5F6',
  textError: '#EF5350',
  textNote: '#9E9E9E',
  textNoteHighlight: '#81C784',
  textNoteElim: '#616161',
  noteHighlightBg: '#1B3B2A',

  // === 手势键盘 ===
  keyBg: '#2A2A2A',
  keyText: '#E0E0E0',
  keyDisabled: '#333333',
  keyDisabledText: '#616161',

  // === 工具栏 ===
  toolbarIcon: '#BDBDBD',
  toolbarActive: '#42A5F5',

  // === 手势提示条 ===
  indicatorNote: '#1A2332',
  indicatorElim: '#2A2216',
  indicatorErase: '#2A2A2A',
  indicatorText: '#E0E0E0',

  // === 难度色标 ===
  diffEasy: '#66BB6A',
  diffMedium: '#42A5F5',
  diffHard: '#FFA726',
  diffExpert: '#FF9800',
  diffEvil: '#EF5350',

  // === 分段按钮 ===
  segmentBg: '#2A2A2A',
  segmentSelected: '#3A3A3A',
  segmentText: '#9E9E9E',
  segmentActive: '#E0E0E0',

  // === 底部入口 ===
  bottomIcon: '#BDBDBD',
  bottomText: '#9E9E9E',

  // === Switch 开关 ===
  switchTrackOff: '#616161',

  // === 分割线 & 阴影 ===
  divider: '#333333',
  shadowColor: '#40000000',
  shadowColorLight: '#20000000',

  // === 暂停遮罩 ===
  pauseOverlayBg: '#0D1117',
  pauseOverlayText: '#E6EDF3',
  pauseInfoCardBg: '#FFFFFF00',
  pauseInfoText: '#8B949E',
  pauseRestartBtn: '#D84315',
  pauseQuitBtn: '#30363D',

  // === 多选提示条 ===
  multiSelectBar: '#1A2332',

  // === TopBar 暂停背景 ===
  topBarPausedBg: '#2A2A2A',

  // === 设置面板 ===
  settingsInactiveBg: '#2A2A2A',
  settingsValidateOnText: '#66BB6A',

  // === 难度指示点（未激活） ===
  diffDotInactive: '#424242',

  // === 聊天气泡 ===
  chatBubbleBg: '#2A2A2A',
  chatInputBg: '#1E1E1E',
  chatQuickBtnBg: '#1A2332',
  chatDisabledBtn: '#424242',

  // === 统计页胜率 ===
  statsWonText: '#66BB6A',
}

/**
 * 当前生效的颜色方案（可被 applyTheme 切换）
 */
export let Colors: ColorsConfig = LightColors

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
  btnRadius: 26,
  btnGap: 12,
  segmentHeight: 44,
  segmentRadius: 22,
  bottomIcon: 22,
  bottomText: 12,

  // === 游戏页 ===
  gamePagePadding: 8,
  topBarHeight: 48,
  boardSize: 328,          // 仅在少数场景用作回退
  cellSize: 36,            // ≈ 328 / 9
  cellBorderBold: 2,
  cellBorderThin: 0.5,
  givenFont: 22,
  userFont: 22,
  noteFont: 10,

  // === 手势提示条 ===
  indicatorHeight: 28,
  indicatorDuration: 150,  // 动画时长 ms

  // === 辅助按钮 ===
  auxColWidth: 48,
  auxIcon: 22,
  auxText: 9,
  auxRadius: 8,

  // === 手势键 ===
  keyFont: 22,
  keyCountFont: 10,
  keyRadius: 12,
  gestureThreshold: 30,    // 滑动判定阈值 vp
}

// ============================================================
// 网格常量
// ============================================================

/** 数独边长 */
export const GRID_SIZE = 9
/** 宫格边长 */
export const BOX_SIZE = 3
/** 总格数 */
export const TOTAL_CELLS = 81
/** 有效数字 1-9 */
export const DIGITS: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
