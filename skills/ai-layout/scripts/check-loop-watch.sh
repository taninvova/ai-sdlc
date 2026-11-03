#!/usr/bin/env bash
# /fc:loop watcher (spec ASD-007): the read-only `loop.js watch` subcommand, the additive
# started_at and finished_at fields of `loop.js next` and `finish`, `make loop-watch`, /fc:watch,
# its docs and the 6.0.0 release.
#
# Groups: fields, render, details, select, errors, follow, readonly, make, surface, docs, release
# (default: every group). Each case reports a missing file or export as its own failure, never as
# a crash, so the red run of a group names every case it holds. A group that a later step of plan
# ASD-007 fills fails with "no cases yet" until that step lands.
#
# Each group has its own marked section below. A step adds cases only below its own group's
# marker, so steps that run in parallel worktrees apply back as separate hunks.
set -euo pipefail
cd "$(dirname "$0")/../../.."
group="${1:-all}"
groups="fields, render, details, select, errors, follow, readonly, make, surface, docs, release"
case "$group" in
	all | fields | render | details | select | errors | follow | readonly | make | surface | docs | release) ;;
	*) echo "check-loop-watch: unknown group '$group' (expected: $groups)" >&2; exit 2 ;;
esac
WATCH_GROUP="$group" node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync, execFileSync } = require("node:child_process");

const selected = process.env.WATCH_GROUP;
const want = (name) => selected === "all" || selected === name;
const failures = [];
const skips = [];
let passed = 0;

const cases = [];
const test = (group, name, fn) => cases.push({ group, name, fn });
// A case that cannot run here throws skip(reason): it is printed as SKIP, neither a pass nor a
// failure.
class Skip extends Error {}
const skip = (reason) => new Skip(reason);

// The commit this feature branches from (plan ASD-007 Step 1). Files are compared with it by
// commit, never with a local `main` ref.
const PRE_ASD007 = "2bdd3a7822c48d09d18340c26ffe17f607896130";

// ---- fixtures ------------------------------------------------------------------------------
// Every fixture is a disposable git repository under ai-factory/runs/tmp/ holding a copy of the
// template's loop.js and the helpers it requires, run as `node ai-factory/make/loop.js` from the
// fixture root so the helper resolves that root exactly as it does in an adopted repo.
const PLUGIN = process.cwd();
const MAKE_REL = "skills/ai-layout/templates/ai-factory/make";
const MAKE = path.join(PLUGIN, MAKE_REL);
const LOOP = path.join(MAKE, "loop.js");
const SCRATCH = path.join(PLUGIN, "ai-factory/runs/tmp");
const LOOP_DIR = "ai-factory/runs/tmp/loop";
const fixtures = [];
// Git and the helper run with no inherited GIT_DIR or GIT_WORK_TREE, which a hook could have set.
const ENV = { ...process.env };
delete ENV.GIT_DIR;
delete ENV.GIT_WORK_TREE;

function needLoop() {
	if (!fs.existsSync(LOOP)) throw new Error("make/loop.js does not exist");
}
const git = (dir, ...args) =>
	execFileSync("git", ["-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", ...args], {
		cwd: dir,
		stdio: "pipe",
		env: ENV,
	}).toString();
// A file's text at PRE_ASD007, read from this repo's history.
const atPre = (rel) => execFileSync("git", ["show", `${PRE_ASD007}:${rel}`], { cwd: PLUGIN, stdio: "pipe", env: ENV, maxBuffer: 64 * 1024 * 1024 }).toString();
// files: { "ai-factory/plans/0001-x.md": "…" }. A plan text written as an array is joined with
// newlines and ends with one. `before(dir)` runs before the fixture's first commit.
function repo(name, files, { before = null } = {}) {
	needLoop();
	fs.mkdirSync(SCRATCH, { recursive: true });
	const dir = fs.mkdtempSync(path.join(SCRATCH, `loop-watch-${name}-`));
	fixtures.push(dir);
	fs.mkdirSync(path.join(dir, "ai-factory/make"), { recursive: true });
	fs.mkdirSync(path.join(dir, "ai-factory/specs"), { recursive: true });
	fs.mkdirSync(path.join(dir, "ai-factory/plans/done"), { recursive: true });
	for (const file of ["loop.js", "contracts.js", "gate.js", "safe-files.js", "assurance.js"])
		fs.copyFileSync(path.join(MAKE, file), path.join(dir, "ai-factory/make", file));
	fs.writeFileSync(path.join(dir, "ai-factory/.gitignore"), "/runs/tmp/\n");
	fs.writeFileSync(path.join(dir, "src.txt"), "base\n");
	for (const [file, text] of Object.entries(files)) {
		fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
		fs.writeFileSync(path.join(dir, file), Array.isArray(text) ? `${text.join("\n")}\n` : text);
	}
	if (before) before(dir);
	git(dir, "init", "-q", "-b", "main");
	git(dir, "add", "-A");
	git(dir, "commit", "-q", "-m", "fixture");
	return dir;
}
// A second fixture whose loop.js is PRE_ASD007's, written from `git show`: the same commands run
// there show what loop.js answered and wrote before this feature.
function prior(name, files) {
	return repo(name, files, {
		before: (dir) => fs.writeFileSync(path.join(dir, "ai-factory/make/loop.js"), atPre(`${MAKE_REL}/loop.js`)),
	});
}
// `node ai-factory/make/loop.js <subcommand> …` in the fixture: exit status, the one JSON object
// on stdout, and stderr.
function cli(dir, ...args) {
	const run = spawnSync(process.execPath, ["ai-factory/make/loop.js", ...args], { cwd: dir, encoding: "utf8", env: ENV });
	let json = null;
	try {
		json = JSON.parse(run.stdout);
	} catch {
		throw new Error(`loop.js ${args.join(" ")} printed no JSON object (exit ${run.status}): ${(run.stdout + run.stderr).trim().split("\n")[0]}`);
	}
	return { status: run.status, json, stdout: run.stdout, stderr: run.stderr };
}
// The same, asserting exit 0.
function ok(dir, ...args) {
	const run = cli(dir, ...args);
	assert.equal(run.status, 0, `loop.js ${args.join(" ")} exited ${run.status}: ${run.stderr.trim()}`);
	return run;
}
const readLoopState = (dir, loopId) => JSON.parse(fs.readFileSync(path.join(dir, LOOP_DIR, loopId, "state.json"), "utf8"));
const writeLoopState = (dir, loopId, state) =>
	fs.writeFileSync(path.join(dir, LOOP_DIR, loopId, "state.json"), `${JSON.stringify(state, null, 2)}\n`);
// Starts the fixture plan and returns its loop ID.
function started(dir, planId = "0001") {
	const run = ok(dir, "start", planId);
	assert.equal(run.json.action, "started", `start ${planId} answered ${run.json.action}, not started`);
	return run.json.loop_id;
}
const plan = (title, ...steps) => [`# ${title}`, "", "**Spec:** `ai-factory/specs/0001-x.md`", "", "## Steps", "", ...steps];
// Step 1 starts alone in the main tree; Steps 2 and 3 then start together in worktrees.
const FANOUT = plan("Fanout", "- [ ] Step 1 — A.", "", "- [ ] Step 2 — B.", "  - Depends on: 1", "", "- [ ] Step 3 — C.", "  - Depends on: 1");
const FANOUT_FILES = { "ai-factory/plans/0001-fanout.md": FANOUT };
const ISO = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/;

// ==== fields (plan ASD-007 Step 2; AC33–AC36) ================================================
// started_at on running[] entries; started_at and finished_at on finished[] records; every
// other answer and field as PRE_ASD007's loop.js writes it.
// Cases for this group go below this marker only.
// ---- marker: fields ----

test("fields", "AC33-next-started-at", () => {
	const dir = repo("ac33", FANOUT_FILES);
	const loopId = started(dir);
	const created = readLoopState(dir, loopId).created_at;
	assert.match(created, ISO, `the fixture's created_at '${created}' is not in the expected format`);
	const expectStartedAt = (numbers) => {
		const state = readLoopState(dir, loopId);
		assert.deepEqual(state.running.map((entry) => entry.step), numbers, `running[] holds steps ${state.running.map((entry) => entry.step).join(", ")}, not ${numbers.join(", ")}`);
		for (const entry of state.running) {
			assert.ok("started_at" in entry, `Step ${entry.step}'s running[] entry has no started_at`);
			assert.match(String(entry.started_at), ISO, `Step ${entry.step}'s started_at '${entry.started_at}' is not in created_at's format`);
			assert.ok(Date.parse(entry.started_at) >= Date.parse(created), `Step ${entry.step}'s started_at is earlier than created_at`);
		}
	};
	assert.equal(ok(dir, "next", loopId).json.action, "start", "next did not start Step 1");
	expectStartedAt([1]);
	ok(dir, "finish", loopId, "1", "--result", "met", "--dry");
	assert.equal(ok(dir, "next", loopId).json.action, "start", "next did not start Steps 2 and 3");
	expectStartedAt([2, 3]);
});

test("fields", "AC34-finish-copies-started-at", () => {
	for (const result of ["met", "failed", "timeout"]) {
		const dir = repo(`ac34-${result}`, FANOUT_FILES);
		const loopId = started(dir);
		ok(dir, "next", loopId);
		const running = readLoopState(dir, loopId).running.find((entry) => entry.step === 1);
		const run = ok(dir, "finish", loopId, "1", "--result", result, "--dry");
		assert.equal(run.json.action, "finished", `finish --result ${result} answered ${run.json.action}`);
		const record = readLoopState(dir, loopId).finished.find((entry) => entry.step === 1);
		assert.ok(record, `finish --result ${result} recorded no finished[] entry for Step 1`);
		assert.ok("finished_at" in record, "Step 1's finished[] entry has no finished_at");
		assert.match(String(record.finished_at), ISO, `--result ${result}: finished_at '${record.finished_at}' is not in created_at's format`);
		assert.ok(running && "started_at" in running, "Step 1's running[] entry has no started_at");
		assert.equal(record.started_at, running.started_at, `--result ${result}: finished[] started_at is not the running entry's`);
		assert.ok(Date.parse(record.finished_at) >= Date.parse(record.started_at), `--result ${result}: finished_at is earlier than started_at`);
	}
});

test("fields", "AC35-finish-without-started-at", () => {
	for (const result of ["met", "failed", "timeout"]) {
		const bare = repo(`ac35-bare-${result}`, FANOUT_FILES);
		const twin = repo(`ac35-twin-${result}`, FANOUT_FILES);
		const bareId = started(bare);
		const twinId = started(twin);
		ok(bare, "next", bareId);
		ok(twin, "next", twinId);
		// A state written before this feature: the running entry has no started_at.
		const state = readLoopState(bare, bareId);
		for (const entry of state.running) delete entry.started_at;
		writeLoopState(bare, bareId, state);
		const bareRun = ok(bare, "finish", bareId, "1", "--result", result, "--dry");
		const twinRun = ok(twin, "finish", twinId, "1", "--result", result, "--dry");
		const record = readLoopState(bare, bareId).finished.find((entry) => entry.step === 1);
		assert.ok(record, `finish --result ${result} recorded no finished[] entry for Step 1`);
		assert.ok("finished_at" in record, "Step 1's finished[] entry has no finished_at");
		assert.match(String(record.finished_at), ISO, `--result ${result}: finished_at '${record.finished_at}' is not in created_at's format`);
		assert.ok(!("started_at" in record), `--result ${result}: the finished[] entry has a started_at its running entry never had`);
		assert.deepEqual(bareRun.json, twinRun.json, `--result ${result}: finish answered differently without started_at`);
	}
});

// The state and answers with every field that legitimately differs between two runs replaced:
// the loop ID, created_at, ended.at, the main tree's recorded tree object (it hashes loop.js
// itself), and the new fields, which are removed only where they belong.
function normalised(value, loopId) {
	const copy = JSON.parse(JSON.stringify(value).split(loopId).join("<loop>"));
	const walk = (node) => {
		if (Array.isArray(node)) return node.forEach(walk);
		if (!node || typeof node !== "object") return;
		if (typeof node.before === "string") node.before = "<tree>";
		for (const key of Object.keys(node)) walk(node[key]);
	};
	walk(copy);
	if (copy && copy.schema === "fc-loop-state") {
		if ("created_at" in copy) copy.created_at = "<created>";
		if (copy.ended && "at" in copy.ended) copy.ended.at = "<ended>";
		for (const entry of copy.running || []) delete entry.started_at;
		for (const entry of copy.finished || []) {
			delete entry.started_at;
			delete entry.finished_at;
		}
	}
	return copy;
}
// start, next, finish --dry and end, in that order; every answer and the state after each.
function session(dir) {
	const out = [];
	const begin = ok(dir, "start", "0001");
	const loopId = begin.json.loop_id;
	out.push({ command: "start", answer: begin.json, state: readLoopState(dir, loopId) });
	const step = (...args) => {
		const run = ok(dir, ...args);
		out.push({ command: args.join(" ").replace(loopId, "<loop>"), answer: run.json, state: readLoopState(dir, loopId) });
	};
	step("next", loopId);
	step("finish", loopId, "1", "--result", "met", "--dry");
	step("next", loopId);
	step("finish", loopId, "3", "--result", "met", "--dry");
	step("finish", loopId, "2", "--result", "met", "--dry");
	step("next", loopId);
	step("end", loopId);
	return { loopId, out };
}

test("fields", "AC36-state-and-answers-unchanged", () => {
	const now = session(repo("ac36-now", FANOUT_FILES));
	const before = session(prior("ac36-prior", FANOUT_FILES));
	assert.equal(now.out.length, before.out.length);
	const last = now.out[now.out.length - 1].state;
	assert.equal(last.version, 1, `the state's version is ${last.version}, not 1`);
	assert.ok(last.ended, "end recorded no ended object");
	for (let index = 0; index < now.out.length; index++) {
		const a = now.out[index];
		const b = before.out[index];
		assert.equal(a.command, b.command);
		assert.deepEqual(normalised(a.answer, now.loopId), normalised(b.answer, before.loopId), `${a.command} answered differently from PRE_ASD007's loop.js`);
		assert.deepEqual(normalised(a.state, now.loopId), normalised(b.state, before.loopId), `the state after ${a.command} differs from PRE_ASD007's beyond the new fields`);
	}
});

test("fields", "AC36-check-loop-unchanged", () => {
	const run = spawnSync("git", ["diff", "--quiet", PRE_ASD007, "--", "skills/ai-layout/scripts/check-loop.sh"], { cwd: PLUGIN, env: ENV });
	assert.equal(run.status, 0, `check-loop.sh differs from PRE_ASD007 (git diff exited ${run.status})`);
});

// ==== render (plan ASD-007 Step 3; AC1, AC18–AC32, AC36 usage, AC37–AC42, AC49, AC51, AC51a) =
// The pure watch.frame renderer and the one-shot plain-mode CLI.
// In-process cases call watch.frame with a fixed `now`; CLI cases spawn the fixture's loop.js.
// Cases for this group go below this marker only.
// ---- marker: render ----

// The watcher's seams, each reported as missing rather than crashing the group.
function watchApi(name) {
	needLoop();
	const api = require(LOOP).watch;
	if (!api || typeof api[name] !== "function") throw new Error(`loop.js exports no watch.${name}()`);
	return api;
}
const frameOf = (...args) => watchApi("frame").frame(...args);
const WATCH_ID = "loop-20261102T100000Z-abc123";
const T0 = Date.parse("2026-11-02T10:00:00.000Z");
const at = (seconds) => new Date(T0 + seconds * 1000).toISOString();
const chars = (text) => Array.from(text).length;
// A step of steps[]: explicit when it has a Depends on: line.
const st = (number, { done = false, depends } = {}) => ({ number, id: `S${number}`, done, explicit: depends !== undefined, depends: depends || [] });
function loopState({ steps, running = [], pending = [], finished = [], causes = [], ended, created = 0, plan: planPath = "ai-factory/plans/0001-x.md" }) {
	const state = {
		schema: "fc-loop-state",
		version: 1,
		loop_id: WATCH_ID,
		created_at: at(created),
		plan: planPath,
		host: "claude",
		max_parallel: 3,
		effective_parallel: 3,
		step_timeout: 30,
		timeout_enforced: true,
		notes: [],
		steps,
		running,
		pending,
		finished,
		ran: [],
		causes,
	};
	if (ended) state.ended = ended;
	return state;
}
const five = (done = []) => [1, 2, 3, 4, 5].map((n) => st(n, { done: done.includes(n) }));
// The frame's step line for step n: icon, space, S<n>.
const STEP_LINE = /^\S S(\d+)(?: |$)/u;
function stepLineOf(lines, number) {
	const found = lines.filter((line) => (line.match(STEP_LINE) || [])[1] === String(number));
	assert.equal(found.length, 1, `Step ${number} has ${found.length} step line(s), not 1:\n${lines.join("\n")}`);
	return found[0];
}
const draw = (state, { titles = null, now = 0, width = 100, color = false } = {}) => frameOf(state, titles, T0 + now * 1000, { details: false, color, width });
// A fixture with a loop state written under the loop directory (ignored, so the tree stays clean).
function watchRepo(name, state, files = {}) {
	const dir = repo(name, files);
	fs.mkdirSync(path.join(dir, LOOP_DIR, state.loop_id), { recursive: true });
	writeLoopState(dir, state.loop_id, state);
	return dir;
}
// `node ai-factory/make/loop.js watch …` in the fixture, stdout piped (not a TTY).
function watchRun(dir, args, { env = {}, expect = 0 } = {}) {
	const runEnv = { ...ENV, ...env };
	delete runEnv.COLUMNS;
	if (env.COLUMNS !== undefined) runEnv.COLUMNS = env.COLUMNS;
	const run = spawnSync(process.execPath, ["ai-factory/make/loop.js", "watch", ...args], { cwd: dir, encoding: "utf8", env: runEnv, timeout: 15000 });
	assert.ok(!run.error, `watch did not exit by itself: ${run.error && run.error.message}`);
	if (/unknown subcommand 'watch'/.test(run.stderr))
		throw new Error(`watch exited ${run.status}, not ${expect === 0 ? 0 : "a refusal"} (stderr: ${run.stderr.trim().split("\n")[0]})`);
	if (run.status !== expect) throw new Error(`watch exited ${run.status}, not ${expect} (stderr: ${run.stderr.trim().split("\n")[0]})`);
	return run;
}
const PLAN_FIVE = plan(
	"Five",
	"- [x] Step 1 — First thing.",
	"- [ ] **Step 2 — Add the parser**",
	"- [ ] Step 3 — Third thing.",
	"- [ ] Step 4 — Fourth thing.",
	"- [ ] Step 5 — Fifth thing.",
);

