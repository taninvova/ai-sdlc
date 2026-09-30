#!/usr/bin/env bash
# Security checks run inside the workspace and use independent Git boundaries.
set -euo pipefail
cd "$(dirname "$0")/../../.."
mkdir -p ai-factory/runs/tmp
FIXTURE=$(mktemp -d "$PWD/ai-factory/runs/tmp/guard-security.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT
node - "$PWD" "$FIXTURE" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const [source, scratch] = process.argv.slice(2);
const guard = path.join(source, 'skills/ai-hooks/scripts/guard-paths.js');
const policyText = '# Protected prefixes\n- `secrets/`\n- `.env`\n- `LICENSE`\n';
function repo(name, layout = 'ai-factory') {
  const root = path.join(scratch, name);
  fs.mkdirSync(root, { recursive: true });
  execFileSync('git', ['init', '-q', root]);
  if (layout) {
    fs.mkdirSync(path.join(root, layout, 'docs'), { recursive: true });
    fs.writeFileSync(path.join(root, layout, 'docs/dont-touch.md'), policyText);
  }
  return root;
}
let passed = 0;
function probe(name, cwd, target, expected, diagnostic) {
  const result = spawnSync(process.execPath, [guard], {
    input: JSON.stringify({ cwd, tool_name: 'Write', tool_input: target === undefined ? {} : { file_path: target } }),
    encoding: 'utf8',
  });
  assert.equal(result.status, expected, `${name}: ${result.stderr}`);
  assert.equal(result.stdout, '', `${name}: unexpected stdout`);
  if (expected === 0) assert.equal(result.stderr, '', `${name}: unexpected diagnostic`);
  if (diagnostic) assert.match(result.stderr, diagnostic, name);
  passed++;
}
const root = repo('adopted');
const policy = path.join(root, 'ai-factory/docs/dont-touch.md');
fs.mkdirSync(path.join(root, 'src/deep'), { recursive: true });
fs.mkdirSync(path.join(root, 'secrets/inner'), { recursive: true });
fs.writeFileSync(path.join(root, 'secrets/token'), 'sentinel');
probe('direct existing', root, 'secrets/token', 2, /Blocked by ai-factory/);
probe('new nested target', root, 'secrets/new/deep/token', 2);
probe('ordinary edit', root, 'src/okay.js', 0);
probe('prefix lookalike directory', root, 'secrets-public/token', 0);
probe('basename prefix', root, 'src/.env.local', 2);
probe('nested cwd', path.join(root, 'src/deep'), '../../secrets/token', 2);
fs.symlinkSync('secrets', path.join(root, 'alias'));
fs.symlinkSync('secrets/token', path.join(root, 'alias-file'));
probe('directory alias', root, 'alias/token', 2);
probe('file alias', root, 'alias-file', 2);
probe('new leaf through alias', root, 'alias/new/deep/token', 2);
fs.symlinkSync('secrets/inner', path.join(root, 'inner-alias'));
probe('parent after symlink', root, 'inner-alias/../token', 2);
fs.symlinkSync('missing-destination', path.join(root, 'broken'));
probe('broken link fails closed', root, 'broken/file', 2);
fs.symlinkSync('loop', path.join(root, 'loop'));
probe('link loop fails closed', root, 'loop/file', 2);
const nestedLayout = path.join(root, 'src/ai-factory/docs');
fs.mkdirSync(nestedLayout, { recursive: true });
fs.writeFileSync(path.join(nestedLayout, 'dont-touch.md'), '<!-- t4:allow-empty-policy -->');
probe('nested layout cannot override repo policy', path.join(root, 'src'), '../secrets/token', 2);
const child = path.join(root, 'child');
execFileSync('git', ['init', '-q', child]);
probe('unadopted nested repository stays isolated', child, 'secrets/token', 0);
const sibling = repo('sibling', null);
probe('unadopted sibling', sibling, 'secrets/token', 0);
probe('missing target', root, undefined, 2, /target path/);
probe('nonstring target', root, 9, 2, /target path/);
fs.renameSync(policy, policy + '.saved');
probe('missing policy', root, 'src/okay.js', 2, /readable, valid policy/);
fs.mkdirSync(policy);
probe('unreadable policy directory', root, 'src/okay.js', 2, /readable, valid policy/);
fs.rmdirSync(policy);
fs.writeFileSync(policy, policyText);
if (process.getuid?.() !== 0) {
  fs.chmodSync(policy, 0);
  probe('unreadable policy permissions', root, 'src/okay.js', 2, /readable, valid policy/);
  fs.chmodSync(policy, 0o600);
}
for (const malformed of ['', '# No rules', '- `secret', '- secrets/', '- `../escape/`', '- `/absolute`', '- `secrets/*`', '- `secrets/`\n- malformed', '<!-- t4:allow-empty-policy -->\n- `secrets/`']) {
  fs.writeFileSync(policy, malformed);
  probe('malformed policy', root, 'src/okay.js', 2, /valid policy/);
}
fs.writeFileSync(policy, '<!-- t4:allow-empty-policy -->\n');
probe('explicit empty policy', root, 'secrets/token', 0);
fs.writeFileSync(policy, policyText);
fs.mkdirSync(path.join(root, 'protected folder'));
fs.writeFileSync(policy, policyText + '- `protected folder/`\n');
probe('prefix containing spaces', root, 'protected folder/new', 2);
const destination = path.join(scratch, 'outside-destination');
fs.mkdirSync(destination);
fs.symlinkSync(destination, path.join(root, 'protected-alias'));
fs.writeFileSync(policy, policyText + '- `protected-alias/`\n');
probe('policy alias protects actual destination', root, path.join(destination, 'new'), 2);
fs.writeFileSync(policy, policyText);
const old = repo('legacy', 'ai');
probe('legacy layout', old, 'secrets/token', 2, /Blocked by ai\/docs/);
fs.mkdirSync(path.join(old, 'ai-factory/docs'), { recursive: true });
fs.writeFileSync(path.join(old, 'ai-factory/docs/dont-touch.md'), '- `preferred/`\n');
probe('new layout takes precedence', old, 'preferred/file', 2);
probe('old layout ignored when new exists', old, 'secrets/token', 0);
execFileSync('git', ['-C', root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--allow-empty', '-qm', 'fixture']);
const worktree = path.join(scratch, 'worktree');
execFileSync('git', ['-C', root, 'worktree', 'add', '--detach', '-q', worktree]);
fs.mkdirSync(path.join(worktree, 'ai-factory/docs'), { recursive: true });
fs.mkdirSync(path.join(worktree, 'src/deep'), { recursive: true });
fs.writeFileSync(path.join(worktree, 'ai-factory/docs/dont-touch.md'), policyText);
assert.equal(fs.lstatSync(path.join(worktree, '.git')).isFile(), true);
probe('real worktree nested cwd', path.join(worktree, 'src/deep'), '../../secrets/new', 2);
assert.equal(fs.readFileSync(path.join(root, 'secrets/token'), 'utf8'), 'sentinel');
console.log(`guard security ok — ${passed} cases, including actual Git worktree and symlink resolution`);
NODE
