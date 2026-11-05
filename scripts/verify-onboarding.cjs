'use strict';
// Execute compiler-produced lifecycle methods; only device/storage boundaries are substituted.
// This deliberately does not emulate ArkUI rendering, focus, touch dispatch or accessibility.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const adapter = require('../docs/audit-2026-11-02/algorithm-build.cjs');
const compiledRoot = process.argv[2];
assert.ok(compiledRoot, 'Pass the real CompileArkTS esmodule/release/.../ets directory');
let ts;
for (const candidate of [process.env.SUDOKU_AUDIT_TYPESCRIPT, 'typescript',
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript'].filter(Boolean)) {
  try { ts = require(candidate); break; } catch (_) {}
}
assert.ok(ts, 'TypeScript parser unavailable');
const sources = new Map();
function sourceFile(relative) {
  const file = path.join(compiledRoot, relative);
  const source = fs.readFileSync(file, 'utf8');
  sources.set(relative, source);
  return ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
}
function members(ast, names) {
  const found = [];
  function visit(node) {
    if ((ts.isMethodDeclaration(node) || ts.isGetAccessorDeclaration(node)) &&
      names.includes(node.name.getText(ast))) found.push(node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast);
  assert.equal(found.length, names.length, `Missing/ambiguous methods: ${names.join(', ')}`);
  return found.join('\n');
}
const pageAst = sourceFile('pages/GamePage.ts');
const pageMethods = members(pageAst, ['finishInit', 'dismissGestureGuide', 'onBackPress',
  'onPageHide', 'aboutToDisappear', 'togglePause', 'handleKeyboardInput']);
const clockMethods = members(sourceFile('models/GameState.ts'), ['tick', 'formattedTime']);
const guideAst = sourceFile('components/GestureGuideOverlay.ts');
const nextStep = members(guideAst, ['nextStep']);
// Find the actual callback associated with tutorial-skip, without running generated UI code.
let skipCallback;
function findSkip(node) {
  if (ts.isBlock(node) && node.statements.some(statement =>
    ts.isExpressionStatement(statement) && ts.isCallExpression(statement.expression) &&
    statement.expression.expression.getText(guideAst) === 'Button.id' &&
    statement.expression.arguments[0]?.text === 'tutorial-skip')) {
    const statement = node.statements.find(item => ts.isExpressionStatement(item) &&
      ts.isCallExpression(item.expression) && item.expression.expression.getText(guideAst) === 'Button.onClick');
    assert.ok(statement, 'Skip has no compiler-produced click callback');
    skipCallback = statement.expression.arguments[0].getText(guideAst);
  }
  ts.forEachChild(node, findSkip);
}
findSkip(guideAst);
assert.ok(skipCallback, 'tutorial-skip callback not found');
const settingsAst = sourceFile('utils/SettingsStorage.ts');
const settingsCode = settingsAst.statements.filter(node =>
  ts.isVariableStatement(node) || ts.isFunctionDeclaration(node))
  .map(node => node.getText(settingsAst).replace(/^export\s+/, '')).join('\n');
const code = adapter.getEsbuild().transformSync(`${settingsCode}
class PageProbe { ${pageMethods} }
class ClockProbe { ${clockMethods} }
const TUTORIAL_STEPS = 4;
class GuideProbe { ${nextStep} skip() { (${skipCallback})(); } }
globalThis.probes = { PageProbe, ClockProbe, GuideProbe, loadSettings };
`, { loader: 'ts', target: 'node20' }).code;

function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}
function harness(options = {}) {
  const durable = options.durable ?? new Map([['gestureGuideShown', !!options.seen]]);
  const pending = new Map(durable);
  const memory = new Map([['appInForeground', options.foreground ?? true]]);
  const intervals = new Map(), timeouts = new Map(), starts = [];
  const effects = { flushes: 0, backs: 0, toasts: 0, retries: 0, deactivated: 0, saveSnapshots: [] };
  let id = 0, page;
  const store = {
    getSync: (key, fallback) => pending.has(key) ? pending.get(key) : fallback,
    putSync: (key, value) => pending.set(key, value),
    flush: async () => { effects.flushes++; for (const [key, value] of pending) durable.set(key, value); },
  };
  const context = {
    preferences: { getPreferencesSync: () => store },
    hilog: { info() {}, warn() {}, error() {} },
    AppStorage: { get: key => memory.get(key), setOrCreate: (key, value) => memory.set(key, value) },
    getContext: () => ({}), normalizeVariantType: value => value,
    reconcileJournalStats: options.reconcile ?? (async () => {}),
    isGameCompleted: () => !!options.completed,
    promptAction: { showToast: () => { effects.toasts++; } },
    router: { back: () => { effects.backs++; } },
    setInterval: (callback, delay) => {
      starts.push({ guide: page.showGestureGuide, loading: page.isLoading, delay });
      intervals.set(++id, callback); return id;
    },
    clearInterval: timer => intervals.delete(timer),
    setTimeout: (callback, delay) => { timeouts.set(++id, { callback, delay }); return id; },
    clearTimeout: timer => timeouts.delete(timer),
    Context: { animateTo: (_options, callback) => callback() }, Curve: { EaseOut: 1 },
    KeyCode: { KEYCODE_ESCAPE: 27 },
  };
  vm.createContext(context);
  vm.runInContext(code, context);
  context.probes.loadSettings({});
  const clock = new context.probes.ClockProbe();
  Object.assign(clock, { elapsedSeconds: options.elapsed ?? 0, errorCount: 0,
    isPaused: false, isCompleted: false, cells: [{ value: 0, notes: 0 }], selectedIndex: -1 });
  page = new context.probes.PageProbe();
  Object.assign(page, {
    pageAlive: true, sessionRevision: 1, isLoading: true, gameState: clock, timerId: -1,
    showGestureGuide: false, showPauseOverlay: false, showJournal: false, journalCompleting: false,
    journalInitialSave: null, journalPreviousSessionId: '', journalStartedInLegacyStats: false,
    boardScale: 0.92, boardOpacity: 0,
    journal: { initialize: options.initialize ?? (async save => save), deactivate: () => { effects.deactivated++; } },
    createCurrentSave: () => ({ variantType: 'standard' }),
    restoreFromSave: () => { clock.isPaused = false; },
    syncJournalState() {}, refreshValidation() {}, syncSelectionVisuals() {}, updateRemainingCounts() {},
    syncDisplayState() { this.displayTime = clock.formattedTime; }, getActiveCages: () => undefined,
    saveCurrentGame() { if (!this.isLoading && !clock.isCompleted) effects.saveSnapshots.push(JSON.stringify(clock)); },
    saveLibraryProgressIfNeeded() {}, terminateWorker() {}, getString: key => key,
    retryJournalSave: async () => { effects.retries++; },
    closeJournalPanel() { this.showJournal = false; },
  });
  // StorageProp reads the shared preference; no ArkUI property wrapper is needed here.
  Object.defineProperty(page, 'gestureGuideShown', { get: () => memory.get('gestureGuideShown') });
  const guide = new context.probes.GuideProbe();
  Object.assign(guide, { step: 0, onDismiss: () => page.dismissGestureGuide(), enterStep(step) { this.step = step; } });
  return { page, guide, clock, effects, memory, durable, intervals, timeouts, starts,
    pulse(count = 1) { for (let n = 0; n < count; n++) for (const callback of [...intervals.values()]) callback(); },
    animate() { for (const { callback } of timeouts.values()) callback(); timeouts.clear(); } };
}

const cases = [];
async function check(name, body) { await body(); cases.push(name); }
async function main() {
  await check('First ready frame owns input before any timer/animation; guide time is not counted', async () => {
    const h = harness(); await h.page.finishInit();
    assert.equal(h.page.isLoading, false); assert.equal(h.page.showGestureGuide, true);
    assert.deepEqual(h.starts, [{ guide: true, loading: false, delay: 1000 }]);
    assert.equal(h.memory.get('gestureGuideShown'), false);
    const before = JSON.stringify(h.clock.cells);
    h.page.handleKeyboardInput(49); h.pulse(15); h.animate();
    assert.equal(JSON.stringify(h.clock.cells), before); assert.equal(h.clock.elapsedSeconds, 0);
    assert.equal(h.page.showGestureGuide, true); assert.equal(h.effects.flushes, 0);
  });
  await check('Seen user enters play directly and timer starts once', async () => {
    const h = harness({ seen: true }); await h.page.finishInit(); h.pulse(3);
    assert.equal(h.page.showGestureGuide, false); assert.equal(h.clock.elapsedSeconds, 3);
    assert.equal(h.intervals.size, 1); assert.equal(h.effects.flushes, 0);
  });
  for (const action of ['finish', 'skip', 'back', 'escape']) {
    await check(`${action}: actual dismissal persists and cold settings reload suppresses repeat`, async () => {
      const h = harness(); await h.page.finishInit();
      if (action === 'finish') { h.guide.step = 3; h.guide.nextStep(); }
      if (action === 'skip') h.guide.skip();
      if (action === 'back') assert.equal(h.page.onBackPress(), true);
      if (action === 'escape') h.page.handleKeyboardInput(27);
      await Promise.resolve();
      assert.equal(h.page.showGestureGuide, false); assert.equal(h.effects.flushes, 1);
      assert.equal(h.durable.get('gestureGuideShown'), true); assert.equal(h.effects.backs, 0);
      h.pulse(); assert.equal(h.clock.elapsedSeconds, 1);
      const cold = harness({ durable: h.durable }); await cold.page.finishInit();
      assert.equal(cold.page.showGestureGuide, false);
    });
  }
  await check('Intermediate tutorial steps do not dismiss or consume first-use preference', async () => {
    const h = harness(); await h.page.finishInit();
    h.guide.nextStep(); assert.equal(h.guide.step, 1);
    assert.equal(h.page.showGestureGuide, true); assert.equal(h.effects.flushes, 0);
    assert.equal(h.durable.get('gestureGuideShown'), false);
  });
  await check('Journal initialization failure leaves first-use intact and never starts a timer', async () => {
    const h = harness({ initialize: async () => { throw new Error('disk unavailable'); } });
    await h.page.finishInit();
    assert.equal(h.effects.backs, 1); assert.equal(h.effects.toasts, 1);
    assert.equal(h.page.showGestureGuide, false); assert.equal(h.intervals.size, 0);
    assert.equal(h.effects.flushes, 0); assert.equal(h.durable.get('gestureGuideShown'), false);
  });
  await check('Back while loading and late async initialization cannot show or consume onboarding', async () => {
    const pending = deferred(), h = harness({ initialize: () => pending.promise });
    const ready = h.page.finishInit(); assert.equal(h.page.onBackPress(), false);
    h.page.aboutToDisappear(); pending.resolve({ variantType: 'standard' }); await ready; h.animate();
    assert.equal(h.page.showGestureGuide, false); assert.equal(h.intervals.size, 0);
    assert.equal(h.effects.deactivated, 1); assert.equal(h.effects.flushes, 0);
  });
  await check('Session changed during async stats projection rejects stale readiness', async () => {
    const pending = deferred(), h = harness({ reconcile: () => pending.promise });
    const ready = h.page.finishInit(true); h.page.sessionRevision++; pending.resolve(); await ready;
    assert.equal(h.page.showGestureGuide, false); assert.equal(h.intervals.size, 0);
    assert.equal(h.effects.flushes, 0);
  });
  await check('Recoverable stats failure does not suppress first onboarding', async () => {
    const h = harness({ reconcile: async () => { throw new Error('projection deferred'); } });
    await h.page.finishInit(); assert.equal(h.page.showGestureGuide, true); assert.equal(h.effects.backs, 0);
  });
  await check('Already completed recovery settles without starting timer or consuming onboarding', async () => {
    const h = harness({ completed: true }); await h.page.finishInit();
    assert.equal(h.clock.isCompleted, true); assert.equal(h.effects.retries, 1);
    assert.equal(h.page.showGestureGuide, false); assert.equal(h.intervals.size, 0);
    assert.equal(h.effects.flushes, 0);
  });
  await check('Seen user finishing generation in background remains paused after foreground return', async () => {
    const pending = deferred(), h = harness({ seen: true, initialize: () => pending.promise });
    const ready = h.page.finishInit(); h.memory.set('appInForeground', false); h.page.onPageHide();
    pending.resolve({ variantType: 'standard' }); await ready; h.pulse(5);
    assert.equal(h.page.showGestureGuide, false); assert.equal(h.page.showPauseOverlay, true);
    assert.equal(h.clock.isPaused, true); assert.equal(h.clock.elapsedSeconds, 0);
    h.memory.set('appInForeground', true); h.pulse(5); assert.equal(h.clock.elapsedSeconds, 0);
    h.page.togglePause(); h.pulse(); assert.equal(h.clock.elapsedSeconds, 1);
  });
  await check('Foreground flag blocks clock even before page-hide callback arrives', async () => {
    const h = harness({ seen: true }); await h.page.finishInit();
    h.memory.set('appInForeground', false); h.pulse(5); assert.equal(h.clock.elapsedSeconds, 0);
  });
  await check('Background during first guide returns to pause; dismiss does not silently resume', async () => {
    const h = harness(); await h.page.finishInit();
    h.memory.set('appInForeground', false); h.page.onPageHide(); h.pulse(5);
    h.memory.set('appInForeground', true); h.guide.skip(); h.pulse(5);
    assert.equal(h.page.showPauseOverlay, true); assert.equal(h.clock.isPaused, true);
    assert.equal(h.clock.elapsedSeconds, 0); assert.equal(h.durable.get('gestureGuideShown'), true);
    h.page.togglePause(); h.pulse(); assert.equal(h.clock.elapsedSeconds, 1);
  });
  await check('Manual help dismiss returns to pause without changing board, clock or selection', async () => {
    const h = harness({ seen: true, elapsed: 19 }); await h.page.finishInit();
    h.page.togglePause(); h.page.showGestureGuide = true;
    const before = JSON.stringify(h.clock);
    h.pulse(8); h.page.onBackPress(); h.pulse(8);
    assert.equal(JSON.stringify(h.clock), before); assert.equal(h.page.showPauseOverlay, true);
    assert.equal(h.page.showGestureGuide, false);
  });
  await check('Leaving an undismissed guide clears timer but preserves first-use opportunity', async () => {
    const h = harness(); await h.page.finishInit(); h.page.aboutToDisappear(); h.animate(); h.pulse(5);
    assert.equal(h.intervals.size, 0); assert.equal(h.clock.elapsedSeconds, 0);
    assert.equal(h.effects.flushes, 0); assert.equal(h.durable.get('gestureGuideShown'), false);
    const cold = harness({ durable: h.durable }); await cold.page.finishInit();
    assert.equal(cold.page.showGestureGuide, true);
  });
  const report = {
    passed: cases.length, cases, compiledRoot: path.resolve(compiledRoot),
    compiledSourceSha256: Object.fromEntries([...sources].map(([file, source]) =>
      [file, crypto.createHash('sha256').update(source).digest('hex')])),
    method: 'Executed real CompileArkTS lifecycle, tutorial completion/skip callback, GameState clock and SettingsStorage load/save; in-memory preferences and deterministic timers at OS boundaries.',
    limitations: [
      'No ArkUI rendering, focus, touch dispatch, accessibility or device Preferences durability is simulated.',
      'Puzzle worker failure routing is not executed; failed readiness and stale asynchronous completion are covered.',
      'Journal and stats are boundary stubs; their persistence and algorithm behavior have separate regression suites.',
    ],
  };
  console.log(JSON.stringify(report, null, 2));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
