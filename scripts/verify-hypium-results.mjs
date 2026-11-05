import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

/** Fail closed: Hvigor may exit 0 and print BUILD SUCCESS with failed cases. */
export function verifyHypiumResults(report) {
  const summaries = [...report.matchAll(/^Tests run: (\d+), Failure: (\d+), Error: (\d+), Pass: (\d+), Ignore: (\d+)\s*$/gm)];
  if (summaries.length !== 1) throw new Error('Expected exactly one complete Hypium result summary.');
  const [total, failure, error, pass, ignore] = summaries[0].slice(1).map(Number);
  if (total === 0 || total !== failure + error + pass + ignore) {
    throw new Error('Hypium reported zero tests or inconsistent summary counts.');
  }
  const results = [...report.matchAll(/^result=(.*)$/gm)].map(match => match[1].trim());
  const counts = { Success: 0, Failure: 0, Error: 0, Ignore: 0 };
  for (const result of results) {
    if (!Object.hasOwn(counts, result)) throw new Error(`Unknown Hypium result status: ${result}`);
    counts[result] += 1;
  }
  if (results.length !== total || counts.Success !== pass || counts.Failure !== failure ||
      counts.Error !== error || counts.Ignore !== ignore) {
    throw new Error('Hypium case results do not match the summary; the report may be incomplete.');
  }
  if (failure || error || ignore) {
    throw new Error(`Hypium did not pass: ${failure} failed, ${error} errors, ${ignore} ignored, ${pass}/${total} passed.`);
  }
  return { total, pass };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if (!process.argv[2]) throw new Error('Usage: node scripts/verify-hypium-results.mjs <test_result.txt>');
    const result = verifyHypiumResults(readFileSync(process.argv[2], 'utf8'));
    console.log(`Hypium passed: ${result.pass}/${result.total} cases.`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
