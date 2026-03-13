/**
 * SudokuFormat.ets — 数独标准格式解析与导出
 *
 * 支持业界通用的数独谜题交换格式：
 *   - 81 字符串（最通用）
 *   - SDM 批量格式（每行一题）
 *   - SDK 格式（带元数据的 9 行）
 *   - SS 格式（空格分隔可读版）
 *   - JSON 格式（现代 API）
 *
 * 所有解析函数统一返回 ParsedPuzzle[]。
 * 导出函数将 9×9 棋盘转为指定格式字符串。
 *
 * 参考：docs/09-数独标准格式与导入导出支持.md
 */
import { GRID_SIZE, BOX_SIZE, BOX_COUNT, TOTAL_CELLS } from '../constants/GameConstants'
import { Difficulty } from '../constants/GameConstants'
import { decodeSeedId } from './SudokuGenerator'

// ============================================================
// 公共接口
// ============================================================

/**
 * 解析后的谜题数据
 */
export interface ParsedPuzzle {
  /** 9×9 棋盘（0 = 空格） */
  board: number[][]
  /** 可选元数据 */
  metadata?: PuzzleMetadata
}

export interface PuzzleMetadata {
  author?: string
  description?: string
  difficulty?: string
  source?: string
  comment?: string
}

/**
 * 格式检测结果
 */
export type SudokuFormatType = 'seed' | '81string' | 'sdm' | 'sdk' | 'ss' | 'json' | 'unknown'

/**
 * 解析结果（含格式信息和错误处理）
 */
export interface ParseResult {
  /** 是否解析成功 */
  success: boolean
  /** 检测到的格式 */
  format: SudokuFormatType
  /** 解析出的谜题（可能多题，如 SDM） */
  puzzles: ParsedPuzzle[]
  /** 错误信息（解析失败时） */
  error?: string
}

// ============================================================
// 核心：智能格式识别与解析
// ============================================================

/**
 * 智能解析输入文本，自动识别格式并解析。
 *
 * 识别顺序：
 *   1. 种子 ID（difficulty:symmetry:seed）
 *   2. JSON（以 { 或 [ 开头）
 *   3. SDK（包含 #A/#D/#B/#S/#C 元数据行）
 *   4. SS（包含空格分隔的数字行）
 *   5. SDM（多行，每行 81 字符）
 *   6. 81 字符串（去杂后恰好 81 字符）
 */
export function parseSudokuInput(input: string): ParseResult {
  const trimmed = input.trim()
  if (trimmed.length === 0) {
    return { success: false, format: 'unknown', puzzles: [], error: 'error_empty_input' }
  }

  // 1. 种子 ID
  if (isSeedId(trimmed)) {
    return { success: true, format: 'seed', puzzles: [], error: undefined }
  }

  // 2. JSON
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      const puzzles = parseJsonFormat(trimmed)
      if (puzzles.length > 0) {
        return { success: true, format: 'json', puzzles }
      }
    } catch (e) {
      // fall through
    }
  }

  // 3. SDK（带元数据行）
  if (hasSdkMetadata(trimmed)) {
    try {
      const puzzle = parseSdkFormat(trimmed)
      return { success: true, format: 'sdk', puzzles: [puzzle] }
    } catch (e) {
      // fall through
    }
  }

  // 4. SS（空格分隔数字行）
  if (isSsFormat(trimmed)) {
    try {
      const puzzle = parseSsFormat(trimmed)
      return { success: true, format: 'ss', puzzles: [puzzle] }
    } catch (e) {
      // fall through
    }
  }

  // 5. SDM（多行 81 字符串）
  const sdmLines = extractSdmLines(trimmed)
  if (sdmLines.length > 1) {
    try {
      const puzzles = sdmLines.map(line => parse81String(line))
      return { success: true, format: 'sdm', puzzles }
    } catch (e) {
      // fall through
    }
  }

  // 6. 81 字符串（最宽松的匹配）
  const digits = extractDigits(trimmed)
  if (digits.length === TOTAL_CELLS) {
    try {
      const puzzle = parse81String(digits)
      return { success: true, format: '81string', puzzles: [puzzle] }
    } catch (e) {
      return { success: false, format: '81string', puzzles: [], error: `error_parse_81:${String(e)}` }
    }
  }

  return {
    success: false,
    format: 'unknown',
    puzzles: [],
    error: `error_unrecognized_format:${digits.length}`
  }
}

/**
 * 仅检测格式，不做完整解析
 */
