import { Context } from '@kit.AbilityKit'
import { GameSaveData } from '../models/GameSaveData'
import { JournalGraph, JournalState, JournalNode, JournalBranch, JournalStartOptions,
  cloneJournalSave, assertJournalSaveMatches, journalNodeById, journalActiveBranch,
  toGameSave } from '../models/GameJournal'
import { startSession, getSessionGraph, getSessionState, appendAction, moveCursor,
  forkFromNode, activateBranch, updateClock, claimSettlement } from '../utils/JournalStorage'

/** 一项先提交日志，再通知兼容存档；回调失败重试时不重复追加节点。 */
class JournalPendingOperation {
  sequence: number
  sessionId: string
  snapshot: GameSaveData
  action: string
  clockOnly: boolean
  committed: boolean = false

  constructor(sequence: number, sessionId: string, snapshot: GameSaveData,
    action: string, clockOnly: boolean) {
    this.sequence = sequence
    this.sessionId = sessionId
    this.snapshot = snapshot
    this.action = action
    this.clockOnly = clockOnly
  }
}

/**
 * 页面只提交当时的完整局面。串行队列保留失败项，显式 flush 才重试；
 * UI 游标、动态 flags 和选择态不参与盘面相等判断。
 */
export class GameJournalCoordinator {
  public onPersisted?: (save: GameSaveData) => void
  private context: Context
  private graph: JournalGraph | null = null
  private state: JournalState | null = null
  private nodeIndex: Map<string, JournalNode> = new Map<string, JournalNode>()
  private pending: JournalPendingOperation[] = []
  private draining: Promise<void> | null = null
  private nextSequence: number = 0
  private transitioning: boolean = false
  private accepting: boolean = true
  private claimedSettlements: Map<string, string> = new Map<string, string>()

  constructor(context: Context) {
    this.context = context
  }

  public getState(): JournalState | null {
    return this.state
  }

  public getGraph(): JournalGraph | null {
    return this.graph
  }

  public isPractice(): boolean {
    return this.state !== null && this.state.branch.mode === 'practice'
  }

  /** 离页先提交最后的 clock，再关闭入口；已排队数据仍可 flush。 */
  public deactivate(): void {
    this.accepting = false
  }

  public async initialize(save: GameSaveData, previousSessionId: string = '',
    startedInLegacyStats: boolean = false): Promise<GameSaveData> {
    const snapshot = cloneJournalSave(save)
    this.beginTransition()
    try {
      await this.flush()
      const sessionId = snapshot.journalSessionId ?? ''
      let graph: JournalGraph | null = sessionId !== '' ? await getSessionGraph(this.context, sessionId) : null
      if (graph === null) {
        const options = new JournalStartOptions()
        // 日志数据库缺失而兼容档仍在时，用已有 ID 恢复可验证的原子历史。
        if (sessionId !== '') options.sessionId = sessionId
        options.previousSessionId = previousSessionId
        options.startedInLegacyStats = startedInLegacyStats
        const created = await startSession(this.context, snapshot, options)
        graph = await this.requireGraph(created.session.id)
      }
      assertJournalSaveMatches(graph.session, snapshot)
      this.installGraph(graph)
      const current = this.requireState()
      const changed = !this.matchesNode(snapshot, current.node)
      const stalePointer = (snapshot.journalNodeId ?? '') !== '' &&
        snapshot.journalNodeId !== current.node.id && snapshot.timestamp < current.node.createdAt
      if (changed && !stalePointer) {
        this.enqueue(snapshot, 'recovered', false)
        await this.flush()
      } else if (!changed) {
        this.enqueue(snapshot, 'clock', true)
        await this.flush()
      }
      const restored = this.currentSave()
      if (this.matchesNode(snapshot, this.requireState().node)) restored.selectedIndex = snapshot.selectedIndex
      return restored
    } finally {
      this.transitioning = false
    }
  }

  /** 历史预览不能隐式移动工作游标；非 head 必须明确选择开练习分支。 */
  public async restore(sessionId: string, nodeId: string, fork: boolean, branchId: string = ''): Promise<GameSaveData> {
    this.beginTransition()
    try {
      await this.flush()
      const graph = await this.requireGraph(sessionId)
      const selectedBranch = branchId !== '' && !fork ?
        graph.branches.find((branch: JournalBranch): boolean => branch.id === branchId) : undefined
      if (branchId !== '' && !fork && selectedBranch === undefined) throw new Error('Journal branch not found')
      const targetId = nodeId || (selectedBranch !== undefined ? selectedBranch.tipNodeId : graph.session.headNodeId)
      if (selectedBranch !== undefined && targetId !== selectedBranch.tipNodeId) {
        throw new Error('Activating a journal branch requires its saved tip')
      }
      if (!fork && selectedBranch === undefined && targetId !== graph.session.headNodeId) {
        throw new Error('Restoring a non-head journal node requires an explicit practice fork')
      }
      // 先验证整条恢复路径，再执行显式的数据库变更。
      toGameSave(graph, targetId, false)
      if (fork) {
        const restored = await forkFromNode(this.context, sessionId, targetId)
        graph.session = restored.session
        graph.branches.push(restored.branch)
      } else if (selectedBranch !== undefined) {
        const restored = await activateBranch(this.context, sessionId, selectedBranch.id)
        graph.session = restored.session
        const index = graph.branches.findIndex((branch: JournalBranch): boolean => branch.id === restored.branch.id)
        graph.branches[index] = restored.branch
      }
      this.installGraph(graph)
      return this.currentSave()
    } finally {
      this.transitioning = false
    }
  }

