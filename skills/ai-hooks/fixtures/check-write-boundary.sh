#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
mkdir -p ai-factory/runs/tmp
FIXTURE=$(mktemp -d "$PWD/ai-factory/runs/tmp/write-boundary.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT
node - "$PWD" "$FIXTURE" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn, spawnSync, execFileSync } = require('node:child_process');
const [source, scratch] = process.argv.slice(2);
const scripts = path.join(source, 'skills/ai-hooks/scripts');
const transcript = path.join(source, 'skills/ai-hooks/fixtures/transcript-uuid.jsonl');
let serial = 0, passed = 0;
const outside = path.join(scratch, 'outside');
fs.mkdirSync(outside);
const sentinel = path.join(outside, 'sentinel');
fs.writeFileSync(sentinel, 'untouched');
const originalOutside = () => assert.deepEqual(fs.readdirSync(outside), ['sentinel']);
function repo() {
  const root = path.join(scratch, `repo-${++serial}`);
  fs.mkdirSync(path.join(root, 'ai-factory/runs'), { recursive: true });
  execFileSync('git', ['init', '-q', root]);
  return root;
}
function event(root, extra = {}) {
  return { cwd: root, session_id: 'fixture', prompt: '/t4:run step 1', transcript_path: transcript,
    agent_transcript_path: transcript, agent_id: 'worker', agent_type: 'implementer',
    tool_input: { file_path: 'src/file.js', command: 'npm test && git commit -m check' }, ...extra };
}
function run(name, root, extra = {}, blocked = true) {
  const result = spawnSync(process.execPath, [path.join(scripts, name)], { input: JSON.stringify(event(root, extra)), encoding: 'utf8' });
  assert.equal(result.status, 0, `${name}: logging must not fail the user's turn: ${result.stderr}`);
  assert.equal(result.stdout, '', `${name}: stdout pollution`);
  if (blocked) assert.match(result.stderr, /Hook write declined:/, `${name}: missing diagnostic`);
  else assert.equal(result.stderr, '', `${name}: ${result.stderr}`);
  assert.equal(fs.readFileSync(sentinel, 'utf8'), 'untouched');
  originalOutside();
  passed++;
}
const writers = ['session-start.js', 'log-task.js', 'log-cmd.js', 'log-edit.js', 'session-stop.js', 'subagent-stop.js', 'log-flush.js'];
for (const name of writers) {
  for (const ancestor of ['ai-factory', 'ai-factory/runs']) {
    const root = repo();
    fs.rmSync(path.join(root, ancestor), { recursive: true });
    fs.symlinkSync(outside, path.join(root, ancestor));
    run(name, root);
  }
}
for (const [name, leaf] of [['session-start.js','sessions.jsonl'],['log-task.js','.task.fixture'],['log-cmd.js','cmds.jsonl'],['log-edit.js','edits.jsonl'],['session-stop.js','.task.fixture'],['session-stop.js','.counted.fixture'],['session-stop.js','log.pending.csv'],['session-stop.js','log.previous.csv'],['subagent-stop.js','.counted.fixture'],['log-flush.js','log.csv'],['log-flush.js','log.pending.csv'],['log-flush.js','log.previous.csv']]) {
  const root = repo();
  fs.symlinkSync(sentinel, path.join(root, 'ai-factory/runs', leaf));
  run(name, root);
}
for (const session_id of ['../escape', '../../outside/sentinel', 'a/b', 'a\\b', '..', 'x\nforged', { bad: true }]) {
  for (const name of ['log-task.js','session-stop.js','subagent-stop.js']) run(name, repo(), { session_id });
}
run('subagent-stop.js', repo(), { agent_id: 'a\nforged' });
const hard = repo();
fs.linkSync(sentinel, path.join(hard, 'ai-factory/runs/edits.jsonl'));
run('log-edit.js', hard);
fs.unlinkSync(path.join(hard, 'ai-factory/runs/edits.jsonl'));
// A rejected output is checked before tokens are claimed; retry keeps the accounting.
const retry = repo(), retryRuns = path.join(retry, 'ai-factory/runs');
fs.symlinkSync(sentinel, path.join(retryRuns, 'log.pending.csv'));
run('session-stop.js', retry);
assert.equal(fs.existsSync(path.join(retryRuns, '.counted.fixture')), false);
fs.unlinkSync(path.join(retryRuns, 'log.pending.csv'));
run('session-stop.js', retry, {}, false);
assert.equal(fs.readFileSync(path.join(retryRuns, 'log.pending.csv'), 'utf8').trim().split('\n').length, 2);
// Existing log migration must reject an unsafe archive before rewriting a source file.
const migration = repo(), migrationRuns = path.join(migration, 'ai-factory/runs');
fs.writeFileSync(path.join(migrationRuns, 'log.pending.csv'), 'old,header\nold,row\n');
fs.symlinkSync(sentinel, path.join(migrationRuns, 'log.previous.csv'));
run('session-stop.js', migration);
assert.equal(fs.readFileSync(path.join(migrationRuns, 'log.pending.csv'), 'utf8'), 'old,header\nold,row\n');
// The standalone headless schema writer enforces the same rules.
const headless = path.join(source, 'skills/ai-layout/templates/ai-factory/make/log.js');
for (const leaf of ['log.csv', 'log.previous.csv']) {
  const root = repo(), runs = path.join(root, 'ai-factory/runs');
  const output = path.join(runs, 'run.json');
  fs.writeFileSync(output, '{"usage":{"input_tokens":1}}');
  fs.symlinkSync(sentinel, path.join(runs, leaf));
  const result = spawnSync(process.execPath, [headless, output, 'run', 'claude'], { cwd: root, encoding: 'utf8' });
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
  assert.equal(fs.readFileSync(sentinel, 'utf8'), 'untouched');
  passed++;
}
const normal = repo();
for (const name of writers.slice(0, 6)) run(name, normal, {}, false);
assert.equal(fs.statSync(path.join(normal, 'ai-factory/runs/.task.fixture')).mode & 0o777, 0o600);
assert.equal(fs.existsSync(path.join(normal, 'ai-factory/runs/.hook-lock')), false);
// Concurrent Stops sharing one session count each transcript record exactly once.
async function concurrent() {
  const root = repo();
  const results = await Promise.all(Array.from({ length: 8 }, () => new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [path.join(scripts, 'session-stop.js')]);
    let stdout = '', stderr = '';
    child.stdout.on('data', data => stdout += data);
    child.stderr.on('data', data => stderr += data);
    child.on('error', reject);
    child.on('close', status => resolve({ status, stdout, stderr }));
    child.stdin.end(JSON.stringify(event(root)));
  })));
  for (const result of results) assert.deepEqual(result, { status: 0, stdout: '', stderr: '' });
  const rows = fs.readFileSync(path.join(root, 'ai-factory/runs/log.pending.csv'), 'utf8').trim().split('\n');
  assert.equal(rows.length, 2, 'concurrent events must not duplicate accounting rows');
  assert.equal(fs.existsSync(path.join(root, 'ai-factory/runs/.hook-lock')), false);
  passed++;
  // The standalone runner must use the same lock as hook accounting. A flush waits
  // for an active hook, then includes the row written while it was waiting.
  const makeDir = path.join(root, 'ai-factory/make');
  fs.cpSync(path.join(source, 'skills/ai-layout/templates/ai-factory/make'), makeDir, {recursive:true});
  const {withLogLock} = require(path.join(scripts, '_safe-files.js'));
  let flushDone;
  withLogLock(path.join(root, 'ai-factory'), safe => {
    const child = spawn(process.execPath, [path.join(makeDir, 'runner.js'), 'log-flush'], {cwd:root});
    flushDone = new Promise((resolve, reject) => {
      let stderr = '';
      child.stderr.on('data', b => stderr += b);
      child.on('error', reject);
      child.on('close', status => resolve({status, stderr}));
    });
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 200);
    const pending = path.join(root, 'ai-factory/runs/log.pending.csv');
    assert(fs.existsSync(pending), 'runner must not flush while a hook owns the lock');
    safe.append(pending, rows[1] + '\n');
  });
  assert.deepEqual(await flushDone, {status:0, stderr:''});
  assert.equal(fs.readFileSync(path.join(root, 'ai-factory/runs/log.csv'), 'utf8').trim().split('\n').length, 3);
  assert.equal(fs.existsSync(path.join(root, 'ai-factory/runs/log.pending.csv')), false);
  assert.equal(fs.existsSync(path.join(root, 'ai-factory/runs/.hook-lock')), false);
  passed++;
  assert.equal(fs.readFileSync(path.join(scripts, '_safe-files.js'), 'utf8'), fs.readFileSync(path.join(source, 'skills/ai-layout/templates/ai-factory/make/safe-files.js'), 'utf8'));
  console.log(`write boundary ok — ${passed} cases, external sentinels unchanged, concurrency and safe retry verified`);
}
concurrent().catch(error => { console.error(error); process.exitCode = 1; });
NODE
