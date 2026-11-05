'use strict';

// Execute the original ETS model/repository with Node SQLite as the RDB adapter.
// This verifies domain rules and real SQL transactions, not HarmonyOS RDB or ArkUI.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { DatabaseSync } = require('node:sqlite');
const { getEsbuild } = require('../docs/audit-2026-11-02/algorithm-build.cjs');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const database = new DatabaseSync(':memory:');
const preferences = new Map();
let failNextNode = false;
let failNextStatsFlush = false;
let statements = 0;

class ResultSet {
  constructor(rows, names) { this.rows = rows; this.names = names; this.index = -1; }
  goToNextRow() { return ++this.index < this.rows.length; }
  getColumnIndex(name) { return this.names.indexOf(name); }
  getString(index) { return String(this.rows[this.index][this.names[index]]); }
  isColumnNull(index) { return this.rows[this.index][this.names[index]] == null; }
  close() {}
}
const rdb = {
  async executeSql(sql, args = []) {
    statements++;
    if (failNextNode && sql.startsWith('INSERT INTO journal_nodes')) {
      failNextNode = false;
      throw new Error('injected disk failure');
    }
    database.prepare(sql).run(...args);
  },
  async querySql(sql, args = []) {
    statements++;
    const prepared = database.prepare(sql);
    return new ResultSet(prepared.all(...args), prepared.columns().map(column => column.name));
  },
  beginTransaction() { database.exec('BEGIN'); },
  commit() { database.exec('COMMIT'); },
  rollBack() { database.exec('ROLLBACK'); },
};
const kit = {
  relationalStore: { SecurityLevel: { S1: 1 }, getRdbStore: async () => rdb },
  preferences: { getPreferencesSync(_context, options) {
    if (!preferences.has(options.name)) preferences.set(options.name, new Map());
    const store = preferences.get(options.name);
    return { getSync: (key, fallback) => store.get(key) ?? fallback,
      putSync: (key, value) => store.set(key, value), flush: async () => {
        if (options.name === 'sudoku_stats' && failNextStatsFlush) {
          failNextStatsFlush = false;
          throw new Error('injected statistics flush failure');
        }
      } };
  } },
};
const cache = new Map();
function load(relative) {
  const file = path.resolve(root, relative.endsWith('.ets') ? relative : `${relative}.ets`);
  if (cache.has(file)) return cache.get(file).exports;
  const module = { exports: {} };
  cache.set(file, module);
  const code = getEsbuild().transformSync(fs.readFileSync(file, 'utf8'), {
    loader: 'ts', format: 'cjs', target: 'node20',
    tsconfigRaw: { compilerOptions: { experimentalDecorators: true } },
  }).code;
  const context = {
    module, exports: module.exports, console, Observed: value => value,
    require(name) {
      if (name === '@kit.ArkData') return kit;
      if (name.startsWith('@kit.')) return {};
      return load(path.relative(root, path.resolve(path.dirname(file), name)));
    },
  };
  vm.runInNewContext(code, context, { filename: file });
  return module.exports;
}
const model = load('models/GameJournal');
const storage = load('utils/JournalStorage');
const { GameSaveData, CellSerialized } = load('models/GameSaveData');
const { CellSnapshot } = load('models/GameHistory');
const statsApi = load('utils/StatsStorage');
const copy = value => JSON.parse(JSON.stringify(value));
function save4() {
  const save = new GameSaveData();
  save.gridSize = 4;
  save.difficulty = 1;
  save.solution = [1, 2, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1];
  save.cells = save.solution.map((digit, index) => new CellSerialized(Math.floor(index / 4), index % 4,
    [1, 2, 3, 5].includes(index) ? digit : 0, [1, 2, 3, 5].includes(index) ? 1 : 0, 0));
  save.cells[8].notes = 1;
  return save;
}
const tests = [];
async function check(name, callback) { await callback(); tests.push(name); }