test("render", "AC1-one-snapshot", () => {
	const dir = watchRepo("ac1", loopState({ steps: five([1, 2]) }), { "ai-factory/plans/0001-x.md": PLAN_FIVE });
	const run = watchRun(dir, [WATCH_ID]);
	assert.equal(run.stdout.split(`/fc:loop ${WATCH_ID}`).length - 1, 1, `stdout holds ${run.stdout.split(`/fc:loop ${WATCH_ID}`).length - 1} frame headers, not 1`);
	assert.match(run.stdout, /2\/5 steps/, "the snapshot has no 2/5 bar");
	assert.match(run.stdout, /Add the parser/, "the snapshot has no Step 2 title");
});

test("render", "AC51-plain-one-shot", () => {
	const dir = watchRepo("ac51", loopState({ steps: five([1]), running: [{ step: 2, mode: "main", started_at: at(0) }] }));
	const began = Date.now();
	watchRun(dir, [WATCH_ID]);
	assert.ok(Date.now() - began < 10000, `watch took ${Date.now() - began} ms to exit`);
});

test("render", "AC18-bar-and-plan", () => {
	const lines = draw(loopState({ steps: five([1, 2]), plan: "ai-factory/plans/0001-x.md" }));
	assert.ok(lines.some((line) => /\b2\/5 steps\b/.test(line)), `no line reads 2/5 steps:\n${lines.join("\n")}`);
	assert.ok(lines.some((line) => line.includes("ai-factory/plans/0001-x.md")), "the plan path is not drawn");
});

test("render", "AC19-one-line-per-step", () => {
	const steps = [3, 1, 7, 2, 9].map((n) => st(n));
	const lines = draw(loopState({ steps, causes: [{ kind: "failed", step: 7, message: "x" }] }));
	const numbers = lines.map((line) => (line.match(STEP_LINE) || [])[1]).filter(Boolean).map(Number);
	assert.deepEqual(numbers, [3, 1, 7, 2, 9], `step lines are for ${numbers.join(", ")}, not 3, 1, 7, 2, 9`);
});

test("render", "AC20-title", () => {
	const dir = repo("ac20", { "ai-factory/plans/0001-x.md": PLAN_FIVE });
	const titles = watchApi("titles").titles(dir, "ai-factory/plans/0001-x.md");
	assert.ok(titles instanceof Map, "watch.titles() returned no Map for a readable plan");
	assert.equal(titles.get(2), "Add the parser");
	assert.equal(titles.get(1), "First thing.");
	assert.match(stepLineOf(draw(loopState({ steps: five([1]) }), { titles }), 2), /^\S S2 +Add the parser +ready/u);
});

test("render", "AC21-plan-missing", () => {
	const state = loopState({ steps: five([1]), plan: "ai-factory/plans/0009-gone.md" });
	const dir = watchRepo("ac21", state);
	assert.equal(watchApi("titles").titles(dir, state.plan), null, "watch.titles() returned titles for a missing plan");
	const lines = draw(state);
	assert.match(stepLineOf(lines, 1), /^\S S1 +done$/u);
	assert.match(stepLineOf(lines, 2), /^\S S2 +ready$/u);
	const run = watchRun(dir, [WATCH_ID]);
	assert.match(run.stdout, /S5 +waiting on 2, 3, 4/);
});

test("render", "R4-plan-outside", () => {
	const steps = ["- [ ] Step 1 — LEAKED-TITLE."];
	const dir = repo("r4", { "outside.md": plan("Outside", ...steps), "ai-factory/notplans/0001-x.md": plan("Elsewhere", ...steps) });
	const above = path.join(path.dirname(dir), `${path.basename(dir)}-outside.md`);
	fs.writeFileSync(above, `${plan("Above", ...steps).join("\n")}\n`);
	try {
		fs.symlinkSync(path.join(dir, "outside.md"), path.join(dir, "ai-factory/plans/0002-link.md"));
		for (const rel of [`../${path.basename(above)}`, "outside.md", "ai-factory/plans/../../outside.md", "ai-factory/notplans/0001-x.md", "ai-factory/plans/0002-link.md", "/etc/hosts"])
			assert.equal(watchApi("titles").titles(dir, rel), null, `watch.titles() read '${rel}', outside ai-factory/plans/`);
		const done = repo("r4-done", { "ai-factory/plans/done/0003-x.md": plan("Done", ...steps) });
		assert.equal(watchApi("titles").titles(done, "ai-factory/plans/done/0003-x.md").get(1), "LEAKED-TITLE.", "a plan under plans/done/ is not read");
	} finally {
		fs.rmSync(above, { force: true });
	}
});

test("render", "AC22-done", () => {
	assert.match(stepLineOf(draw(loopState({ steps: five([1]) })), 1), /\bdone\b/);
});

test("render", "AC23-running-main", () => {
	const line = stepLineOf(draw(loopState({ steps: five([1]), running: [{ step: 2, mode: "main", started_at: at(0) }] })), 2);
	assert.match(line, /\brunning\b/);
	assert.match(line, /\bmain\b/);
});

test("render", "AC24-running-worktree", () => {
	const running = [2, 3].map((step) => ({ step, mode: "worktree", worktree: `ai-factory/runs/tmp/worktrees/W-S${step}`, started_at: at(0) }));
	const lines = draw(loopState({ steps: five([1]), running }));
	for (const n of [2, 3]) assert.match(stepLineOf(lines, n), /\brunning\b.*\bworktree\b/);
});

test("render", "AC25-applying", () => {
	const finished = [{ step: 2, mode: "worktree", result: "met", started_at: at(0), finished_at: at(10) }];
	assert.match(stepLineOf(draw(loopState({ steps: five([1]), pending: [2], finished })), 2), /\bapplying\b/);
});

test("render", "AC26-failed", () => {
	const finished = [{ step: 3, mode: "worktree", result: "failed", started_at: at(0), finished_at: at(10) }];
	assert.match(stepLineOf(draw(loopState({ steps: five([1, 2]), finished })), 3), /\bfailed\b/);
});

test("render", "AC27-timeout", () => {
	const finished = [{ step: 3, mode: "worktree", result: "timeout", started_at: at(0), finished_at: at(10) }];
	assert.match(stepLineOf(draw(loopState({ steps: five([1, 2]), finished })), 3), /\btimeout\b/);
});

test("render", "AC28-waiting-explicit", () => {
	const steps = [st(1, { done: true }), st(2, { depends: [1] }), st(3, { depends: [1] }), st(4, { depends: [2, 3] })];
	assert.match(stepLineOf(draw(loopState({ steps })), 4), /waiting on 2, 3$/);
});

test("render", "AC29-waiting-implicit", () => {
	const steps = [st(1, { done: true }), st(2), st(3)];
	const line = stepLineOf(draw(loopState({ steps })), 3);
	assert.match(line, /waiting on 2$/);
});

test("render", "AC30-ready", () => {
	const steps = [st(1, { done: true }), st(2, { done: true }), st(3, { depends: [1] }), st(4, { done: true }), st(5)];
	const lines = draw(loopState({ steps }));
	assert.match(stepLineOf(lines, 5), /\bready$/);
	assert.match(stepLineOf(lines, 3), /\bready$/);
});

test("render", "AC31-cause", () => {
	const causes = [{ kind: "conflict", step: 3, message: "git apply --3way left conflict markers in src.txt", files: ["src.txt"] }];
	const lines = draw(loopState({ steps: five([1, 2]), causes }));
	const line = lines.find((text) => text.includes("git apply --3way left conflict markers in src.txt"));
	assert.ok(line, `no line shows the cause message:\n${lines.join("\n")}`);
	assert.match(line, /\bconflict\b/);
	assert.match(line, /\bS3\b/);
});

test("render", "AC32-ended-code-4", () => {
	const lines = draw(loopState({ steps: five([1, 2]), ended: { at: at(60), code: 4 } }), { now: 600 });
	assert.ok(lines.some((line) => /\bended\b/.test(line) && /\bcode 4\b/.test(line)), `no line says ended with code 4:\n${lines.join("\n")}`);
	assert.ok(!lines.some((line) => /\brunning ·/.test(line)), "an ended loop is drawn as running");
});

test("render", "AC37-elapsed-formats", () => {
	for (const [seconds, text] of [[252, "4m12s"], [37, "37s"], [3852, "1h04m12s"], [0, "0s"], [60, "1m00s"]]) {
		const line = stepLineOf(draw(loopState({ steps: five([1]), running: [{ step: 2, mode: "main", started_at: at(100) }] }), { now: 100 + seconds }), 2);
		assert.ok(line.endsWith(` ${text}`), `${seconds} s is drawn as '${line}', not ending in ${text}`);
	}
});

test("render", "AC38-elapsed-unknown", () => {
	const lines = draw(loopState({ steps: five([1]), running: [{ step: 2, mode: "main" }] }), { now: 10 });
	assert.match(stepLineOf(lines, 2), /\brunning main +unknown$/);
	assert.match(stepLineOf(lines, 1), /done$/);
	assert.match(stepLineOf(lines, 3), /waiting on 2$/);
});

test("render", "AC39-durations", () => {
	const finished = [
		{ step: 1, mode: "main", result: "met", started_at: at(0), finished_at: at(252) },
		{ step: 2, mode: "worktree", result: "failed", started_at: at(300), finished_at: at(552) },
		{ step: 3, mode: "worktree", result: "timeout", started_at: at(300), finished_at: at(552) },
	];
	const lines = draw(loopState({ steps: five([1]), finished }), { now: 9000 });
	for (const n of [1, 2, 3]) assert.match(stepLineOf(lines, n), / 4m12s$/);
});

test("render", "AC40-duration-unknown", () => {
	for (const record of [{ finished_at: at(252) }, { started_at: at(0) }]) {
		const finished = [{ step: 1, mode: "main", result: "met", ...record }];
		const lines = draw(loopState({ steps: five([1]), finished }), { now: 9000 });
		assert.match(stepLineOf(lines, 1), /\bdone +unknown$/);
		assert.match(stepLineOf(lines, 2), /\bready$/);
	}
});

test("render", "AC41-ticked-before-start", () => {
	const line = stepLineOf(draw(loopState({ steps: five([1]) }), { now: 9000 }), 1);
	assert.match(line, /\bdone$/, `Step 1 is drawn as '${line}', with something after done`);
});

test("render", "AC42-total", () => {
	const running = draw(loopState({ steps: five([1]) }), { now: 600 });
	assert.ok(running.some((line) => /running · 10m00s elapsed/.test(line)), `no running · 10m00s elapsed line:\n${running.join("\n")}`);
	const ended = draw(loopState({ steps: five([1]), ended: { at: at(125), code: 0 } }), { now: 9999 });
	assert.ok(ended.some((line) => /ended \(code 0\) · 2m05s/.test(line)), `the ended total is not measured to ended.at:\n${ended.join("\n")}`);
	const unknown = draw({ ...loopState({ steps: five([1]) }), created_at: "not a time" }, { now: 600 });
	assert.ok(unknown.some((line) => /running · unknown elapsed/.test(line)), "an unreadable created_at is not drawn as unknown");
});

test("render", "AC49-plain-non-tty", () => {
	const state = loopState({ steps: five([1]), running: [{ step: 2, mode: "main", started_at: at(0) }], causes: [{ kind: "failed", step: 2, message: "boom" }] });
	const dir = watchRepo("ac49", state, { "ai-factory/plans/0001-x.md": PLAN_FIVE });
	for (const env of [{}, { TERM: "xterm-256color" }]) {
		const run = watchRun(dir, [WATCH_ID], { env });
		assert.ok(!run.stdout.includes("\u001b"), "plain output holds U+001B");
		assert.ok(!run.stdout.includes("\u009b"), "plain output holds U+009B");
	}
});

test("render", "AC36-usage-gains-watch", () => {
	needLoop();
	const LINE = "       loop.js watch [<loop-id>] [--follow] [--details] [--width 40-500]";
	const now = require(LOOP).USAGE;
	if (!now.split("\n").some((line) => line.includes("loop.js watch"))) throw new Error("USAGE has no 'loop.js watch' line");
	const pre = prior("usage", {});
	const before = require(path.join(pre, "ai-factory/make/loop.js")).USAGE;
	assert.equal(now, `${before}\n${LINE}`, "USAGE is not PRE_ASD007's USAGE plus exactly the watch line");
	const cur = repo("usage-now", {});
	for (const name of ["frobnicate", ""]) {
		const a = cli(cur, ...(name ? [name] : []));
		const b = cli(pre, ...(name ? [name] : []));
		assert.equal(a.status, b.status, `unknown subcommand '${name}' exits ${a.status}, not ${b.status}`);
		assert.equal(a.json.usage, now);
		assert.equal(b.json.usage, before);
		const strip = ({ usage, ...rest }) => rest;
		assert.deepEqual(strip(a.json), strip(b.json), `unknown subcommand '${name}' answers differently`);
		assert.equal(a.stderr, b.stderr.replace(before, now), `unknown subcommand '${name}' writes different stderr`);
	}
});

test("render", "AC51a-width-order", () => {
	const { width } = watchApi("width");
	const tty = { isTTY: true, columns: 120 };
	assert.equal(width({ arg: 60, env: { COLUMNS: "80" }, ...tty }), 60, "--width does not win over COLUMNS");
	assert.equal(width({ arg: null, env: { COLUMNS: "80" }, ...tty }), 80, "COLUMNS does not win over the TTY's columns");
	assert.equal(width({ arg: null, env: {}, ...tty }), 120, "the TTY's columns are not used");
	assert.equal(width({ arg: null, env: {}, isTTY: false, columns: 120 }), 100, "a pipe's columns are used");
	assert.equal(width({ arg: null, env: {}, isTTY: false }), 100, "the default is not 100");
	for (const bad of ["abc", "80.5", "", "-80", " 80"]) {
		assert.equal(width({ arg: null, env: { COLUMNS: bad }, ...tty }), 120, `COLUMNS '${bad}' is not ignored on a TTY`);
		assert.equal(width({ arg: null, env: { COLUMNS: bad }, isTTY: false }), 100, `COLUMNS '${bad}' is not ignored on a pipe`);
	}
	assert.equal(width({ arg: 30, env: {}, isTTY: false }), 40, "--width 30 is not drawn at 40");
	assert.equal(width({ arg: null, env: { COLUMNS: "30" }, isTTY: false }), 40, "COLUMNS=30 is not drawn at 40");
	assert.equal(width({ arg: null, env: {}, isTTY: true, columns: 30 }), 40, "a 30-column TTY is not drawn at 40");
});

const LONG_TITLE = "Seventy-two characters of a step title, cut down to fit the narrow view.";
test("render", "AC51a-title-cut", () => {
	assert.equal(chars(LONG_TITLE), 72, "the fixture title is not 72 characters");
	const dir = watchRepo("title-cut", loopState({ steps: [st(1), st(2)] }), {
		"ai-factory/plans/0001-x.md": plan("Cut", `- [ ] Step 1 — ${LONG_TITLE}`, "- [ ] Step 2 — Short."),
	});
	const run = watchRun(dir, [WATCH_ID, "--width", "60"]);
	const line = stepLineOf(run.stdout.replace(/\n$/, "").split("\n"), 1);
	assert.ok(chars(line) <= 60, `Step 1's line is ${chars(line)} characters wide: '${line}'`);
	assert.ok(/…/.test(line) && !line.includes(LONG_TITLE), `Step 1's title is not cut with …: '${line}'`);
	assert.match(line, /…\s+ready$/, `the cut title does not end in …: '${line}'`);
});

test("render", "AC51a-all-lines-fit", () => {
	const steps = Array.from({ length: 12 }, (_, i) => st(i + 1, { done: i < 4, depends: i === 9 ? [5, 6, 7, 8, 9] : undefined }));
	const titles = new Map(steps.map((step) => [step.number, `Step title ${step.number} ${"long words ".repeat(step.number)}`.trim()]));
	const state = loopState({
		steps,
		plan: `ai-factory/plans/${"very-long-plan-name-".repeat(6)}x.md`,
		running: [{ step: 5, mode: "worktree", started_at: at(0) }, { step: 6, mode: "worktree", started_at: at(30) }],
		pending: [7],
		finished: [{ step: 1, mode: "main", result: "met", started_at: at(0), finished_at: at(4000) }, { step: 8, mode: "worktree", result: "failed", started_at: at(0), finished_at: at(60) }],
		causes: [{ kind: "failed", step: 8, message: `the implementer reported ${"a very long failure message ".repeat(8)}` }],
	});
	const cells = {};
	for (const width of [40, 60, 100]) {
		for (const s of [state, { ...state, ended: { at: at(5000), code: 1 } }]) {
			const lines = draw(s, { titles, now: 5000, width });
			for (const line of lines) assert.ok(chars(line) <= width, `at width ${width} a line is ${chars(line)} characters: '${line}'`);
			assert.equal(lines.filter((line) => STEP_LINE.test(line)).length, 12, `at width ${width} not every step has a line`);
			const bar = lines.find((line) => /\d+\/12 steps/.test(line));
			assert.ok(bar, `at width ${width} there is no bar`);
			cells[width] = chars(bar.replace(/ *\d+\/12 steps.*$/, "").replace(/[[\]]/g, ""));
		}
	}
	assert.ok(cells[40] < cells[100], `the bar has ${cells[40]} cells at 40 and ${cells[100]} at 100`);
	assert.ok(cells[100] <= 30, `the bar has ${cells[100]} cells at 100, more than 30`);
});

