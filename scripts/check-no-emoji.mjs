#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readdir, readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Keep the scanner and its fixtures free of literal emoji as well.
const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const excludedDirectories = new Set([
  '.git', '.hvigor', '.idea', '.preview', '.test', '.cache', '__pycache__',
  'node_modules', 'oh_modules', 'build', 'dist', 'coverage', 'test-results',
  'docs', 'release-artifacts',
]);
const excludedFiles = new Set([
  'website/deployment-verification.json', 'website/validation.json',
  'website/pages-preflight.json',
]);
const textExtensions = new Set([
  '.ets', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.json', '.json5',
  '.html', '.htm', '.css', '.scss', '.sass', '.less', '.svg', '.xml',
  '.yml', '.yaml', '.py', '.sh', '.bash', '.zsh', '.md', '.txt',
  '.toml', '.ini', '.conf', '.properties', '.example',
]);
const textFileNames = new Set(['Dockerfile', 'Makefile', '.gitignore', '.gitattributes', '.npmrc', '.ohpmrc']);
const escapedStringExtensions = new Set(['.ets', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.json', '.json5']);
const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
const emojiCharacter = /[\p{Extended_Pictographic}\p{Emoji_Presentation}\p{Regional_Indicator}\p{Emoji_Modifier}\uFE0F\u20E3]/u;
const plainCopyright = /^[\u00A9\u00AE\u2122]\uFE0E?$/u;

export function findEmoji(text) {
  const findings = [];
  for (const [lineIndex, line] of text.split(/\r?\n/u).entries()) {
    for (const { segment, index } of segmenter.segment(line)) {
      if (!emojiCharacter.test(segment) || plainCopyright.test(segment)) continue;
      findings.push({
        line: lineIndex + 1,
        column: [...line.slice(0, index)].length + 1,
        codePoints: [...segment].map(character => `U+${character.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')}`),
      });
    }
  }
  return findings;
}

// Inspect quoted values, not regular-expression declarations or comments. This
// catches escaped UI strings without treating the scanner's Unicode patterns as UI.
function stringRanges(text) {
  const ranges = [];
  let canStartRegex = true;
  let index = 0;
  while (index < text.length) {
    const character = text[index];
    if (/\s/u.test(character)) { index++; continue; }
    if (text.startsWith('//', index)) {
      const end = text.indexOf('\n', index + 2);
      index = end < 0 ? text.length : end;
      continue;
    }
    if (text.startsWith('/*', index)) {
      const end = text.indexOf('*/', index + 2);
      index = end < 0 ? text.length : end + 2;
      continue;
    }
    if (character === '"' || character === "'" || character === '`') {
      const start = ++index;
      while (index < text.length && text[index] !== character) {
        if (text[index] === '\\') index++;
        index++;
      }
      ranges.push([start, index]);
      index++;
      canStartRegex = false;
      continue;
    }
    if (character === '/' && canStartRegex) {
      index++;
      let inClass = false;
      while (index < text.length) {
        if (text[index] === '\\') { index += 2; continue; }
        if (text[index] === '[') inClass = true;
        if (text[index] === ']') inClass = false;
        if (text[index] === '/' && !inClass) { index++; break; }
        if (text[index] === '\n') break;
        index++;
      }
      while (/[a-z]/iu.test(text[index] ?? '')) index++;
      canStartRegex = false;
      continue;
    }
    if (/[a-z_$]/iu.test(character)) {
      const start = index++;
      while (/[\w$]/u.test(text[index] ?? '')) index++;
      canStartRegex = /^(return|throw|case|typeof|void|delete|yield|await|in|of)$/u.test(text.slice(start, index));
      continue;
    }
    canStartRegex = '([{:;,=!?&|+-*%^~<>'.includes(character);
    index++;
  }
  return ranges;
}

export function findEscapedEmoji(text) {
  const findings = [];
  for (const [start, end] of stringRanges(text)) {
    let decoded = '';
    const origins = [];
    const escaped = [];
    for (let index = start; index < end; index++) {
      const origin = index;
      let value = text[index];
      let unicodeEscape = false;
      if (value === '\\' && index + 1 < end) {
        const rest = text.slice(index, end);
        const braced = /^\\u\{([0-9a-f]{1,6})\}/iu.exec(rest);
        const fixed = /^\\u([0-9a-f]{4})/iu.exec(rest);
        const hex = /^\\x([0-9a-f]{2})/iu.exec(rest);
        const match = braced ?? fixed ?? hex;
        if (match && Number.parseInt(match[1], 16) <= 0x10FFFF) {
          value = String.fromCodePoint(Number.parseInt(match[1], 16));
          unicodeEscape = true;
          index += match[0].length - 1;
        } else {
          // Consume escaped backslashes together: a literal backslash followed
          // by uXXXX is text, not a Unicode escape executed by JavaScript/JSON.
          value = text[++index];
        }
      }
      decoded += value;
      for (let unit = 0; unit < value.length; unit++) {
        origins.push(origin);
        escaped.push(unicodeEscape);
      }
    }
    for (const { segment, index } of segmenter.segment(decoded)) {
      if (!emojiCharacter.test(segment) || plainCopyright.test(segment)) continue;
      if (!escaped.slice(index, index + segment.length).some(Boolean)) continue;
      const prefix = text.slice(0, origins[index]);
      findings.push({
        line: prefix.split('\n').length,
        column: [...prefix.slice(prefix.lastIndexOf('\n') + 1)].length + 1,
        codePoints: [...segment].map(character => `U+${character.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')}`),
        escaped: true,
      });
    }
  }
  return findings;
}

async function collectFiles(target, files) {
  const info = await stat(target);
  if (info.isFile()) {
    if (textExtensions.has(path.extname(target).toLowerCase()) || textFileNames.has(path.basename(target))) files.add(target);
    return;
  }
  if (!info.isDirectory()) return;
  for (const entry of await readdir(target, { withFileTypes: true })) {
    // Do not follow links into dependencies, signing directories or other trees.
    if (entry.isSymbolicLink()) continue;
    const child = path.join(target, entry.name);
    const relative = path.relative(repositoryRoot, child).split(path.sep).join('/');
    if (entry.isDirectory() && excludedDirectories.has(entry.name)) continue;
    if (excludedFiles.has(relative)) continue;
    await collectFiles(child, files);
  }
}

function selfTest() {
  const cp = (...points) => String.fromCodePoint(...points);
  const rejected = [
    cp(0x1F600), cp(0x1F44D, 0x1F3FD), cp(0x1F1E8, 0x1F1F3),
    cp(0x31, 0xFE0F, 0x20E3), cp(0x31, 0x20E3), cp(0xFE0F),
    cp(0x1F469, 0x200D, 0x1F4BB), cp(0x2600), cp(0x2699),
    cp(0x00A9, 0xFE0F), cp(0x00AE, 0xFE0F), cp(0x2122, 0xFE0F),
  ];
  for (const value of rejected) assert.ok(findEmoji(value).length > 0, 'Missed an emoji sequence');
  for (const value of ['中文 ABC 123 # *', cp(0x2192), cp(0x00A9), cp(0x00AE), cp(0x2122), cp(0x00A9, 0xFE0E), cp(0x200D)]) {
    assert.deepEqual(findEmoji(value), [], 'Rejected plain text');
  }
  assert.deepEqual(findEmoji(`first\nabc ${cp(0x1F600)}`), [{ line: 2, column: 5, codePoints: ['U+1F600'] }]);
  const slash = String.fromCharCode(0x5C);
  for (const source of [
    `const label = '${slash}u{1F600}';`,
    `{"value":"${slash}uD83D${slash}uDE00"}`,
    `const label = "${slash}u2699${slash}uFE0F";`,
    `const label = \`${slash}u{1F469}${slash}u200D${slash}u{1F4BB}\`;`,
    `const label = '1${slash}uFE0F${slash}u20E3';`,
    `const label = '${slash}u00A9${slash}uFE0F';`,
  ]) assert.ok(findEscapedEmoji(source).length > 0, 'Missed an escaped emoji string');
  for (const source of [
    `const pattern = /[${slash}u2600-${slash}u27FF]/u;`,
    `const label = '${slash}${slash}u{1F600}';`,
    `const label = '${slash}u00A9';`,
    `const label = '${slash}u00AE';`,
    `const label = '${slash}u2122';`,
    `// Example pattern ${slash}u{1F600}`,
  ]) assert.deepEqual(findEscapedEmoji(source), [], 'Misread a pattern or plain text as an escaped emoji');
  console.log('Emoji scanner self-test passed (raw/escaped sequences, text exceptions and locations).');
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help')) {
    console.log('Usage: node scripts/check-no-emoji.mjs [--self-test] [path ...]');
    console.log('Without paths, scans project-owned text from the repository root.');
    console.log('Dependencies, generated directories, docs and release evidence are excluded.');
    console.log('An explicitly named root is scanned, so use website/dist to check its handwritten static source.');
    return;
  }
  if (args.includes('--self-test')) selfTest();
  const paths = args.filter(argument => argument !== '--self-test');
  if (paths.some(argument => argument.startsWith('--'))) throw new Error('Unknown option; use --help');
  if (args.length === 1 && args[0] === '--self-test') return;
  const files = new Set();
  for (const target of paths.length ? paths : [repositoryRoot]) await collectFiles(path.resolve(target), files);
  if (files.size === 0) throw new Error('No source text files found; refusing an empty successful check');
  let count = 0;
  for (const file of [...files].sort()) {
    const text = await readFile(file, 'utf8');
    if (text.includes('\u0000')) continue;
    const findings = findEmoji(text);
    if (escapedStringExtensions.has(path.extname(file).toLowerCase())) findings.push(...findEscapedEmoji(text));
    for (const finding of findings) {
      console.error(`${path.relative(repositoryRoot, file)}:${finding.line}:${finding.column}: ${finding.codePoints.join(' ')}${finding.escaped ? ' (Unicode escape)' : ''}`);
      count++;
    }
  }
  console.log(`Scanned ${files.size} project text files; found ${count} emoji or emoji-style symbol sequences.`);
  if (count > 0) process.exitCode = 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => {
    console.error(`Emoji check failed: ${error.message}`);
    process.exitCode = 1;
  });
}
