'use strict';
// Execute the real page methods plus original domain code. --source is a fast,
// pre-build check; passing CompileArkTS's ets directory tests compiler output.
// Neither mode substitutes for native rendering/input QA.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const adapter = require('../docs/audit-2026-11-02/algorithm-build.cjs');
const input = process.argv[2];
assert.ok(input, 'Pass --source or the real CompileArkTS esmodule/release/.../ets directory');
const sourceMode = input === '--source';
const inputRoot = sourceMode ? adapter.sourceRoot : input;
let ts;
for (const candidate of [process.env.SUDOKU_AUDIT_TYPESCRIPT, 'typescript',
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript'].filter(Boolean)) {
  try { ts = require(candidate); break; } catch (_) {}
}
assert.ok(ts, 'TypeScript parser unavailable');
// Only pure dependencies needed by these checks; device/language/storage modules
// must not be pulled in just because they share the utils directory.
const bundle = path.join(os.tmpdir(), 'sudoku-play-feedback-probe.cjs');
const pure = ['models/CellData', 'models/GameJournal', 'models/GameSaveData',
  'constants/GameConstants', 'models/VariantConfig', 'utils/Topology', 'utils/SudokuValidator'];
adapter.getEsbuild().buildSync({
  stdin: { contents: pure.map(name => `export * as ${path.basename(name)} from ${JSON.stringify(path.join(adapter.sourceRoot, name + '.ets'))};`).join('\n'),
    loader: 'ts', resolveDir: adapter.sourceRoot },
  outfile: bundle, bundle: true, platform: 'node', target: 'node20', format: 'cjs',
  resolveExtensions: ['.ets', '.ts', '.js'], loader: { '.ets': 'ts' },
  tsconfigRaw: { compilerOptions: { experimentalDecorators: true } },
  banner: { js: 'const Observed = value => value;' }, logLevel: 'error',
});
const app = require(bundle);
app.GameConstants.applyGridConfig(app.VariantConfig.getGridConfigBySize(4));
app.Topology.applyTopology(app.VariantConfig.createSizedConfig(4, 2, 2));
const hashes = {};
function extract(relative, names) {
  const file = path.join(inputRoot, relative + (sourceMode ? '.ets' : '.ts'));
  const original = fs.readFileSync(file, 'utf8');
  hashes[relative] = crypto.createHash('sha256').update(original).digest('hex');
  const source = sourceMode ? original.replace(/^(\s*(?:export\s+)?)struct\s+/gm, '$1class ') : original;
  const ast = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  const methods = [];
  function visit(node) {
    if (ts.isMethodDeclaration(node) && names.includes(node.name.getText(ast))) methods.push(node.getText(ast));
    ts.forEachChild(node, visit);
  }
  visit(ast);
  assert.equal(methods.length, names.length, relative + ': missing/ambiguous requested method');
  return methods.join('\n');
}
const toasts = [], dialogs = [];
const context = { ...app.CellData, validateAllCells: app.SudokuValidator.validateAllCells,
  GRID_SIZE: 4, GestureDirection: app.GameConstants.GestureDirection,
  KeyCode: { KEYCODE_N: 1001, KEYCODE_TAB: 1002 },
  promptAction: { showToast: value => toasts.push(value) },
  getContext: () => ({ resourceManager: { getStringByNameSync: name => name } }),
  getLocalizedString: (_context, key, revision) => `${key}@${revision}`,
  AlertDialog: { show: value => dialogs.push(value) } };
vm.createContext(context);
function define(name, relative, methods) {
  vm.runInContext(adapter.getEsbuild().transformSync(
    `class ${name} { ${extract(relative, methods)} } globalThis.${name} = ${name};`,
    { loader: 'ts', target: 'node20' }).code, context);
}
define('Probe', 'pages/GamePage', ['refreshValidation', 'handleFillDigit', 'handleKeyboardInput',
  'showCompletionDialog', 'getString']);
const solution = [1,2,3,4,3,4,1,2,2,1,4,3,4,3,2,1];
function page(libraryId, puzzleIndex, practice = false) {
  const probe = new context.Probe();
  Object.assign(probe, { libraryId, puzzleIndex, journalPractice: practice, validateInput: true,
    localeRevision: 0, gameState: { cells: app.CellData.createEmptyBoard(), solution,
      errorCount: 0, isChallengeFailed: false, isCompleted: false, isPaused: false, selectedIndex: 1,
      formattedTime: '01:23' }, getActiveCages: () => undefined });
  probe.gameState.cells[0].value = 1;
  probe.gameState.cells[0].flags = app.CellData.CellFlags.GIVEN;
  return probe;
}
const cases = [];
for (const [name, libraryId, index, practice] of [
  ['ordinary', undefined, -1, false], ['imported', '', -1, false],
  ['library', 'beginner', 0, false], ['practice', 'beginner', 0, true],
]) {
  const probe = page(libraryId, index, practice);
  for (const digit of [1,3,1,3]) probe.handleFillDigit(probe.gameState.cells[1], digit);
  assert.equal(probe.gameState.errorCount, 4, name);
  assert.equal(probe.gameState.cells[1].isError, true, name);
  assert.equal(probe.gameState.isChallengeFailed, false, name);
  probe.handleFillDigit(probe.gameState.cells[1], 2);
  assert.equal(probe.gameState.cells[1].value, 2, name + ': still editable after four mistakes');
  assert.equal(probe.gameState.cells[1].isError, false);
  assert.equal(probe.gameState.errorCount, 4, 'Correcting a value does not rewind the ledger');
  probe.handleFillDigit(probe.gameState.cells[1], 2); // same digit toggles erase
  probe.refreshValidation();
  assert.equal(probe.gameState.cells[1].value, 0);
  assert.equal(probe.gameState.errorCount, 4, 'Erasing does not add a mistake');
  cases.push(name + ': four mistakes show/count, remain editable, correct/erase do not add mistakes');
}
const conflictOnly = page(); conflictOnly.validateInput = false;
conflictOnly.handleFillDigit(conflictOnly.gameState.cells[1], 3); // no conflict, different reference answer
assert.equal(conflictOnly.gameState.cells[1].isError, false);
assert.equal(conflictOnly.gameState.errorCount, 0);
conflictOnly.handleFillDigit(conflictOnly.gameState.cells[1], 1); // same row/box as a given
assert.equal(conflictOnly.gameState.cells[1].isError, true);
assert.equal(conflictOnly.gameState.errorCount, 1);
conflictOnly.gameState.cells[1].flags |= app.CellData.CellFlags.SELECTED;
conflictOnly.journalPractice = true;
conflictOnly.refreshValidation();
assert.ok(conflictOnly.gameState.cells[1].isError);
assert.ok(conflictOnly.gameState.cells[1].isSelected);
assert.ok(conflictOnly.gameState.cells[0].isGiven);
cases.push('Answer check off counts visible peer conflicts only; trial restore recalculates errors and preserves selection/givens');
const cage = page(); cage.validateInput = false;
cage.getActiveCages = () => [{ cells: [0,1], sum: 3 }];
cage.handleFillDigit(cage.gameState.cells[1], 3); // no peer conflict, but completed cage sum is wrong
assert.ok(cage.gameState.cells[1].isError); assert.equal(cage.gameState.errorCount, 1);
cases.push('Answer check off still counts an incorrect completed Killer cage');
const complete = page();
const alternative = [1,3,2,4,2,4,1,3,3,1,4,2,4,2,3,1];
alternative.forEach((value, i) => { complete.gameState.cells[i].value = value; });
complete.refreshValidation();
assert.ok(complete.gameState.cells.some(cell => cell.isError));
assert.equal(app.SudokuValidator.isGameCompleted(complete.gameState.cells), true);
const save = new app.GameSaveData.GameSaveData(); save.gridSize = 4; save.difficulty = 1; save.solution = solution;
save.cells = complete.gameState.cells.map((cell, index) => new app.GameSaveData.CellSerialized(
  Math.floor(index / 4), index % 4, cell.isGiven ? cell.value : 0, cell.isGiven ? 1 : 0, 0));
assert.equal(app.GameJournal.isJournalBoardComplete(save, alternative), true);
cases.push('A valid alternate solution to an imported puzzle still completes despite reference mismatch styling');
const journalSession = new app.GameJournal.JournalSession();
const original = new app.GameJournal.JournalBranch();
app.GameJournal.updateJournalMetrics(journalSession, original, 12, 4, false);
app.GameJournal.updateJournalMetrics(journalSession, original, 8, 1, false); // undo has older metrics
assert.equal(original.errorCount, 4); assert.equal(journalSession.scoreChallengeFailed, false);
const practice = new app.GameJournal.JournalBranch(); practice.mode = 'practice';
app.GameJournal.updateJournalMetrics(journalSession, practice, 30, 8, false);
assert.equal(practice.errorCount, 8); assert.equal(journalSession.scoreErrorCount, 4);
cases.push('Error limit stays zero; undo cannot rewind errors and practice errors do not enter original score');
const completed = page(); completed.gameState.errorCount = 4;
completed.showCompletionDialog();
assert.ok(dialogs.at(-1).message.includes('dialog_congrats_errors: 4'));
cases.push('Ordinary completion includes error information');
const keyboard = page(); keyboard.gestureDirection = app.GameConstants.GestureDirection.RIGHT;
keyboard.handleKeyboardInput(1001); assert.equal(keyboard.isNoteMode, true);
keyboard.handleKeyboardInput(1002); assert.equal(keyboard.isNoteMode, false);
assert.equal(keyboard.gestureDirection, app.GameConstants.GestureDirection.RIGHT);
assert.deepEqual(toasts.map(item => item.message), ['note_mode_on@0', 'note_mode_off@0']);
keyboard.showGestureGuide = true; keyboard.handleKeyboardInput(1001);
assert.equal(toasts.length, 2); assert.equal(keyboard.isNoteMode, false);
cases.push('N/Tab show short mode toasts without altering touch direction; guide guards keyboard input');
assert.equal(keyboard.getString('label'), 'label@0'); keyboard.localeRevision = 7;
assert.equal(keyboard.getString('label'), 'label@7');
cases.push('Game helper forwards current locale revision without rebuilding game state');
define('WatchProbe', 'pages/WatchGamePage', ['cellColor', 'text']);
const watch = new context.WatchProbe();
Object.assign(watch, { givens: [1,0,0,0], values: [1,1,0,4], localeRevision: 0,
  session: { data: { solution: [1,2,3,4] } },
  getPalette: () => ({ textGiven: 'given', textUser: 'user', textNote: 'note', textError: 'red' }) });
assert.equal(watch.cellColor(0), 'given'); assert.equal(watch.cellColor(1), 'red');
assert.equal(watch.cellColor(2), 'note'); assert.equal(watch.cellColor(3), 'user');
assert.equal(watch.text('watch_box'), 'watch_box@0'); watch.localeRevision = 2;
assert.equal(watch.text('watch_box'), 'watch_box@2');
cases.push('Watch wrong values are red; givens/correct values/notes retain their ink, locale revision is observed');
define('CellProbe', 'components/SudokuCell', ['getTextColor', 'getNoteColor', 'getCellBgColor']);
const cell = new context.CellProbe();
Object.assign(cell, { showErrors: true, selectedValue: 0, isHintTarget: false,
  cellData: { isError: true, isGiven: false, isSelected: false, isMultiSelected: false,
    isHighlighted: false, value: 3, notes: app.CellData.setNoteState(0, 3, app.CellData.NoteState.ACTIVE) },
  decoration: { backgroundColor: '' }, isNoteConflicting: () => true,
  getPalette: () => ({ textUser: 'ink', textNote: 'note', textNoteElim: 'eliminated', textError: 'red', cellError: 'red paper' }) });
assert.equal(cell.getTextColor(), 'red'); assert.equal(cell.getNoteColor(3), 'red');
assert.equal(cell.getCellBgColor(), 'red paper');
cell.cellData.notes = app.CellData.setNoteState(0, 3, app.CellData.NoteState.ELIMINATED);
assert.equal(cell.getNoteColor(3), 'eliminated');
cases.push('Value ink, cell background and active conflicting candidates are red; eliminated notes stay distinct');
console.log(JSON.stringify({ passed: cases.length, cases, inputMode: sourceMode ? 'ETS method extraction' : 'CompileArkTS output',
  sourceSha256: hashes, limitation: 'Pure method/domain execution, not native UI or a replacement for compiler checks.' }, null, 2));
