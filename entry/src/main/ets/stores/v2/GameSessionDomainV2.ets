import { Difficulty } from '../../constants/GameConstants'
import { Symmetry } from '../../utils/SudokuGenerator'

export interface GameSessionStartOptions {
  difficulty?: Difficulty
  symmetry?: Symmetry | null
  seedId?: string
  importedPuzzle?: string
}

@ObservedV2
export class GameSessionDomainV2 {
  @Trace difficulty: Difficulty = Difficulty.EASY
  @Trace symmetry: Symmetry | null = null
  @Trace seedId: string = ''
  @Trace importedPuzzle: string = ''
  @Trace elapsedSeconds: number = 0
  @Trace errorCount: number = 0
  @Trace isCompleted: boolean = false
  @Trace isPaused: boolean = false

  start(options?: GameSessionStartOptions): void {
    this.difficulty = options?.difficulty ?? Difficulty.EASY
    this.symmetry = options?.symmetry ?? null
    this.seedId = options?.seedId ?? ''
    this.importedPuzzle = options?.importedPuzzle ?? ''
    this.elapsedSeconds = 0
    this.errorCount = 0
    this.isCompleted = false
    this.isPaused = false
  }

  tick(): void {
    if (!this.isPaused && !this.isCompleted) {
      this.elapsedSeconds += 1
    }
  }

  complete(): void {
    this.isCompleted = true
    this.isPaused = false
  }
}
