/** 本局记录：选择节点只读预览，恢复由宿主页面明确执行。 */
import { KeyCode } from '@kit.InputKit'
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'
import { GameSaveData, isValidGameSave } from '../models/GameSaveData'
import { JournalGraph, JournalNode, JournalBranch } from '../models/GameJournal'
import { getSessionGraph, toGameSave, bookmarkNode } from '../utils/JournalStorage'
import { formatStr, getLocalizedString } from '../utils/I18nHelper'
import { buildJournalGraphLayout, JournalGraphLayout, JournalGraphRow, JournalGraphStroke, journalGraphRowAt, journalLaneCenter,
  JOURNAL_GRAPH_ROW_HEIGHT, JOURNAL_GRAPH_LANE_WIDTH } from '../utils/JournalGraphLayout'
import { JournalBoardPreview } from './JournalBoardPreview'

/** 列表只创建可见节点；布局变化后使用新键刷新连线，旧节点数据不被改写。 */
class JournalGraphDataSource implements IDataSource {
  private layout: JournalGraphLayout = new JournalGraphLayout()
  private listeners: DataChangeListener[] = []
  revision: number = 0

  totalCount(): number { return this.layout.rows.length }
  getData(index: number): JournalGraphRow { return journalGraphRowAt(this.layout, index) }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) this.listeners.push(listener)
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((item: DataChangeListener): boolean => item !== listener)
  }
  setLayout(layout: JournalGraphLayout): void {
    this.layout = layout
    this.revision++
    for (const listener of this.listeners) listener.onDataReloaded()
  }
}

@Component
export struct JournalPanel {
  @Prop @Watch('reload') sessionId: string = ''
  @Prop initialNodeId: string = ''
  @Prop initialBranchId: string = ''
  @Prop inGame: boolean = true
  onClose: () => void = () => {}
  onRestore: (sessionId: string, nodeId: string, fork: boolean, branchId?: string) => void = () => {}

  @StorageProp('isDarkMode') private isDarkMode: boolean = false
  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('topRectHeight') private topRectHeight: number = 0
  @StorageProp('bottomRectHeight') private bottomRectHeight: number = 0
  @StorageProp('leftRectWidth') private leftRectWidth: number = 0
  @StorageProp('rightRectWidth') private rightRectWidth: number = 0
  @State private graph: JournalGraph | null = null
  @State private rows: JournalGraphRow[] = []
  @State private laneCount: number = 1
  @State private treeWidth: number = 300
  @State private selectedNodeId: string = ''
  @State private selectedBranchId: string = ''
  @State private preview: GameSaveData | null = null
  @State private previewFailed: boolean = false
  @State private expandedGroups: string[] = []
  @State private loading: boolean = true
  @State private failed: boolean = false
  @State private bodyWidth: number = 0
  @State private panelHeight: number = 0
  @State private mobilePreview: boolean = false
  @State private showNameInput: boolean = false
  @State private nodeName: string = ''
  @State private savingName: boolean = false
  @State private nameFailed: boolean = false
  private requestSerial: number = 0
  private focusTreeOnAppear: boolean = false
  private treeScroller: Scroller = new Scroller()
  private graphData: JournalGraphDataSource = new JournalGraphDataSource()

  private getPalette(): ColorsConfig { return getThemeColors(this.isDarkMode) }
  private text(key: string): string {
    return getLocalizedString(getContext(this), key, this.localeRevision)
  }

  private isCompact(): boolean {
    const height = this.panelHeight - this.topRectHeight - this.bottomRectHeight
    return height > 0 && height < 480
  }

  private requestFocus(id: string): void {
    try {
      this.getUIContext().getFocusController().requestFocus(id)
    } catch (_error) {
      // 节点尚未挂载时保留默认焦点，焦点请求不能中断存档浏览。
    }
  }

  aboutToAppear(): void { this.reload() }

  aboutToDisappear(): void { this.requestSerial++ }

  private reload(): void {
    this.loadGraph()
  }