export function detectFormat(input: string): SudokuFormatType {
  const trimmed = input.trim()
  if (isSeedId(trimmed)) return 'seed'
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return 'json'
  if (hasSdkMetadata(trimmed)) return 'sdk'
  if (isSsFormat(trimmed)) return 'ss'
  if (extractSdmLines(trimmed).length > 1) return 'sdm'
  if (extractDigits(trimmed).length === TOTAL_CELLS) return '81string'
  return 'unknown'
}

// ============================================================
// 格式检测辅助函数
// ============================================================

/**
 * 是否为种子 ID 格式：difficulty:symmetry:seed
 */
function isSeedId(input: string): boolean {
  return decodeSeedId(input) !== null
}

/**
 * 是否包含 SDK 元数据行（#A, #D, #B, #S, #C）
 */
function hasSdkMetadata(input: string): boolean {
  const lines = input.split('\n')
  for (const line of lines) {
    const t = line.trim()
    if (/^#[ADBSC]\s/.test(t)) {
      return true
    }
  }
  return false
}

/**
 * 是否为 SS 格式（空格分隔的数字行，至少 9 行有效数据）
 */
function isSsFormat(input: string): boolean {
  const lines = input.split('\n').filter(l => l.trim().length > 0)
  let dataLineCount = 0
  for (const line of lines) {
    const t = line.trim()
    // SS 行特征：包含空格分隔的数字或点，每行至少有 9 个有效字符
    const chars = t.replace(/\s+/g, '').split('').filter(c => /[0-9.]/.test(c))
    if (chars.length === GRID_SIZE && t.includes(' ')) {
      dataLineCount++
    }
  }
  return dataLineCount >= GRID_SIZE
}

/**
 * 提取 SDM 有效行（非注释非空行，且每行提取后为 81 字符）
 */
function extractSdmLines(input: string): string[] {
  return input.split('\n')
    .map(l => l.trim())
    .filter(l => l.length > 0 && !l.startsWith('#'))
    .filter(l => extractDigits(l).length === TOTAL_CELLS)
}

/**
 * 提取输入中的所有数字和点，点转为 0
 */
function extractDigits(input: string): string {
  return input.replace(/[^0-9.]/g, '').replace(/\./g, '0')
}

// ============================================================
// 各格式解析器
// ============================================================

/**
 * 解析 81 字符串为 GRID_SIZE×GRID_SIZE 棋盘
 */
export function parse81String(input: string): ParsedPuzzle {
  const digits = extractDigits(input)
  if (digits.length !== TOTAL_CELLS) {
    throw new Error(`error_need_81_digits:${digits.length}`)
  }

  const board: number[][] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    const row: number[] = []
    for (let c = 0; c < GRID_SIZE; c++) {
      const ch = digits[r * GRID_SIZE + c]
      row.push(Number.parseInt(ch, 10))
    }
    board.push(row)
  }

  validateBoard(board)
  return { board }
}

/**
 * 解析 SDK 格式（Sadman Sudoku）
 */
function parseSdkFormat(input: string): ParsedPuzzle {
  const lines = input.split('\n')
  const metadata: PuzzleMetadata = {}
  const dataLines: string[] = []

  for (const line of lines) {
    const t = line.trim()
    if (t.length === 0) continue

    if (t.startsWith('#A ')) {
      metadata.author = t.substring(3).trim()
    } else if (t.startsWith('#D ')) {
      metadata.description = t.substring(3).trim()
    } else if (t.startsWith('#B ')) {
      metadata.difficulty = t.substring(3).trim()
    } else if (t.startsWith('#S ')) {
      metadata.source = t.substring(3).trim()
    } else if (t.startsWith('#C ')) {
      metadata.comment = t.substring(3).trim()
    } else if (!t.startsWith('#')) {
      // 数据行：提取数字和点
      const clean = t.replace(/[^0-9.]/g, '')
      if (clean.length > 0) {
        dataLines.push(clean)
      }
    }
  }

  // 拼接所有数据行为 81 字符串
  const all = dataLines.join('')
  const parsed = parse81String(all)
  parsed.metadata = metadata
  return parsed
}

/**
 * 解析 SS 格式（Simple Sudoku）
 */
function parseSsFormat(input: string): ParsedPuzzle {
  const lines = input.split('\n')
  let digits = ''
  for (const line of lines) {
    const t = line.trim()
    if (t.length === 0) continue
    // 提取所有数字和点
    for (const ch of t) {
      if (/[1-9]/.test(ch)) {
        digits += ch
      } else if (ch === '.' || ch === '0') {
        digits += '0'
      }
      // 忽略空格和其他分隔符
    }
  }
  return parse81String(digits)
}

