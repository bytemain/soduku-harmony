'use strict';
// Check source themes and actual Hvigor-generated methods; no device rendering.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const adapter = require('../docs/audit-2026-11-02/algorithm-build.cjs');
const root = path.resolve(__dirname, '..');
const options = {};
for (let index = 2; index < process.argv.length; index++) {
  const arg = process.argv[index];
  if (arg === '--source-only') options.sourceOnly = true;
  else if (arg === '--compiled-root' || arg === '--output') {
    assert.ok(process.argv[index + 1] && !process.argv[index + 1].startsWith('--'), `${arg} requires a path`);
    options[arg === '--compiled-root' ? 'compiledRoot' : 'output'] = path.resolve(process.argv[++index]);
  } else throw new Error(`Unknown argument: ${arg}`);
}
assert.ok(Boolean(options.sourceOnly) !== Boolean(options.compiledRoot),
  'Pass --compiled-root <Hvigor CompileArkTS/esmodule/release/.../ets> for release verification, or --source-only explicitly.');
const manifest = fs.readFileSync(path.join(root, 'AppScope/app.json5'), 'utf8');
const version = manifest.match(/"?versionName"?\s*:\s*['"]([^'"]+)['"]/);
assert.ok(version, 'AppScope versionName is required');
assert.match(version[1], /^[0-9A-Za-z._-]+$/, 'Unsafe versionName for report filename');
const output = options.output || path.join(root,
  `release-artifacts/not-bad-sudoku-${version[1]}-theme-validation${options.sourceOnly ? '-source-only' : ''}.json`);
