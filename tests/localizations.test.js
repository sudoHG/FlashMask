const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');
const { execFile } = require('node:child_process');
const { promisify } = require('node:util');

const run = promisify(execFile);
const root = path.resolve(__dirname, '..');
const packer = path.join(root, 'scripts', 'package-localizations.py');
const buildRoot = path.join(root, '.derivedData', 'localization-tests');
const resourceFile = locale => path.join(root, 'src', 'localizations', `${locale}.json`);
const resource = locale => JSON.parse(fs.readFileSync(resourceFile(locale), 'utf8'));
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function temporary(prefix) {
  fs.mkdirSync(buildRoot, { recursive: true });
  return fs.mkdtempSync(path.join(buildRoot, prefix));
}
async function pack(repo, destination) {
  const args = [packer, '--repo-root', repo];
  if (destination) args.push('--resources', destination);
  const { stdout } = await run('/usr/bin/python3', args, { timeout: 10000 });
  return JSON.parse(stdout);
}
function copyResources(destination) {
  fs.mkdirSync(destination, { recursive: true });
  for (const locale of ['en', 'zh', 'ja']) fs.copyFileSync(resourceFile(locale), path.join(destination, `${locale}.json`));
}
// This three-language fixture deliberately stays isolated from any additional installed locales.
function fixtureRepo(destination) {
  copyResources(path.join(destination, 'src', 'localizations'));
  for (const locale of ['en', 'zh-Hans', 'ja']) {
    fs.cpSync(path.join(root, 'macos', `${locale}.lproj`), path.join(destination, 'macos', `${locale}.lproj`), { recursive: true });
  }
}

test('成对本地化资源完整，已审译文和既有中英文保持原文', async () => {
  const expectedHashes = {
    en: '18cd7956fd355ebc5e8ef4e869d6fff0056b078bf2a021011970a06e1924c51d',
    zh: '7d5e99dd97c49e1dec3d38ee0f502eeb03e8e0270ca090d704b9bf254286c4e7',
    ja: 'b33091ae5295798b201d636b8f1762620f8033e7f5c87e1cd09dc6466dca9f38'
  };
  for (const [locale, expected] of Object.entries(expectedHashes)) {
    assert.equal(hash(fs.readFileSync(resourceFile(locale))), expected, `${locale}: reviewed source changed`);
  }
  const validated = await pack(root);
  const actualResources = fs.readdirSync(path.join(root, 'src', 'localizations'))
    .filter(name => name.endsWith('.json'))
    .map(name => JSON.parse(fs.readFileSync(path.join(root, 'src', 'localizations', name), 'utf8')));
  const expectedKeys = Object.keys(resource('en').strings).sort();
  for (const actual of actualResources) {
    assert.deepEqual(Object.keys(actual.strings).sort(), expectedKeys);
    assert.ok(fs.existsSync(path.join(root, 'macos', `${actual.bundle_localization}.lproj`, 'InfoPlist.strings')));
  }
  assert.deepEqual(validated.locales, actualResources.map(value => value.locale).sort());
  assert.deepEqual(validated.bundle_localizations, actualResources.map(value => value.bundle_localization).sort());
  assert.equal(validated.keys_per_locale, 132);
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const messages = vm.runInNewContext(`(${/const messages = (\{[\s\S]+?\n    \});/.exec(html)[1]})`);
  const values = /const values = (\{[\s\S]+?\n      \});/.exec(html)[1];
  for (const locale of ['en', 'zh']) {
    const strings = resource(locale).strings;
    for (const [key, source] of Object.entries(messages[locale])) assert.equal(strings[`editor.${key}`], source);
    for (const [key, source] of Object.entries(vm.runInNewContext(`(${values})`, { english: locale === 'en' }))) {
      assert.equal(strings[`editor.${key}`], source);
    }
  }
  assert.equal(resource('en').strings['editor.aria.areaTabs'], 'Numbered areas');
  assert.equal(resource('en').strings['editor.aria.chooseLanguage'], 'Choose interface language');
});

