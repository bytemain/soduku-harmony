/** 本局存档的只读轨道布局；不改变节点、路线或当前游标。 */
import { JournalGraph, JournalNode, JournalBranch } from '../models/GameJournal'

export const JOURNAL_GRAPH_ROW_HEIGHT: number = 68
export const JOURNAL_GRAPH_LANE_WIDTH: number = 36

export class JournalGraphStroke {
  id: string
  branchId: string
  commands: string

  constructor(id: string, branchId: string, commands: string) {
    this.id = id
    this.branchId = branchId
    this.commands = commands
  }
}

export class JournalGraphRow {
  id: string
  node: JournalNode
  lane: number
  kind: 'node' | 'group' | 'route'
  branch: JournalBranch | null = null
  count: number = 0
  expanded: boolean = false
  strokes: JournalGraphStroke[] = []

  constructor(id: string, node: JournalNode, lane: number, kind: 'node' | 'group' | 'route' = 'node') {
    this.id = id
    this.node = node
    this.lane = lane
    this.kind = kind
  }
}

export class JournalGraphLayout {
  rows: JournalGraphRow[] = []
  edges: JournalGraphEdge[] = []
  laneCount: number = 1
}

export class JournalGraphEdge {
  id: string
  branchId: string
  from: number
  to: number

  constructor(id: string, branchId: string, from: number, to: number) {
    this.id = id
    this.branchId = branchId
    this.from = from
    this.to = to
  }
}

export function journalLaneCenter(lane: number): number {
  return 18 + lane * JOURNAL_GRAPH_LANE_WIDTH
}

/** 每条路线独立占轨；没有新输入的路线也有独立端点，不能被共享分叉点吞掉。 */
export function buildJournalGraphLayout(graph: JournalGraph, selectedNodeId: string,
  expandedGroups: string[]): JournalGraphLayout {
  const layout = new JournalGraphLayout()
  const lanes = new Map<string, number>()
  for (const branch of graph.branches) lanes.set(branch.id, lanes.size)
  for (const node of graph.nodes) {
    if (!lanes.has(node.branchId)) lanes.set(node.branchId, lanes.size)
  }
  layout.laneCount = Math.max(1, lanes.size)

  const children = new Map<string, number>()
  const keyIds = new Set<string>([selectedNodeId, graph.session.headNodeId])
  const routesAtTip = new Map<string, JournalBranch[]>()
  for (const node of graph.nodes) children.set(node.parentId, (children.get(node.parentId) ?? 0) + 1)
  for (const branch of graph.branches) {
    keyIds.add(branch.forkNodeId)
    keyIds.add(branch.tipNodeId)
    const atTip = routesAtTip.get(branch.tipNodeId) ?? []
    atTip.push(branch)
    routesAtTip.set(branch.tipNodeId, atTip)
  }
  for (const node of graph.nodes) {
    if (node.parentId.length === 0 || node.manual || node.label.length > 0 ||
      (children.get(node.id) ?? 0) !== 1) keyIds.add(node.id)
  }

  const ordered = graph.nodes.slice().sort((left: JournalNode, right: JournalNode): number => left.sequence - right.sequence)
  const rowByNode = new Map<string, number>()
  let index = 0
  while (index < ordered.length) {
    const first = ordered[index]
    const lane = lanes.get(first.branchId) ?? 0
    let end = index
    while (end < ordered.length && !keyIds.has(ordered[end].id) &&
      (end === index || (ordered[end].branchId === first.branchId && ordered[end].parentId === ordered[end - 1].id))) end++

    if (end - index >= 3) {
      const group = new JournalGraphRow(`group:${first.id}`, first, lane, 'group')
      group.count = end - index
      group.expanded = expandedGroups.includes(first.id)
      const groupIndex = layout.rows.length
      layout.rows.push(group)
      for (let at = index; at < end; at++) {
        if (group.expanded) {
          rowByNode.set(ordered[at].id, layout.rows.length)
          layout.rows.push(new JournalGraphRow(ordered[at].id, ordered[at], lane))
        } else rowByNode.set(ordered[at].id, groupIndex)
      }
      index = end
    } else {
      rowByNode.set(first.id, layout.rows.length)
      layout.rows.push(new JournalGraphRow(first.id, first, lane))
      // 路线标签与该路线的末端紧邻，提供显式的路线选择目标。
      for (const branch of routesAtTip.get(first.id) ?? []) {
        const route = new JournalGraphRow(`route:${branch.id}`, first, lanes.get(branch.id) ?? 0, 'route')
        route.branch = branch
        layout.rows.push(route)
      }
      index++
    }
  }

  const connections = new Set<string>()
  for (const node of ordered) {
    const from = rowByNode.get(node.parentId)
    const to = rowByNode.get(node.id)
    if (from === undefined || to === undefined || from === to || from > to) continue
    const key = `${from}:${to}`
    if (connections.has(key)) continue
    connections.add(key)
    layout.edges.push(new JournalGraphEdge(key, node.branchId, from, to))
  }
  for (let rowIndex = 0; rowIndex < layout.rows.length; rowIndex++) {
    const row = layout.rows[rowIndex]
    if (row.kind !== 'route' || row.branch === null) continue
    const from = rowByNode.get(row.branch.tipNodeId)
    if (from !== undefined && from < rowIndex) {
      layout.edges.push(new JournalGraphEdge(row.id, row.branch.id, from, rowIndex))
    }
  }
  return layout
}

/** 只为当前可见行生成线段，避免大量长分叉产生「步数乘路线数」的常驻对象。 */
export function journalGraphRowAt(layout: JournalGraphLayout, index: number): JournalGraphRow {
  const source = layout.rows[index]
  const row = new JournalGraphRow(source.id, source.node, source.lane, source.kind)
  row.branch = source.branch
  row.count = source.count
  row.expanded = source.expanded
  const height = JOURNAL_GRAPH_ROW_HEIGHT
  const middle = height / 2
  for (const edge of layout.edges) {
    if (index < edge.from || index > edge.to) continue
    const startX = journalLaneCenter(layout.rows[edge.from].lane)
    const endX = journalLaneCenter(layout.rows[edge.to].lane)
    let commands: string
    if (index === edge.from) {
      commands = startX === endX ? `M ${startX} ${middle} L ${endX} ${height}` :
        `M ${startX} ${middle} C ${startX} ${height - 6} ${endX} ${middle + 6} ${endX} ${height}`
    } else commands = `M ${endX} 0 L ${endX} ${index === edge.to ? middle : height}`
    row.strokes.push(new JournalGraphStroke(`${edge.id}:${index}`, edge.branchId, commands))
  }
  return row
}
