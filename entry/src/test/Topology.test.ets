import { describe, it, expect } from '@ohos/hypium'
import { ALL_UNITS, UNITS_OF, PEERS, rowOf, colOf, boxOf, indexOf } from '../main/ets/utils/Topology'

export default function topologyTest() {
  describe('Topology.Precomputed', () => {
    it('total_27_units', 0, () => {
      expect(ALL_UNITS.length).assertEqual(27)
    })

    it('each_unit_has_9_cells', 0, () => {
      for (const unit of ALL_UNITS) {
        expect(unit.length).assertEqual(9)
      }
    })

    it('no_duplicate_indices_in_unit', 0, () => {
      for (const unit of ALL_UNITS) {
        const set = new Set<number>()
        for (const idx of unit) {
          set.add(idx)
        }
        expect(set.size).assertEqual(9)
      }
    })

    it('all_indices_in_0_to_80_range', 0, () => {
      for (const unit of ALL_UNITS) {
        for (const idx of unit) {
          expect(idx >= 0).assertTrue()
          expect(idx <= 80).assertTrue()
        }
      }
    })

    it('first_9_units_are_rows', 0, () => {
      for (let row = 0; row < 9; row++) {
        const unit = ALL_UNITS[row]
        for (let col = 0; col < 9; col++) {
          expect(unit[col]).assertEqual(row * 9 + col)
        }
      }
    })

    it('next_9_units_are_columns', 0, () => {
      for (let col = 0; col < 9; col++) {
        const unit = ALL_UNITS[9 + col]
        for (let row = 0; row < 9; row++) {
          expect(unit[row]).assertEqual(row * 9 + col)
        }
      }
    })

    it('last_9_units_are_boxes', 0, () => {
      // 宫 0: (0,0)~(2,2)
      const box0 = ALL_UNITS[18]
      expect(box0.indexOf(0)).assertLargerOrEqual(0)   // (0,0) = index 0
      expect(box0.indexOf(1)).assertLargerOrEqual(0)   // (0,1) = index 1
      expect(box0.indexOf(2)).assertLargerOrEqual(0)   // (0,2) = index 2
      expect(box0.indexOf(9)).assertLargerOrEqual(0)   // (1,0) = index 9
      expect(box0.indexOf(20)).assertLargerOrEqual(0)  // (2,2) = index 20
    })
  })

  describe('UNITS_OF.each_cell_belongs_to_3_units', () => {
    it('each_cell_in_exactly_3_units', 0, () => {
      expect(UNITS_OF.length).assertEqual(81)
      for (let i = 0; i < 81; i++) {
        expect(UNITS_OF[i].length).assertEqual(3)
      }
    })

    it('cell_is_in_its_units', 0, () => {
      for (let i = 0; i < 81; i++) {
        for (const unit of UNITS_OF[i]) {
          expect(unit.indexOf(i) >= 0).assertTrue()
        }
      }
    })
  })

  describe('PEERS.Buddies', () => {
    it('all_81_cells_have_peers', 0, () => {
      expect(PEERS.length).assertEqual(81)
    })

    it('each_cell_has_20_peers', 0, () => {
      for (let i = 0; i < 81; i++) {
        expect(PEERS[i].length).assertEqual(20)
      }
    })

    it('peers_exclude_self', 0, () => {
      for (let i = 0; i < 81; i++) {
        expect(PEERS[i].indexOf(i)).assertEqual(-1)
      }
    })

    it('peers_are_symmetric', 0, () => {
      for (let i = 0; i < 81; i++) {
        for (const peer of PEERS[i]) {
          expect(PEERS[peer].indexOf(i) >= 0).assertTrue()
        }
      }
    })

    it('verify_peers_of_cell_0_0', 0, () => {
      // index 0 = (0,0)
      const peers0 = PEERS[0]
      // 同行: 1,2,3,4,5,6,7,8
      for (let c = 1; c <= 8; c++) {
        expect(peers0.indexOf(c) >= 0).assertTrue()
      }
      // 同列: 9,18,27,36,45,54,63,72
      for (let r = 1; r <= 8; r++) {
        expect(peers0.indexOf(r * 9) >= 0).assertTrue()
      }
      // 同宫: (1,1)=10, (1,2)=11, (2,1)=19, (2,2)=20
      expect(peers0.indexOf(10) >= 0).assertTrue()
      expect(peers0.indexOf(11) >= 0).assertTrue()
      expect(peers0.indexOf(19) >= 0).assertTrue()
      expect(peers0.indexOf(20) >= 0).assertTrue()
    })
  })

  describe('IndexConversion', () => {
    it('rowOf_correct', 0, () => {
      expect(rowOf(0)).assertEqual(0)
      expect(rowOf(8)).assertEqual(0)
      expect(rowOf(9)).assertEqual(1)
      expect(rowOf(80)).assertEqual(8)
      expect(rowOf(40)).assertEqual(4) // 40/9=4.44 → 4
    })

    it('colOf_correct', 0, () => {
      expect(colOf(0)).assertEqual(0)
      expect(colOf(8)).assertEqual(8)
      expect(colOf(9)).assertEqual(0)
      expect(colOf(80)).assertEqual(8)
      expect(colOf(40)).assertEqual(4) // 40%9=4
    })

    it('boxOf_correct', 0, () => {
      expect(boxOf(0)).assertEqual(0)    // (0,0) → 宫0
      expect(boxOf(3)).assertEqual(1)    // (0,3) → 宫1
      expect(boxOf(6)).assertEqual(2)    // (0,6) → 宫2
      expect(boxOf(27)).assertEqual(3)   // (3,0) → 宫3
      expect(boxOf(40)).assertEqual(4)   // (4,4) → 宫4
      expect(boxOf(80)).assertEqual(8)   // (8,8) → 宫8
    })

    it('indexOf_row_col_to_1D', 0, () => {
      expect(indexOf(0, 0)).assertEqual(0)
      expect(indexOf(0, 8)).assertEqual(8)
      expect(indexOf(1, 0)).assertEqual(9)
      expect(indexOf(8, 8)).assertEqual(80)
    })

    it('rowOf_colOf_indexOf_roundtrip', 0, () => {
      for (let i = 0; i < 81; i++) {
        expect(indexOf(rowOf(i), colOf(i))).assertEqual(i)
      }
    })
  })
}
