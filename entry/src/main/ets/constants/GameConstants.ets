/**
 * GameConstants.ets — 全局常量（配色、尺寸、难度配置）
 *
 * 所有魔法数字都定义在这里，任何组件不应出现硬编码的颜色或尺寸。
 * 后续做深色模式时，只需提供第二套 DarkColors 对象。
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
  minClues: number
  maxClues: number
  holesToDig: number
  color: string
}

export const DIFFICULTY_CONFIGS: DifficultyConfig[] = [
  { level: Difficulty.EASY, name: '简单', minClues: 36, maxClues: 45, holesToDig: 40, color: '#4CAF50' },
  { level: Difficulty.MEDIUM, name: '中等', minClues: 32, maxClues: 35, holesToDig: 48, color: '#2196F3' },
  { level: Difficulty.HARD, name: '困难', minClues: 28, maxClues: 31, holesToDig: 52, color: '#FF9800' },
  { level: Difficulty.EXPERT, name: '专家', minClues: 24, maxClues: 27, holesToDig: 56, color: '#F57C00' },
  { level: Difficulty.EVIL, name: '地狱', minClues: 17, maxClues: 23, holesToDig: 62, color: '#F44336' },
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
  textNoteElim: string
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
}

export const Colors: ColorsConfig = {
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
  textNoteElim: '#BDBDBD',

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
  gamePagePadding: 16,
  topBarHeight: 48,
  boardSize: 328,
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
  auxColWidth: 60,
  auxIcon: 28,
  auxText: 13,
  auxRadius: 8,

  // === 手势键 ===
  keyFont: 28,
  keyCountFont: 11,
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
