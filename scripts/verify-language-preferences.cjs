'use strict';
// Run the actual language service and preference functions; substitute only platform boundaries.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const adapter = require('../docs/audit-2026-11-02/algorithm-build.cjs');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'entry/src/main/ets/utils');
const code = adapter.getEsbuild().buildSync({
  stdin: { contents: `export * from './LanguagePreferences.ets'; export * from './SettingsStorage.ets';`,
    resolveDir: source, loader: 'ts' },
  bundle: true, write: false, format: 'cjs', platform: 'node', target: 'node20',
  resolveExtensions: ['.ets', '.ts', '.js'], loader: { '.ets': 'ts' },
  external: ['@kit.AbilityKit', '@kit.ArkData', '@kit.LocalizationKit', '@kit.PerformanceAnalysisKit'],
}).outputFiles[0].text;

function harness(mode = 'system') {
  const durable = new Map([['languageMode', mode], ['themeMode', 'dark'], ['gestureGuideShown', true]]);
  const cache = new Map(durable), memory = new Map(), events = [], timers = [];
  const control = { locale: 'zh-Hans-CN', failFlush: 0, failApi: false, configUnavailable: false };
  const store = {
    getSync: (key, fallback) => cache.has(key) ? cache.get(key) : fallback,
    putSync: (key, value) => cache.set(key, value),
    flush: async () => {
      events.push('flush:' + cache.get('languageMode'));
      if (control.failFlush > 0) { control.failFlush--; throw new Error('disk busy'); }
      for (const [key, value] of cache) durable.set(key, value);
    },
  };
  const platform = {
    '@kit.ArkData': { preferences: { getPreferencesSync: () => store } },
    '@kit.LocalizationKit': { i18n: { System: { setAppPreferredLanguage(language) {
      events.push('native:' + language);
      if (control.failApi) throw new Error('native rejected');
      if (language !== 'default') control.locale = language;
    } } } },
    '@kit.PerformanceAnalysisKit': { hilog: { info() {}, warn() {}, error() {} } },
  };
  const context = {
    module: { exports: {} }, exports: {},
    AppStorage: { get: key => memory.get(key), setOrCreate: (key, value) => memory.set(key, value) },
    setTimeout: callback => { timers.push(callback); return timers.length; },
    require: name => { assert.ok(platform[name], 'Unexpected OS dependency ' + name); return platform[name]; },
  };
  vm.createContext(context); vm.runInContext(code, context);
  const api = context.module.exports;
  const host = { resourceManager: { getConfigurationSync() {
    if (control.configUnavailable) throw new Error('resource manager unavailable');
    return { locale: control.locale };
  } } };
  api.loadSettings(host);
  return { api, host, memory, durable, cache, events, timers, control };
}