const app = require(adapter.build());
const expectedComponents = [
  'components/AuxButtonGrid.ets', 'components/CollapsibleSelector.ets', 'components/DifficultySegment.ets',
  'components/GameLoadingView.ets', 'components/GestureGuideOverlay.ets', 'components/GestureKey.ets',
  'components/GestureModeIndicator.ets', 'components/MultiSelectBanner.ets', 'components/PauseOverlay.ets',
  'components/SettingsPanel.ets', 'components/StatsPanel.ets', 'components/SudokuBoard.ets',
  'components/SudokuCell.ets', 'components/TopBar.ets', 'components/VariantSegment.ets',
  'pages/GamePage.ets', 'pages/Index.ets', 'pages/PrivacyPage.ets', 'pages/PuzzleLibraryPage.ets',
  'pages/WatchHomePage.ets', 'pages/WatchGamePage.ets',
  'components/GameMainContent.ets', 'components/JournalBoardPreview.ets', 'components/JournalPanel.ets',
  'components/HomeDisclosureRow.ets', 'components/HistoryList.ets',
  'pages/HistoryPage.ets', 'pages/StatsPage.ets',
].sort();
function sha256(text) { return crypto.createHash('sha256').update(text).digest('hex'); }
function getTypeScript() {
  for (const candidate of [process.env.SUDOKU_AUDIT_TYPESCRIPT, 'typescript',
    '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript',
    '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript'].filter(Boolean)) {
    try { return require(candidate); } catch (error) {
      if (error.code !== 'MODULE_NOT_FOUND') throw error;
    }
  }
  throw new Error('Set SUDOKU_AUDIT_TYPESCRIPT to an installed TypeScript package to inspect compiled class methods.');
}
function verifyCompiledPalettes() {
  const ts = getTypeScript();
  const results = [];
  for (const relative of expectedComponents) {
    const filename = path.join(options.compiledRoot, relative.replace(/\.ets$/, '.ts'));
    const text = fs.readFileSync(filename, 'utf8');
    const sourceFile = ts.createSourceFile(filename, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
    assert.equal(sourceFile.parseDiagnostics.length, 0, `${relative}: invalid compiled TypeScript`);
    const definitions = [];
    const uses = [];
    function visit(node, owner) {
      if (ts.isClassDeclaration(node) || ts.isClassExpression(node)) owner = node;
      if (ts.isPropertyAccessExpression(node) && node.expression.kind === ts.SyntaxKind.ThisKeyword) {
        assert.notEqual(node.name.text, 'palette', `${relative}: legacy this.palette survived compilation`);
        if (node.name.text === 'getPalette') {
          assert.ok(ts.isCallExpression(node.parent) && node.parent.expression === node,
            `${relative}: getPalette must be called, not passed unbound`);
          uses.push({ owner, node });
        }
      }
      if (ts.isMethodDeclaration(node) && node.name.getText(sourceFile) === 'getPalette') {
        definitions.push({ owner, method: node });
      }
      ts.forEachChild(node, child => visit(child, owner));
    }
    visit(sourceFile, undefined);
    assert.equal(definitions.length, 1, `${relative}: expected one compiled getPalette method`);
    assert.ok(uses.length > 0, `${relative}: no compiled palette calls`);
    const { owner, method } = definitions[0];
    assert.ok(owner, `${relative}: palette method outside class`);
    assert.ok(uses.every(use => use.owner === owner), `${relative}: palette calls in a class without the method`);
    assert.ok(owner.members.some(member => ts.isGetAccessorDeclaration(member) &&
      member.name.getText(sourceFile) === 'isDarkMode'), `${relative}: reactive isDarkMode accessor missing`);
    assert.equal(method.body.statements.length, 1, `${relative}: palette implementation changed`);
    const statement = method.body.statements[0];
    assert.ok(ts.isReturnStatement(statement) && statement.expression &&
      statement.expression.getText(sourceFile) === 'getThemeColors(this.isDarkMode)',
    `${relative}: compiled method must read the current reactive theme`);
    // Execute the compiler-produced method itself, switching the same instance.
    const context = { getThemeColors: app.GameConstants.getThemeColors };
    vm.createContext(context);
    const code = `class ThemeProbe { ${method.getText(sourceFile)} }\nglobalThis.ThemeProbe = ThemeProbe;`;
    vm.runInContext(adapter.getEsbuild().transformSync(code, { loader: 'ts', target: 'node20' }).code, context);
    const probe = new context.ThemeProbe();
    let dark = false, reads = 0;
    Object.defineProperty(probe, 'isDarkMode', { get() { reads++; return dark; } });
    for (const mode of [false, true, false]) {
      dark = mode;
      const palette = probe.getPalette();
      assert.equal(palette, app.GameConstants.getThemeColors(mode), `${relative}: wrong theme`);
      assert.ok(palette.pageBg, `${relative}: pageBg is undefined`);
    }
    assert.equal(reads, 3, `${relative}: theme state was cached`);
    results.push({ file: relative.replace(/\.ets$/, '.ts'), className: owner.name.text,
      paletteCalls: uses.length, generatedSourceSha256: sha256(text),
      generatedMethodSha256: sha256(method.getText(sourceFile)), lightDarkLightPassed: true });
  }
  assert.equal(results.length, expectedComponents.length, 'Compiled component coverage changed');
  return results;
}
const contrasts = [];
function luminance(hex) {
  const rgb = hex.slice(1).match(/../g).map(value => parseInt(value, 16) / 255)
    .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
}
function checkContrast(theme, name, foreground, background) {
  const a = luminance(foreground), b = luminance(background);
  const ratio = (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
  contrasts.push({ theme, name, foreground, background, ratio: +ratio.toFixed(3) });
  assert.ok(ratio >= 4.5, `${theme} ${name}: contrast ${ratio.toFixed(3)} below 4.5`);
}
for (const dark of [false, true]) {
  const theme = dark ? 'dark' : 'light';
  const palette = app.GameConstants.getThemeColors(dark);
  const colorResource = JSON.parse(fs.readFileSync(path.join(root,
    `entry/src/main/resources/${dark ? 'dark' : 'base'}/element/color.json`), 'utf8'));
  for (const [foreground, background] of [['titleText', 'pageBg'], ['subtitleText', 'pageBg'],
    ['primaryText', 'primaryBtn'], ['keyText', 'keyBg'], ['killerCageLabel', 'boardBg']]) {
    checkContrast(theme, `${foreground}/${background}`, palette[foreground], palette[background]);
  }
  const backgrounds = ['cellDefault', 'cellSelected', 'cellHighlight', 'cellSameNumber',
    'cellDiagonal', 'cellDiagonalHighlight', 'cellError'].map(name => [name, palette[name]]);
  for (const item of colorResource.color.filter(item => item.name !== 'start_window_background')) {
    backgrounds.push([item.name, item.value]);
  }
  for (const foreground of ['textGiven', 'textUser', 'textNote', 'textNoteElim', 'textError']) {
    for (const [name, background] of backgrounds) {
      checkContrast(theme, `${foreground}/${name}`, palette[foreground], background);
    }
  }
  const diagonal = app.BoardDecoration.buildDiagonalBoardDecorations(0, palette);
  assert.equal(diagonal[0].backgroundColor, palette.cellDiagonal);
  assert.equal(diagonal[0].highlightBackgroundColor, palette.cellDiagonalHighlight);
}
assert.equal(app.GameConstants.Sizes.cellBorderThin, 0.5);
assert.equal(app.GameConstants.Sizes.cellBorderBold, 1.25);
// Reproduce the callback after SettingsPanel already updated AppStorage.
const lifecycleFile = path.join(adapter.sourceRoot, 'entryability/EntryAbility.ets');
const lifecycleSource = fs.readFileSync(lifecycleFile, 'utf8');
const start = lifecycleSource.indexOf('  onConfigurationUpdate(');
assert.ok(start >= 0);
const method = lifecycleSource.slice(start, lifecycleSource.indexOf('\n  }', start) + 4);
const lifecycleOutcomes = [];
for (const test of [
  { name: 'manual dark preupdated storage', mode: 'dark', initial: true, incoming: 1, expected: true },
  { name: 'manual light preupdated storage', mode: 'light', initial: false, incoming: 0, expected: false },
  { name: 'system switches to dark', mode: 'system', initial: false, incoming: 1, expected: true },
  { name: 'manual light ignores system dark', mode: 'light', initial: false, incoming: 1, expected: false },
  { name: 'unrelated configuration preserves theme', mode: 'system', initial: true, incoming: undefined, expected: true },
]) {
  const storage = new Map([['themeMode', test.mode], ['isDarkMode', test.initial]]);
  const bars = [];
  const context = { AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) },
    ConfigurationConstant: { ColorMode: { COLOR_MODE_LIGHT: 0, COLOR_MODE_DARK: 1 } },
    refreshLocaleRevision() {}, applyTheme() {}, hilog: { info() {} }, DOMAIN: 0 };
  vm.createContext(context);
  const code = 'class Ability { ' + method + ' }\nglobalThis.Ability=Ability;';
  vm.runInContext(adapter.getEsbuild().transformSync(code, { loader: 'ts', target: 'node20' }).code, context);
  const ability = new context.Ability();
  ability.mainWindow = {};
  ability.updateSystemBarStyle = (_, dark) => bars.push(dark);
  ability.onConfigurationUpdate({ colorMode: test.incoming });
  assert.equal(storage.get('isDarkMode'), test.expected);
  assert.deepEqual(bars, test.incoming === undefined ? [] : [test.expected]);
  lifecycleOutcomes.push({ name: test.name, passed: true });
}
const themeComponents = [];
for (const dir of ['pages', 'components']) {
  for (const file of fs.readdirSync(path.join(adapter.sourceRoot, dir)).filter(name => name.endsWith('.ets'))) {
    const relative = path.join(dir, file);
    const source = fs.readFileSync(path.join(adapter.sourceRoot, relative), 'utf8');
    assert.ok(!/\bthis\.palette\b|\bget\s+palette\s*\(/.test(source), `${relative}: unsupported palette accessor`);
    if (!/\bgetPalette\b/.test(source)) continue;
    assert.equal((source.match(/private\s+getPalette\(\):\s*ColorsConfig/g) || []).length, 1,
      `${relative}: expected one ordinary palette method`);
    assert.ok(source.includes('this.getPalette()'), `${relative}: palette method has no calls`);
    assert.ok(source.includes("@StorageProp('isDarkMode')"), `${relative}: missing reactive theme`);
    assert.ok(source.includes('return getThemeColors(this.isDarkMode)'), `${relative}: cached palette`);
    themeComponents.push(relative);
  }
}
assert.deepEqual(themeComponents.sort(), expectedComponents, 'Theme coverage must match the component inventory');
const compiledPalettes = options.compiledRoot ? verifyCompiledPalettes() : null;
const report = { version: version[1],
  scope: 'Source palette contrast and original lifecycle method with mocks; when supplied, actual Hvigor-generated palette methods are parsed and executed. No ArkUI/device rendering or launch validation.',
  compiledPalettesVerified: Boolean(compiledPalettes), compiledRoot: options.compiledRoot || null,
  compiledPalettes,
  minimumContrast: Math.min(...contrasts.map(item => item.ratio)), contrastPairs: contrasts.length,
  contrasts, lifecycleOutcomes, themeComponents, diagonalThemePassed: true,
  boardLineWidths: { thin: 0.5, bold: 1.25 },
  lifecycleSourceSha256: sha256(lifecycleSource) };
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ minimumContrast: report.minimumContrast, contrastPairs: report.contrastPairs,
  lifecycleCasesPassed: lifecycleOutcomes.length, themeComponents: themeComponents.length,
  compiledPaletteMethods: compiledPalettes ? compiledPalettes.length : 0,
  compiledPalettesVerified: Boolean(compiledPalettes), output }, null, 2));
