#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
node skills/ai-layout/scripts/sync-codex-skills.js --check
node skills/ai-layout/scripts/sync-claude-commands.js --check
node <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const manifest = JSON.parse(fs.readFileSync('.codex-plugin/plugin.json'));
const taskDir = 'skills/ai-layout/templates/ai-factory/tasks';
for (const file of fs.readdirSync(taskDir).filter(f => f.endsWith('.md'))) {
  const command = path.join('commands', file);
  assert.ok(fs.existsSync(command), `Claude plugin cannot discover /t4:${path.basename(file, '.md')}: missing ${command}`);
  const task = fs.readFileSync(path.join(taskDir, file), 'utf8');
  const body = fs.readFileSync(command, 'utf8');
  assert.match(body, /^description: .+/m);
  assert.equal(/^argument-hint: (.*)$/m.exec(body)?.[1], /^argument-hint: (.*)$/m.exec(task)?.[1]);
  assert.ok(body.includes(`ai-factory/tasks/${file}`), `${command} must load the repo's procedure`);
  assert.ok(body.includes('$ARGUMENTS'), `${command} must pass the user's input`);
}
const names = new Set(['ai-layout', 'ai-hooks']);
for (const dir of ['commands', 'skills/ai-layout/templates/ai-factory/tasks']) {
  for (const file of fs.readdirSync(dir).filter(f => f.endsWith('.md'))) names.add('t4-' + path.basename(file, '.md'));
}
for (const name of names) {
  const file = path.join(manifest.skills, name, 'SKILL.md');
  assert.ok(fs.existsSync(file), `Codex plugin cannot discover ${name}: missing ${file}`);
  const text = fs.readFileSync(file, 'utf8');
  assert.match(text, new RegExp(`^name: ${name}$`, 'm'));
  assert.match(text, /^description: .+/m);
  for (const match of text.matchAll(/\]\((\.\.\/[^)]+)\)/g)) {
    assert.ok(fs.existsSync(path.resolve(path.dirname(file), match[1])), `${file}: broken reference ${match[1]}`);
  }
}
assert.ok(manifest.hooks, 'Codex requires an explicit host adapter for hooks');
const hooks = JSON.parse(fs.readFileSync(manifest.hooks));
for (const event of ['SessionStart','UserPromptSubmit','PreToolUse','PostToolUse','Stop','SubagentStop']) {
  assert.ok(hooks.hooks[event]?.length, `Missing Codex ${event} hook`);
}
const claude = JSON.parse(fs.readFileSync('hooks/hooks.json'));
for (const [event, groups] of Object.entries(claude.hooks)) {
  const handlers = groups.flatMap(group => group.hooks.map(h => path.basename(h.command.replace(/"/g, ''), '.js')));
  const codexHandlers = hooks.hooks[event].flatMap(group => group.hooks.map(h => h.command.split(' ').at(-1)));
  assert.deepEqual(codexHandlers, handlers, `${event}: host handler coverage differs`);
}
const discovered = fs.readdirSync(manifest.skills).filter(name => fs.existsSync(path.join(manifest.skills, name, 'SKILL.md')));
assert.deepEqual(discovered.sort(), [...names].sort(), 'Stale or missing native skills');
console.log(`plugin hosts ok — ${fs.readdirSync('commands').filter(f => f.endsWith('.md')).length} native Claude commands, ${names.size} Codex skills and lifecycle hooks`);
NODE
