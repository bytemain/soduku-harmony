'use strict';

// Offline geometry checks, optionally against compiler output and a captured portrait UITest tree.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const vm = require('node:vm');
const adapter = require('../docs/audit-2026-11-02/algorithm-build.cjs');
const root = path.resolve(__dirname, '..');
const options = {};
for (let index = 2; index < process.argv.length; index++) {
  const arg = process.argv[index];
  assert.ok(['--compiled-root', '--output', '--portrait-tree', '--pixel-ratio'].includes(arg), `Unknown argument: ${arg}`);
  assert.ok(process.argv[index + 1] && !process.argv[index + 1].startsWith('--'), `${arg} needs a path`);
  if (arg === '--pixel-ratio') {
    options.pixelRatio = Number(process.argv[++index]);
    assert.ok(Number.isFinite(options.pixelRatio) && options.pixelRatio > 0, '--pixel-ratio must be the measured display px/vp ratio');
    continue;
  }
  const name = { '--compiled-root': 'compiledRoot', '--output': 'output', '--portrait-tree': 'portraitTree' }[arg];
  options[name] = path.resolve(process.argv[++index]);
}
assert.ok(!options.portraitTree || options.pixelRatio, '--portrait-tree requires --pixel-ratio from the capture device');
const output = options.output || path.join(root, 'docs/audit-2026-11-02/adaptive-layout-results.json');
const sha256 = text => crypto.createHash('sha256').update(text).digest('hex');
const normalized = value => JSON.parse(JSON.stringify(value));
const sourceFile = path.join(adapter.sourceRoot, 'utils/AdaptiveLayout.ets');
const source = fs.readFileSync(sourceFile, 'utf8');
function loadPureModule(text) {
  const module = { exports: {} };
  const context = { module, exports: module.exports };
  vm.createContext(context);
  vm.runInContext(adapter.getEsbuild().transformSync(text,
    { loader: 'ts', format: 'cjs', target: 'node20' }).code, context);
  return module.exports;
}
const api = loadPureModule(source);
const scenarios = [
  { name: 'phone portrait', width: 393, height: 650, wide: false, homeWide: false },
  { name: 'square number pad below former one-row breakpoint', width: 447.99, height: 700, wide: false, homeWide: false },
  { name: 'square number pad at former one-row breakpoint', width: 448, height: 700, wide: false, homeWide: false },
  { name: 'square number pad above former one-row breakpoint', width: 448.01, height: 700, wide: false, homeWide: false },
  { name: 'narrow landscape at two-column breakpoint', width: 656, height: 400, wide: true, homeWide: false },
  { name: 'phone landscape', width: 780, height: 280, wide: true, homeWide: true },
  { name: '600 vp split window', width: 600, height: 420, wide: false, homeWide: false },
  { name: '960 vp unfolded window', width: 960, height: 720, wide: true, homeWide: true },
  { name: 'short unfolded window', width: 840, height: 240, wide: true, homeWide: true },
  { name: 'narrow short split window', width: 320, height: 220, wide: false, homeWide: false },
  { name: 'Pura X Max narrow portrait content', width: 664, height: 836, wide: false, homeWide: false },
  { name: 'narrow unfolded portrait', width: 840, height: 1000, wide: false, homeWide: true },
  { name: 'wide unfolded portrait', width: 960, height: 1200, wide: true, homeWide: true },
  { name: 'portrait just below roomy breakpoint', width: 855, height: 1000, wide: false, homeWide: true },
  { name: 'portrait at roomy breakpoint', width: 856, height: 1000, wide: true, homeWide: true },
];
const widths = [0, 1, 16, 32, 100, 207.99, 208, 303.99, 304, 320, 360, 393, 447.99, 448, 448.01, 600, 655, 656, 664, 700, 767, 768, 840, 855, 856, 960, 1440, -1, Infinity, NaN];
const heights = [0, 1, 32, 100, 200, 280, 420, 650, 836, 900, 1000, 1200, -1, Infinity, NaN];
// The compact number grid puts 4vp gaps between keys. Other arrangements
// still use GridItem padding of 2vp on each edge.
function keypadTouchSize(plan) {
  if (plan.compactKeypad) {
    const side = Math.max(0, plan.stackedKeypadWidth - 8) / 3;
    return { width: side, height: side };
  }
  const numberWidth = plan.toolsHorizontal ? plan.stackedKeypadWidth : plan.controlWidth - plan.actionHeight * 2 / 3 - 8;
  const numberHeight = plan.actionHeight - (plan.toolsHorizontal ? 48 + 6 : 0);
  return { width: numberWidth / plan.keypadColumns - 4, height: numberHeight / plan.keypadRows - 4 };
}
function checkKeypadContract(plan, size, top, coordinates, width, height) {
  assert.equal(typeof plan.toolsHorizontal, 'boolean', 'Layout must expose the actual tool orientation');
  assert.ok(Number.isInteger(plan.keypadColumns) && plan.keypadColumns > 0, 'Missing or invalid keypadColumns');
  assert.ok(Number.isInteger(plan.keypadRows) && plan.keypadRows > 0, 'Missing or invalid keypadRows');
  assert.equal(plan.keypadColumns * plan.keypadRows, size, 'Every digit must have exactly one visible slot');
  const stackedFallback = !plan.wide && size === 9 && plan.controlWidth < 252;
  assert.equal(plan.toolsHorizontal, plan.wide ? width >= height || top : size !== 9 || stackedFallback,
    'Landscape tools must stay above; portrait split layouts honor the preference and narrow windows remain reachable');
  assert.equal(plan.compactKeypad, !plan.wide && size === 9, 'Only stacked nine-digit games use the compact independent keypad');
  assert.ok(plan.stackedKeypadWidth <= plan.controlWidth + 1e-6 || stackedFallback,
    'Only the internally scrollable narrow fallback may exceed its viewport width');
  if (size === 9) {
    assert.deepEqual([plan.keypadColumns, plan.keypadRows], [3, 3], 'Digits 1–9 must keep the same 3×3 arrangement after resizing');
    const target = keypadTouchSize(plan);
    assert.ok(Math.abs(target.width - target.height) < 1e-6, 'A digit must stay square in both tool orientations');
    if (plan.compactKeypad) {
      assert.ok(Math.abs(plan.stackedKeypadWidth - (plan.actionHeight - (stackedFallback ? 106 : 0))) < 1e-6,
        'The compact number grid must have equal overall width and height');
      assert.ok(target.width >= 48 - 1e-6 && target.width <= 68 + 1e-6,
        'Compact paper keys must stay between 48 and 68vp');
      if (stackedFallback) {
        assert.equal(plan.stackedKeypadWidth, 152, 'Narrow windows preserve 48vp targets using internal scrolling when needed');
      } else {
        assert.ok(plan.stackedKeypadWidth + 100 <= plan.controlWidth + 1e-6,
          'The 92vp tool grid plus 8vp gap and keypad must fit the controls');
      }
    } else {
      assert.ok(target.height >= 44 - 1e-6 && target.height <= 80 + 1e-6,
        'Wide two-column keypads have independent touch sizing');
    }
  } else if (plan.keypadRows === 1) {
    assert.equal(plan.keypadColumns, size);
    assert.equal(plan.stackedKeypadWidth, plan.controlWidth);
    assert.ok(!plan.wide && plan.controlWidth / size >= 48, 'A single digit row must preserve its minimum hit width');
  } else {
    assert.deepEqual([plan.keypadColumns, plan.keypadRows], [size === 4 ? 2 : 3, 2]);
  }
  const numberHeight = plan.actionHeight - (plan.toolsHorizontal ? 54 : 0);
  if (size !== 9) assert.ok(numberHeight / plan.keypadRows >= 54 && numberHeight / plan.keypadRows <= 78,
    'Digit rows must stay comfortably tappable without consuming the entire page');
  assert.ok(plan.keyFontSize >= 22 && plan.keyFontSize <= 34, 'Digit font must be scaled within its legibility range');
}
function checkLayoutInvariants(implementation) {
  let gameCases = 0, homeCases = 0;
  const snapshots = [];
  for (const width of widths) for (const height of heights) {
    const availableWidth = Number.isFinite(width) && width > 0 ? width : 0;
    const availableHeight = Number.isFinite(height) && height > 0 ? height : 0;
    for (const coordinates of [false, true]) for (const multiSelect of [false, true]) for (const top of [false, true]) for (const size of [4, 6, 9]) {
      const plan = implementation.computeGameLayout(width, height, coordinates, multiSelect, top, size);
      checkKeypadContract(plan, size, top, coordinates, availableWidth, availableHeight);
      for (const [key, value] of Object.entries(plan)) {
        if (typeof value === 'number') assert.ok(Number.isFinite(value) && value >= 0, `Invalid ${key}: ${width}×${height}`);
      }
      assert.ok(plan.contentWidth <= availableWidth + 1e-6, 'Content overflows available width');
      assert.ok(plan.boardFrameWidth <= plan.contentWidth + 1e-6, 'Animated board overflows content width');
      assert.ok(plan.boardFrameHeight <= availableHeight + 1e-6, 'Animated board overflows available height');
      assert.ok(plan.boardWidth <= plan.boardFrameWidth + 1e-6);
      assert.ok(plan.boardHeight <= plan.boardFrameHeight + 1e-6);
      assert.ok(plan.controlWidth <= plan.contentWidth + 1e-6);
      if (plan.wide) assert.ok(plan.boardFrameWidth + plan.gap + plan.controlWidth <= plan.contentWidth + 1e-6,
        'Board and controls overlap or overflow in two-column mode');
      if (availableWidth === 0 || availableHeight === 0) assert.equal(plan.measured, false);
      gameCases++;
    }
    const home = implementation.computeHomeLayout(width, height);
    for (const value of Object.values(home)) if (typeof value === 'number') assert.ok(Number.isFinite(value) && value >= 0);
    assert.ok(home.contentWidth <= availableWidth + 1e-6);
    assert.ok(home.introWidth <= home.contentWidth + 1e-6 && home.optionsWidth <= home.contentWidth + 1e-6);
    if (home.wide) assert.ok(home.introWidth + home.optionsWidth + home.gap <= home.contentWidth + 1e-6);
    if (availableWidth === 0 || availableHeight === 0) assert.equal(home.measured, false);
    homeCases++;
  }
  for (const scenario of scenarios) {
    const game = implementation.computeGameLayout(scenario.width, scenario.height);
    const home = implementation.computeHomeLayout(scenario.width, scenario.height);
    assert.equal(game.wide, scenario.wide, scenario.name);
    assert.equal(home.wide, scenario.homeWide, scenario.name);
    assert.ok(game.boardWidth > 0 && game.actionHeight > 0 && home.optionsWidth > 0);
    snapshots.push({ name: scenario.name, availableWidth: scenario.width, availableHeight: scenario.height, game, home });
  }
  // 四键、六键保留原有的一排切换阈值；九键始终是三行。
  const rowBoundaries = [];
  for (const size of [4, 6]) {
    const boundaryWidth = size * 48 + 16;
    const below = implementation.computeGameLayout(boundaryWidth - 0.01, 700, false, false, false, size);
    const at = implementation.computeGameLayout(boundaryWidth, 700, false, false, false, size);
    const above = implementation.computeGameLayout(boundaryWidth + 0.01, 700, false, false, false, size);
    assert.equal(below.keypadRows, 2, `${size}-digit row must not switch early`);
    assert.equal(at.keypadRows, 1, `${size}-digit row must switch exactly at its touch-width boundary`);
    assert.equal(above.keypadRows, 1);
    assert.equal(at.keypadColumns, size);
    assert.ok(Math.abs(keypadTouchSize(at).width - 44) < 1e-6, 'Boundary digit hit target must be 44vp, not its padded slot width');
    rowBoundaries.push({ gridSize: size, contentWidth: size * 48, viewportWidth: boundaryWidth,
      belowRows: below.keypadRows, boundaryRows: at.keypadRows, touchTarget: keypadTouchSize(at) });
  }
  for (const invalid of [0, -1, 5, 9.5, NaN, Infinity]) {
    assert.deepEqual(normalized(implementation.computeGameLayout(393, 650, false, false, false, invalid)),
      normalized(implementation.computeGameLayout(393, 650)), 'Unsupported grid sizes must use the default 9-digit layout');
  }
  // 回归手机与折叠外屏底排截断，覆盖坐标轴、多选和全部题型尺寸。
  let sameScreenCases = 0, touchTargetCases = 0;
  for (const [width, height] of [[1264 / 2.75, 1466 / 2.75], [664, 836], [393, 650], [320, 650],
    [360, 650], [447.99, 700], [448, 700], [448.01, 700]]) {
    for (const coordinates of [false, true]) for (const multiSelect of [false, true])
      for (const top of [false, true]) for (const size of [4, 6, 9]) {
        const plan = implementation.computeGameLayout(width, height, coordinates, multiSelect, top, size);
        const occupiedHeight = plan.boardFrameHeight + plan.gap + plan.actionHeight + (multiSelect ? 40 : 0) + 4;
        assert.ok(!plan.wide && occupiedHeight <= height + 1e-6,
          `${width}x${height}, grid ${size}: normal phone/fold screen must show its bottom key row without scrolling`);
        const target = keypadTouchSize(plan);
        assert.ok(target.width >= 44 - 1e-6 && target.height >= 44 - 1e-6,
          `${width}x${height}, grid ${size}: digit touch target is only ${target.width}x${target.height}`);
        sameScreenCases++;
        touchTargetCases++;
      }
  }
  // 两栏扣除左侧工具宽度，不能把整个控制栏误当成数字键宽度。
  for (const width of [656, 664, 700, 780, 960]) for (const top of [false, true]) for (const size of [4, 6, 9]) {
    const plan = implementation.computeGameLayout(width, 400, false, false, top, size);
    assert.equal(plan.wide, true);
    const target = keypadTouchSize(plan);
    assert.ok(target.width >= 44 - 1e-6 && target.height >= 44 - 1e-6,
      `Landscape ${width}x400, top ${top}, grid ${size}: digit touch target is only ${target.width}x${target.height}`);
    touchTargetCases++;
  }
  const shortWindow = implementation.computeGameLayout(320, 220, true, true);
  const shortKey = keypadTouchSize(shortWindow);
  assert.ok(shortWindow.boardFrameHeight + shortWindow.actionHeight > 220 && shortKey.width >= 44 && shortKey.height >= 44,
    'A short split window should keep the controls at a usable size and let the game Scroll reach them');
  // Changing dimensions must not affect a later call with the original dimensions.
  const roomy = implementation.computeGameLayout(960, 650);
  const compact = implementation.computeGameLayout(656, 400);
  assert.ok(roomy.keyFontSize > compact.keyFontSize && keypadTouchSize(roomy).height > keypadTouchSize(compact).height,
    'A roomier side panel should enlarge both the number and its touch area');
  for (const size of [4, 6, 9]) {
    const before = implementation.computeGameLayout(393, 650, true, true, true, size);
    implementation.computeGameLayout(960, 720, true, true, true, size === 9 ? 4 : 9);
    assert.deepEqual(normalized(implementation.computeGameLayout(393, 650, true, true, true, size)), normalized(before));
  }
  // Regression: equal-width board/pad squares previously reduced this actual
  // 555vp phone body to a ~226vp playable board despite large side margins.
  const boardPriorityCases = [];
  for (const [width, height] of [[1080 / 2.75, 555], [393, 650], [664, 836], [840, 1000]]) {
    for (const coordinates of [false, true]) for (const multiSelect of [false, true]) {
      const plan = implementation.computeGameLayout(width, height, coordinates, multiSelect, false, 9);
      assert.ok(!plan.wide && plan.compactKeypad);
      const playableWidth = plan.boardWidth - (coordinates ? 18 : 0);
      const horizontalSlack = plan.contentWidth - plan.boardFrameWidth;
      const verticalSlack = height - (plan.boardFrameHeight + plan.gap + plan.actionHeight + (multiSelect ? 40 : 0) + 4);
      assert.ok(horizontalSlack <= 1 || verticalSlack <= 4 || plan.boardWidth >= 560,
        'A single-column board must use its width or height budget before leaving large empty margins');
      if (height === 555 && !multiSelect) assert.ok(playableWidth > 290,
        `The 555vp phone body needs a playable board over 290vp, got ${playableWidth}`);
      assert.equal(plan.boardFrameWidth, plan.boardWidth,
        'Single-column completion animation must stay inside the board instead of reserving empty margins');
      boardPriorityCases.push({ width, height, coordinates, multiSelect, playableWidth,
        keypadWidth: plan.stackedKeypadWidth, horizontalSlack, verticalSlack });
    }
  }
  const narrowFallbackCases = [];
  for (const width of [100, 152, 168, 208, 267.99, 268, 268.01]) {
    const plan = implementation.computeGameLayout(width, 650, true, false, false, 9);
    const target = keypadTouchSize(plan);
    const fallback = width < 268;
    assert.equal(plan.toolsHorizontal, fallback, 'The paired tool/keypad layout must switch before it overflows');
    assert.ok(target.width >= 48 && target.height >= 48);
    narrowFallbackCases.push({ width, toolsHorizontal: plan.toolsHorizontal,
      scrollRequired: plan.stackedKeypadWidth > plan.controlWidth, target });
  }
  for (const top of [false, true]) {
    assert.equal(implementation.computeGameLayout(960, 650, false, false, top).toolsHorizontal, true,
      'A saved old preference must never put landscape tools alongside the numbers');
    assert.equal(implementation.computeGameLayout(960, 1200, false, false, top).toolsHorizontal, top,
      'The persisted preference must remain effective for a wide portrait split layout');
  }
  return { gameCases, homeCases, snapshots, rowBoundaries, sameScreenCases, touchTargetCases,
    boardPriorityCases, narrowFallbackCases, foldUnfoldRoundTripPassed: true };
}
function checkHitTesting(implementation) {
  let cellCenters = 0, rejectedPoints = 0;
  for (const size of [4, 6, 9]) for (const width of [160, 283.7, 320, 512]) for (const height of [160, 301.5, 512]) {
    for (let row = 0; row < size; row++) for (let col = 0; col < size; col++) {
      // Generate the geometric center of each expected cell; no implementation rounding is copied.
      const x = 2 + (col + 0.5) * (width - 4) / size;
      const y = 2 + (row + 0.5) * (height - 4) / size;
      assert.equal(implementation.hitTestBoardCell(x, y, width, height, size, 2), row * size + col);
      cellCenters++;
    }
    assert.equal(implementation.hitTestBoardCell(2, 2, width, height, size, 2), 0);
    assert.equal(implementation.hitTestBoardCell(width - 2.001, height - 2.001, width, height, size, 2), size * size - 1);
    for (const [x, y] of [[-1, 20], [1, 20], [width - 2, 20], [20, 1], [20, height - 2], [NaN, 20], [20, Infinity]]) {
      assert.equal(implementation.hitTestBoardCell(x, y, width, height, size, 2), -1);
      rejectedPoints++;
    }
  }
  for (const size of [0, -1, 2.5, NaN, Infinity]) {
    assert.equal(implementation.hitTestBoardCell(20, 20, 320, 320, size, 2), -1);
    rejectedPoints++;
  }
  for (const dimension of [0, 4, -1, NaN, Infinity]) {
    assert.equal(implementation.hitTestBoardCell(20, 20, dimension, 320, 9, 2), -1);
    assert.equal(implementation.hitTestBoardCell(20, 20, 320, dimension, 9, 2), -1);
    rejectedPoints += 2;
  }
  assert.equal(implementation.hitTestBoardCell(0, 0, 90, 90, 9), 0);
  assert.equal(implementation.hitTestBoardCell(89.99, 89.99, 90, 90, 9), 80);
  assert.equal(implementation.hitTestBoardCell(90, 90, 90, 90, 9), -1);
  return { gridSizes: [4, 6, 9], cellCenters, rejectedPoints, borderAndResizeCasesPassed: true };
}
function getTypeScript() {
  for (const candidate of [process.env.SUDOKU_AUDIT_TYPESCRIPT, 'typescript',
    '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript'].filter(Boolean)) {
    try { return require(candidate); } catch (error) { if (error.code !== 'MODULE_NOT_FOUND') throw error; }
  }
  throw new Error('Set SUDOKU_AUDIT_TYPESCRIPT to an existing TypeScript package.');
}