  public async record(save: GameSaveData, action: string): Promise<void> {
    this.assertAccepting()
    this.enqueue(cloneJournalSave(save), action, false)
    await this.flush()
  }

  public async persistClock(save: GameSaveData): Promise<void> {
    this.assertAccepting()
    this.enqueue(cloneJournalSave(save), 'clock', true)
    await this.flush()
  }

  public flush(): Promise<void> {
    if (this.draining !== null) return this.draining
    const work = this.drainQueue()
    this.draining = work.then((): void => {
      this.draining = null
    }, (error: Error): void => {
      this.draining = null
      throw error
    })
    return this.draining
  }

  public async settle(outcome: 'won' | 'completed_failed'): Promise<boolean> {
    this.beginTransition()
    try {
      await this.flush()
      await this.assertCurrentCursor()
      const sessionId = this.requireState().session.id
      const previousClaim = this.claimedSettlements.get(sessionId)
      if (previousClaim !== undefined && previousClaim !== outcome) throw new Error('Settlement outcome changed during retry')
      const claimed = previousClaim !== undefined || await claimSettlement(this.context, sessionId, outcome)
      if (claimed) this.claimedSettlements.set(sessionId, outcome)
      this.mergeState(await getSessionState(this.context, sessionId))
      // 认领成功但刷新失败时保留回执，重试不能误报 false 导致漏记统计。
      this.claimedSettlements.delete(sessionId)
      return claimed
    } finally {
      this.transitioning = false
    }
  }

  /** 返回独立对象，调用者继续改格子不能反向改动队列或缓存。 */
  public stampSave(save: GameSaveData): GameSaveData {
    const stamped = cloneJournalSave(save)
    if (this.state !== null) {
      stamped.journalSessionId = this.state.session.id
      stamped.journalNodeId = this.state.node.id
      stamped.journalBranchId = this.state.branch.id
    }
    return stamped
  }

  private assertAccepting(): void {
    if (!this.accepting) throw new Error('Journal coordinator is inactive')
    if (this.transitioning) throw new Error('Journal coordinator is restoring')
    this.requireState()
  }

  private beginTransition(): void {
    if (!this.accepting) throw new Error('Journal coordinator is inactive')
    if (this.transitioning) throw new Error('Journal transition is already in progress')
    this.transitioning = true
  }

  private requireState(): JournalState {
    if (this.state === null) throw new Error('Journal coordinator is not initialized')
    return this.state
  }

  private async requireGraph(sessionId: string): Promise<JournalGraph> {
    const graph = await getSessionGraph(this.context, sessionId)
    if (graph === null || graph.session.kind === 'legacy') throw new Error('Restorable journal session not found')
    return graph
  }

  private installGraph(graph: JournalGraph): void {
    this.graph = graph
    this.nodeIndex.clear()
    for (const node of graph.nodes) this.nodeIndex.set(node.id, node)
    this.state = new JournalState(graph.session,
      journalNodeById(graph, graph.session.headNodeId), journalActiveBranch(graph))
  }

  private mergeState(state: JournalState): void {
    if (this.graph === null || this.graph.session.id !== state.session.id) {
      throw new Error('Journal state does not match cached session')
    }
    this.graph.session = state.session
    const nodeIndex = this.graph.nodes.findIndex((node: JournalNode): boolean => node.id === state.node.id)
    if (nodeIndex < 0) this.graph.nodes.push(state.node)
    else this.graph.nodes[nodeIndex] = state.node
    this.nodeIndex.set(state.node.id, state.node)
    const branchIndex = this.graph.branches.findIndex((branch: JournalBranch): boolean => branch.id === state.branch.id)
    if (branchIndex < 0) this.graph.branches.push(state.branch)
    else this.graph.branches[branchIndex] = state.branch
    this.state = state
  }

  /** 防止旧页面在另一个页面已恢复分支后继续写入旧快照。 */
  private async assertCurrentCursor(): Promise<void> {
    const expected = this.requireState()
    const actual = await getSessionState(this.context, expected.session.id)
    if (actual.session.headNodeId !== expected.node.id || actual.session.activeBranchId !== expected.branch.id) {
      throw new Error('Journal cursor changed outside this coordinator; reload explicitly')
    }
    this.mergeState(actual)
  }

  private enqueue(snapshot: GameSaveData, action: string, clockOnly: boolean): void {
    const state = this.requireState()
    assertJournalSaveMatches(state.session, snapshot)
    this.nextSequence++
    this.pending.push(new JournalPendingOperation(this.nextSequence, state.session.id, snapshot, action, clockOnly))
  }

