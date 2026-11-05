import { GameSaveData, CellSerialized, isValidGameSave } from './GameSaveData'
import { CellSnapshot } from './GameHistory'

export type JournalMode = 'auto' | 'manual'
export type JournalOutcome = 'active' | 'won' | 'completed_failed'
export type JournalBranchMode = 'challenge' | 'practice'

export class JournalStartOptions {
  sessionId?: string
  mode?: JournalMode = 'auto'
  previousSessionId?: string = ''
  startedInLegacyStats?: boolean = false
}

/** 原题只存在 session 中。节点不复制答案、变种拓扑或撤销栈。 */
export class JournalSession {
  id: string = ''
  kind: 'journal' | 'legacy' = 'journal'
  legacyOnly: boolean = false
  createdAt: number = 0
  updatedAt: number = 0
  puzzle: GameSaveData = new GameSaveData()
  headNodeId: string = ''
  activeBranchId: string = ''
  nodeCount: number = 0
  mode: JournalMode = 'auto'
  outcome: JournalOutcome = 'active'
  previousSessionId: string = ''
  scoreElapsedSeconds: number = 0
  scoreErrorCount: number = 0
  scoreChallengeFailed: boolean = false
  settled: boolean = false
  settledAt: number = 0
  legacyReplaySave?: GameSaveData
  legacyStepCount: number = 0
  historyImportTruncated: boolean = false
  startedInLegacyStats: boolean = false
  challengeFailedAt: number = 0
  completionNodeId: string = ''
  /** 0 为自由练习，不因累计错误判失败；仅旧完成记录可保留旧上限。 */
  errorLimit: number = 0
}

export class JournalNode {
  id: string = ''
  sessionId: string = ''
  parentId: string = ''
  branchId: string = ''
  sequence: number = 0
  createdAt: number = 0
  action: string = ''
  values: number[] = []
  notes: number[] = []
  elapsedSeconds: number = 0
  errorCount: number = 0
  isChallengeFailed: boolean = false
  outcome: JournalOutcome = 'active'
  /** 读取时合并 bookmark 元数据，不改不可变节点行。 */
  label: string = ''
  manual: boolean = false
  /** 导入旧撤销栈的过往节点没有真实时间信息。 */
  timingKnown: boolean = true
}

export class JournalBranch {
  id: string = ''
  sessionId: string = ''
  forkNodeId: string = ''
  tipNodeId: string = ''
  name: string = ''
  mode: JournalBranchMode = 'challenge'
  createdAt: number = 0
  elapsedSeconds: number = 0
  errorCount: number = 0
  isChallengeFailed: boolean = false
}

export class JournalGraph {
  session: JournalSession = new JournalSession()
  nodes: JournalNode[] = []
  branches: JournalBranch[] = []
}

export class JournalState {
  session: JournalSession
  node: JournalNode
  branch: JournalBranch

  constructor(session: JournalSession, node: JournalNode, branch: JournalBranch) {
    this.session = session
    this.node = node
    this.branch = branch
  }
}

export class JournalStatsFact {
  id: string = ''
  difficulty: number = 0
  createdAt: number = 0
  startedInLegacyStats: boolean = false
  challengeFailedAt: number = 0
  settled: boolean = false
  settledAt: number = 0
  outcome: JournalOutcome = 'active'
  elapsedSeconds: number = 0
  errorCount: number = 0
  errorLimit: number = 0
}

export class JournalStatsSnapshot {
  legacyJson: string = ''
  facts: JournalStatsFact[] = []
}

export function cloneJournalSave(save: GameSaveData): GameSaveData {
  return JSON.parse(JSON.stringify(save)) as GameSaveData
}

/** 从合法当前局提取不可变原题，避免以后靠 seed 或生成器版本重建。 */
export function journalPuzzleFromSave(save: GameSaveData): GameSaveData {
  if (!isValidGameSave(save)) throw new Error('Invalid journal source save')
  const puzzle = cloneJournalSave(save)
  puzzle.gridSize = save.gridSize ?? 9
  puzzle.variantType = save.variantType ?? 'standard'
  puzzle.cells = save.cells.map((cell: CellSerialized): CellSerialized => {
    const given = (cell.flags & 1) !== 0
    return new CellSerialized(cell.row, cell.col, given ? cell.value : 0, given ? 1 : 0, 0)
  })
  puzzle.undoStack = []
  puzzle.redoStack = []
  puzzle.elapsedSeconds = 0
  puzzle.errorCount = 0
  puzzle.isChallengeFailed = false
  puzzle.selectedIndex = -1
  puzzle.journalSessionId = ''
  puzzle.journalNodeId = ''
  puzzle.journalBranchId = ''
  return puzzle
}

