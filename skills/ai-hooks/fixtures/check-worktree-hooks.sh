#!/usr/bin/env bash
# Hooks inside a /t4:loop worktree (spec 0022, AC35-AC38), with real `git worktree` fixtures.
# A loop worktree lives at <main>/ai-factory/runs/tmp/worktrees/<loop-id>-S<N>. The guard allows
# edits inside it unless the worktree-relative path matches dont-touch.md; every other path under
# runs/ stays blocked; run-log rows, task markers and lifecycle events land in the main repo's
# ai-factory/runs/; and no hook reads or writes the worktree subtree from the main tree.
set -euo pipefail
cd "$(dirname "$0")/../../.."
mkdir -p ai-factory/runs/tmp
FIXTURE=$(mktemp -d "$PWD/ai-factory/runs/tmp/worktree-hooks.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT
node - "$PWD" "$FIXTURE" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const [source, scratchRaw] = process.argv.slice(2);
const scratch = fs.realpathSync(scratchRaw);
const scripts = path.join(source, 'skills/ai-hooks/scripts');
const fixtures = path.join(source, 'skills/ai-hooks/fixtures');
const policy = '# Do not edit\n- `.env`\n- `LICENSE`\n- `ai-factory/runs/`\n- `ai-factory/make/`\n';
const git = (cwd, ...args) => execFileSync('git', ['-c', 'user.name=fixture', '-c', 'user.email=fixture@invalid',
  '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', ...args], { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();

// The main repository and one loop worktree, laid out exactly as loop.js creates them.
function setup(name) {
  const main = path.join(scratch, name);
  fs.mkdirSync(main, { recursive: true });
  git(main, 'init', '-q');
  const files = {
    '.gitignore': 'ai-factory/runs/tmp/\nai-factory/runs/*.jsonl\nai-factory/runs/log.pending.csv\nai-factory/runs/.task.*\nai-factory/runs/.counted.*\nai-factory/runs/lifecycle/\n',
    'ai-factory/docs/dont-touch.md': policy,
    'ai-factory/runs/log.csv': 'tracked\n',
    'ai-factory/plans/0001-a.md': '# A\n\n- [ ] Step 1 — a\n',
    'ai-factory/contracts/config.json': JSON.stringify({ schema: 't4-contracts-config', version: 1, code_scope: { include: ['**'] }, lifecycle: { enabled: true } }),
    'src/a.js': 'module.exports = 1;\n',
    'LICENSE': 'MIT\n',
  };
  for (const [file, body] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(main, file)), { recursive: true });
    fs.writeFileSync(path.join(main, file), body);
  }
  git(main, 'add', '-A');
  git(main, 'commit', '-q', '--no-verify', '-m', 'fixture');
  const wt = path.join(main, 'ai-factory/runs/tmp/worktrees/L1-S1');
  git(main, 'worktree', 'add', '-q', '-b', 't4-loop/L1/S1', wt, 'HEAD');
  assert.equal(fs.lstatSync(path.join(wt, '.git')).isFile(), true, 'worktree .git must be a file');
  return { main, wt };
}

function hook(name, ev) {
  const result = spawnSync(process.execPath, [path.join(scripts, name)], { input: JSON.stringify(ev), encoding: 'utf8' });
  assert.equal(result.stdout, '', `${name}: stdout must stay empty, got ${JSON.stringify(result.stdout)}`);
  return result;
}
function guard(cwd, target, expected, label = target) {
  const result = hook('guard-paths.js', { cwd, tool_name: 'Write', tool_input: { file_path: target } });
  assert.equal(result.status, expected, `guard ${label} from ${path.relative(scratch, cwd)}: expected ${expected}, got ${result.status}: ${result.stderr.trim()}`);
  if (expected === 2) assert.match(result.stderr, /^Blocked by /, `guard ${label}: missing block reason`);
  else assert.equal(result.stderr, '', `guard ${label}: ${result.stderr}`);
}
function logHook(name, ev) {
  const result = hook(name, ev);
  assert.equal(result.status, 0, `${name}: ${result.stderr}`);
  assert.equal(result.stderr, '', `${name}: ${result.stderr}`);
}
function listing(dir) {
  const out = [];
  (function walk(d) {
    for (const entry of fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(d, entry.name);
      if (entry.isDirectory()) { if (entry.name !== '.git') walk(full); }
      else out.push(`${path.relative(dir, full)}:${entry.isSymbolicLink() ? 'link:' + fs.readlinkSync(full) : fs.readFileSync(full, 'utf8')}`);
    }
  })(dir);
  return out;
}

const cases = [];
const test = (name, fn) => cases.push([name, fn]);

test('guard-allows-worktree-edit', () => {
  const { main, wt } = setup('allow');
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/src/a.js', 0);
  guard(main, path.join(wt, 'src/a.js'), 0, 'absolute src/a.js');
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/src/new/b.js', 0);
  guard(wt, 'src/a.js', 0);
  guard(wt, path.join(wt, 'src/a.js'), 0, 'absolute src/a.js');
  guard(path.join(wt, 'src'), 'a.js', 0, 'a.js from worktree subdir');
});

test('guard-blocks-worktree-dont-touch', () => {
  const { main, wt } = setup('dont-touch');
  for (const rest of ['.env', 'ai-factory/runs/x', 'LICENSE', 'src/.env.local', 'ai-factory/make/ai.mk']) {
    guard(main, `ai-factory/runs/tmp/worktrees/L1-S1/${rest}`, 2);
    guard(main, path.join(wt, rest), 2, `absolute ${rest}`);
    guard(wt, rest, 2);
  }
});

test('guard-still-blocks-runs', () => {
  const { main } = setup('runs');
  for (const target of ['ai-factory/runs/log.csv', 'ai-factory/runs/tmp/other', 'ai-factory/runs/tmp/worktrees',
    'ai-factory/runs/tmp/worktrees/L1-S1', 'ai-factory/runs/tmp/worktrees/L1-S1/', 'ai-factory/runs/tmp/worktrees/stray/src/a.js',
    'ai-factory/runs/tmp/worktrees/stray/.git'])
    guard(main, target, 2);
});

// Added beyond the plan's list: AC36 from inside the worktree, where the guard must still see
// the main repository's runs/ (relative to the worktree, those paths are outside its root).
test('guard-blocks-main-runs-from-worktree', () => {
  const { main, wt } = setup('runs-from-wt');
  guard(wt, path.join(main, 'ai-factory/runs/log.csv'), 2, 'main runs/log.csv');
  guard(wt, '../../../../runs/log.csv', 2, 'relative escape to main runs/log.csv');
  guard(wt, '../L1-S2/src/a.js', 2, 'sibling non-worktree directory');
  fs.symlinkSync(path.join(main, 'ai-factory/runs'), path.join(wt, 'esc'));
  guard(wt, 'esc/log.csv', 2, 'symlinked escape from worktree cwd');
});

test('guard-blocks-traversal', () => {
  const { main, wt } = setup('traversal');
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/../../log.csv', 2);
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/../../../log.csv', 2);
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/src/../../L1-S1/../other/x', 2);
  fs.symlinkSync(path.join(main, 'ai-factory/runs'), path.join(wt, 'esc'));
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/esc/log.csv', 2, 'symlinked directory escape');
  fs.symlinkSync(path.join(main, 'ai-factory/runs/log.csv'), path.join(wt, 'link.csv'));
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/link.csv', 2, 'symlinked file escape');
  fs.writeFileSync(path.join(main, '.env'), 'SECRET=1\n');
  fs.symlinkSync(path.join(main, '.env'), path.join(wt, 'src/env-link'));
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/src/env-link', 2, 'symlink to main .env');
});

test('guard-uses-main-policy', () => {
  // A worktree's own dont-touch.md is a snapshot an implementer can edit; the main one decides.
  const { main, wt } = setup('policy');
  fs.writeFileSync(path.join(wt, 'ai-factory/docs/dont-touch.md'), '<!-- t4:allow-empty-policy -->\n');
  guard(wt, '.env', 2);
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/.env', 2);
});

test('logs-land-in-main', () => {
  const { main, wt } = setup('logs');
  const mainRuns = path.join(main, 'ai-factory/runs'), wtRuns = path.join(wt, 'ai-factory/runs');
  const before = listing(wtRuns);
  const base = { cwd: wt, session_id: 'wt-session' };
  logHook('session-start.js', base);
  logHook('log-task.js', { ...base, prompt: '/t4:run step 1' });
  logHook('log-edit.js', { ...base, tool_name: 'Write', tool_input: { file_path: 'src/a.js' } });
  logHook('log-cmd.js', { ...base, tool_input: { command: 'npm test' } });
  logHook('session-stop.js', { ...base, transcript_path: path.join(fixtures, 'transcript-uuid.jsonl') });
  logHook('subagent-stop.js', { ...base, session_id: 'wt-agent', agent_id: 'a1', agent_type: 'implementer',
    agent_transcript_path: path.join(fixtures, 'agent-transcript.jsonl') });
  assert.deepEqual(listing(wtRuns), before, 'the worktree\'s ai-factory/runs/ gained files');
  assert.equal(fs.existsSync(path.join(wt, 'ai-factory/runs/lifecycle')), false, 'lifecycle event in the worktree');
  assert.equal(fs.readFileSync(path.join(mainRuns, '.task.wt-session'), 'utf8'), 'run\n');
  assert.match(fs.readFileSync(path.join(mainRuns, 'sessions.jsonl'), 'utf8'), /"session_id":"wt-session"/);
  assert.match(fs.readFileSync(path.join(mainRuns, 'edits.jsonl'), 'utf8'), /"file":"src\/a.js"/);
  assert.match(fs.readFileSync(path.join(mainRuns, 'cmds.jsonl'), 'utf8'), /"cmd":"npm test"/);
  const rows = fs.readFileSync(path.join(mainRuns, 'log.pending.csv'), 'utf8').trim().split('\n');
  assert.equal(rows.length, 3, `expected header + session + agent rows, got ${rows.length}`);
  assert.match(rows[1], /,wt-session,session,.*,t4-loop\/L1\/S1,run,claude,,/);
  assert.match(rows[2], /,wt-agent,agent,/);
  const events = fs.readdirSync(path.join(mainRuns, 'lifecycle/events')).filter((f) => f.endsWith('.json'));
  assert.equal(events.length, 2, `expected two usage_linked events in main, got ${events.length}`);
  for (const file of events)
    assert.equal(JSON.parse(fs.readFileSync(path.join(mainRuns, 'lifecycle/events', file), 'utf8')).type, 'usage_linked');
  // log-flush never moves main rows into log.csv or stages anything from inside a worktree.
  const pending = fs.readFileSync(path.join(mainRuns, 'log.pending.csv'), 'utf8');
  logHook('log-flush.js', { ...base, tool_input: { command: 'git commit -m x' } });
  assert.equal(fs.readFileSync(path.join(mainRuns, 'log.pending.csv'), 'utf8'), pending);
  assert.equal(fs.readFileSync(path.join(mainRuns, 'log.csv'), 'utf8'), 'tracked\n');
  assert.deepEqual(listing(wtRuns), before);
  assert.equal(git(main, 'diff', '--cached', '--name-only'), '');
  assert.equal(git(wt, 'diff', '--cached', '--name-only'), '');
});

test('no-worktree-scan', () => {
  const { main, wt } = setup('scan');
  fs.writeFileSync(path.join(wt, 'ai-factory/plans/9999-z.md'), '# Z\n');
  fs.mkdirSync(path.join(wt, 'ai-factory/runs/lifecycle/events'), { recursive: true });
  fs.writeFileSync(path.join(wt, 'ai-factory/runs/lifecycle/events/junk.json'), 'not json');
  fs.writeFileSync(path.join(wt, 'ai-factory/docs/dont-touch.md'), 'not a policy\n');
  const before = listing(wt);
  const base = { cwd: main, session_id: 'main-session' };
  logHook('session-start.js', base);
  assert.equal(JSON.parse(fs.readFileSync(path.join(main, 'ai-factory/runs/sessions.jsonl'), 'utf8')).plan_in_flight, '0001-a.md');
  logHook('log-task.js', { ...base, prompt: '/t4:review' });
  logHook('log-edit.js', { ...base, tool_name: 'Write', tool_input: { file_path: 'src/a.js' } });
  logHook('log-cmd.js', { ...base, tool_input: { command: 'npm test' } });
  logHook('session-stop.js', { ...base, transcript_path: path.join(fixtures, 'transcript-uuid.jsonl') });
  logHook('subagent-stop.js', { ...base, session_id: 'main-agent', agent_id: 'a1',
    agent_transcript_path: path.join(fixtures, 'agent-transcript.jsonl') });
  guard(main, 'src/a.js', 0);
  guard(main, 'ai-factory/runs/tmp/worktrees/L1-S1/src/a.js', 0);
  assert.deepEqual(listing(wt), before, 'a hook run from the main tree touched the worktree');
});

test('stdout-empty', () => {
  // Every hook, through both entry points, with the worktree as cwd; then a repo without the layout.
  const { wt } = setup('stdout');
  const transcript = path.join(fixtures, 'transcript-uuid.jsonl');
  const ev = { cwd: wt, session_id: 'quiet', prompt: '/t4:run', transcript_path: transcript, agent_transcript_path: transcript,
    agent_id: 'q', tool_name: 'Write', tool_input: { file_path: 'src/a.js', command: 'npm test && git commit -m x' } };
  const names = ['session-start', 'log-task', 'guard-paths', 'log-flush', 'log-edit', 'log-cmd', 'session-stop', 'subagent-stop'];
  for (const name of names) {
    assert.equal(hook(`${name}.js`, ev).status, 0, name);
    const codex = spawnSync(process.execPath, [path.join(scripts, 'codex-hook.js'), name], { input: JSON.stringify(ev), encoding: 'utf8' });
    assert.equal(codex.stdout, '', `codex ${name}: stdout`);
    assert.equal(codex.status, 0, `codex ${name}: ${codex.stderr}`);
  }
  const bare = path.join(scratch, 'bare');
  fs.mkdirSync(path.join(bare, 'src'), { recursive: true });
  fs.writeFileSync(path.join(bare, 'src/a.js'), '');
  git(bare, 'init', '-q');
  git(bare, 'add', '-A');
  git(bare, 'commit', '-q', '--no-verify', '-m', 'bare');
  const bareWt = path.join(bare, 'x/runs/tmp/worktrees/L1-S1');
  git(bare, 'worktree', 'add', '-q', '--detach', bareWt, 'HEAD');
  const before = listing(bare);
  for (const name of names) {
    const result = hook(`${name}.js`, { ...ev, cwd: bareWt });
    assert.equal(result.status, 0, `${name} without a layout: ${result.stderr}`);
    assert.equal(result.stderr, '', `${name} without a layout: ${result.stderr}`);
  }
  assert.deepEqual(listing(bare), before, 'a hook wrote into a repo without the layout');
});

let failed = 0;
for (const [name, fn] of cases) {
  try { fn(); console.log(`PASS ${name}`); }
  catch (error) { failed++; console.log(`FAIL ${name}: ${error.message.split('\n')[0]}`); }
}
if (failed) { console.log(`worktree hooks: ${failed} of ${cases.length} cases failed`); process.exit(1); }
console.log(`worktree hooks ok — ${cases.length} cases with real git worktrees`);
NODE
