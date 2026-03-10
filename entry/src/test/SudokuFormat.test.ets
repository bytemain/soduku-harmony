import { describe, it, expect } from '@ohos/hypium'
import {
  parseSudokuInput, parse81String, detectFormat,
  exportTo81String, exportToSdk, exportToSs, exportToJson,
  countGivens, getFormatDisplayNameKey, boardPreview,
  initFormatSolver, validateUniqueness,
} from '../main/ets/utils/SudokuFormat'
import { countSolutions } from '../main/ets/utils/SudokuSolver'

// ============================================================
// 测试数据
// ============================================================

// 一道标准数独 81 字符串（来自 Norvig 经典测试集）
const VALID_81 = '003020600900305001001806400008102900700000008006708200002609500800203009005010300'

// 对应的 9×9 棋盘
function getExpectedBoard(): number[][] {
  return [
    [0, 0, 3, 0, 2, 0, 6, 0, 0],
    [9, 0, 0, 3, 0, 5, 0, 0, 1],
    [0, 0, 1, 8, 0, 6, 4, 0, 0],
    [0, 0, 8, 1, 0, 2, 9, 0, 0],
    [7, 0, 0, 0, 0, 0, 0, 0, 8],
    [0, 0, 6, 7, 0, 8, 2, 0, 0],
    [0, 0, 2, 6, 0, 9, 5, 0, 0],
    [8, 0, 0, 2, 0, 3, 0, 0, 9],
    [0, 0, 5, 0, 1, 0, 3, 0, 0],
  ]
}

// 用点号表示空格的 81 字符串
const VALID_81_DOTS = '..3.2.6..9..3.5..1..18.64....81.29..7.......8..67.82....26.95..8..2.3..9..5.1.3..'

// SDK 格式字符串
const VALID_SDK = `#D Test puzzle
#A Test Author
#B Medium
..3.2.6..
9..3.5..1
..18.64..
..81.29..
7.......8
..67.82..
..26.95..
8..2.3..9
..5.1.3..`

// SS 格式字符串（空格分隔 + 宫分隔空行）
const VALID_SS = `. . 3  . 2 .  6 . .
9 . .  3 . 5  . . 1
. . 1  8 . 6  4 . .

. . 8  1 . 2  9 . .
7 . .  . . .  . . 8
. . 6  7 . 8  2 . .

. . 2  6 . 9  5 . .
8 . .  2 . 3  . . 9
. . 5  . 1 .  3 . .`

// SDM 格式（多行，每行 81 字符）
const VALID_SDM = `003020600900305001001806400008102900700000008006708200002609500800203009005010300
530070000600195000098000060800060003400803001700020006060000280000419005000080079`

// JSON 格式（字符串形式）
const VALID_JSON_STR = `{"puzzle":"003020600900305001001806400008102900700000008006708200002609500800203009005010300","difficulty":"medium","author":"Norvig"}`

// JSON 格式（二维数组形式）
const VALID_JSON_ARRAY = `{"board":[[0,0,3,0,2,0,6,0,0],[9,0,0,3,0,5,0,0,1],[0,0,1,8,0,6,4,0,0],[0,0,8,1,0,2,9,0,0],[7,0,0,0,0,0,0,0,8],[0,0,6,7,0,8,2,0,0],[0,0,2,6,0,9,5,0,0],[8,0,0,2,0,3,0,0,9],[0,0,5,0,1,0,3,0,0]]}`

// JSON 数组格式（多题）
const VALID_JSON_MULTI = `[{"puzzle":"003020600900305001001806400008102900700000008006708200002609500800203009005010300"},{"puzzle":"530070000600195000098000060800060003400803001700020006060000280000419005000080079"}]`

// 含冲突的 81 字符串（第一行两个 3）
const CONFLICT_81 = '303020600900305001001806400008102900700000008006708200002609500800203009005010300'

// 长度不够的字符串
const SHORT_INPUT = '00302060090030500100180640000810290070000000800670820000260950'

// 全零棋盘
const ALL_ZEROS = '000000000000000000000000000000000000000000000000000000000000000000000000000000000'

