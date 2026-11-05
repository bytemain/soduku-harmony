import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, copyFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const scripts = dirname(fileURLToPath(import.meta.url));
const validReport = 'test=one\nresult=Success\nTests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0\n';
const failedReport = validReport.replace('result=Success', 'result=Failure').replace('Failure: 0', 'Failure: 1').replace('Pass: 1', 'Pass: 0');

test('runner rejects stale/missing reports and false-green Hvigor exits, and preserves fresh reports', () => {
  const root = mkdtempSync(join(tmpdir(), 'hypium-gate-test-'));
  try {
    mkdirSync(join(root, 'scripts'));
    for (const name of ['run-hypium-tests.mjs', 'verify-hypium-results.mjs']) {
      copyFileSync(join(scripts, name), join(root, 'scripts', name));
    }
    const report = join(root, 'entry/.test/default/intermediates/test/coverage_data/test_result.txt');
    const saved = join(root, 'test-results/native-unit-test-result.txt');
    mkdirSync(dirname(report), { recursive: true });
    const fakeHvigor = join(root, 'hvigor-fixture');
    for (const scenario of [
      { text: null, exit: 0, expected: 1 },
      { text: failedReport, exit: 0, expected: 1 },
      { text: validReport, exit: 1, expected: 1 },
      { text: validReport, exit: 0, expected: 0 }
    ]) {
      writeFileSync(report, validReport); // Simulate a stale earlier pass.
      const write = scenario.text === null ? '' : `fs.writeFileSync(${JSON.stringify(report)}, ${JSON.stringify(scenario.text)});`;
      writeFileSync(fakeHvigor, `#!${process.execPath}\nconst fs = require('node:fs');\nif(process.env.HYPIUM_COMPILE_ONLY !== '0')process.exit(9);\n${write}\nconsole.log('BUILD SUCCESS');\nprocess.exit(${scenario.exit});\n`, { mode: 0o700 });
      const result = spawnSync(process.execPath, [join(root, 'scripts/run-hypium-tests.mjs')], {
        encoding: 'utf8', env: { ...process.env, HVIGORW: fakeHvigor, HYPIUM_COMPILE_ONLY: '1' }
      });
      assert.equal(result.status, scenario.expected, result.stdout + result.stderr);
      assert.equal(existsSync(saved), scenario.text !== null);
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
