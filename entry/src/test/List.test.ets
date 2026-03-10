import localUnitTest from './LocalUnit.test'
import cellDataTest from './CellData.test'
import topologyTest from './Topology.test'
import commonTest from './Common.test'
import solverTest from './SudokuSolver.test'
import validatorTest from './SudokuValidator.test'
import generatorTest from './SudokuGenerator.test'
import gameStateTest from './GameState.test'
import logicSolverTest from './LogicSolver.test'
import sudokuFormatTest from './SudokuFormat.test'
import variantConfigTest from './VariantConfig.test'
import variantTopologyTest from './VariantTopology.test'

export default function testsuite() {
  localUnitTest()
  cellDataTest()
  topologyTest()
  commonTest()
  solverTest()
  validatorTest()
  generatorTest()
  gameStateTest()
  logicSolverTest()
  sudokuFormatTest()
  variantConfigTest()
  variantTopologyTest()
}