const WIDE_PLAN = plan("Wide", ...[1, 2, 3].map((n) => `- [ ] Step ${n} — ${"A rather long step title that goes on ".repeat(4)}`));
test("render", "AC51a-default-100", () => {
	const dir = watchRepo("default-100", loopState({ steps: [st(1), st(2), st(3)] }), { "ai-factory/plans/0001-x.md": WIDE_PLAN });
	const run = watchRun(dir, [WATCH_ID]);
	const widest = Math.max(...run.stdout.replace(/\n$/, "").split("\n").map(chars));
	assert.ok(widest <= 100, `a line is ${widest} characters wide, more than 100`);
	assert.ok(widest >= 90, `the widest line is ${widest} characters: the default is not 100`);
});

test("render", "AC51a-columns-env", () => {
	const dir = watchRepo("columns-env", loopState({ steps: [st(1), st(2), st(3)] }), { "ai-factory/plans/0001-x.md": WIDE_PLAN });
	const run = watchRun(dir, [WATCH_ID], { env: { COLUMNS: "50" } });
	const widest = Math.max(...run.stdout.replace(/\n$/, "").split("\n").map(chars));
	assert.ok(widest <= 50, `with COLUMNS=50 a line is ${widest} characters wide`);
	assert.ok(widest >= 45, `with COLUMNS=50 the widest line is ${widest} characters`);
});

test("render", "AC51a-refused", () => {
	const dir = watchRepo("refused", loopState({ steps: five([1]) }));
	const loopDir = path.join(dir, LOOP_DIR);
	const root = typeof process.getuid === "function" && process.getuid() === 0;
	if (!root) fs.chmodSync(loopDir, 0o000);
	try {
		const cases = [
			[["--width", "39"], "39"],
			[["--width", "501"], "501"],
			[["--width", "60.5"], "60.5"],
			[["--width", "-60"], "-60"],
			[["--width", "abc"], "abc"],
			[["--width"], "--width"],
			[["--width", "60", "--width", "70"], "70"],
		];
		for (const [flags, named] of cases) {
			const run = watchRun(dir, [WATCH_ID, ...flags], { expect: 2 });
			const lines = run.stderr.replace(/\n$/, "").split("\n");
			assert.ok(lines[0].includes(named) && /refused/.test(lines[0]), `${flags.join(" ")}: the first stderr line '${lines[0]}' does not refuse '${named}'`);
			assert.match(lines[1] || "", /^usage: loop\.js watch /, `${flags.join(" ")}: the usage does not follow the refusal`);
			assert.equal(lines.length, 2, `${flags.join(" ")}: stderr holds ${lines.length} lines, not 2`);
			assert.equal(run.stdout, "", `${flags.join(" ")}: a frame was printed`);
		}
	} finally {
		if (!root) fs.chmodSync(loopDir, 0o755);
	}
	if (root) throw skip("running as root: the unreadable loop directory proves nothing (the refusal itself was checked)");
});


// ==== details (plan ASD-007 Step 4; AC43–AC45, AC49 --details) ===============================
// --details, character stripping and wrapped saved output.
// The fixture puts control characters into a cause message, an output and a plan title.
// Cases for this group go below this marker only.
// ---- marker: details ----

const WORKTREE_S2 = "ai-factory/runs/tmp/worktrees/W-S2";
// AC43's state: Step 2 runs in a worktree and Step 1's finished[] record holds a saved output.
// Neither string occurs in any cause message.
const detailsState = (output = "first line\nSECRET-MARKER\n") =>
	loopState({
		steps: five([1]),
		running: [{ step: 2, mode: "worktree", worktree: WORKTREE_S2, started_at: at(0) }],
		finished: [{ step: 1, mode: "main", result: "met", started_at: at(0), finished_at: at(30), output }],
		causes: [{ kind: "failed", step: 4, message: "an unrelated cause" }],
	});
const drawDetails = (state, { titles = null, now = 60, width = 100, details = true } = {}) => frameOf(state, titles, T0 + now * 1000, { details, color: false, width });
// The lines under step n's line, up to the next step line or a blank line.
function underStep(lines, number) {
	const index = lines.indexOf(stepLineOf(lines, number));
	const out = [];
	for (let i = index + 1; i < lines.length && lines[i] !== "" && !STEP_LINE.test(lines[i]); i++) out.push(lines[i]);
	return out;
}
const outLines = (text) => text.replace(/\n$/, "").split("\n");

test("details", "AC43-default-hides", () => {
	const state = detailsState();
	const dir = watchRepo("ac43", state, { "ai-factory/plans/0001-x.md": PLAN_FIVE });
	const outputs = [watchRun(dir, [WATCH_ID]).stdout, drawDetails(state, { details: false }).join("\n")];
	for (const text of outputs) {
		assert.ok(!text.includes(WORKTREE_S2), `the default view shows the worktree path:\n${text}`);
		assert.ok(!text.includes("SECRET-MARKER"), `the default view shows the saved output:\n${text}`);
	}
});

test("details", "AC44-details-shows", () => {
	const state = detailsState();
	const dir = watchRepo("ac44", state, { "ai-factory/plans/0001-x.md": PLAN_FIVE });
	const run = watchRun(dir, [WATCH_ID, "--details"]);
	for (const [how, lines] of [["CLI", outLines(run.stdout)], ["frame", drawDetails(state)]]) {
		const two = [stepLineOf(lines, 2), ...underStep(lines, 2)].join("\n");
		assert.ok(two.includes(WORKTREE_S2), `${how}: Step 2's line and the lines under it do not show ${WORKTREE_S2}:\n${lines.join("\n")}`);
		const one = underStep(lines, 1).join("\n");
		assert.ok(one.includes("SECRET-MARKER"), `${how}: SECRET-MARKER is missing under Step 1:\n${lines.join("\n")}`);
		assert.ok(one.includes("first line"), `${how}: the first line of Step 1's saved output is missing:\n${lines.join("\n")}`);
		assert.ok(!underStep(lines, 1).some((line) => line.includes("first line") && line.includes("SECRET-MARKER")), `${how}: the saved output's line break is not kept`);
		for (const n of [3, 4, 5]) assert.ok(!underStep(lines, n).join("\n").includes("SECRET-MARKER"), `${how}: the saved output is shown under Step ${n}`);
	}
});

test("details", "AC51a-details-wrapped", () => {
	const long = Array.from({ length: 120 }, (_, i) => String.fromCharCode(65 + (i % 26))).join("");
	assert.equal(chars(long), 120);
	const state = detailsState(`${long}\nshort tail\n`);
	const dir = watchRepo("details-wrapped", state, { "ai-factory/plans/0001-x.md": PLAN_FIVE });
	const run = watchRun(dir, [WATCH_ID, "--details", "--width", "40"]);
	for (const [how, lines] of [["CLI", outLines(run.stdout)], ["frame", drawDetails(state, { width: 40 })]]) {
		for (const line of lines) assert.ok(chars(line) <= 40, `${how}: a line is ${chars(line)} characters at --width 40: '${line}'`);
		const under = underStep(lines, 1);
		assert.ok(under.length >= 4, `${how}: the 120-character output line is not wrapped under Step 1:\n${lines.join("\n")}`);
		assert.ok(under.join("").replace(/[^A-Z]/g, "").includes(long), `${how}: the wrapped lines do not hold the whole output line:\n${under.join("\n")}`);
		assert.ok(under.some((line) => line.includes("short tail")), `${how}: the output's second line is missing`);
		const two = [stepLineOf(lines, 2), ...underStep(lines, 2)].join("").replace(/\s/g, "");
		assert.ok(two.includes(WORKTREE_S2), `${how}: the worktree path is not shown whole at --width 40`);
	}
});

// Every terminal control character of the spec: C0 except LF, DEL, C1 and the bidi controls.
const CONTROL = /[\u0000-\u0009\u000B-\u001F\u007F-\u009F؜‎‏‪-‮⁦-⁩]/u;
function noControls(text, how) {
	const found = text.match(CONTROL);
	if (found) throw new Error(`${how}: output holds U+${found[0].codePointAt(0).toString(16).toUpperCase().padStart(4, "0")} …`);
}
const BAD = "\u001b[31m\u0007\r\u007f\u009b\u0085‮\t";
const CYRILLIC = "Перевірка Л";
const PLAN_BAD = plan("Bad", `- [x] Step 1 — ${CYRILLIC}`, `- [ ] Step 2 — bad${BAD}title`, "- [ ] Step 3 — Third.");
const badState = () =>
	loopState({
		steps: [st(1, { done: true }), st(2), st(3)],
		running: [{ step: 2, mode: "main", started_at: at(0) }],
		finished: [{ step: 1, mode: "main", result: "met", started_at: at(0), finished_at: at(30), output: `out${BAD}put\nSECOND\n` }],
		causes: [{ kind: "failed", step: 3, message: `cause${BAD}\nmsg` }],
	});
// stdout as raw bytes, stdout piped.
function watchRaw(dir, args) {
	const env = { ...ENV };
	delete env.COLUMNS;
	const run = spawnSync(process.execPath, ["ai-factory/make/loop.js", "watch", ...args], { cwd: dir, env, timeout: 15000 });
	if (run.status !== 0) throw new Error(`watch exited ${run.status}, not 0 (stderr: ${String(run.stderr).trim().split("\n")[0]})`);
	return run.stdout;
}

// The two CLI runs read the clock separately, so their times are compared as placeholders.
const untimed = (lines) => lines.map((line) => line.replace(/\b(?:\d+h\d\dm\d\ds|\d+m\d\ds|\d+s)\b/g, "<t>"));

test("details", "AC45-controls-stripped", () => {
	const state = badState();
	const dir = watchRepo("ac45", state, { "ai-factory/plans/0001-x.md": PLAN_BAD });
	const titles = watchApi("titles").titles(dir, state.plan);
	assert.ok(titles instanceof Map, "watch.titles() read no titles from the fixture plan");
	const plainFrame = drawDetails(state, { titles, details: false });
	const plainRaw = watchRaw(dir, [WATCH_ID]);
	// The default views first: a missing strip is reported before --details is even run.
	noControls(plainFrame.join("\n"), "frame");
	noControls(plainRaw.toString("utf8"), "CLI");
	const detailsFrame = drawDetails(state, { titles, details: true });
	const detailsRaw = watchRaw(dir, [WATCH_ID, "--details"]);
	const views = [
		["frame", plainFrame],
		["frame --details", detailsFrame],
		["CLI", outLines(plainRaw.toString("utf8"))],
		["CLI --details", outLines(detailsRaw.toString("utf8"))],
	];
	for (const [how, lines] of views) {
		noControls(lines.join("\n"), how);
		assert.match(stepLineOf(lines, 2), /bad.*title/u, `${how}: Step 2's title is not drawn on its line`);
		const cause = lines.filter((line) => /cause|msg/u.test(line) && line !== "causes:");
		assert.equal(cause.length, 1, `${how}: the cause is not drawn on one line`);
		assert.match(cause[0], /cause.*msg/u, `${how}: the cause message is split across lines`);
		assert.ok(lines.join("\n").includes(CYRILLIC), `${how}: the Cyrillic title is not drawn intact`);
	}
	for (const [how, raw] of [["CLI", plainRaw], ["CLI --details", detailsRaw]]) {
		assert.ok(raw.includes(Buffer.from(CYRILLIC, "utf8")), `${how}: stdout's bytes do not hold ${CYRILLIC} unchanged`);
		assert.ok(raw.includes(Buffer.from([0xd0, 0x9b])), `${how}: stdout's bytes lost Л's d0 9b`);
	}
	// Every LF in --details output comes from the saved output: without the lines under Step 1,
	// the --details view is the default view line for line.
	for (const [how, plainLines, detailsLines] of [["frame", plainFrame, detailsFrame], ["CLI", untimed(outLines(plainRaw.toString("utf8"))), untimed(outLines(detailsRaw.toString("utf8")))]]) {
		const extra = underStep(detailsLines, 1);
		assert.ok(extra.some((line) => /out.*put/u.test(line)), `${how}: the saved output's first line is missing under Step 1`);
		assert.ok(extra.some((line) => line.includes("SECOND") && !/out.*put/u.test(line)), `${how}: the saved output's LF is not kept`);
		const index = detailsLines.indexOf(stepLineOf(detailsLines, 1));
		const rest = [...detailsLines.slice(0, index + 1), ...detailsLines.slice(index + 1 + extra.length)];
		assert.deepEqual(rest, plainLines, `${how}: --details adds lines other than Step 1's saved output`);
	}
});

test("details", "AC49-plain-details", () => {
	const dir = watchRepo("ac49-details", badState(), { "ai-factory/plans/0001-x.md": PLAN_BAD });
	for (const env of [{}, { TERM: "xterm-256color" }]) {
		const run = watchRun(dir, [WATCH_ID, "--details"], { env });
		assert.ok(!run.stdout.includes("\u001b"), "--details output holds U+001B");
		assert.ok(!run.stdout.includes("\u009b"), "--details output holds U+009B");
	}
});


// ==== select (plan ASD-007 Step 5; AC10–AC12, R4) ============================================
// Which loop the watcher draws when no loop ID is given, and the ended-loops table.
// The listing skips directory names that are not loop IDs and non-regular state files.
// Cases for this group go below this marker only.
// ---- marker: select ----

// A fixture holding several loop states, each under its own loop ID's directory.
function loopsRepo(name, states, files = { "ai-factory/plans/0001-x.md": PLAN_FIVE }) {
	const dir = repo(name, files);
	for (const state of states) {
		fs.mkdirSync(path.join(dir, LOOP_DIR, state.loop_id), { recursive: true });
		writeLoopState(dir, state.loop_id, state);
	}
	return dir;
}
const named = (loopId, created, extra = {}) => ({ ...loopState({ steps: five([1]), ...extra }), loop_id: loopId, created_at: created });
// `watch` with no loop ID, stdout piped.
function watchNoId(dir) {
	const env = { ...ENV };
	delete env.COLUMNS;
	const run = spawnSync(process.execPath, ["ai-factory/make/loop.js", "watch"], { cwd: dir, encoding: "utf8", env, timeout: 15000 });
	assert.ok(!run.error, `watch did not exit by itself: ${run.error && run.error.message}`);
	if (run.status !== 0) throw new Error(`watch with no loop ID exited ${run.status}, not 0 (stderr: ${run.stderr.trim().split("\n")[0]})`);
	return run;
}
const LOOP_A = "loop-20261102T120000Z-aaaaaa";
const LOOP_B = "loop-20261102T100000Z-ffffff";
const LOOP_C = "loop-20261102T110000Z-000000";
const BAR = /\d+\/\d+ steps/;

test("select", "AC10-newest-running", () => {
	// A has ended and is the newest; C's ID sorts first, so neither name order nor the ended loop
	// can stand in for created_at order among running loops.
	const dir = loopsRepo("ac10", [
		named(LOOP_A, "2026-11-02T12:00:00Z", { ended: { at: "2026-11-02T12:30:00Z", code: 0 } }),
		named(LOOP_B, "2026-11-02T10:00:00Z"),
		named(LOOP_C, "2026-11-02T11:00:00Z"),
	]);
	const run = watchNoId(dir);
	const lines = outLines(run.stdout);
	assert.ok(lines[0].includes(LOOP_C), `the snapshot is not of loop C (${LOOP_C}): '${lines[0]}'`);
	assert.ok(!run.stdout.includes(LOOP_B) && !run.stdout.includes(LOOP_A), `the snapshot names another loop:\n${run.stdout}`);
	assert.match(run.stdout, BAR, "no progress bar: the output is not a snapshot");
	stepLineOf(lines, 2);
});

test("select", "AC11-ended-table", () => {
	const older = "loop-20261102T090000Z-111111";
	const newer = "loop-20261102T080000Z-222222";
	const dir = loopsRepo("ac11", [
		named(older, "2026-11-02T09:00:00Z", { ended: { at: "2026-11-02T09:30:00Z", code: 0 }, plan: "ai-factory/plans/0001-older.md" }),
		named(newer, "2026-11-02T13:00:00Z", { ended: { at: "2026-11-02T13:30:00Z", code: 4 }, plan: "ai-factory/plans/0002-newer.md" }),
	]);
	const run = watchNoId(dir);
	const lines = outLines(run.stdout);
	const rows = lines.filter((line) => line.includes(older) || line.includes(newer));
	assert.equal(rows.length, 2, `the table has ${rows.length} loop rows, not 2:\n${run.stdout}`);
	assert.ok(rows[0].includes(newer) && rows[1].includes(older), `the rows are not newest created_at first:\n${run.stdout}`);
	for (const [row, planPath, code, created] of [
		[rows[0], "ai-factory/plans/0002-newer.md", 4, "2026-11-02T13:00:00Z"],
		[rows[1], "ai-factory/plans/0001-older.md", 0, "2026-11-02T09:00:00Z"],
	]) {
		assert.ok(row.includes(planPath), `the row does not show the plan ${planPath}: '${row}'`);
		assert.match(row, new RegExp(`\\bended ${code}\\b`), `the row does not show 'ended ${code}': '${row}'`);
		assert.ok(row.includes(created), `the row does not show created_at ${created}: '${row}'`);
	}
	assert.ok(!BAR.test(run.stdout), `the table prints a progress bar:\n${run.stdout}`);
	assert.ok(!lines.some((line) => STEP_LINE.test(line)), `the table prints a step line:\n${run.stdout}`);
});