(async () => {
  const baseline = new statsApi.GameStats();
  baseline.totalGamesPlayed = 10; baseline.totalGamesWon = 4;
  Object.assign(baseline.difficulties[1], { gamesPlayed: 10, gamesWon: 4, totalTimeSeconds: 400,
    totalErrors: 6, currentStreak: 1, bestStreak: 3, bestTimeSeconds: 80 });
  const baselineJson = JSON.stringify(baseline);
  preferences.set('sudoku_stats', new Map([['game_stats', baselineJson]]));
  const legacy = { timestamp: 20, won: true, difficulty: 1, timeSeconds: 50, errors: 0,
    stepCount: 4, seed: 7, symmetry: 'none', replaySave: save4(), steps: [[{ index: 0 }]] };
  preferences.set('sudoku_history', new Map([['game_records', JSON.stringify([legacy])]]));
  await check('legacy migration preserves only actual summary/material and is idempotent', async () => {
    await storage.openJournalStore({});
    await storage.openJournalStore({});
    const sessions = await storage.listSessions({});
    assert.equal(sessions.length, 1);
    assert.equal(sessions[0].legacyOnly, true);
    assert.ok(sessions[0].legacyReplaySave);
    assert.equal((await storage.getSessionGraph({}, sessions[0].id)).nodes.length, 0);
    assert.deepEqual(JSON.parse(database.prepare('SELECT legacy_payload FROM journal_sessions').get().legacy_payload), copy(legacy));
  });

  let start, first, second, fork, source;
  await check('session ID is idempotent, givens and solution cannot be replaced', async () => {
    source = save4();
    start = await storage.startSession({}, source, { sessionId: 'main', mode: 'auto' });
    const again = await storage.startSession({}, source, { sessionId: 'main' });
    assert.equal(start.node.id, again.node.id);
    const different = copy(source); different.cells[0].flags = 1; different.cells[0].value = 1;
    await assert.rejects(storage.startSession({}, different, { sessionId: 'main' }), /givens/);
  });

  await check('queued snapshots are immutable and atomic peer cleanup remains one undo batch', async () => {
    const a = copy(source); a.cells[0].value = 1; a.cells[8].notes = 0; a.elapsedSeconds = 5;
    const b = copy(a); b.cells[4].value = 3; b.elapsedSeconds = 8;
    const pendingA = storage.appendAction({}, 'main', a, 'fill');
    a.cells[0].value = 4;
    const pendingB = storage.appendAction({}, 'main', b, 'fill');
    [first, second] = await Promise.all([pendingA, pendingB]);
    const graph = await storage.getSessionGraph({}, 'main');
    assert.equal(graph.nodes.length, 3);
    assert.equal(first.node.values[0], 1);
    assert.equal(second.node.parentId, first.node.id);
    const save = storage.toGameSave(graph);
    assert.equal(save.undoStack.length, 2);
    assert.deepEqual(copy(save.undoStack[0].map(item => item.index)), [0, 8]);
    assert.equal(save.undoStack[0][1].oldNotes, 1);
    assert.equal(save.undoStack[0][1].newNotes, 0);
  });

  await check('undo keeps old tip and monotone errors/time; new input retains old route', async () => {
    await storage.updateClock({}, 'main', 20, 2, false);
    await storage.moveCursor({}, 'main', first.node.id);
    let graph = await storage.getSessionGraph({}, 'main');
    let save = storage.toGameSave(graph);
    assert.equal(save.elapsedSeconds, 20);
    assert.equal(save.errorCount, 2);
    assert.equal(save.redoStack.length, 1);
    save.cells[6].value = 1; save.elapsedSeconds = 21;
    fork = await storage.appendAction({}, 'main', save, 'fill');
    graph = await storage.getSessionGraph({}, 'main');
    assert.equal(graph.branches.length, 2);
    assert.equal(graph.nodes.length, 4);
    assert.ok(graph.branches.some(branch => branch.tipNodeId === second.node.id));
    assert.equal(fork.node.parentId, first.node.id);
    assert.equal(graph.session.scoreErrorCount, 2);
    await assert.rejects(storage.moveCursor({}, 'main', second.node.id), /outside/);
  });

  await check('bookmarks never modify immutable node data', async () => {
    const before = database.prepare('SELECT payload FROM journal_nodes WHERE id = ?').get(first.node.id).payload;
    await storage.bookmarkNode({}, 'main', first.node.id, 'First idea');
    const graph = await storage.getSessionGraph({}, 'main');
    assert.equal(graph.nodes.find(node => node.id === first.node.id).label, 'First idea');
    assert.equal(database.prepare('SELECT payload FROM journal_nodes WHERE id = ?').get(first.node.id).payload, before);
  });

  await check('failed node write rolls back head, tip and metrics; later writes still work', async () => {
    const before = await storage.getSessionGraph({}, 'main');
    const save = storage.toGameSave(before); save.cells[7].value = 2; save.elapsedSeconds = 40;
    failNextNode = true;
    await assert.rejects(storage.appendAction({}, 'main', save, 'fill'), /injected disk failure/);
    const after = await storage.getSessionGraph({}, 'main');
    assert.deepEqual(copy(after), copy(before));
    await storage.appendAction({}, 'main', save, 'fill');
  });

  await check('practice fork cannot change challenge ledger or claim settlement', async () => {
    const before = await storage.getSessionGraph({}, 'main');
    await storage.forkFromNode({}, 'main', first.node.id, 'Try another route');
    let graph = await storage.getSessionGraph({}, 'main');
    assert.equal(model.journalActiveBranch(graph).mode, 'practice');
    const trial = storage.toGameSave(graph);
    trial.cells.forEach((cell, index) => { cell.value = trial.solution[index]; cell.notes = 0; });
    trial.elapsedSeconds = 100; trial.errorCount = 5; trial.isChallengeFailed = true;
    await storage.appendAction({}, 'main', trial, 'fill');
    assert.equal(await storage.claimSettlement({}, 'main', 'completed_failed'), false);
    graph = await storage.getSessionGraph({}, 'main');
    assert.equal(graph.session.scoreElapsedSeconds, before.session.scoreElapsedSeconds);
    assert.equal(graph.session.scoreErrorCount, before.session.scoreErrorCount);
    assert.equal(graph.session.outcome, before.session.outcome);
  });

  await check('practice returns to original challenge without deleting tips, starting or settling again', async () => {
    const before = await storage.getSessionGraph({}, 'main');
    const trialBranch = model.journalActiveBranch(before);
    const challenge = before.branches.find(branch => branch.id === fork.branch.id);
    const returned = await storage.activateBranch({}, 'main', challenge.id);
    assert.equal(returned.node.id, challenge.tipNodeId);
    assert.equal(returned.branch.mode, 'challenge');
    assert.equal(returned.branch.elapsedSeconds, before.session.scoreElapsedSeconds);
    assert.equal(returned.branch.errorCount, before.session.scoreErrorCount);
    let graph = await storage.getSessionGraph({}, 'main');
    assert.equal(graph.nodes.length, before.nodes.length);
    assert.equal(graph.branches.length, before.branches.length);
    assert.equal(graph.session.createdAt, before.session.createdAt);
    assert.equal(graph.session.settled, false);
    assert.equal(graph.branches.find(branch => branch.id === trialBranch.id).tipNodeId, trialBranch.tipNodeId);
    const save = storage.toGameSave(graph); save.cells[8].value = 2; save.elapsedSeconds += 1;
    const continued = await storage.appendAction({}, 'main', save, 'fill');
    assert.equal(continued.branch.id, challenge.id);
    assert.equal(continued.node.parentId, challenge.tipNodeId);
    assert.equal(continued.session.scoreErrorCount, 2);
    await storage.activateBranch({}, 'main', trialBranch.id);
    graph = await storage.getSessionGraph({}, 'main');
    assert.equal(graph.session.headNodeId, trialBranch.tipNodeId);
    assert.equal(graph.branches.find(branch => branch.id === challenge.id).tipNodeId, continued.node.id);
    const stable = copy(graph);
    await assert.rejects(storage.activateBranch({}, 'main', 'missing-branch'), /not found/);
    assert.deepEqual(copy(await storage.getSessionGraph({}, 'main')), stable);
  });

  await check('settlement is one claim per completed challenge and blocks later mutation', async () => {
    await storage.startSession({}, save4(), { sessionId: 'finish' });
    const completed = save4(); completed.cells.forEach((cell, index) => { cell.value = completed.solution[index]; cell.notes = 0; });
    completed.elapsedSeconds = 60;
    await storage.appendAction({}, 'finish', completed, 'fill');
    assert.equal(await storage.claimSettlement({}, 'finish', 'won'), true);
    assert.equal(await storage.claimSettlement({}, 'finish', 'won'), false);
    await assert.rejects(storage.appendAction({}, 'finish', completed, 'checkpoint'), /practice/);
    const finished = await storage.getSessionGraph({}, 'finish');
    await assert.rejects(storage.activateBranch({}, 'finish', finished.session.activeBranchId), /cannot be activated/);
  });

  await check('existing undo/redo batches import without losing history or inventing timestamps', async () => {
    const saved = save4(); saved.cells[0].value = 1; saved.cells[8].notes = 0;
    saved.elapsedSeconds = 35;
    saved.undoStack = [[new CellSnapshot(0, 0, 1, 0, 0), new CellSnapshot(8, 0, 0, 1, 0)]];
    saved.redoStack = [[new CellSnapshot(4, 0, 3, 0, 0)]];
    const created = await storage.startSession({}, saved, { sessionId: 'imported' });
    const graph = await storage.getSessionGraph({}, 'imported');
    assert.equal(graph.nodes.length, 3);
    assert.equal(graph.session.headNodeId, graph.nodes[1].id);
    assert.equal(graph.nodes[0].createdAt, 0);
    assert.equal(graph.nodes[0].timingKnown, false);
    assert.equal(created.branch.tipNodeId, graph.nodes[2].id);
    const restored = storage.toGameSave(graph);
    assert.equal(restored.undoStack.length, 1);
    assert.equal(restored.redoStack.length, 1);
    assert.equal(restored.elapsedSeconds, 35);
    saved.undoStack[0][0].index = 500;
    const partial = await storage.startSession({}, saved, { sessionId: 'damaged' });
    assert.equal(partial.session.historyImportTruncated, true);
    assert.equal((await storage.getSessionGraph({}, 'damaged')).nodes.length, 2);
  });

  await check('no-op updates clocks without nodes, explicit checkpoints preserve an immutable point', async () => {
    const before = await storage.getSessionGraph({}, 'main');
    const save = storage.toGameSave(before); save.elapsedSeconds += 5;
    const unchanged = await storage.appendAction({}, 'main', save, 'fill');
    assert.equal(unchanged.session.nodeCount, before.nodes.length);
    const checkpoint = await storage.appendAction({}, 'main', save, 'checkpoint');
    assert.equal(checkpoint.session.nodeCount, before.nodes.length + 1);
    assert.equal(checkpoint.node.manual, true);
    const stored = JSON.parse(database.prepare('SELECT payload FROM journal_nodes WHERE id = ?').get(checkpoint.node.id).payload);
    assert.equal(stored.solution, undefined);
    assert.equal(stored.undoStack, undefined);
    assert.equal(stored.killerCages, undefined);
    assert.equal((await storage.getSessionState({}, 'main')).node.id, checkpoint.node.id);
  });

  await check('six-by-six reconstruction is independent of global grid size', async () => {
    const save = new GameSaveData(); save.gridSize = 6; save.difficulty = 2;
    save.solution = Array.from({ length: 36 }, (_, index) => {
      const row = Math.floor(index / 6), column = index % 6;
      return (row * 3 + Math.floor(row / 2) + column) % 6 + 1;
    });
    save.cells = save.solution.map((digit, index) => new CellSerialized(Math.floor(index / 6), index % 6,
      index === 0 ? digit : 0, index === 0 ? 1 : 0, 0));
    await storage.startSession({}, save, { sessionId: 'six' });
    save.cells[35].notes = 1 << 10;
    await storage.appendAction({}, 'six', save, 'note');
    const reconstructed = storage.toGameSave(await storage.getSessionGraph({}, 'six'));
    assert.equal(reconstructed.cells.length, 36);
    assert.equal(reconstructed.cells[35].notes, 1 << 10);
    assert.equal(reconstructed.journalSessionId, 'six');
    assert.equal(reconstructed.undoStack[0][0].index, 35);
  });

  await check('all local sessions remain available beyond former 50-row limit', async () => {
    for (let index = 0; index < 60; index++) await storage.startSession({}, save4(), { sessionId: `page-${index}` });
    const firstPage = await storage.listSessions({}, 30, 0);
    const secondPage = await storage.listSessions({}, 30, 30);
    const thirdPage = await storage.listSessions({}, 30, 60);
    assert.equal(firstPage.length, 30);
    assert.equal(secondPage.length, 30);
    assert.equal(thirdPage.length, 6);
    assert.equal(new Set([...firstPage, ...secondPage, ...thirdPage].map(session => session.id)).size, 66);
  });

  await check('statistics replay uses event chronology, includes historical loss, and ignores new error limits', async () => {
    const snapshot = new model.JournalStatsSnapshot(); snapshot.legacyJson = baselineJson;
    function fact(id, createdAt, settledAt, outcome, errorLimit, errors) {
      const value = new model.JournalStatsFact();
      Object.assign(value, { id, difficulty: 1, createdAt, settled: true, settledAt, outcome,
        errorLimit, errorCount: errors, elapsedSeconds: 50 });
      return value;
    }
    const earlyWin = fact('earlier-win', 10, 100, 'won', 0, 7);
    const oldLoss = fact('old-policy-loss', 20, 250, 'completed_failed', 3, 3);
    oldLoss.challengeFailedAt = 200;
    const laterWin = fact('later-win', 30, 300, 'won', 0, 9);
    snapshot.facts = [laterWin, oldLoss, earlyWin];
    const projected = statsApi.projectJournalStats(snapshot);
    assert.equal(projected.totalGamesPlayed, 13);
    assert.equal(projected.totalGamesWon, 6);
    assert.equal(projected.difficulties[1].currentStreak, 1);
    assert.equal(projected.difficulties[1].bestStreak, 3);
    assert.equal(projected.difficulties[1].totalErrors, 22);
    snapshot.facts.reverse();
    assert.deepEqual(copy(statsApi.projectJournalStats(snapshot)), copy(projected));
  });

  await check('crash before claim and failed stats flush recover without touching practice or duplicating totals', async () => {
    await statsApi.reconcileJournalStats({});
    const beforeJson = preferences.get('sudoku_stats').get('game_stats');
    const before = JSON.parse(beforeJson);
    const origin = await storage.startSession({}, save4(), { sessionId: 'crash-before-claim' });
    const finished = save4(); finished.cells.forEach((cell, index) => { cell.value = finished.solution[index]; cell.notes = 0; });
    finished.elapsedSeconds = 70; finished.errorCount = 8; finished.isChallengeFailed = true;
    const completed = await storage.appendAction({}, 'crash-before-claim', finished, 'fill');
    assert.equal(completed.node.outcome, 'won');
    assert.equal(completed.session.scoreChallengeFailed, false);
    assert.equal(completed.session.settled, false);
    const practice = await storage.forkFromNode({}, 'crash-before-claim', origin.node.id);
    failNextStatsFlush = true;
    await assert.rejects(statsApi.reconcileJournalStats({}), /statistics flush failure/);
    const recovered = await storage.getSessionGraph({}, 'crash-before-claim');
    assert.equal(recovered.session.settled, true);
    assert.equal(recovered.session.outcome, 'won');
    assert.equal(recovered.session.headNodeId, practice.node.id);
    assert.equal(recovered.session.activeBranchId, practice.branch.id);
    // Simulate process loss of an unflushed Preferences value; RDB already holds the settlement.
    preferences.set('sudoku_stats', new Map([['game_stats', beforeJson]]));
    await statsApi.reconcileJournalStats({});
    const once = statsApi.loadStats({});
    assert.equal(once.totalGamesPlayed, before.totalGamesPlayed + 1);
    assert.equal(once.totalGamesWon, before.totalGamesWon + 1);
    assert.equal(once.difficulties[1].totalErrors, before.difficulties[1].totalErrors + 8);
    await statsApi.reconcileJournalStats({});
    assert.deepEqual(copy(statsApi.loadStats({})), copy(once));
    assert.equal(database.prepare('SELECT value FROM journal_meta WHERE key = ?').get('legacy_stats_baseline_v1').value, baselineJson);
  });

  await check('legacy unfinished resume does not double-count start or retain the retired three-error rule', async () => {
    const before = copy(statsApi.loadStats({}));
    const oldSave = save4(); oldSave.elapsedSeconds = 100; oldSave.errorCount = 4; oldSave.isChallengeFailed = true;
    const resumed = await storage.startSession({}, oldSave, { sessionId: 'legacy-resume', startedInLegacyStats: true });
    assert.equal(resumed.session.startedInLegacyStats, true);
    assert.equal(resumed.session.scoreChallengeFailed, false);
    assert.equal(resumed.session.challengeFailedAt, 0);
    await statsApi.reconcileJournalStats({});
    assert.equal(statsApi.loadStats({}).totalGamesPlayed, before.totalGamesPlayed);
    const done = copy(oldSave); done.cells.forEach((cell, index) => { cell.value = done.solution[index]; cell.notes = 0; });
    await storage.appendAction({}, 'legacy-resume', done, 'fill');
    await statsApi.reconcileJournalStats({});
    const after = statsApi.loadStats({});
    assert.equal(after.totalGamesPlayed, before.totalGamesPlayed);
    assert.equal(after.totalGamesWon, before.totalGamesWon + 1);
  });

  await check('alternative valid solution completes and crash settlement never rewrites the reference answer', async () => {
    const source = save4();
    const originalSolution = copy(source.solution);
    const other = [1, 2, 3, 4, 3, 4, 1, 2, 4, 3, 2, 1, 2, 1, 4, 3];
    assert.notDeepEqual(other, originalSolution);
    assert.equal(model.isJournalBoardComplete(source, other), true);
    await storage.startSession({}, source, { sessionId: 'alternative-solution' });
    const solved = copy(source);
    solved.cells.forEach((cell, index) => { cell.value = other[index]; cell.notes = 0; });
    const terminal = await storage.appendAction({}, 'alternative-solution', solved, 'fill');
    assert.equal(terminal.node.outcome, 'won');
    await statsApi.reconcileJournalStats({});
    const graph = await storage.getSessionGraph({}, 'alternative-solution');
    assert.equal(graph.session.settled, true);
    assert.equal(graph.session.outcome, 'won');
    assert.deepEqual(copy(graph.session.puzzle.solution), originalSolution);
    assert.deepEqual(copy(storage.toGameSave(graph).cells.map(cell => cell.value)), other);
    assert.deepEqual(copy(source.solution), originalSolution);
  });

  await check('conflicting filled board and changed givens cannot claim a win', async () => {
    const source = save4();
    const clash = copy(source.solution); clash[0] = 2;
    assert.equal(model.isJournalBoardComplete(source, clash), false);
    const givenChange = [2, 1, 3, 4, 3, 4, 2, 1, 1, 2, 4, 3, 4, 3, 1, 2];
    assert.equal(model.isJournalBoardComplete(source, givenChange), false);
    await storage.startSession({}, source, { sessionId: 'invalid-completion' });
    const invalid = copy(source);
    invalid.cells.forEach((cell, index) => { cell.value = clash[index]; cell.notes = 0; });
    const nonterminal = await storage.appendAction({}, 'invalid-completion', invalid, 'fill');
    assert.equal(nonterminal.node.outcome, 'active');
    await assert.rejects(storage.claimSettlement({}, 'invalid-completion', 'won'), /does not match/);
    invalid.cells.forEach((cell, index) => { cell.value = givenChange[index]; });
    await assert.rejects(storage.appendAction({}, 'invalid-completion', invalid, 'fill'), /Invalid journal save|givens/);
    assert.equal((await storage.getSessionGraph({}, 'invalid-completion')).session.settled, false);
  });

  console.log(JSON.stringify({ passed: tests.length, tests, sqlStatements: statements,
    limitation: 'Node SQLite adapter and original ETS business code; native RDB/ArkUI still requires device verification.' }, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });
