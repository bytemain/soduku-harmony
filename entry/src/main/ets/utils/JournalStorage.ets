/**
 * 每局原题独立一行，节点只追加；head、分支 tip 与节点在同一事务提交。
 * 所有访问经同一队列，避免异步输入、计时与恢复穿插进同一连接事务。
 */
import { relationalStore, preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { GameSaveData, CellSerialized, isValidGameSave } from '../models/GameSaveData'
import { GameRecord } from './HistoryStorage'
import { JournalSession, JournalNode, JournalBranch, JournalGraph, JournalState, JournalStartOptions,
  JournalStatsFact, JournalStatsSnapshot,
  JournalOutcome, journalPuzzleFromSave, assertJournalSaveMatches, updateJournalMetrics, makeJournalNode,
  journalNodeById, journalActiveBranch, importJournalLineage, isJournalBoardComplete, toGameSave } from '../models/GameJournal'

export { toGameSave } from '../models/GameJournal'

const STORE_NAME: string = 'sudoku_journal.db'
let storePromise: Promise<relationalStore.RdbStore> | null = null
let operationTail: Promise<void> = Promise.resolve()
let idCounter: number = 0

function nextId(prefix: string): string {
  idCounter++
  return `${prefix}-${Date.now().toString(36)}-${idCounter.toString(36)}-${Math.random().toString(36).slice(2, 12)}`
}

function serialized<T>(operation: () => Promise<T>): Promise<T> {
  const result = operationTail.then(operation)
  // 保持队列可用，但仍把本次错误返回调用者，不能把写失败伪装为成功。
  operationTail = result.then((): void => {}, (): void => {})
  return result
}

async function transaction<T>(store: relationalStore.RdbStore, operation: () => Promise<T>): Promise<T> {
  store.beginTransaction()
  try {
    const result = await operation()
    store.commit()
    return result
  } catch (error) {
    store.rollBack()
    throw new Error((error as Error)?.message || String(error))
  }
}

/** 元数据更新不反复写入原题、答案或旧版回放素材。 */
function metadataJson(session: JournalSession): string {
  const metadata = new JournalSession()
  metadata.id = session.id
  metadata.kind = session.kind
  metadata.legacyOnly = session.legacyOnly
  metadata.createdAt = session.createdAt
  metadata.updatedAt = session.updatedAt
  metadata.headNodeId = session.headNodeId
  metadata.activeBranchId = session.activeBranchId
  metadata.nodeCount = session.nodeCount
  metadata.mode = session.mode
  metadata.outcome = session.outcome
  metadata.previousSessionId = session.previousSessionId
  metadata.scoreElapsedSeconds = session.scoreElapsedSeconds
  metadata.scoreErrorCount = session.scoreErrorCount
  metadata.scoreChallengeFailed = session.scoreChallengeFailed
  metadata.settled = session.settled
  metadata.settledAt = session.settledAt
  metadata.legacyStepCount = session.legacyStepCount
  metadata.historyImportTruncated = session.historyImportTruncated
  metadata.startedInLegacyStats = session.startedInLegacyStats
  metadata.challengeFailedAt = session.challengeFailedAt
  metadata.completionNodeId = session.completionNodeId
  metadata.errorLimit = session.errorLimit
  return JSON.stringify(metadata)
}

async function insertSession(store: relationalStore.RdbStore, session: JournalSession,
  legacyJson: string = ''): Promise<void> {
  await store.executeSql('INSERT INTO journal_sessions (id, updated_at, puzzle, metadata, legacy_payload) VALUES (?, ?, ?, ?, ?)',
    [session.id, session.updatedAt, JSON.stringify(session.puzzle), metadataJson(session), legacyJson])
}

async function saveSessionMetadata(store: relationalStore.RdbStore, session: JournalSession): Promise<void> {
  await store.executeSql('UPDATE journal_sessions SET updated_at = ?, metadata = ? WHERE id = ?',
    [session.updatedAt, metadataJson(session), session.id])
}

function sessionFromRow(rows: relationalStore.ResultSet): JournalSession {
  const session = JSON.parse(rows.getString(rows.getColumnIndex('metadata'))) as JournalSession
  session.startedInLegacyStats = session.startedInLegacyStats ?? false
  session.challengeFailedAt = session.challengeFailedAt ?? 0
  session.completionNodeId = session.completionNodeId ?? ''
  session.historyImportTruncated = session.historyImportTruncated ?? false
  const historicalCompletion = session.settled || session.completionNodeId !== '' || session.outcome !== 'active'
  session.errorLimit = session.errorLimit ?? (historicalCompletion ? 3 : 0)
  if (!historicalCompletion) session.errorLimit = 0
  if (session.errorLimit === 0) {
    session.scoreChallengeFailed = false
    session.challengeFailedAt = 0
  }
  session.puzzle = JSON.parse(rows.getString(rows.getColumnIndex('puzzle'))) as GameSaveData
  const legacyJson = rows.getString(rows.getColumnIndex('legacy_payload'))
  if (legacyJson !== '') {
    const record = JSON.parse(legacyJson) as GameRecord
    if (isValidGameSave(record.replaySave)) session.legacyReplaySave = record.replaySave
  }
  return session
}

async function readSession(store: relationalStore.RdbStore, id: string): Promise<JournalSession | null> {
  const rows = await store.querySql('SELECT metadata, puzzle, legacy_payload FROM journal_sessions WHERE id = ?', [id])
  try { return rows.goToNextRow() ? sessionFromRow(rows) : null } finally { rows.close() }
}

async function readGraph(store: relationalStore.RdbStore, id: string): Promise<JournalGraph | null> {
  const session = await readSession(store, id)
  if (!session) return null
  const graph = new JournalGraph()
  graph.session = session
  const nodes = await store.querySql('SELECT n.payload, b.label FROM journal_nodes n LEFT JOIN journal_bookmarks b ON n.id = b.node_id WHERE n.session_id = ? ORDER BY n.ordinal ASC', [id])
  try {
    while (nodes.goToNextRow()) {
      const node = JSON.parse(nodes.getString(0)) as JournalNode
      if (!nodes.isColumnNull(1)) {
        node.label = nodes.getString(1)
        node.manual = true
      }
      graph.nodes.push(node)
    }
  } finally { nodes.close() }
  const branches = await store.querySql('SELECT payload FROM journal_branches WHERE session_id = ? ORDER BY created_at ASC, id ASC', [id])
  try {
    while (branches.goToNextRow()) graph.branches.push(JSON.parse(branches.getString(0)) as JournalBranch)
  } finally { branches.close() }
  return graph
}

async function requireGraph(store: relationalStore.RdbStore, id: string): Promise<JournalGraph> {
  const graph = await readGraph(store, id)
  if (!graph || graph.session.kind === 'legacy') throw new Error('Active journal session not found')
  return graph
}

async function readNode(store: relationalStore.RdbStore, sessionId: string, nodeId: string): Promise<JournalNode> {
  const rows = await store.querySql('SELECT n.payload, b.label FROM journal_nodes n LEFT JOIN journal_bookmarks b ON n.id = b.node_id WHERE n.session_id = ? AND n.id = ?', [sessionId, nodeId])
  try {
    if (!rows.goToNextRow()) throw new Error('Journal node not found')
    const node = JSON.parse(rows.getString(0)) as JournalNode
    if (!rows.isColumnNull(1)) { node.label = rows.getString(1); node.manual = true }
    return node
  } finally { rows.close() }
}

/** 输入、计时只读取 head 及元数据，不能每一步重读整棵历史树。 */
async function requireState(store: relationalStore.RdbStore, sessionId: string): Promise<JournalState> {
  const session = await readSession(store, sessionId)
  if (!session || session.kind === 'legacy') throw new Error('Active journal session not found')
  const rows = await store.querySql('SELECT payload FROM journal_branches WHERE session_id = ? AND id = ?', [sessionId, session.activeBranchId])
  let branch: JournalBranch
  try {
    if (!rows.goToNextRow()) throw new Error('Journal branch not found')
    branch = JSON.parse(rows.getString(0)) as JournalBranch
  } finally { rows.close() }
  return new JournalState(session, await readNode(store, sessionId, session.headNodeId), branch)
}

async function insertNode(store: relationalStore.RdbStore, node: JournalNode): Promise<void> {
  await store.executeSql('INSERT INTO journal_nodes (id, session_id, parent_id, branch_id, ordinal, payload) VALUES (?, ?, ?, ?, ?, ?)',
    [node.id, node.sessionId, node.parentId, node.branchId, node.sequence, JSON.stringify(node)])
}

async function insertBranch(store: relationalStore.RdbStore, branch: JournalBranch): Promise<void> {
  await store.executeSql('INSERT INTO journal_branches (id, session_id, created_at, payload) VALUES (?, ?, ?, ?)',
    [branch.id, branch.sessionId, branch.createdAt, JSON.stringify(branch)])
}

async function saveBranch(store: relationalStore.RdbStore, branch: JournalBranch): Promise<void> {
  await store.executeSql('UPDATE journal_branches SET payload = ? WHERE id = ? AND session_id = ?',
    [JSON.stringify(branch), branch.id, branch.sessionId])
}

function stateFromGraph(graph: JournalGraph): JournalState {
  return new JournalState(graph.session, journalNodeById(graph, graph.session.headNodeId), journalActiveBranch(graph))
}

/** 旧记录只迁移现有证据，不从 steps 猜时间，也不伪造可恢复节点。 */
async function migrateLegacy(store: relationalStore.RdbStore, context: Context): Promise<void> {
  const marker = await store.querySql('SELECT value FROM journal_meta WHERE key = ?', ['legacy_history_v1'])
  let migrated = false
  try { migrated = marker.goToNextRow() } finally { marker.close() }
  if (migrated) return
  // 不调用吞掉读取错误并返回 [] 的旧包装，失败时保留迁移未完成状态供重试。
  const legacyOptions: preferences.Options = { name: 'sudoku_history' }
  const legacyStore = preferences.getPreferencesSync(context, legacyOptions)
  const legacyText = legacyStore.getSync('game_records', '') as string
  const records = legacyText ? JSON.parse(legacyText) as GameRecord[] : []
  if (!Array.isArray(records)) throw new Error('Invalid legacy history data')
  await transaction(store, async (): Promise<void> => {
    for (let index = 0; index < records.length; index++) {
      const record = records[index]
      const session = new JournalSession()
      session.id = `legacy-v1-${index}`
      session.kind = 'legacy'
      session.legacyOnly = true
      session.createdAt = Number.isFinite(record.timestamp) ? record.timestamp : 0
      session.updatedAt = session.createdAt
      session.outcome = record.won ? 'won' : 'completed_failed'
      session.settled = true
      session.settledAt = session.createdAt
      session.scoreElapsedSeconds = Number.isFinite(record.timeSeconds) ? Math.max(0, record.timeSeconds) : 0
      session.scoreErrorCount = Number.isInteger(record.errors) ? Math.max(0, record.errors) : 0
      session.scoreChallengeFailed = !record.won
      session.legacyStepCount = Number.isInteger(record.stepCount) ? Math.max(0, record.stepCount) : 0
      if (isValidGameSave(record.replaySave)) {
        session.puzzle = journalPuzzleFromSave(record.replaySave!)
      } else {
        session.puzzle.difficulty = record.difficulty
        session.puzzle.seed = record.seed
        session.puzzle.symmetry = record.symmetry
      }
      await insertSession(store, session, JSON.stringify(record))
    }
    await store.executeSql('INSERT INTO journal_meta (key, value) VALUES (?, ?)', ['legacy_history_v1', '1'])
  })
}

async function initializeStore(context: Context): Promise<relationalStore.RdbStore> {
  const config: relationalStore.StoreConfig = { name: STORE_NAME, securityLevel: relationalStore.SecurityLevel.S1 }
  const store = await relationalStore.getRdbStore(context, config)
  await store.executeSql('CREATE TABLE IF NOT EXISTS journal_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)')
  await store.executeSql('CREATE TABLE IF NOT EXISTS journal_sessions (id TEXT PRIMARY KEY, updated_at INTEGER NOT NULL, puzzle TEXT NOT NULL, metadata TEXT NOT NULL, legacy_payload TEXT NOT NULL)')
  await store.executeSql('CREATE INDEX IF NOT EXISTS journal_sessions_updated ON journal_sessions(updated_at DESC, id ASC)')
  await store.executeSql('CREATE TABLE IF NOT EXISTS journal_nodes (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, parent_id TEXT NOT NULL, branch_id TEXT NOT NULL, ordinal INTEGER NOT NULL, payload TEXT NOT NULL, UNIQUE(session_id, ordinal))')
  await store.executeSql('CREATE INDEX IF NOT EXISTS journal_nodes_session ON journal_nodes(session_id, ordinal)')
  await store.executeSql('CREATE TABLE IF NOT EXISTS journal_branches (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, created_at INTEGER NOT NULL, payload TEXT NOT NULL)')
  await store.executeSql('CREATE INDEX IF NOT EXISTS journal_branches_session ON journal_branches(session_id)')
  await store.executeSql('CREATE TABLE IF NOT EXISTS journal_bookmarks (node_id TEXT PRIMARY KEY, session_id TEXT NOT NULL, label TEXT NOT NULL)')
  // 首次开库先冻结旧统计；此操作先于任何 journal session 创建，避免双算的初始化竞态。
  const baseline = await store.querySql('SELECT value FROM journal_meta WHERE key = ?', ['legacy_stats_baseline_v1'])
  let hasBaseline = false
  try { hasBaseline = baseline.goToNextRow() } finally { baseline.close() }
  if (!hasBaseline) {
    const statsOptions: preferences.Options = { name: 'sudoku_stats' }
    const statsStore = preferences.getPreferencesSync(context, statsOptions)
    const legacyStats = statsStore.getSync('game_stats', '') as string
    await store.executeSql('INSERT INTO journal_meta (key, value) VALUES (?, ?)', ['legacy_stats_baseline_v1', legacyStats])
  }
  await migrateLegacy(store, context)
  return store
}

async function getStore(context: Context): Promise<relationalStore.RdbStore> {
  if (storePromise === null) storePromise = initializeStore(context)
  try { return await storePromise } catch (error) {
    storePromise = null
    throw new Error((error as Error)?.message || String(error))
  }
}

export function openJournalStore(context: Context): Promise<void> {
  return serialized(async (): Promise<void> => { await getStore(context) })
}

export function listSessions(context: Context, limit: number = 30, offset: number = 0): Promise<JournalSession[]> {
  return serialized(async (): Promise<JournalSession[]> => {
    const store = await getStore(context)
    const pageSize = Math.max(1, Math.min(200, Math.floor(limit)))
    const start = Math.max(0, Math.floor(offset))
    const rows = await store.querySql('SELECT metadata, puzzle, legacy_payload FROM journal_sessions ORDER BY updated_at DESC, id ASC LIMIT ? OFFSET ?', [pageSize, start])
    const sessions: JournalSession[] = []
    try { while (rows.goToNextRow()) sessions.push(sessionFromRow(rows)) } finally { rows.close() }
    return sessions
  })
}

export function getSessionGraph(context: Context, sessionId: string): Promise<JournalGraph | null> {
  return serialized(async (): Promise<JournalGraph | null> => readGraph(await getStore(context), sessionId))
}

export function getSessionState(context: Context, sessionId: string): Promise<JournalState> {
  return serialized(async (): Promise<JournalState> => requireState(await getStore(context), sessionId))
}

export function startSession(context: Context, save: GameSaveData,
  options: JournalStartOptions = new JournalStartOptions()): Promise<JournalState> {
  // 在排队之前复制，不能在 await 后读取会被后续输入修改的数组。
  const snapshot = JSON.parse(JSON.stringify(save)) as GameSaveData
  const sessionOptions = JSON.parse(JSON.stringify(options)) as JournalStartOptions
  return serialized(async (): Promise<JournalState> => {
    const store = await getStore(context)
    return transaction(store, async (): Promise<JournalState> => {
      const id = sessionOptions.sessionId || nextId('session')
      const existing = await readGraph(store, id)
      if (existing) {
        if (existing.session.kind === 'legacy') throw new Error('Cannot replace legacy session')
        assertJournalSaveMatches(existing.session, snapshot)
        return stateFromGraph(existing)
      }
      const session = new JournalSession()
      session.id = id
      session.createdAt = Date.now()
      session.updatedAt = session.createdAt
      session.mode = sessionOptions.mode ?? 'auto'
      session.previousSessionId = sessionOptions.previousSessionId ?? ''
      session.startedInLegacyStats = sessionOptions.startedInLegacyStats ?? false
      session.puzzle = journalPuzzleFromSave(snapshot)
      const branch = new JournalBranch()
      branch.id = nextId('branch')
      branch.sessionId = id
      branch.createdAt = session.createdAt
      updateJournalMetrics(session, branch, snapshot.elapsedSeconds, snapshot.errorCount, snapshot.isChallengeFailed)
      // 旧存档原有失败已包含在 baseline；只有之后新发生的失败才增加 journal 事件。
      if (session.startedInLegacyStats && session.scoreChallengeFailed) session.challengeFailedAt = 0
      const lineage = importJournalLineage(snapshot)
      const nodes: JournalNode[] = []
      const importedProgress = snapshot.elapsedSeconds > 0 || lineage.saves.length > 1 || snapshot.cells.some((cell: CellSerialized): boolean =>
        ((cell.flags & 1) === 0 && cell.value !== 0) || cell.notes !== 0)
      for (let index = 0; index < lineage.saves.length; index++) {
        const knownTime = index === lineage.headIndex
        const action = lineage.saves.length > 1 ? (index === 0 ? 'import' : 'imported_edit') : (importedProgress ? 'import' : 'start')
        const node = makeJournalNode(session, branch, lineage.saves[index], nextId('node'), action, knownTime ? session.createdAt : 0)
        node.timingKnown = knownTime
        if (!knownTime) { node.elapsedSeconds = 0; node.errorCount = 0; node.isChallengeFailed = false }
        nodes.push(node)
        session.headNodeId = node.id
        session.nodeCount++
      }
      const head = nodes[lineage.headIndex]
      branch.tipNodeId = nodes[nodes.length - 1].id
      session.headNodeId = head.id
      session.activeBranchId = branch.id
      session.outcome = head.outcome
      if (head.outcome !== 'active') session.completionNodeId = head.id
      session.historyImportTruncated = lineage.truncated
      await insertSession(store, session)
      await insertBranch(store, branch)
      for (const node of nodes) await insertNode(store, node)
      return new JournalState(session, head, branch)
    })
  })
}

export function appendAction(context: Context, sessionId: string, save: GameSaveData,
  action: string): Promise<JournalState> {
  const snapshot = JSON.parse(JSON.stringify(save)) as GameSaveData
  return serialized(async (): Promise<JournalState> => {
    const store = await getStore(context)
    return transaction(store, async (): Promise<JournalState> => {
      const current = await requireState(store, sessionId)
      const session = current.session
      let branch = current.branch
      if (branch.mode === 'challenge' && (session.settled || session.completionNodeId !== '')) throw new Error('Completed challenge requires a practice branch')
      assertJournalSaveMatches(session, snapshot)
      updateJournalMetrics(session, branch, snapshot.elapsedSeconds, snapshot.errorCount, snapshot.isChallengeFailed)
      const head = current.node
      const changed = snapshot.cells.some((cell: CellSerialized, index: number): boolean => cell.value !== head.values[index] || cell.notes !== head.notes[index])
      session.updatedAt = Date.now()
      if (!changed && action !== 'checkpoint') {
        await saveBranch(store, branch)
        await saveSessionMetadata(store, session)
        return new JournalState(session, head, branch)
      }
      if (session.headNodeId !== branch.tipNodeId) {
        await saveBranch(store, branch)
        const fork = new JournalBranch()
        fork.id = nextId('branch')
        fork.sessionId = sessionId
        fork.forkNodeId = session.headNodeId
        fork.tipNodeId = session.headNodeId
        fork.mode = branch.mode
        fork.createdAt = session.updatedAt
        fork.elapsedSeconds = branch.elapsedSeconds
        fork.errorCount = branch.errorCount
        fork.isChallengeFailed = branch.isChallengeFailed
        branch = fork
        session.activeBranchId = branch.id
        await insertBranch(store, branch)
      }
      const node = makeJournalNode(session, branch, snapshot, nextId('node'), action, session.updatedAt)
      session.headNodeId = node.id
      session.nodeCount++
      branch.tipNodeId = node.id
      if (branch.mode === 'challenge') {
        session.outcome = node.outcome
        if (node.outcome !== 'active' && session.completionNodeId === '') session.completionNodeId = node.id
      }
      await insertNode(store, node)
      await saveBranch(store, branch)
      await saveSessionMetadata(store, session)
      return new JournalState(session, node, branch)
    })
  })
}

export function moveCursor(context: Context, sessionId: string, nodeId: string): Promise<JournalState> {
  return serialized(async (): Promise<JournalState> => {
    const store = await getStore(context)
    return transaction(store, async (): Promise<JournalState> => {
      const current = await requireState(store, sessionId)
      const branch = current.branch
      if (branch.mode === 'challenge' && (current.session.settled || current.session.completionNodeId !== '')) throw new Error('Completed challenge requires a practice branch')
      const path = await store.querySql('WITH RECURSIVE ancestry(id, parent_id) AS (SELECT id, parent_id FROM journal_nodes WHERE id = ? AND session_id = ? UNION SELECT n.id, n.parent_id FROM journal_nodes n JOIN ancestry a ON n.id = a.parent_id WHERE n.session_id = ?) SELECT id FROM ancestry WHERE id = ? LIMIT 1',
        [branch.tipNodeId, sessionId, sessionId, nodeId])
      try {
        if (!path.goToNextRow()) throw new Error('Node is outside the active branch; use forkFromNode')
      } finally { path.close() }
      const node = await readNode(store, sessionId, nodeId)
      current.session.headNodeId = nodeId
      current.session.updatedAt = Date.now()
      if (branch.mode === 'challenge') current.session.outcome = node.outcome
      await saveSessionMetadata(store, current.session)
      return new JournalState(current.session, node, branch)
    })
  })
}

export function forkFromNode(context: Context, sessionId: string, nodeId: string,
  name: string = ''): Promise<JournalState> {
  return serialized(async (): Promise<JournalState> => {
    const store = await getStore(context)
    return transaction(store, async (): Promise<JournalState> => {
      const graph = await requireGraph(store, sessionId)
      const node = journalNodeById(graph, nodeId)
      // 同时校验节点值、原题和整条祖先链，损坏节点不能进入正式页面。
      toGameSave(graph, nodeId, false)
      const branch = new JournalBranch()
      branch.id = nextId('branch')
      branch.sessionId = sessionId
      branch.forkNodeId = nodeId
      branch.tipNodeId = nodeId
      branch.name = name.trim().slice(0, 80)
      branch.mode = 'practice'
      branch.createdAt = Date.now()
      branch.elapsedSeconds = node.elapsedSeconds
      branch.errorCount = node.errorCount
      branch.isChallengeFailed = false
      graph.session.headNodeId = nodeId
      graph.session.activeBranchId = branch.id
      graph.session.updatedAt = branch.createdAt
      await insertBranch(store, branch)
      await saveSessionMetadata(store, graph.session)
      return new JournalState(graph.session, node, branch)
    })
  })
}

/** 回到已有路线，不新建节点/分支，也不丢弃试验路线。 */
export function activateBranch(context: Context, sessionId: string, branchId: string): Promise<JournalState> {
  return serialized(async (): Promise<JournalState> => {
    const store = await getStore(context)
    return transaction(store, async (): Promise<JournalState> => {
      const graph = await requireGraph(store, sessionId)
      const branch = graph.branches.find((item: JournalBranch): boolean => item.id === branchId)
      if (!branch || branch.sessionId !== sessionId) throw new Error('Journal branch not found')
      if (branch.mode === 'challenge' && (graph.session.settled || graph.session.completionNodeId !== '')) {
        throw new Error('Completed challenge cannot be activated for play')
      }
      // 只读校验整条祖先链、棋盘值与原题；任一步失败不改变活动指针。
      toGameSave(graph, branch.tipNodeId, false)
      const node = journalNodeById(graph, branch.tipNodeId)
      if (branch.mode === 'challenge') {
        updateJournalMetrics(graph.session, branch, graph.session.scoreElapsedSeconds,
          graph.session.scoreErrorCount, graph.session.scoreChallengeFailed)
        graph.session.outcome = node.outcome
      }
      graph.session.headNodeId = branch.tipNodeId
      graph.session.activeBranchId = branch.id
      graph.session.updatedAt = Date.now()
      await saveBranch(store, branch)
      await saveSessionMetadata(store, graph.session)
      return new JournalState(graph.session, node, branch)
    })
  })

}

export function bookmarkNode(context: Context, sessionId: string, nodeId: string, label: string): Promise<void> {
  return serialized(async (): Promise<void> => {
    const store = await getStore(context)
    return transaction(store, async (): Promise<void> => {
      await readNode(store, sessionId, nodeId)
      const name = label.trim().slice(0, 80)
      if (name === '') {
        await store.executeSql('DELETE FROM journal_bookmarks WHERE node_id = ? AND session_id = ?', [nodeId, sessionId])
      } else {
        await store.executeSql('INSERT OR REPLACE INTO journal_bookmarks (node_id, session_id, label) VALUES (?, ?, ?)', [nodeId, sessionId, name])
      }
    })
  })
}

export function updateClock(context: Context, sessionId: string, elapsedSeconds: number,
  errorCount: number, challengeFailed: boolean): Promise<JournalState> {
  return serialized(async (): Promise<JournalState> => {
    const store = await getStore(context)
    return transaction(store, async (): Promise<JournalState> => {
      const current = await requireState(store, sessionId)
      const branch = current.branch
      if (branch.mode === 'challenge' && current.session.settled) return current
      updateJournalMetrics(current.session, branch, elapsedSeconds, errorCount, challengeFailed)
      current.session.updatedAt = Date.now()
      await saveBranch(store, branch)
      await saveSessionMetadata(store, current.session)
      return current
    })
  })
}

/** 只认领正式挑战一次；上层可按 sessionId 幂等重投统计投影。 */
export function claimSettlement(context: Context, sessionId: string,
  outcome: 'won' | 'completed_failed'): Promise<boolean> {
  return serialized(async (): Promise<boolean> => {
    const store = await getStore(context)
    return transaction(store, async (): Promise<boolean> => {
      const current = await requireState(store, sessionId)
      const branch = current.branch
      if (branch.mode !== 'challenge' || current.session.settled) return false
      const node = current.node
      const expected: JournalOutcome = current.session.scoreChallengeFailed ? 'completed_failed' : 'won'
      if (node.outcome === 'active' || expected !== outcome || !isJournalBoardComplete(current.session.puzzle, node.values)) {
        throw new Error('Journal settlement does not match completed head')
      }
      current.session.settled = true
      current.session.outcome = outcome
      current.session.completionNodeId = node.id
      current.session.settledAt = node.createdAt > 0 ? node.createdAt : Date.now()
      current.session.updatedAt = current.session.settledAt
      await saveSessionMetadata(store, current.session)
      return true
    })
  })
}

/**
 * 返回同一事务中的统计事实。完成节点已落库、claim 前崩溃时补认领，
 * 即使当前已进入 practice 也只结算原挑战，不改变任何活动游标或分支。
 */
export function loadJournalStatsSnapshot(context: Context): Promise<JournalStatsSnapshot> {
  return serialized(async (): Promise<JournalStatsSnapshot> => {
    const store = await getStore(context)
    return transaction(store, async (): Promise<JournalStatsSnapshot> => {
      const snapshot = new JournalStatsSnapshot()
      const baseline = await store.querySql('SELECT value FROM journal_meta WHERE key = ?', ['legacy_stats_baseline_v1'])
      try {
        if (!baseline.goToNextRow()) throw new Error('Journal statistics baseline missing')
        snapshot.legacyJson = baseline.getString(0)
      } finally { baseline.close() }
      const rows = await store.querySql('SELECT metadata, puzzle, legacy_payload FROM journal_sessions ORDER BY updated_at ASC, id ASC')
      const sessions: JournalSession[] = []
      try {
        while (rows.goToNextRow()) {
          const session = sessionFromRow(rows)
          if (!session.legacyOnly && session.kind !== 'legacy') sessions.push(session)
        }
      } finally { rows.close() }
      for (const session of sessions) {
        if (!session.settled) {
          let completion: JournalNode | null = null
          if (session.completionNodeId !== '') {
            completion = await readNode(store, session.id, session.completionNodeId)
          } else if (session.outcome !== 'active') {
            // 兼容早期 journal 中没有 completionNodeId 的已完成挑战。
            const graph = await requireGraph(store, session.id)
            for (const branch of graph.branches) {
              if (branch.mode !== 'challenge') continue
              const tip = journalNodeById(graph, branch.tipNodeId)
              if (tip.outcome !== 'active' && (completion === null || tip.sequence < completion.sequence)) completion = tip
            }
          }
          if (completion !== null) {
            const branchRows = await store.querySql('SELECT payload FROM journal_branches WHERE session_id = ? AND id = ?', [session.id, completion.branchId])
            let challengeNode = false
            try {
              if (branchRows.goToNextRow()) {
                const branch = JSON.parse(branchRows.getString(0)) as JournalBranch
                challengeNode = branch.mode === 'challenge'
              }
            } finally { branchRows.close() }
            const complete = isJournalBoardComplete(session.puzzle, completion.values)
            if (!challengeNode || !complete || completion.outcome === 'active') throw new Error('Invalid journal completion receipt')
            session.completionNodeId = completion.id
            session.settled = true
            session.outcome = session.scoreChallengeFailed ? 'completed_failed' : 'won'
            session.settledAt = completion.createdAt > 0 ? completion.createdAt : session.updatedAt
            await saveSessionMetadata(store, session)
          }
        }
        const fact = new JournalStatsFact()
        fact.id = session.id
        fact.difficulty = session.puzzle.difficulty
        fact.createdAt = session.createdAt
        fact.startedInLegacyStats = session.startedInLegacyStats
        fact.challengeFailedAt = session.challengeFailedAt
        fact.settled = session.settled
        fact.settledAt = session.settledAt
        fact.outcome = session.outcome
        fact.elapsedSeconds = session.scoreElapsedSeconds
        fact.errorCount = session.scoreErrorCount
        fact.errorLimit = session.errorLimit
        snapshot.facts.push(fact)
      }
      return snapshot
    })
  })
}