export function assertJournalSaveMatches(session: JournalSession, save: GameSaveData): void {
  if (!isValidGameSave(save)) throw new Error('Invalid journal save')
  const puzzle = session.puzzle
  if ((save.gridSize ?? 9) !== puzzle.gridSize || (save.variantType ?? 'standard') !== puzzle.variantType ||
    JSON.stringify(save.solution) !== JSON.stringify(puzzle.solution) ||
    JSON.stringify(save.killerCages ?? []) !== JSON.stringify(puzzle.killerCages ?? []) ||
    JSON.stringify(save.jigsawRegionMap ?? []) !== JSON.stringify(puzzle.jigsawRegionMap ?? [])) {
    throw new Error('Journal puzzle does not match session')
  }
  for (let index = 0; index < puzzle.cells.length; index++) {
    const original = puzzle.cells[index]
    const current = save.cells[index]
    if ((original.flags & 1) !== (current.flags & 1) ||
      ((original.flags & 1) !== 0 && original.value !== current.value)) {
      throw new Error('Journal givens cannot change')
    }
  }
}

/** 可变挑战账本独立于节点，撤销不能回退计时、错误数或失败事实。 */
export function updateJournalMetrics(session: JournalSession, branch: JournalBranch,
  elapsedSeconds: number, errorCount: number, challengeFailed: boolean): void {
  if (!Number.isFinite(elapsedSeconds) || elapsedSeconds < 0 ||
    !Number.isInteger(errorCount) || errorCount < 0) throw new Error('Invalid journal metrics')
  branch.elapsedSeconds = Math.max(branch.elapsedSeconds, elapsedSeconds)
  branch.errorCount = Math.max(branch.errorCount, errorCount)
  branch.isChallengeFailed = branch.mode === 'challenge' && session.errorLimit > 0 &&
    (branch.isChallengeFailed || challengeFailed || errorCount >= session.errorLimit)
  if (branch.mode === 'challenge') {
    const wasFailed = session.scoreChallengeFailed
    session.scoreElapsedSeconds = Math.max(session.scoreElapsedSeconds, branch.elapsedSeconds)
    session.scoreErrorCount = Math.max(session.scoreErrorCount, branch.errorCount)
    session.scoreChallengeFailed = session.errorLimit > 0 && (session.scoreChallengeFailed || branch.isChallengeFailed)
    if (!wasFailed && session.scoreChallengeFailed) session.challengeFailedAt = Date.now()
    branch.elapsedSeconds = session.scoreElapsedSeconds
    branch.errorCount = session.scoreErrorCount
    branch.isChallengeFailed = session.scoreChallengeFailed
  }
}

/**
 * 按题面约束判通关，而不是与参考答案逐格比较；导入题可能有多个合法解。
 * 临时副本的 solution 用来复用尺寸、行列宫、对角线、区域和笼约束校验，
 * 不修改 session 中不可变的原题与参考答案。
 */
export function isJournalBoardComplete(puzzle: GameSaveData, values: number[]): boolean {
  const size = puzzle.gridSize ?? 9
  if (!Array.isArray(values) || values.length !== size * size ||
    values.some((value: number): boolean => !Number.isInteger(value) || value < 1 || value > size)) return false
  const candidate = cloneJournalSave(puzzle)
  candidate.solution = values.slice()
  return isValidGameSave(candidate)
}

export function makeJournalNode(session: JournalSession, branch: JournalBranch,
  save: GameSaveData, id: string, action: string, now: number): JournalNode {
  assertJournalSaveMatches(session, save)
  const node = new JournalNode()
  node.id = id
  node.sessionId = session.id
  node.parentId = session.headNodeId
  node.branchId = branch.id
  node.sequence = session.nodeCount + 1
  node.createdAt = now
  node.action = action
  node.values = save.cells.map((cell: CellSerialized): number => cell.value)
  node.notes = save.cells.map((cell: CellSerialized): number => cell.notes)
  node.elapsedSeconds = branch.elapsedSeconds
  node.errorCount = branch.errorCount
  node.isChallengeFailed = branch.isChallengeFailed
  const complete = isJournalBoardComplete(session.puzzle, node.values)
  node.outcome = complete ? (node.isChallengeFailed ? 'completed_failed' : 'won') : 'active'
  node.manual = action === 'checkpoint'
  return node
}

