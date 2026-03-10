import { describe, it, expect } from '@ohos/hypium'
import {
  VariantType,
  GRID_4x4, GRID_6x6, GRID_9x9, GRID_12x12, GRID_16x16,
  createStandardConfig, createDiagonalConfig, createJigsawConfig,
  createKillerConfig, createSizedConfig,
  STANDARD_CONFIG, buildStandardRegionMap, getRegionMap, isStandard9x9,
} from '../main/ets/models/VariantConfig'

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

    it('createKillerConfig_has_cages', 0, () => {
      const cages = [
        { cells: [0, 1], sum: 10 },
        { cells: [2, 3, 4], sum: 15 },
      ]
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
  })

  describe('VariantConfig.IsStandard', () => {
    it('STANDARD_CONFIG_is_standard', 0, () => {
      expect(isStandard9x9(STANDARD_CONFIG)).assertTrue()
    })

    it('diagonal_is_not_standard', 0, () => {
      expect(isStandard9x9(createDiagonalConfig())).assertFalse()
    })

    it('jigsaw_is_not_standard', 0, () => {
      const map: number[] = new Array(81).fill(0)
      expect(isStandard9x9(createJigsawConfig(map))).assertFalse()
    })

    it('killer_is_not_standard', 0, () => {
      expect(isStandard9x9(createKillerConfig([]))).assertFalse()
    })

    it('sized_4x4_is_not_standard_9x9', 0, () => {
      expect(isStandard9x9(createSizedConfig(4, 2, 2))).assertFalse()
    })
  })
}