const cases = [];
async function check(name, body) { await body(); cases.push(name); }
async function main() {
  await check('Chinese/English changes persist before native update and preserve unrelated settings', async () => {
    const h = harness();
    assert.equal(await h.api.setAppLanguage(h.host, 'en'), true);
    assert.deepEqual(h.events.slice(0, 2), ['flush:en', 'native:en']);
    assert.equal(h.durable.get('languageMode'), 'en'); assert.equal(h.memory.get('languageMode'), 'en');
    assert.equal(h.memory.get('languageRestartRequired'), false);
    assert.equal(h.memory.get('effectiveLocale'), 'en'); assert.equal(h.memory.get('localeRevision'), 1);
    assert.equal(h.durable.get('themeMode'), 'dark'); assert.equal(h.durable.get('gestureGuideShown'), true);
    assert.equal(await h.api.setAppLanguage(h.host, 'zh-Hans'), true);
    assert.equal(h.durable.get('languageMode'), 'zh-Hans'); assert.equal(h.memory.get('localeRevision'), 2);
  });
  await check('Follow-system clears native override with default and explicitly remains pending cold start', async () => {
    const h = harness('en'); h.control.locale = 'en';
    assert.equal(await h.api.setAppLanguage(h.host, 'system'), true);
    assert.deepEqual(h.events.slice(0, 2), ['flush:system', 'native:default']);
    assert.equal(h.memory.get('languageRestartRequired'), true);
    assert.equal(h.control.locale, 'en', 'Do not pretend default updated running resources');
    assert.equal(h.durable.get('languageMode'), 'system');
  });
  await check('Failed preference flush rolls back cached/durable choice without changing native language', async () => {
    const h = harness('zh-Hans'); h.control.failFlush = 1;
    assert.equal(await h.api.setAppLanguage(h.host, 'en'), false);
    assert.equal(h.cache.get('languageMode'), 'zh-Hans'); assert.equal(h.durable.get('languageMode'), 'zh-Hans');
    assert.equal(h.memory.get('languageMode'), 'zh-Hans'); assert.ok(!h.events.some(event => event.startsWith('native:')));
  });
  await check('Native API failure restores persisted previous choice and leaves UI selection unchanged', async () => {
    const h = harness('system'); h.control.failApi = true;
    assert.equal(await h.api.setAppLanguage(h.host, 'en'), false);
    assert.deepEqual(h.events, ['flush:en', 'native:en', 'flush:system']);
    assert.equal(h.durable.get('languageMode'), 'system'); assert.equal(h.memory.get('languageMode'), 'system');
    assert.equal(h.memory.get('languageRestartRequired'), undefined);
  });
  await check('Concurrent choices serialize and finish with the latest requested language', async () => {
    const h = harness();
    const results = await Promise.all([h.api.setAppLanguage(h.host, 'en'), h.api.setAppLanguage(h.host, 'zh-Hans')]);
    assert.ok(results.every(Boolean));
    assert.deepEqual(h.events, ['flush:en', 'native:en', 'flush:zh-Hans', 'native:zh-Hans']);
    assert.equal(h.durable.get('languageMode'), 'zh-Hans'); assert.equal(h.memory.get('languageMode'), 'zh-Hans');
  });
  await check('Invalid/same choices are no-ops; ordinary settings save does not overwrite language transaction', async () => {
    const h = harness('en');
    assert.equal(await h.api.setAppLanguage(h.host, 'bogus'), false);
    assert.equal(await h.api.setAppLanguage(h.host, 'en'), true); assert.equal(h.events.length, 0);
    h.memory.set('languageMode', 'system'); await h.api.saveSettings(h.host);
    assert.equal(h.durable.get('languageMode'), 'en');
  });
  await check('Cold load restores chosen language and clears only the pending restart notice', async () => {
    const h = harness('en'); h.memory.set('languageRestartRequired', true);
    h.api.initializeAppLanguage(h.host);
    assert.equal(h.memory.get('languageMode'), 'en'); assert.equal(h.events[0], 'native:en');
    assert.equal(h.memory.get('languageRestartRequired'), false); assert.equal(h.memory.get('effectiveLocale'), 'en');
    const system = harness(); system.api.initializeAppLanguage(system.host);
    assert.equal(system.events[0], 'native:default');
  });
  await check('Only effective locale changes advance revision; unavailable resources use configuration callback', async () => {
    const h = harness(); h.api.refreshLocaleRevision(h.host);
    const first = h.memory.get('localeRevision');
    h.api.refreshLocaleRevision(h.host); assert.equal(h.memory.get('localeRevision'), first);
    h.control.locale = 'en'; h.api.refreshLocaleRevision(h.host, 'en');
    assert.equal(h.memory.get('localeRevision'), first + 1);
    h.control.configUnavailable = true; h.api.refreshLocaleRevision(h.host, 'zh-Hans');
    assert.equal(h.memory.get('localeRevision'), first + 2);
  });
  console.log(JSON.stringify({ passed: cases.length, cases,
    sourceSha256: Object.fromEntries(['LanguagePreferences.ets', 'SettingsStorage.ets'].map(file =>
      [file, crypto.createHash('sha256').update(fs.readFileSync(path.join(source, file))).digest('hex')])),
    limitations: ['Real service/preference functions with platform stubs; native resource refresh and Preferences durability require device validation.',
      'OS API and Preferences are not one atomic transaction; a rollback write failure is logged and reported as failure.'] }, null, 2));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
