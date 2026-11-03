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
  assert.ok(fs.existsSync(command), `Claude plugin cannot discover /fc:${path.basename(file, '.md')}: missing ${command}`);
  const task = fs.readFileSync(path.join(taskDir, file), 'utf8');
  const body = fs.readFileSync(command, 'utf8');
  assert.match(body, /^description: .+/m);
  assert.equal(/^argument-hint: (.*)$/m.exec(body)?.[1], /^argument-hint: (.*)$/m.exec(task)?.[1]);
  assert.ok(body.includes(`ai-factory/tasks/${file}`), `${command} must load the repo's procedure`);
  assert.ok(body.includes('$ARGUMENTS'), `${command} must pass the user's input`);
}
const names = new Set(['ai-layout', 'ai-hooks']);
for (const dir of ['commands', 'skills/ai-layout/templates/ai-factory/tasks']) {
  for (const file of fs.readdirSync(dir).filter(f => f.endsWith('.md'))) names.add('fc-' + path.basename(file, '.md'));
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
// Continuation is interactive on both hosts and shares one task procedure.
for (const file of ['commands/continue.md', path.join(manifest.skills, 'fc-continue', 'SKILL.md')]) {
  assert.ok(fs.existsSync(file), `missing continuation entry ${file}`);
  const text = fs.readFileSync(file, 'utf8');
  assert.ok(text.includes('ai-factory/tasks/continue.md'), `${file} must load the shared continue procedure`);
  assert.match(text, /continue\.js handoff --host (claude|codex)/, `${file} must hand off through continue.js`);
}
const discovered = fs.readdirSync(manifest.skills).filter(name => fs.existsSync(path.join(manifest.skills, name, 'SKILL.md')));
assert.deepEqual(discovered.sort(), [...names].sort(), 'Stale or missing native skills');
// A shortcut (models.js TASK_SHORTCUTS) is a stable second name for its target, never deprecated:
// /fc:ba and $fc-ba run analyse with analyse's own preamble, hint and procedure (AC4, AC5, AC7, AC9).
const models = require(path.resolve('skills/ai-layout/templates/ai-factory/make/models.js'));
const frontmatter = (text, key) => new RegExp(`^${key}: (.*)$`, 'm').exec(text)?.[1];
assert.ok(Object.keys(models.TASK_SHORTCUTS).length > 0, 'models.js exports no TASK_SHORTCUTS');
for (const [shortcut, target] of Object.entries(models.TASK_SHORTCUTS)) {
  const command = path.join('commands', `${shortcut}.md`);
  assert.ok(fs.existsSync(command), `${command} does not exist`);
  const body = fs.readFileSync(command, 'utf8');
  const targetCommand = fs.readFileSync(path.join('commands', `${target}.md`), 'utf8');
  assert.equal(frontmatter(body, 'description'), `Shortcut for /fc:${target} — ${frontmatter(targetCommand, 'description')}`, `${command} description`);
  assert.equal(frontmatter(body, 'argument-hint'), frontmatter(targetCommand, 'argument-hint'), `${command} takes the target's argument-hint`);
  assert.ok(body.includes(`ai-factory/tasks/${target}.md`), `${command} must load ai-factory/tasks/${target}.md`);
  assert.ok(!body.includes(`ai-factory/tasks/${shortcut}.md`), `${command} must not load a task of its own`);
  assert.ok(body.includes(models.entryPreamble('claude', target)), `${command} must carry the target's preamble`);
  assert.doesNotMatch(body, /deprecated/i, `${command} must not call itself deprecated`);
  const skill = path.join(manifest.skills, `fc-${shortcut}`, 'SKILL.md');
  assert.ok(fs.existsSync(skill), `${skill} does not exist`);
  const text = fs.readFileSync(skill, 'utf8');
  const task = fs.readFileSync(path.join(taskDir, `${target}.md`), 'utf8');
  assert.equal(JSON.parse(frontmatter(text, 'description')), `Shortcut for $fc-${target} — ${frontmatter(task, 'description')}`, `${skill} description`);
  assert.ok(text.includes(`ai-factory/tasks/${target}.md`), `${skill} must load ai-factory/tasks/${target}.md`);
  assert.ok(text.includes(models.entryPreamble('codex', target)), `${skill} must carry the target's preamble`);
  assert.ok(!text.includes('canonical command'), `${skill} must be a task skill, not a generic command pointer`);
  assert.doesNotMatch(text, /deprecated/i, `${skill} must not call itself deprecated`);
}
console.log(`plugin hosts ok — ${fs.readdirSync('commands').filter(f => f.endsWith('.md')).length} native Claude commands, ${names.size} Codex skills and lifecycle hooks`);
NODE

# A task file that takes a shortcut or deprecated name would shadow that plugin entry point: both
# generators refuse before writing anything (AC11, AC12). Run them on a scratch copy so the real
# commands/ and codex-skills/ are never touched.
export TMPDIR="$PWD/ai-factory/runs/tmp"
mkdir -p "$TMPDIR"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
clash() { # <task file name> <expected message>
  local tree="$scratch/$1" gen out
  rm -rf "$tree"
  mkdir -p "$tree/skills/ai-layout/templates/ai-factory" "$tree/skills/ai-hooks" "$tree/commands"
  cp -R skills/ai-layout/scripts "$tree/skills/ai-layout/scripts"
  cp skills/ai-layout/SKILL.md "$tree/skills/ai-layout/SKILL.md"
  cp skills/ai-hooks/SKILL.md "$tree/skills/ai-hooks/SKILL.md"
  cp -R skills/ai-layout/templates/ai-factory/make skills/ai-layout/templates/ai-factory/tasks "$tree/skills/ai-layout/templates/ai-factory/"
  printf -- '---\ndescription: A project task that took a reserved name\n---\nDo the thing.\n' > "$tree/skills/ai-layout/templates/ai-factory/tasks/$1"
  for gen in sync-claude-commands.js sync-codex-skills.js; do
    if out=$(node "$tree/skills/ai-layout/scripts/$gen" 2>&1); then
      echo "FAIL: $gen accepted tasks/$1 instead of refusing" >&2; exit 1
    fi
    case "$out" in *"$2"*) ;; *) echo "FAIL: $gen refused tasks/$1 without \"$2\": $out" >&2; exit 1;; esac
  done
  [ -z "$(ls -A "$tree/commands")" ] || { echo "FAIL: tasks/$1 clash still wrote commands/: $(ls "$tree/commands" | head -3)" >&2; exit 1; }
  [ ! -e "$tree/codex-skills" ] || { echo "FAIL: tasks/$1 clash still wrote codex-skills/" >&2; exit 1; }
}
clash ba.md "Task ba.md uses the shortcut name of analyse; rename the task file"
clash scout.md "Task scout.md uses the shortcut name of explore; rename the task file"
clash check.md "Task check.md uses the deprecated name of review; rename the task file"
echo "plugin generators refuse shortcut and deprecated task-file names"
