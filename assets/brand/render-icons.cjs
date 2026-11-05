'use strict';
// Render original vector sources; no existing raster artwork is read or edited.
const fs = require('node:fs');
const path = require('node:path');
const repo = path.resolve(__dirname, '../..');
function loadSharp() {
  const candidates = [process.env.SUDOKU_SHARP, 'sharp',
    '/opt/homebrew/lib/node_modules/wrangler/node_modules/sharp',
    '/usr/local/lib/node_modules/wrangler/node_modules/sharp'].filter(Boolean);
  for (const candidate of candidates) {
    try { return require(candidate); } catch (_) {}
  }
  throw new Error('Set SUDOKU_SHARP to an existing sharp package path. No packages are installed automatically.');
}
async function render() {
  const sharp = loadSharp();
  const foreground = path.join(__dirname, 'sudoku-foreground.svg');
  const background = path.join(__dirname, 'sudoku-background.svg');
  const outputs = [];
  async function png(source, target, size) {
    await sharp(source).resize(size, size).png().toFile(target);
    outputs.push({ file: path.relative(repo, target), size });
  }
  for (const relative of ['AppScope/resources/base/media', 'entry/src/main/resources/base/media']) {
    const dir = path.join(repo, relative);
    await png(foreground, path.join(dir, 'foreground.png'), 1024);
    await png(background, path.join(dir, 'background.png'), 1024);
  }
  // The composed app layers must be pixel-identical to the store icon.
  const media = path.join(repo, 'AppScope/resources/base/media');
  const composed = await sharp(path.join(media, 'background.png'))
    .composite([{ input: path.join(media, 'foreground.png') }]).raw().toBuffer();
  const storeFile = path.join(__dirname, 'sudoku-icon-1024.png');
  await sharp(path.join(media, 'background.png'))
    .composite([{ input: path.join(media, 'foreground.png') }]).png().toFile(storeFile);
  outputs.push({ file: path.relative(repo, storeFile), size: 1024 });
  // In-app/start-window artwork can be transparent; launcher/store background
  // remains the solid ivory layer required by HarmonyOS icon design guidance.
  await png(foreground, path.join(repo, 'entry/src/main/resources/base/media/startIcon.png'), 144);
  await png(foreground, path.join(__dirname, 'sudoku-mark-1024.png'), 1024);
  const store = await sharp(storeFile).raw().toBuffer();
  if (!composed.equals(store)) throw new Error('Layered app icon differs from store icon.');
  for (const name of ['foreground.png', 'background.png']) {
    const first = fs.readFileSync(path.join(repo, 'AppScope/resources/base/media', name));
    const second = fs.readFileSync(path.join(repo, 'entry/src/main/resources/base/media', name));
    if (!first.equals(second)) throw new Error(`AppScope and entry differ: ${name}`);
  }
  console.log(JSON.stringify({ sharp: sharp.versions.sharp, svgRenderer: sharp.versions.rsvg,
    originalVectorArtwork: true, appAndStorePixelsMatch: true, outputs }, null, 2));
}
render().catch(error => { console.error(error); process.exitCode = 1; });
