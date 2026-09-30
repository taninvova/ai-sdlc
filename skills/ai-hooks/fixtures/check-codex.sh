#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
mkdir -p ai-factory/runs/tmp
FIXTURE=$(mktemp -d "$PWD/ai-factory/runs/tmp/codex-hooks.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT
node - "$PWD" "$FIXTURE" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const [source, root] = process.argv.slice(2);
execFileSync('git', ['init', '-q', root]);
const ai = path.join(root, 'ai-factory');
fs.mkdirSync(path.join(ai, 'docs'), { recursive: true });
fs.writeFileSync(path.join(ai, 'docs/dont-touch.md'), '- `secrets/`\n');
const scripts = path.join(source, 'skills/ai-hooks/scripts');
const failures = [];
function check(name, test) {
  try { test(); console.log('ok: ' + name); }
  catch (error) { failures.push(name); console.error('FAIL: ' + name + ': ' + error.message); }
}
function hook(script, event) {
  return spawnSync(process.execPath, [path.join(scripts, 'codex-hook.js'), script], {
    input: JSON.stringify({ cwd: root, session_id: 'codex-live', ...event }), encoding: 'utf8',
  });
}
function patch(command) {
  return hook('guard-paths', { tool_name: 'apply_patch', tool_input: { command } });
}
check('Codex ordinary patch allowed silently', () => {
  const result = patch('*** Begin Patch\n*** Add File: src/okay.js\n+hello\n*** End Patch');
  assert.equal(result.status, 0, result.stderr); assert.equal(result.stdout, '');
});
check('Codex all patch targets and rename destinations guarded', () => {
  for (const body of [
    '*** Add File: src/okay.js\n+okay\n*** Delete File: secrets/key',
    '*** Update File: src/okay.js\n*** Move to: secrets/key\n@@\n-old\n+new',
    '*** Update File: secrets/key\n*** Move to: src/key\n@@\n-old\n+new',
  ]) assert.equal(patch('*** Begin Patch\n' + body + '\n*** End Patch').status, 2);
  assert.equal(patch('not a patch').status, 2);
});
check('Codex patch logs every touched file', () => {
  const result = hook('log-edit', { tool_name: 'apply_patch', tool_input: { command: '*** Begin Patch\n*** Update File: src/old.js\n*** Move to: src/new.js\n@@\n-old\n+new\n*** End Patch' } });
  assert.equal(result.status, 0, result.stderr);
  const rows = fs.readFileSync(path.join(ai, 'runs/edits.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
  assert.deepEqual(rows.map(r => r.file), ['src/old.js', 'src/new.js']);
});
check('Codex skill invocation attributes the task', () => {
  for (const prompt of ['$t4-run 0007', '$t4:t4-run 0007', '/t4:run 0007']) {
    hook('log-task', { prompt });
    assert.equal(fs.readFileSync(path.join(ai, 'runs/.task.codex-live'), 'utf8'), 'run\n');
  }
});
const transcript = path.join(root, 'rollout.jsonl');
const usage = (id, input, cached, output) => ({ type: 'token_usage_record', payload: { response_id: id, usage: { input_tokens: input, cached_input_tokens: cached, output_tokens: output } } });
const records = [{ type: 'turn_context', payload: { model: 'gpt-test' } }, usage('response-a', 100, 60, 10)];
const write = () => fs.writeFileSync(transcript, records.map(JSON.stringify).join('\n') + '\n');
const stop = () => hook('session-stop', { transcript_path: transcript, model: 'gpt-test' });
check('Codex usage rows are deltas, cached input is separate, cost is unknown', () => {
  write(); const first = stop(); assert.equal(first.status, 0, first.stderr); assert.equal(first.stdout, '');
  stop();
  records.push(usage('response-b', 70, 20, 5)); write(); stop();
  const rows = fs.readFileSync(path.join(ai, 'runs/log.pending.csv'), 'utf8').trim().split('\n').slice(1).map(r => r.split(','));
  assert.equal(rows.length, 2);
  assert.deepEqual(rows.map(r => r.slice(5, 14)), [
    ['run','codex','','gpt-test','1','40','10','60','0'],
    ['run','codex','','gpt-test','1','50','5','20','0'],
  ]);
  assert.ok(rows.every(r => r[15] === ''));
});
check('Codex inherited response is counted once across parent and child', () => {
  const child = path.join(root, 'child.jsonl');
  fs.writeFileSync(child, [records[0], records[1], usage('response-child', 30, 10, 2)].map(JSON.stringify).join('\n'));
  const event = { agent_id: 'child', agent_type: 'explorer', model: 'gpt-test', agent_transcript_path: child };
  hook('subagent-stop', event); hook('subagent-stop', event);
  const rows = fs.readFileSync(path.join(ai, 'runs/log.pending.csv'), 'utf8').trim().split('\n').slice(1).map(r => r.split(','));
  assert.equal(rows.length, 3);
  assert.deepEqual(rows[2].slice(2, 3), ['agent']);
  assert.deepEqual(rows[2].slice(5, 14), ['run','codex','explorer','gpt-test','1','20','2','10','0']);
});
check('Older Codex cumulative snapshots count increments and ignore repeated snapshots', () => {
  const old = path.join(root, 'old-rollout.jsonl');
  const snapshot = (time, input, cached, output) => ({ timestamp: time, type: 'event_msg', payload: { type: 'token_count', info: { total_token_usage: { input_tokens: input, cached_input_tokens: cached, output_tokens: output } } } });
  const entries = [snapshot('a', 100, 60, 10), snapshot('b', 100, 60, 10), snapshot('c', 170, 80, 15)];
  const oldStop = () => hook('session-stop', { session_id: 'codex-old', transcript_path: old, model: 'gpt-old' });
  fs.writeFileSync(old, entries.map(JSON.stringify).join('\n')); oldStop(); oldStop();
  entries.push(snapshot('d', 200, 90, 17));
  fs.writeFileSync(old, entries.map(JSON.stringify).join('\n')); oldStop();
  const rows = fs.readFileSync(path.join(ai, 'runs/log.pending.csv'), 'utf8').trim().split('\n').slice(1).map(r => r.split(',')).filter(r => r[1] === 'codex-old');
  assert.equal(rows.length, 2);
  assert.deepEqual(rows.map(r => r.slice(9, 14)), [['2','90','15','80','0'], ['1','20','2','10','0']]);
});
check('Modern usage records take precedence over mirrored cumulative snapshots', () => {
  const file = path.join(root, 'mixed-rollout.jsonl');
  fs.writeFileSync(file, [usage('mixed', 100, 60, 10), { type: 'event_msg', payload: { type: 'token_count', info: { total_token_usage: { input_tokens: 100, cached_input_tokens: 60, output_tokens: 10 } } } }].map(JSON.stringify).join('\n'));
  hook('session-stop', { session_id: 'codex-mixed', transcript_path: file, model: 'gpt-test' });
  const rows = fs.readFileSync(path.join(ai, 'runs/log.pending.csv'), 'utf8').trim().split('\n').slice(1).map(r => r.split(',')).filter(r => r[1] === 'codex-mixed');
  assert.equal(rows.length, 1); assert.deepEqual(rows[0].slice(9, 14), ['1','40','10','60','0']);
});
if (failures.length) process.exit(1);
NODE
