#!/usr/bin/env node
// Test, lint, type-check and format-check commands of any stack; nothing here assumes one.
// Every pattern is matched only in command position, so a check named inside another command
// (`grep pytest`, `echo go test`, a commit message) is not logged. Command position is the start
// of the string or of a chained command (after ; & | or an opening paren), followed by any number
// of env assignments and wrappers (time, timeout N, sudo [-E], nice), then any runner that
// executes a tool (npx, bunx, bun x, npm exec, yarn, pnpm [exec|dlx|--filter X], uv/poetry/pipenv
// run, bundle exec), and a tool may be named by path (vendor/bin/phpunit, ./gradlew).
const START = String.raw`(?:^|[;&|(])\s*`;
const PREFIX = String.raw`(?:\w+=\S*\s+|time\s+|timeout\s+\S+\s+|sudo(?:\s+-\w+)*\s+|nice\s+)*`;
const RUNNER = String.raw`(?:(?:npx|bunx|bun\s+x|npm\s+exec|yarn|pnpm(?:\s+(?:exec|dlx)|\s+--filter[=\s]\S+)?|uv\s+run|poetry\s+run|pipenv\s+run|bundle\s+exec)\s+)?`;
const PATH = String.raw`(?:\S*\/)?`;
const at = (body) => new RegExp(START + PREFIX + RUNNER + PATH + body);
const CHECK_COMMANDS = [
	// Tools that only check.
	at(String.raw`(?:vitest|jest|mocha|playwright|cypress|biome|eslint|tsc|fallow|pytest|ruff|mypy|pyright|flake8|pylint|tox|nox|golangci-lint|staticcheck|rspec|rubocop|phpunit|phpstan)\b`),
	at(String.raw`prettier\b.*--check\b`),
	at(String.raw`python3?\s+-m\s+(?:pytest|unittest|mypy|ruff)\b`),
	// Package managers and build tools with a check verb.
	at(String.raw`(?:pnpm|npm|yarn|bun)\s+(?:run\s+)?(?:test|lint|e2e|check|type-check|typecheck)(?::\w+)?\b`),
	at(String.raw`go\s+(?:test|vet)\b`),
	at(String.raw`cargo\s+(?:test|clippy|check|nextest|fmt\s+(?:.*\s)?--check)\b`),
	at(String.raw`(?:gradlew|gradle)\s+(?:.*\s)?(?:test|check)\b`),
	at(String.raw`mvn\s+(?:.*\s)?(?:test|verify)\b`),
	at(String.raw`dotnet\s+(?:test|format\s+(?:.*\s)?--verify-no-changes)\b`),
	at(String.raw`make\s+(?:-f\s+\S+\s+)?(?:test|lint|check|verify|typecheck)\b`),
];
require("./_common").runHook(() => {
	const { readEvent, logDir, appendJsonl, path } = require("./_common");
	const ev = readEvent();
	const ai = logDir(ev);
	if (!ai) return;
	const cmd = String(ev.tool_input?.command || "");
	require("./_lifecycle").bindSession(ai, ev);
	if (!CHECK_COMMANDS.some((re) => re.test(cmd))) return;
	appendJsonl(path.join(ai, "runs", "cmds.jsonl"), {
		session_id: ev.session_id,
		ts: new Date().toISOString(),
		cmd: cmd.slice(0, 200),
	});
});