export function journalNodeById(graph: JournalGraph, id: string): JournalNode {
  const node = graph.nodes.find((item: JournalNode): boolean => item.id === id)
  if (!node) throw new Error('Journal node not found')
  return node
}

export function journalActiveBranch(graph: JournalGraph): JournalBranch {
  const branch = graph.branches.find((item: JournalBranch): boolean => item.id === graph.session.activeBranchId)
  if (!branch) throw new Error('Journal branch not found')
  return branch
}

/** 根至目标的祖先链；同时拒绝环、断链和跨 session 引用。 */
export function journalPath(graph: JournalGraph, nodeId: string): JournalNode[] {
  const path: JournalNode[] = []
  const visited = new Set<string>()
  const byId = new Map<string, JournalNode>()
  for (const node of graph.nodes) byId.set(node.id, node)
  let id = nodeId
  while (id !== '') {
    if (visited.has(id)) throw new Error('Cycle in journal')
    visited.add(id)
    const node = byId.get(id)
    if (!node) throw new Error('Journal node not found')
    if (node.sessionId !== graph.session.id) throw new Error('Cross-session journal node')
    path.push(node)
    id = node.parentId
  }
  return path.reverse()
}

export function journalDelta(before: JournalNode, after: JournalNode): CellSnapshot[] {
  const delta: CellSnapshot[] = []
  for (let index = 0; index < before.values.length; index++) {
    if (before.values[index] !== after.values[index] || before.notes[index] !== after.notes[index]) {
      delta.push(new CellSnapshot(index, before.values[index], after.values[index],
        before.notes[index], after.notes[index]))
    }
  }
  return delta
}

export class JournalImportedLineage {
  saves: GameSaveData[] = []
  headIndex: number = 0
  truncated: boolean = false
}

function legacyGroups(raw: CellSnapshot[][] | CellSnapshot[]): CellSnapshot[][] {
  if (!Array.isArray(raw) || raw.length === 0) return []
  if (Array.isArray(raw[0])) return raw as CellSnapshot[][]
  return (raw as CellSnapshot[]).map((snapshot: CellSnapshot): CellSnapshot[] => [snapshot])
}

function applyLegacyBatch(current: GameSaveData, group: CellSnapshot[], forward: boolean): GameSaveData | null {
  if (!Array.isArray(group) || group.length === 0) return null
  const next = cloneJournalSave(current)
  const size = current.gridSize
  const ordered = forward ? group : group.slice().reverse()
  for (const snapshot of ordered) {
    if (!snapshot || !Number.isInteger(snapshot.index) || snapshot.index < 0 || snapshot.index >= next.cells.length ||
      !Number.isInteger(snapshot.oldValue) || snapshot.oldValue < 0 || snapshot.oldValue > size ||
      !Number.isInteger(snapshot.newValue) || snapshot.newValue < 0 || snapshot.newValue > size ||
      !Number.isInteger(snapshot.oldNotes) || snapshot.oldNotes < 0 || snapshot.oldNotes >= Math.pow(2, size * 2) ||
      !Number.isInteger(snapshot.newNotes) || snapshot.newNotes < 0 || snapshot.newNotes >= Math.pow(2, size * 2)) return null
    const cell = next.cells[snapshot.index]
    const expectedValue = forward ? snapshot.oldValue : snapshot.newValue
    const expectedNotes = forward ? snapshot.oldNotes : snapshot.newNotes
    const value = forward ? snapshot.newValue : snapshot.oldValue
    const notes = forward ? snapshot.newNotes : snapshot.oldNotes
    if (cell.value !== expectedValue || cell.notes !== expectedNotes ||
      ((cell.flags & 1) !== 0 && (value !== cell.value || notes !== cell.notes))) return null
    cell.value = value
    cell.notes = notes
  }
  return isValidGameSave(next) ? next : null
}

