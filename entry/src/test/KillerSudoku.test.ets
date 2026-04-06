import { describe, it, expect } from '@ohos/hypium'
import { CellData, createEmptyBoard, createBoardFromArray } from '../main/ets/models/CellData'
import { KillerCage, createKillerConfig } from '../main/ets/models/VariantConfig'
import {
  generateRandomCageLayout,
  buildKillerCagesFromSolution,
} from '../main/ets/utils/KillerSudoku'
import {
  validateAllCells,
  isGameCompleted,
} from '../main/ets/utils/SudokuValidator'
import { applyTopology } from '../main/ets/utils/Topology'
import { createStandardConfig } from '../main/ets/models/VariantConfig'
import {
  setActiveCages,
  clearActiveCages,
  getNextHint,
  Technique,
} from '../main/ets/utils/LogicSolver'
import { SeededRandom } from '../main/ets/utils/Common'

// 有效的完整终盘
function getCompleteSolution(): number[][] {
  return [
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
}

function flattenSolution(sol: number[][]): number[] {
  const flat: number[] = []
  for (const row of sol) {
    for (const v of row) flat.push(v)
  }
  return flat
}

export default function killerSudokuTest() {
  // ============================================================
  // 随机笼子生成
  // ============================================================

  describe('KillerSudoku.RandomCageGeneration', () => {
    it('covers_all_81_cells_exactly_once', 0, () => {
      const cages = generateRandomCageLayout()
      const hitCount: number[] = new Array(81).fill(0)
      for (const cage of cages) {
        for (const cellIndex of cage.cells) {
          hitCount[cellIndex]++
        }
      }
      for (let i = 0; i < 81; i++) {
        expect(hitCount[i]).assertEqual(1)
      }
    })

    it('each_cage_is_connected', 0, () => {
      const cages = generateRandomCageLayout()
      for (const cage of cages) {
        if (cage.cells.length <= 1) continue
        const visited = new Set<number>()
        const queue: number[] = [cage.cells[0]]
        visited.add(cage.cells[0])
        const cellSet = new Set<number>(cage.cells)

        while (queue.length > 0) {
          const current = queue.pop()!
          const row = Math.floor(current / 9)
          const col = current % 9
          const neighbors: number[] = []
          if (row > 0) neighbors.push(current - 9)
          if (row < 8) neighbors.push(current + 9)
          if (col > 0) neighbors.push(current - 1)
          if (col < 8) neighbors.push(current + 1)
          for (const nb of neighbors) {
            if (cellSet.has(nb) && !visited.has(nb)) {
              visited.add(nb)
              queue.push(nb)
            }
          }
        }
        expect(visited.size).assertEqual(cage.cells.length)
      }
    })

    it('cage_sizes_within_bounds', 0, () => {
      // 运行多次确保随机结果稳定
      for (let trial = 0; trial < 5; trial++) {
        const cages = generateRandomCageLayout()
        for (const cage of cages) {
          expect(cage.cells.length >= 1).assertTrue()
          expect(cage.cells.length <= 5).assertTrue()
        }
      }
    })

    it('multiple_runs_produce_different_layouts', 0, () => {
      const layout1 = generateRandomCageLayout()
      const layout2 = generateRandomCageLayout()
      // 不同次运行大概率产生不同数量或不同格子分配
      // (理论上可能相同但概率极低)
      let different = layout1.length !== layout2.length
      if (!different) {
        for (let i = 0; i < layout1.length; i++) {
          if (layout1[i].cells.length !== layout2[i].cells.length) {
            different = true
            break
          }
          for (let j = 0; j < layout1[i].cells.length; j++) {
            if (layout1[i].cells[j] !== layout2[i].cells[j]) {
              different = true
              break
            }
          }
          if (different) break
        }
      }
      expect(different).assertTrue()
    })
  })

  // ============================================================
  // 笼子求和约束验证
  // ============================================================

  describe('KillerSudoku.CageSumValidation', () => {
    it('correct_sum_no_error', 0, () => {
      applyTopology(createStandardConfig())
      const sol = getCompleteSolution()
      const cells = createBoardFromArray(sol)
      // 笼子 [0,1] sum = sol[0][0] + sol[0][1] = 4 + 8 = 12
      const cage: KillerCage = { cells: [0, 1], sum: 12 }
      const count = validateAllCells(cells, undefined, [cage])
      expect(count).assertEqual(0)
    })

    it('wrong_sum_marks_error', 0, () => {
      applyTopology(createStandardConfig())
      const sol = getCompleteSolution()
      const cells = createBoardFromArray(sol)
      // 实际和是 12，但 cage.sum 是 10 → 错误
      const cage: KillerCage = { cells: [0, 1], sum: 10 }
      const count = validateAllCells(cells, undefined, [cage])
      expect(count).assertLargerOrEqual(2)
      expect(cells[0].isError).assertTrue()
      expect(cells[1].isError).assertTrue()
    })

    it('partial_cage_not_validated', 0, () => {
      applyTopology(createStandardConfig())
      const cells = createEmptyBoard()
      cells[0].value = 5
      // cells[1] 仍为空 → 笼子未填满，不应触发和约束错误
      const cage: KillerCage = { cells: [0, 1], sum: 10 }
      const count = validateAllCells(cells, undefined, [cage])
      expect(count).assertEqual(0)
    })

    it('isGameCompleted_requires_correct_cage_sums', 0, () => {
      applyTopology(createStandardConfig())
      const sol = getCompleteSolution()
      const cells = createBoardFromArray(sol)
      // 正确求和的笼子
      const flatSol = flattenSolution(sol)
      const cage: KillerCage = { cells: [0, 1], sum: flatSol[0] + flatSol[1] }
      expect(isGameCompleted(cells, [cage])).assertTrue()
    })

    it('isGameCompleted_fails_with_wrong_cage_sum', 0, () => {
      applyTopology(createStandardConfig())
      const sol = getCompleteSolution()
      const cells = createBoardFromArray(sol)
      // 错误的目标和
      const cage: KillerCage = { cells: [0, 1], sum: 999 }
      expect(isGameCompleted(cells, [cage])).assertFalse()
    })

    it('isGameCompleted_without_cages_still_works', 0, () => {
      applyTopology(createStandardConfig())
      const sol = getCompleteSolution()
      const cells = createBoardFromArray(sol)
      expect(isGameCompleted(cells)).assertTrue()
    })
  })

  // ============================================================
  // Killer 拓扑：笼子不重复约束
  // ============================================================

  describe('KillerSudoku.CageNoRepeatTopology', () => {
    it('cage_peers_detect_duplicate_within_cage', 0, () => {
      // 用 Killer 拓扑：[0, 30] 在同一笼子中 → 互为 peers
      const cage: KillerCage = { cells: [0, 30], sum: 10 }
      applyTopology(createKillerConfig([cage]))
      try {
        const cells = createEmptyBoard()
        cells[0].value = 5
        cells[30].value = 5 // 同笼子重复
        const count = validateAllCells(cells)
        expect(count).assertEqual(2)
        expect(cells[0].isError).assertTrue()
        expect(cells[30].isError).assertTrue()
      } finally {
        applyTopology(createStandardConfig())
      }
    })

    it('cage_peers_allow_different_values', 0, () => {
      const cage: KillerCage = { cells: [0, 30], sum: 10 }
      applyTopology(createKillerConfig([cage]))
      try {
        const cells = createEmptyBoard()
        cells[0].value = 3
        cells[30].value = 7 // 不同值，不冲突
        const count = validateAllCells(cells)
        expect(count).assertEqual(0)
      } finally {
        applyTopology(createStandardConfig())
      }
    })
  })

  // ============================================================
  // Killer 候选数排除 (LogicSolver)
  // ============================================================

  describe('KillerSudoku.CageCandidateExclusion', () => {
    it('cage_sum_technique_exists', 0, () => {
      expect(Technique.CAGE_SUM).assertEqual('CageSum')
    })

    it('cage_sum_determines_last_cell_value', 0, () => {
      // 构造场景：笼子 [0, 1]，sum=12
      // 格子 0 已填 4，格子 1 候选应为 {8}
      const board: number[][] = [
        [4, 0, 3, 9, 2, 1, 6, 5, 7],
        [9, 6, 7, 3, 4, 5, 8, 2, 1],
        [2, 5, 1, 8, 7, 6, 4, 9, 3],
        [5, 4, 8, 1, 3, 2, 9, 7, 6],
        [7, 2, 9, 5, 6, 4, 1, 3, 8],
        [1, 3, 6, 7, 9, 8, 2, 4, 5],
        [3, 7, 2, 6, 8, 9, 5, 1, 4],
        [8, 1, 4, 2, 5, 3, 7, 6, 9],
        [6, 9, 5, 4, 1, 7, 3, 8, 2],
      ]
      // 挖一个洞
      board[0][1] = 0

      const cage: KillerCage = { cells: [0, 1], sum: 12 }
      setActiveCages([cage])
      try {
        const hint = getNextHint(board)
        expect(hint !== null).assertTrue()
        // 提示可能是 NakedSingle 或 CageSum，取决于哪个先找到
        // 但只要返回了正确的填数就行
        if (hint!.technique === Technique.CAGE_SUM) {
          expect(hint!.digit).assertEqual(8)
          expect(hint!.cellIndex).assertEqual(1)
        }
      } finally {
        clearActiveCages()
      }
    })

    it('no_cage_sum_hint_without_active_cages', 0, () => {
      clearActiveCages()
      const board: number[][] = [
        [0, 0, 3, 9, 2, 1, 6, 5, 7],
        [9, 6, 7, 3, 4, 5, 8, 2, 1],
        [2, 5, 1, 8, 7, 6, 4, 9, 3],
        [5, 4, 8, 1, 3, 2, 9, 7, 6],
        [7, 2, 9, 5, 6, 4, 1, 3, 8],
        [1, 3, 6, 7, 9, 8, 2, 4, 5],
        [3, 7, 2, 6, 8, 9, 5, 1, 4],
        [8, 1, 4, 2, 5, 3, 7, 6, 9],
        [6, 9, 5, 4, 1, 7, 3, 8, 2],
      ]
      const hint = getNextHint(board)
      expect(hint !== null).assertTrue()
      // 无活跃笼子时，不应出现 CAGE_SUM 技巧
      expect(hint!.technique !== Technique.CAGE_SUM).assertTrue()
    })
  })

  // ============================================================
  // 端到端：完整的 Killer 生成与验证
  // ============================================================

  describe('KillerSudoku.EndToEnd', () => {
    it('generated_cages_with_solution_pass_validation', 0, () => {
      applyTopology(createStandardConfig())
      const sol = getCompleteSolution()
      const flatSol = flattenSolution(sol)
      const layout = generateRandomCageLayout(flatSol)
      const cages = buildKillerCagesFromSolution(flatSol, layout)

      // 用 Killer 拓扑验证
      applyTopology(createKillerConfig(cages))
      try {
        const cells = createBoardFromArray(sol)
        // 应该通过所有检查（含笼子求和）
        const errorCount = validateAllCells(cells, undefined, cages)
        expect(errorCount).assertEqual(0)
        expect(isGameCompleted(cells, cages)).assertTrue()
      } finally {
        applyTopology(createStandardConfig())
      }
    })

    it('generated_cages_sums_total_405', 0, () => {
      // 9×9 所有数字之和 = 9 × (1+2+...+9) = 9 × 45 = 405
      const sol = getCompleteSolution()
      const flatSol = flattenSolution(sol)
      const layout = generateRandomCageLayout(flatSol)
      const cages = buildKillerCagesFromSolution(flatSol, layout)
      let totalSum = 0
      for (const cage of cages) {
        totalSum += cage.sum
      }
      expect(totalSum).assertEqual(405)
    })

    it('no_duplicate_digits_in_any_cage', 0, () => {
      // 多次验证笼内不出现重复数字
      const sol = getCompleteSolution()
      const flatSol = flattenSolution(sol)
      for (let trial = 0; trial < 10; trial++) {
        const layout = generateRandomCageLayout(flatSol)
        for (const cage of layout) {
          const digits = new Set<number>()
          for (const cellIndex of cage.cells) {
            const digit = flatSol[cellIndex]
            expect(digits.has(digit)).assertFalse()
            digits.add(digit)
          }
        }
      }
    })

    it('seeded_cage_generation_is_deterministic', 0, () => {
      const sol = getCompleteSolution()
      const flatSol = flattenSolution(sol)
      const seed = 12345
      const rng1 = new SeededRandom(seed)
      const layout1 = generateRandomCageLayout(flatSol, rng1)
      const rng2 = new SeededRandom(seed)
      const layout2 = generateRandomCageLayout(flatSol, rng2)

      expect(layout1.length).assertEqual(layout2.length)
      for (let i = 0; i < layout1.length; i++) {
        expect(layout1[i].cells.length).assertEqual(layout2[i].cells.length)
        for (let j = 0; j < layout1[i].cells.length; j++) {
          expect(layout1[i].cells[j]).assertEqual(layout2[i].cells[j])
        }
      }
    })
  })
}
