const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { promisify } = require('node:util');
const run = promisify(require('node:child_process').execFile);
const contract = require('../src/flash-mask-contract.js');
const root = path.resolve(__dirname, '..');

async function createSyntheticImages(directory) {
  fs.mkdirSync(directory);
  const width = 120;
  const height = 80;
  const pixels = Uint8Array.from({ length: width * height }, (_, index) =>
    (Math.floor((index % width) / 20) + Math.floor(Math.floor(index / width) / 20)) % 2);
  const png = path.join(directory, 'synthetic.png');
  fs.writeFileSync(png, contract.encodeMaskPng(width, height, pixels));
  await run('/usr/bin/sips', ['-s', 'format', 'jpeg', png, '--out', path.join(directory, 'synthetic.jpeg')]);
  // Lossless 120 x 80 WebP of the same synthetic 20-pixel cells; no EXIF or XMP.
  // The system can decode WebP but does not provide a WebP encoder.
  const webp = Buffer.from('UklGRjYAAABXRUJQVlA4TCkAAAAvd8ATAA8w//M///MfeCCTtqmD+Xc5B7UwdkX0/woSUJ3JaWAmd6vPAAA=', 'base64');
  fs.writeFileSync(path.join(directory, 'synthetic.webp'), webp);
}

test('Mac WK/AppKit 本地化界面保持任务与输出，隔离偏好和剪贴板', { skip: process.platform !== 'darwin' }, async () => {
  const { stdout: disk } = await run('/bin/df', ['-k', '/System/Volumes/Data']);
  // Protects contributors' disks; hosted CI runners are disposable and smaller.
  if (!process.env.CI) assert.ok(Number(disk.trim().split('\n').at(-1).trim().split(/\s+/)[3]) >= 80 * 1024 * 1024, '80 GiB required before native UI build');
  const temporaryRoot = path.join(root, '.derivedData');
  fs.mkdirSync(temporaryRoot, { recursive: true });
  const directory = fs.mkdtempSync(path.join(temporaryRoot, 'localization-ui-'));
  const screenshots = path.join(directory, 'screenshots');
  fs.mkdirSync(screenshots);
  const bundleId = `com.331workc.flashmask.localization-ui-test.${crypto.randomUUID()}`;
  try {
    const bundle = path.join(directory, 'LocalizationUI.app');
    const contents = path.join(bundle, 'Contents');
    const resources = path.join(contents, 'Resources');
    const executable = path.join(contents, 'MacOS', 'LocalizationUI');
    const fixtures = path.join(directory, 'synthetic-images');
    await createSyntheticImages(fixtures);
    fs.mkdirSync(path.dirname(executable), { recursive: true });
    fs.mkdirSync(resources, { recursive: true });
    fs.copyFileSync(path.join(root, 'macos', 'Info.plist'), path.join(contents, 'Info.plist'));
    for (const [key, value] of [['CFBundleExecutable', 'LocalizationUI'], ['CFBundleIdentifier', bundleId]]) {
      await run('/usr/bin/plutil', ['-replace', key, '-string', value, path.join(contents, 'Info.plist')]);
    }
    const { stdout: discovery } = await run('/usr/bin/python3', [path.join(root, 'scripts', 'package-localizations.py'), '--repo-root', root, '--resources', resources]);
    const installed = JSON.parse(discovery).locales;
    for (const file of ['index.html', 'src/flash-mask-contract.js', 'src/selection-lasso-cleaner.js', 'assets/FlashMask-Mark.svg']) {
      fs.mkdirSync(path.dirname(path.join(resources, file)), { recursive: true });
      fs.copyFileSync(path.join(root, file), path.join(resources, file));
    }
    fs.copyFileSync(path.join(root, 'macos', 'FlashMask.icns'), path.join(resources, 'FlashMask.icns'));
    await run('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-target', `${process.arch === 'arm64' ? 'arm64' : 'x86_64'}-apple-macosx13.0`, '-module-cache-path', path.join(directory, 'module-cache'), '-framework', 'AppKit', '-framework', 'WebKit', '-framework', 'StoreKit', path.join(root, 'macos', 'App.swift'), path.join(root, 'tests', 'mac-localization-ui.swift'), '-o', executable], { timeout: 60000, maxBuffer: 2 * 1024 * 1024 });
    await run('/usr/bin/codesign', ['--force', '--sign', '-', bundle]);
    const args = [fixtures, screenshots];
    const emptyOnly = process.env.FLASH_MASK_LOCALIZATION_EMPTY_ONLY === '1';
    if (emptyOnly) args.push('--empty-only');
    const { stdout } = await run(executable, args, { timeout: 90000, maxBuffer: 2 * 1024 * 1024 });
    const result = JSON.parse(stdout.trim().split('\n').findLast(line => line.startsWith('{')));
    assert.equal(result.ok, true);
    assert.deepEqual([...result.locales].sort(), installed.sort());
    assert.equal(result.isolated_bundle_id, bundleId);
    assert.equal(result.apple_languages_unchanged, true);
    assert.ok(result.checks >= result.locales.length * 60);
    const empty = JSON.parse(fs.readFileSync(path.join(screenshots, 'empty-layout.json'), 'utf8'));
    assert.ok(empty.screens.length > 0, 'actual NSScreen metadata available');
    assert.equal(empty.layouts.length, installed.length * (4 + 2 * empty.screens.length));
    console.log(`empty guide: ${empty.layouts.length} layouts on ${empty.screens.length} screens`);
    if (emptyOnly) assert.equal(result.empty_only, true);
    else {
      assert.deepEqual(result.formats, ['png', 'jpeg', 'webp']);
      assert.equal(result.menu_escape, true);
      assert.equal(result.menu_outside, true);
      for (const format of result.formats) {
        assert.match(result.hashes[format].json_sha256, /^[a-f0-9]{64}$/);
        assert.match(result.hashes[format].png_sha256, /^[a-f0-9]{64}$/);
      }
      console.log(`native UI: ${result.checks} checks; locales=${result.locales.join(',')}; formats=${result.formats.join(',')}`);
    }
    if (process.env.FLASH_MASK_KEEP_LOCALIZATION_SCREENSHOTS === '1') {
      console.log(`screenshots retained: ${path.relative(root, screenshots)}`);
    }
  } catch (error) {
    const message = [error.message, error.stdout, error.stderr].filter(Boolean).join('\n').split(root).join('.');
    throw new Error(message);
  } finally {
    await run('/usr/bin/defaults', ['delete', bundleId]).catch(() => {});
    if (process.env.FLASH_MASK_KEEP_LOCALIZATION_SCREENSHOTS === '1') {
      for (const name of fs.readdirSync(directory)) if (name !== 'screenshots') fs.rmSync(path.join(directory, name), { recursive: true, force: true });
    } else fs.rmSync(directory, { recursive: true, force: true });
  }
});
