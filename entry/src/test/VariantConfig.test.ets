import { describe, it, expect } from '@ohos/hypium'
import {
  VariantType, KillerCage,
  GRID_4x4, GRID_6x6, GRID_9x9, GRID_12x12, GRID_16x16,
  createStandardConfig, createDiagonalConfig, createJigsawConfig,
  createKillerConfig, createSizedConfig, createDefaultJigsawConfig, createDefaultJigsawRegionMap,
  STANDARD_CONFIG, buildStandardRegionMap, getRegionMap,
} from '../main/ets/models/VariantConfig'
import { buildJigsawBoardDecorations, buildKillerBoardDecorations } from '../main/ets/models/BoardDecoration'
import { buildKillerCagesFromSolution, generateRandomCageLayout, normalizeVariantType } from '../main/ets/utils/KillerSudoku'

export default function variantConfigTest() {
  describe('VariantConfig.GridPresets', () => {
    it('GRID_4x4_dimensions', 0, () => {
      expect(GRID_4x4.gridSize).assertEqual(4)
      expect(GRID_4x4.boxRows).assertEqual(2)
      expect(GRID_4x4.boxCols).assertEqual(2)
      expect(GRID_4x4.totalCells).assertEqual(16)
      expect(GRID_4x4.digits.length).assertEqual(4)
    })

    it('GRID_6x6_dimensions', 0, () => {
      expect(GRID_6x6.gridSize).assertEqual(6)
      expect(GRID_6x6.boxRows).assertEqual(2)
      expect(GRID_6x6.boxCols).assertEqual(3)
      expect(GRID_6x6.totalCells).assertEqual(36)
      expect(GRID_6x6.digits.length).assertEqual(6)
    })

    it('GRID_9x9_dimensions', 0, () => {
      expect(GRID_9x9.gridSize).assertEqual(9)
      expect(GRID_9x9.boxRows).assertEqual(3)
      expect(GRID_9x9.boxCols).assertEqual(3)
      expect(GRID_9x9.totalCells).assertEqual(81)
      expect(GRID_9x9.digits.length).assertEqual(9)
    })

    it('GRID_12x12_dimensions', 0, () => {
      expect(GRID_12x12.gridSize).assertEqual(12)
      expect(GRID_12x12.boxRows).assertEqual(3)
      expect(GRID_12x12.boxCols).assertEqual(4)
      expect(GRID_12x12.totalCells).assertEqual(144)
      expect(GRID_12x12.digits.length).assertEqual(12)
    })

    it('GRID_16x16_dimensions', 0, () => {
      expect(GRID_16x16.gridSize).assertEqual(16)
      expect(GRID_16x16.boxRows).assertEqual(4)
      expect(GRID_16x16.boxCols).assertEqual(4)
      expect(GRID_16x16.totalCells).assertEqual(256)
      expect(GRID_16x16.digits.length).assertEqual(16)
    })

    it('grid_totalCells_equals_gridSize_squared', 0, () => {
      const grids = [GRID_4x4, GRID_6x6, GRID_9x9, GRID_12x12, GRID_16x16]
      for (const g of grids) {
        expect(g.totalCells).assertEqual(g.gridSize * g.gridSize)
      }
    })

    it('grid_boxRows_times_boxCols_equals_gridSize', 0, () => {
      const grids = [GRID_4x4, GRID_6x6, GRID_9x9, GRID_12x12, GRID_16x16]
      for (const g of grids) {
        expect(g.boxRows * g.boxCols).assertEqual(g.gridSize)
      }
    })

    it('digits_are_1_to_gridSize', 0, () => {
      const grids = [GRID_4x4, GRID_6x6, GRID_9x9, GRID_12x12, GRID_16x16]
      for (const g of grids) {
        for (let i = 0; i < g.digits.length; i++) {
          expect(g.digits[i]).assertEqual(i + 1)
        }
      }
    })
  })

  describe('VariantConfig.Factories', () => {
    it('createStandardConfig_returns_standard', 0, () => {
      const config = createStandardConfig()
      expect(config.type).assertEqual(VariantType.STANDARD)
      expect(config.grid.gridSize).assertEqual(9)
      expect(config.hasDiagonals).assertFalse()
      expect(config.regions).assertNull()
      expect(config.cages).assertNull()
    })

    it('createDiagonalConfig_has_diagonals', 0, () => {
      const config = createDiagonalConfig()
      expect(config.type).assertEqual(VariantType.DIAGONAL)
      expect(config.grid.gridSize).assertEqual(9)
      expect(config.hasDiagonals).assertTrue()
      expect(config.regions).assertNull()
      expect(config.cages).assertNull()
    })

    it('createJigsawConfig_has_custom_regions', 0, () => {
      const mockRegionMap: number[] = []
      for (let i = 0; i < 81; i++) {
        mockRegionMap.push(i % 9)
      }
      const config = createJigsawConfig(mockRegionMap)
      expect(config.type).assertEqual(VariantType.JIGSAW)
      expect(config.hasDiagonals).assertFalse()
      expect(config.regions !== null).assertTrue()
      expect(config.regions!.regionCount).assertEqual(9)
      expect(config.regions!.regionMap.length).assertEqual(81)
      expect(config.cages).assertNull()
    })

    it('createDefaultJigsawConfig_has_default_regions', 0, () => {
      const config = createDefaultJigsawConfig()
      expect(config.type).assertEqual(VariantType.JIGSAW)
      expect(config.regions !== null).assertTrue()
      expect(config.regions!.regionCount).assertEqual(9)
      expect(config.regions!.regionMap.length).assertEqual(81)
    })

    it('createKillerConfig_has_cages', 0, () => {
      const cage1: KillerCage = { cells: [0, 1], sum: 10 }
      const cage2: KillerCage = { cells: [2, 3, 4], sum: 15 }
      const cages: KillerCage[] = [cage1, cage2]
      const config = createKillerConfig(cages)
      expect(config.type).assertEqual(VariantType.KILLER)
      expect(config.hasDiagonals).assertFalse()
      expect(config.regions).assertNull()
      expect(config.cages !== null).assertTrue()
      expect(config.cages!.length).assertEqual(2)
      expect(config.cages![0].sum).assertEqual(10)
      expect(config.cages![1].cells.length).assertEqual(3)
    })

    it('createSizedConfig_4x4', 0, () => {
      const config = createSizedConfig(4, 2, 2)
      expect(config.type).assertEqual(VariantType.STANDARD)
      expect(config.grid.gridSize).assertEqual(4)
      expect(config.grid.boxRows).assertEqual(2)
      expect(config.grid.boxCols).assertEqual(2)
      expect(config.grid.totalCells).assertEqual(16)
      expect(config.grid.digits.length).assertEqual(4)
    })

    it('createSizedConfig_12x12', 0, () => {
      const config = createSizedConfig(12, 3, 4)
      expect(config.grid.gridSize).assertEqual(12)
      expect(config.grid.totalCells).assertEqual(144)
      expect(config.grid.digits.length).assertEqual(12)
      expect(config.grid.digits[11]).assertEqual(12)
    })
  })

  describe('VariantConfig.RegionMap', () => {
    it('buildStandardRegionMap_9x9_length', 0, () => {
      const map = buildStandardRegionMap(GRID_9x9)
      expect(map.length).assertEqual(81)
    })

    it('buildStandardRegionMap_9x9_cell_0_0_in_region_0', 0, () => {
      const map = buildStandardRegionMap(GRID_9x9)
      expect(map[0]).assertEqual(0) // (0,0) → box 0
    })

    it('buildStandardRegionMap_9x9_cell_0_3_in_region_1', 0, () => {
      const map = buildStandardRegionMap(GRID_9x9)
      expect(map[3]).assertEqual(1) // (0,3) → box 1
    })

    it('buildStandardRegionMap_9x9_cell_3_0_in_region_3', 0, () => {
      const map = buildStandardRegionMap(GRID_9x9)
      expect(map[27]).assertEqual(3) // (3,0) → box 3
    })

    it('buildStandardRegionMap_9x9_cell_8_8_in_region_8', 0, () => {
      const map = buildStandardRegionMap(GRID_9x9)
      expect(map[80]).assertEqual(8) // (8,8) → box 8
    })

    it('buildStandardRegionMap_each_region_has_9_cells', 0, () => {
      const map = buildStandardRegionMap(GRID_9x9)
      const counts: number[] = new Array(9).fill(0)
      for (const regionId of map) {
        counts[regionId]++
      }
      for (const c of counts) {
        expect(c).assertEqual(9)
      }
    })

    it('buildStandardRegionMap_4x4', 0, () => {
      const map = buildStandardRegionMap(GRID_4x4)
      expect(map.length).assertEqual(16)
      // (0,0) → box 0, (0,2) → box 1, (2,0) → box 2, (2,2) → box 3
      expect(map[0]).assertEqual(0)
      expect(map[2]).assertEqual(1)
      expect(map[8]).assertEqual(2)   // (2,0) in 4×4: row=2, col=0
      expect(map[10]).assertEqual(3)  // (2,2) in 4×4: row=2, col=2
    })

    it('getRegionMap_standard_uses_box_calculation', 0, () => {
      const config = createStandardConfig()
      const map = getRegionMap(config)
      const expected = buildStandardRegionMap(GRID_9x9)
      expect(map.length).assertEqual(expected.length)
      for (let i = 0; i < map.length; i++) {
        expect(map[i]).assertEqual(expected[i])
      }
    })

    it('getRegionMap_jigsaw_uses_custom_map', 0, () => {
      const customMap: number[] = []
      for (let i = 0; i < 81; i++) {
        customMap.push(i % 9)
      }
      const config = createJigsawConfig(customMap)
      const map = getRegionMap(config)
      for (let i = 0; i < 81; i++) {
        expect(map[i]).assertEqual(i % 9)
      }
    })

    it('createDefaultJigsawRegionMap_has_9_regions_of_9_cells', 0, () => {
      const map = createDefaultJigsawRegionMap()
      const counts: number[] = new Array(9).fill(0)
      expect(map.length).assertEqual(81)
      for (const regionId of map) {
        counts[regionId]++
      }
      for (const count of counts) {
        expect(count).assertEqual(9)
      }
    })
  })

  describe('VariantConfig.KillerHelpers', () => {
    it('normalizeVariantType_supports_killer', 0, () => {
      expect(normalizeVariantType(VariantType.KILLER)).assertEqual(VariantType.KILLER)
      expect(normalizeVariantType(VariantType.JIGSAW)).assertEqual(VariantType.JIGSAW)
      expect(normalizeVariantType(VariantType.DIAGONAL)).assertEqual(VariantType.DIAGONAL)
      expect(normalizeVariantType(undefined)).assertEqual(VariantType.STANDARD)
      expect(normalizeVariantType('unknown')).assertEqual(VariantType.STANDARD)
    })

    it('generateRandomCageLayout_covers_all_81_cells', 0, () => {
      const cages = generateRandomCageLayout()
      const hitCount: number[] = new Array(81).fill(0)
      for (const cage of cages) {
        for (const cellIndex of cage.cells) {
          hitCount[cellIndex]++
        }
      }

      expect(cages.length > 0).assertTrue()
      for (const count of hitCount) {
        expect(count).assertEqual(1)
      }
    })

    it('generateRandomCageLayout_cages_are_connected', 0, () => {
      const cages = generateRandomCageLayout()
      for (const cage of cages) {
        // 每个笼子的格子应通过正交邻接连通
        if (cage.cells.length <= 1) continue
        const visited = new Set<number>()
        const queue: number[] = [cage.cells[0]]
        visited.add(cage.cells[0])
        const cellSet = new Set<number>(cage.cells)

        while (queue.length > 0) {
          const current = queue.pop()!
          const row = Math.floor(current / 9)
          const col = current % 9
          const neighbors = [
            row > 0 ? current - 9 : -1,
            row < 8 ? current + 9 : -1,
            col > 0 ? current - 1 : -1,
            col < 8 ? current + 1 : -1,
          ]
          for (const nb of neighbors) {
            if (nb >= 0 && cellSet.has(nb) && !visited.has(nb)) {
              visited.add(nb)
              queue.push(nb)
            }
          }
        }
        expect(visited.size).assertEqual(cage.cells.length)
      }
    })

    it('generateRandomCageLayout_cage_sizes_within_bounds', 0, () => {
      const cages = generateRandomCageLayout()
      for (const cage of cages) {
        expect(cage.cells.length >= 1).assertTrue()
        expect(cage.cells.length <= 5).assertTrue()
      }
    })

    it('buildKillerCagesFromSolution_uses_solution_sum', 0, () => {
      const solution: number[] = []
      for (let row = 0; row < 9; row++) {
        for (let col = 0; col < 9; col++) {
          solution.push(((row * 3 + Math.floor(row / 3) + col) % 9) + 1)
        }
      }

      const layout = generateRandomCageLayout()
      const cages = buildKillerCagesFromSolution(solution, layout)
      expect(cages.length).assertEqual(layout.length)
      // 验证第一个笼子的和
      let expectedSum = 0
      for (const idx of cages[0].cells) {
        expectedSum += solution[idx]
      }
      expect(cages[0].sum).assertEqual(expectedSum)
    })

    it('buildKillerBoardDecorations_uses_generic_decoration_model', 0, () => {
      const cage: KillerCage = { cells: [0, 1, 2], sum: 6 }
      const decorations = buildKillerBoardDecorations([cage])
      expect(decorations[0].topLeftLabel).assertEqual('6')
      expect(decorations[0].border.left > 0).assertTrue()
      expect(decorations[1].topLeftLabel).assertEqual('')
      expect(decorations[1].border.left).assertEqual(0)
      expect(decorations[1].border.top > 0).assertTrue()
    })

    it('buildKillerBoardDecorations_suppresses_grid_lines_for_cage_cells', 0, () => {
      // 笼子格：同笼相邻侧隐藏网格线，笼子边界侧也隐藏（装饰边框替代）
      // 但如果邻居是不同 cage 或不在 cage 中，保留灰色网格线
      const cage: KillerCage = { cells: [0, 1, 2], sum: 6 }
      const decorations = buildKillerBoardDecorations([cage])
      // cell 0 (row0,col0): left=border(边界), top=border(边界), right=同笼(cell1), bottom=border(cell9不在笼)
      // gridBorder: left=0(边框替代), top=0(边框替代), right=0(同笼), bottom=-1(邻居不在笼→保留灰线)
      expect(decorations[0].gridBorder.left).assertEqual(0)
      expect(decorations[0].gridBorder.top).assertEqual(0)
      expect(decorations[0].gridBorder.right).assertEqual(0)
      expect(decorations[0].gridBorder.bottom).assertEqual(-1)
      // cell 1 (row0,col1): left=同笼(cell0), right=同笼(cell2)
      expect(decorations[1].gridBorder.left).assertEqual(0)
      expect(decorations[1].gridBorder.right).assertEqual(0)
      // 不属于任何笼子的格子保持默认网格线
      expect(decorations[9].gridBorder.left).assertEqual(-1)
      expect(decorations[9].gridBorder.top).assertEqual(-1)
    })

    it('buildJigsawBoardDecorations_marks_region_edges', 0, () => {
      const decorations = buildJigsawBoardDecorations(createDefaultJigsawRegionMap())
      expect(decorations.length).assertEqual(81)
      expect(decorations[0].border.left > 0).assertTrue()
      expect(decorations[0].border.top > 0).assertTrue()
      expect(decorations[0].border.right).assertEqual(0)
      expect(decorations[2].border.right > 0).assertTrue()
      expect(decorations[20].border.bottom > 0).assertTrue()
    })

    it('buildJigsawBoardDecorations_suppresses_grid_lines_for_region_cells', 0, () => {
      const regionMap = createDefaultJigsawRegionMap()
      const decorations = buildJigsawBoardDecorations(regionMap)
      // 宫格内所有格子的所有边网格线都被隐藏（装饰边框替代）
      expect(decorations[0].gridBorder.left).assertEqual(0)
      expect(decorations[0].gridBorder.top).assertEqual(0)
      expect(decorations[0].gridBorder.right).assertEqual(0)
      expect(decorations[0].gridBorder.bottom).assertEqual(0)
    })

    it('buildKillerBoardDecorations_computes_corner_patches_for_L_shape', 0, () => {
      // L 形笼子：cells [0, 9, 18, 19]
      //   X .      row0: cell 0
      //   X .      row1: cell 9
      //   X X      row2: cell 18, 19
      const cage: KillerCage = { cells: [0, 9, 18, 19], sum: 20 }
      const decorations = buildKillerBoardDecorations([cage])

      // cell 9 (row1,col0): right=border, bottom=同cage → 右下对角 cell 10 不在 cage
      // hasRight=false, hasBottom=true, hasBottomRight=false
      // bottomRight 应该被标记为需要补丁（内凹角）
      // 但 cell 9 的 hasRight=false && hasBottom=true → !hasRight, 条件是 hasBottom && hasRight = false
      // 实际上 cell 9 的正交方向：hasTop=true(cell0同cage), hasBottom=true(cell18同cage), hasLeft=false(边界), hasRight=false(cell10不同cage)
      // topRight: !hasTopRight && hasTop && hasRight = X && true && false = false (正确，不需要)
      // bottomRight: !hasBottomRight && hasBottom && hasRight = true && true && false = false
      // 所以 cell 9 没有 corner patch - 正确！因为 cell 9 的右侧有 border(padding-right)
      // 其 padding-right 覆盖了整个右侧包括右下角
      expect(decorations[9].cornerPatches.bottomRight).assertFalse()

      // cell 18 (row2,col0): top=同cage(cell9), right=同cage(cell19)
      // 但右上对角 cell 10 不在 cage → 内凹角需要补丁
      // hasTop=true, hasRight=true, hasTopRight=false
      // topRight = !false && true && true = true ✓
      expect(decorations[18].cornerPatches.topRight).assertTrue()
      // 其他角不需要补丁
      expect(decorations[18].cornerPatches.topLeft).assertFalse()
      expect(decorations[18].cornerPatches.bottomLeft).assertFalse()
      expect(decorations[18].cornerPatches.bottomRight).assertFalse()
    })
  })
}
