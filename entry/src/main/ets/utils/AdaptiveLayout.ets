/**
 * 只使用组件实测可用空间，不依赖机型、屏幕物理分辨率或折叠状态。
 * 页面负责系统避让；这里的尺寸均为避让后内容区域的 vp。
 */
export interface GameLayoutPlan {
  measured: boolean
  wide: boolean
  contentWidth: number
  boardWidth: number
  boardHeight: number
  boardFrameWidth: number
  boardFrameHeight: number
  controlWidth: number
  stackedKeypadWidth: number
  actionHeight: number
  toolsHorizontal: boolean
  compactKeypad: boolean
  keypadColumns: number
  keypadRows: number
  keyFontSize: number
  gap: number
}

export interface HomeLayoutPlan {
  measured: boolean
  wide: boolean
  contentWidth: number
  introWidth: number
  optionsWidth: number
  gap: number
}

function usableDimension(value: number): number {
  return Number.isFinite(value) ? Math.max(0, value) : 0
}

/** 完成动效最大放大至 1.06，布局先留出空间，避免动画伸出窗口。 */
const BOARD_ANIMATION_SCALE: number = 1.06
export const COORDINATE_GUTTER: number = 18

export function computeGameLayout(width: number, height: number,
  showCoordinates: boolean = false, multiSelect: boolean = false,
  auxButtonsOnTop: boolean = false, gridSize: number = 9): GameLayoutPlan {
  const viewportWidth = usableDimension(width)
  const viewportHeight = usableDimension(height)
  const contentWidth = Math.max(0, Math.min(viewportWidth - 16, 1080))
  // 较窄的竖向阔折叠仍用单列，避免棋盘与操作区各被挤成细栏。
  // 横屏可利用两栏；足够宽的竖屏则保留双栏。
  const wide = contentWidth >= 640 && (viewportWidth >= viewportHeight || contentWidth >= 840)
  const boardAnimationScale = wide ? BOARD_ANIMATION_SCALE : 1
  const gap = wide ? 24 : 8
  const controlWidth = wide ? Math.min(400, Math.max(284, contentWidth * 0.4)) : contentWidth
  const digits = gridSize === 4 || gridSize === 6 ? gridSize : 9
  const compactKeypad = !wide && digits === 9
  // 真横屏固定上置；竖向双栏保留用户选择。窄单列容不下两组时上下排布。
  const compactToolsStacked = compactKeypad && controlWidth < 252
  const toolsHorizontal = wide ? viewportWidth >= viewportHeight || auxButtonsOnTop :
    digits !== 9 || compactToolsStacked
  const singleRow = digits !== 9 && !wide && controlWidth / digits >= 48
  const keypadColumns = singleRow ? digits : (digits === 4 ? 2 : 3)
  const keypadRows = Math.ceil(digits / keypadColumns)
  const toolsHeight = (compactToolsStacked ? 100 : 48) + 6
  const bodyInsets = (multiSelect ? 40 : 0) + gap + (wide ? 8 : 4)
  const keyBalanceInsets = (multiSelect ? 40 : 0) + 16
  let keyRowHeight = wide ? Math.min(78, Math.max(54,
    Math.min(viewportHeight * 0.14, (controlWidth - 152) / 2))) : 54
  if (digits === 9 && !toolsHorizontal) {
    // 横屏侧栏并排放两列工具和三列数字，二者之间留 8vp。
    keyRowHeight = (controlWidth - 8) / (2 + keypadColumns)
  }
  // 保留纸签方键，同时限制并排操作组不宽于棋盘。
  // 不把两块正方形绑成同一宽度，避免操作键挤占棋盘面积。
  const compactCoordinateGutter = showCoordinates ? COORDINATE_GUTTER : 0
  const compactWidthLimit = controlWidth / BOARD_ANIMATION_SCALE - compactCoordinateGutter - 100
  const compactHeightLimit = (viewportHeight - keyBalanceInsets - BOARD_ANIMATION_SCALE * (compactCoordinateGutter + 100)) / (1 + BOARD_ANIMATION_SCALE)
  const compactPadSide = compactToolsStacked ? 152 :
    Math.max(152, Math.min(212, compactWidthLimit, compactHeightLimit))
  const compactKeySide = (compactPadSide - 8) / 3
  const padHeight = compactKeypad ? compactPadSide : (keypadRows === 1 ? 64 : keypadRows * keyRowHeight)
  const actionHeight = toolsHorizontal ? toolsHeight + padHeight : padHeight
  // 手势提示叠在工具区，不再为平时不可见的提示条占据36vp。
  const reservedControls = actionHeight + bodyInsets
  const availableBoardWidth = wide ? contentWidth - controlWidth - gap : contentWidth
  const heightLimit = Math.max(0, viewportHeight - (wide ? 8 : 4)) / boardAnimationScale
  // 正常手机/折叠外屏优先让完整棋盘和底排同屏；极短分屏才滚动。
  // 9格棋盘保留至少约27vp单格，不用无限缩字来隐藏溢出。
  const preferredBoardHeight = wide ? heightLimit : Math.max(240, (viewportHeight - reservedControls) / boardAnimationScale)
  const boardWidth = Math.max(0, Math.min(560, availableBoardWidth / boardAnimationScale,
    heightLimit, preferredBoardHeight))
  let stackedKeypadWidth = controlWidth
  if (compactKeypad) {
    stackedKeypadWidth = compactPadSide
  } else if (digits === 9) {
    stackedKeypadWidth = keyRowHeight * keypadColumns
  } else if (!wide && keypadRows > 1) {
    stackedKeypadWidth = Math.min(controlWidth, Math.max(boardWidth, keypadColumns * 48))
  }
  // 坐标轴左侧18vp、上侧16vp；棋盘 Grid 自身保持正方形。
  const boardHeight = showCoordinates && boardWidth >= COORDINATE_GUTTER ? boardWidth - 2 : boardWidth
  const keyFontSize = compactKeypad ? Math.max(22, compactKeySide * 0.4) :
    wide || digits === 9 ? Math.min(34, Math.max(22, keyRowHeight * 0.40)) : 22
  return {
    measured: viewportWidth > 0 && viewportHeight > 0,
    wide: wide,
    contentWidth: contentWidth,
    boardWidth: boardWidth,
    boardHeight: boardHeight,
    boardFrameWidth: boardWidth * boardAnimationScale,
    boardFrameHeight: boardHeight * boardAnimationScale,
    controlWidth: controlWidth,
    stackedKeypadWidth: stackedKeypadWidth,
    actionHeight: actionHeight,
    toolsHorizontal: toolsHorizontal,
    compactKeypad: compactKeypad,
    keypadColumns: keypadColumns,
    keypadRows: keypadRows,
    keyFontSize: keyFontSize,
    gap: gap,
  }
}