test("select", "AC12-no-loops", () => {
	const missing = repo("ac12-missing", {});
	const empty = repo("ac12-empty", {});
	fs.mkdirSync(path.join(empty, LOOP_DIR), { recursive: true });
	for (const [how, dir] of [["no loop directory", missing], ["an empty loop directory", empty]]) {
		const run = watchNoId(dir);
		const lines = outLines(run.stdout);
		assert.equal(lines.length, 1, `${how}: ${lines.length} lines, not 1:\n${run.stdout}`);
		assert.match(lines[0], /no loops under ai-factory\/runs\/tmp\/loop\//, `${how}: '${lines[0]}' does not say there are no loops`);
	}
	assert.ok(!fs.existsSync(path.join(missing, LOOP_DIR)), "the watcher created the loop directory");
});

test("select", "R4-listing-skips", () => {
	// Both skipped entries hold a running loop newer than the one ended loop: if either were read,
	// it would be drawn as a snapshot instead of the table.
	const ended = "loop-20261102T070000Z-333333";
	const linked = "loop-20261102T140000Z-444444";
	const dir = loopsRepo("r4-skips", [named(ended, "2026-11-02T07:00:00Z", { ended: { at: "2026-11-02T07:30:00Z", code: 0 } })]);
	const notLoop = path.join(dir, LOOP_DIR, "not-a-loop");
	fs.mkdirSync(notLoop, { recursive: true });
	fs.writeFileSync(path.join(notLoop, "state.json"), JSON.stringify(named("not-a-loop", "2026-11-02T15:00:00Z")));
	const elsewhere = path.join(dir, "ai-factory/runs/tmp/elsewhere.json");
	fs.writeFileSync(elsewhere, JSON.stringify(named(linked, "2026-11-02T14:00:00Z")));
	fs.mkdirSync(path.join(dir, LOOP_DIR, linked), { recursive: true });
	fs.symlinkSync(elsewhere, path.join(dir, LOOP_DIR, linked, "state.json"));
	const run = watchNoId(dir);
	assert.ok(!BAR.test(run.stdout), `a skipped entry was drawn as a snapshot:\n${run.stdout}`);
	assert.ok(run.stdout.includes(ended), `the ended loop is not listed:\n${run.stdout}`);
	assert.ok(!run.stdout.includes("not-a-loop"), `the directory not-a-loop is listed:\n${run.stdout}`);
	assert.ok(!run.stdout.includes(linked), `the symlinked state.json is listed:\n${run.stdout}`);
});


// ==== errors (plan ASD-007 Step 5; AC13–AC16) ================================================
// Refusals before any file is read, a missing state and bounded rereads.
// AC13 runs with the loop directory unreadable and skips when the check runs as root.
// Cases for this group go below this marker only.
// ---- marker: errors ----

test("errors", "AC13-refusals", () => {
	const dir = watchRepo("ac13", loopState({ steps: five([1]) }));
	const loopDir = path.join(dir, LOOP_DIR);
	const root = typeof process.getuid === "function" && process.getuid() === 0;
	if (!root) fs.chmodSync(loopDir, 0o000);
	try {
		for (const arg of ["../../etc", "loop-1", "--foo"]) {
			const run = watchRun(dir, [arg], { expect: 2 });
			const lines = run.stderr.replace(/\n$/, "").split("\n");
			assert.ok(lines[0].includes(arg) && /refused/.test(lines[0]), `${arg}: the first stderr line '${lines[0]}' does not refuse '${arg}'`);
			assert.match(lines[1] || "", /^usage: loop\.js watch /, `${arg}: the usage does not follow the refusal`);
			assert.equal(lines.length, 2, `${arg}: stderr holds ${lines.length} lines, not 2`);
			assert.equal(run.stdout, "", `${arg}: a frame was printed`);
		}
	} finally {
		if (!root) fs.chmodSync(loopDir, 0o755);
	}
	if (root) throw skip("running as root: the unreadable loop directory proves nothing (the refusal itself was checked)");
});

test("errors", "AC14-missing-state", () => {
	const dir = repo("ac14", {});
	const run = watchRun(dir, [WATCH_ID], { expect: 2 });
	const lines = run.stderr.replace(/\n$/, "").split("\n");
	assert.equal(lines.length, 1, `stderr holds ${lines.length} lines, not 1:\n${run.stderr}`);
	assert.ok(lines[0].includes(`no loop state for ${WATCH_ID}`), `'${lines[0]}' does not say 'no loop state for ${WATCH_ID}'`);
	assert.equal(run.stdout, "", "a frame was printed");
});

// A sink for watch.cli's stdout and stderr.
const sink = () => ({ text: "", isTTY: false, write(chunk) { this.text += chunk; return true; } });

test("errors", "AC15-torn-then-valid", () => {
	const state = loopState({ steps: five([1, 2]) });
	const dir = watchRepo("ac15", state, { "ai-factory/plans/0001-x.md": PLAN_FIVE });
	const api = watchApi("readState");
	const reader = () => {
		const texts = ['{"schema":', JSON.stringify(state)];
		const reader = (file) => {
			reader.files.push(String(file));
			return texts[Math.min(reader.files.length - 1, texts.length - 1)];
		};
		reader.files = [];
		return reader;
	};
	const direct = reader();
	const read = api.readState(dir, WATCH_ID, { read: direct, pause: () => {} });
	assert.equal(direct.files.length, 2, `readState read ${direct.files.length} time(s), not 2`);
	assert.ok(direct.files.every((file) => file.endsWith(`${WATCH_ID}/state.json`)), `readState read ${direct.files.join(", ")}`);
	assert.ok(read && read.state, `readState gave ${JSON.stringify(read)}, not the parsed state`);
	assert.deepEqual(read.state, state, "readState did not give the state of the read that parsed");
	const through = reader();
	const stdout = sink();
	const stderr = sink();
	const code = api.cli([WATCH_ID], { root: dir, stdout, stderr, env: {}, read: through, pause: () => {} });
	assert.equal(code, 0, `watch.cli returned ${code}, not 0 (stderr: ${stderr.text.trim()})`);
	assert.equal(through.files.length, 2, `watch.cli read the state ${through.files.length} time(s), not 2`);
	const lines = outLines(stdout.text);
	assert.equal(lines.filter((line) => BAR.test(line)).length, 1, `not one frame:\n${stdout.text}`);
	assert.ok(lines.some((line) => line.includes("2/5")), `the frame does not draw the parsed state:\n${stdout.text}`);
	assert.equal(stderr.text, "", `stderr: ${stderr.text}`);
});

test("errors", "AC16-never-parses", () => {
	const dir = watchRepo("ac16", loopState({ steps: five([1]) }));
	fs.writeFileSync(path.join(dir, LOOP_DIR, WATCH_ID, "state.json"), '{"schema":');
	// A preload counts the reads of state.json through fs.readFileSync and their times.
	const log = path.join(dir, "reads.json");
	const preload = path.join(dir, "count-reads.js");
	fs.writeFileSync(
		preload,
		[
			'const fs = require("node:fs");',
			"const original = fs.readFileSync;",
			"const times = [];",
			'fs.readFileSync = function (file, ...rest) { if (String(file).endsWith("state.json")) times.push(Date.now()); return original.call(this, file, ...rest); };',
			`process.on("exit", () => fs.writeFileSync(${JSON.stringify(log)}, JSON.stringify(times)));`,
			"",
		].join("\n"),
	);
	const env = { ...ENV };
	delete env.COLUMNS;
	const run = spawnSync(process.execPath, ["--require", preload, "ai-factory/make/loop.js", "watch", WATCH_ID], { cwd: dir, encoding: "utf8", env, timeout: 15000 });
	assert.ok(!run.error, `watch did not exit by itself: ${run.error && run.error.message}`);
	const times = JSON.parse(fs.readFileSync(log, "utf8"));
	assert.equal(times.length, 5, `read the state ${times.length} time(s), not 5`);
	const span = times[times.length - 1] - times[0];
	assert.ok(span >= 350 && span <= 1500, `5 reads took ${span} ms, not 350–1500 ms`);
	assert.equal(run.status, 1, `watch exited ${run.status}, not 1 (stderr: ${run.stderr.trim()})`);
	const lines = run.stderr.replace(/\n$/, "").split("\n");
	assert.equal(lines.length, 1, `stderr holds ${lines.length} lines, not 1:\n${run.stderr}`);
	assert.ok(lines[0].includes(`loop state ${LOOP_DIR}/${WATCH_ID}/state.json is unreadable`), `'${lines[0]}' does not name the state file as unreadable`);
	assert.equal(run.stdout, "", "a frame was printed");
});


// ==== follow (plan ASD-007 Step 6; AC17, AC46–AC52b) =========================================
// Live and plain follow, signals, a vanished state and the stall line.
// Live mode is proved in process, through the child-process TTY harness, and by script(1).
// Cases for this group go below this marker only.
// ---- marker: follow ----

// Layer 1 (in process): the mode rules and the stall line, with an injected clock.
test("follow", "AC49-mode-matrix", () => {
	const { mode } = watchApi("mode");
	for (const isTTY of [true, false])
		for (const TERM of [undefined, "xterm", "dumb"])
			for (const NO_COLOR of [undefined, "", "1"]) {
				const env = {};
				if (TERM !== undefined) env.TERM = TERM;
				if (NO_COLOR !== undefined) env.NO_COLOR = NO_COLOR;
				const expected = isTTY && TERM !== "dumb" && !NO_COLOR ? "live" : "plain";
				const got = mode({ isTTY, env });
				assert.equal(got, expected, `mode({ isTTY: ${isTTY}, TERM: ${TERM}, NO_COLOR: ${JSON.stringify(NO_COLOR)} }) is ${got}, not ${expected}`);
			}
});

test("follow", "AC52b-stall-clock", () => {
	const { stall } = watchApi("stall");
	const running = loopState({ steps: five([1]) });
	const since = T0;
	const minutes = (n) => since + n * 60 * 1000;
	assert.equal(stall(running, since, minutes(30)), null, "a stall line at exactly step_timeout (30m)");
	assert.equal(stall(running, since, minutes(31)), "no update for 31m — the loop may have stopped; Ctrl-C to quit", "the stall line at 31m");
	assert.equal(stall({ ...running, step_timeout: 5 }, since, minutes(6)), "no update for 6m — the loop may have stopped; Ctrl-C to quit", "step_timeout 5 is not used");
	assert.equal(stall({ ...running, step_timeout: 5 }, since, minutes(4)), null, "a stall line before step_timeout 5");
	const bare = { ...running };
	delete bare.step_timeout;
	assert.equal(stall(bare, since, minutes(29)), null, "no step_timeout: not 30 by default");
	assert.match(String(stall(bare, since, minutes(45))), /^no update for 45m /, "no step_timeout: no line at 45m");
	assert.equal(stall(loopState({ steps: five([1]), ended: { at: at(10), code: 0 } }), since, minutes(90)), null, "a stall line on an ended loop");
});

// Layer 2 (required, every platform): a child-process TTY harness with real timers, real file
// changes and real signals. The harness marks its stdout as a TTY and calls the fixture's own
// watch.cli, the function main()'s watch branch calls. Each scenario runs in a driver process
// (the cases here are synchronous); the scenario function is written into it as text, so it uses
// only what the driver passes it (h).
const HARNESS = [
	'const path = require("node:path");',
	'Object.defineProperty(process.stdout, "isTTY", { value: true, configurable: true });',
	'Object.defineProperty(process.stdout, "columns", { value: Number(process.env.HARNESS_COLUMNS || 100), configurable: true, writable: true });',
	'const root = path.resolve(__dirname, "../../..");',
	'const { watch } = require(path.join(root, "ai-factory/make/loop.js"));',
	"Promise.resolve(watch.cli(process.argv.slice(2), { root })).then(",
	"	(code) => { process.exitCode = code; },",
	'	(error) => { process.stderr.write(`harness: ${error.message}\\n`); process.exitCode = 70; },',
	");",
	"",
].join("\n");
// The driver's helpers: watcher() starts the watcher, in the TTY harness (tty) or as
// `node ai-factory/make/loop.js watch` with stdout piped (plain).
const DRIVER = String.raw`
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, execFileSync } = require("node:child_process");
const ROOT = process.cwd();
const HARNESS = path.join(ROOT, "ai-factory/runs/tmp/tty-harness.js");
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const HEADER = "/fc:loop ";
function watcher(args, { tty = false, env = {}, columns = 100, preload = null } = {}) {
	const runEnv = { ...process.env, TERM: "xterm", HARNESS_COLUMNS: String(columns) };
	delete runEnv.COLUMNS;
	delete runEnv.NO_COLOR;
	Object.assign(runEnv, env);
	const argv = [...(preload ? ["--require", preload] : []), ...(tty ? [HARNESS] : ["ai-factory/make/loop.js", "watch"]), ...args];
	const child = spawn(process.execPath, argv, { cwd: ROOT, env: runEnv, stdio: ["ignore", "pipe", "pipe"] });
	const w = { child, out: "", err: "", began: Date.now(), exited: null };
	child.stdout.setEncoding("utf8");
	child.stderr.setEncoding("utf8");
	child.stdout.on("data", (chunk) => (w.out += chunk));
	child.stderr.on("data", (chunk) => (w.err += chunk));
	w.done = new Promise((resolve) => child.on("close", (code, signal) => resolve((w.exited = { code, signal, at: Date.now() }))));
	w.count = (needle, from = 0) => w.out.slice(from).split(needle).length - 1;
	w.frames = (from = 0) => w.count(HEADER, from);
	w.why = () => (w.exited ? "the watcher exited " + w.exited.code + (w.exited.signal ? " (" + w.exited.signal + ")" : "") + " after " + (w.exited.at - w.began) + " ms" + (w.err.trim() ? ": " + w.err.trim().split("\n")[0] : "") : "");
	// Waits until pred holds; the message names the measured delay, or the watcher's exit.
	w.until = async (pred, ms, what) => {
		const start = Date.now();
		for (;;) {
			if (pred(w)) return Date.now() - start;
			if (w.exited) {
				await sleep(50);
				if (pred(w)) return Date.now() - start;
				throw new Error(what + " (" + w.why() + ")");
			}
			if (Date.now() - start > ms) throw new Error(what + " (waited " + (Date.now() - start) + " ms)");
			await sleep(20);
		}
	};
	w.exit = async (ms, what) => {
		const start = Date.now();
		const timer = sleep(ms).then(() => null);
		const got = await Promise.race([w.done, timer]);
		if (!got) throw new Error(what + " (still running after " + (Date.now() - start) + " ms)");
		return { ...got, delay: Date.now() - start };
	};
	w.kill = async (signal) => {
		const start = Date.now();
		child.kill(signal);
		const got = await w.exit(5000, "no exit after " + signal);
		return { ...got, delay: Date.now() - start };
	};
	w.stop = async () => {
		if (!w.exited) {
			child.kill("SIGKILL");
			await w.done;
		}
	};
	return w;
}
const strip = (text) => text.replace(/\u001b\[[0-9;?]*[A-Za-z]/g, "");
// The text of the last frame drawn: from its header to the end of the output.
const lastFrame = (w) => w.out.slice(w.out.lastIndexOf(HEADER));
async function run(scenario, data) {
	const started = [];
	const file = path.join(ROOT, "ai-factory/runs/tmp/loop", data.loopId || "-", "state.json");
	const h = {
		data,
		file,
		sleep,
		strip,
		lastFrame,
		HEADER,
		ESC: "\u001b",
		CSI: "\u009b",
		SHOW: "\u001b[?25h",
		HIDE: "\u001b[?25l",
		watcher: (...args) => {
			const w = watcher(...args);
			started.push(w);
			return w;
		},
		write: (state) => fs.writeFileSync(file, JSON.stringify(state, null, 2) + "\n"),
		read: () => JSON.parse(fs.readFileSync(file, "utf8")),
		loop: (...args) => execFileSync(process.execPath, ["ai-factory/make/loop.js", ...args], { cwd: ROOT, stdio: "pipe" }).toString(),
		assert,
		fs,
		path,
		ROOT,
	};
	let result;
	try {
		const value = await scenario(h);
		result = { value: value === undefined ? null : value };
	} catch (error) {
		result = { error: String((error && error.message) || error).split("\n")[0] };
	}
	for (const w of started) await w.stop();
	process.stdout.write(JSON.stringify(result) + "\n");
}
`;
// Writes the harness into the fixture and runs scenario(h) in a driver there.
function drive(dir, scenario, data = {}, { timeout = 40000 } = {}) {
	const tmp = path.join(dir, "ai-factory/runs/tmp");
	fs.mkdirSync(tmp, { recursive: true });
	fs.writeFileSync(path.join(tmp, "tty-harness.js"), HARNESS);
	const file = path.join(tmp, "drive.js");
	fs.writeFileSync(file, `${DRIVER}\nrun(${scenario.toString()}, ${JSON.stringify(data)});\n`);
	const env = { ...ENV };
	delete env.COLUMNS;
	const run = spawnSync(process.execPath, [file], { cwd: dir, encoding: "utf8", env, timeout });
	if (run.error) throw new Error(`the driver did not finish: ${run.error.message}`);
	let result = null;
	try {
		result = JSON.parse(run.stdout.trim().split("\n").pop());
	} catch {
		throw new Error(`the driver printed no result (exit ${run.status}): ${(run.stderr || run.stdout).trim().split("\n")[0]}`);
	}
	if (result.error) throw new Error(result.error);
	return result.value;
}
// A running loop for the follow cases: Step 1 ticked, Step 2 running in the main tree.
const followState = (extra = {}) => loopState({ steps: five([1]), running: [{ step: 2, mode: "main", started_at: at(0) }], ...extra });
const followEnded = (extra = {}) =>
	loopState({
		steps: five([1, 2]),
		causes: [
			{ kind: "failed", step: 3, message: "FIRST-CAUSE the implementer stopped" },
			{ kind: "timeout", step: 4, message: "SECOND-CAUSE past step_timeout" },
		],
		ended: { at: at(600), code: 4 },
		...extra,
	});
const followRepo = (name, state = followState()) => watchRepo(name, state, { "ai-factory/plans/0001-x.md": PLAN_FIVE });

test("follow", "AC51-live-one-shot", () => {
	const dir = followRepo("f-ac51");
	drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId], { tty: true });
			const end = await w.exit(10000, "the live one-shot did not exit by itself");
			h.assert.equal(end.code, 0, `the live one-shot exited ${end.code}, not 0 (${w.err.trim()})`);
			h.assert.equal(w.frames(), 1, `the live one-shot drew ${w.frames()} frames, not 1`);
			h.assert.ok(/2\/5 steps|1\/5 steps/.test(w.out), "the frame has no bar");
			h.assert.ok(w.out.includes(h.ESC), "the live one-shot is not drawn in live mode (no ESC)");
		},
		{ loopId: WATCH_ID },
	);
});

