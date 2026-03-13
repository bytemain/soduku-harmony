/**
 * GameHistory.ets — 撤销/前进操作栈
 *
 * 记录每次玩家操作前的快照（index, oldValue, newValue, oldNotes, newNotes），
 * 支持 undo / redo。
 *
 * 每个栈条目是一个 CellSnapshot[]，表示一次"用户操作"可能涉及的多个格子变更。
 * 单格操作 push 一个长度为 1 的数组；批量操作（如一键填候选）push 一个包含多个快照的数组。
 * 撤销/重做时整组一起回退或重放。
 *
 * 参考：Doc 03 任务 2.1
 */

export class CellSnapshot {
  index: number
  oldValue: number
  newValue: number
  oldNotes: number
  newNotes: number
  oldFlags: number
  newFlags: number

  constructor(
    index: number = 0,
    oldValue: number = 0,
    newValue: number = 0,
    oldNotes: number = 0,
    newNotes: number = 0,
    oldFlags: number = 0,
    newFlags: number = 0,
  ) {
    this.index = index
    this.oldValue = oldValue
    this.newValue = newValue
    this.oldNotes = oldNotes
    this.newNotes = newNotes
    this.oldFlags = oldFlags
    this.newFlags = newFlags
  }
}

@Observed
export class GameHistory {
  /** 撤销栈 — 每个条目是一组快照，代表一次用户操作 */
  undoStack: CellSnapshot[][] = []
  /** 重做栈 — 每个条目是一组快照，代表一次用户操作 */
  redoStack: CellSnapshot[][] = []

  /** 记录单步操作（包装为长度 1 的组） */
  push(snapshot: CellSnapshot): void {
    this.undoStack.push([snapshot])
    // 有新操作时清空 redo 栈
    this.redoStack = []
  }

  /** 记录批量操作（多个快照作为一组，撤销/重做时整组处理） */
  pushBatch(snapshots: CellSnapshot[]): void {
    if (snapshots.length === 0) return
    this.undoStack.push(snapshots)
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

  /** 弹出最近一组（用于 undo），返回整组快照 */
  popUndo(): CellSnapshot[] | null {
    if (this.undoStack.length === 0) return null
    const group = this.undoStack.pop()!
    this.redoStack.push(group)
    return group
  }

  /** 弹出一组 redo，返回整组快照 */
  popRedo(): CellSnapshot[] | null {
    if (this.redoStack.length === 0) return null
    const group = this.redoStack.pop()!
    this.undoStack.push(group)
    return group
  }

  /** 清空历史 */
  clear(): void {
    this.undoStack = []
    this.redoStack = []
  }
}
