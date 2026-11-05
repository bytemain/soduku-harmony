'use strict';

// 执行实际 ETS 纯布局，不模拟 ArkUI；原生滚动、焦点和绘制仍须设备验收。
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { performance } = require('node:perf_hooks');
const { getEsbuild } = require('../docs/audit-2026-11-02/algorithm-build.cjs');
const root = path.resolve(__dirname, '..');
const file = path.join(root, 'entry/src/main/ets/utils/JournalGraphLayout.ets');
const source = fs.readFileSync(file, 'utf8');
const moduleObject = { exports: {} };
vm.runInNewContext(getEsbuild().transformSync(source, {
  loader: 'ts', format: 'cjs', target: 'node20',
}).code, { module: moduleObject, exports: moduleObject.exports }, { filename: file });
const { buildJournalGraphLayout: layout, journalGraphRowAt: rowAt } = moduleObject.exports;
const node = (id, parentId, branchId, sequence, extra = {}) => ({
  id, parentId, branchId, sequence, label: '', manual: false, ...extra,
});
const branch = (id, forkNodeId, tipNodeId) => ({ id, forkNodeId, tipNodeId });
const fixture = {
  session: { headNodeId: 'b3' },
  branches: [branch('main', '', 'a8'), branch('trial', 'a3', 'b3'), branch('empty', 'a3', 'a3')],
  nodes: [node('a1', '', 'main', 1), node('a2', 'a1', 'main', 2), node('a3', 'a2', 'main', 3),
    node('a4', 'a3', 'main', 4), node('a5', 'a4', 'main', 5), node('a6', 'a5', 'main', 6),
    node('a7', 'a6', 'main', 7), node('a8', 'a7', 'main', 8), node('b1', 'a3', 'trial', 9),
    node('b2', 'b1', 'trial', 10, { label: 'Try 2 here' }), node('b3', 'b2', 'trial', 11)],
};
const checks = [];
function check(name, body) { body(); checks.push({ name, status: 'passed' }); }
const initial = JSON.stringify(fixture);
const collapsed = layout(fixture, 'b3', []);

check('each route has a stable independent lane and endpoint', () => {
  assert.equal(collapsed.laneCount, 3);
  assert.equal(collapsed.rows.filter(row => row.kind === 'route').length, 3);
  assert.equal(collapsed.rows.find(row => row.id === 'route:empty').lane, 2);
});
check('a shared-tip route remains visible before its first move', () => {
  const forkIndex = collapsed.rows.findIndex(row => row.id === 'a3');
  const fork = rowAt(collapsed, forkIndex);
  for (const id of ['trial', 'empty']) {
    assert(fork.strokes.some(stroke => stroke.branchId === id && stroke.commands.includes(' C ')));
  }
});
check('head, named point, fork point and route tips cannot be collapsed', () => {
  for (const id of ['a3', 'a8', 'b2', 'b3']) {
    assert(collapsed.rows.some(row => row.id === id && row.kind === 'node'));
  }
});
check('continuous automatic moves collapse and expand without losing nodes', () => {
  assert.equal(collapsed.rows.find(row => row.id === 'group:a4').count, 4);
  const expanded = layout(fixture, 'b3', ['a4']);
  for (let index = 4; index <= 7; index++) assert(expanded.rows.some(row => row.id === `a${index}`));
});
check('selecting a hidden step makes that step individually addressable', () => {
  assert(layout(fixture, 'a5', []).rows.some(row => row.id === 'a5' && row.kind === 'node'));
});
check('all edges point forward and have continuous row boundary coordinates', () => {
  for (const edge of collapsed.edges) {
    assert(edge.from < edge.to);
    const end = rowAt(collapsed, edge.to).strokes.find(stroke => stroke.id === `${edge.id}:${edge.to}`);
    assert(end.commands.endsWith(' 34'));
    for (let index = edge.from + 1; index < edge.to; index++) {
      const middle = rowAt(collapsed, index).strokes.find(stroke => stroke.id === `${edge.id}:${index}`);
      const numbers = middle.commands.match(/[0-9]+/g).map(Number);
      assert.equal(numbers[0], numbers[2]);
      assert.equal(numbers[1], 0);
      assert.equal(numbers[3], 68);
    }
  }
});
check('layout and visible-row materialization never mutate the source graph', () => {
  for (let index = 0; index < collapsed.rows.length; index++) rowAt(collapsed, index);
  assert.equal(JSON.stringify(fixture), initial);
  assert(collapsed.rows.every(row => row.strokes.length === 0));
});
check('empty and legacy summaries do not invent restorable nodes', () => {
  const empty = layout({ session: { headNodeId: '' }, branches: [], nodes: [] }, '', []);
  assert.equal(empty.rows.length, 0);
  assert.equal(empty.edges.length, 0);
});