// A real UITest tree from a normal-height, nine-digit portrait game. Use the actual
// clickable keys (inside the GridItem padding) and the safe-area-aware game Scroll.
function checkPortraitTree(file) {
  const tree = JSON.parse(fs.readFileSync(file, 'utf8'));
  const matches = [];
  const boards = [];
  const toolbars = [];
  function digitText(node) {
    if (node.attributes.type === 'Text' && node.attributes.text) return node.attributes.text;
    for (const child of node.children) {
      const text = digitText(child);
      if (text) return text;
    }
  }
  function visit(node, scroll) {
    if (node.attributes.type === 'Scroll') scroll = node;
    if (scroll && node.attributes.type === 'Grid' && node.children.length === 9) {
      if (node.children.every(item => item.attributes.type === 'GridItem' &&
          item.children.some(box => box.attributes.type === 'Grid' && box.children.length === 9))) {
        boards.push({ grid: node, scroll });
      }
      const keys = node.children.map(item => item.children.find(child => child.attributes.clickable === 'true'));
      if (keys.every((key, i) => key && digitText(key) === String(i + 1))) matches.push({ keys, scroll });
    }
    if (scroll && node.attributes.type === 'Grid' && [5, 6].includes(node.children.length) &&
      node.children.every(item => item.attributes.type === 'GridItem')) {
      const buttons = node.children.map(item => item.children.find(child => child.attributes.clickable === 'true'));
      if (buttons.every(button => button && digitText(button))) toolbars.push({ buttons, scroll });
    }
    for (const child of node.children) visit(child, scroll);
  }
  visit(tree, null);
  assert.equal(matches.length, 1, 'Expected one visible nine-digit keypad inside the game Scroll');
  assert.equal(boards.length, 1, 'Expected the board Grid with nine Sudoku boxes');
  assert.equal(toolbars.length, 1, 'Expected one game toolbar with five or six actions');
  assert.equal(boards[0].scroll, matches[0].scroll, 'Phone board and keypad must share the same scroll viewport');
  assert.equal(toolbars[0].scroll, matches[0].scroll, 'The toolbar must share the board/keypad scroll viewport');
  function rect(node) {
    const values = node.attributes.bounds.match(/-?\d+/g);
    assert.equal(values?.length, 4, 'Missing native bounds');
    return values.map(Number);
  }
  const screen = rect(tree);
  const viewport = rect(matches[0].scroll);
  const board = rect(boards[0].grid);
  const keys = matches[0].keys.map(rect);
  const tools = toolbars[0].buttons.map(rect);
  const pixelRatio = options.pixelRatio;
  const [left, top] = keys[0], [, , right, bottom] = keys[8];
  const rowHeight = keys[0][3] - top;
  assert.ok(screen[2] - screen[0] < screen[3] - screen[1], 'A portrait capture is required');
  const playableWidthVp = (board[2] - board[0]) / pixelRatio;
  const viewportWidthVp = (viewport[2] - viewport[0]) / pixelRatio;
  const viewportHeightVp = (viewport[3] - viewport[1]) / pixelRatio;
  if (viewportWidthVp >= 380 && viewportHeightVp >= 550) {
    assert.ok(playableWidthVp > 290,
      `A normal-height phone board must not shrink to keypad width; measured ${playableWidthVp}vp`);
  }
  assert.ok(Math.abs(board[2] - board[0] - (board[3] - board[1])) <= 2,
    'The playable board must remain square');
  keys.forEach(([x1, y1, x2, y2], i) => {
    assert.ok(x2 > x1 && y2 > y1 && Math.abs((x2 - x1) - (y2 - y1)) <= 2, `Digit ${i + 1} is not square`);
    assert.ok(Math.abs(y2 - y1 - rowHeight) <= 2, `Digit ${i + 1} does not share the other keys' size`);
    assert.ok(Math.min(x2 - x1, y2 - y1) >= 48 * pixelRatio - 2 &&
      Math.max(x2 - x1, y2 - y1) <= 68 * pixelRatio + 2,
      `Digit ${i + 1} must be a compact 48–68vp touch target`);
    const col = i % 3, row = Math.floor(i / 3);
    assert.ok(Math.abs(x1 - keys[col][0]) <= 1 && Math.abs(x2 - keys[col][2]) <= 1 &&
      Math.abs(y1 - keys[row * 3][1]) <= 1 && Math.abs(y2 - keys[row * 3][3]) <= 1,
      `Digit ${i + 1} is outside its row or column`);
    if (col) assert.ok(x1 >= keys[i - 1][2], 'Neighboring columns overlap');
    if (row) assert.ok(y1 >= keys[i - 3][3], 'Neighboring rows overlap');
  });
  assert.ok(left >= viewport[0] && right <= viewport[2] && top >= viewport[1], 'Keypad is clipped');
  assert.ok(board[1] >= viewport[1] && board[3] <= top, 'A normal portrait viewport must show the board above the keys');
  tools.forEach(([x1, y1, x2, y2], i) => {
    assert.ok(x1 >= viewport[0] && x2 <= viewport[2] && y1 >= board[3] && y2 <= bottom,
      'Toolbar actions must remain below the board and inside the safe controls area');
    assert.ok(x2 - x1 >= 44 * pixelRatio - 2 && y2 - y1 >= 44 * pixelRatio - 2,
      'Toolbar actions must keep a usable touch target');
    for (const other of [...tools.slice(0, i), ...keys]) {
      assert.ok(x2 <= other[0] || x1 >= other[2] || y2 <= other[1] || y1 >= other[3],
        'Tool and number touch targets must not overlap');
    }
  });
  const leftInset = left - viewport[0], rightInset = viewport[2] - right;
  const safeBottomGap = viewport[3] - bottom;
  const controls = [Math.min(left, ...tools.map(rect => rect[0])), Math.min(top, ...tools.map(rect => rect[1])),
    Math.max(right, ...tools.map(rect => rect[2])), Math.max(bottom, ...tools.map(rect => rect[3]))];
  const toolsBounds = [Math.min(...tools.map(rect => rect[0])), Math.min(...tools.map(rect => rect[1])),
    Math.max(...tools.map(rect => rect[2])), Math.max(...tools.map(rect => rect[3]))];
  assert.ok(Math.abs((controls[0] - viewport[0]) - (viewport[2] - controls[2])) <= 2,
    'The paired tool/keypad group must be centered independently of the board coordinate gutter');
  assert.ok(Math.abs(toolsBounds[1] - top) <= 2 && Math.abs(toolsBounds[3] - bottom) <= 2,
    'Portrait tools should share the number grid height');
  assert.ok(Math.abs(toolsBounds[2] - toolsBounds[0] - 92 * pixelRatio) <= 2,
    'The paired portrait tool grid must preserve two 44vp columns');
  assert.ok(controls[2] - controls[0] <= board[2] - board[0] + 2,
    'The normal portrait operation group should not be wider than the playable board');
  assert.ok(safeBottomGap > 0 && safeBottomGap <= rowHeight / 4,
    'The bottom row should sit close to the safe bottom edge with a small gap');
  return { file, pixelRatio, screen, viewport, board, playableWidthVp, tools, toolsBounds, controls,
    keys, leftInset, rightInset, safeBottomGap, leftHand: toolsBounds[0] >= right };
}