  private async loadGraph(): Promise<void> {
    const serial = ++this.requestSerial
    this.loading = true
    this.failed = false
    this.savingName = false
    this.showNameInput = false
    try {
      const graph = await getSessionGraph(getContext(this), this.sessionId)
      if (serial !== this.requestSerial) return
      if (graph === null) {
        this.failed = true
        this.graph = null
        return
      }
      this.graph = graph
      const initialBranch = graph.branches.find((branch: JournalBranch): boolean => branch.id === this.initialBranchId)
      this.selectedBranchId = initialBranch ? initialBranch.id : graph.session.activeBranchId
      const initial = graph.nodes.find((node: JournalNode): boolean => node.id === this.initialNodeId)
      const target = initial ? initial.id : (initialBranch ? initialBranch.tipNodeId : graph.session.headNodeId)
      this.selectNode(target, target !== graph.session.headNodeId,
        initialBranch !== undefined || target === graph.session.headNodeId)
    } catch (_error) {
      if (serial === this.requestSerial) this.failed = true
    } finally {
      if (serial === this.requestSerial) this.loading = false
    }
  }

  private selectedNode(): JournalNode | undefined {
    return this.graph?.nodes.find((node: JournalNode): boolean => node.id === this.selectedNodeId)
  }

  private selectedBranch(): JournalBranch | undefined {
    return this.graph?.branches.find((branch: JournalBranch): boolean => branch.id === this.selectedBranchId)
  }

  /** 共享分叉点归属所选路线；读取祖先链不改变当前游标。 */
  private routeContains(branch: JournalBranch, nodeId: string): boolean {
    if (this.graph === null) return false
    const nodes = new Map<string, JournalNode>()
    for (const node of this.graph.nodes) nodes.set(node.id, node)
    const visited = new Set<string>()
    let id = branch.tipNodeId
    while (id.length > 0 && !visited.has(id)) {
      if (id === nodeId) return true
      visited.add(id)
      const node = nodes.get(id)
      if (!node) return false
      id = node.parentId
    }
    return false
  }

  private selectRoute(branch: JournalBranch): void {
    this.selectedBranchId = branch.id
    this.selectNode(branch.tipNodeId, true, true)
  }

  private routeLabel(branch: JournalBranch): string {
    if (branch.name.trim().length > 0) return branch.name
    if (branch.mode === 'challenge') {
      const routes = this.graph?.branches.filter((entry: JournalBranch): boolean => entry.mode === 'challenge') ?? []
      const index = routes.findIndex((entry: JournalBranch): boolean => entry.id === branch.id)
      return index <= 0 ? this.text('journal_original_route') : formatStr(this.text('journal_solving_route'), index + 1)
    }
    const trials = this.graph?.branches.filter((entry: JournalBranch): boolean => entry.mode === 'practice') ?? []
    return formatStr(this.text('journal_trial_route'), trials.findIndex((entry: JournalBranch): boolean => entry.id === branch.id) + 1)
  }

  private selectNode(id: string, openPreview: boolean = true, preserveBranch: boolean = false): void {
    if (this.graph === null) return
    const node = this.graph.nodes.find((entry: JournalNode): boolean => entry.id === id)
    const branch = this.selectedBranch()
    const shared = this.graph.branches.some((entry: JournalBranch): boolean => entry.forkNodeId === id)
    if (!preserveBranch && node !== undefined && !(shared && branch !== undefined && this.routeContains(branch, id))) {
      this.selectedBranchId = node.branchId
    }
    this.selectedNodeId = id
    this.showNameInput = false
    this.nameFailed = false
    this.mobilePreview = openPreview
    this.previewFailed = false
    try {
      if (this.graph.session.kind === 'legacy') {
        this.preview = isValidGameSave(this.graph.session.puzzle) ? this.graph.session.puzzle : null
      } else {
        const save = toGameSave(this.graph, id, false)
        this.preview = isValidGameSave(save) ? save : null
        this.previewFailed = this.preview === null
      }
    } catch (_error) {
      this.preview = null
      this.previewFailed = true
    }
    this.refreshRows()
  }

  private isForkPoint(node: JournalNode): boolean {
    return (this.graph?.nodes.filter((entry: JournalNode): boolean => entry.parentId === node.id).length ?? 0) > 1 || (this.graph !== null &&
      this.graph.branches.some((branch: JournalBranch): boolean => branch.forkNodeId === node.id))
  }

