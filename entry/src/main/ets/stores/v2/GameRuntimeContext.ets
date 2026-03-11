import { GameHistory } from '../../models/GameHistory'

export class GameRuntimeContext {
  timerId: number = -1
  history: GameHistory = new GameHistory()
  isMouseDragging: boolean = false
  mouseDragStartIndex: number = -1

  reset(): void {
    this.timerId = -1
    this.history.clear()
    this.isMouseDragging = false
    this.mouseDragStartIndex = -1
  }
}