function checkSourceAnimationBounds() {
  const text = fs.readFileSync(path.join(adapter.sourceRoot, 'components/GameMainContent.ets'), 'utf8');
  const method = text.match(/private getBoardDisplayScale\(\): number \{[\s\S]*?\n  \}/);
  assert.ok(method, 'GameMainContent must own the bounded completion scale');
  const probeModule = loadPureModule(`export class Probe { wide: boolean = false; boardScale: number = 1;
    completionScale: number = 1; getLayout() { return { wide: this.wide }; }
    ${method[0].replace('private ', '')} }`);
  const probe = new probeModule.Probe();
  let cases = 0;
  for (const wide of [false, true]) for (const boardScale of [0.92, 1])
    for (const completionScale of [0.95, 1, 1.06]) {
      Object.assign(probe, { wide, boardScale, completionScale });
      const scale = probe.getBoardDisplayScale();
      assert.ok(scale > 0 && scale <= (wide ? 1.06 : 1), 'Completion animation must fit its reserved frame');
      cases++;
    }
  return { cases, portraitMaximum: 1, wideMaximum: 1.06 };
}
function inspectCompiledMethod(relative, methodName, bindings) {
  const ts = getTypeScript();
  const text = fs.readFileSync(path.join(options.compiledRoot, relative), 'utf8');
  const sourceFile = ts.createSourceFile(relative, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  assert.equal(sourceFile.parseDiagnostics.length, 0);
  const definitions = [], callers = [];
  function visit(node, owner) {
    if (ts.isClassDeclaration(node) || ts.isClassExpression(node)) owner = node;
    if (ts.isMethodDeclaration(node) && node.name.getText(sourceFile) === methodName) definitions.push({ method: node, owner });
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) &&
      node.expression.expression.kind === ts.SyntaxKind.ThisKeyword && node.expression.name.text === methodName) callers.push(owner);
    ts.forEachChild(node, child => visit(child, owner));
  }
  visit(sourceFile, undefined);
  assert.equal(definitions.length, 1, `${relative}: missing or duplicated compiled ${methodName}`);
  const { method, owner } = definitions[0];
  assert.ok(callers.length > 0 && callers.every(caller => caller === owner), `${relative}: calls without same-class method`);
  const context = { ...bindings };
  vm.createContext(context);
  vm.runInContext(adapter.getEsbuild().transformSync(`class Probe { ${method.getText(sourceFile)} }\nglobalThis.Probe=Probe;`,
    { loader: 'ts', target: 'node20' }).code, context);
  return { probe: new context.Probe(), evidence: { file: relative, method: methodName, calls: callers.length,
    generatedFileSha256: sha256(text), generatedMethodSha256: sha256(method.getText(sourceFile)) } };
}

