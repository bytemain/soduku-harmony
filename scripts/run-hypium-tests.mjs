import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { verifyHypiumResults } from './verify-hypium-results.mjs';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const reportPath = resolve(projectRoot, 'entry/.test/default/intermediates/test/coverage_data/test_result.txt');
const savedReport = resolve(projectRoot, 'test-results/native-unit-test-result.txt');

try {
  // Never accept a stale pass. Remove only known generated reports.
  rmSync(reportPath, { force: true });
  rmSync(savedReport, { force: true });
  const env = { ...process.env, HYPIUM_COMPILE_ONLY: '0' };
  const result = spawnSync(process.env.HVIGORW || 'hvigorw', [
    'test', '--mode', 'module', '-p', 'product=default', '--no-daemon'
  ], { cwd: projectRoot, env, stdio: 'inherit', shell: false });
  if (existsSync(reportPath)) {
    mkdirSync(dirname(savedReport), { recursive: true });
    copyFileSync(reportPath, savedReport);
  }
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Hvigor failed (exit ${result.status}, signal ${result.signal || 'none'}).`);
  if (!existsSync(reportPath)) throw new Error('No fresh Hypium report was produced; tests were not verified.');
  const verified = verifyHypiumResults(readFileSync(reportPath, 'utf8'));
  console.log(`Native unit tests passed: ${verified.pass}/${verified.total}. Report: test-results/native-unit-test-result.txt`);
} catch (error) {
  console.error(`Native unit test gate failed: ${error.message}`);
  process.exitCode = 1;
}