export function computeHomeLayout(width: number, height: number): HomeLayoutPlan {
  const viewportWidth = usableDimension(width)
  const viewportHeight = usableDimension(height)
  const availableWidth = Math.max(0, viewportWidth - 48)
  const wide = availableWidth >= 720
  const contentWidth = Math.min(availableWidth, wide ? 1040 : 520)
  const gap = wide ? 32 : 20
  const introWidth = wide ? Math.min(340, Math.max(260, contentWidth * 0.34)) : contentWidth
  return {
    measured: viewportWidth > 0 && viewportHeight > 0,
    wide: wide,
    contentWidth: contentWidth,
    introWidth: introWidth,
    optionsWidth: wide ? contentWidth - introWidth - gap : contentWidth,
    gap: gap,
  }
}

/** x/y 为最终 Grid 本地坐标；边框不参与格子命中，边界外返回 -1。 */
export function hitTestBoardCell(x: number, y: number, width: number, height: number,
  gridSize: number, borderWidth: number = 0): number {
  if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(gridSize) ||
    gridSize < 1 || Math.floor(gridSize) !== gridSize) return -1
  const border = usableDimension(borderWidth)
  const innerWidth = usableDimension(width) - border * 2
  const innerHeight = usableDimension(height) - border * 2
  if (innerWidth <= 0 || innerHeight <= 0 || x < border || y < border ||
    x >= border + innerWidth || y >= border + innerHeight) return -1
  const col = Math.floor((x - border) / innerWidth * gridSize)
  const row = Math.floor((y - border) / innerHeight * gridSize)
  return row * gridSize + col
}