  /** 时间从上到下，每条路线保持独立轨道；只生成展示数据。 */
  private refreshRows(): void {
    if (this.graph === null) { this.rows = []; return }
    const layout = buildJournalGraphLayout(this.graph, this.selectedNodeId, this.expandedGroups)
    this.rows = layout.rows
    this.laneCount = layout.laneCount
    this.graphData.setLayout(layout)
  }

  private toggleGroup(id: string): void {
    this.expandedGroups = this.expandedGroups.includes(id) ?
      this.expandedGroups.filter((value: string): boolean => value !== id) : [...this.expandedGroups, id]
    this.refreshRows()
  }

  private nodeTitle(node: JournalNode): string {
    if (node.label.length > 0) return node.label
    if (node.parentId.length === 0) return this.text('journal_start_node')
    return formatStr(this.text('journal_step_number'), node.sequence)
  }

  private actionLabel(action: string): string {
    const known: string[] = ['fill', 'note', 'eliminate', 'erase_note', 'erase', 'auto_notes', 'hint',
      'multi_notes', 'undo', 'redo', 'checkpoint', 'recovered', 'imported_edit', 'import', 'start']
    return this.text(known.includes(action) ? `journal_action_${action}` : 'journal_action_other')
  }

  private nodeDetail(node: JournalNode): string {
    const labels: string[] = [this.actionLabel(node.action)]
    if (node.id === this.graph?.session.headNodeId) labels.push(this.text('journal_current'))
    if (this.isForkPoint(node)) labels.push(this.text('journal_fork_point'))
    if (node.manual || node.label.length > 0) labels.push(this.text('journal_named_point'))
    if (labels.length === 1) labels.push(this.text('journal_auto_point'))
    labels.push(node.timingKnown === false ? this.text('journal_old_node') : this.formatTime(node.elapsedSeconds))
    return labels.join(' · ')
  }

  private formatTime(seconds: number): string {
    const total = Math.max(0, Math.floor(seconds))
    return `${Math.floor(total / 60).toString().padStart(2, '0')}:${(total % 60).toString().padStart(2, '0')}`
  }

  private routeCanContinue(): boolean {
    const node = this.selectedNode()
    const branch = this.selectedBranch()
    return this.graph !== null && node !== undefined && branch !== undefined && node.outcome === 'active' &&
      !(branch.mode === 'challenge' && (this.graph.session.settled || this.graph.session.completionNodeId.length > 0))
  }

  private atRouteTip(): boolean {
    const branch = this.selectedBranch()
    return branch !== undefined && this.selectedNodeId === branch.tipNodeId
  }

  private canContinueCurrent(): boolean {
    return this.graph !== null && this.selectedBranchId === this.graph.session.activeBranchId &&
      this.selectedNodeId === this.graph.session.headNodeId && this.routeCanContinue()
  }

  private canContinue(): boolean {
    return this.routeCanContinue() && (this.atRouteTip() || this.canContinueCurrent())
  }

  private isPractice(): boolean {
    return this.selectedBranch()?.mode === 'practice'
  }

  private nodeMetrics(node: JournalNode): string {
    if (node.timingKnown === false) return this.text('journal_time_unknown')
    const elapsed = this.formatTime(node.elapsedSeconds)
    return formatStr(this.text('journal_node_metrics'), elapsed, node.errorCount)
  }

  private restoreLabel(): string {
    if (this.routeCanContinue() && this.atRouteTip()) return this.text('journal_continue_route')
    return this.text(this.canContinueCurrent() ?
      (this.isPractice() ? 'journal_continue_practice' : 'journal_continue') : 'journal_restore_trial')
  }

  private restoreSelection(): void {
    if (this.loading || this.previewFailed || this.preview === null || this.savingName ||
      this.graph === null || this.graph.session.kind === 'legacy' || this.selectedNode() === undefined) return
    const canContinue = this.canContinue()
    // 当前撤销游标不在tip时，空branchId保留游标；显式路线切换才激活该tip。
    const branchId = canContinue && this.atRouteTip() ? this.selectedBranchId : ''
    this.onRestore(this.sessionId, this.selectedNodeId, !canContinue, branchId)
  }