/**
 * 解析 JSON 格式
 * 支持两种结构：
 *   1. { "puzzle": "81chars...", "solution": "81chars..." }
 *   2. { "puzzle": [[...], ...] }
 *   3. [{ "puzzle": ... }, ...] 数组形式
 */
function parseJsonFormat(input: string): ParsedPuzzle[] {
  const obj: object = JSON.parse(input)
  const results: ParsedPuzzle[] = []

  if (Array.isArray(obj)) {
    // 数组形式
    const arr = obj as Object[]
    for (let i = 0; i < arr.length; i++) {
      const parsed = parseJsonObject(arr[i] as Record<string, Object>)
      if (parsed) results.push(parsed)
    }
  } else {
    const parsed = parseJsonObject(obj as Record<string, Object>)
    if (parsed) results.push(parsed)
  }

  return results
}

/**
 * 解析单个 JSON 对象为谜题
 */
function parseJsonObject(obj: Record<string, Object>): ParsedPuzzle | null {
  // 尝试找 puzzle 字段
  const puzzleField = obj['puzzle'] || obj['board'] || obj['data'] || obj['grid']
  if (!puzzleField) return null

  let board: number[][]

  if (typeof puzzleField === 'string') {
    // 字符串形式的 81 字符
    board = parse81String(puzzleField as string).board
  } else if (Array.isArray(puzzleField)) {
    const arr = puzzleField as Object[]
    if (arr.length === GRID_SIZE && Array.isArray(arr[0])) {
      // 二维数组
      board = (arr as number[][]).map(row =>
        row.map(v => typeof v === 'number' ? v : 0)
      )
    } else if (arr.length === TOTAL_CELLS) {
      // 一维数组
      board = []
      for (let r = 0; r < GRID_SIZE; r++) {
        const row: number[] = []
        for (let c = 0; c < GRID_SIZE; c++) {
          const v = arr[r * GRID_SIZE + c]
          row.push(typeof v === 'number' ? v as number : 0)
        }
        board.push(row)
      }
    } else {
      return null
    }
  } else {
    return null
  }

  validateBoard(board)

  const metadata: PuzzleMetadata = {}
  if (typeof obj['difficulty'] === 'string') {
    metadata.difficulty = obj['difficulty'] as string
  }
  if (typeof obj['author'] === 'string') {
    metadata.author = obj['author'] as string
  }
  if (typeof obj['source'] === 'string') {
    metadata.source = obj['source'] as string
  }

  return { board, metadata }
}

// ============================================================
// 验证
// ============================================================

/**
 * 基础棋盘验证：尺寸 + 数值范围 + 无冲突
 */
function validateBoard(board: number[][]): void {
  if (board.length !== GRID_SIZE) {
    throw new Error(`error_board_rows:${board.length}`)
  }
  for (let r = 0; r < GRID_SIZE; r++) {
    if (board[r].length !== GRID_SIZE) {
      throw new Error(`error_row_cols:${r + 1}:${board[r].length}`)
    }
    for (let c = 0; c < GRID_SIZE; c++) {
      const v = board[r][c]
      if (v < 0 || v > GRID_SIZE || !Number.isInteger(v)) {
        throw new Error(`error_cell_value:${r + 1}:${c + 1}:${v}`)
      }
    }
  }

  // 冲突检测：行、列、宫
  for (let r = 0; r < GRID_SIZE; r++) {
    const rowSeen: boolean[] = new Array(GRID_SIZE + 1).fill(false)
    for (let c = 0; c < GRID_SIZE; c++) {
      const v = board[r][c]
      if (v > 0) {
        if (rowSeen[v]) {
          throw new Error(`error_row_duplicate:${r + 1}:${v}`)
        }
        rowSeen[v] = true
      }
    }
  }
  for (let c = 0; c < GRID_SIZE; c++) {
    const colSeen: boolean[] = new Array(GRID_SIZE + 1).fill(false)
    for (let r = 0; r < GRID_SIZE; r++) {
      const v = board[r][c]
      if (v > 0) {
        if (colSeen[v]) {
          throw new Error(`error_col_duplicate:${c + 1}:${v}`)
        }
        colSeen[v] = true
      }
    }
  }
  for (let br = 0; br < BOX_COUNT; br++) {
    for (let bc = 0; bc < BOX_COUNT; bc++) {
      const boxSeen: boolean[] = new Array(GRID_SIZE + 1).fill(false)
      for (let dr = 0; dr < BOX_SIZE; dr++) {
        for (let dc = 0; dc < BOX_SIZE; dc++) {
          const v = board[br * BOX_SIZE + dr][bc * BOX_SIZE + dc]
          if (v > 0) {
            if (boxSeen[v]) {
              throw new Error(`error_box_duplicate:${br * BOX_COUNT + bc + 1}:${v}`)
            }
            boxSeen[v] = true
          }
        }
      }
    }
  }
}

