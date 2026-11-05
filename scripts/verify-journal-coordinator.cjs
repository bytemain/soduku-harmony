'use strict';

// Execute the original ETS coordinator and repository with a Node SQLite RDB adapter.
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
let statements = 0;
let fullGraphReads = 0;
let failStateAfterClaim = false;
let failStateRead = false;
let repository;

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
    if (sql.includes('ORDER BY n.ordinal ASC')) fullGraphReads++;
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
      putSync: (key, value) => store.set(key, value), flush: async () => {} };
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
      if (file.endsWith('GameJournalCoordinator.ets') && name === '../utils/JournalStorage') {
        return { ...repository,
          getSessionState: async (...args) => {
            if (failStateRead) { failStateRead = false; throw new Error('injected refresh failure'); }
            return repository.getSessionState(...args);
          },
          claimSettlement: async (...args) => {
            const result = await repository.claimSettlement(...args);
            if (failStateAfterClaim) { failStateAfterClaim = false; failStateRead = true; }
            return result;
          },
        };
      }
      return load(path.relative(root, path.resolve(path.dirname(file), name)));
    },
  };
  vm.runInNewContext(code, context, { filename: file });
  return module.exports;
}
const model = load('models/GameJournal');
repository = load('utils/JournalStorage');
const { GameJournalCoordinator } = load('services/GameJournalCoordinator');
const { GameSaveData, CellSerialized } = load('models/GameSaveData');
const { CellSnapshot } = load('models/GameHistory');
const copy = value => JSON.parse(JSON.stringify(value));
function save4() {
  const save = new GameSaveData();
  save.gridSize = 4; save.difficulty = 1;
  save.solution = [1,2,3,4,3,4,1,2,2,1,4,3,4,3,2,1];
  save.cells = save.solution.map((digit,index) => new CellSerialized(Math.floor(index/4),index%4,
    [1,2,3,5].includes(index) ? digit : 0,[1,2,3,5].includes(index) ? 1 : 0,0));
  save.cells[8].notes=1;
  return save;
}
function position(save) { return save.cells.map(cell=>[cell.value,cell.notes]); }
function current(coordinator) { return coordinator.stampSave(model.toGameSave(coordinator.getGraph())); }
const tests=[];
async function check(name,run) { await run(); tests.push(name); }

