/**
 * GameHistory.ets — 撤销/前进操作栈
 *
 * 记录每次玩家操作前的快照（index, oldValue, newValue, oldNotes, newNotes），
 * 支持 undo / redo。
 *
 * 参考：Doc 03 任务 2.1
 */

export interface CellSnapshot {
  index: number
  oldValue: number
  newValue: number
  oldNotes: number
  newNotes: number
  oldFlags: number
  newFlags: number
}

@Observed
export class GameHistory {
  /** 撤销栈 */
  undoStack: CellSnapshot[] = []
  /** 重做栈 */
  redoStack: CellSnapshot[] = []

  /** 记录一步操作 */
  push(snapshot: CellSnapshot): void {
    this.undoStack.push(snapshot)
    // 有新操作时清空 redo 栈
    this.redoStack = []
  }

  /** 能否撤销 */
  get canUndo(): boolean {
    return this.undoStack.length > 0
  }

  /** 能否前进 */
  get canRedo(): boolean {
    return this.redoStack.length > 0
  }

  /** 弹出最近一步（用于 undo） */
  popUndo(): CellSnapshot | null {
    if (this.undoStack.length === 0) return null
    const snap = this.undoStack.pop()!
    this.redoStack.push(snap)
    return snap
  }

  /** 弹出一步 redo */
  popRedo(): CellSnapshot | null {
    if (this.redoStack.length === 0) return null
    const snap = this.redoStack.pop()!
    this.undoStack.push(snap)
    return snap
  }

  /** 清空历史 */
  clear(): void {
    this.undoStack = []
    this.redoStack = []
  }
}
