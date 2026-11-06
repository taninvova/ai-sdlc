#!/usr/bin/env bash
# log-cmd.js logs test, lint, type-check and format-check commands of any stack to
# ai-factory/runs/cmds.jsonl, and nothing else.
set -euo pipefail
cd "$(dirname "$0")/../../.."
mkdir -p ai-factory/runs/tmp
FIXTURE=$(mktemp -d "$PWD/ai-factory/runs/tmp/log-cmd.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT
node - "$PWD" "$FIXTURE" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const [source, scratch] = process.argv.slice(2);
const hook = path.join(source, 'skills/ai-hooks/scripts/log-cmd.js');
const root = path.join(scratch, 'repo');
fs.mkdirSync(path.join(root, 'ai-factory/runs'), { recursive: true });
execFileSync('git', ['init', '-q', root]);
const log = path.join(root, 'ai-factory/runs/cmds.jsonl');

function logged(command) {
  fs.rmSync(log, { force: true });
  const result = spawnSync(process.execPath, [hook], {
    input: JSON.stringify({ cwd: root, session_id: 'fixture', tool_input: { command } }),
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, `${command}: ${result.stderr}`);
  assert.equal(result.stdout, '', `${command}: stdout pollution`);
  return fs.existsSync(log);
}

const checks = [
  // JavaScript / TypeScript
  'npm test', 'pnpm run lint', 'yarn typecheck', 'bun test', 'npx vitest run', 'jest --ci',
  'npx playwright test', 'biome check .', 'npx eslint src', 'tsc --noEmit', 'prettier --check .',
  'npx fallow dead-code',
  // Python
  'pytest -q', 'python -m pytest tests', 'python3 -m unittest', 'ruff check .', 'mypy src',
  'pyright', 'uv run pytest', 'tox -e py312',
  // Go
  'go test ./...', 'go vet ./...', 'golangci-lint run',
  // Rust
  'cargo test', 'cargo clippy -- -D warnings', 'cargo fmt --check', 'cargo nextest run',
  // JVM
  './gradlew test', 'gradle check', 'mvn verify', 'mvn -q test',
  // .NET, Ruby, PHP
  'dotnet test', 'dotnet format --verify-no-changes', 'bundle exec rspec', 'rubocop',
  'vendor/bin/phpunit', 'phpstan analyse',
  // Stack-neutral entry points
  'make test', 'make lint', 'make -f ai-factory/make/ai.mk verify',
  // Env prefix and chained commands
  'CI=1 pytest', 'npm ci && npm test',
  // Logged before 7.0.0 and still logged: bare runner prefixes, time/timeout, a cd chain
  'pnpm vitest run', 'pnpm tsc --noEmit', 'pnpm biome check .', 'pnpm playwright test',
  'pnpm --filter web vitest', 'npm exec vitest', 'bun x vitest', 'yarn jest', 'time vitest',
  'timeout 60 jest', 'cd web && pnpm jest', 'npm run test:unit', 'sudo -E make test',
];
const ignored = [
  'git status', 'ls -la', 'cat package.json', 'npm install', 'go build ./...', 'cargo build',
  'echo testing', 'grep -rn pytest docs', 'rg vitest src', 'git log --grep=ruff', 'make build', 'mvn package', 'node --check a.js',
  // A check verb named inside another command is not a check
  'echo go test', 'git commit -m "fix go test"', 'echo cargo clippy', 'grep -rn "npm test" docs',
  'git log --grep="make lint"', 'echo mvn verify',
];

const missed = checks.filter((c) => !logged(c));
const extra = ignored.filter((c) => logged(c));
assert.deepEqual(missed, [], `check commands not logged: ${missed.join(' | ')}`);
assert.deepEqual(extra, [], `non-check commands logged: ${extra.join(' | ')}`);
console.log(`log-cmd: ${checks.length} check commands logged, ${ignored.length} others ignored`);
NODE