(async()=>{
  let c=new GameJournalCoordinator({}), source, a, b, firstId, secondId, challengeBranch;
  await check('stampSave before initialization is safe and never aliases input',async()=>{
    const original=save4(), stamped=c.stampSave(original);
    stamped.cells[0].value=4;
    assert.equal(original.cells[0].value,0);
    assert.equal(stamped.journalSessionId,'');
  });
  await check('initialize imports existing atomic undo/redo and previous-session link',async()=>{
    const migrated=save4(); migrated.cells[0].value=1; migrated.cells[8].notes=0;
    migrated.undoStack=[[new CellSnapshot(0,0,1,0,0),new CellSnapshot(8,0,0,1,0)]];
    migrated.redoStack=[[new CellSnapshot(4,0,3,0,0)]];
    const restored=await c.initialize(migrated,'previous-game');
    assert.equal(c.getGraph().nodes.length,3);
    assert.equal(restored.undoStack[0].length,2);
    assert.equal(restored.redoStack.length,1);
    assert.equal(c.getState().session.previousSessionId,'previous-game');
    assert.equal(restored.journalNodeId,c.getState().node.id);
    assert.equal(restored.journalBranchId,c.getState().branch.id);
    c=new GameJournalCoordinator({}); source=await c.initialize(save4());
  });
  await check('rapid mutable inputs snapshot immediately; callback only latest; no whole-tree reread',async()=>{
    const callbacks=[]; c.onPersisted=save=>callbacks.push(copy(save));
    const reads=fullGraphReads;
    a=copy(source); a.cells[0].value=1; a.cells[8].notes=0; a.elapsedSeconds=5;
    b=copy(a); b.cells[4].value=3; b.elapsedSeconds=8;
    const pa=c.record(a,'fill'); a.cells[0].value=4;
    const pb=c.record(b,'fill'); b.cells[4].value=1;
    await Promise.all([pa,pb]);
    assert.equal(fullGraphReads,reads);
    const graph=c.getGraph(); assert.equal(graph.nodes.length,3);
    firstId=graph.nodes[1].id; secondId=graph.nodes[2].id; challengeBranch=c.getState().branch.id;
    assert.equal(graph.nodes[1].values[0],1); assert.equal(graph.nodes[1].notes[8],0);
    assert.equal(graph.nodes[2].values[4],3); assert.equal(graph.nodes[2].parentId,firstId);
    assert.equal(callbacks.length,1); assert.equal(callbacks[0].cells[4].value,3);
    assert.equal(callbacks[0].journalNodeId,secondId);
    callbacks[0].cells[0].value=4; assert.equal(c.getState().node.values[0],1);
  });
  await check('undo/redo moves cursor, retains tip and ignores selection/flags',async()=>{
    c.onPersisted=undefined;
    const undo=model.toGameSave(c.getGraph(),firstId,false); undo.elapsedSeconds=20; undo.errorCount=2;
    undo.selectedIndex=4; undo.cells[0].flags=8;
    await c.record(undo,'undo');
    assert.equal(c.getGraph().nodes.length,3); assert.equal(c.getState().node.id,firstId);
    assert.equal(c.getState().branch.tipNodeId,secondId);
    const redo=model.toGameSave(c.getGraph(),secondId,false); redo.elapsedSeconds=4; redo.errorCount=0;
    await c.record(redo,'redo');
    assert.equal(c.getState().node.id,secondId); assert.equal(c.getGraph().nodes.length,3);
    assert.equal(current(c).elapsedSeconds,20); assert.equal(current(c).errorCount,2);
  });
  await check('checkpoint duplicates do not prevent one-batch undo and redo',async()=>{
    await c.record(current(c),'checkpoint'); const checkpoint=c.getState().node.id;
    assert.equal(c.getGraph().nodes.length,4);
    await c.record(model.toGameSave(c.getGraph(),firstId,false),'undo');
    assert.equal(c.getState().node.id,firstId); assert.equal(c.getState().branch.tipNodeId,checkpoint);
    await c.record(model.toGameSave(c.getGraph(),secondId,false),'redo');
    assert.equal(c.getState().node.id,secondId); assert.equal(c.getGraph().nodes.length,4);
  });
  await check('failed write retains all queued edits and retry commits in original order',async()=>{
    const d=new GameJournalCoordinator({});const s=await d.initialize(save4());
    const x=copy(s);x.cells[0].value=1;const y=copy(x);y.cells[4].value=3;
    failNextNode=true;
    const results=await Promise.allSettled([d.record(x,'fill'),d.record(y,'fill')]);
    assert.ok(results.every(result=>result.status==='rejected'));
    assert.equal(d.getGraph().nodes.length,1);
    await d.flush(); assert.equal(d.getGraph().nodes.length,3);
    assert.equal(d.getGraph().nodes[1].values[0],1);
    assert.equal(d.getGraph().nodes[1].values[4],0);
    assert.equal(d.getGraph().nodes[2].values[4],3);
  });
  await check('callback failure retries notification without duplicating committed node',async()=>{
    const d=new GameJournalCoordinator({}); const s=await d.initialize(save4()); let callbacks=0;
    d.onPersisted=()=>{ if (++callbacks===1) throw new Error('compatibility store failed'); };
    s.cells[0].value=1;
    await assert.rejects(d.record(s,'fill'),/compatibility store failed/);
    assert.equal(d.getGraph().nodes.length,2);
    await d.flush();assert.equal(callbacks,2);assert.equal(d.getGraph().nodes.length,2);
  });
  await check('clock is snapshotted, monotone, and never adds a node',async()=>{
    const s=current(c), before=c.getGraph().nodes.length, reads=fullGraphReads;
    s.elapsedSeconds=40; s.errorCount=3; s.isChallengeFailed=true;
    const pending=c.persistClock(s);s.elapsedSeconds=1000;s.errorCount=20;
    await pending;
    assert.equal(current(c).elapsedSeconds,40);assert.equal(current(c).errorCount,3);
    assert.equal(c.getGraph().nodes.length,before);assert.equal(fullGraphReads,reads);
  });
  await check('initialize prefers newer journal head to older compatibility pointer',async()=>{
    const old=copy(source);old.timestamp=0;
    const d=new GameJournalCoordinator({});const restored=await d.initialize(old);
    assert.deepEqual(copy(position(restored)),copy(position(current(c))));
    assert.equal(d.getGraph().nodes.length,c.getGraph().nodes.length);
  });
  await check('initialize recovers newer differing snapshot and preserves earlier route',async()=>{
    const s=current(c);s.cells[6].value=1;s.timestamp=Date.now()+10000;
    const d=new GameJournalCoordinator({});const recovered=await d.initialize(s);
    assert.equal(d.getState().node.action,'recovered');assert.equal(recovered.cells[6].value,1);
    assert.ok(d.getGraph().nodes.some(node=>node.id===secondId));
    c=d;
  });
  await check('explicit non-head restore rejects; queued work flushes before practice fork',async()=>{
    const before=c.getState().node.id;
    await assert.rejects(c.restore(c.getState().session.id,firstId,false),/explicit practice fork/);
    assert.equal(c.getState().node.id,before);
    const s=current(c);s.cells[7].value=2;
    const pending=c.record(s,'fill');
    const fork=c.restore(c.getState().session.id,firstId,true);
    await pending;const restored=await fork;
    assert.equal(c.isPractice(),true);assert.equal(restored.journalNodeId,firstId);
    assert.ok(c.getGraph().nodes.some(node=>node.values[7]===2));
    assert.equal(await c.settle('won'),false);
  });
  await check('challenge to practice then explicit original-branch activation retains both routes',async()=>{
    const session=c.getState().session.id, practiceBranch=c.getState().branch.id;
    const s=current(c);s.cells[6].value=1;await c.record(s,'fill');const practiceTip=c.getState().node.id;
    const branch=c.getGraph().branches.find(item=>item.id===challengeBranch);
    await assert.rejects(c.restore(session,firstId,false,challengeBranch),/saved tip/);
    await c.restore(session,'',false,challengeBranch);
    assert.equal(c.isPractice(),false);assert.equal(c.getState().node.id,branch.tipNodeId);
    const next=current(c);next.cells[7].value=2;await c.record(next,'fill');
    assert.ok(c.getGraph().branches.some(item=>item.id===practiceBranch && item.tipNodeId===practiceTip));
    const persisted=await repository.getSessionGraph({},session);
    assert.ok(persisted.nodes.some(node=>node.id===practiceTip));
  });
  await check('settlement refresh failure retains claim receipt; successful challenge settles once',async()=>{
    const d=new GameJournalCoordinator({});const s=await d.initialize(save4());
    s.cells.forEach((cell,i)=>{cell.value=s.solution[i];cell.notes=0;});
    await d.record(s,'fill');failStateAfterClaim=true;
    await assert.rejects(d.settle('won'),/injected refresh failure/);
    assert.equal(await d.settle('won'),true);assert.equal(d.getState().session.settled,true);
    assert.equal(await d.settle('won'),false);
  });
  await check('deactivate rejects new work but permits failed queued operation to flush',async()=>{
    const d=new GameJournalCoordinator({});const s=await d.initialize(save4());s.cells[0].value=1;
    failNextNode=true;await assert.rejects(d.record(s,'fill'),/injected disk failure/);
    d.deactivate();await assert.rejects(d.record(s,'fill'),/inactive/);
    await assert.rejects(d.persistClock(s),/inactive/);
    await d.flush();assert.equal(d.getState().node.values[0],1);
  });
  await check('old coordinator refuses writes after another coordinator changes active branch',async()=>{
    const d=new GameJournalCoordinator({});const s=await d.initialize(save4());
    await repository.forkFromNode({},d.getState().session.id,d.getState().node.id);
    s.elapsedSeconds=999;
    await assert.rejects(d.persistClock(s),/changed outside/);
    const graph=await repository.getSessionGraph({},d.getState().session.id);
    assert.equal(model.journalActiveBranch(graph).elapsedSeconds,0);
  });
  console.log(JSON.stringify({passed:tests.length,tests,sqlStatements:statements,fullGraphReads,
    limitation:'Original ETS coordinator/repository under Node SQLite adapter; not native ArkTS or HarmonyOS RDB validation.'},null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