  private async saveName(): Promise<void> {
    if (this.savingName || this.nodeName.trim().length === 0 || this.selectedNode() === undefined) return
    this.savingName = true
    this.nameFailed = false
    const serial = this.requestSerial
    const sessionId = this.sessionId
    const nodeId = this.selectedNodeId
    try {
      await bookmarkNode(getContext(this), sessionId, nodeId, this.nodeName.trim())
      if (serial !== this.requestSerial) return
      const graph = await getSessionGraph(getContext(this), sessionId)
      if (serial !== this.requestSerial) return
      if (graph !== null) {
        this.graph = graph
        // 命名提交期间可浏览别的节点，不将预览强行切回旧选中项。
        if (this.selectedNodeId === nodeId) this.showNameInput = false
        this.refreshRows()
      }
    } catch (_error) {
      if (serial === this.requestSerial && this.selectedNodeId === nodeId) this.nameFailed = true
    } finally {
      if (serial === this.requestSerial) this.savingName = false
    }
  }

  private graphTracksWidth(): number {
    return this.laneCount * JOURNAL_GRAPH_LANE_WIDTH
  }

  private graphContentWidth(): number {
    return Math.max(this.treeWidth, this.graphTracksWidth() + 196)
  }

  /** Path 命令以 px 计量，布局轨道以 vp 计量，必须按当前窗口密度转换。 */
  private pathCommands(entry: JournalGraphRow, selected: boolean): string {
    const commands = entry.strokes.filter((line: JournalGraphStroke): boolean =>
      (line.branchId === this.selectedBranchId) === selected)
      .map((line: JournalGraphStroke): string => line.commands).join(' ')
    return commands.replace(/[0-9]+(?:\.[0-9]+)?/g, (value: string): string =>
      this.getUIContext().vp2px(Number(value)).toString())
  }

  private rowSelected(entry: JournalGraphRow): boolean {
    if (entry.kind === 'route') {
      return entry.branch?.id === this.selectedBranchId && entry.node.id === this.selectedNodeId
    }
    return entry.kind === 'node' && entry.node.id === this.selectedNodeId
  }

  private rowTitle(entry: JournalGraphRow): string {
    if (entry.kind === 'route' && entry.branch !== null) return this.routeLabel(entry.branch)
    return entry.kind === 'group' ? formatStr(this.text('journal_auto_group'), entry.count) : this.nodeTitle(entry.node)
  }

  private rowDetail(entry: JournalGraphRow): string {
    if (entry.kind === 'route') {
      return entry.branch?.id === this.graph?.session.activeBranchId ?
        this.text('journal_route_current') : this.text('journal_route_preview')
    }
    return entry.kind === 'group' ? this.text(entry.expanded ? 'journal_collapse_steps' : 'journal_expand_steps') :
      this.nodeDetail(entry.node)
  }