test("follow", "AC51a-tty-width", () => {
	const title = "A step title far longer than any of the narrow terminal widths this case draws at, so it is cut.";
	const files = { "ai-factory/plans/0001-x.md": plan("Wide", `- [x] Step 1 — ${title}`, `- [ ] Step 2 — ${title}`, "- [ ] Step 3 — C.", "- [ ] Step 4 — D.", "- [ ] Step 5 — E.") };
	const dir = watchRepo("f-ac51a", followState({ causes: [{ kind: "conflict", step: 3, message: `a long cause message ${"x".repeat(150)}` }] }), files);
	drive(
		dir,
		async (h) => {
			for (const [columns, env, limit] of [
				[72, {}, 72],
				[72, { COLUMNS: "50" }, 50],
			]) {
				const w = h.watcher([h.data.loopId, "--follow"], { tty: true, columns, env });
				await w.until((x) => x.frames() >= 2, 3500, `columns ${columns}: two live frames were not drawn`);
				const end = await w.kill("SIGINT");
				h.assert.equal(end.code, 0, `columns ${columns}: SIGINT exited ${end.code}`);
				h.assert.ok(w.out.includes(h.ESC), `columns ${columns}: not drawn in live mode`);
				for (const line of h.strip(w.out).split("\n")) {
					const length = Array.from(line).length;
					h.assert.ok(length <= limit, `columns ${columns}${env.COLUMNS ? `, COLUMNS ${env.COLUMNS}` : ""}: a ${length}-character line, over ${limit}: '${line}'`);
				}
			}
		},
		{ loopId: WATCH_ID },
	);
});

test("follow", "AC49-tty-dumb", () => {
	const dir = followRepo("f-ac49-dumb");
	drive(
		dir,
		async (h) => {
			for (const args of [[h.data.loopId], [h.data.loopId, "--details"], [h.data.loopId, "--follow"], [h.data.loopId, "--follow", "--details"]]) {
				h.write(h.data.running);
				const w = h.watcher(args, { tty: true, env: { TERM: "dumb" } });
				if (args.includes("--follow")) {
					await w.until((x) => x.frames() >= 1, 3000, `${args.join(" ")}: no snapshot`);
					h.write(h.data.ended);
				}
				const end = await w.exit(5000, `${args.join(" ")}: the watcher did not exit`);
				h.assert.equal(end.code, 0, `${args.join(" ")}: exited ${end.code}, not 0 (${w.err.trim()})`);
				h.assert.ok(!w.out.includes(h.ESC) && !w.out.includes(h.CSI), `TERM=dumb ${args.join(" ")}: the output holds an escape sequence`);
			}
		},
		{ loopId: WATCH_ID, running: followState(), ended: followEnded() },
	);
});

test("follow", "AC49-tty-no-color", () => {
	const dir = followRepo("f-ac49-nocolor");
	drive(
		dir,
		async (h) => {
			for (const args of [[h.data.loopId], [h.data.loopId, "--follow", "--details"]]) {
				h.write(h.data.running);
				const w = h.watcher(args, { tty: true, env: { NO_COLOR: "1" } });
				if (args.includes("--follow")) {
					await w.until((x) => x.frames() >= 1, 3000, `${args.join(" ")}: no snapshot`);
					h.write(h.data.ended);
				}
				const end = await w.exit(5000, `${args.join(" ")}: the watcher did not exit`);
				h.assert.equal(end.code, 0, `${args.join(" ")}: exited ${end.code}, not 0 (${w.err.trim()})`);
				h.assert.ok(!w.out.includes(h.ESC) && !w.out.includes(h.CSI), `NO_COLOR=1 ${args.join(" ")}: the output holds an escape sequence`);
			}
		},
		{ loopId: WATCH_ID, running: followState(), ended: followEnded() },
	);
});

test("follow", "AC46-live-redraw", () => {
	const dir = repo("f-ac46", FANOUT_FILES);
	const loopId = started(dir);
	assert.equal(ok(dir, "next", loopId).json.action, "start", "next did not start Step 1");
	drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId, "--follow"], { tty: true });
			await w.until((x) => x.count("0/3 steps") >= 1 || x.exited, 3000, "no first frame");
			await h.sleep(300);
			const mark = w.out.length;
			h.loop("finish", h.data.loopId, "1", "--result", "met", "--dry");
			const delay = await w.until((x) => x.out.slice(mark).includes("1/3 steps"), 2000, "no redraw within 2000 ms");
			h.assert.ok(w.out.slice(mark).includes("\u001b[H"), `the redraw after ${delay} ms is not in place`);
			const from = w.out.length;
			const began = Date.now();
			await h.sleep(3000);
			const frames = w.frames(from);
			h.assert.ok(frames >= 2 && frames <= 5, `${frames} frames in ${Date.now() - began} ms, not 2–5`);
			h.assert.equal(w.exited, null, w.why());
			const end = await w.kill("SIGINT");
			h.assert.equal(end.code, 0, `SIGINT exited ${end.code}`);
			return delay;
		},
		{ loopId },
	);
});

test("follow", "AC47-live-end", () => {
	const dir = followRepo("f-ac47");
	drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId, "--follow"], { tty: true });
			await w.until((x) => x.frames() >= 1, 3000, "no first frame");
			h.write(h.data.ended);
			const end = await w.exit(3000, "the watcher did not exit after the loop ended");
			h.assert.equal(end.code, 0, `the watcher exited ${end.code}, not 0 (${w.err.trim()})`);
			h.assert.equal(w.count("ended (code 4)"), 1, `the final view was drawn ${w.count("ended (code 4)")} times, not once`);
			const last = h.lastFrame(w);
			h.assert.ok(last.includes("FIRST-CAUSE") && last.includes("SECOND-CAUSE"), `the final view lacks a cause:\n${h.strip(last)}`);
			h.assert.ok(w.out.endsWith(`${h.SHOW}\n`) || w.out.endsWith(h.SHOW), "the cursor is not shown again at the end");
		},
		{ loopId: WATCH_ID, ended: followEnded() },
	);
});

test("follow", "AC48-sigint", () => {
	const dir = followRepo("f-ac48");
	drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId, "--follow"], { tty: true });
			await w.until((x) => x.frames() >= 1, 3000, "no first frame");
			h.assert.ok(w.out.includes(h.HIDE), "live mode did not hide the cursor");
			const end = await w.kill("SIGINT");
			h.assert.ok(end.delay < 1000, `SIGINT took ${end.delay} ms to exit`);
			h.assert.equal(end.signal, null, `the watcher was killed by ${end.signal}, not handled`);
			h.assert.equal(end.code, 0, `SIGINT exited ${end.code}, not 0`);
			h.assert.ok(w.out.endsWith(`${h.SHOW}\n`), `stdout does not end with ESC[?25h and a newline: ${JSON.stringify(w.out.slice(-20))}`);
		},
		{ loopId: WATCH_ID },
	);
});

test("follow", "R9-sigterm-restores", () => {
	const dir = followRepo("f-r9");
	drive(
		dir,
		async (h) => {
			for (const [signal, code] of [
				["SIGTERM", 143],
				["SIGHUP", 129],
			]) {
				const w = h.watcher([h.data.loopId, "--follow"], { tty: true });
				await w.until((x) => x.frames() >= 1, 3000, `${signal}: no first frame`);
				const end = await w.kill(signal);
				h.assert.ok(end.delay < 1000, `${signal} took ${end.delay} ms to exit`);
				h.assert.equal(end.code, code, `${signal} exited ${end.code}${end.signal ? ` (${end.signal})` : ""}, not ${code}`);
				h.assert.ok(w.out.endsWith(`${h.SHOW}\n`), `${signal}: stdout does not end with ESC[?25h and a newline`);
			}
		},
		{ loopId: WATCH_ID },
	);
});

test("follow", "AC50-plain-follow", () => {
	const dir = followRepo("f-ac50");
	drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId, "--follow"]);
			await w.until((x) => x.frames() >= 1, 1000, "watch --follow printed no snapshot at once");
			h.assert.equal(w.exited, null, `watch --follow exited, not following (${w.why()})`);
			await h.sleep(2500);
			h.assert.equal(w.frames(), 1, `${w.frames()} snapshots while the bytes were unchanged for 2 intervals, not 1`);
			h.write(h.data.changed);
			await w.until((x) => x.frames() >= 2, 2500, "no new snapshot after the bytes changed");
			h.assert.ok(h.lastFrame(w).includes("2/5 steps"), "the new snapshot does not draw the changed state");
			h.write(h.data.ended);
			const end = await w.exit(3000, "the watcher did not exit after the loop ended");
			h.assert.equal(end.code, 0, `the watcher exited ${end.code}, not 0`);
			h.assert.equal(w.frames(), 3, `${w.frames()} snapshots, not 3`);
			const last = h.lastFrame(w);
			h.assert.ok(last.includes("FIRST-CAUSE") && last.includes("SECOND-CAUSE"), "the final snapshot lacks a cause");
			h.assert.ok(!w.out.includes(h.ESC) && !w.out.includes(h.CSI), "plain follow output holds an escape sequence");
		},
		{ loopId: WATCH_ID, changed: loopState({ steps: five([1, 2]), running: [{ step: 3, mode: "main", started_at: at(5) }] }), ended: followEnded() },
	);
});

test("follow", "AC52-already-ended", () => {
	const dir = followRepo("f-ac52", followEnded());
	const run = watchRun(dir, [WATCH_ID, "--follow"]);
	assert.equal(run.stdout.split(`/fc:loop ${WATCH_ID}`).length - 1, 1, "plain: not one final view");
	assert.ok(run.stdout.includes("SECOND-CAUSE"), "plain: the final view lacks a cause");
	drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId, "--follow"], { tty: true });
			const end = await w.exit(5000, "live: the watcher did not exit on an ended loop");
			h.assert.equal(end.code, 0, `live: exited ${end.code}, not 0 (${w.err.trim()})`);
			h.assert.equal(w.frames(), 1, `live: ${w.frames()} views, not 1`);
			h.assert.ok(w.out.includes("FIRST-CAUSE") && w.out.includes("SECOND-CAUSE"), "live: the final view lacks a cause");
		},
		{ loopId: WATCH_ID },
	);
});

test("follow", "R-stale-first-read", () => {
	// Review finding: the change baseline must come from the same read as the view. The caller's
	// read (injected) is a running loop; the file on disk has since ended. The watcher must show
	// the ended view and exit 0, not keep the stale view and wait forever.
	const dir = followRepo("f-stale", followEnded());
	const stale = JSON.stringify(followState());
	const script = [
		'const path = require("node:path");',
		'const { watch } = require(path.join(process.cwd(), "ai-factory/make/loop.js"));',
		'let out = "", err = "";',
		"const stdout = { isTTY: false, columns: 100, write: (s) => ((out += s), true) };",
		"const stderr = { write: (s) => ((err += s), true) };",
		'const timer = setTimeout(() => { process.stdout.write(JSON.stringify({ timeout: true, out, err }) + "\\n"); process.exit(0); }, 4000);',
		`Promise.resolve(watch.cli([${JSON.stringify(WATCH_ID)}, "--follow"], { root: process.cwd(), stdout, stderr, env: {}, read: () => ${JSON.stringify(stale)} }))`,
		'	.then((code) => { clearTimeout(timer); process.stdout.write(JSON.stringify({ code, out, err }) + "\\n"); });',
	].join("\n");
	const run = spawnSync(process.execPath, ["-e", script], { cwd: dir, encoding: "utf8", env: ENV, timeout: 15000 });
	const result = JSON.parse(run.stdout.trim().split("\n").pop());
	assert.ok(!result.timeout, "the watcher kept a stale first view and did not exit when the state on disk had ended");
	assert.equal(result.code, 0, `exited ${result.code}, not 0 (${result.err.trim()})`);
	assert.ok(result.out.includes("SECOND-CAUSE"), "the ended view (with its causes) was never drawn");
});

test("follow", "AC17-torn-while-following", () => {
	const dir = followRepo("f-ac17");
	drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId, "--follow"]);
			await w.until((x) => x.frames() >= 1, 1000, "watch --follow printed no snapshot");
			h.fs.writeFileSync(h.file, '{"schema":');
			await h.sleep(1500);
			h.assert.equal(w.exited, null, `the watcher exited on a torn read (${w.why()})`);
			h.assert.equal(w.err, "", `stderr: ${w.err.trim()}`);
			h.assert.equal(w.frames(), 1, "a snapshot was printed from a read that did not parse");
			h.write(h.data.changed);
			await w.until((x) => x.frames() >= 2, 2500, "no snapshot from the next read that parsed");
			h.assert.ok(h.lastFrame(w).includes("2/5 steps"), "the next snapshot does not draw the valid state");
		},
		{ loopId: WATCH_ID, changed: loopState({ steps: five([1, 2]) }) },
	);
});

test("follow", "AC52a-gone", () => {
	const dir = followRepo("f-ac52a");
	drive(
		dir,
		async (h) => {
			for (const tty of [true, false]) {
				const how = tty ? "live" : "plain";
				h.write(h.data.running);
				const w = h.watcher([h.data.loopId, "--follow"], { tty });
				await w.until((x) => x.frames() >= 1, 3000, `${how}: no first frame`);
				h.fs.unlinkSync(h.file);
				const end = await w.exit(4000, `${how}: the watcher did not exit when the state was gone`);
				h.assert.equal(end.code, 1, `${how}: exited ${end.code}, not 1`);
				const lines = w.err.replace(/\n$/, "").split("\n");
				h.assert.equal(lines.length, 1, `${how}: stderr holds ${lines.length} lines, not 1`);
				h.assert.ok(lines[0].includes(`loop state for ${h.data.loopId} is gone`), `${how}: '${lines[0]}' does not say the state is gone`);
				if (tty) h.assert.ok(w.out.endsWith(`${h.SHOW}\n`), "live: the cursor is not shown again before the exit");
			}
		},
		{ loopId: WATCH_ID, running: followState() },
	);
});

test("follow", "AC52a-reappears", () => {
	const dir = followRepo("f-ac52a-back");
	// A preload records each read of state.json that found no file.
	const log = path.join(dir, "ai-factory/runs/tmp/misses.json");
	const preload = path.join(dir, "ai-factory/runs/tmp/count-misses.js");
	fs.mkdirSync(path.dirname(preload), { recursive: true });
	fs.writeFileSync(
		preload,
		[
			'const fs = require("node:fs");',
			"const misses = [];",
			'const note = (file, error) => { if (String(file).endsWith("state.json") && error && error.code === "ENOENT") misses.push(Date.now()); };',
			"const sync = fs.readFileSync;",
			"fs.readFileSync = function (file, ...rest) { try { return sync.call(this, file, ...rest); } catch (error) { note(file, error); throw error; } };",
			"const promised = fs.promises.readFile;",
			"fs.promises.readFile = async function (file, ...rest) { try { return await promised.call(this, file, ...rest); } catch (error) { note(file, error); throw error; } };",
			"const callback = fs.readFile;",
			"fs.readFile = function (file, ...rest) { const done = rest.pop(); return callback.call(this, file, ...rest, (error, data) => { note(file, error); done(error, data); }); };",
			`process.on("exit", () => fs.writeFileSync(${JSON.stringify(log)}, JSON.stringify(misses)));`,
			"",
		].join("\n"),
	);
	fs.writeFileSync(log, "[]");
	drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId, "--follow"], { tty: true, preload: h.data.preload });
			await w.until((x) => x.frames() >= 1, 3000, "no first frame");
			const bytes = h.fs.readFileSync(h.file);
			// Live mode redraws right after each poll, so a redraw marks the poll's time; the file is
			// away from 850 ms to 1250 ms after one, across the next poll.
			for (let round = 0; round < 3; round++) {
				const frames = w.frames();
				await w.until((x) => x.frames() > frames, 2500, `round ${round + 1}: no redraw`);
				await h.sleep(850);
				h.fs.unlinkSync(h.file);
				await h.sleep(400);
				h.fs.writeFileSync(h.file, bytes);
			}
			await h.sleep(1200);
			h.assert.equal(w.exited, null, `the watcher exited although the state came back (${w.why()})`);
			h.assert.equal(w.err, "", `stderr: ${w.err.trim()}`);
			const end = await w.kill("SIGINT");
			h.assert.equal(end.code, 0, `SIGINT exited ${end.code}`);
			const misses = JSON.parse(h.fs.readFileSync(h.data.log, "utf8"));
			h.assert.ok(misses.length >= 1, "no read found the state missing, so the case proved nothing");
		},
		{ loopId: WATCH_ID, preload, log },
	);
});