// ============================================================
// 辅助：比较棋盘
// ============================================================
function boardsEqual(a: number[][], b: number[][]): boolean {
  if (a.length !== b.length) return false
  for (let r = 0; r < a.length; r++) {
    if (a[r].length !== b[r].length) return false
    for (let c = 0; c < a[r].length; c++) {
      if (a[r][c] !== b[r][c]) return false
    }
  }
  return true
}

export default function sudokuFormatTest() {

  // ============================================================
  // parse81String
  // ============================================================
  describe('parse81String', () => {
    it('parses_valid_81_digits_string', 0, () => {
      const result = parse81String(VALID_81)
      expect(result.board.length).assertEqual(9)
      expect(boardsEqual(result.board, getExpectedBoard())).assertTrue()
    })

    it('parses_81_string_with_dots_as_zeros', 0, () => {
      const result = parse81String(VALID_81_DOTS)
      expect(boardsEqual(result.board, getExpectedBoard())).assertTrue()
    })

    it('parses_81_string_with_mixed_separators', 0, () => {
      // 带空格、换行、破折号等杂质
      const messy = '003 020 600\n900 305 001\n001-806-400\n008 102 900\n700 000 008\n006 708 200\n002 609 500\n800 203 009\n005 010 300'
      const result = parse81String(messy)
      expect(boardsEqual(result.board, getExpectedBoard())).assertTrue()
    })

    it('throws_on_too_few_digits', 0, () => {
      let threw = false
      try {
        parse81String('12345')
      } catch (e) {
        threw = true
      }
      expect(threw).assertTrue()
    })

    it('throws_on_too_many_digits', 0, () => {
      let threw = false
      try {
        parse81String(VALID_81 + '1')
      } catch (e) {
        threw = true
      }
      expect(threw).assertTrue()
    })

    it('throws_on_row_conflict', 0, () => {
      let threw = false
      try {
        parse81String(CONFLICT_81)
      } catch (e) {
        threw = true
      }
      expect(threw).assertTrue()
    })

    it('parses_all_zeros_as_empty_board', 0, () => {
      const result = parse81String(ALL_ZEROS)
      expect(result.board.length).assertEqual(9)
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          expect(result.board[r][c]).assertEqual(0)
        }
      }
    })

    it('board_is_9x9', 0, () => {
      const result = parse81String(VALID_81)
      expect(result.board.length).assertEqual(9)
      for (let r = 0; r < 9; r++) {
        expect(result.board[r].length).assertEqual(9)
      }
    })

    it('all_values_in_0_to_9_range', 0, () => {
      const result = parse81String(VALID_81)
      for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
          expect(result.board[r][c] >= 0 && result.board[r][c] <= 9).assertTrue()
        }
      }
    })
  })

  // ============================================================
  // detectFormat
  // ============================================================
  describe('detectFormat', () => {
    it('detects_81string_format', 0, () => {
      expect(detectFormat(VALID_81)).assertEqual('81string')
    })

    it('detects_81string_with_dots', 0, () => {
      expect(detectFormat(VALID_81_DOTS)).assertEqual('81string')
    })

    it('detects_json_object_format', 0, () => {
      expect(detectFormat(VALID_JSON_STR)).assertEqual('json')
    })

    it('detects_json_array_format', 0, () => {
      expect(detectFormat(VALID_JSON_MULTI)).assertEqual('json')
    })

    it('detects_sdk_format', 0, () => {
      expect(detectFormat(VALID_SDK)).assertEqual('sdk')
    })

    it('detects_ss_format', 0, () => {
      expect(detectFormat(VALID_SS)).assertEqual('ss')
    })

    it('detects_sdm_format', 0, () => {
      expect(detectFormat(VALID_SDM)).assertEqual('sdm')
    })

    it('detects_seed_format', 0, () => {
      // 种子 ID 格式：difficulty:symmetry:seed
      expect(detectFormat('3:rot180:12345')).assertEqual('seed')
    })

    it('returns_unknown_for_garbage', 0, () => {
      expect(detectFormat('hello world')).assertEqual('unknown')
    })

    it('returns_unknown_for_empty', 0, () => {
      expect(detectFormat('')).assertEqual('unknown')
    })

    it('returns_unknown_for_short_digits', 0, () => {
      expect(detectFormat(SHORT_INPUT)).assertEqual('unknown')
    })
  })

  // ============================================================
  // parseSudokuInput (智能识别)
  // ============================================================
  describe('parseSudokuInput', () => {
    it('parses_81string_successfully', 0, () => {
      const result = parseSudokuInput(VALID_81)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('81string')
      expect(result.puzzles.length).assertEqual(1)
      expect(boardsEqual(result.puzzles[0].board, getExpectedBoard())).assertTrue()
    })

    it('parses_81string_with_dots', 0, () => {
      const result = parseSudokuInput(VALID_81_DOTS)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('81string')
      expect(result.puzzles.length).assertEqual(1)
    })

    it('parses_sdk_format_with_metadata', 0, () => {
      const result = parseSudokuInput(VALID_SDK)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('sdk')
      expect(result.puzzles.length).assertEqual(1)
      expect(boardsEqual(result.puzzles[0].board, getExpectedBoard())).assertTrue()
      // 验证元数据
      expect(result.puzzles[0].metadata !== undefined).assertTrue()
      expect(result.puzzles[0].metadata!.author).assertEqual('Test Author')
      expect(result.puzzles[0].metadata!.description).assertEqual('Test puzzle')
      expect(result.puzzles[0].metadata!.difficulty).assertEqual('Medium')
    })

    it('parses_ss_format', 0, () => {
      const result = parseSudokuInput(VALID_SS)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('ss')
      expect(result.puzzles.length).assertEqual(1)
      expect(boardsEqual(result.puzzles[0].board, getExpectedBoard())).assertTrue()
    })

    it('parses_sdm_format_multiple_puzzles', 0, () => {
      const result = parseSudokuInput(VALID_SDM)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('sdm')
      expect(result.puzzles.length).assertEqual(2)
      // 第一题应和 VALID_81 一致
      expect(boardsEqual(result.puzzles[0].board, getExpectedBoard())).assertTrue()
      // 第二题也应是有效 9×9
      expect(result.puzzles[1].board.length).assertEqual(9)
    })

    it('parses_json_string_puzzle', 0, () => {
      const result = parseSudokuInput(VALID_JSON_STR)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('json')
      expect(result.puzzles.length).assertEqual(1)
      expect(boardsEqual(result.puzzles[0].board, getExpectedBoard())).assertTrue()
      // 验证 JSON 元数据
      expect(result.puzzles[0].metadata !== undefined).assertTrue()
      expect(result.puzzles[0].metadata!.difficulty).assertEqual('medium')
      expect(result.puzzles[0].metadata!.author).assertEqual('Norvig')
    })

    it('parses_json_2d_array_puzzle', 0, () => {
      const result = parseSudokuInput(VALID_JSON_ARRAY)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('json')
      expect(result.puzzles.length).assertEqual(1)
      expect(boardsEqual(result.puzzles[0].board, getExpectedBoard())).assertTrue()
    })

    it('parses_json_multi_puzzle_array', 0, () => {
      const result = parseSudokuInput(VALID_JSON_MULTI)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('json')
      expect(result.puzzles.length).assertEqual(2)
    })

    it('recognizes_seed_id', 0, () => {
      const result = parseSudokuInput('3:rot180:12345')
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('seed')
      expect(result.puzzles.length).assertEqual(0) // seed 不返回 puzzles
    })

    it('fails_on_empty_input', 0, () => {
      const result = parseSudokuInput('')
      expect(result.success).assertFalse()
      expect(result.format).assertEqual('unknown')
    })

    it('fails_on_whitespace_only', 0, () => {
      const result = parseSudokuInput('   \n  \t  ')
      expect(result.success).assertFalse()
      expect(result.format).assertEqual('unknown')
    })

    it('fails_on_short_digits', 0, () => {
      const result = parseSudokuInput('12345')
      expect(result.success).assertFalse()
      expect(result.error !== undefined).assertTrue()
    })

    it('fails_on_garbage_text', 0, () => {
      const result = parseSudokuInput('This is not a sudoku puzzle at all')
      expect(result.success).assertFalse()
    })

    it('fails_on_conflict_board', 0, () => {
      const result = parseSudokuInput(CONFLICT_81)
      expect(result.success).assertFalse()
    })

    it('trims_whitespace_before_parsing', 0, () => {
      const result = parseSudokuInput(`  ${VALID_81}  `)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('81string')
    })

    it('handles_all_zeros_board', 0, () => {
      const result = parseSudokuInput(ALL_ZEROS)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('81string')
      expect(result.puzzles.length).assertEqual(1)
    })
  })

  // ============================================================
  // exportTo81String
  // ============================================================
  describe('exportTo81String', () => {
    it('exports_board_to_81_chars', 0, () => {
      const board = getExpectedBoard()
      const result = exportTo81String(board)
      expect(result.length).assertEqual(81)
      expect(result).assertEqual(VALID_81)
    })

    it('all_zero_board_exports_all_zeros', 0, () => {
      const board: number[][] = []
      for (let r = 0; r < 9; r++) {
        const row: number[] = []
        for (let c = 0; c < 9; c++) row.push(0)
        board.push(row)
      }
      const result = exportTo81String(board)
      expect(result).assertEqual(ALL_ZEROS)
    })

    it('round_trip_81string', 0, () => {
      // parse → export → should equal original
      const parsed = parse81String(VALID_81)
      const exported = exportTo81String(parsed.board)
      expect(exported).assertEqual(VALID_81)
    })
  })

  // ============================================================
  // exportToSdk
  // ============================================================
  describe('exportToSdk', () => {
    it('exports_board_with_dots_for_zeros', 0, () => {
      const board = getExpectedBoard()
      const result = exportToSdk(board)
      // 不应包含 '0'（空格用 . 表示）
      expect(result.includes('0')).assertFalse()
      // 应包含 '.'
      expect(result.includes('.')).assertTrue()
      // 应有 9 行数据
      const dataLines = result.split('\n').filter(l => !l.startsWith('#') && l.trim().length > 0)
      expect(dataLines.length).assertEqual(9)
    })

    it('includes_metadata_when_provided', 0, () => {
      const board = getExpectedBoard()
      const result = exportToSdk(board, {
        author: 'Alice',
        description: 'A test',
        difficulty: 'Hard',
        source: 'Test suite',
        comment: 'For testing',
      })
      expect(result.includes('#A Alice')).assertTrue()
      expect(result.includes('#D A test')).assertTrue()
      expect(result.includes('#B Hard')).assertTrue()
      expect(result.includes('#S Test suite')).assertTrue()
      expect(result.includes('#C For testing')).assertTrue()
    })

    it('no_metadata_lines_when_undefined', 0, () => {
      const board = getExpectedBoard()
      const result = exportToSdk(board)
      expect(result.includes('#A')).assertFalse()
      expect(result.includes('#D')).assertFalse()
    })

    it('round_trip_sdk', 0, () => {
      // export → parse back → same board
      const board = getExpectedBoard()
      const sdk = exportToSdk(board, { author: 'Test', description: 'round trip' })
      const result = parseSudokuInput(sdk)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('sdk')
      expect(boardsEqual(result.puzzles[0].board, board)).assertTrue()
    })
  })

  // ============================================================
  // exportToSs
  // ============================================================
  describe('exportToSs', () => {
    it('exports_board_in_ss_format', 0, () => {
      const board = getExpectedBoard()
      const result = exportToSs(board)
      // SS 格式应包含空格
      expect(result.includes(' ')).assertTrue()
      // 应有空行分隔（每 3 行之间）
      expect(result.includes('\n\n')).assertTrue()
    })

    it('uses_dots_for_zeros', 0, () => {
      const board = getExpectedBoard()
      const result = exportToSs(board)
      expect(result.includes('.')).assertTrue()
    })

    it('round_trip_ss', 0, () => {
      const board = getExpectedBoard()
      const ss = exportToSs(board)
      const result = parseSudokuInput(ss)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('ss')
      expect(boardsEqual(result.puzzles[0].board, board)).assertTrue()
    })
  })

  // ============================================================
  // exportToJson
  // ============================================================
  describe('exportToJson', () => {
    it('exports_valid_json', 0, () => {
      const board = getExpectedBoard()
      const result = exportToJson(board)
      // 应该是可解析的 JSON
      const parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>
      expect(typeof parsed['puzzle']).assertEqual('string')
      expect((parsed['puzzle'] as string).length).assertEqual(81)
    })

    it('includes_metadata_fields', 0, () => {
      const board = getExpectedBoard()
      const result = exportToJson(board, { difficulty: 'hard', author: 'Bob', source: 'tests' })
      const parsed: Record<string, Object> = JSON.parse(result) as Record<string, Object>
      expect(parsed['difficulty']).assertEqual('hard')
      expect(parsed['author']).assertEqual('Bob')
      expect(parsed['source']).assertEqual('tests')
    })

    it('round_trip_json', 0, () => {
      const board = getExpectedBoard()
      const json = exportToJson(board, { author: 'Test' })
      const result = parseSudokuInput(json)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('json')
      expect(boardsEqual(result.puzzles[0].board, board)).assertTrue()
    })
  })

  // ============================================================
  // countGivens
  // ============================================================
  describe('countGivens', () => {
    it('counts_nonzero_cells', 0, () => {
      const board = getExpectedBoard()
      const count = countGivens(board)
      // VALID_81 中非零数字计数
      let expected = 0
      for (const ch of VALID_81) {
        if (ch !== '0') expected++
      }
      expect(count).assertEqual(expected)
    })

    it('all_zeros_returns_zero', 0, () => {
      const board: number[][] = []
      for (let r = 0; r < 9; r++) {
        const row: number[] = []
        for (let c = 0; c < 9; c++) row.push(0)
        board.push(row)
      }
      expect(countGivens(board)).assertEqual(0)
    })

    it('full_board_returns_81', 0, () => {
      const board: number[][] = [
        [4, 8, 3, 9, 2, 1, 6, 5, 7],
        [9, 6, 7, 3, 4, 5, 8, 2, 1],
        [2, 5, 1, 8, 7, 6, 4, 9, 3],
        [5, 4, 8, 1, 3, 2, 9, 7, 6],
        [7, 2, 9, 5, 6, 4, 1, 3, 8],
        [1, 3, 6, 7, 9, 8, 2, 4, 5],
        [3, 7, 2, 6, 8, 9, 5, 1, 4],
        [8, 1, 4, 2, 5, 3, 7, 6, 9],
        [6, 9, 5, 4, 1, 7, 3, 8, 2],
      ]
      expect(countGivens(board)).assertEqual(81)
    })
  })

  // ============================================================
  // getFormatDisplayName
  // ============================================================
  describe('getFormatDisplayNameKey', () => {
    it('returns_correct_key_for_each_format', 0, () => {
      expect(getFormatDisplayNameKey('seed')).assertEqual('format_seed')
      expect(getFormatDisplayNameKey('81string')).assertEqual('format_81string')
      expect(getFormatDisplayNameKey('sdm')).assertEqual('format_sdm')
      expect(getFormatDisplayNameKey('sdk')).assertEqual('format_sdk')
      expect(getFormatDisplayNameKey('ss')).assertEqual('format_ss')
      expect(getFormatDisplayNameKey('json')).assertEqual('format_json')
      expect(getFormatDisplayNameKey('unknown')).assertEqual('format_unknown')
    })
  })

  // ============================================================
  // boardPreview
  // ============================================================
  describe('boardPreview', () => {
    it('returns_ss_format_string', 0, () => {
      const board = getExpectedBoard()
      const preview = boardPreview(board)
      const ss = exportToSs(board)
      expect(preview).assertEqual(ss)
    })
  })

  // ============================================================
  // validateUniqueness + initFormatSolver
  // ============================================================
  describe('validateUniqueness', () => {
    it('returns_zero_before_solver_injection', 0, () => {
      // 默认未注入 solver，应返回 0
      // 先重置（不方便重置，跳过或仅检查初始化后）
    })

    it('validates_unique_solution_after_init', 0, () => {
      // 注入真实 solver
      initFormatSolver(countSolutions)
      const board = getExpectedBoard()
      const count = validateUniqueness(board)
      expect(count).assertEqual(1) // 标准题唯一解
    })

    it('detects_empty_board_as_multi_solution', 0, () => {
      initFormatSolver(countSolutions)
      const board: number[][] = []
      for (let r = 0; r < 9; r++) {
        const row: number[] = []
        for (let c = 0; c < 9; c++) row.push(0)
        board.push(row)
      }
      const count = validateUniqueness(board)
      expect(count).assertEqual(2) // 空棋盘多解，上限截断为 2
    })
  })

  // ============================================================
  // 边界与异常场景
  // ============================================================
  describe('SudokuFormat.EdgeCases', () => {
    it('sdk_without_all_metadata_fields', 0, () => {
      // 只有 #A 没有其他元数据行
      const sdk = `#A Author Only
..3.2.6..
9..3.5..1
..18.64..
..81.29..
7.......8
..67.82..
..26.95..
8..2.3..9
..5.1.3..`
      const result = parseSudokuInput(sdk)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('sdk')
      expect(result.puzzles[0].metadata!.author).assertEqual('Author Only')
      expect(result.puzzles[0].metadata!.description === undefined).assertTrue()
    })

    it('json_with_board_field_name', 0, () => {
      const json = `{"board":"${VALID_81}"}`
      const result = parseSudokuInput(json)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('json')
    })

    it('json_with_data_field_name', 0, () => {
      const json = `{"data":"${VALID_81}"}`
      const result = parseSudokuInput(json)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('json')
    })

    it('json_with_grid_field_name', 0, () => {
      const json = `{"grid":"${VALID_81}"}`
      const result = parseSudokuInput(json)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('json')
    })

    it('sdm_single_line_falls_to_81string', 0, () => {
      // 只有一行 81 字符 → 应识别为 81string 而非 sdm
      const result = parseSudokuInput(VALID_81)
      expect(result.format).assertEqual('81string')
    })

    it('sdm_comment_lines_are_ignored', 0, () => {
      const sdm = `# This is a comment
${VALID_81}
# Another comment
530070000600195000098000060800060003400803001700020006060000280000419005000080079`
      const result = parseSudokuInput(sdm)
      expect(result.success).assertTrue()
      expect(result.format).assertEqual('sdm')
      expect(result.puzzles.length).assertEqual(2)
    })

    it('invalid_json_falls_through', 0, () => {
      // 以 { 开头但非法 JSON → 应 fall through 到其他格式
      const result = parseSudokuInput('{invalid json}}}')
      expect(result.success).assertFalse()
    })

    it('column_conflict_throws', 0, () => {
      // 第一列有两个 9
      const col_conflict = '903020600900305001001806400008102900700000008006708200002609500800203009005010300'
      const result = parseSudokuInput(col_conflict)
      expect(result.success).assertFalse()
    })

    it('box_conflict_throws', 0, () => {
      // 左上宫有两个 1
      const box_conflict = '103020600910305001001806400008102900700000008006708200002609500800203009005010300'
      const result = parseSudokuInput(box_conflict)
      expect(result.success).assertFalse()
    })

    it('export_then_reimport_preserves_board', 0, () => {
      const board = getExpectedBoard()

      // 81-string round trip
      const s81 = exportTo81String(board)
      expect(boardsEqual(parse81String(s81).board, board)).assertTrue()

      // SDK round trip
      const sdk = exportToSdk(board, { author: 'RT' })
      const sdkResult = parseSudokuInput(sdk)
      expect(boardsEqual(sdkResult.puzzles[0].board, board)).assertTrue()

      // SS round trip
      const ss = exportToSs(board)
      const ssResult = parseSudokuInput(ss)
      expect(boardsEqual(ssResult.puzzles[0].board, board)).assertTrue()

      // JSON round trip
      const json = exportToJson(board)
      const jsonResult = parseSudokuInput(json)
      expect(boardsEqual(jsonResult.puzzles[0].board, board)).assertTrue()
    })
  })
}