  /** 连线属于装饰，节点整行才是至少 68vp 的点击与读屏目标。 */
  @Builder
  private GraphTracks(entry: JournalGraphRow) {
    Stack({ alignContent: Alignment.TopStart }) {
      Path()
        .commands(this.pathCommands(entry, false))
        .width(this.graphTracksWidth()).height(JOURNAL_GRAPH_ROW_HEIGHT)
        .fill(Color.Transparent).stroke(this.getPalette().cellBorderBold)
        .strokeWidth(1).opacity(0.5)
      Path()
        .commands(this.pathCommands(entry, true))
        .width(this.graphTracksWidth()).height(JOURNAL_GRAPH_ROW_HEIGHT)
        .fill(Color.Transparent).stroke(this.getPalette().toolbarActive)
        .strokeWidth(1.8)
      if (entry.kind === 'group') {
        Column() {
          Image($r('app.media.paper_arrow_right'))
            .width(14).height(14)
            .fillColor(this.getPalette().subtitleText)
            .rotate({ angle: entry.expanded ? 90 : 0 })
        }
        .width(22).height(26)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.getPalette().pageBg)
        .border({ width: 0.6, color: this.getPalette().cardBorder })
        .borderRadius(3)
        .position({ x: journalLaneCenter(entry.lane) - 11, y: JOURNAL_GRAPH_ROW_HEIGHT / 2 - 13 })
      } else if (entry.kind === 'route') {
        Rect()
          .width(12).height(12).radius(2)
          .fill(this.rowSelected(entry) ? this.getPalette().toolbarActive : this.getPalette().pageBg)
          .stroke(this.getPalette().toolbarActive).strokeWidth(1.3)
          .position({ x: journalLaneCenter(entry.lane) - 6, y: JOURNAL_GRAPH_ROW_HEIGHT / 2 - 6 })
      } else {
        if (entry.node.id === this.graph?.session.headNodeId) {
          Column() {}
            .width(22).height(22).borderRadius(11)
            .backgroundColor(this.getPalette().pageBg)
            .border({ width: 1.2, color: this.getPalette().toolbarActive })
            .position({ x: journalLaneCenter(entry.lane) - 11, y: JOURNAL_GRAPH_ROW_HEIGHT / 2 - 11 })
        }
        Column() {}
          .width(entry.node.manual || entry.node.label.length > 0 ? 13 : 10)
          .height(entry.node.manual || entry.node.label.length > 0 ? 13 : 10)
          .borderRadius(entry.node.manual || entry.node.label.length > 0 ? 6.5 : 5)
          .backgroundColor(this.rowSelected(entry) || entry.node.manual || entry.node.label.length > 0 ?
            this.getPalette().toolbarActive : this.getPalette().pageBg)
          .border({ width: 1.4, color: this.getPalette().toolbarActive })
          .position({ x: journalLaneCenter(entry.lane) - (entry.node.manual || entry.node.label.length > 0 ? 6.5 : 5),
            y: JOURNAL_GRAPH_ROW_HEIGHT / 2 - (entry.node.manual || entry.node.label.length > 0 ? 6.5 : 5) })
      }
    }
    .width(this.graphTracksWidth()).height(JOURNAL_GRAPH_ROW_HEIGHT)
    .accessibilityLevel('no-hide-descendants')
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private TreeRow(entry: JournalGraphRow) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        this.GraphTracks(entry)
        Column({ space: 4 }) {
          Text(this.rowTitle(entry))
            .fontSize(entry.kind === 'route' ? 14 : 15)
            .fontWeight(this.rowSelected(entry) || entry.kind === 'route' ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.getPalette().titleText)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.rowDetail(entry))
            .fontSize(11).lineHeight(15)
            .fontColor(this.getPalette().subtitleText)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
        .padding({ right: 10 })
      }
      .width('100%')
    }
    .id(`journal-graph-${entry.id}`)
    .width('100%').height(JOURNAL_GRAPH_ROW_HEIGHT)
    .padding(0).borderRadius(3)
    .backgroundColor(this.rowSelected(entry) ? this.getPalette().cellHighlight : Color.Transparent)
    .accessibilityText(`${this.rowTitle(entry)}, ${this.rowDetail(entry)}`)
    .accessibilityDescription(this.rowSelected(entry) ? this.text('home_selected') : '')
    .onAppear(() => {
      if (this.focusTreeOnAppear && this.rowSelected(entry)) {
        this.requestFocus(`journal-graph-${entry.id}`)
        this.focusTreeOnAppear = false
      }
    })
    .onClick(() => {
      if (entry.kind === 'group') this.toggleGroup(entry.node.id)
      else if (entry.kind === 'route' && entry.branch !== null) this.selectRoute(entry.branch)
      else this.selectNode(entry.node.id)
    })
  }

  @Builder
  private Tree() {
    Column({ space: 8 }) {
      Text($r('app.string.journal_tree_help'))
        .fontSize(12).lineHeight(18)
        .fontColor(this.getPalette().subtitleText).width('100%')
      if (this.graph?.session.historyImportTruncated) {
        Text($r('app.string.journal_partial_history'))
          .fontSize(12).lineHeight(18).fontColor(this.getPalette().subtitleText).width('100%')
      }
      // 横向容纳全部路线轨道，纵向列表负责大量自动步骤；操作按钮留在滚动区外。
      Scroll() {
        List({ scroller: this.treeScroller }) {
          LazyForEach(this.graphData, (entry: JournalGraphRow) => {
            ListItem() { this.TreeRow(entry) }
          }, (entry: JournalGraphRow) => `${this.graphData.revision}:${entry.id}`)
        }
        .width(this.graphContentWidth()).height('100%')
        .cachedCount(3)
        .scrollBar(BarState.Auto)
        .onAppear(() => {
          const index = this.rows.findIndex((row: JournalGraphRow): boolean => row.kind === 'node' && row.node.id === this.selectedNodeId)
          if (index >= 0) this.treeScroller.scrollToIndex(Math.max(0, index - 2))
        })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
      .width('100%').layoutWeight(1)
    }
    .width('100%').height('100%')
    .onAreaChange((_oldArea: Area, area: Area) => { this.treeWidth = Number(area.width) })
  }

  @Builder
  private Preview() {
    Scroll() {
      Column({ space: 14 }) {
        if (this.bodyWidth < 720 && this.graph?.session.kind !== 'legacy') {
          Button($r('app.string.journal_back_tree'), { type: ButtonType.Normal })
            .id('journal-preview-back')
            .height(44)
            .fontSize(14)
            .fontColor(this.getPalette().toolbarActive)
            .backgroundColor(Color.Transparent)
            .alignSelf(ItemAlign.Start)
            .padding(0)
            .onAppear(() => { this.requestFocus('journal-preview-back') })
            .onClick(() => {
              this.focusTreeOnAppear = true
              this.mobilePreview = false
            })
        }
        Text(this.graph?.session.kind === 'legacy' ? this.text('journal_legacy') :
          (this.selectedNode() ? this.nodeTitle(this.selectedNode()!) : this.text('journal_preview')))
          .fontSize(19).fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().titleText)
          .width('100%')
        Text(this.graph?.session.kind === 'legacy' ? this.text('journal_legacy_note') : this.text('journal_preview_note'))
          .fontSize(13).lineHeight(20)
          .fontColor(this.getPalette().subtitleText)
          .width('100%')
        if (this.isCompact() && this.graph?.session.kind !== 'legacy') {
          Text(this.canContinue() ? this.text(this.atRouteTip() ? 'journal_continue_route_note' : 'journal_continue_note') : this.text('journal_fork_note'))
            .fontSize(12).lineHeight(18).fontColor(this.getPalette().subtitleText).width('100%')
        }
        if (this.previewFailed) {
          Text($r('app.string.journal_load_failed'))
            .fontSize(14).fontColor(this.getPalette().textError).width('100%')
        }
        if (this.preview !== null) {
          JournalBoardPreview({ save: this.preview })
            .width('100%')
            .constraintSize({ maxWidth: 360 })
        }
        if (this.selectedNode() !== undefined) {
          Text(this.text(this.isPractice() ? 'journal_trial_branch' : 'journal_original_branch'))
            .fontSize(13).fontColor(this.getPalette().toolbarActive).width('100%')
          Text(this.nodeMetrics(this.selectedNode()!))
            .fontSize(13).fontColor(this.getPalette().subtitleText)
            .width('100%')
          if (this.showNameInput) {
            TextInput({ text: this.nodeName, placeholder: this.text('journal_name_placeholder') })
              .id('journal-node-name')
              .onAppear(() => { this.requestFocus('journal-node-name') })
              .height(48).fontSize(15).maxLength(40)
              .backgroundColor(this.getPalette().cardBg)
              .fontColor(this.getPalette().titleText)
              .accessibilityText($r('app.string.journal_name_node'))
              .onChange((value: string) => { this.nodeName = value })
            Row({ space: 12 }) {
              Button($r('app.string.journal_name_cancel'), { type: ButtonType.Normal })
                .height(44).layoutWeight(1).fontSize(14)
                .fontColor(this.getPalette().subtitleText)
                .backgroundColor(Color.Transparent)
                .enabled(!this.savingName)
                .onClick(() => { this.showNameInput = false })
              Button($r('app.string.journal_name_save'), { type: ButtonType.Normal })
                .height(44).layoutWeight(1).fontSize(14)
                .fontColor(this.getPalette().primaryText)
                .backgroundColor(this.getPalette().primaryBtn)
                .borderRadius(6)
                .enabled(!this.savingName && this.nodeName.trim().length > 0)
                .onClick(() => { this.saveName() })
            }
            .width('100%')
            if (this.nameFailed) {
              Text($r('app.string.journal_name_failed'))
                .fontSize(13).fontColor(this.getPalette().textError).width('100%')
            }
          } else {
            Button($r('app.string.journal_name_node'), { type: ButtonType.Normal })
              .height(44).width('100%').fontSize(14)
              .fontColor(this.getPalette().toolbarActive)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.nodeName = this.selectedNode()?.label ?? ''
                this.showNameInput = true
              })
          }
        }
      }
      .width('100%')
      .padding({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Auto)
  }

  build() {
    Column({ space: this.isCompact() ? 8 : 12 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.text(this.inGame ? 'journal_title' : 'journal_archive_title'))
            .fontSize(21).fontWeight(FontWeight.Medium)
            .fontColor(this.getPalette().titleText)
          if (this.graph !== null) {
            Text(formatStr(this.text('journal_original_time'), this.formatTime(this.graph.session.scoreElapsedSeconds)))
              .fontSize(12).fontColor(this.getPalette().subtitleText)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button(this.text(this.inGame ? 'journal_close' : 'journal_back_history'), { type: ButtonType.Normal })
          .id('journal-close')
          .height(44).fontSize(14)
          .fontColor(this.getPalette().subtitleText)
          .backgroundColor(Color.Transparent)
          .defaultFocus(true)
          .onClick(() => this.onClose())
      }
      .width('100%')
      if (this.loading) {
        Column() { LoadingProgress().width(40).height(40) }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.failed || this.graph === null) {
        Column({ space: 16 }) {
          Text($r('app.string.journal_load_failed')).fontSize(15).fontColor(this.getPalette().subtitleText)
          Button($r('app.string.journal_reload'), { type: ButtonType.Normal })
            .height(44).fontSize(15).backgroundColor(Color.Transparent).fontColor(this.getPalette().toolbarActive)
            .onClick(() => { this.reload() })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Column() {
          if (this.graph.session.kind === 'legacy') {
            this.Preview()
          } else if (this.bodyWidth >= 720) {
            Row({ space: 28 }) {
              Column() { this.Tree() }.width(Math.max(340, this.bodyWidth * 0.53)).height('100%')
              Column() { this.Preview() }.layoutWeight(1).height('100%')
            }
            .width('100%').height('100%')
          } else if (this.mobilePreview) {
            this.Preview()
          } else {
            this.Tree()
          }
        }
        .width('100%')
        .layoutWeight(1)
        .onAreaChange((_oldArea: Area, area: Area) => { this.bodyWidth = Number(area.width) })
        if (this.graph.session.kind !== 'legacy' && this.selectedNode() !== undefined && this.preview !== null) {
          Column({ space: 8 }) {
            if (!this.isCompact()) {
              Text(this.canContinue() ? this.text(this.atRouteTip() ? 'journal_continue_route_note' : 'journal_continue_note') : this.text('journal_fork_note'))
                .fontSize(12).lineHeight(18).fontColor(this.getPalette().subtitleText).width('100%')
            }
            Button(this.restoreLabel(), { type: ButtonType.Normal })
              .id('journal-restore')
              .height(48).width('100%').fontSize(16)
              .fontColor(this.getPalette().primaryText)
              .backgroundColor(this.getPalette().primaryBtn)
              .borderRadius(6)
              .enabled(!this.savingName)
              .onAppear(() => {
                if (this.mobilePreview && this.bodyWidth >= 720) this.requestFocus('journal-restore')
              })
              .onClick(() => { this.restoreSelection() })
          }
          .width('100%')
          .padding({ top: this.isCompact() ? 8 : 12 })
          .border({ width: { top: 0.5 }, color: this.getPalette().divider })
        }
      }
    }
    .width('100%').height('100%')
    .constraintSize({ maxWidth: 1100 })
    .padding({ top: this.topRectHeight + (this.isCompact() ? 8 : 12), bottom: this.bottomRectHeight + (this.isCompact() ? 8 : 16),
      left: this.leftRectWidth + 20, right: this.rightRectWidth + 20 })
    .backgroundColor(this.getPalette().pageBg)
    .focusable(true)
    .onAreaChange((_oldArea: Area, area: Area) => { this.panelHeight = Number(area.height) })
    .onAppear(() => { this.requestFocus('journal-close') })
    .onKeyEvent((event: KeyEvent) => {
      if (event.type === KeyType.Down && event.keyCode === KeyCode.KEYCODE_ESCAPE) {
        if (this.showNameInput) {
          this.showNameInput = false
          this.requestFocus('journal-close')
        } else if (this.mobilePreview && this.bodyWidth < 720) {
          this.focusTreeOnAppear = true
          this.mobilePreview = false
        } else this.onClose()
        event.stopPropagation()
      }
    })
  }
}