test("follow", "AC52b-stall", () => {
	const dir = followRepo("f-ac52b");
	drive(
		dir,
		async (h) => {
			const LINE = "no update for 31m — the loop may have stopped; Ctrl-C to quit";
			const back = (Date.now() - 31 * 60 * 1000 - 20 * 1000) / 1000;
			// Live: the line is on every draw, and gone from the first draw after a change.
			h.write(h.data.running);
			h.fs.utimesSync(h.file, back, back);
			const live = h.watcher([h.data.loopId, "--follow"], { tty: true });
			await live.until((x) => x.frames() >= 2, 3500, "live: two frames were not drawn");
			h.assert.ok(live.count(LINE) >= 2, `live: the stall line is on ${live.count(LINE)} of ${live.frames()} draws`);
			const mark = live.out.length;
			h.write(h.data.changed);
			await live.until((x) => x.frames(mark) >= 2, 3000, "live: no draw after the change");
			h.assert.ok(!h.lastFrame(live).includes("no update for"), "live: the stall line stayed after a change");
			h.assert.equal(live.exited, null, `live: the watcher exited on a stall (${live.why()})`);
			await live.kill("SIGINT");
			// Plain: printed once per stall, not again after a change.
			h.write(h.data.running);
			h.fs.utimesSync(h.file, back, back);
			const plain = h.watcher([h.data.loopId, "--follow"]);
			await plain.until((x) => x.count(LINE) >= 1, 2500, "plain: no stall line");
			await h.sleep(2500);
			h.assert.equal(plain.count(LINE), 1, `plain: the stall line was printed ${plain.count(LINE)} times, not once`);
			h.write(h.data.changed);
			await plain.until((x) => x.frames() >= 2, 2500, "plain: no snapshot after the change");
			await h.sleep(1500);
			h.assert.equal(plain.count("no update for"), 1, "plain: the stall line was printed again after a change");
			h.assert.equal(plain.exited, null, `plain: the watcher exited on a stall (${plain.why()})`);
		},
		{ loopId: WATCH_ID, running: followState(), changed: loopState({ steps: five([1, 2]) }) },
	);
});

// Layer 3 (optional): script(1) gives the watcher a real pseudo-terminal. Its arguments differ by
// platform; elsewhere, or without script, the case prints SKIP and the harness stays the proof.
test("follow", "tty-smoke", () => {
	const platform = process.platform === "darwin" ? "Darwin" : process.platform === "linux" ? "Linux" : process.platform;
	if (platform !== "Darwin" && platform !== "Linux") throw skip(`(${platform}): script(1) arguments are known only for Darwin and Linux`);
	const found = spawnSync("sh", ["-c", "command -v script"], { encoding: "utf8" });
	if (found.status !== 0) throw skip(`(${platform}): script(1) is not installed`);
	assert.match(WATCH_ID, /^loop-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$/);
	const dir = followRepo("f-smoke");
	const env = { ...ENV, TERM: "xterm" };
	delete env.NO_COLOR;
	delete env.COLUMNS;
	const args = platform === "Darwin" ? ["-q", "/dev/null", process.execPath, "ai-factory/make/loop.js", "watch", WATCH_ID] : ["-qec", `'${process.execPath}' ai-factory/make/loop.js watch ${WATCH_ID}`, "/dev/null"];
	const run = spawnSync("script", args, { cwd: dir, encoding: "utf8", env, timeout: 15000, stdio: ["ignore", "pipe", "pipe"] });
	if (run.error) throw new Error(`script(1) did not finish: ${run.error.message}`);
	if (run.status !== 0 && !run.stdout.includes("/fc:loop"))
		throw skip(`(${platform}): script(1) could not open a terminal here (exit ${run.status}: ${(run.stderr || run.stdout).trim().split("\n")[0]})`);
	assert.ok(run.stdout.includes("\u001b"), `(${platform}) the watcher under script(1) wrote no ESC sequence`);
	assert.match(run.stdout, /\d+\/5 steps/, `(${platform}) the watcher under script(1) drew no bar`);
});


// ==== readonly (plan ASD-007 Step 7; AC53–AC57, AC60–AC62, R12) ==============================
// The watcher writes nothing, holds no lock and leaves /fc:current's output unchanged.
// Files that must stay unchanged are compared with PRE_ASD007.
// Cases for this group go below this marker only.
// ---- marker: readonly ----

// Every entry under <root>/<rel>: a file by its SHA-256, a link by its target, a directory as
// such. Self-contained, so a driver scenario can rebuild it from its text (data.snapshot).
function snapshot(root, rel = "ai-factory") {
	const fs = require("node:fs");
	const path = require("node:path");
	const crypto = require("node:crypto");
	const out = {};
	const walk = (sub) => {
		const full = path.join(root, sub);
		const stat = fs.lstatSync(full);
		if (stat.isSymbolicLink()) out[sub] = `link:${fs.readlinkSync(full)}`;
		else if (stat.isDirectory()) {
			out[sub] = "dir";
			for (const name of fs.readdirSync(full).sort()) walk(path.join(sub, name));
		} else out[sub] = `file:${crypto.createHash("sha256").update(fs.readFileSync(full)).digest("hex")}`;
	};
	walk(rel);
	return out;
}
// What changed between two snapshots, one entry per path: +added, -removed, ~changed.
function changes(before, after) {
	const out = [];
	for (const key of Object.keys(after)) if (!(key in before)) out.push(`+${key}`);
	for (const key of Object.keys(before)) if (!(key in after)) out.push(`-${key}`);
	for (const key of Object.keys(before)) if (key in after && before[key] !== after[key]) out.push(`~${key}`);
	return out;
}
const unchanged = (before, after, what) => {
	const diff = changes(before, after);
	assert.deepEqual(diff, [], `${what}: ${diff.slice(0, 5).join(", ")}`);
};
const porcelain = (dir) => git(dir, "status", "--porcelain", "--untracked-files=all");
// A file the check owns outside every fixture: `find -newer` compares the fixture with its mtime.
function refFile(name) {
	fs.mkdirSync(SCRATCH, { recursive: true });
	const file = path.join(SCRATCH, `loop-watch-ref-${name}-${process.pid}-${Date.now()}`);
	fs.writeFileSync(file, "");
	fixtures.push(file);
	return file;
}
const newer = (dir, ref) => {
	const run = spawnSync("find", ["ai-factory", "-newer", ref], { cwd: dir, encoding: "utf8" });
	assert.equal(run.status, 0, `find -newer exited ${run.status}: ${run.stderr.trim()}`);
	return run.stdout.split("\n").filter(Boolean);
};
// The plugin's own git, comparing this tree with PRE_ASD007.
function plugin(...args) {
	return spawnSync("git", args, { cwd: PLUGIN, encoding: "utf8", env: ENV });
}
function samePre(paths, what) {
	const have = plugin("cat-file", "-e", `${PRE_ASD007}^{commit}`);
	assert.equal(have.status, 0, `PRE_ASD007 ${PRE_ASD007} is not in this repo's history: ${have.stderr.trim()}`);
	const run = plugin("diff", "--quiet", PRE_ASD007, "--", ...paths);
	if (run.status === 0) return;
	const names = plugin("diff", "--name-only", PRE_ASD007, "--", ...paths).stdout.trim().split("\n").filter(Boolean);
	throw new Error(`${what} differ from PRE_ASD007 (git diff exited ${run.status}): ${names.join(", ") || run.stderr.trim()}`);
}
const untracked = (...paths) => plugin("ls-files", "--others", "--exclude-standard", "--", ...paths).stdout.split("\n").filter(Boolean);
// A one-step plan that a scripted start → next → finish --dry → end runs to its end.
const ONE_FILES = { "ai-factory/plans/0001-one.md": plan("One", "- [ ] Step 1 — Only.") };

test("readonly", "AC53-lock-held", () => {
	const dir = followRepo("r-ac53");
	const lock = path.join(dir, LOOP_DIR, WATCH_ID, "state.lock");
	fs.writeFileSync(lock, `${JSON.stringify({ pid: process.pid, at: new Date().toISOString() })}\n`);
	const held = () => {
		const stat = fs.statSync(lock);
		return { bytes: fs.readFileSync(lock, "hex"), mtime: stat.mtimeMs, ino: stat.ino, dev: stat.dev };
	};
	const before = held();
	const began = Date.now();
	const run = watchRun(dir, [WATCH_ID]);
	const took = Date.now() - began;
	assert.ok(took < 1000, `the snapshot took ${took} ms with state.lock held, not under 1000`);
	assert.ok(run.stdout.includes(`/fc:loop ${WATCH_ID}`), "one-shot: no snapshot while state.lock is held");
	assert.deepEqual(held(), before, "one-shot: state.lock changed (bytes, mtime or inode)");
	const first = drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId, "--follow"]);
			const delay = await w.until((x) => x.frames() >= 1, 1000, "--follow: no snapshot within 1000 ms with state.lock held");
			h.write(h.data.ended);
			const end = await w.exit(4000, "--follow: the watcher did not exit after the loop ended");
			h.assert.equal(end.code, 0, `--follow: exited ${end.code}, not 0 (${w.err.trim()})`);
			return delay;
		},
		{ loopId: WATCH_ID, ended: followEnded() },
	);
	assert.ok(first < 1000, `--follow: the first snapshot took ${first} ms`);
	assert.deepEqual(held(), before, "--follow: state.lock changed (bytes, mtime or inode)");
});

test("readonly", "AC54-no-writes", () => {
	const dir = repo("r-ac54", ONE_FILES);
	const loopId = started(dir);
	assert.equal(ok(dir, "next", loopId).json.action, "start", "next did not start Step 1");
	assert.equal(porcelain(dir), "", "the fixture's tree is not clean before the watcher runs");
	// One-shot, plain and with --details.
	const before = snapshot(dir);
	const ref = refFile("ac54");
	for (const args of [[loopId], [loopId, "--details"]]) watchRun(dir, args);
	unchanged(before, snapshot(dir), "one-shot: files under ai-factory/ changed");
	assert.deepEqual(newer(dir, ref), [], "one-shot: find ai-factory -newer lists files");
	assert.equal(porcelain(dir), "", "one-shot: git status --porcelain is not empty");
	// Live one-shot, then --follow until a scripted end. The driver writes its own two files first;
	// the snapshots are taken after that, inside the driver.
	const ends = refFile("ac54-end");
	const seen = drive(
		dir,
		async (h) => {
			const snapshot = eval(`(${h.data.snapshot})`);
			const start = snapshot(h.ROOT);
			const live = h.watcher([h.data.loopId], { tty: true });
			const once = await live.exit(5000, "live one-shot: the watcher did not exit");
			h.assert.equal(once.code, 0, `live one-shot: exited ${once.code} (${live.err.trim()})`);
			const afterLive = snapshot(h.ROOT);
			const w = h.watcher([h.data.loopId, "--follow"]);
			await w.until((x) => x.frames() >= 1, 3000, "--follow: no snapshot");
			await h.sleep(2300);
			h.assert.equal(w.exited, null, `--follow: the watcher stopped following (${w.why()})`);
			const following = snapshot(h.ROOT);
			h.loop("finish", h.data.loopId, "1", "--result", "met", "--dry");
			h.loop("end", h.data.loopId);
			const ended = snapshot(h.ROOT);
			h.fs.writeFileSync(h.data.ref, "");
			const end = await w.exit(4000, "--follow: the watcher did not exit after the loop ended");
			h.assert.equal(end.code, 0, `--follow: exited ${end.code}, not 0 (${w.err.trim()})`);
			h.assert.ok(h.lastFrame(w).includes("ended (code 0)"), "--follow: the final snapshot does not show the end");
			return { start, afterLive, following, ended, after: snapshot(h.ROOT) };
		},
		{ loopId, snapshot: snapshot.toString(), ref: ends },
	);
	unchanged(seen.start, seen.afterLive, "live one-shot: files under ai-factory/ changed");
	unchanged(seen.start, seen.following, "--follow: files under ai-factory/ changed while following");
	assert.ok(changes(seen.following, seen.ended).length > 0, "the scripted end changed nothing, so the case proved nothing");
	unchanged(seen.ended, seen.after, "--follow: files under ai-factory/ changed after the loop's own last write");
	assert.deepEqual(newer(dir, ends), [], "--follow: find ai-factory -newer lists files written after the loop's last write");
	assert.equal(porcelain(dir), "", "--follow: git status --porcelain is not empty");
});

test("readonly", "AC55-follow-three-intervals", () => {
	const dir = repo("r-ac55", FANOUT_FILES);
	const loopId = started(dir);
	const file = path.join(dir, LOOP_DIR, loopId, "state.json");
	const pick = (state) => ({
		running: state.running,
		pending: state.pending,
		finished: state.finished,
		causes: state.causes,
		ended: state.ended,
		done: state.steps.map((step) => [step.number, step.done]),
	});
	const before = pick(readLoopState(dir, loopId));
	assert.ok(before.done.some(([, done]) => !done) && before.running.length === 0, "the fixture loop has no ready step");
	const bytes = fs.readFileSync(file, "hex");
	const loopDir = snapshot(dir, path.join(LOOP_DIR, loopId));
	const seen = drive(
		dir,
		async (h) => {
			const w = h.watcher([h.data.loopId, "--follow"], { tty: true });
			const began = Date.now();
			await w.until((x) => x.frames() >= 4, 5000, "fewer than 3 redraws after the first frame");
			const took = Date.now() - began;
			h.assert.equal(w.exited, null, w.why());
			h.assert.ok(h.strip(h.lastFrame(w)).includes("ready"), "the followed loop shows no ready step");
			const end = await w.kill("SIGINT");
			h.assert.equal(end.code, 0, `SIGINT exited ${end.code}`);
			return { frames: w.frames(), took };
		},
		{ loopId },
	);
	assert.ok(seen.took >= 2500, `${seen.frames} frames in ${seen.took} ms: fewer than 3 intervals passed`);
	assert.deepEqual(pick(readLoopState(dir, loopId)), before, "running, pending, finished, causes, ended or a step's done changed");
	assert.equal(fs.readFileSync(file, "hex"), bytes, "state.json changed while the watcher followed");
	unchanged(loopDir, snapshot(dir, path.join(LOOP_DIR, loopId)), "the loop directory changed (a lock, a worktree or an outcome)");
	assert.ok(!fs.existsSync(path.join(dir, "ai-factory/runs/tmp/worktrees")), "a worktree directory was created");
});

test("readonly", "AC56-current-unchanged", () => {
	const CURRENT = path.join(PLUGIN, "skills/ai-layout/scripts/current.js");
	const CHECK = path.join(PLUGIN, "skills/ai-layout/scripts/check-current.sh");
	for (const file of [CURRENT, CHECK]) if (!fs.existsSync(file)) throw new Error(`${path.relative(PLUGIN, file)} does not exist (ASD-006)`);
	fs.mkdirSync(SCRATCH, { recursive: true });
	const dir = fs.mkdtempSync(path.join(SCRATCH, "loop-watch-r-ac56-"));
	fixtures.push(dir);
	const built = spawnSync("bash", [CHECK, "fixture", dir], { cwd: PLUGIN, encoding: "utf8", env: ENV });
	assert.equal(built.status, 0, `check-current.sh fixture exited ${built.status}: ${built.stderr.trim()}`);
	assert.equal(porcelain(dir), "", "ASD-006's AC9 repo is not clean as built");
	// The watcher runs from the fixture's own make/, as in an adopted repo, on a running loop of a
	// plan the listing shows.
	fs.mkdirSync(path.join(dir, "ai-factory/make"), { recursive: true });
	for (const file of ["loop.js", "contracts.js", "gate.js", "safe-files.js", "assurance.js"])
		fs.copyFileSync(path.join(MAKE, file), path.join(dir, "ai-factory/make", file));
	const steps = [1, 2, 3, 4].map((n) => st(n, { done: n <= 2 }));
	const state = loopState({ steps, running: [{ step: 3, mode: "main", started_at: at(0) }], plan: "ai-factory/plans/ASD-910-alpha.md" });
	fs.mkdirSync(path.join(dir, LOOP_DIR, WATCH_ID), { recursive: true });
	writeLoopState(dir, WATCH_ID, state);
	const seen = drive(
		dir,
		async (h) => {
			const { spawnSync } = require("node:child_process");
			const current = () => {
				const run = spawnSync(process.execPath, [h.data.current, h.ROOT], { cwd: h.data.plugin, encoding: "utf8" });
				return { status: run.status, stdout: run.stdout, stderr: run.stderr };
			};
			const before = current();
			const w = h.watcher([h.data.loopId, "--follow"]);
			await w.until((x) => x.frames() >= 1, 3000, "the watcher printed no snapshot");
			const during = [];
			for (let round = 0; round < 3; round++) {
				during.push(current());
				await h.sleep(700);
			}
			h.assert.equal(w.exited, null, `the watcher stopped following (${w.why()})`);
			return { before, during };
		},
		{ loopId: WATCH_ID, current: CURRENT, plugin: PLUGIN },
	);
	assert.equal(seen.before.status, 0, `current.js exited ${seen.before.status} before the watcher: ${seen.before.stderr.trim()}`);
	assert.ok(seen.before.stdout.includes("ai-factory/plans/ASD-910-alpha.md"), `current.js does not list ASD-910 in the AC9 repo:\n${seen.before.stdout}`);
	for (const [index, run] of seen.during.entries())
		assert.deepEqual(run, seen.before, `current.js answered differently while the watcher followed (read ${index + 1}):\n${run.stdout}${run.stderr}`);
	const check = spawnSync("bash", [CHECK], { cwd: PLUGIN, encoding: "utf8", env: ENV, timeout: 120000 });
	assert.equal(check.status, 0, `check-current.sh exited ${check.status}: ${(check.stderr || check.stdout).trim().split("\n")[0]}`);
});

test("readonly", "AC57-runner-unchanged", () => {
	samePre([`${MAKE_REL}/runner.js`], "runner.js");
});

test("readonly", "AC60-one-file", () => {
	assert.equal(plugin("cat-file", "-e", `${PRE_ASD007}^{commit}`).status, 0, `PRE_ASD007 ${PRE_ASD007} is not in this repo's history`);
	const added = plugin("diff", "--name-only", "--diff-filter=A", PRE_ASD007, "--", MAKE_REL).stdout.trim();
	assert.equal(added, "", `files added under ${MAKE_REL}/: ${added.replace(/\n/g, ", ")}`);
	const fresh = untracked(MAKE_REL);
	assert.deepEqual(fresh, [], `untracked files under ${MAKE_REL}/: ${fresh.join(", ")}`);
	// This repo's ai-factory/make/ holds one symbolic link per template file: each is still a link
	// and none was replaced or edited through it.
	samePre(["ai-factory/make"], "entries of ai-factory/make/");
	const links = fs.readdirSync(path.join(PLUGIN, "ai-factory/make"));
	for (const name of links)
		assert.ok(fs.lstatSync(path.join(PLUGIN, "ai-factory/make", name)).isSymbolicLink(), `ai-factory/make/${name} is not a symbolic link`);
	assert.equal(fs.realpathSync(path.join(PLUGIN, "ai-factory/make/loop.js")), fs.realpathSync(LOOP), "ai-factory/make/loop.js does not resolve to the template's loop.js");
	assert.ok(fs.readFileSync(LOOP, "utf8").includes("// --- watch ---"), "loop.js has no `// --- watch ---` section");
	const api = require(LOOP).watch;
	assert.ok(api && typeof api.cli === "function" && typeof api.frame === "function", "loop.js exports no watch.cli() and watch.frame()");
});

