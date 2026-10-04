const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFile } = require('node:child_process');
const { promisify } = require('node:util');

const run = promisify(execFile);
const root = path.resolve(__dirname, '..');

test('设置窗口居中在主窗口上，并完整显示在屏幕可见区域内', { skip: process.platform !== 'darwin' }, async () => {
  const { stdout: disk } = await run('/bin/df', ['-k', '/System/Volumes/Data']);
  const availableKiB = Number(disk.trim().split('\n').at(-1).trim().split(/\s+/)[3]);
  assert.ok(availableKiB >= 80 * 1024 * 1024, '80 GiB required before compiling native harness');
  const buildRoot = path.join(root, '.derivedData', 'settings-window-tests');
  fs.mkdirSync(buildRoot, { recursive: true });
  const directory = fs.mkdtempSync(path.join(buildRoot, 'settings-window-'));
  try {
    const executable = path.join(directory, 'SettingsWindowTest');
    const architecture = process.arch === 'arm64' ? 'arm64' : 'x86_64';
    await run('/usr/bin/xcrun', [
      'swiftc', '-parse-as-library', '-target', `${architecture}-apple-macosx13.0`,
      '-module-cache-path', path.join(directory, 'module-cache'),
      '-framework', 'AppKit', '-framework', 'WebKit', '-framework', 'StoreKit',
      path.join(root, 'macos', 'App.swift'), path.join(root, 'tests', 'mac-settings-window.swift'),
      '-o', executable
    ], { timeout: 60000, maxBuffer: 2 * 1024 * 1024 });
    const { stdout } = await run(executable, [], { timeout: 10000 }).catch(error => {
      assert.fail(error.stdout || error.stderr || error.message);
    });
    const result = JSON.parse(stdout.trim().split('\n').at(-1));
    assert.equal(result.ok, true, JSON.stringify(result));
    assert.equal(result.checks, 13);
    console.log(`settings window checks: ${result.checks}`);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
