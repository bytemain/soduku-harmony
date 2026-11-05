import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyHypiumResults } from './verify-hypium-results.mjs';

const passing = 'class=Example\ntest=one\nresult=Success\ntest=two\nresult=Success\nTests run: 2, Failure: 0, Error: 0, Pass: 2, Ignore: 0\n';

test('accepts complete all-passing LF and CRLF reports', () => {
  assert.deepEqual(verifyHypiumResults(passing), { total: 2, pass: 2 });
  assert.deepEqual(verifyHypiumResults(passing.replaceAll('\n', '\r\n')), { total: 2, pass: 2 });
});
test('rejects failed cases even if Hvigor prints BUILD SUCCESS', () => {
  const report = passing.replace('result=Success', 'result=Failure')
    .replace('Failure: 0', 'Failure: 1').replace('Pass: 2', 'Pass: 1') + 'BUILD SUCCESS\n';
  assert.throws(() => verifyHypiumResults(report), /1 failed/);
});
test('rejects absent, truncated, duplicated, empty and inconsistent reports', () => {
  const invalid = [
    '', 'BUILD SUCCESS', passing.replace(/Tests run:.*/, ''), passing + passing,
    'Tests run: 0, Failure: 0, Error: 0, Pass: 0, Ignore: 0\n',
    passing.replace('Pass: 2', 'Pass: 3'), passing.replace('result=Success\n', ''),
    passing.replace('result=Success', 'result=Unknown')
  ];
  for (const report of invalid) assert.throws(() => verifyHypiumResults(report));
});
test('rejects ignored tests and errors', () => {
  for (const status of ['Ignore', 'Error']) {
    const report = passing.replace('result=Success', `result=${status}`)
      .replace(`${status}: 0`, `${status}: 1`).replace('Pass: 2', 'Pass: 1');
    assert.throws(() => verifyHypiumResults(report), /Hypium did not pass/);
  }
});