test("readonly", "AC61-builtins-only", () => {
	const source = fs.readFileSync(LOOP, "utf8");
	const calls = [...source.matchAll(/\brequire\s*\(([^)]*)\)/g)];
	assert.ok(calls.length > 0, "loop.js has no require call");
	for (const [call, arg] of calls) {
		const literal = arg.trim().match(/^(["'])([^"'`]+)\1$/);
		assert.ok(literal, `loop.js: ${call} does not name a module by a string literal`);
		const name = literal[2];
		if (name.startsWith("node:")) {
			assert.ok(require("node:module").isBuiltin(name), `loop.js requires ${name}, which is not a Node built-in`);
			continue;
		}
		assert.match(name, /^\.\/[A-Za-z0-9_.-]+\.js$/, `loop.js requires '${name}', neither node:* nor ./<file>.js`);
		assert.ok(fs.existsSync(path.join(MAKE, name)), `loop.js requires '${name}', which is not a file under ${MAKE_REL}/`);
	}
	const packages = plugin("diff", "--name-only", "--diff-filter=AM", PRE_ASD007, "--", ":(glob)**/package.json").stdout.trim();
	assert.equal(packages, "", `the diff adds or changes a package.json: ${packages.replace(/\n/g, ", ")}`);
	const fresh = untracked(":(glob)**/package.json");
	assert.deepEqual(fresh, [], `untracked package.json: ${fresh.join(", ")}`);
});

test("readonly", "AC62-untouched", () => {
	const paths = [
		"hooks/hooks.json",
		"skills/ai-hooks",
		`${MAKE_REL}/lifecycle-events.js`,
		`${MAKE_REL}/delivery-status.js`,
		"skills/ai-layout/scripts/state.sh",
		"commands/state.md",
		"commands/current.md",
		"skills/ai-layout/scripts/current.js",
	];
	for (const rel of paths) assert.ok(fs.existsSync(path.join(PLUGIN, rel)), `${rel} does not exist`);
	samePre(paths, "AC62's files");
	const fresh = untracked(...paths);
	assert.deepEqual(fresh, [], `untracked files under AC62's paths: ${fresh.join(", ")}`);
});

test("readonly", "R12-writer-unchanged", () => {
	const writer = (source, where) => {
		const from = source.indexOf("\nfunction writeState(");
		assert.ok(from >= 0, `${where} has no writeState function`);
		const to = source.indexOf("\n}\n", from);
		assert.ok(to > from, `${where}: writeState has no closing brace at column 0`);
		return source.slice(from, to + 3);
	};
	const now = writer(fs.readFileSync(LOOP, "utf8"), "loop.js");
	const before = writer(atPre(`${MAKE_REL}/loop.js`), "PRE_ASD007's loop.js");
	assert.equal(now, before, "writeState differs from PRE_ASD007's");
	samePre([`${MAKE_REL}/safe-files.js`], "safe-files.js");
});


// ==== make (plan ASD-007 Step 8; AC2–AC4, AC59) ==============================================
// make loop-watch with LOOP, FOLLOW and DETAILS captured as data.
// Make runs with MAKEFLAGS and MAKEOVERRIDES cleared.
// Cases for this group go below this marker only.
// ---- marker: make ----

const AI_MK = path.join(MAKE, "ai.mk");
// The environment make and node run with: MAKEFLAGS and MAKEOVERRIDES cleared, and none of the
// target's own variables inherited, so only what a case passes reaches the target.
function makeEnv() {
	const env = { ...ENV, MAKEFLAGS: "", MAKEOVERRIDES: "" };
	for (const name of ["COLUMNS", "NO_COLOR", "LOOP", "FOLLOW", "DETAILS", "MFLAGS", "MAKELEVEL"]) delete env[name];
	return env;
}
// A watch fixture that also holds a copy of the template ai.mk.
const makeRepo = (name, state, files = {}) =>
	watchRepo(name, state, { "ai-factory/plans/0001-x.md": PLAN_FIVE, "ai-factory/make/ai.mk": fs.readFileSync(AI_MK, "utf8"), ...files });
// `make -s -f ai-factory/make/ai.mk loop-watch <vars…>` in the fixture, stdout piped.
function makeWatch(dir, vars) {
	const run = spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", "loop-watch", ...vars], {
		cwd: dir,
		encoding: "utf8",
		env: makeEnv(),
		timeout: 15000,
	});
	assert.ok(!run.error, `make loop-watch did not exit by itself: ${run.error && run.error.message}`);
	return run;
}
// The same, which must exit 0: a missing target is reported with make's own message.
function makeOk(dir, vars) {
	const run = makeWatch(dir, vars);
	if (run.status !== 0) throw new Error(run.stderr.trim().split("\n")[0] || `make loop-watch ${vars.join(" ")} exited ${run.status}`);
	return run;
}
// `node ai-factory/make/loop.js watch <args…>` with the same environment.
function nodeWatch(dir, args) {
	const run = spawnSync(process.execPath, ["ai-factory/make/loop.js", "watch", ...args], { cwd: dir, encoding: "utf8", env: makeEnv(), timeout: 15000 });
	assert.ok(!run.error, `watch did not exit by itself: ${run.error && run.error.message}`);
	return run;
}
// Both runs read the clock separately, so their times are compared as placeholders.
const sameOutput = (got, want, how) =>
	assert.deepEqual(untimed(got.split("\n")), untimed(want.split("\n")), `${how}: make's output differs from node's:\n--- make\n${got}\n--- node\n${want}`);
const frameCount = (text) => text.split(`/fc:loop ${WATCH_ID}`).length - 1;

test("make", "AC2-same-as-node", () => {
	const dir = makeRepo("m-ac2", followState());
	const named = makeOk(dir, [`LOOP=${WATCH_ID}`]);
	const direct = nodeWatch(dir, [WATCH_ID]);
	assert.equal(direct.status, 0, `node … watch ${WATCH_ID} exited ${direct.status}: ${direct.stderr.trim()}`);
	assert.equal(frameCount(named.stdout), 1, `LOOP=${WATCH_ID}: ${frameCount(named.stdout)} snapshots, not 1`);
	sameOutput(named.stdout, direct.stdout, `LOOP=${WATCH_ID}`);
	assert.equal(named.stderr, direct.stderr, `LOOP=${WATCH_ID}: stderr differs`);
	const bare = makeOk(dir, []);
	const bareDirect = nodeWatch(dir, []);
	assert.equal(bareDirect.status, 0, `node … watch exited ${bareDirect.status}: ${bareDirect.stderr.trim()}`);
	sameOutput(bare.stdout, bareDirect.stdout, "no LOOP");
	// With no loop at all, both refuse alike: the target passed node no argument after watch.
	const empty = repo("m-ac2-empty", { "ai-factory/make/ai.mk": fs.readFileSync(AI_MK, "utf8") });
	const none = makeWatch(empty, []);
	const noneDirect = nodeWatch(empty, []);
	assert.equal(none.status === 0, noneDirect.status === 0, `no loop: make exited ${none.status}, node exited ${noneDirect.status}`);
	assert.ok(none.stderr.startsWith(noneDirect.stderr), `no loop: make's stderr does not start with node's:\n${none.stderr}\n---\n${noneDirect.stderr}`);
	assert.equal(none.stdout, noneDirect.stdout, "no loop: stdout differs");
	// An empty LOOP is the same as none.
	sameOutput(makeOk(dir, ["LOOP="]).stdout, bareDirect.stdout, "LOOP=");
});

test("make", "AC3-follow", () => {
	const dir = makeRepo("m-ac3", followState());
	const once = makeOk(dir, [`LOOP=${WATCH_ID}`]);
	assert.equal(frameCount(once.stdout), 1, `without FOLLOW: ${frameCount(once.stdout)} snapshots, not 1`);
	for (const value of ["0", "yes", ""]) {
		const other = makeOk(dir, [`LOOP=${WATCH_ID}`, `FOLLOW=${value}`]);
		assert.equal(frameCount(other.stdout), 1, `FOLLOW=${value}: ${frameCount(other.stdout)} snapshots, not 1`);
	}
	// The same scripted state changes, once under make with FOLLOW=1 and once under node --follow.
	const outputs = drive(
		dir,
		async (h) => {
			const { spawn } = require("node:child_process");
			const env = { ...process.env, MAKEFLAGS: "", MAKEOVERRIDES: "" };
			for (const name of ["COLUMNS", "NO_COLOR", "LOOP", "FOLLOW", "DETAILS", "MFLAGS", "MAKELEVEL"]) delete env[name];
			const frames = (text) => text.split(h.HEADER).length - 1;
			async function follow(how, command, args) {
				h.write(h.data.initial);
				const child = spawn(command, args, { cwd: h.ROOT, env, stdio: ["ignore", "pipe", "pipe"] });
				let out = "";
				let err = "";
				child.stdout.setEncoding("utf8");
				child.stderr.setEncoding("utf8");
				child.stdout.on("data", (chunk) => (out += chunk));
				child.stderr.on("data", (chunk) => (err += chunk));
				let exited = null;
				const done = new Promise((resolve) => child.on("close", (code) => resolve((exited = code))));
				const until = async (pred, ms, what) => {
					const start = Date.now();
					while (!pred()) {
						if (exited !== null || Date.now() - start > ms) {
							child.kill("SIGKILL");
							throw new Error(`${how}: ${what} (${exited !== null ? `exited ${exited}: ${err.trim().split("\n")[0]}` : `waited ${Date.now() - start} ms`})`);
						}
						await h.sleep(20);
					}
				};
				await until(() => frames(out) >= 1, 3000, "printed no snapshot");
				await h.sleep(300);
				h.assert.equal(exited, null, `${how}: exited after one snapshot, not following`);
				h.write(h.data.changed);
				await until(() => frames(out) >= 2, 3000, "no new snapshot after the bytes changed");
				h.write(h.data.ended);
				const end = await Promise.race([done, h.sleep(4000).then(() => "timeout")]);
				if (end === "timeout") {
					child.kill("SIGKILL");
					throw new Error(`${how}: did not exit after the loop ended`);
				}
				h.assert.equal(end, 0, `${how}: exited ${end}, not 0 (${err.trim()})`);
				return out;
			}
			const viaMake = await follow("make FOLLOW=1", "make", ["-s", "-f", "ai-factory/make/ai.mk", "loop-watch", `LOOP=${h.data.loopId}`, "FOLLOW=1"]);
			const viaNode = await follow("node --follow", process.execPath, ["ai-factory/make/loop.js", "watch", h.data.loopId, "--follow"]);
			return { viaMake, viaNode };
		},
		{
			loopId: WATCH_ID,
			initial: followState(),
			changed: loopState({ steps: five([1, 2]), running: [{ step: 3, mode: "main", started_at: at(5) }] }),
			ended: followEnded(),
		},
	);
	assert.equal(frameCount(outputs.viaMake), 3, `make FOLLOW=1: ${frameCount(outputs.viaMake)} snapshots, not 3`);
	sameOutput(outputs.viaMake, outputs.viaNode, "FOLLOW=1");
});

test("make", "AC4-details", () => {
	const dir = makeRepo("m-ac4", detailsState());
	const shown = makeOk(dir, [`LOOP=${WATCH_ID}`, "DETAILS=1"]);
	const direct = nodeWatch(dir, [WATCH_ID, "--details"]);
	assert.equal(direct.status, 0, `node … watch --details exited ${direct.status}: ${direct.stderr.trim()}`);
	assert.ok(shown.stdout.includes("SECRET-MARKER") && shown.stdout.includes(WORKTREE_S2), "DETAILS=1 shows no details");
	sameOutput(shown.stdout, direct.stdout, "DETAILS=1");
	for (const vars of [[], ["DETAILS="], ["DETAILS=0"], ["DETAILS=yes"]]) {
		const hidden = makeOk(dir, [`LOOP=${WATCH_ID}`, ...vars]);
		const how = vars.length ? vars[0] : "without DETAILS";
		for (const needle of ["SECRET-MARKER", WORKTREE_S2]) assert.ok(!hidden.stdout.includes(needle), `${how}: the output shows ${needle}`);
		sameOutput(hidden.stdout, nodeWatch(dir, [WATCH_ID]).stdout, how);
	}
});

test("make", "AC59-static", () => {
	if (!fs.existsSync(AI_MK)) throw new Error("make/ai.mk does not exist");
	const text = fs.readFileSync(AI_MK, "utf8");
	const lines = text.split("\n");
	assert.ok(lines.some((line) => /^\.PHONY:.*(?:^|\s)loop-watch(?:\s|$)/.test(line)), "ai.mk has no loop-watch in .PHONY");
	for (const name of ["LOOP", "FOLLOW", "DETAILS"]) {
		assert.ok(lines.includes(`override ${name} := $(value ${name})`), `ai.mk has no 'override ${name} := $(value ${name})'`);
		assert.ok(lines.some((line) => new RegExp(`^export\\s(?:.*\\s)?${name}(?:\\s|$)`).test(line)), `ai.mk does not export ${name}`);
		const other = lines.filter((line) => line !== `override ${name} := $(value ${name})` && new RegExp(`^\\s*(?:override\\s+)?${name}\\s*[:?+!]?=`).test(line));
		assert.equal(other.length, 0, `ai.mk also assigns ${name}: ${other[0]}`);
	}
	const start = lines.findIndex((line) => /^loop-watch\s*:/.test(line));
	assert.ok(start >= 0, "ai.mk has no loop-watch: rule");
	assert.equal(lines[start].replace(/^loop-watch\s*:/, "").trim(), "", `loop-watch has prerequisites or an inline recipe: ${lines[start]}`);
	const recipe = [];
	for (let i = start + 1; i < lines.length && lines[i].startsWith("\t"); i++) recipe.push(lines[i]);
	assert.equal(recipe.length, 1, `the loop-watch recipe has ${recipe.length} lines, not 1`);
	const body = recipe[0];
	assert.ok(body.startsWith("\t@"), "the loop-watch recipe is not silent");
	assert.ok(body.includes("node ai-factory/make/loop.js watch"), "the loop-watch recipe does not run node ai-factory/make/loop.js watch");
	for (const name of ["LOOP", "FOLLOW", "DETAILS"]) {
		for (const form of [`$(${name})`, `\${${name}}`, `$(value ${name})`])
			assert.ok(!body.includes(form), `the loop-watch recipe expands ${form}`);
		assert.ok(body.includes(`$$${name}`), `the loop-watch recipe does not read ${name} from the environment`);
	}
	// Make expands nothing else in it either: every $ is a $$ escape.
	assert.ok(!/(?<!\$)\$(?!\$)/.test(body.replace(/\$\$/g, "")), "the loop-watch recipe holds a make expansion");
});

test("make", "AC59-injection", () => {
	const dir = makeRepo("m-ac59", followState());
	const pwned = [path.join(dir, "pwned"), path.join(PLUGIN, "pwned")];
	for (const file of pwned) assert.ok(!fs.existsSync(file), `${file} exists before the run; remove it and run again`);
	for (const value of ["$(shell touch pwned)", "x; touch pwned", "$$(touch pwned)", "`touch pwned`", "x\" ; touch pwned ; \""]) {
		const run = makeWatch(dir, [`LOOP=${value}`]);
		for (const file of pwned) assert.ok(!fs.existsSync(file), `LOOP=${value}: ${file} was created`);
		assert.notEqual(run.status, 0, `LOOP=${value}: make exited 0`);
		// $(value …) keeps the command-line text as written, $$ included: the watcher sees it literally.
		const literal = value;
		const refusal = `'${literal}' is refused: it is not a loop ID`;
		assert.ok(run.stderr.includes(refusal), `LOOP=${value}: stderr does not hold "${refusal}": ${run.stderr.trim().split("\n")[0]}`);
		assert.equal(run.stdout, "", `LOOP=${value}: a snapshot was printed`);
		const direct = nodeWatch(dir, [literal]);
		assert.equal(direct.status, 2, `node … watch '${literal}' exited ${direct.status}, not 2`);
		assert.ok(direct.stderr.includes(refusal), `node … watch '${literal}': stderr does not hold "${refusal}"`);
		for (const file of pwned) assert.ok(!fs.existsSync(file), `node … watch '${literal}': ${file} was created`);
	}
});


// ==== surface (plan ASD-007 Step 9; AC5, AC7–AC9, AC58) ======================================
// /fc:watch, $fc-watch and the one added tasks/loop.md line.
// AC6–AC8 as they behave in a session are proved by transcripts, not here.
// Cases for this group go below this marker only.
// ---- marker: surface ----
const WATCH_CMD = "commands/watch.md";
const WATCH_SKILL = "codex-skills/fc-watch/SKILL.md";
const LOOP_TASK = "skills/ai-layout/templates/ai-factory/tasks/loop.md";
// commands/watch.md split into its frontmatter and its body, failing when the file is missing.
function watchCommand() {
	const file = path.join(PLUGIN, WATCH_CMD);
	if (!fs.existsSync(file)) throw new Error(`${WATCH_CMD} does not exist`);
	const text = fs.readFileSync(file, "utf8");
	const front = /^---\n([\s\S]*?)\n---\n/.exec(text);
	if (!front) throw new Error(`${WATCH_CMD} has no frontmatter`);
	return { front: front[1], body: text.slice(front[0].length), flat: text.slice(front[0].length).replace(/\s+/g, " ") };
}

