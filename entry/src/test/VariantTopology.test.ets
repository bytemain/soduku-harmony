import { describe, it, expect } from '@ohos/hypium'
import {
  createStandardConfig, createDiagonalConfig, createJigsawConfig,
  createKillerConfig, createSizedConfig, GRID_9x9, GRID_4x4,
  KillerCage,
} from '../main/ets/models/VariantConfig'
import {
  buildVariantTopology, VariantTopology,
  rowOfVariant, colOfVariant, indexOfVariant,
  isOnMainDiagonal, isOnAntiDiagonal, isOnDiagonal,
  isDifferentRegion,
} from '../main/ets/utils/VariantTopology'

export default function variantTopologyTest() {
  // ============================================================
  // 标准 9×9 拓扑 — 验证与 Topology.ets 结果一致
  // ============================================================

  describe('VariantTopology.Standard9x9', () => {
    it('standard_has_27_units', 0, () => {
      const topo = buildVariantTopology(createStandardConfig())
      expect(topo.allUnits.length).assertEqual(27)
    })

    it('standard_each_unit_has_9_cells', 0, () => {
      const topo = buildVariantTopology(createStandardConfig())
      for (const unit of topo.allUnits) {
        expect(unit.length).assertEqual(9)
      }
    })

    it('standard_each_cell_in_3_units', 0, () => {
      const topo = buildVariantTopology(createStandardConfig())
      expect(topo.unitsOf.length).assertEqual(81)
      for (let i = 0; i < 81; i++) {
        expect(topo.unitsOf[i].length).assertEqual(3)
      }
    })

    it('standard_each_cell_has_20_peers', 0, () => {
      const topo = buildVariantTopology(createStandardConfig())
      expect(topo.peers.length).assertEqual(81)
      for (let i = 0; i < 81; i++) {
        expect(topo.peers[i].length).assertEqual(20)
      }
    })

    it('standard_peers_exclude_self', 0, () => {
      const topo = buildVariantTopology(createStandardConfig())
      for (let i = 0; i < 81; i++) {
        expect(topo.peers[i].indexOf(i)).assertEqual(-1)
      }
    })

    it('standard_peers_are_symmetric', 0, () => {
      const topo = buildVariantTopology(createStandardConfig())
      for (let i = 0; i < 81; i++) {
        for (const peer of topo.peers[i]) {
          expect(topo.peers[peer].indexOf(i) >= 0).assertTrue()
        }
      }
    })

    it('standard_first_9_units_are_rows', 0, () => {
      const topo = buildVariantTopology(createStandardConfig())
      for (let row = 0; row < 9; row++) {
        const unit = topo.allUnits[row]
        for (let col = 0; col < 9; col++) {
          expect(unit[col]).assertEqual(row * 9 + col)
        }
      }
    })

    it('standard_next_9_units_are_columns', 0, () => {
      const topo = buildVariantTopology(createStandardConfig())
      for (let col = 0; col < 9; col++) {
        const unit = topo.allUnits[9 + col]
        for (let row = 0; row < 9; row++) {
          expect(unit[row]).assertEqual(row * 9 + col)
        }
      }
    })
  })

  // ============================================================
  // Sudoku-X 对角线拓扑
  // ============================================================

  describe('VariantTopology.Diagonal', () => {
    it('diagonal_has_29_units', 0, () => {
      // 27 standard + 2 diagonals
      const topo = buildVariantTopology(createDiagonalConfig())
      expect(topo.allUnits.length).assertEqual(29)
    })

    it('diagonal_main_diag_unit_correct', 0, () => {
      const topo = buildVariantTopology(createDiagonalConfig())
      // 28th unit (index 27) = main diagonal
      const mainDiag = topo.allUnits[27]
      expect(mainDiag.length).assertEqual(9)
      for (let i = 0; i < 9; i++) {
        expect(mainDiag[i]).assertEqual(i * 9 + i) // (0,0),(1,1),...,(8,8)
      }
    })

    it('diagonal_anti_diag_unit_correct', 0, () => {
      const topo = buildVariantTopology(createDiagonalConfig())
      // 29th unit (index 28) = anti diagonal
      const antiDiag = topo.allUnits[28]
      expect(antiDiag.length).assertEqual(9)
      for (let i = 0; i < 9; i++) {
        expect(antiDiag[i]).assertEqual(i * 9 + (8 - i)) // (0,8),(1,7),...,(8,0)
      }
    })

    it('diagonal_corner_cell_has_more_peers', 0, () => {
      const stdTopo = buildVariantTopology(createStandardConfig())
      const diagTopo = buildVariantTopology(createDiagonalConfig())

      // Cell (0,0) is on main diagonal: should have more peers
      const stdPeers0 = stdTopo.peers[0].length  // 20
      const diagPeers0 = diagTopo.peers[0].length
      expect(diagPeers0 > stdPeers0).assertTrue()
    })

    it('diagonal_center_cell_in_5_units', 0, () => {
      const topo = buildVariantTopology(createDiagonalConfig())
      // Cell (4,4) = index 40: row + col + box + main diag + anti diag
      expect(topo.unitsOf[40].length).assertEqual(5)
    })

    it('diagonal_non_diag_cell_in_3_units', 0, () => {
      const topo = buildVariantTopology(createDiagonalConfig())
      // Cell (0,1) = index 1: not on any diagonal
      expect(topo.unitsOf[1].length).assertEqual(3)
    })

    it('diagonal_main_diag_cell_in_4_units', 0, () => {
      const topo = buildVariantTopology(createDiagonalConfig())
      // Cell (1,1) = index 10: on main diagonal only (not anti)
      expect(topo.unitsOf[10].length).assertEqual(4)
    })

    it('diagonal_anti_diag_cell_in_4_units', 0, () => {
      const topo = buildVariantTopology(createDiagonalConfig())
      // Cell (0,8) = index 8: on anti diagonal only (not main)
      expect(topo.unitsOf[8].length).assertEqual(4)
    })
  })

  // ============================================================
  // Killer 笼子拓扑
  // ============================================================

  describe('VariantTopology.Killer', () => {
    it('killer_cages_add_units', 0, () => {
      const cage1: KillerCage = { cells: [0, 1], sum: 10 }
      const cage2: KillerCage = { cells: [2, 3, 4], sum: 15 }
      const cages: KillerCage[] = [cage1, cage2]
      const topo = buildVariantTopology(createKillerConfig(cages))
      // 27 standard + 2 cage units
      expect(topo.allUnits.length).assertEqual(29)
    })

    it('killer_cage_members_are_peers', 0, () => {
      const cage1: KillerCage = { cells: [0, 9], sum: 10 } // (0,0) and (1,0)
      const cages: KillerCage[] = [cage1]
      const topo = buildVariantTopology(createKillerConfig(cages))

      // Cell 0 and 9 are already peers (same column), but cage reinforces it
      expect(topo.peers[0].indexOf(9) >= 0).assertTrue()
      expect(topo.peers[9].indexOf(0) >= 0).assertTrue()
    })

    it('killer_cage_creates_new_peer_relationship', 0, () => {
      // Cells 0 and 10 are peers (same box), but let's use non-peer cells
      // Cell (0,0)=0 and Cell (3,3)=30: not in same row/col/box
      const cage1: KillerCage = { cells: [0, 30], sum: 10 }
      const cages: KillerCage[] = [cage1]
      const topo = buildVariantTopology(createKillerConfig(cages))

      // In standard topology, 0 and 30 are NOT peers
      const stdTopo = buildVariantTopology(createStandardConfig())
      expect(stdTopo.peers[0].indexOf(30)).assertEqual(-1)

      // With killer cage, they become peers
      expect(topo.peers[0].indexOf(30) >= 0).assertTrue()
      expect(topo.peers[30].indexOf(0) >= 0).assertTrue()
    })
  })

  // ============================================================
  // Jigsaw 自定义区域拓扑
  // ============================================================

  describe('VariantTopology.Jigsaw', () => {
    it('jigsaw_still_has_27_units', 0, () => {
      // 9 rows + 9 cols + 9 regions = 27 (same count, different region shapes)
      const regionMap: number[] = []
      for (let i = 0; i < 81; i++) {
        regionMap.push(Math.floor(i / 9)) // row-based regions
      }
      const topo = buildVariantTopology(createJigsawConfig(regionMap))
      expect(topo.allUnits.length).assertEqual(27)
    })

    it('jigsaw_row_based_regions_give_correct_peers', 0, () => {
      // If regions = rows, each cell has peers: same row (region=row) + same col
      // This means row peers overlap with region peers
      const regionMap: number[] = []
      for (let i = 0; i < 81; i++) {
        regionMap.push(Math.floor(i / 9))
      }
      const topo = buildVariantTopology(createJigsawConfig(regionMap))

      // Cell (0,0) peers: same row (0..8) + same col (0,9,18,...,72) + same region(=row, already counted)
      // = 8 (row) + 8 (col) = 16 unique peers (no box overlap since regions=rows)
      expect(topo.peers[0].length).assertEqual(16)
    })
  })

  // ============================================================
  // 4×4 棋盘拓扑
  // ============================================================

  describe('VariantTopology.4x4', () => {
    it('4x4_has_12_units', 0, () => {
      // 4 rows + 4 cols + 4 boxes = 12
      const topo = buildVariantTopology(createSizedConfig(4, 2, 2))
      expect(topo.allUnits.length).assertEqual(12)
    })

    it('4x4_total_cells_16', 0, () => {
      const topo = buildVariantTopology(createSizedConfig(4, 2, 2))
      expect(topo.totalCells).assertEqual(16)
      expect(topo.peers.length).assertEqual(16)
    })

    it('4x4_each_unit_has_4_cells', 0, () => {
      const topo = buildVariantTopology(createSizedConfig(4, 2, 2))
      for (const unit of topo.allUnits) {
        expect(unit.length).assertEqual(4)
      }
    })

    it('4x4_each_cell_in_3_units', 0, () => {
      const topo = buildVariantTopology(createSizedConfig(4, 2, 2))
      for (let i = 0; i < 16; i++) {
        expect(topo.unitsOf[i].length).assertEqual(3)
      }
    })

    it('4x4_cell_has_7_peers', 0, () => {
      // In a 4×4 with 2×2 boxes:
      // row peers: 3, col peers: 3, box peers: 3
      // overlap: box shares 1 with row, 1 with col → 3+3+3-1-1 = 7
      const topo = buildVariantTopology(createSizedConfig(4, 2, 2))
      for (let i = 0; i < 16; i++) {
        expect(topo.peers[i].length).assertEqual(7)
      }
    })
  })

  // ============================================================
  // 辅助函数
  // ============================================================

  describe('VariantTopology.Helpers', () => {
    it('rowOfVariant_correct', 0, () => {
      expect(rowOfVariant(0, 9)).assertEqual(0)
      expect(rowOfVariant(8, 9)).assertEqual(0)
      expect(rowOfVariant(9, 9)).assertEqual(1)
      expect(rowOfVariant(80, 9)).assertEqual(8)
      expect(rowOfVariant(0, 4)).assertEqual(0)
      expect(rowOfVariant(5, 4)).assertEqual(1)
    })

    it('colOfVariant_correct', 0, () => {
      expect(colOfVariant(0, 9)).assertEqual(0)
      expect(colOfVariant(8, 9)).assertEqual(8)
      expect(colOfVariant(9, 9)).assertEqual(0)
      expect(colOfVariant(0, 4)).assertEqual(0)
      expect(colOfVariant(5, 4)).assertEqual(1)
    })

    it('indexOfVariant_correct', 0, () => {
      expect(indexOfVariant(0, 0, 9)).assertEqual(0)
      expect(indexOfVariant(1, 0, 9)).assertEqual(9)
      expect(indexOfVariant(8, 8, 9)).assertEqual(80)
      expect(indexOfVariant(1, 1, 4)).assertEqual(5)
    })

    it('indexOfVariant_roundtrip', 0, () => {
      for (let i = 0; i < 81; i++) {
        const r = rowOfVariant(i, 9)
        const c = colOfVariant(i, 9)
        expect(indexOfVariant(r, c, 9)).assertEqual(i)
      }
    })

    it('isOnMainDiagonal_correct', 0, () => {
      expect(isOnMainDiagonal(0, 9)).assertTrue()   // (0,0)
      expect(isOnMainDiagonal(10, 9)).assertTrue()  // (1,1)
      expect(isOnMainDiagonal(40, 9)).assertTrue()  // (4,4)
      expect(isOnMainDiagonal(80, 9)).assertTrue()  // (8,8)
      expect(isOnMainDiagonal(1, 9)).assertFalse()  // (0,1)
      expect(isOnMainDiagonal(9, 9)).assertFalse()  // (1,0)
    })

    it('isOnAntiDiagonal_correct', 0, () => {
      expect(isOnAntiDiagonal(8, 9)).assertTrue()   // (0,8)
      expect(isOnAntiDiagonal(16, 9)).assertTrue()  // (1,7)
      expect(isOnAntiDiagonal(40, 9)).assertTrue()  // (4,4)
      expect(isOnAntiDiagonal(72, 9)).assertTrue()  // (8,0)
      expect(isOnAntiDiagonal(0, 9)).assertFalse()  // (0,0) only on main
      expect(isOnAntiDiagonal(80, 9)).assertFalse() // (8,8) only on main
    })

    it('isOnDiagonal_correct', 0, () => {
      expect(isOnDiagonal(0, 9)).assertTrue()   // main diag
      expect(isOnDiagonal(8, 9)).assertTrue()   // anti diag
      expect(isOnDiagonal(40, 9)).assertTrue()  // both diags (center)
      expect(isOnDiagonal(1, 9)).assertFalse()  // neither
    })

    it('isDifferentRegion_correct', 0, () => {
      const regionMap = [0, 0, 0, 1, 1, 1, 2, 2, 2]
      expect(isDifferentRegion(0, 1, regionMap)).assertFalse() // same region
      expect(isDifferentRegion(2, 3, regionMap)).assertTrue()  // different region
    })
  })
}