  private async drainQueue(): Promise<void> {
    while (this.pending.length > 0) {
      const operation = this.pending[0]
      if (!operation.committed) {
        await this.commitOperation(operation)
        operation.committed = true
      }
      // 后续输入已排队时，不用旧快照覆盖 GameStorage。回调失败保留 committed 项。
      if (operation.sequence === this.nextSequence && this.onPersisted !== undefined) {
        const persisted = this.stampSave(operation.snapshot)
        const state = this.requireState()
        persisted.elapsedSeconds = state.branch.elapsedSeconds
        persisted.errorCount = state.branch.errorCount
        persisted.isChallengeFailed = state.branch.isChallengeFailed
        this.onPersisted(persisted)
      }
      this.pending.shift()
    }
  }

  private async commitOperation(operation: JournalPendingOperation): Promise<void> {
    if (operation.sessionId !== this.requireState().session.id) throw new Error('Queued journal session changed')
    await this.assertCurrentCursor()
    const state = this.requireState()
    assertJournalSaveMatches(state.session, operation.snapshot)
    if (operation.clockOnly && !this.matchesNode(operation.snapshot, state.node)) {
      throw new Error('Clock snapshot differs from journal head; record the edit first')
    }
    const cursorTarget = operation.action === 'undo' ? this.undoTarget(operation.snapshot) :
      operation.action === 'redo' ? this.redoTarget(operation.snapshot) : null
    if (operation.clockOnly || cursorTarget !== null) {
      this.mergeState(await updateClock(this.context, state.session.id, operation.snapshot.elapsedSeconds,
        operation.snapshot.errorCount, operation.snapshot.isChallengeFailed))
      if (cursorTarget !== null && cursorTarget.id !== this.requireState().node.id) {
        this.mergeState(await moveCursor(this.context, state.session.id, cursorTarget.id))
      }
      return
    }
    const previousBranch = state.branch
    const next = await appendAction(this.context, state.session.id, operation.snapshot, operation.action)
    // append 从撤销后的 head 创建新路线时，旧分支账本也在同一事务更新了。
    if (next.branch.id !== previousBranch.id) {
      previousBranch.elapsedSeconds = next.branch.elapsedSeconds
      previousBranch.errorCount = next.branch.errorCount
      previousBranch.isChallengeFailed = next.branch.isChallengeFailed
    }
    this.mergeState(next)
  }

  private matchesNode(save: GameSaveData, node: JournalNode): boolean {
    if (save.cells.length !== node.values.length || save.cells.length !== node.notes.length) return false
    for (let index = 0; index < save.cells.length; index++) {
      if (save.cells[index].value !== node.values[index] || save.cells[index].notes !== node.notes[index]) return false
    }
    return true
  }

  private samePosition(first: JournalNode, second: JournalNode): boolean {
    if (first.values.length !== second.values.length || first.notes.length !== second.notes.length) return false
    for (let index = 0; index < first.values.length; index++) {
      if (first.values[index] !== second.values[index] || first.notes[index] !== second.notes[index]) return false
    }
    return true
  }

  private indexedNode(id: string): JournalNode {
    const node = this.nodeIndex.get(id)
    if (node === undefined) throw new Error('Journal cached node not found')
    return node
  }

  private undoTarget(save: GameSaveData): JournalNode | null {
    const head = this.requireState().node
    if (this.matchesNode(save, head)) return head
    const visited = new Set<string>()
    let id = head.parentId
    while (id !== '') {
      if (visited.has(id)) throw new Error('Cycle in journal undo path')
      visited.add(id)
      const parent = this.indexedNode(id)
      if (this.matchesNode(save, parent)) return parent
      // checkpoint 与 head 同盘面时不占 GameHistory 的一个 undo 批次。
      if (!this.samePosition(parent, head)) return null
      id = parent.parentId
    }
    return null
  }

  private redoTarget(save: GameSaveData): JournalNode | null {
    const state = this.requireState()
    if (this.matchesNode(save, state.node)) return state.node
    const route: JournalNode[] = []
    const visited = new Set<string>()
    let id = state.branch.tipNodeId
    while (id !== state.node.id && id !== '') {
      if (visited.has(id)) throw new Error('Cycle in journal redo path')
      visited.add(id)
      const node = this.indexedNode(id)
      route.push(node)
      id = node.parentId
    }
    if (id !== state.node.id) throw new Error('Head is outside cached branch route')
    for (let index = route.length - 1; index >= 0; index--) {
      const next = route[index]
      if (this.matchesNode(save, next)) return next
      if (!this.samePosition(next, state.node)) return null
    }
    return null
  }

  private currentSave(): GameSaveData {
    if (this.graph === null) throw new Error('Journal coordinator is not initialized')
    const save = this.stampSave(toGameSave(this.graph))
    save.timestamp = Math.max(save.timestamp, this.graph.session.updatedAt)
    return save
  }
}