// ============================================================
// 高级验证（可选调用，依赖 SudokuSolver）
// ============================================================

/**
 * 验证谜题是否有唯一解
 * 返回解的数量（0 = 无解, 1 = 唯一解, 2+ = 多解）
 * 需要导入 countSolutions
 */
export function validateUniqueness(board: number[][]): number {
  return _countSolutions(board, 2)
}

// 注入点：由调用方设置
let _countSolutions: (board: number[][], maxCount: number) => number =
  (_board: number[][], _maxCount: number): number => 0

/**
 * 初始化求解器引用（应在 App 启动时调用一次）
 */
export function initFormatSolver(countSolutions: (board: number[][], maxCount: number) => number): void {
  _countSolutions = countSolutions
}

// ============================================================
// 导出功能
// ============================================================

/**
 * 将棋盘导出为 81 字符串
 */
export function exportTo81String(board: number[][]): string {
  let result = ''
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      result += board[r][c].toString()
    }
  }
  return result
}

/**
 * 将棋盘导出为 SDK 格式
 */
export function exportToSdk(board: number[][], metadata?: PuzzleMetadata): string {
  let result = ''
  if (metadata?.description) result += `#D ${metadata.description}\n`
  if (metadata?.author) result += `#A ${metadata.author}\n`
  if (metadata?.difficulty) result += `#B ${metadata.difficulty}\n`
  if (metadata?.source) result += `#S ${metadata.source}\n`
  if (metadata?.comment) result += `#C ${metadata.comment}\n`
  for (const row of board) {
    result += row.map(v => v === 0 ? '.' : v.toString()).join('') + '\n'
  }
  return result.trimEnd()
}

/**
 * 将棋盘导出为 SS 格式（人类可读）
 */
export function exportToSs(board: number[][]): string {
  const lines: string[] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    const parts: string[] = []
    for (let c = 0; c < GRID_SIZE; c++) {
      const v = board[r][c]
      parts.push(v === 0 ? '.' : v.toString())
      // 每 BOX_SIZE 列加一个额外空格
      if ((c + 1) % BOX_SIZE === 0 && c < GRID_SIZE - 1) {
        parts.push('')
      }
    }
    lines.push(parts.join(' '))
    // 每 BOX_SIZE 行加一个空行
    if ((r + 1) % BOX_SIZE === 0 && r < GRID_SIZE - 1) {
      lines.push('')
    }
  }
  return lines.join('\n')
}

/**
 * 将棋盘导出为 JSON 格式
 */
export function exportToJson(board: number[][], metadata?: PuzzleMetadata): string {
  const obj = new Map<string, Object>()
  obj.set('puzzle', exportTo81String(board))
  if (metadata?.difficulty) obj.set('difficulty', metadata.difficulty)
  if (metadata?.author) obj.set('author', metadata.author)
  if (metadata?.source) obj.set('source', metadata.source)
  // 转为普通对象再序列化
  const plain: Record<string, Object> = {} as Record<string, Object>
  obj.forEach((v: Object, k: string) => {
    plain[k] = v
  })
  return JSON.stringify(plain, null, 2)
}

// ============================================================
// 便捷工具
// ============================================================

/**
 * 格式类型的 i18n 资源 key。
 * 调用方通过 resourceManager.getStringByNameSync() 解析。
 */
export function getFormatDisplayNameKey(format: SudokuFormatType): string {
  switch (format) {
    case 'seed': return 'format_seed'
    case '81string': return 'format_81string'
    case 'sdm': return 'format_sdm'
    case 'sdk': return 'format_sdk'
    case 'ss': return 'format_ss'
    case 'json': return 'format_json'
    default: return 'format_unknown'
  }
}

/**
 * 计算棋盘中已知数（给定数字）的数量
 */
export function countGivens(board: number[][]): number {
  let count = 0
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      if (board[r][c] > 0) count++
    }
  }
  return count
}

/**
 * 棋盘预览字符串（用于 UI 展示，SS 风格）
 */
export function boardPreview(board: number[][]): string {
  return exportToSs(board)
}