test("surface", "AC5-command-text", () => {
	const { front, body, flat } = watchCommand();
	assert.match(front, /^description: \S/m, `${WATCH_CMD} has no description`);
	assert.match(front, /^argument-hint: .*<loop id>.*--details.*--width/m, `${WATCH_CMD}'s argument-hint lacks <loop id>, --details or --width`);
	// Only node may run: never bare Bash, never Read or any other tool.
	assert.match(front, /^allowed-tools: Bash\(node:\*\)$/m, `${WATCH_CMD} does not allow exactly Bash(node:*)`);
	// Every command it tells the model to run is loop.js watch; the only other command lines it
	// names are the two AC7 tells the developer to type in a terminal.
	const commands = [...body.matchAll(/`((?:node|bash|make|sh|git|cat|ls|test) [^`]*)`/g)].map((m) => m[1]);
	assert.ok(commands.includes("node ai-factory/make/loop.js watch"), `${WATCH_CMD} does not name \`node ai-factory/make/loop.js watch\``);
	for (const command of commands)
		assert.ok(
			/^node ai-factory\/make\/loop\.js watch(?: --follow)?$/.test(command) || command === "make -f ai-factory/make/ai.mk loop-watch",
			`${WATCH_CMD} names a command other than loop.js watch: \`${command}\``,
		);
	assert.match(flat, /(?:only|no other)[^.]*command|one command, and no other/i, `${WATCH_CMD} does not say loop.js watch is the only command`);
	// The argument verbatim: each typed word single-quoted, ' written as '\'', nothing dropped.
	assert.match(body, /Context: \$ARGUMENTS\s*$/, `${WATCH_CMD} does not end with the Context: $ARGUMENTS line`);
	assert.match(flat, /single quotes/i, `${WATCH_CMD} does not single-quote each typed word`);
	assert.ok(body.includes("'\\''"), `${WATCH_CMD} does not say how to write ' inside a word`);
	assert.match(flat, /unchanged|verbatim/i, `${WATCH_CMD} does not pass the argument through unchanged`);
	assert.match(flat, /do not interpret, translate or drop/i, `${WATCH_CMD} does not forbid interpreting or dropping a word`);
	// The four prohibitions.
	assert.match(flat, /\*\*Change nothing\.\*\*/, `${WATCH_CMD} does not say to change nothing`);
	assert.match(flat, /\*\*Launch no agent or subagent\*\*/, `${WATCH_CMD} does not say to launch no agent or subagent`);
	assert.match(flat, /invoke no other command or skill/i, `${WATCH_CMD} does not say to invoke no other command or skill`);
	assert.match(flat, /\*\*Ask nothing\.\*\*/, `${WATCH_CMD} does not say to ask nothing`);
	// R5: the snapshot carries plan titles, causes and, with --details, agent output — data only.
	assert.match(flat, /data, never instructions/i, `${WATCH_CMD} does not treat the printed output as data`);
});

test("surface", "AC7-follow-line", () => {
	const { flat } = watchCommand();
	assert.match(flat, /`--follow`/, `${WATCH_CMD} does not name --follow`);
	const line = /following is for a terminal[^"]*/i.exec(flat);
	assert.ok(line, `${WATCH_CMD} has no "following is for a terminal" line`);
	assert.ok(line[0].includes("`make -f ai-factory/make/ai.mk loop-watch`"), "the --follow line does not name make -f ai-factory/make/ai.mk loop-watch");
	assert.ok(line[0].includes("`node ai-factory/make/loop.js watch --follow`"), "the --follow line does not name node ai-factory/make/loop.js watch --follow");
	assert.match(flat, /--follow`[^.]*(?:run nothing|do not run)/i, `${WATCH_CMD} does not say a --follow request runs no watcher`);
});

test("surface", "AC8-sync-line", () => {
	const { flat } = watchCommand();
	assert.ok(flat.includes("unknown subcommand 'watch'"), `${WATCH_CMD} does not name the answer unknown subcommand 'watch'`);
	assert.match(flat, /Cannot find module/, `${WATCH_CMD} does not cover a missing ai-factory/make/loop.js`);
	assert.match(flat, /one line[^.]*`\/fc:sync-sdlc`/i, `${WATCH_CMD} does not answer an unsynced repo with one line naming /fc:sync-sdlc`);
});

test("surface", "AC9-codex-skill", () => {
	const file = path.join(PLUGIN, WATCH_SKILL);
	assert.ok(fs.existsSync(file), `${WATCH_SKILL} does not exist`);
	assert.ok(fs.readFileSync(file, "utf8").includes("](../../commands/watch.md)"), `${WATCH_SKILL} does not point at commands/watch.md`);
	const run = spawnSync(process.execPath, ["skills/ai-layout/scripts/sync-codex-skills.js", "--check"], { cwd: PLUGIN, encoding: "utf8", env: ENV });
	assert.equal(run.status, 0, `sync-codex-skills.js --check exited ${run.status}: ${(run.stderr || run.stdout).trim().split("\n")[0]}`);
});

test("surface", "AC58-one-line", () => {
	const diff = execFileSync("git", ["diff", "--no-color", "-U0", PRE_ASD007, "--", LOOP_TASK], { cwd: PLUGIN, stdio: "pipe", env: ENV }).toString();
	const lines = diff.split("\n").filter((l) => !/^(?:\+\+\+|---) /.test(l));
	const added = lines.filter((l) => l.startsWith("+"));
	const removed = lines.filter((l) => l.startsWith("-"));
	assert.equal(added.length, 1, `tasks/loop.md has ${added.length} added lines, not 1`);
	assert.equal(removed.length, 0, `tasks/loop.md has ${removed.length} removed or changed lines, not 0`);
	assert.ok(added[0].includes("make -f ai-factory/make/ai.mk loop-watch"), "the added tasks/loop.md line does not name make -f ai-factory/make/ai.mk loop-watch");
	assert.match(added[0], /LOOP=<loop id>/, "the added tasks/loop.md line does not name the loop ID");
	assert.match(added[0], /second terminal/, "the added tasks/loop.md line does not say a second terminal");
});


// ==== docs (plan ASD-007 Step 10; AC63–AC66, R5) =============================================
// The notes page, its group, the loop notes, headless CI and workflow.md.
// Command counts are checked by check-risk.sh, never against a literal.
// Cases for this group go below this marker only.
// ---- marker: docs ----
const WATCH_NOTES = "docs/commands/_notes/watch.md";
const GROUPS = "docs/commands/_notes/_groups.md";
const LOOP_NOTES = "docs/commands/_notes/loop.md";
const HEADLESS = "docs/headless-ci.md";
const WORKFLOW_DOC = "ai-factory/docs/workflow.md";
const readDoc = (rel) => {
	const file = path.join(PLUGIN, rel);
	if (!fs.existsSync(file)) throw new Error(`${rel} does not exist`);
	return fs.readFileSync(file, "utf8");
};
const flatDoc = (rel) => readDoc(rel).replace(/\s+/g, " ");
// The body of each `## ` section of a markdown page, keyed by its heading.
function sections(text) {
	const out = {};
	let name = null;
	for (const line of text.split("\n")) {
		const heading = /^## (.+?)\s*$/.exec(line);
		if (heading) out[(name = heading[1])] = "";
		else if (name !== null) out[name] += `${line}\n`;
	}
	return out;
}

test("docs", "AC63-notes-sections", () => {
	const found = sections(readDoc(WATCH_NOTES));
	for (const heading of ["Usage", "Examples", "Writes", "Refuses or asks"]) {
		assert.ok(heading in found, `${WATCH_NOTES} has no ## ${heading} section`);
		assert.ok(found[heading].trim() !== "", `${WATCH_NOTES}'s ## ${heading} section is empty`);
	}
	const flat = flatDoc(WATCH_NOTES);
	// AC51a, R10 and AC52b, as the step names them.
	assert.match(flat, /--width/, `${WATCH_NOTES} does not cover --width`);
	assert.match(flat, /`COLUMNS`/, `${WATCH_NOTES} does not cover COLUMNS`);
	assert.match(flat, /live mode/i, `${WATCH_NOTES} does not name live mode`);
	assert.match(flat, /plain mode/i, `${WATCH_NOTES} does not name plain mode`);
	assert.match(flat, /no update for/, `${WATCH_NOTES} does not describe the stall line`);
	assert.match(flat, /In CI[^.]*make -f ai-factory\/make\/ai\.mk loop-watch LOOP=<loop id>`?,? without `FOLLOW`/, `${WATCH_NOTES} does not tell CI to snapshot without FOLLOW`);
});

test("docs", "AC63-grouped", () => {
	const rows = readDoc(GROUPS).split("\n").filter((line) => line.startsWith("| [Build and verify]"));
	assert.equal(rows.length, 1, `${GROUPS} has ${rows.length} "Build and verify" rows, not one`);
	const names = [...rows[0].matchAll(/`([^`]+)`/g)].map((m) => m[1]);
	const at = names.indexOf("watch");
	assert.ok(at >= 0, `${GROUPS} does not list watch in Build and verify`);
	assert.equal(names[at - 1], "loop", `${GROUPS} does not list watch next to loop (after ${names[at - 1]})`);
	assert.ok(fs.existsSync(path.join(PLUGIN, "docs/commands/watch.md")), "docs/commands/watch.md was not generated");
});

test("docs", "AC64-loop-notes", () => {
	const lines = readDoc(LOOP_NOTES).split("\n").filter((line) => line.includes("/fc:watch") && line.includes("make -f ai-factory/make/ai.mk loop-watch"));
	assert.equal(lines.length, 1, `${LOOP_NOTES} has ${lines.length} lines naming both /fc:watch and make -f ai-factory/make/ai.mk loop-watch, not one`);
	assert.match(lines[0], /follow/i, `${LOOP_NOTES}'s watcher line is not about following a running loop`);
});

test("docs", "AC65-headless", () => {
	const flat = flatDoc(HEADLESS);
	assert.ok(flat.includes("make -f ai-factory/make/ai.mk loop-watch LOOP=<loop id>"), `${HEADLESS} does not show make -f ai-factory/make/ai.mk loop-watch LOOP=<loop id>`);
	assert.match(flat, /In CI[^.]*snapshot[^.]*without `FOLLOW`/, `${HEADLESS} does not tell CI to take a snapshot without FOLLOW (R10)`);
	assert.match(flat, /`DETAILS=1`/, `${HEADLESS} does not name DETAILS=1`);
	assert.match(flat, /`FOLLOW=1`/, `${HEADLESS} does not name FOLLOW=1`);
});

test("docs", "AC66-workflow", () => {
	const text = readDoc(WORKFLOW_DOC);
	const start = text.indexOf("\n## 4. The main loop");
	const end = text.indexOf("\n## 5. ", start);
	assert.ok(start >= 0 && end > start, `${WORKFLOW_DOC} has no "4. The main loop" section`);
	const section = text.slice(start, end);
	const bullet = /\n- \*\*`\/fc:loop <plan>` is the one exception\.\*\*[\s\S]*?(?=\n- )/.exec(section);
	assert.ok(bullet, `${WORKFLOW_DOC}'s main loop has no /fc:loop bullet`);
	const flat = bullet[0].replace(/\s+/g, " ");
	assert.match(flat, /watcher/i, `${WORKFLOW_DOC}'s /fc:loop bullet does not mention the watcher`);
	assert.ok(flat.includes("`/fc:watch`"), `${WORKFLOW_DOC}'s /fc:loop bullet does not mention /fc:watch`);
	assert.ok(flat.includes("`make loop-watch`"), `${WORKFLOW_DOC}'s /fc:loop bullet does not mention make loop-watch`);
	const every = text.slice(end, text.indexOf("\n### Project tasks", end));
	assert.match(every, /^\| `\/fc:watch` \|/m, `${WORKFLOW_DOC}'s plugin-level table has no /fc:watch row`);
});

test("docs", "R5-details-warning", () => {
	// --details and DETAILS=1 copy saved agent output into terminals and CI logs.
	for (const rel of [WATCH_NOTES, HEADLESS]) {
		const flat = flatDoc(rel);
		const said = flat.split(/(?<=\.) /).filter((sentence) => /`DETAILS=1`/.test(sentence) && /agent output/.test(sentence) && /\b(?:CI log|terminal)/.test(sentence));
		assert.ok(said.length, `${rel} does not warn that DETAILS=1 copies saved agent output into logs`);
	}
});


// ==== release (plan ASD-007 Step 11; AC70) ===================================================
// The 6.0.0 CHANGELOG entry above 5.2.0.
// Version fields are checked by check-versions.sh.
// Cases for this group go below this marker only.
// ---- marker: release ----
// The text of one `## <version>` entry of CHANGELOG.md, from its heading to the next `## `.
function changelogEntry(text, version) {
	const heading = new RegExp(`^## ${version.replace(/\./g, "\\.")}(?: |$)`, "m").exec(text);
	if (!heading) return null;
	const rest = text.slice(heading.index + heading[0].length);
	const next = /^## /m.exec(rest);
	return { at: heading.index, line: text.slice(heading.index, text.indexOf("\n", heading.index)), body: next ? rest.slice(0, next.index) : rest };
}

test("release", "AC70-entry", () => {
	const text = readDoc("CHANGELOG.md");
	const entry = changelogEntry(text, "6.0.0");
	assert.ok(entry, "CHANGELOG.md has no 6.0.0 entry");
	assert.match(entry.line, /^## 6\.0\.0 — \d{4}-\d\d-\d\d$/, `CHANGELOG.md's 6.0.0 heading is not "## 6.0.0 — <date>": ${entry.line}`);
	const previous = changelogEntry(text, "5.2.0");
	assert.ok(previous, "CHANGELOG.md has no 5.2.0 entry");
	assert.ok(entry.at < previous.at, "CHANGELOG.md's 6.0.0 entry is not above its 5.2.0 entry");
	assert.ok(!/^## /m.test(text.slice(0, entry.at)), "CHANGELOG.md's 6.0.0 entry is not the newest entry");
	const flat = entry.body.replace(/\s+/g, " ");
	// AC70: every part of the feature, by the name a reader would search for.
	for (const item of ["`loop.js watch`", "`/fc:watch`", "`$fc-watch`", "`make loop-watch`", "`LOOP", "`FOLLOW", "`DETAILS", "`started_at`", "`finished_at`", "`tasks/loop.md`"])
		assert.ok(flat.includes(item), `CHANGELOG.md's 6.0.0 entry does not name ${item}`);
	// AC70: breaking, because templates change, which is why the release is major; picked up with /fc:sync-sdlc.
	assert.match(flat, /\*\*Breaking for adopted repos[:.]?\*\*/i, "CHANGELOG.md's 6.0.0 entry does not say it is breaking for adopted repos");
	for (const template of ["loop.js", "ai.mk", "tasks/loop.md"])
		assert.ok(flat.includes(`\`${template}\``), `CHANGELOG.md's 6.0.0 entry does not name the ${template} template`);
	assert.match(flat, /templates?/i, "CHANGELOG.md's 6.0.0 entry does not say templates change");
	assert.match(flat, /major/i, "CHANGELOG.md's 6.0.0 entry does not say why the release is major");
	assert.ok(flat.includes("`/fc:sync-sdlc`"), "CHANGELOG.md's 6.0.0 entry does not say adopted repos pick it up with /fc:sync-sdlc");
	// R13, R11, R5 and R10, as plan Step 11 lists them.
	assert.match(flat, /roll(?:ing)? back[^.]*resync/i, "CHANGELOG.md's 6.0.0 entry does not say rolling back means resyncing (R13)");
	assert.match(flat, /6\.0\.0[^.]*(?:cannot|can't|not) be reused|(?:cannot|can't) reuse[^.]*6\.0\.0/i, "CHANGELOG.md's 6.0.0 entry does not say 6.0.0 cannot be reused (R13)");
	assert.ok(flat.split(/(?<=\.) /).some((s) => s.includes("5.x") && s.includes("`unknown`") && /elapsed/.test(s)), "CHANGELOG.md's 6.0.0 entry does not say 5.x states show elapsed time as unknown (R11)");
	assert.ok(flat.split(/(?<=\.) /).some((s) => s.includes("`--details`") && s.includes("`DETAILS=1`") && /agent output/.test(s)), "CHANGELOG.md's 6.0.0 entry does not say --details and DETAILS=1 print saved agent output (R5)");
	assert.ok(flat.split(/(?<=\.) /).some((s) => /\bCI\b/.test(s) && /snapshot/.test(s) && s.includes("without `FOLLOW`")), "CHANGELOG.md's 6.0.0 entry does not say CI takes snapshots without FOLLOW (R10)");
});

// ---- the step of plan ASD-007 that fills each group (fixed; no later step edits it) --------
const later = { fields: 2, render: 3, details: 4, select: 5, errors: 5, follow: 6, readonly: 7, make: 8, surface: 9, docs: 10, release: 11 };

try {
	for (const c of cases) {
		if (!want(c.group)) continue;
		try {
			c.fn();
			passed++;
			if (process.env.VERBOSE) console.log(`ok: ${c.group}/${c.name}`);
		} catch (error) {
			if (error instanceof Skip) skips.push(`${c.group}/${c.name}: ${error.message}`);
			else failures.push(`${c.group}/${c.name}: ${String(error.message).split("\n")[0]}`);
		}
	}
} finally {
	for (const dir of fixtures) fs.rmSync(dir, { recursive: true, force: true });
}
for (const [name, step] of Object.entries(later))
	if (want(name) && !cases.some((c) => c.group === name))
		failures.push(`${name}: no cases yet (plan ASD-007 Step ${step} adds them)`);
for (const line of skips) console.log(`SKIP ${line}`);
for (const line of failures) console.error(`FAIL ${line}`);
if (failures.length) process.exitCode = 1;
else console.log(`loop-watch ok — ${passed} cases (${selected})`);
NODE