function longFixture(total, routeCount) {
  const graph = { session: { headNodeId: `n${total}` }, branches: [], nodes: [node('n1', '', 'r0', 1)] };
  let sequence = 2;
  for (let route = 0; route < routeCount; route++) {
    const id = `r${route}`;
    const remainingRoutes = routeCount - route;
    const length = Math.ceil((total - sequence + 1) / remainingRoutes);
    let previous = 'n1';
    for (let step = 0; step < length; step++, sequence++) {
      const next = `n${sequence}`;
      graph.nodes.push(node(next, previous, id, sequence));
      previous = next;
    }
    graph.branches.push(branch(id, route === 0 ? '' : 'n1', previous));
  }
  return graph;
}
const benchmarks = [];
for (const routeCount of [1, 80, 300]) {
  const graph = longFixture(3000, routeCount);
  const beforeHeap = process.memoryUsage().heapUsed;
  const start = performance.now();
  const compact = layout(graph, graph.session.headNodeId, []);
  const groups = compact.rows.filter(row => row.kind === 'group').map(row => row.node.id);
  const expanded = layout(graph, graph.session.headNodeId, groups);
  const layoutMs = performance.now() - start;
  check(`3000 steps / ${routeCount} routes: linear retained layout and lazy visible strokes`, () => {
    assert.equal(expanded.rows.filter(row => row.kind === 'node').length, 3000);
    assert.equal(expanded.rows.filter(row => row.kind === 'route').length, routeCount);
    assert(expanded.edges.length <= graph.nodes.length + graph.branches.length);
    assert(expanded.rows.every(row => row.strokes.length === 0));
    assert.equal(new Set(expanded.rows.map(row => row.id)).size, expanded.rows.length);
  });
  const viewportStart = performance.now();
  let maxViewportStrokes = 0;
  for (const offset of [0, Math.floor(expanded.rows.length / 2), expanded.rows.length - 14]) {
    let strokes = 0;
    for (let index = Math.max(0, offset); index < Math.min(expanded.rows.length, offset + 14); index++) {
      strokes += rowAt(expanded, index).strokes.length;
    }
    maxViewportStrokes = Math.max(maxViewportStrokes, strokes);
  }
  benchmarks.push({ steps: 3000, routes: routeCount, collapsedRows: compact.rows.length,
    expandedRows: expanded.rows.length, retainedEdges: expanded.edges.length,
    retainedStrokeObjects: 0, maxViewportRows: 14, maxViewportStrokes,
    layoutMs: Number(layoutMs.toFixed(2)), threeViewportsMs: Number((performance.now() - viewportStart).toFixed(2)),
    approximateHeapDeltaBytes: process.memoryUsage().heapUsed - beforeHeap });
}
check('ArkUI integration uses a lazy list, bounded cache and at most two track shapes per visible row', () => {
  const panel = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/JournalPanel.ets'), 'utf8');
  assert(panel.includes('LazyForEach(this.graphData'));
  assert(panel.includes('.cachedCount(3)'));
  const tracks = panel.slice(panel.indexOf('private GraphTracks('), panel.indexOf('private TreeRow('));
  assert.equal((tracks.match(/Path\(\)/g) || []).length, 2);
  assert(panel.includes('this.getUIContext().vp2px(Number(value))'));
});
check('a written winning checkpoint blocks challenge reactivation even before settlement completes', () => {
  const panel = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/JournalPanel.ets'), 'utf8');
  const method = panel.slice(panel.indexOf('private routeCanContinue()'), panel.indexOf('private atRouteTip()'));
  const context = {};
  vm.createContext(context);
  vm.runInContext(getEsbuild().transformSync(`class Probe { ${method} } globalThis.Probe = Probe;`,
    { loader: 'ts', target: 'node20' }).code, context);
  const probe = new context.Probe();
  probe.graph = { session: { settled: false, completionNodeId: '' } };
  probe.selectedNode = () => ({ outcome: 'active' });
  probe.selectedBranch = () => ({ mode: 'challenge' });
  assert.equal(probe.routeCanContinue(), true);
  probe.graph.session.completionNodeId = 'winning-checkpoint';
  assert.equal(probe.routeCanContinue(), false, 'Do not offer a restore that the repository must reject');
  probe.selectedBranch = () => ({ mode: 'practice' });
  assert.equal(probe.routeCanContinue(), true, 'Existing experiments remain available');
  probe.graph.session.settled = true;
  probe.selectedBranch = () => ({ mode: 'challenge' });
  assert.equal(probe.routeCanContinue(), false);
});
const report = { scope: 'Compiled pure layout + source wiring; no native rendering or gesture claim',
  status: 'passed', passed: checks.length, checks, benchmarks,
  nativeChecksRemaining: ['horizontal and vertical scrolling', 'fold / phone viewport clipping',
    'focus after preview', 'current and named node appearance', 'route switch preserves four-argument restore semantics'] };
const reportArg = process.argv.find(arg => arg.startsWith('--report='));
if (reportArg) fs.writeFileSync(path.resolve(reportArg.slice('--report='.length)), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