test('同一打包器发现新增成对资源、拒绝缺项和变量变更，并清除派生包内旧语言', async () => {
  const directory = temporary('localization-package-');
  try {
    const source = path.join(directory, 'fixture-repo');
    fixtureRepo(source);
    const destination = path.join(directory, 'Fixture.app', 'Contents', 'Resources');
    const first = await pack(source, destination);
    assert.deepEqual(first.locales, ['en', 'ja', 'zh']);
    for (const locale of first.locales) {
      assert.equal(hash(fs.readFileSync(path.join(destination, 'src', 'localizations', `${locale}.json`))), hash(fs.readFileSync(resourceFile(locale))));
    }
    // Synthetic data tests discovery only; it is not a production French translation.
    const added = resource('ja');
    Object.assign(added, { locale: 'fr', native_name: 'Français', html_lang: 'fr', bundle_localization: 'fr' });
    const addedFile = path.join(source, 'src', 'localizations', 'fr.json');
    fs.writeFileSync(addedFile, JSON.stringify(added));
    fs.cpSync(path.join(source, 'macos', 'en.lproj'), path.join(source, 'macos', 'fr.lproj'), { recursive: true });
    assert.deepEqual((await pack(source, destination)).locales, ['en', 'fr', 'ja', 'zh']);
    assert.ok(fs.existsSync(path.join(destination, 'fr.lproj', 'InfoPlist.strings')));
    const before = hash(fs.readFileSync(path.join(destination, 'src', 'localizations', 'fr.json')));
    const cases = [
      value => { delete value.strings['editor.fit']; },
      value => { value.strings['native.version.withBuild'] += ' {build}'; },
      value => { value.strings['dynamic.regionLabel'] = '領域 {number}'; },
      value => { value.strings['editor.guideTitle'] += '<a>link</a>'; },
      value => { value.strings['editor.guideTitle'] += '<br>'; },
      value => { value.html_lang = 'ja'; }
    ];
    for (const mutate of cases) {
      const invalid = structuredClone(added);
      mutate(invalid);
      fs.writeFileSync(addedFile, JSON.stringify(invalid));
      await assert.rejects(pack(source, destination), /localization validation failed/);
      assert.equal(hash(fs.readFileSync(path.join(destination, 'src', 'localizations', 'fr.json'))), before);
    }
    fs.writeFileSync(addedFile, JSON.stringify(added));
    fs.rmSync(path.join(source, 'macos', 'fr.lproj'), { recursive: true });
    await assert.rejects(pack(source), /missing fr.lproj/);
    fs.rmSync(addedFile);
    await pack(source, destination);
    assert.equal(fs.existsSync(path.join(destination, 'fr.lproj')), false);
    assert.equal(fs.existsSync(path.join(destination, 'src', 'localizations', 'fr.json')), false);
    await assert.rejects(pack(source, source), /destination must be/);
    fs.writeFileSync(path.join(source, 'src', 'localizations', 'ja.json'), fs.readFileSync(resourceFile('ja'), 'utf8').replace('"locale": "ja"', '"locale": "ja", "locale": "ja"'));
    await assert.rejects(pack(source), /duplicate key: locale/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('原生在隔离的三语言 fixture 中读取、格式化、匹配地区与偏好', { skip: process.platform !== 'darwin' }, async () => {
  const { stdout: disk } = await run('/bin/df', ['-k', '/System/Volumes/Data']);
  const availableKiB = Number(disk.trim().split('\n').at(-1).trim().split(/\s+/)[3]);
  assert.ok(availableKiB >= 80 * 1024 * 1024, '80 GiB required before compiling native harness');
  const directory = temporary('localization-native-');
  try {
    const cases = path.join(directory, 'cases');
    const mutations = {
      valid: () => {},
      'missing-key': value => { delete value.strings['editor.fit']; },
      'different-key': value => { delete value.strings['editor.fit']; value.strings['editor.synthetic'] = 'Fixture'; },
      'wrong-token': value => { value.strings['dynamic.regionLabel'] = '領域 {number}'; },
      'duplicate-token': value => { value.strings['native.version.withBuild'] += ' {build}'; },
      'bad-html': value => { value.strings['editor.guideTitle'] += '<img>'; },
      'wrong-metadata': value => { value.bundle_localization = 'fr'; },
      'missing-english': () => {}
    };
    for (const [name, mutate] of Object.entries(mutations)) {
      const output = path.join(cases, name);
      copyResources(output);
      const japanese = resource('ja');
      mutate(japanese);
      fs.writeFileSync(path.join(output, 'ja.json'), JSON.stringify(japanese));
      if (name === 'missing-english') fs.rmSync(path.join(output, 'en.json'));
    }
    const bundle = path.join(directory, 'Native.app');
    const contents = path.join(bundle, 'Contents');
    const executable = path.join(contents, 'MacOS', 'LocalizationTest');
    fs.mkdirSync(path.dirname(executable), { recursive: true });
    fs.writeFileSync(path.join(contents, 'Info.plist'), `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LocalizationTest</string>
<key>CFBundleIdentifier</key><string>com.331workc.flashmask.localization-test</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
</dict></plist>`);
    const source = path.join(directory, 'fixture-repo');
    fixtureRepo(source);
    await pack(source, path.join(contents, 'Resources'));
    const architecture = process.arch === 'arm64' ? 'arm64' : 'x86_64';
    await run('/usr/bin/xcrun', [
      'swiftc', '-parse-as-library', '-target', `${architecture}-apple-macosx13.0`,
      '-module-cache-path', path.join(directory, 'module-cache'),
      '-framework', 'AppKit', '-framework', 'WebKit', '-framework', 'StoreKit',
      path.join(root, 'macos', 'App.swift'), path.join(root, 'tests', 'mac-localization.swift'),
      '-o', executable
    ], { timeout: 60000, maxBuffer: 2 * 1024 * 1024 });
    const { stdout } = await run(executable, [cases], { timeout: 10000 }).catch(error => {
      assert.fail(error.stdout || error.stderr || error.message);
    });
    const result = JSON.parse(stdout.trim());
    assert.equal(result.ok, true, JSON.stringify(result.failures));
    assert.deepEqual(result.locales, ['zh', 'en', 'ja']);
    assert.ok(result.checks >= 70);
    console.log(`native localization checks: ${result.checks}`);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
