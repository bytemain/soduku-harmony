import { GestureDirection } from '../../constants/GameConstants'

@ObservedV2
export class GameInteractionDomainV2 {
  @Trace selectedIndex: number = -1
  @Trace gestureDirection: GestureDirection | null = null
  @Trace hintFocusIndex: number = -1
  @Trace isHintLoading: boolean = false
  @Trace isMultiSelectMode: boolean = false
  @Trace multiSelectIndices: number[] = []

  setSelectedIndex(index: number): void {
    this.selectedIndex = index
  }

  setMultiSelection(indices: number[]): void {
    this.multiSelectIndices = indices
    this.isMultiSelectMode = indices.length > 1
  }

  clearInteraction(): void {
    this.gestureDirection = null
    this.hintFocusIndex = -1
    this.isHintLoading = false
    this.isMultiSelectMode = false
    this.multiSelectIndices = []
  }
}
