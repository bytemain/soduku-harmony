export interface GameHistorySyncState {
  canUndo: boolean
  canRedo: boolean
  remainingCounts: number[]
}

@ObservedV2
export class GameHistoryDomainV2 {
  @Trace canUndo: boolean = false
  @Trace canRedo: boolean = false
  @Trace remainingCounts: number[] = [0, 9, 9, 9, 9, 9, 9, 9, 9, 9]

  sync(options: GameHistorySyncState): void {
    this.canUndo = options.canUndo
    this.canRedo = options.canRedo
    this.remainingCounts = options.remainingCounts
  }

  reset(): void {
    this.canUndo = false
    this.canRedo = false
    this.remainingCounts = [0, 9, 9, 9, 9, 9, 9, 9, 9, 9]
  }
}