/** 只导入旧档实际保存且可验证的原子批次，不推测被丢弃的路线或时间。 */
export function importJournalLineage(save: GameSaveData): JournalImportedLineage {
  if (!isValidGameSave(save)) throw new Error('Invalid journal import')
  const result = new JournalImportedLineage()
  const current = cloneJournalSave(save)
  current.gridSize = save.gridSize ?? 9
  current.variantType = save.variantType ?? 'standard'
  current.undoStack = []
  current.redoStack = []
  const backwards: GameSaveData[] = [current]
  let cursor = current
  const undo = legacyGroups(save.undoStack)
  for (let index = undo.length - 1; index >= 0; index--) {
    const previous = applyLegacyBatch(cursor, undo[index], false)
    if (previous === null) { result.truncated = true; break }
    backwards.push(previous)
    cursor = previous
  }
  result.saves = backwards.reverse()
  result.headIndex = result.saves.length - 1
  cursor = current
  const redo = legacyGroups(save.redoStack)
  for (let index = redo.length - 1; index >= 0; index--) {
    const next = applyLegacyBatch(cursor, redo[index], true)
    if (next === null) { result.truncated = true; break }
    result.saves.push(next)
    cursor = next
  }
  return result
}

function assertNodeValues(session: JournalSession, node: JournalNode): void {
  const size = session.puzzle.gridSize
  if (node.values.length !== size * size || node.notes.length !== size * size) throw new Error('Invalid journal node size')
  for (let index = 0; index < node.values.length; index++) {
    const value = node.values[index]
    const notes = node.notes[index]
    if (!Number.isInteger(value) || value < 0 || value > size || !Number.isInteger(notes) || notes < 0 ||
      notes >= Math.pow(2, size * 2)) throw new Error('Invalid journal cell')
    const given = session.puzzle.cells[index]
    if ((given.flags & 1) !== 0 && (given.value !== value || notes !== 0)) throw new Error('Invalid journal given')
  }
}

/** 只读重建。历史预览传 false，续玩当前 head 使用工作账本。 */
export function toGameSave(graph: JournalGraph, nodeId?: string, useWorkingClock: boolean = true): GameSaveData {
  if (graph.session.kind === 'legacy') throw new Error('Legacy summary has no restorable journal node')
  const selectedId = nodeId ?? graph.session.headNodeId
  const node = journalNodeById(graph, selectedId)
  assertNodeValues(graph.session, node)
  const save = cloneJournalSave(graph.session.puzzle)
  for (let index = 0; index < save.cells.length; index++) {
    save.cells[index].value = node.values[index]
    save.cells[index].notes = node.notes[index]
    save.cells[index].flags &= 1
  }
  save.elapsedSeconds = node.elapsedSeconds
  save.errorCount = node.errorCount
  save.isChallengeFailed = node.isChallengeFailed
  save.selectedIndex = -1
  save.timestamp = node.createdAt
  save.journalSessionId = graph.session.id
  save.journalNodeId = node.id
  save.journalBranchId = selectedId === graph.session.headNodeId ? graph.session.activeBranchId : node.branchId
  const path = journalPath(graph, selectedId)
  save.undoStack = []
  for (let index = 1; index < path.length; index++) {
    assertNodeValues(graph.session, path[index - 1])
    const delta = journalDelta(path[index - 1], path[index])
    if (delta.length > 0) save.undoStack.push(delta)
  }
  save.redoStack = []
  if (selectedId === graph.session.headNodeId) {
    const branch = journalActiveBranch(graph)
    if (useWorkingClock) {
      save.elapsedSeconds = branch.mode === 'challenge' ? graph.session.scoreElapsedSeconds : branch.elapsedSeconds
      save.errorCount = branch.mode === 'challenge' ? graph.session.scoreErrorCount : branch.errorCount
      save.isChallengeFailed = branch.mode === 'challenge' ? graph.session.scoreChallengeFailed : branch.isChallengeFailed
    }
    const redoPath = journalPath(graph, branch.tipNodeId)
    const cursor = redoPath.findIndex((item: JournalNode): boolean => item.id === selectedId)
    if (cursor >= 0) {
      for (let index = redoPath.length - 1; index > cursor; index--) {
        assertNodeValues(graph.session, redoPath[index])
        const delta = journalDelta(redoPath[index - 1], redoPath[index])
        if (delta.length > 0) save.redoStack.push(delta)
      }
    }
  }
  if (!isValidGameSave(save)) throw new Error('Invalid reconstructed journal save')
  return save
}