const sourceResults = { layouts: checkLayoutInvariants(api), hitTesting: checkHitTesting(api),
  animationBounds: checkSourceAnimationBounds() };
let compiledResults = null;
if (options.compiledRoot) {
  const compiledSource = fs.readFileSync(path.join(options.compiledRoot, 'utils/AdaptiveLayout.ts'), 'utf8');
  const compiled = loadPureModule(compiledSource);
  compiledResults = { helperSha256: sha256(compiledSource), layouts: checkLayoutInvariants(compiled),
    hitTesting: checkHitTesting(compiled), methods: [] };
  const game = inspectCompiledMethod('components/GameMainContent.ts', 'getLayout', { computeGameLayout: compiled.computeGameLayout, GRID_SIZE: 9 });
  const home = inspectCompiledMethod('pages/Index.ts', 'getHomeLayout', { computeHomeLayout: compiled.computeHomeLayout });
  for (const scenario of [...scenarios, scenarios[0]]) {
    Object.assign(game.probe, { bodyWidth: scenario.width, bodyHeight: scenario.height,
      showCoordinates: true, isMultiSelectMode: true, auxButtonsOnTop: true });
    Object.assign(home.probe, { viewportWidth: scenario.width, viewportHeight: scenario.height });
    assert.deepEqual(normalized(game.probe.getLayout()), normalized(compiled.computeGameLayout(scenario.width, scenario.height, true, true, true, 9)));
    assert.deepEqual(normalized(home.probe.getHomeLayout()), normalized(compiled.computeHomeLayout(scenario.width, scenario.height)));
  }
  const actualBorderWidth = require(adapter.build()).GameConstants.Sizes.cellBorderBold;
  const touch = inspectCompiledMethod('components/SudokuBoard.ts', 'hitTestCellIndex',
    { hitTestBoardCell: compiled.hitTestBoardCell, GRID_SIZE: 9, Sizes: { cellBorderBold: actualBorderWidth } });
  for (const width of [320, 512, 283.7, 320]) {
    Object.assign(touch.probe, { boardWidth: width, boardHeight: width });
    assert.equal(touch.probe.hitTestCellIndex(width / 2, width / 2), 40);
    assert.equal(touch.probe.hitTestCellIndex(width - actualBorderWidth - 0.001, width - actualBorderWidth - 0.001), 80);
    assert.equal(touch.probe.hitTestCellIndex(width, width), -1);
  }
  compiledResults.methods = [game.evidence, home.evidence, touch.evidence];
  compiledResults.originalMethodsExecutedAfterResize = true;
}
const report = {
  scope: 'Pure layout/coordinate invariants and optional actual Hvigor-generated methods executed in Node. An optional portrait UITest tree verifies rendered key bounds. This script does not exercise live gestures or rotation.',
  sourceSha256: sha256(source), sourceResults, compiledVerified: Boolean(compiledResults),
  compiledRoot: options.compiledRoot || null, compiledResults,
  nativePortrait: options.portraitTree ? checkPortraitTree(options.portraitTree) : null,
  limitation: 'Core controls fit the checked normal phone and fold-cover viewports. Extremely short split windows may scroll; native rendering is verified separately.',
};
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ gameCases: sourceResults.layouts.gameCases, homeCases: sourceResults.layouts.homeCases,
  cellCenters: sourceResults.hitTesting.cellCenters, rejectedPoints: sourceResults.hitTesting.rejectedPoints,
  sameScreenCases: sourceResults.layouts.sameScreenCases, touchTargetCases: sourceResults.layouts.touchTargetCases,
  nativePortraitVerified: Boolean(report.nativePortrait), compiledVerified: report.compiledVerified,
  compiledMethods: compiledResults ? compiledResults.methods.length : 0, output }, null, 2));
