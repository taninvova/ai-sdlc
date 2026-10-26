#!/usr/bin/env bash
# /t4:loop (spec 0022): pins the ADR that records the loop's exceptions, and later the
# ai-factory/make/loop.js helper, the headless runner, the prompts and the docs.
#
# Groups: adr, options, select, validate, schedule, worktree, apply, outcome, headless,
# procedures, docs (default: every group). Each case reports a missing file or export as its
# own failure, never as a crash, so the red run of a group names every case it holds. A group
# that a later step of plan 0022 fills fails with "no cases yet" until that step lands.
set -euo pipefail
cd "$(dirname "$0")/../../.."
group="${1:-all}"
groups="adr, options, select, validate, schedule, worktree, apply, outcome, headless, procedures, docs"
case "$group" in
	all | adr | options | select | validate | schedule | worktree | apply | outcome | headless | procedures | docs) ;;
	*) echo "check-loop: unknown group '$group' (expected: $groups)" >&2; exit 2 ;;
esac
LOOP_GROUP="$group" node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const ADR_DIR = "ai-factory/adr";
const selected = process.env.LOOP_GROUP;
const want = (name) => selected === "all" || selected === name;
const failures = [];
let passed = 0;

const cases = [];
const test = (group, name, fn) => cases.push({ group, name, fn });

// Every ADR in the repo, the template excluded. The filename's ID is never read: an ADR is a
// legacy `NNNN-` file or one created by `ids.js new adr` with a letter-and-digit ID.
function adrs() {
	if (!fs.existsSync(ADR_DIR)) throw new Error(`${ADR_DIR}/ does not exist`);
	return fs
		.readdirSync(ADR_DIR, { withFileTypes: true })
		.filter((entry) => entry.isFile() && entry.name.endsWith(".md") && entry.name !== "0000-template.md")
		.map((entry) => ({ rel: `${ADR_DIR}/${entry.name}`, text: fs.readFileSync(path.join(ADR_DIR, entry.name), "utf8") }))
		.sort((a, b) => a.rel.localeCompare(b.rel));
}

// ---- adr (plan 0022 Step 1, AC53) ---------------------------------------------------------
test("adr", "adr-records-exceptions", () => {
	const naming = adrs().filter((adr) => /\/t4:loop\b/.test(adr.text));
	if (naming.length === 0) throw new Error("no ADR names /t4:loop");
	assert.equal(naming.length, 1, `more than one ADR names /t4:loop: ${naming.map((adr) => adr.rel).join(", ")}`);
	const [{ rel, text }] = naming;
	for (const id of ["DEC-003", "BR-010", "FR-026", "FR-027"])
		assert.match(text, new RegExp(`\\b${id}\\b`), `${rel} does not name ${id}`);
	assert.match(text, /^(?:.*·\s*)?Status:\s*accepted\s*$/m, `${rel} has no 'Status: accepted' line`);
});

// ---- loop.js fixtures (plan 0022 Step 2 onwards) ------------------------------------------
// Every fixture is a disposable git repository under ai-factory/runs/tmp/ holding a copy of the
// template's loop.js and the helpers it requires, run as `node ai-factory/make/loop.js` from the
// fixture root so the helper resolves that root exactly as it does in an adopted repo.
const { spawnSync, execFileSync } = require("node:child_process");
const crypto = require("node:crypto");
const PLUGIN = process.cwd();
const MAKE = path.join(PLUGIN, "skills/ai-layout/templates/ai-factory/make");
const LOOP = path.join(MAKE, "loop.js");
const STATE_SH = path.join(PLUGIN, "skills/ai-layout/scripts/state.sh");
const SCRATCH = path.join(PLUGIN, "ai-factory/runs/tmp");
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
// files: { "ai-factory/plans/0001-x.md": "…" }. A plan text written as an array is joined with
// newlines and ends with one.
function repo(name, files) {
	needLoop();
	fs.mkdirSync(SCRATCH, { recursive: true });
	const dir = fs.mkdtempSync(path.join(SCRATCH, `loop-${name}-`));
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
	git(dir, "init", "-q", "-b", "main");
	git(dir, "add", "-A");
	git(dir, "commit", "-q", "-m", "fixture");
	// Uncommitted work of every kind, so "no file changes" is measured against a dirty tree.
	fs.writeFileSync(path.join(dir, "src.txt"), "base\nstaged\n");
	git(dir, "add", "src.txt");
	fs.writeFileSync(path.join(dir, "src.txt"), "base\nstaged\nunstaged\n");
	fs.writeFileSync(path.join(dir, "untracked.txt"), "new\n");
	return dir;
}
// `node ai-factory/make/loop.js start …` in the fixture: exit status, the one JSON object on
// stdout, and stderr.
function start(dir, ...args) {
	const run = spawnSync(process.execPath, ["ai-factory/make/loop.js", "start", ...args], {
		cwd: dir,
		encoding: "utf8",
		env: ENV,
	});
	let json = null;
	try {
		json = JSON.parse(run.stdout);
	} catch {
		throw new Error(`loop.js start ${args.join(" ")} printed no JSON object (exit ${run.status}): ${(run.stdout + run.stderr).trim().split("\n")[0]}`);
	}
	return { status: run.status, json, stderr: run.stderr };
}
// The working tree's content as a tree hash, built in a throwaway index so the real one is never
// refreshed, plus the real index's bytes and the loop scratch directory's existence.
function fingerprint(dir) {
	const temp = path.join(dir, ".git", "fingerprint-index");
	fs.copyFileSync(path.join(dir, ".git/index"), temp);
	const env = { ...ENV, GIT_INDEX_FILE: temp };
	execFileSync("git", ["add", "-A"], { cwd: dir, env, stdio: "pipe" });
	const tree = execFileSync("git", ["write-tree"], { cwd: dir, env, stdio: "pipe" }).toString().trim();
	fs.unlinkSync(temp);
	const index = crypto.createHash("sha256").update(fs.readFileSync(path.join(dir, ".git/index"))).digest("hex");
	return { tree, index, loopScratch: fs.existsSync(path.join(dir, "ai-factory/runs/tmp/loop")) };
}
function unchanged(dir, label, fn) {
	const before = fingerprint(dir);
	const result = fn();
	assert.deepEqual(fingerprint(dir), before, `${label} changed a file, the index or created loop state`);
	return result;
}
const expectUsage = (dir, args, option) => {
	const run = unchanged(dir, `start ${args.join(" ")}`, () => start(dir, ...args));
	assert.equal(run.status, 2, `start ${args.join(" ")} exited ${run.status}, not 2 (usage)`);
	assert.equal(run.json.action, "usage", `start ${args.join(" ")} is not a usage answer`);
	if (option) assert.match(run.json.message, new RegExp(option), `start ${args.join(" ")} does not name ${option}`);
	return run;
};
const expectStarted = (dir, args) => {
	const run = start(dir, ...args);
	assert.equal(run.status, 0, `start ${args.join(" ")} exited ${run.status}: ${run.stderr.trim()}`);
	assert.equal(run.json.action, "started", `start ${args.join(" ")} answered ${run.json.action}, not started`);
	const state = JSON.parse(fs.readFileSync(path.join(dir, run.json.state), "utf8"));
	assert.equal(state.loop_id, run.json.loop_id);
	return { ...run, state };
};
const expectList = (dir, args, reason) => {
	const run = unchanged(dir, `start ${args.join(" ")}`, () => start(dir, ...args));
	assert.equal(run.status, 0, `start ${args.join(" ")} exited ${run.status}, not 0 (listing)`);
	assert.equal(run.json.action, "list", `start ${args.join(" ")} answered ${run.json.action}, not list`);
	assert.equal(run.json.reason, reason, `start ${args.join(" ")} listed for '${run.json.reason}', not '${reason}'`);
	return run;
};
const expectInvalid = (dir, args) => {
	const run = unchanged(dir, `start ${args.join(" ")}`, () => start(dir, ...args));
	assert.equal(run.status, 3, `start ${args.join(" ")} exited ${run.status}, not 3 (validation)`);
	assert.equal(run.json.action, "invalid", `start ${args.join(" ")} answered ${run.json.action}, not invalid`);
	assert.ok(run.stderr.trim(), `start ${args.join(" ")} reported nothing on stderr`);
	return run;
};
const plan = (title, ...steps) => [`# ${title}`, "", "**Spec:** `ai-factory/specs/0001-x.md`", "", "## Steps", "", ...steps];
const LEGACY = plan("Legacy", "- [x] Step 1 — First.", "", "- [ ] Step 2 — Second.", "  - Do it.", "", "- [ ] Step 3 — Third.");

// ---- options (plan 0022 Step 2; AC5, AC6, AC66) -------------------------------------------
test("options", "max-parallel-range", () => {
	const dir = repo("max-parallel", { "ai-factory/plans/0001-legacy.md": LEGACY });
	for (const value of ["0", "9", "3.5", "x", "-1", ""]) expectUsage(dir, ["0001", "--max-parallel", value], "--max-parallel");
	expectUsage(dir, ["0001", "--max-parallel"], "--max-parallel");
	expectUsage(dir, ["0001", "--max-parallel", "--step-timeout", "5"], "--max-parallel");
	for (const value of [1, 8]) assert.equal(expectStarted(dir, ["0001", "--max-parallel", String(value)]).state.max_parallel, value);
	assert.equal(expectStarted(dir, ["--max-parallel=4", "0001"]).state.max_parallel, 4);
	assert.equal(expectStarted(dir, ["0001"]).state.max_parallel, 3, "--max-parallel does not default to 3");
});
test("options", "step-timeout-range", () => {
	const dir = repo("step-timeout", { "ai-factory/plans/0001-legacy.md": LEGACY });
	for (const value of ["0", "241", "1.5", "x"]) expectUsage(dir, ["0001", "--step-timeout", value], "--step-timeout");
	expectUsage(dir, ["0001", "--step-timeout"], "--step-timeout");
	for (const value of [1, 240]) assert.equal(expectStarted(dir, ["0001", "--step-timeout", String(value)]).state.step_timeout, value);
	assert.equal(expectStarted(dir, ["0001"]).state.step_timeout, 30, "--step-timeout does not default to 30");
});
test("options", "usage-before-validation", () => {
	const dir = repo("usage-first", {
		"ai-factory/plans/0001-cycle.md": plan("Cycle", "- [ ] Step 1 — A.", "  - Depends on: 2", "", "- [ ] Step 2 — B.", "  - Depends on: 1"),
	});
	expectInvalid(dir, ["0001"]);
	expectUsage(dir, ["0001", "--max-parallel", "0"], "--max-parallel");
	expectUsage(dir, ["0001", "--step-timeout", "241"], "--step-timeout");
	expectUsage(dir, ["0099", "--max-parallel", "9"], "--max-parallel");
	expectUsage(dir, ["--step-timeout", "0"], "--step-timeout");
	expectUsage(dir, ["0001", "--bogus"], "--bogus");
	expectUsage(dir, ["0001", "0002"]);
	expectUsage(dir, ["0001", "--host", "vim"], "--host");
	expectUsage(dir, ["0001", "--max-parallel", "2", "--max-parallel", "3"], "--max-parallel");
});
test("options", "codex-timeout-accepted", () => {
	const dir = repo("codex", { "ai-factory/plans/0001-legacy.md": LEGACY });
	for (const value of ["1", "240"]) {
		const run = expectStarted(dir, ["0001", "--host", "codex", "--step-timeout", value]);
		assert.equal(run.state.host, "codex");
		assert.equal(run.state.step_timeout, Number(value));
		assert.equal(run.state.effective_parallel, 1, "Codex does not run steps one at a time");
		assert.ok(run.state.notes.some((note) => /not enforced on Codex/.test(note)), "no 'not enforced on Codex' note");
		assert.ok(run.state.notes.some((note) => /sequential(ly)? on Codex/.test(note)), "no 'sequential on Codex' note");
	}
	const plain = expectStarted(dir, ["0001", "--host", "codex", "--max-parallel", "5"]);
	assert.equal(plain.state.max_parallel, 5);
	assert.equal(plain.state.effective_parallel, 1);
	expectUsage(dir, ["0001", "--host", "codex", "--step-timeout", "241"], "--step-timeout");
	const claude = expectStarted(dir, ["0001", "--host", "claude", "--max-parallel", "5"]);
	assert.equal(claude.state.effective_parallel, 5);
	assert.deepEqual(claude.state.notes, []);
});
test("options", "no-file-changes", () => {
	const dir = repo("no-changes", {
		"ai-factory/plans/0001-legacy.md": LEGACY,
		"ai-factory/plans/0002-cycle.md": plan("Cycle", "- [ ] Step 1 — A.", "  - Depends on: 1"),
		"ai-factory/plans/0007-a.md": LEGACY,
		"ai-factory/plans/0007-b.md": LEGACY,
	});
	expectUsage(dir, ["0001", "--max-parallel", "0"]);
	expectUsage(dir, ["0001", "--step-timeout", "0"]);
	expectInvalid(dir, ["0002"]);
	expectList(dir, [], "no-argument");
	expectList(dir, ["0099"], "unknown");
	expectList(dir, ["7"], "ambiguous");
	// The one start that is allowed to write: its state, and only under the ignored scratch.
	const before = fingerprint(dir);
	const run = expectStarted(dir, ["0001"]);
	assert.match(run.json.state, /^ai-factory\/runs\/tmp\/loop\/[^/]+\/state\.json$/);
	const after = fingerprint(dir);
	assert.equal(after.tree, before.tree, "a successful start changed a tracked or untracked file");
	assert.equal(after.index, before.index, "a successful start changed the index");
});

// ---- select (plan 0022 Step 2; AC1–AC4) ---------------------------------------------------
test("select", "select-number-and-path", () => {
	const dir = repo("select", {
		"ai-factory/plans/0003-alpha.md": LEGACY,
		"ai-factory/plans/0012-beta.md": LEGACY,
		"ai-factory/plans/done/0004-filed.md": plan("Filed", "- [~] Step 1 — Partly."),
		"ai-factory/plans/ABC123-new-id.md": LEGACY,
		"ai-factory/specs/0003-alpha.md": "# Alpha\n",
	});
	const want = "ai-factory/plans/0003-alpha.md";
	for (const arg of ["3", "03", "0003", "0003-alpha", "0003-alpha.md", want, `./${want}`, path.join(dir, want)])
		assert.equal(expectStarted(dir, [arg]).state.plan, want, `start ${arg} selected another plan`);
	assert.equal(expectStarted(dir, ["0004"]).state.plan, "ai-factory/plans/done/0004-filed.md", "a plan under plans/done/ is not selectable");
	// Ambiguity 1: numeric NNNN only until spec 0022 is amended; a spec path is not a plan.
	for (const arg of ["ABC123", "ai-factory/plans/ABC123-new-id.md", "ai-factory/specs/0003-alpha.md"]) expectList(dir, [arg], "unknown");
});
test("select", "select-no-arg", () => {
	const dir = repo("no-arg", {
		"ai-factory/plans/0001-legacy.md": LEGACY,
		"ai-factory/plans/0002-done.md": plan("Done", "- [x] Step 1 — Only."),
	});
	const run = expectList(dir, [], "no-argument");
	const lines = run.json.listing.split("\n");
	assert.equal(lines[0], "kind\tid\tstate\tpath\tstep\tdetail");
	assert.ok(lines.some((line) => line.startsWith("plan\t0001\tnot-started\tai-factory/plans/0001-legacy.md\tStep 2\t")), "the outstanding plan's step is not listed");
	assert.ok(!run.json.listing.includes("0002-done"), "a complete plan is listed as a candidate");
});
test("select", "select-unknown", () => {
	const dir = repo("unknown", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const all = expectList(dir, [], "no-argument").json.listing;
	for (const arg of ["0099", "99", "ai-factory/plans/0099-none.md", "0001-other", "nonsense", "../0001-legacy.md"]) {
		const run = expectList(dir, [arg], "unknown");
		assert.equal(run.json.listing, all, `start ${arg} does not list the candidate plans`);
		assert.equal(run.json.argument, arg);
	}
});
test("select", "select-ambiguous", () => {
	const dir = repo("ambiguous", {
		"ai-factory/plans/0001-legacy.md": LEGACY,
		"ai-factory/plans/0007-a.md": LEGACY,
		"ai-factory/plans/0007-b.md": plan("B", "- [x] Step 1 — Done."),
	});
	for (const arg of ["7", "0007"]) {
		const run = expectList(dir, [arg], "ambiguous");
		const lines = run.json.listing.trimEnd().split("\n");
		assert.equal(lines[0], "kind\tid\tstate\tpath\tstep\tdetail");
		const paths = new Set(lines.slice(1).map((line) => line.split("\t")[3]));
		assert.deepEqual([...paths], ["ai-factory/plans/0007-a.md", "ai-factory/plans/0007-b.md"], `start ${arg} does not list exactly the matching plans`);
		assert.deepEqual(run.json.matches, ["ai-factory/plans/0007-a.md", "ai-factory/plans/0007-b.md"]);
	}
	assert.equal(expectStarted(dir, ["0007-a"]).state.plan, "ai-factory/plans/0007-a.md", "a basename does not disambiguate");
});
test("select", "select-parity-with-state", () => {
	const varied = {
		"ai-factory/plans/0001-legacy.md": LEGACY,
		"ai-factory/plans/0002-complete.md": plan("Complete", "- [x] Step 1 — Done."),
		"ai-factory/plans/0003-mixed.md": [
			"# Mixed",
			"- [ ] **Step 1 – En dash.** Body",
			"- [~] Step 02 - hyphen",
			"- [ ] Step 3 (no dash)",
			"- [ ] A step with no number",
			"- [ ]   Tabs\tand   spaces  ",
			"- [label](https://example.invalid) is a link, not a step",
			"- [ ] Step 4 — Withdrawn later.",
			"**Result — Step 4 withdrawn; replaced.**",
			"    **Result — Step 3 withdrawn; indented, so ignored.**",
			"```",
			"**Result — Step 1 withdrawn; fenced, so ignored.**",
			"```",
		],
		"ai-factory/plans/0004-unknown.md": plan("Unknown", "- [?] Step 1 — Odd marker.", "- [ ] Step 2 — Fine."),
		"ai-factory/plans/0005-no-steps.md": "# Nothing here\n",
		"ai-factory/plans/0006-closed.md": plan("Closed", "- [ ] Step 1 — Gone.", "**Result — Step 1 withdrawn; not needed.**"),
		"ai-factory/plans/done/0008-filed.md": plan("Filed", "- [~] Step 1 — Partly."),
		"ai-factory/plans/done/0009-filed-done.md": plan("Filed done", "- [x] Step 1 — Done."),
		"ai-factory/plans/abc123-lower.md": ["# Lower", "Created: 2026-10-01T10:00:00Z", "- [ ] Step 1 — New ID."],
		"ai-factory/plans/DEF456-dated.md": ["# Dated", "Created: 2026-09-01T10:00:00.500Z", "- [ ] Step 1 — Earlier."],
		"ai-factory/plans/GHI789-undated.md": ["# Undated", "- [ ] Step 1 — No stamp."],
		"ai-factory/plans/0010-no-newline.md": "# No newline\n- [ ] Step 1 — Read.\n- [ ] Step 2 — Last line, unterminated.",
		"ai-factory/plans/notes.md": "- [ ] Step 1 — A name with no ID.\n",
	};
	const finished = { "ai-factory/plans/0001-done.md": plan("Done", "- [x] Step 1 — Done.") };
	for (const [name, files] of [["parity", varied], ["parity-done", finished]]) {
		const dir = repo(name, files);
		const expected = execFileSync("bash", [STATE_SH, dir, ".", "--plans"], { cwd: PLUGIN, encoding: "utf8" });
		for (const args of [[], ["0099"]]) {
			const listing = expectList(dir, args, args.length ? "unknown" : "no-argument").json.listing;
			assert.equal(listing, expected, `start ${args.join(" ")} listing differs from state.sh --plans in fixture ${name}`);
		}
	}
});

// ---- validate (plan 0022 Step 2; AC8–AC10, the helper side of AC11) ------------------------
const problems = (run, kind) => run.json.problems.filter((problem) => problem.kind === kind);
test("validate", "missing-reference", () => {
	const dir = repo("missing-ref", {
		"ai-factory/plans/0001-missing.md": plan("Missing", "- [x] Step 1 — A.", "", "- [ ] Step 2 — B.", "  - Depends on: 1, 9", "", "- [ ] Step 3 — C.", "  - Depends on: 2"),
	});
	const run = expectInvalid(dir, ["0001"]);
	const found = problems(run, "missing-reference");
	assert.equal(found.length, 1, "the missing reference is not reported exactly once");
	assert.equal(found[0].step, 2);
	assert.equal(found[0].reference, 9);
	assert.match(found[0].message, /Step 2\b/);
	assert.match(found[0].message, /\b9\b/);
	assert.match(run.stderr, /Step 2\b.*\b9\b/);
});
test("validate", "cycle-named", () => {
	const two = repo("cycle-two", {
		"ai-factory/plans/0001-two.md": plan("Two", "- [ ] Step 1 — A.", "  - Depends on: 2", "", "- [ ] Step 2 — B.", "  - Depends on: 1", "", "- [ ] Step 3 — C."),
	});
	const twoCycles = problems(expectInvalid(two, ["0001"]), "cycle");
	assert.equal(twoCycles.length, 1);
	assert.deepEqual(twoCycles[0].steps, [1, 2]);
	assert.match(twoCycles[0].message, /Step 1\b/);
	assert.match(twoCycles[0].message, /Step 2\b/);
	// A three-step cycle closed through an implicit dependency: Step 3 has no line, so it waits
	// for Steps 1 and 2, and Step 1 waits for Step 3. Step 4 depends on the cycle but is not in it.
	const three = repo("cycle-three", {
		"ai-factory/plans/0001-three.md": plan("Three", "- [ ] Step 1 — A.", "  - Depends on: 3", "", "- [ ] Step 2 — B.", "  - Depends on: 1", "", "- [ ] Step 3 — C.", "", "- [ ] Step 4 — D."),
	});
	const threeCycles = problems(expectInvalid(three, ["0001"]), "cycle");
	assert.equal(threeCycles.length, 1);
	assert.deepEqual(threeCycles[0].steps, [1, 2, 3]);
	const self = repo("cycle-self", { "ai-factory/plans/0001-self.md": plan("Self", "- [ ] Step 1 — A.", "  - Depends on: 1") });
	assert.deepEqual(problems(expectInvalid(self, ["0001"]), "cycle")[0].steps, [1]);
});
test("validate", "withdrawn-unticked", () => {
	const after = repo("withdrawn-after", {
		"ai-factory/plans/0001-after.md": plan("After", "- [x] Step 1 — A.", "", "- [ ] Step 2 — B.", "", "**Result — Step 2 withdrawn; superseded.**", "", "- [ ] Step 3 — C."),
	});
	const before = repo("withdrawn-before", {
		"ai-factory/plans/0001-before.md": [
			"# Before",
			"**Result — Step 3 is withdrawn.** Recorded first.",
			"",
			"- [ ] Step 1 — A.",
			"- [~] Step 3 — C.",
			"- [x] Step 4 — D.",
			"**Result — Step 4 withdrawn; ticked first, so already reconciled.**",
		],
	});
	for (const [dir, step] of [[after, 2], [before, 3]]) {
		const found = problems(expectInvalid(dir, ["0001"]), "withdrawn-unticked");
		assert.deepEqual(found.map((problem) => problem.step), [step], `the unticked withdrawn Step ${step} is not the one reported`);
		assert.match(found[0].message, /reconcile/i);
	}
});
test("validate", "validate-exit-3", () => {
	const dir = repo("exit-3", {
		"ai-factory/plans/0001-all.md": plan(
			"All",
			"- [ ] Step 1 — A.",
			"  - Depends on: 7",
			"",
			"- [ ] Step 2 — B.",
			"  - Depends on: 3",
			"",
			"- [ ] Step 3 — C.",
			"  - Depends on: 2",
			"",
			"- [ ] Step 4 — D.",
			"**Result — Step 4 withdrawn; gone.**",
		),
		"ai-factory/plans/0002-malformed.md": plan("Malformed", "- [ ] Step 1 — A.", "", "- [ ] Step 2 — B.", "  - Depends on: Step 1"),
	});
	const run = expectInvalid(dir, ["0001"]);
	assert.deepEqual(run.json.problems.map((problem) => problem.kind).sort(), ["cycle", "missing-reference", "withdrawn-unticked"], "every problem is not reported together");
	assert.equal(run.json.plan, "ai-factory/plans/0001-all.md");
	for (const problem of run.json.problems) assert.ok(run.stderr.includes(problem.message), `stderr omits: ${problem.message}`);
	assert.deepEqual(problems(expectInvalid(dir, ["0002"]), "malformed-depends").map((problem) => problem.step), [2]);
});
test("validate", "legacy-plan-valid", () => {
	const dir = repo("legacy", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const run = expectStarted(dir, ["0001"]);
	assert.deepEqual(
		run.state.steps.map((step) => [step.number, step.done, step.depends]),
		[[1, true, []], [2, false, [1]], [3, false, [1, 2]]],
		"a step with no Depends on: line does not wait for every earlier step",
	);
	const explicit = repo("explicit", {
		"ai-factory/plans/0001-explicit.md": plan("Explicit", "- [ ] Step 1 — A.", "", "- [ ] Step 2 — B.", "  - Depends on: 1, 1", "", "- [ ] Step 3 — C.", "  Depends on: 1", "", "- [ ] Step 4 — D."),
	});
	assert.deepEqual(expectStarted(explicit, ["0001"]).state.steps.map((step) => step.depends), [[], [1], [1], [1, 2, 3]]);
	const ticked = repo("all-ticked", { "ai-factory/plans/0001-done.md": plan("Done", "- [x] Step 1 — A.", "- [x] Step 2 — B.") });
	assert.deepEqual(expectStarted(ticked, ["0001"]).json.remaining, [], "a fully ticked plan does not start with nothing remaining");
	// This repo's own plan, as written, passes the same validation.
	const own = require(LOOP).validatePlan(fs.readFileSync("ai-factory/plans/0022-loop.md", "utf8"));
	assert.deepEqual(own.problems, [], `plan 0022 does not validate: ${own.problems.map((problem) => problem.message).join("; ")}`);
});

// ---- schedule (plan 0022 Step 3; AC7, AC12, AC14–AC17, AC21–AC23, AC30, AC34, AC41, AC46) ---
// Pure: no git, no host. A plan text goes through validatePlan and createState, then `next` and
// `finish --dry` are driven through the module exports with simulated implementer results.
function scheduler() {
	if (!fs.existsSync(LOOP)) throw new Error("make/loop.js does not exist");
	const loop = require(LOOP);
	for (const name of ["next", "finish", "createState"])
		if (typeof loop[name] !== "function") throw new Error(`loop.js exports no ${name}()`);
	return loop;
}
// steps: [[number, done, depends|null], …] → a plan text. depends null writes no Depends on: line.
function stepsPlan(steps) {
	const lines = ["# Scheduled", "", "## Steps", ""];
	for (const [number, done, depends] of steps) {
		lines.push(`- [${done ? "x" : " "}] Step ${number} — Step ${number}.`);
		if (depends) lines.push(`  - Depends on: ${depends.join(", ")}`);
		lines.push("");
	}
	return lines.join("\n");
}
function schedState(steps, options = {}) {
	const loop = scheduler();
	const { steps: parsed, problems: found } = loop.validatePlan(stepsPlan(steps));
	assert.deepEqual(found, [], "the fixture plan does not validate");
	return loop.createState({
		plan: "ai-factory/plans/0001-scheduled.md",
		steps: parsed,
		options: { ...loop.DEFAULTS, ...options },
		loopId: "loop-20261025T000000Z-000000",
	});
}
// Drives the loop to its end. `pick(running)` chooses which running step finishes next (default:
// the lowest); `results[N]` is that step's simulated result (default met).
function drive(state, { pick = (running) => Math.min(...running), results = {} } = {}) {
	const loop = scheduler();
	const trace = { batches: [], starts: [], modes: {}, maxRunning: 0, applied: [], finishes: [], snapshots: [] };
	for (let guard = 0; guard < 100000; guard++) {
		const answer = loop.next(state);
		if (answer.action === "start") {
			assert.ok(answer.steps.length > 0, "next answered start with no steps");
			trace.batches.push(answer.steps.map((step) => step.number));
			for (const step of answer.steps) {
				assert.ok(!(step.number in trace.modes), `Step ${step.number} started twice`);
				trace.starts.push(step.number);
				trace.modes[step.number] = step.mode;
				// A step's dependencies are ticked before it starts (AC16), and so is every earlier step
				// with no Depends on: line (AC14).
				const own = state.steps.find((entry) => entry.number === step.number);
				for (const ref of own.depends)
					assert.ok(state.steps.find((entry) => entry.number === ref).done, `Step ${step.number} started before Step ${ref} was ticked`);
				for (const earlier of state.steps.filter((entry) => entry.number < step.number && !entry.explicit))
					assert.ok(earlier.done, `Step ${step.number} started before Step ${earlier.number}, which has no Depends on: line, was ticked`);
			}
			const modes = state.running.map((entry) => entry.mode);
			assert.ok(!(modes.includes("main") && modes.length > 1), "a main-tree step runs alongside another step");
			trace.maxRunning = Math.max(trace.maxRunning, state.running.length);
			continue;
		}
		if (answer.action === "wait") {
			const running = state.running.map((entry) => entry.step);
			assert.ok(running.length > 0, "next answered wait with no step running");
			const step = pick(running);
			const result = results[step] || "met";
			const done = loop.finish(state, step, result, { dry: true });
			trace.finishes.push(step);
			trace.applied.push(...done.applied);
			continue;
		}
		return { answer, trace };
	}
	throw new Error("the loop never ended");
}
const ticked = (state) => state.steps.filter((step) => step.done).map((step) => step.number);
const range = (from, to) => Array.from({ length: to - from + 1 }, (_, index) => from + index);

test("schedule", "max-parallel-1-sequential", () => {
	const state = schedState([[1, false, null], ...range(2, 6).map((n) => [n, false, [1]])], { max_parallel: 1 });
	const { answer, trace } = drive(state);
	assert.equal(answer.action, "review");
	assert.deepEqual(trace.starts, range(1, 6), "--max-parallel 1 does not run the steps in plan order");
	assert.ok(trace.batches.every((batch) => batch.length === 1), "--max-parallel 1 started a batch of more than one step");
	assert.equal(trace.maxRunning, 1);
	assert.ok(Object.values(trace.modes).every((mode) => mode === "main"), "--max-parallel 1 used a worktree");
});
test("schedule", "runs-all-unticked", () => {
	const steps = [[1, false, null], [2, false, [1]], [3, false, [1]], [4, false, [1]], [5, false, [2, 3]], [6, false, null],
		[7, false, [6]], [8, false, [6]], [9, false, [7]], [10, false, [8, 9]], [11, false, [6]], [12, false, null]];
	const state = schedState(steps);
	const { answer, trace } = drive(state, { pick: (running) => Math.max(...running) });
	assert.equal(answer.action, "review", `the loop ended with ${answer.action}, not review`);
	assert.deepEqual(ticked(state), range(1, 12), "not every step is ticked in one state lifetime");
	assert.deepEqual([...trace.starts].sort((a, b) => a - b), range(1, 12));
	assert.deepEqual(state.causes, []);
	assert.deepEqual([...state.ran].sort((a, b) => a - b), range(1, 12), "the steps run in this invocation are not all recorded");
	assert.deepEqual(answer.ran, range(1, 12), "review does not report the steps run in this invocation");
	const partial = schedState([[1, true, null], [2, false, null], [3, true, null], [4, false, null]]);
	const again = drive(partial);
	assert.equal(again.answer.action, "review");
	assert.deepEqual(again.trace.starts, [2, 4], "a ticked step was run again, or an unticked one skipped");
	const allDone = schedState([[1, true, null], [2, true, [1]]]);
	const none = drive(allDone);
	assert.equal(none.answer.action, "review", "a fully ticked plan does not go straight to review");
	assert.deepEqual(none.trace.starts, []);
});
test("schedule", "implicit-depends-all-earlier", () => {
	// Step 4 has no line: it waits for 1–3, and Step 5 (Depends on: 1) and Step 6 wait for it.
	const state = schedState([[1, false, null], [2, false, [1]], [3, false, [1]], [4, false, null], [5, false, [1]], [6, false, [1]]]);
	const { answer, trace } = drive(state, { pick: (running) => Math.max(...running) });
	assert.equal(answer.action, "review");
	assert.deepEqual(trace.batches, [[1], [2, 3], [4], [5, 6]], "a step with no Depends on: line is not a barrier both ways");
	assert.equal(trace.modes[4], "main");
	assert.ok(trace.starts.indexOf(5) > trace.starts.indexOf(4), "a later step started before the step with no line was ticked");
	// Step 3 waits for Step 2, which waits for Step 5, which may not pass Step 3: a cycle only through
	// that barrier is still a cycle, so a plan that validates can never deadlock the scheduler.
	const barrier = scheduler().validatePlan(stepsPlan([[1, false, null], [2, false, [5]], [3, false, null], [4, false, [1]], [5, false, [1]]]));
	assert.deepEqual(barrier.problems.filter((problem) => problem.kind === "cycle").map((problem) => problem.steps), [[2, 3, 5]]);
});
test("schedule", "legacy-plan-sequential-main", () => {
	const state = schedState(range(1, 7).map((n) => [n, n === 1, null]), { max_parallel: 8 });
	const { answer, trace } = drive(state);
	assert.equal(answer.action, "review");
	assert.deepEqual(trace.batches, range(2, 7).map((n) => [n]));
	assert.ok(Object.values(trace.modes).every((mode) => mode === "main"), "a legacy plan used a worktree");
	assert.equal(trace.maxRunning, 1);
});
test("schedule", "explicit-depends", () => {
	const loop = scheduler();
	const plan = [[1, true, null], [2, false, [1]], [3, false, [1]], [4, false, [2, 3]], [5, false, [2]]];
	// Step 2 finishes first and is applied; Step 4 still waits for Step 3, Step 5 starts.
	const state = schedState(plan);
	assert.deepEqual(loop.next(state).steps.map((step) => step.number), [2, 3]);
	assert.deepEqual(loop.finish(state, 2, "met", { dry: true }).applied, [2]);
	const after2 = loop.next(state);
	assert.equal(after2.action, "start");
	assert.deepEqual(after2.steps.map((step) => [step.number, step.mode]), [[5, "worktree"]], "Step 4 started before Step 3 was ticked");
	assert.equal(loop.next(state).action, "wait");
	loop.finish(state, 3, "met", { dry: true });
	loop.finish(state, 5, "met", { dry: true });
	assert.deepEqual(loop.next(state).steps.map((step) => [step.number, step.mode]), [[4, "main"]]);
	// The full drive, in both finishing orders, never starts a step before its dependencies.
	for (const pick of [(running) => Math.min(...running), (running) => Math.max(...running)])
		assert.equal(drive(schedState(plan), { pick }).answer.action, "review");
});
test("schedule", "alone-runs-main", () => {
	const loop = scheduler();
	const state = schedState([[1, false, null], [2, false, [1]], [3, false, [1]], [4, false, [2, 3]]]);
	assert.deepEqual(loop.next(state).steps, [{ number: 1, mode: "main" }], "a lone first step does not run in the main tree");
	assert.equal(loop.next(state).action, "wait", "a step started while a main-tree step runs");
	loop.finish(state, 1, "met", { dry: true });
	assert.deepEqual(loop.next(state).steps.map((step) => step.mode), ["worktree", "worktree"]);
	loop.finish(state, 3, "met", { dry: true });
	assert.equal(loop.next(state).action, "wait");
	loop.finish(state, 2, "met", { dry: true });
	assert.deepEqual(loop.next(state).steps, [{ number: 4, mode: "main" }], "a step running alone after a parallel batch is not in the main tree");
	// A main-tree step is ticked by its implementer, as under /t4:run: finish applies no delta.
	const main = loop.finish(state, 4, "met", { dry: true });
	assert.deepEqual(main.applied, []);
	assert.deepEqual(main.ticked, [4]);
	assert.equal(loop.next(state).action, "review");
});
test("schedule", "concurrent-up-to-limit", () => {
	const loop = scheduler();
	const state = schedState([[1, true, null], [2, false, [1]], [3, false, [1]], [4, false, [1]]]);
	const answer = loop.next(state);
	assert.equal(answer.action, "start");
	assert.deepEqual(answer.steps, [2, 3, 4].map((number) => ({ number, mode: "worktree" })), "ready steps do not start together in worktrees");
	assert.deepEqual(state.running.map((entry) => entry.step), [2, 3, 4]);
});
test("schedule", "default-limit-3", () => {
	const state = schedState([[1, true, null], ...range(2, 9).map((n) => [n, false, [1]])]);
	assert.equal(state.effective_parallel, 3);
	const { answer, trace } = drive(state);
	assert.equal(answer.action, "review");
	assert.equal(trace.maxRunning, 3, "the default limit is not three");
	assert.deepEqual(trace.batches[0], [2, 3, 4]);
});
test("schedule", "limit-n", () => {
	for (const limit of [2, 8]) {
		const state = schedState([[1, true, null], ...range(2, 13).map((n) => [n, false, [1]])], { max_parallel: limit });
		const { answer, trace } = drive(state, { pick: (running) => Math.max(...running) });
		assert.equal(answer.action, "review");
		assert.equal(trace.maxRunning, limit, `--max-parallel ${limit} ran ${trace.maxRunning} steps at once`);
		assert.deepEqual(trace.batches[0], range(2, 1 + limit));
		assert.deepEqual(ticked(state), range(1, 13));
	}
});
test("schedule", "apply-in-plan-order", () => {
	const loop = scheduler();
	const state = schedState([[1, true, null], [2, false, [1]], [3, false, [1]], [4, false, [1]]]);
	loop.next(state);
	const three = loop.finish(state, 3, "met", { dry: true });
	assert.deepEqual(three.applied, [], "Step 3 was applied while Step 2 still ran");
	assert.equal(state.steps.find((step) => step.number === 3).done, false, "Step 3 was ticked before its apply");
	assert.deepEqual(state.pending, [3]);
	const two = loop.finish(state, 2, "met", { dry: true });
	assert.deepEqual(two.applied, [2, 3], "Step 2 was not applied before Step 3");
	assert.deepEqual(two.ticked, [2, 3]);
	assert.deepEqual(loop.finish(state, 4, "met", { dry: true }).applied, [4]);
	const { trace } = drive(schedState([[1, true, null], ...range(2, 6).map((n) => [n, false, [1]])], { max_parallel: 5 }), {
		pick: (running) => Math.max(...running),
	});
	assert.deepEqual(trace.finishes, [6, 5, 4, 3, 2]);
	assert.deepEqual(trace.applied, [2, 3, 4, 5, 6], "deltas are not applied in plan order");
});
test("schedule", "codex-sequential", () => {
	const plan = [[1, true, null], ...range(2, 5).map((n) => [n, false, [1]])];
	for (const options of [{ host: "codex", max_parallel: 5 }, { host: "codex" }]) {
		const state = schedState(plan, options);
		assert.equal(state.effective_parallel, 1);
		assert.ok(state.notes.some((note) => /sequential(ly)? on Codex/.test(note)), "no 'sequential on Codex' note");
		const { answer, trace } = drive(state);
		assert.equal(answer.action, "review");
		assert.deepEqual(trace.batches, range(2, 5).map((n) => [n]), "Codex did not run the ready steps one at a time in plan order");
		assert.ok(Object.values(trace.modes).every((mode) => mode === "main"), "Codex used a worktree");
	}
	assert.equal(schedState(plan, { host: "claude", max_parallel: 5 }).effective_parallel, 5);
});
test("schedule", "failure-drains", () => {
	const loop = scheduler();
	for (const kind of ["failed", "timeout"]) {
		const state = schedState([[1, true, null], [2, false, [1]], [3, false, [1]], [4, false, [1]], [5, false, [1]], [6, false, [2]]]);
		assert.deepEqual(loop.next(state).steps.map((step) => step.number), [2, 3, 4]);
		loop.finish(state, 4, "met", { dry: true }); // waits behind 2 and 3
		const failed = loop.finish(state, 3, kind, { dry: true });
		assert.deepEqual(failed.applied, []);
		assert.equal(loop.next(state).action, "wait", `a ${kind} step did not stop new starts`);
		const two = loop.finish(state, 2, "met", { dry: true });
		assert.deepEqual(two.applied, [2, 4], "steps that finished cleanly are not brought back after a failure");
		const end = loop.next(state);
		assert.equal(end.action, "stop", `the loop did not stop after a ${kind}`);
		assert.deepEqual(state.causes.map((cause) => [cause.kind, cause.step]), [[kind, 3]]);
		assert.deepEqual(end.remaining, [3, 5, 6], "the remaining unticked steps are not reported");
		assert.deepEqual(ticked(state), [1, 2, 4]);
		assert.ok(!state.ran.includes(5) && !state.ran.includes(6), "a step started after the failure");
	}
	// A main-tree failure stops at once: nothing is running, nothing else starts.
	const main = schedState(range(1, 4).map((n) => [n, false, null]));
	const { answer, trace } = drive(main, { results: { 2: "failed" } });
	assert.equal(answer.action, "stop");
	assert.deepEqual(trace.starts, [1, 2]);
	assert.deepEqual(answer.remaining, [2, 3, 4]);
	// A later step that finished before the failing lower one is applied once that one ends.
	const late = schedState([[1, true, null], [2, false, [1]], [3, false, [1]]]);
	loop.next(late);
	loop.finish(late, 3, "met", { dry: true });
	assert.deepEqual(loop.finish(late, 2, "failed", { dry: true }).applied, [3]);
	assert.equal(loop.next(late).action, "stop");
	assert.throws(() => loop.finish(late, 2, "met", { dry: true }), /not running/, "a step that is not running can be finished");
	assert.throws(() => loop.finish(schedState([[1, false, null]]), 1, "maybe", { dry: true }), /met, failed or timeout/);
});
test("schedule", "no-step-cap", () => {
	const legacy = schedState(range(1, 60).map((n) => [n, false, null]));
	const sequential = drive(legacy);
	assert.equal(sequential.answer.action, "review", "a sixty-step plan did not run to its end");
	assert.equal(sequential.trace.starts.length, 60);
	const wide = schedState([[1, false, null], ...range(2, 60).map((n) => [n, false, [1]])], { max_parallel: 8 });
	const parallel = drive(wide);
	assert.equal(parallel.answer.action, "review");
	assert.deepEqual(ticked(wide), range(1, 60));
});

// ---- worktree (plan 0022 Step 4; AC24–AC26, AC32, AC33, AC39) ------------------------------
// Real git fixtures: `start` and `next` through the CLI, then `prepare` through the CLI, or through
// the fixture's own module with an injected git runner where a failure has to be forced.
function preparer() {
	if (!fs.existsSync(LOOP)) throw new Error("make/loop.js does not exist");
	if (typeof require(LOOP).prepare !== "function") throw new Error("loop.js exports no prepare()");
}
// `node ai-factory/make/loop.js <subcommand> …` in the fixture.
function cli(dir, ...args) {
	const run = spawnSync(process.execPath, ["ai-factory/make/loop.js", ...args], { cwd: dir, encoding: "utf8", env: ENV });
	let json = null;
	try {
		json = JSON.parse(run.stdout);
	} catch {
		throw new Error(`loop.js ${args.join(" ")} printed no JSON object (exit ${run.status}): ${(run.stdout + run.stderr).trim().split("\n")[0]}`);
	}
	return { status: run.status, json, stderr: run.stderr };
}
const PARALLEL = plan("Parallel", "- [x] Step 1 — A.", "", "- [ ] Step 2 — B.", "  - Depends on: 1", "", "- [ ] Step 3 — C.", "  - Depends on: 1", "", "- [ ] Step 4 — D.");
// A started loop whose `next` has started Steps 2 and 3 in worktrees.
function startedPair(name, files = {}) {
	preparer();
	const dir = repo(name, { "ai-factory/plans/0001-parallel.md": PARALLEL, ...files });
	const { json } = expectStarted(dir, ["0001"]);
	const answer = cli(dir, "next", json.loop_id).json;
	assert.deepEqual(answer.steps, [{ number: 2, mode: "worktree" }, { number: 3, mode: "worktree" }], "the fixture plan did not start two worktree steps");
	return { dir, loopId: json.loop_id };
}
const readLoopState = (dir, loopId) => JSON.parse(fs.readFileSync(path.join(dir, "ai-factory/runs/tmp/loop", loopId, "state.json"), "utf8"));
const expectPrepared = (dir, loopId, step) => {
	const run = cli(dir, "prepare", loopId, String(step));
	assert.equal(run.status, 0, `prepare ${step} exited ${run.status}: ${run.stderr.trim()}`);
	assert.equal(run.json.action, "prepared", `prepare ${step} answered ${run.json.action}: ${run.json.message || ""}`);
	return run.json;
};
// The developer's side of the repository: HEAD, its commit, every ref but the loop's, and the
// number of commits on HEAD.
function refsOf(dir) {
	return {
		head: git(dir, "symbolic-ref", "HEAD").trim(),
		commit: git(dir, "rev-parse", "HEAD").trim(),
		refs: git(dir, "for-each-ref", "--format=%(refname) %(objectname)").split("\n").filter((line) => line && !line.startsWith("refs/heads/t4-loop/")),
		count: git(dir, "rev-list", "--count", "HEAD").trim(),
	};
}
// The main tree as the developer sees it: status (no optional locks, so status itself writes
// nothing), the content digest and the index bytes.
function mainTree(dir) {
	const status = execFileSync("git", ["--no-optional-locks", "status", "--porcelain=v1", "-z", "--untracked-files=all"], { cwd: dir, env: ENV, stdio: "pipe" }).toString();
	const { tree, index } = fingerprint(dir);
	return { status, tree, index };
}
// Every path the main tree's snapshot covers, tracked or untracked-and-not-ignored, from its root.
function snapshotPaths(dir) {
	const tracked = git(dir, "ls-files", "-z").split("\0").filter(Boolean);
	const untracked = git(dir, "ls-files", "--others", "--exclude-standard", "-z").split("\0").filter(Boolean);
	return [...new Set([...tracked, ...untracked, ...git(dir, "ls-tree", "-r", "-z", "--name-only", "HEAD").split("\0").filter(Boolean)])].sort();
}
const bytesOf = (file) => (fs.existsSync(file) ? fs.readFileSync(file) : null);

test("worktree", "worktree-location-branch", () => {
	const { dir, loopId } = startedPair("wt-location");
	const head = git(dir, "rev-parse", "HEAD").trim();
	const seen = new Set();
	for (const step of [2, 3]) {
		const got = expectPrepared(dir, loopId, step);
		const rel = `ai-factory/runs/tmp/worktrees/${loopId}-S${step}`;
		const branch = `t4-loop/${loopId}/S${step}`;
		assert.equal(got.worktree, rel, `Step ${step}'s worktree is not under ai-factory/runs/tmp/worktrees/`);
		assert.equal(got.branch, branch);
		assert.ok(fs.existsSync(path.join(dir, rel, ".git")), `${rel} is not a git worktree`);
		const listed = git(dir, "worktree", "list", "--porcelain");
		assert.ok(listed.includes(`worktree ${fs.realpathSync(path.join(dir, rel))}\n`), `git does not list ${rel} as a worktree`);
		assert.ok(listed.includes(`branch refs/heads/${branch}\n`), `${branch} is not checked out in a worktree`);
		assert.equal(git(dir, "rev-parse", `refs/heads/${branch}`).trim(), head, `${branch} was not created from HEAD`);
		assert.equal(git(path.join(dir, rel), "rev-parse", "HEAD").trim(), head, `the worktree's HEAD is not the main tree's HEAD`);
		assert.equal(git(path.join(dir, rel), "symbolic-ref", "HEAD").trim(), `refs/heads/${branch}`);
		seen.add(rel);
		const entry = readLoopState(dir, loopId).running.find((running) => running.step === step);
		assert.equal(entry.worktree, rel, "the state does not record the worktree");
		assert.equal(entry.branch, branch);
		assert.equal(entry.head, head);
	}
	assert.equal(seen.size, 2, "the two steps share a worktree");
	// Only a running worktree step is prepared, and only once.
	assert.equal(cli(dir, "prepare", loopId, "2").status, 2, "a step was prepared twice");
	assert.equal(cli(dir, "prepare", loopId, "4").status, 2, "a step that is not running was prepared");
	const lone = repo("wt-main", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const started = expectStarted(lone, ["0001"]).json.loop_id;
	assert.deepEqual(cli(lone, "next", started).json.steps, [{ number: 2, mode: "main" }]);
	const refused = cli(lone, "prepare", started, "2");
	assert.equal(refused.status, 2, "a main-tree step was given a worktree");
	assert.match(refused.json.message, /main tree/);
	assert.ok(!fs.existsSync(path.join(lone, "ai-factory/runs/tmp/worktrees")), "a worktree directory exists for a main-tree step");
	assert.equal(cli(dir, "prepare", "not-a-loop", "2").status, 2);
});
test("worktree", "snapshot-complete", () => {
	const binary = (seed) => Buffer.from([0, 1, 2, 255, 254, seed, 0, 10, 13, 0]);
	const { dir, loopId } = (() => {
		preparer();
		const fixture = repo("wt-snapshot", {
			"ai-factory/plans/0001-parallel.md": PARALLEL,
			".gitignore": "*.ignored\n",
			"gone.txt": "deleted, unstaged\n",
			"removed.txt": "deleted, staged\n",
			"kept.txt": "staged only\n",
			"nested/deep.txt": "deep\n",
		});
		fs.writeFileSync(path.join(fixture, "image.bin"), binary(1));
		git(fixture, "add", "image.bin");
		git(fixture, "commit", "-q", "-m", "binary");
		// Every kind of uncommitted work (repo() already left src.txt staged and unstaged, and
		// untracked.txt untracked).
		fs.rmSync(path.join(fixture, "gone.txt"));
		git(fixture, "rm", "-q", "removed.txt");
		fs.writeFileSync(path.join(fixture, "kept.txt"), "staged only\nchanged\n");
		git(fixture, "add", "kept.txt");
		fs.writeFileSync(path.join(fixture, "image.bin"), binary(2));
		fs.writeFileSync(path.join(fixture, "nested/deep.txt"), "deep\nunstaged\n");
		fs.mkdirSync(path.join(fixture, "fresh/inner"), { recursive: true });
		fs.writeFileSync(path.join(fixture, "fresh/inner/new.bin"), binary(3));
		fs.writeFileSync(path.join(fixture, "secret.ignored"), "ignored\n");
		fs.writeFileSync(path.join(fixture, "nested/also.ignored"), "ignored\n");
		const { json } = expectStarted(fixture, ["0001"]);
		cli(fixture, "next", json.loop_id);
		return { dir: fixture, loopId: json.loop_id };
	})();
	const got = expectPrepared(dir, loopId, 2);
	const tree = path.join(dir, got.worktree);
	for (const rel of snapshotPaths(dir)) {
		if (rel.startsWith("ai-factory/runs/")) continue;
		const main = bytesOf(path.join(dir, rel));
		const copy = bytesOf(path.join(tree, rel));
		assert.ok(main === null ? copy === null : copy !== null && main.equals(copy), `${rel} differs between the main tree and the worktree`);
	}
	for (const rel of ["gone.txt", "removed.txt"]) assert.ok(!fs.existsSync(path.join(tree, rel)), `the deletion of ${rel} is not in the worktree`);
	assert.deepEqual(bytesOf(path.join(tree, "image.bin")), binary(2), "the binary change is not in the worktree");
	assert.deepEqual(bytesOf(path.join(tree, "fresh/inner/new.bin")), binary(3), "an untracked binary file is not in the worktree");
	assert.equal(bytesOf(path.join(tree, "src.txt")).toString(), "base\nstaged\nunstaged\n");
	assert.equal(bytesOf(path.join(tree, "untracked.txt")).toString(), "new\n");
	for (const rel of ["secret.ignored", "nested/also.ignored"]) assert.ok(!fs.existsSync(path.join(tree, rel)), `the ignored ${rel} was copied`);
	assert.ok(!fs.existsSync(path.join(tree, "ai-factory/runs/tmp")), "the loop's own scratch was copied into the worktree");
	assert.equal(git(tree, "diff", "--cached", "--name-only").trim(), "", "something is staged in the worktree");
	assert.equal(git(tree, "rev-parse", "HEAD").trim(), git(dir, "rev-parse", "HEAD").trim(), "the snapshot was committed in prepare");
	assert.deepEqual(got.untracked, ["fresh/inner/new.bin", "untracked.txt"], "prepare does not report the untracked files it copied");
	// A clean main tree gives a clean worktree.
	const clean = repo("wt-clean", { "ai-factory/plans/0001-parallel.md": PARALLEL });
	git(clean, "add", "-A");
	git(clean, "commit", "-q", "-m", "clean");
	const id = expectStarted(clean, ["0001"]).json.loop_id;
	cli(clean, "next", id);
	const plain = path.join(clean, expectPrepared(clean, id, 3).worktree);
	assert.equal(git(plain, "status", "--porcelain").trim(), "", "a clean main tree gave a dirty worktree");
});
test("worktree", "snapshot-failure-stops", () => {
	const { dir, loopId } = startedPair("wt-fail");
	const loop = require(path.join(dir, "ai-factory/make/loop.js"));
	const state = readLoopState(dir, loopId);
	const before = { ...mainTree(dir), ...refsOf(dir) };
	const calls = [];
	const failing = (args, options) => {
		calls.push(args[0]);
		if (args[0] === "apply") throw new Error("error: patch failed: src.txt:1 (forced by the fixture)");
		return loop.git(args, options);
	};
	const answer = loop.prepare(state, 2, { root: dir, git: failing });
	assert.ok(calls.includes("apply"), "the snapshot was never applied");
	assert.equal(answer.action, "snapshot-failed", `a failed snapshot answered ${answer.action}`);
	assert.deepEqual(state.causes.map((cause) => [cause.kind, cause.step]), [["snapshot", 2]], "no snapshot cause is recorded for Step 2");
	assert.match(state.causes[0].message, /forced by the fixture/, "the cause does not carry git's message");
	assert.equal(answer.worktree, `ai-factory/runs/tmp/worktrees/${loopId}-S2`, "the report does not give the kept worktree");
	assert.ok(!state.running.some((entry) => entry.step === 2), "the step whose snapshot failed is still running");
	assert.ok(!state.ran.includes(2), "the step whose snapshot failed counts as run");
	assert.equal(state.steps.find((step) => step.number === 2).done, false);
	// No further step starts; Step 3, already running, drains; then the loop stops naming Step 2.
	assert.equal(loop.next(state).action, "wait", "the loop did not wait for the running Step 3");
	assert.deepEqual(loop.finish(state, 3, "met", { dry: true }).applied, [3], "the running step was not brought back");
	const end = loop.next(state);
	assert.equal(end.action, "stop", "the loop did not stop after a failed snapshot");
	assert.deepEqual(end.causes.map((cause) => [cause.kind, cause.step]), [["snapshot", 2]]);
	assert.deepEqual(end.remaining, [2, 4]);
	assert.deepEqual({ ...mainTree(dir), ...refsOf(dir) }, before, "a failed snapshot changed the main tree or the developer's refs");
	// A worktree that cannot be created at all (a branch named t4-loop blocks t4-loop/…) is the same
	// cause, through the CLI with the real git.
	const blocked = startedPair("wt-blocked");
	git(blocked.dir, "branch", "t4-loop");
	const run = cli(blocked.dir, "prepare", blocked.loopId, "3");
	assert.equal(run.status, 0, `a failed snapshot exited ${run.status}: ${run.stderr.trim()}`);
	assert.equal(run.json.action, "snapshot-failed");
	const after = readLoopState(blocked.dir, blocked.loopId);
	assert.deepEqual(after.causes.map((cause) => [cause.kind, cause.step]), [["snapshot", 3]]);
	assert.deepEqual(after.running.map((entry) => entry.step), [2]);
	assert.equal(cli(blocked.dir, "next", blocked.loopId).json.action, "wait");
});
test("worktree", "head-and-branches-unchanged", () => {
	const { dir, loopId } = startedPair("wt-refs");
	git(dir, "branch", "feature/other");
	const before = refsOf(dir);
	for (const step of [2, 3]) expectPrepared(dir, loopId, step);
	assert.deepEqual(refsOf(dir), before, "prepare moved HEAD, a branch of the developer's or committed outside the loop's branches");
	const loopBranches = git(dir, "for-each-ref", "--format=%(refname)", "refs/heads/t4-loop/").trim().split("\n");
	assert.deepEqual(loopBranches, [`refs/heads/t4-loop/${loopId}/S2`, `refs/heads/t4-loop/${loopId}/S3`], "prepare created a branch other than the step's own");
	assert.equal(git(dir, "rev-list", "--count", `HEAD..t4-loop/${loopId}/S2`).trim(), "0", "prepare committed on the loop branch");
});
test("worktree", "main-tree-not-reset", () => {
	const { dir, loopId } = startedPair("wt-reset");
	const before = mainTree(dir);
	assert.ok(before.status.length > 0, "the fixture main tree is not dirty");
	for (const step of [2, 3]) expectPrepared(dir, loopId, step);
	const after = mainTree(dir);
	assert.equal(after.status, before.status, "the main tree's status changed");
	assert.equal(after.tree, before.tree, "the main tree's content changed");
	assert.equal(after.index, before.index, "the main tree's index changed");
	assert.equal(fs.readFileSync(path.join(dir, "src.txt"), "utf8"), "base\nstaged\nunstaged\n");
	assert.equal(git(dir, "diff", "--cached", "--name-only").trim(), "src.txt", "the staged change is gone from the main tree");
});
test("worktree", "gitignore-runs-tmp", () => {
	const lines = fs.readFileSync(path.join(PLUGIN, ".gitignore"), "utf8").split("\n");
	assert.ok(lines.includes("ai-factory/runs/tmp/"), "this repo's root .gitignore does not ignore ai-factory/runs/tmp/");
	const probe = spawnSync("git", ["check-ignore", "-q", "--no-index", "ai-factory/runs/tmp/worktrees/w/src/a.js"], { cwd: PLUGIN, env: ENV });
	assert.equal(probe.status, 0, "git does not ignore a file under ai-factory/runs/tmp/worktrees/");
});

// ---- apply (plan 0022 Step 5; AC28, AC29, AC31, AC32, AC43, AC62–AC64, AC70) -------------
// Real git fixtures: Steps 2 and 3 of PARALLEL run in prepared worktrees, the test plays the
// implementer by writing into a worktree, and `loop.js finish <id> <step> --result …` (no --dry)
// makes the two loop commits and brings the delta back to the main tree.
function finisher() {
	preparer();
	if (typeof require(LOOP).finish !== "function") throw new Error("loop.js exports no finish()");
}
const LINES = Array.from({ length: 20 }, (_, index) => `line ${index + 1}`);
const worktreeDir = (dir, loopId, step) => path.join(dir, `ai-factory/runs/tmp/worktrees/${loopId}-S${step}`);
const loopBranch = (loopId, step) => `t4-loop/${loopId}/S${step}`;
const branchExists = (dir, branch) => spawnSync("git", ["rev-parse", "--verify", "-q", `refs/heads/${branch}`], { cwd: dir, env: ENV }).status === 0;
const indexDigest = (dir) => crypto.createHash("sha256").update(fs.readFileSync(path.join(dir, ".git/index"))).digest("hex");
function editLine(file, number, text) {
	const lines = fs.readFileSync(file, "utf8").split("\n");
	lines[number - 1] = text;
	fs.writeFileSync(file, lines.join("\n"));
}
// A started loop with Steps 2 and 3 prepared in their worktrees; `setup(dir)` runs before start.
function preparedPair(name, files = {}, setup = null) {
	finisher();
	const dir = repo(name, { "ai-factory/plans/0001-parallel.md": PARALLEL, "lines.txt": LINES, ...files });
	if (setup) setup(dir);
	const { json } = expectStarted(dir, ["0001"]);
	const answer = cli(dir, "next", json.loop_id).json;
	assert.deepEqual(answer.steps, [{ number: 2, mode: "worktree" }, { number: 3, mode: "worktree" }], "the fixture plan did not start two worktree steps");
	for (const step of [2, 3]) expectPrepared(dir, json.loop_id, step);
	return { dir, loopId: json.loop_id, tree: (step) => worktreeDir(dir, json.loop_id, step) };
}
// `finish` through the CLI, without --dry.
function finishStep(dir, loopId, step, result = "met") {
	const run = cli(dir, "finish", loopId, String(step), "--result", result);
	assert.equal(run.status, 0, `finish ${step} --result ${result} exited ${run.status}: ${run.json.message || run.stderr.trim()}`);
	assert.equal(run.json.action, "finished", `finish ${step} answered ${run.json.action}`);
	return run.json;
}
const applyOf = (answer, step) => (answer.applies || []).find((entry) => entry.step === step);
const planText = (dir) => fs.readFileSync(path.join(dir, "ai-factory/plans/0001-parallel.md"), "utf8");
const tickedIn = (text, step) => new RegExp(`^- \\[x\\] Step ${step} `, "m").test(text);

test("apply", "two-loop-commits", () => {
	const sentinel = path.join(SCRATCH, `loop-hook-sentinel-${process.pid}`);
	fs.rmSync(sentinel, { force: true });
	fixtures.push(sentinel);
	const { dir, loopId, tree } = preparedPair("ap-commits", {}, (fixture) => {
		// The developer's hooks and signing: any of them running writes the sentinel.
		const hook = `#!/bin/sh\necho ran >> '${sentinel}'\nexit 1\n`;
		for (const name of ["pre-commit", "commit-msg", "prepare-commit-msg", "post-commit", "post-checkout", "reference-transaction"]) {
			fs.writeFileSync(path.join(fixture, ".git/hooks", name), hook, { mode: 0o755 });
			fs.mkdirSync(path.join(fixture, ".git/devhooks"), { recursive: true });
			fs.writeFileSync(path.join(fixture, ".git/devhooks", name), hook, { mode: 0o755 });
		}
		fs.writeFileSync(path.join(fixture, ".git/gpg-sentinel.sh"), hook, { mode: 0o755 });
		git(fixture, "config", "commit.gpgsign", "true");
		git(fixture, "config", "gpg.program", path.join(fixture, ".git/gpg-sentinel.sh"));
	});
	fs.rmSync(sentinel, { force: true });
	git(dir, "config", "core.hooksPath", path.join(dir, ".git/devhooks"));
	const head = git(dir, "rev-parse", "HEAD").trim();
	// Step 2 changes nothing; Step 3 adds one file.
	fs.writeFileSync(path.join(tree(3), "three.txt"), "three\n");
	for (const step of [2, 3]) {
		const branch = loopBranch(loopId, step);
		const answer = finishStep(dir, loopId, step);
		assert.ok(answer.baseline && answer.commit, `finish ${step} does not report its baseline and step commits`);
		assert.equal(git(dir, "rev-list", "--count", `${head}..${answer.commit}`).trim(), "2", `Step ${step}'s branch does not hold exactly two new commits`);
		assert.equal(git(dir, "rev-parse", `${answer.commit}^`).trim(), answer.baseline, "the step commit does not sit on the baseline");
		assert.equal(git(dir, "rev-parse", `${answer.baseline}^`).trim(), head, "the baseline does not sit on HEAD");
		for (const sha of [answer.baseline, answer.commit]) {
			assert.equal(git(dir, "log", "-1", "--format=%an <%ae>|%cn <%ce>", sha).trim(), "t4-loop <t4-loop@invalid>|t4-loop <t4-loop@invalid>", "a loop commit is not the loop's");
			assert.equal(git(dir, "cat-file", "-p", sha).includes("gpgsig"), false, "a loop commit is signed");
		}
		// The baseline holds the snapshot: exactly the main tree's uncommitted work.
		assert.deepEqual(git(dir, "diff", "--name-only", head, answer.baseline).split("\n").filter(Boolean), ["src.txt", "untracked.txt"], "the baseline commit is not the snapshot");
		assert.equal(git(dir, "show", `${answer.baseline}:src.txt`), "base\nstaged\nunstaged\n");
		const own = git(dir, "diff", "--name-only", answer.baseline, answer.commit).split("\n").filter(Boolean);
		assert.deepEqual(own, step === 2 ? [] : ["three.txt"], `Step ${step}'s commit does not hold exactly the implementer's changes`);
		assert.equal(branchExists(dir, branch), false, `${branch} survived a clean apply`);
	}
	assert.ok(!fs.existsSync(sentinel), `a hook or signing program of the developer's ran: ${fs.existsSync(sentinel) ? fs.readFileSync(sentinel, "utf8").trim() : ""}`);
});
test("apply", "plain-apply-own-delta-only", () => {
	const { dir, loopId, tree } = preparedPair("ap-own");
	const before = { index: indexDigest(dir), staged: git(dir, "diff", "--cached", "--binary") };
	fs.appendFileSync(path.join(tree(2), "src.txt"), "step2\n");
	fs.writeFileSync(path.join(tree(2), "two.bin"), Buffer.from([0, 1, 2, 3, 0, 255]));
	editLine(path.join(tree(3), "lines.txt"), 15, "fifteen");
	fs.rmSync(path.join(tree(3), "untracked.txt"));
	const two = finishStep(dir, loopId, 2);
	assert.equal((applyOf(two, 2) || {}).apply, "plain", "Step 2 was not applied with plain git apply");
	const three = finishStep(dir, loopId, 3);
	assert.equal((applyOf(three, 3) || {}).apply, "plain", "Step 3 was not applied with plain git apply");
	assert.equal(fs.readFileSync(path.join(dir, "src.txt"), "utf8"), "base\nstaged\nunstaged\nstep2\n", "the snapshot came back a second time, or the step's change is missing");
	assert.deepEqual(fs.readFileSync(path.join(dir, "two.bin")), Buffer.from([0, 1, 2, 3, 0, 255]), "a binary file the step added is not in the main tree");
	assert.equal(fs.readFileSync(path.join(dir, "lines.txt"), "utf8").split("\n")[14], "fifteen");
	assert.ok(!fs.existsSync(path.join(dir, "untracked.txt")), "a deletion the step made is not in the main tree");
	assert.equal(indexDigest(dir), before.index, "a plain apply changed the index");
	assert.equal(git(dir, "diff", "--cached", "--binary"), before.staged, "a plain apply changed what is staged");
	assert.equal(git(dir, "ls-files", "--others", "--exclude-standard").includes("two.bin"), true, "the added file is not left untracked");
});
test("apply", "tick-cleanup", () => {
	const { dir, loopId, tree } = preparedPair("ap-tick");
	const original = planText(dir);
	fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
	const answer = finishStep(dir, loopId, 2);
	assert.deepEqual(answer.ticked, [2], "finish does not report Step 2 as ticked");
	const text = planText(dir);
	assert.ok(tickedIn(text, 2), "Step 2 is not ticked in the main tree's plan");
	assert.equal(text, original.replace("- [ ] Step 2 ", "- [x] Step 2 "), "ticking changed more of the plan than Step 2's box");
	assert.ok(!fs.existsSync(tree(2)), "Step 2's worktree was not removed");
	assert.ok(!git(dir, "worktree", "list", "--porcelain").includes(`${loopId}-S2`), "git still lists Step 2's worktree");
	assert.equal(branchExists(dir, loopBranch(loopId, 2)), false, "Step 2's temporary branch was not deleted");
	assert.ok(fs.existsSync(tree(3)) && branchExists(dir, loopBranch(loopId, 3)), "Step 3's still-running worktree or branch was touched");
	const state = readLoopState(dir, loopId);
	assert.equal(state.steps.find((step) => step.number === 2).done, true, "the state does not record Step 2 as done");
	assert.deepEqual(state.running.map((entry) => entry.step), [3]);
	// Step 3 then comes back too, and the next step (4, which waits for all earlier) runs alone.
	finishStep(dir, loopId, 3);
	assert.ok(tickedIn(planText(dir), 3), "Step 3 is not ticked");
	assert.ok(!fs.existsSync(path.join(dir, "ai-factory/runs/tmp/worktrees", `${loopId}-S3`)));
	assert.deepEqual(cli(dir, "next", loopId).json.steps, [{ number: 4, mode: "main" }]);
});
test("apply", "index-unchanged-plain", () => {
	const { dir, loopId, tree } = preparedPair("ap-index");
	git(dir, "add", "untracked.txt");
	const staged = git(dir, "diff", "--cached", "--name-only").trim();
	assert.equal(staged, "src.txt\nuntracked.txt", "the fixture has no staged changes");
	const before = indexDigest(dir);
	fs.appendFileSync(path.join(tree(2), "untracked.txt"), "more\n");
	fs.writeFileSync(path.join(tree(3), "three.txt"), "three\n");
	for (const step of [2, 3]) {
		const answer = finishStep(dir, loopId, step);
		assert.equal(applyOf(answer, step).staging_changed, false, `Step ${step}'s apply reports a staging change`);
		assert.equal(indexDigest(dir), before, `Step ${step}'s plain apply changed the index`);
	}
	assert.equal(fs.readFileSync(path.join(dir, "untracked.txt"), "utf8"), "new\nmore\n");
	assert.equal(git(dir, "diff", "--cached", "--name-only").trim(), staged);
});
test("apply", "threeway-clean", () => {
	const { dir, loopId, tree } = preparedPair("ap-3way");
	editLine(path.join(tree(2), "lines.txt"), 10, "ten (step 2)");
	// After the snapshot, the main tree changes a context line of Step 2's hunk, and stages it, so
	// `git apply --check` fails and `--3way` merges cleanly.
	editLine(path.join(dir, "lines.txt"), 8, "eight (main)");
	git(dir, "add", "lines.txt");
	const before = indexDigest(dir);
	const answer = finishStep(dir, loopId, 2);
	const apply = applyOf(answer, 2);
	assert.equal(apply && apply.apply, "3way", "the --3way fallback was not used");
	assert.equal(apply.staging_changed, true, "the --3way apply does not flag that staging changed");
	assert.ok(tickedIn(planText(dir), 2), "a clean --3way apply did not tick the step");
	assert.ok(!fs.existsSync(tree(2)), "a clean --3way apply kept the worktree");
	const lines = fs.readFileSync(path.join(dir, "lines.txt"), "utf8").split("\n");
	assert.deepEqual([lines[7], lines[9]], ["eight (main)", "ten (step 2)"], "the --3way apply lost one side");
	assert.notEqual(indexDigest(dir), before, "the fixture's --3way apply did not touch the index");
	assert.deepEqual(answer.causes, [], "a clean --3way apply recorded a stop cause");
	const notes = readLoopState(dir, loopId).notes.join("\n");
	assert.match(notes, /Step 2\b.*--3way.*staging/, "the state's notes do not say Step 2 used --3way and changed staging");
});
test("apply", "no-staging-note-plain", () => {
	const { dir, loopId, tree } = preparedPair("ap-nonote");
	fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
	const applies = [];
	for (const step of [2, 3]) applies.push(...finishStep(dir, loopId, step).applies);
	assert.deepEqual(applies.map((entry) => [entry.step, entry.apply, entry.staging_changed]), [[2, "plain", false], [3, "none", false]]);
	// Step 4 runs alone in the main tree and its implementer ticks it, as under /t4:run.
	assert.deepEqual(cli(dir, "next", loopId).json.steps, [{ number: 4, mode: "main" }]);
	fs.writeFileSync(path.join(dir, "ai-factory/plans/0001-parallel.md"), planText(dir).replace("- [ ] Step 4 ", "- [x] Step 4 "));
	finishStep(dir, loopId, 4);
	assert.equal(cli(dir, "next", loopId).json.action, "review");
	const state = readLoopState(dir, loopId);
	assert.ok(!/staging/i.test(state.notes.join("\n")), `a run of plain applies notes a staging change: ${state.notes.join(" | ")}`);
	assert.ok(!JSON.stringify(state).includes('"staging_changed":true'), "a run of plain applies records a staging change");
});
test("apply", "threeway-conflict", () => {
	const { dir, loopId, tree } = preparedPair("ap-conflict");
	editLine(path.join(tree(2), "lines.txt"), 10, "ten (step 2)");
	editLine(path.join(dir, "lines.txt"), 10, "ten (main)");
	git(dir, "add", "lines.txt");
	fs.writeFileSync(path.join(tree(3), "three.txt"), "three\n");
	const original = planText(dir);
	const answer = finishStep(dir, loopId, 2);
	assert.deepEqual(answer.ticked, [], "a conflicting step was ticked");
	assert.equal(planText(dir), original, "a conflict changed the plan");
	const [cause] = answer.causes;
	assert.ok(cause, "a conflict recorded no stop cause");
	assert.deepEqual([cause.kind, cause.step], ["conflict", 2]);
	assert.deepEqual(cause.files, ["lines.txt"], "the files with conflict markers are not listed");
	assert.equal(cause.worktree, `ai-factory/runs/tmp/worktrees/${loopId}-S2`, "the cause does not give the kept worktree");
	assert.match(fs.readFileSync(path.join(dir, "lines.txt"), "utf8"), /^<<<<<<< /m, "the fixture left no conflict markers");
	assert.ok(fs.existsSync(tree(2)) && branchExists(dir, loopBranch(loopId, 2)), "the conflicting step's worktree or branch was removed");
	// No new step starts; the running Step 3 finishes and comes back; then the loop stops.
	assert.equal(cli(dir, "next", loopId).json.action, "wait");
	const three = finishStep(dir, loopId, 3);
	assert.deepEqual(three.applied, [3], "the running step did not come back after the conflict");
	assert.ok(tickedIn(planText(dir), 3) && !tickedIn(planText(dir), 2));
	const end = cli(dir, "next", loopId).json;
	assert.equal(end.action, "stop");
	assert.deepEqual(end.causes.map((entry) => [entry.kind, entry.step]), [["conflict", 2]]);
});
test("apply", "threeway-refused", () => {
	const { dir, loopId, tree } = preparedPair("ap-refused");
	editLine(path.join(tree(2), "lines.txt"), 10, "ten (step 2)");
	fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
	// An unstaged main-tree edit in a touched file: --3way refuses without writing markers.
	editLine(path.join(dir, "lines.txt"), 8, "eight (main, unstaged)");
	const original = planText(dir);
	const before = fingerprint(dir);
	const answer = finishStep(dir, loopId, 2);
	assert.deepEqual(fingerprint(dir), before, "a refused apply changed the main tree's files or index");
	assert.equal(planText(dir), original, "a refused apply ticked the step");
	assert.deepEqual(answer.ticked, []);
	const [cause] = answer.causes;
	assert.ok(cause, "a refused apply recorded no stop cause");
	assert.deepEqual([cause.kind, cause.step], ["refused", 2]);
	assert.deepEqual(cause.files, ["lines.txt", "two.txt"], "the refused apply does not name the touched files");
	assert.match(cause.message, /refused/, "the cause does not say the apply was refused");
	assert.equal(cause.worktree, `ai-factory/runs/tmp/worktrees/${loopId}-S2`);
	assert.ok(fs.existsSync(tree(2)) && branchExists(dir, loopBranch(loopId, 2)), "the refused step's worktree was removed");
	assert.ok(!fs.existsSync(path.join(dir, "two.txt")), "part of a refused apply landed");
	assert.equal(cli(dir, "next", loopId).json.action, "wait", "a new step could start after a refused apply");
});
test("apply", "plan-file-excluded", () => {
	const { dir, loopId, tree } = preparedPair("ap-plan");
	const original = planText(dir);
	const worktreePlan = path.join(tree(2), "ai-factory/plans/0001-parallel.md");
	fs.writeFileSync(worktreePlan, fs.readFileSync(worktreePlan, "utf8").replace("- [ ] Step 2 ", "- [x] Step 2 ").replace("- [ ] Step 4 ", "- [x] Step 4 ") + "\nAn implementer's note.\n");
	fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
	const answer = finishStep(dir, loopId, 2);
	assert.equal(planText(dir), original.replace("- [ ] Step 2 ", "- [x] Step 2 "), "the implementer's plan edit reached the main tree");
	assert.ok(fs.existsSync(path.join(dir, "two.txt")), "the step's own change did not come back");
	assert.equal(applyOf(answer, 2).apply, "plain");
	// A delta that touches nothing but the plan applies nothing, and still ticks.
	fs.writeFileSync(path.join(tree(3), "ai-factory/plans/0001-parallel.md"), "# rewritten\n");
	const three = finishStep(dir, loopId, 3);
	assert.equal(applyOf(three, 3).apply, "none");
	assert.equal(planText(dir), original.replace("- [ ] Step 2 ", "- [x] Step 2 ").replace("- [ ] Step 3 ", "- [x] Step 3 "));
});
test("apply", "no-commit-main", () => {
	const { dir, loopId, tree } = preparedPair("ap-nocommit", {}, (fixture) => git(fixture, "branch", "feature/other"));
	const before = refsOf(dir);
	const status = mainTree(dir).status;
	fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
	fs.writeFileSync(path.join(tree(3), "three.txt"), "three\n");
	for (const step of [2, 3]) finishStep(dir, loopId, step);
	assert.deepEqual(refsOf(dir), before, "a full apply moved HEAD, a branch of the developer's or committed on it");
	assert.equal(git(dir, "for-each-ref", "--format=%(refname)", "refs/heads/t4-loop/").trim(), "", "a loop branch survived its clean apply");
	assert.equal(git(dir, "worktree", "list", "--porcelain").split("\n").filter((line) => line.startsWith("worktree ")).length, 1, "a worktree survived its clean apply");
	const entries = (text) => text.split("\0").filter(Boolean).sort();
	assert.deepEqual(entries(mainTree(dir).status), entries(status).concat([" M ai-factory/plans/0001-parallel.md", "?? three.txt", "?? two.txt"]).sort(), `the main tree's status is not its earlier status plus the ticks and the steps' new files: ${JSON.stringify(entries(mainTree(dir).status))} vs ${JSON.stringify(entries(status))}`);
	assert.equal(fs.readFileSync(path.join(dir, "src.txt"), "utf8"), "base\nstaged\nunstaged\n", "the main tree's earlier work is gone");
	assert.equal(git(dir, "diff", "--cached", "--name-only").trim(), "src.txt");
});
test("apply", "main-step-checkbox-read", () => {
	// A main-tree step that reports its phase met is done only when its implementer ticked it.
	finisher();
	const dir = repo("ap-main", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const id = expectStarted(dir, ["0001"]).json.loop_id;
	assert.deepEqual(cli(dir, "next", id).json.steps, [{ number: 2, mode: "main" }]);
	const answer = finishStep(dir, id, 2);
	assert.deepEqual(answer.ticked, [], "an unticked main-tree step counts as done");
	assert.deepEqual(answer.causes.map((cause) => [cause.kind, cause.step]), [["failed", 2]], "an unticked main-tree step is not a failure");
	const other = repo("ap-main-ticked", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const started = expectStarted(other, ["0001"]).json.loop_id;
	cli(other, "next", started);
	const file = path.join(other, "ai-factory/plans/0001-legacy.md");
	fs.writeFileSync(file, fs.readFileSync(file, "utf8").replace("- [ ] Step 2 ", "- [x] Step 2 "));
	const ticked = finishStep(other, started, 2);
	assert.deepEqual([ticked.ticked, ticked.causes], [[2], []]);
	assert.deepEqual(cli(other, "next", started).json.steps, [{ number: 3, mode: "main" }]);
});
test("apply", "worktree-switched-to-dev-branch", () => {
	// ADR ETT683: nothing is ever committed on the developer's branch. A worktree switched onto
	// it (its HEAD SHA unchanged), or one whose .git file is pointed at the main git dir, must
	// fail the step with the developer's ref, HEAD and index untouched and the worktree kept.
	const { dir, loopId, tree } = preparedPair("ap-switched");
	fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
	fs.writeFileSync(path.join(tree(3), "three.txt"), "three\n");
	git(tree(2), "checkout", "--quiet", "--ignore-other-worktrees", "main");
	fs.writeFileSync(path.join(tree(3), ".git"), `gitdir: ${path.join(fs.realpathSync(dir), ".git")}\n`);
	const before = { refs: refsOf(dir), index: indexDigest(dir), main: git(dir, "rev-parse", "refs/heads/main").trim() };
	const original = planText(dir);
	for (const step of [2, 3]) {
		const answer = finishStep(dir, loopId, step);
		assert.deepEqual(refsOf(dir), before.refs, `finish ${step} moved HEAD, the developer's branch or a ref of theirs`);
		assert.equal(git(dir, "rev-parse", "refs/heads/main").trim(), before.main, `finish ${step} committed on the developer's branch`);
		assert.equal(indexDigest(dir), before.index, `finish ${step} wrote the main index`);
		const cause = answer.causes.find((entry) => entry.step === step);
		assert.ok(cause, `finish ${step} recorded no stop cause`);
		assert.equal(cause.kind, "failed", `finish ${step} recorded ${cause.kind}, not failed`);
		assert.equal(cause.worktree, `ai-factory/runs/tmp/worktrees/${loopId}-S${step}`, `finish ${step} does not name the kept worktree`);
		assert.ok(fs.existsSync(tree(step)), `Step ${step}'s worktree was removed`);
		assert.deepEqual(answer.ticked, [], `finish ${step} ticked a step`);
	}
	assert.equal(planText(dir), original, "the plan changed");
	assert.ok(!fs.existsSync(path.join(dir, "two.txt")) && !fs.existsSync(path.join(dir, "three.txt")), "a step's delta came back");
	assert.equal(git(dir, "rev-list", "--count", "HEAD").trim(), before.refs.count);
});
test("apply", "concurrent-finish-no-lost-update", () => {
	// Two finish calls at once, as separate processes: the state lock serialises them, so neither
	// result is lost and the git apply and tick work never interleave.
	const { dir, loopId, tree } = preparedPair("ap-concurrent");
	fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
	fs.writeFileSync(path.join(tree(3), "three.txt"), "three\n");
	const both = spawnSync(
		"bash",
		["-c", 'node ai-factory/make/loop.js finish "$1" 2 --result met > finish-2.json & node ai-factory/make/loop.js finish "$1" 3 --result met > finish-3.json & wait', "concurrent", loopId],
		{ cwd: dir, encoding: "utf8", env: ENV },
	);
	assert.equal(both.status, 0, `the concurrent finishes failed: ${both.stderr}`);
	for (const step of [2, 3]) {
		const answer = JSON.parse(fs.readFileSync(path.join(dir, `finish-${step}.json`), "utf8"));
		assert.equal(answer.action, "finished", `finish ${step} answered ${answer.action}: ${answer.message || ""}`);
	}
	const state = readLoopState(dir, loopId);
	assert.deepEqual(state.running, [], `a finished step is still recorded as running: ${JSON.stringify(state.running)}`);
	assert.deepEqual(state.pending, [], `a finished step is still waiting to be applied: ${JSON.stringify(state.pending)}`);
	assert.deepEqual(state.steps.filter((step) => step.done).map((step) => step.number), [1, 2, 3], "a finished step is not recorded as done");
	assert.deepEqual(state.finished.map((entry) => entry.step).sort(), [2, 3], "a finish record was lost");
	assert.ok(tickedIn(planText(dir), 2) && tickedIn(planText(dir), 3), "a tick was lost");
	assert.ok(fs.existsSync(path.join(dir, "two.txt")) && fs.existsSync(path.join(dir, "three.txt")), "a step's delta was lost");
	assert.ok(!fs.existsSync(path.join(dir, "ai-factory/runs/tmp/loop", loopId, "state.lock")), "the state lock was left behind");
});
test("apply", "state-lock-held-and-stale", () => {
	finisher();
	const dir = repo("ap-lock", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const loopId = expectStarted(dir, ["0001"]).json.loop_id;
	const lock = path.join(dir, "ai-factory/runs/tmp/loop", loopId, "state.lock");
	// Held by a live process: next waits until it is released, then runs.
	const held = spawnSync(
		"bash",
		[
			"-c",
			'printf \'{"pid":%s}\' "$$" > "$2"; node ai-factory/make/loop.js next "$1" > next.json & sleep 1; node -e \'process.stdout.write(JSON.stringify(require(process.argv[1]).running))\' "$PWD/$3" > running.json; rm -f "$2"; wait',
			"held",
			loopId,
			lock,
			path.relative(dir, path.join(dir, "ai-factory/runs/tmp/loop", loopId, "state.json")),
		],
		{ cwd: dir, encoding: "utf8", env: ENV },
	);
	assert.equal(held.status, 0, `the held-lock run failed: ${held.stderr}`);
	assert.equal(fs.readFileSync(path.join(dir, "running.json"), "utf8"), "[]", "next changed the state while another process held its lock");
	assert.equal(JSON.parse(fs.readFileSync(path.join(dir, "next.json"), "utf8")).action, "start", "next did not run once the lock was released");
	assert.deepEqual(readLoopState(dir, loopId).running.map((entry) => entry.step), [2]);
	// Left by a process that died: reclaimed, and released after use.
	const dead = spawnSync(process.execPath, ["-e", ""]).pid;
	fs.writeFileSync(lock, JSON.stringify({ pid: dead, at: new Date(Date.now() - 3600 * 1000).toISOString() }));
	const old = new Date(Date.now() - 3600 * 1000);
	fs.utimesSync(lock, old, old);
	const run = cli(dir, "finish", loopId, "2", "--result", "failed");
	assert.equal(run.status, 0, `finish under a stale lock exited ${run.status}: ${run.json.message || run.stderr.trim()}`);
	assert.equal(run.json.action, "finished");
	assert.ok(!fs.existsSync(lock), "the stale lock was not reclaimed and released");
	assert.deepEqual(readLoopState(dir, loopId).running, []);
});
test("apply", "touched-path-already-unmerged", () => {
	// A path the delta touches that is already unmerged in the main tree is refused up front,
	// named, with nothing applied, whether or not plain `git apply --check` would pass.
	for (const variant of ["markers", "clean-file"]) {
		const { dir, loopId, tree } = preparedPair(`ap-unmerged-${variant}`);
		editLine(path.join(tree(2), "lines.txt"), 10, "ten (step 2)");
		fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
		const blob = (text) => execFileSync("git", ["hash-object", "-w", "--stdin"], { cwd: dir, env: ENV, input: text }).toString().trim();
		const base = blob(fs.readFileSync(path.join(dir, "lines.txt")));
		const ours = blob(fs.readFileSync(path.join(dir, "lines.txt"), "utf8").replace("line 9\n", "line 9 (ours)\n"));
		const theirs = blob(fs.readFileSync(path.join(dir, "lines.txt"), "utf8").replace("line 9\n", "line 9 (theirs)\n"));
		execFileSync("git", ["update-index", "--index-info"], {
			cwd: dir,
			env: ENV,
			input: `0 ${"0".repeat(40)}\tlines.txt\n100644 ${base} 1\tlines.txt\n100644 ${ours} 2\tlines.txt\n100644 ${theirs} 3\tlines.txt\n`,
		});
		if (variant === "markers")
			editLine(path.join(dir, "lines.txt"), 9, "<<<<<<< ours\nline 9 (ours)\n=======\nline 9 (theirs)\n>>>>>>> theirs");
		const original = planText(dir);
		const before = { files: fingerprint(dir).tree, index: indexDigest(dir), lines: fs.readFileSync(path.join(dir, "lines.txt")) };
		const answer = finishStep(dir, loopId, 2);
		assert.deepEqual(fs.readFileSync(path.join(dir, "lines.txt")), before.lines, `${variant}: the unmerged file was changed`);
		assert.equal(indexDigest(dir), before.index, `${variant}: the index was changed`);
		assert.equal(fingerprint(dir).tree, before.files, `${variant}: the main tree's files changed`);
		assert.ok(!fs.existsSync(path.join(dir, "two.txt")), `${variant}: part of the delta was applied`);
		assert.equal(planText(dir), original, `${variant}: the step was ticked`);
		const cause = answer.causes.find((entry) => entry.step === 2);
		assert.ok(cause, `${variant}: no stop cause was recorded`);
		assert.equal(cause.kind, "refused", `${variant}: recorded ${cause.kind}, not refused`);
		assert.deepEqual(cause.files, ["lines.txt"], `${variant}: the cause does not name exactly the unmerged paths`);
		assert.match(cause.message, /unmerged/, `${variant}: the cause does not say the path is unmerged`);
		assert.equal((applyOf(answer, 2) || {}).apply, "refused");
		assert.ok(fs.existsSync(tree(2)), `${variant}: the worktree was removed`);
	}
});

// ---- outcome (plan 0022 Step 6; AC18, AC19, AC34, AC42, AC45, AC65, AC67–AC69) -------------
// `verdict` takes the reviewer's JSON on stdin; `end` prints the report and writes the outcome
// record that the headless runner maps to its exit code. Real fixtures run through the CLI; the
// cause-order cases drive the fixture's own module, with an injected git runner where a snapshot
// failure has to be forced.
function ender() {
	finisher();
	for (const name of ["end", "verdict"])
		if (typeof require(LOOP)[name] !== "function") throw new Error(`loop.js exports no ${name}()`);
}
// `node ai-factory/make/loop.js <subcommand> …` with stdin and extra environment.
function cliWith(dir, args, { input = "", env = {} } = {}) {
	const run = spawnSync(process.execPath, ["ai-factory/make/loop.js", ...args], { cwd: dir, encoding: "utf8", input, env: { ...ENV, GATE_ENFORCE: "", T4_LOOP_RESULT: "", ...env } });
	let json = null;
	try {
		json = JSON.parse(run.stdout);
	} catch {
		throw new Error(`loop.js ${args.join(" ")} printed no JSON object (exit ${run.status}): ${(run.stdout + run.stderr).trim().split("\n")[0]}`);
	}
	return { status: run.status, json, stderr: run.stderr };
}
const APPROVE = '{ "verdict": "approve",  "summary": "Looks right — ünïcode kept",\n  "findings": [ { "severity": "minor", "file": "a.js", "line": 3, "issue": "nit", "suggestion": "tidy" } ] }\n';
const CHANGES = '{"verdict":"request_changes","summary":"one more test","findings":[{"severity":"major","file":"a.js","line":1,"issue":"untested","suggestion":"add a case"}]}';
const sendVerdict = (dir, loopId, text, env = {}) => {
	const run = cliWith(dir, ["verdict", loopId], { input: text, env });
	assert.equal(run.status, 0, `verdict exited ${run.status}: ${run.stderr.trim()}`);
	assert.equal(run.json.action, "verdict", `verdict answered ${run.json.action}`);
	return run.json;
};
const endLoop = (dir, loopId, env = {}) => {
	const run = cliWith(dir, ["end", loopId], { env });
	assert.equal(run.status, 0, `end exited ${run.status}: ${run.stderr.trim()}`);
	assert.equal(run.json.action, "ended", `end answered ${run.json.action}`);
	return run.json;
};
const tickByHand = (dir, rel, step) => {
	const file = path.join(dir, rel);
	fs.writeFileSync(file, fs.readFileSync(file, "utf8").replace(`- [ ] Step ${step} `, `- [x] Step ${step} `));
};
// Runs a LEGACY plan's main-tree Steps 2 and 3 to the check point, the test playing an implementer
// that ticks each step; `results[N]` overrides a step's result (its box is then left unticked).
function runLegacy(dir, loopId, results = {}) {
	for (const step of [2, 3]) {
		const answer = cli(dir, "next", loopId).json;
		if (answer.action !== "start") return answer;
		assert.deepEqual(answer.steps, [{ number: step, mode: "main" }]);
		const result = results[step] || "met";
		if (result === "met") tickByHand(dir, "ai-factory/plans/0001-legacy.md", step);
		finishStep(dir, loopId, step, result);
	}
	return cli(dir, "next", loopId).json;
}
const outcomeFile = (dir, loopId) => path.join(dir, "ai-factory/runs/tmp/loop", loopId, "outcome.json");
const kinds = (causes) => causes.map((cause) => [cause.kind, cause.step]);

test("outcome", "report-includes-verdict-unchanged", () => {
	ender();
	const dir = repo("oc-verdict", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const loopId = expectStarted(dir, ["0001"]).json.loop_id;
	assert.equal(runLegacy(dir, loopId).action, "review");
	const answer = sendVerdict(dir, loopId, APPROVE);
	assert.equal(answer.approved, true, "a valid approve with no blocker is not approval");
	const end = endLoop(dir, loopId);
	assert.equal(end.verdict.raw, APPROVE, "the reviewer's verdict is not relayed byte for byte");
	assert.ok(end.report.includes(APPROVE.trimEnd()), "the report text does not carry the verdict unchanged");
	assert.deepEqual(end.ran, [2, 3], "the report does not name the steps run in this invocation");
	assert.match(end.report, /Steps run in this invocation: 2, 3\b/);
	assert.deepEqual([end.code, end.causes, end.remaining], [0, [], []]);
	assert.equal(end.no_steps_remained, false);
	const record = JSON.parse(fs.readFileSync(outcomeFile(dir, loopId), "utf8"));
	assert.equal(record.schema, "t4-loop-outcome");
	assert.deepEqual([record.code, record.verdict.raw, record.report], [0, APPROVE, end.report], "the outcome record is not the report end printed");
	// /t4:review runs once: a second verdict is refused.
	const again = cliWith(dir, ["verdict", loopId], { input: APPROVE });
	assert.equal(again.status, 2, "a second verdict was accepted");
});
test("outcome", "state-from-before-review-rename", () => {
	// A loop state written before `check` was renamed `review` carries the old command name only in
	// its recorded cause messages; the helper reads it, relays those messages unchanged and decides
	// the same code. The state has no action field: `next` derives the review point from the steps.
	ender();
	const dir = repo("oc-renamed", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const loopId = expectStarted(dir, ["0001"]).json.loop_id;
	assert.equal(runLegacy(dir, loopId).action, "review");
	sendVerdict(dir, loopId, CHANGES, { GATE_ENFORCE: "1" });
	const file = path.join(dir, "ai-factory/runs/tmp/loop", loopId, "state.json");
	const current = fs.readFileSync(file, "utf8");
	assert.ok(!/"check"/.test(current), "the state records no action name");
	const old = current.replaceAll("/t4:review", "/t4:check");
	assert.notEqual(old, current, "the recorded cause names the review command");
	fs.writeFileSync(file, old);
	const stopped = cli(dir, "next", loopId).json;
	assert.equal(stopped.action, "stop");
	assert.match(stopped.causes[0].message, /^\/t4:check verdict request_changes/);
	const end = endLoop(dir, loopId, { GATE_ENFORCE: "1" });
	assert.equal(end.code, 5, "an old verdict cause no longer stops the loop with 5");
	assert.ok(end.report.includes("/t4:check verdict request_changes, which is not an approval"), "the recorded cause was not relayed unchanged");
	assert.match(end.report, /^\/t4:review verdict, unchanged:$/m, "the report's own lines use the current name");
	// A legacy state at the review point with no verdict yet still answers review and takes one.
	const fresh = repo("oc-renamed-open", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const openId = expectStarted(fresh, ["0001"]).json.loop_id;
	assert.equal(runLegacy(fresh, openId).action, "review");
	assert.deepEqual(cli(fresh, "next", openId).json.action, "review");
	assert.equal(sendVerdict(fresh, openId, APPROVE).approved, true);
	assert.equal(endLoop(fresh, openId).code, 0);
});
test("outcome", "all-ticked-report", () => {
	ender();
	const dir = repo("oc-all", { "ai-factory/plans/0001-done.md": plan("Done", "- [x] Step 1 — A.", "", "- [x] Step 2 — B.") });
	const before = fingerprint(dir);
	const status = mainTree(dir).status;
	const loopId = expectStarted(dir, ["0001"]).json.loop_id;
	assert.deepEqual(cli(dir, "next", loopId).json, { action: "review", ran: [] });
	sendVerdict(dir, loopId, APPROVE);
	const end = endLoop(dir, loopId);
	assert.equal(end.no_steps_remained, true, "the report does not say no steps remained");
	assert.match(end.report, /no steps remained/);
	assert.deepEqual([end.ran, end.code, end.verdict.raw], [[], 0, APPROVE]);
	const after = fingerprint(dir);
	assert.deepEqual([after.tree, after.index], [before.tree, before.index], "a loop with nothing to run changed a file or the index");
	assert.equal(mainTree(dir).status, status, "a loop with nothing to run changed the main tree's status");
	// Everything the loop wrote is its own scratch under runs/tmp/.
	const scratch = fs.readdirSync(path.join(dir, "ai-factory/runs/tmp"));
	assert.deepEqual(scratch, ["loop"]);
	assert.deepEqual(fs.readdirSync(path.join(dir, "ai-factory/runs/tmp/loop", loopId)).sort(), ["outcome.json", "state.json"]);
});
test("outcome", "failure-report", () => {
	ender();
	// A worktree step fails while another applies cleanly.
	const { dir, loopId, tree } = preparedPair("oc-fail-wt");
	const output = path.join(dir, "ai-factory/runs/tmp/implementer-S3.txt");
	fs.writeFileSync(output, "Step 3: the red test still fails\n  expected 2, got 3\n");
	fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
	const failed = cli(dir, "finish", loopId, "3", "--result", "failed", "--output-file", output);
	assert.equal(failed.status, 0, `finish --output-file exited ${failed.status}: ${failed.stderr.trim()}`);
	finishStep(dir, loopId, 2);
	assert.equal(cli(dir, "next", loopId).json.action, "stop");
	const end = endLoop(dir, loopId);
	assert.equal(end.code, 1);
	assert.deepEqual(kinds(end.causes), [["failed", 3]]);
	const [cause] = end.causes;
	assert.equal(cause.output, "Step 3: the red test still fails\n  expected 2, got 3\n", "the failed step's output is not relayed");
	assert.equal(cause.worktree, `ai-factory/runs/tmp/worktrees/${loopId}-S3`, "the report does not give the failed step's worktree");
	assert.ok(fs.existsSync(tree(3)), "the failed step's worktree is gone");
	assert.deepEqual(end.remaining, [3, 4], "the report does not list the steps still unticked");
	assert.deepEqual(end.ticked, [2]);
	for (const text of ["Step 3", "expected 2, got 3", cause.worktree, "Still unticked: 3, 4"])
		assert.ok(end.report.includes(text), `the report text lacks '${text}'`);
	// A main-tree failure: its output is relayed, and no worktree is named.
	const main = repo("oc-fail-main", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const id = expectStarted(main, ["0001"]).json.loop_id;
	cli(main, "next", id);
	const said = path.join(main, "ai-factory/runs/tmp/out.txt");
	fs.writeFileSync(said, "phase not met\n");
	assert.equal(cli(main, "finish", id, "2", "--result", "failed", `--output-file=${said}`).status, 0);
	const stopped = endLoop(main, id);
	assert.deepEqual([stopped.code, kinds(stopped.causes), stopped.remaining], [1, [["failed", 2]], [2, 3]]);
	assert.equal(stopped.causes[0].output, "phase not met\n");
	assert.equal(stopped.causes[0].worktree, undefined, "a main-tree failure names a worktree");
	assert.match(stopped.report, /phase not met/);
});
test("outcome", "main-timeout-partial", () => {
	ender();
	const dir = repo("oc-timeout", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const loopId = expectStarted(dir, ["0001"]).json.loop_id;
	assert.deepEqual(cli(dir, "next", loopId).json.steps, [{ number: 2, mode: "main" }]);
	// The implementer's partial work, on top of the developer's own uncommitted src.txt and
	// untracked.txt, which are not the step's and are not listed.
	fs.appendFileSync(path.join(dir, "src.txt"), "half a change\n");
	fs.mkdirSync(path.join(dir, "lib"));
	fs.writeFileSync(path.join(dir, "lib/partial.js"), "// partial\n");
	const answer = finishStep(dir, loopId, 2, "timeout");
	assert.deepEqual(kinds(answer.causes), [["timeout", 2]]);
	assert.equal(fs.readFileSync(path.join(dir, "src.txt"), "utf8"), "base\nstaged\nunstaged\nhalf a change\n", "the partial change was not left in place");
	assert.ok(fs.existsSync(path.join(dir, "lib/partial.js")));
	const end = endLoop(dir, loopId);
	assert.equal(end.code, 1);
	const [cause] = end.causes;
	assert.equal(cause.partial, true, "a main-tree timeout is not labelled partial");
	assert.deepEqual(cause.files, ["lib/partial.js", "src.txt"], `the partial files are not exactly the step's: ${JSON.stringify(cause)}`);
	assert.match(end.report, /partial/i);
	for (const file of cause.files) assert.ok(end.report.includes(file), `the report does not list ${file}`);
	assert.ok(!/untracked\.txt/.test(end.report), "the developer's own untouched change is listed as the step's");
	// Where nothing ignores ai-factory/runs/tmp/, the loop's own scratch is still not a partial file.
	const bare = repo("oc-timeout-unignored", { "ai-factory/plans/0001-legacy.md": LEGACY, "ai-factory/.gitignore": "" });
	const bareId = expectStarted(bare, ["0001"]).json.loop_id;
	cli(bare, "next", bareId);
	fs.writeFileSync(path.join(bare, "half.txt"), "half\n");
	const bareCause = finishStep(bare, bareId, 2, "timeout").causes[0];
	assert.deepEqual([bareCause.partial, bareCause.files], [true, ["half.txt"]], `an unignored scratch leaks into the partial files: ${JSON.stringify(bareCause)}`);
});
test("outcome", "codex-notes", () => {
	ender();
	const dir = repo("oc-codex", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const loopId = expectStarted(dir, ["0001", "--host", "codex", "--max-parallel", "5", "--step-timeout", "1"]).json.loop_id;
	assert.equal(runLegacy(dir, loopId).action, "review");
	sendVerdict(dir, loopId, APPROVE);
	const end = endLoop(dir, loopId);
	assert.equal(end.code, 0);
	for (const pattern of [/sequential(ly)? on Codex/, /not enforced on Codex/]) {
		assert.ok(end.notes.some((note) => pattern.test(note)), `the outcome notes lack ${pattern}`);
		assert.match(end.report, pattern);
	}
	// Without --max-parallel, the same notes.
	const plain = repo("oc-codex-plain", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const plainId = expectStarted(plain, ["0001", "--host", "codex"]).json.loop_id;
	assert.equal(runLegacy(plain, plainId).action, "review");
	const plainEnd = endLoop(plain, plainId);
	assert.match(plainEnd.report, /sequential(ly)? on Codex/);
	assert.match(plainEnd.report, /not enforced on Codex/);
	// AC65: on Codex a step is never treated as failed for exceeding the timeout.
	const other = repo("oc-codex-timeout", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const id = expectStarted(other, ["0001", "--host", "codex"]).json.loop_id;
	cli(other, "next", id);
	const refused = cli(other, "finish", id, "2", "--result", "timeout");
	assert.equal(refused.status, 2, "a timeout result was accepted on Codex");
	assert.match(refused.json.message, /not enforced on Codex/);
	assert.deepEqual(readLoopState(other, id).causes, []);
	// Claude Code carries neither note.
	const claude = repo("oc-claude", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const claudeId = expectStarted(claude, ["0001"]).json.loop_id;
	runLegacy(claude, claudeId);
	assert.ok(!/Codex/.test(endLoop(claude, claudeId).report), "a Claude Code report carries a Codex note");
});
// A conflict on Step 2 and a failure of Step 3 in either order, through real git.
function conflictAndFailure(name, failFirst) {
	const { dir, loopId, tree } = preparedPair(name);
	editLine(path.join(tree(2), "lines.txt"), 10, "ten (step 2)");
	editLine(path.join(dir, "lines.txt"), 10, "ten (main)");
	git(dir, "add", "lines.txt");
	if (failFirst) finishStep(dir, loopId, 3, "failed");
	finishStep(dir, loopId, 2);
	if (!failFirst) finishStep(dir, loopId, 3, "timeout");
	assert.equal(cli(dir, "next", loopId).json.action, "stop");
	return endLoop(dir, loopId, { GATE_ENFORCE: "1" });
}
test("outcome", "priority-4-over-1", () => {
	ender();
	const conflictFirst = conflictAndFailure("oc-p4-a", false);
	assert.deepEqual(kinds(conflictFirst.causes), [["conflict", 2], ["timeout", 3]]);
	assert.equal(conflictFirst.code, 4, "a conflict then a timeout does not exit 4");
	const failureFirst = conflictAndFailure("oc-p4-b", true);
	assert.deepEqual(kinds(failureFirst.causes), [["failed", 3], ["conflict", 2]]);
	assert.equal(failureFirst.code, 4, "a failure then a conflict does not exit 4");
	// A failed snapshot copy ranks with a conflict, in either order.
	const dir = repo("oc-p4-snap", {});
	const loop = require(path.join(dir, "ai-factory/make/loop.js"));
	const broken = () => {
		throw new Error("fatal: forced by the fixture");
	};
	for (const snapshotFirst of [true, false]) {
		const state = schedState([[1, true, null], [2, false, [1]], [3, false, [1]]]);
		state.loop_id = `loop-20261025T000000Z-00000${snapshotFirst ? 1 : 2}`;
		loop.next(state);
		if (!snapshotFirst) loop.finish(state, 3, "failed", { dry: true });
		assert.equal(loop.prepare(state, 2, { root: dir, git: broken }).action, "snapshot-failed");
		if (snapshotFirst) loop.finish(state, 3, "failed", { dry: true });
		const end = loop.end(state, { root: dir, env: { GATE_ENFORCE: "1" } });
		assert.deepEqual(kinds(end.causes), snapshotFirst ? [["snapshot", 2], ["failed", 3]] : [["failed", 3], ["snapshot", 2]]);
		assert.equal(end.code, 4, "a failed snapshot copy with a failure does not exit 4");
	}
	// A refused --3way apply is a conflict too (AC70).
	const refused = schedState([[1, true, null], [2, false, [1]]]);
	refused.causes.push({ kind: "failed", step: 3 }, { kind: "refused", step: 2, files: ["a"] });
	assert.equal(loop.end(refused, { root: dir, env: {} }).code, 4);
});
test("outcome", "priority-1-over-5", () => {
	ender();
	const dir = repo("oc-p1", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const enforced = { GATE_ENFORCE: "1" };
	const loopId = expectStarted(dir, ["0001"]).json.loop_id;
	assert.equal(runLegacy(dir, loopId, { 3: "failed" }).action, "stop");
	assert.equal(sendVerdict(dir, loopId, CHANGES, enforced).approved, false);
	const end = endLoop(dir, loopId, enforced);
	assert.deepEqual(kinds(end.causes), [["failed", 3], ["verdict", null]]);
	assert.equal(end.code, 1, "a failure with a non-approving verdict under GATE_ENFORCE=1 does not exit 1");
	// The verdict alone: 5 when enforced (AC51), 0 and reported when not (AC52).
	for (const [env, code] of [[enforced, 5], [{}, 0]]) {
		const fresh = repo(`oc-p5-${code}`, { "ai-factory/plans/0001-legacy.md": LEGACY });
		const freshId = expectStarted(fresh, ["0001"]).json.loop_id;
		assert.equal(runLegacy(fresh, freshId).action, "review");
		sendVerdict(fresh, freshId, CHANGES, env);
		const done = endLoop(fresh, freshId, env);
		assert.equal(done.code, code, `a request_changes verdict ${code === 5 ? "with" : "without"} GATE_ENFORCE=1 does not exit ${code}`);
		assert.equal(done.verdict.verdict, "request_changes");
		assert.ok(done.report.includes(CHANGES), "the non-approving verdict is not reported");
	}
});
test("outcome", "causes-in-order", () => {
	ender();
	const dir = repo("oc-order", {});
	const loop = require(path.join(dir, "ai-factory/make/loop.js"));
	const state = schedState([[1, true, null], [2, false, [1]], [3, false, [1]], [4, false, [1]]]);
	state.loop_id = "loop-20261025T000000Z-0000aa";
	assert.deepEqual(loop.next(state).steps.map((step) => step.number), [2, 3, 4]);
	loop.finish(state, 4, "timeout", { dry: true });
	loop.prepare(state, 2, { root: dir, git: () => { throw new Error("fatal: forced by the fixture"); } });
	loop.finish(state, 3, "failed", { dry: true });
	loop.verdict(state, CHANGES, { root: dir, env: { GATE_ENFORCE: "1" } });
	const end = loop.end(state, { root: dir, env: { GATE_ENFORCE: "1" } });
	assert.deepEqual(kinds(end.causes), [["timeout", 4], ["snapshot", 2], ["failed", 3], ["verdict", null]], "the causes are not in the order they happened");
	assert.equal(end.code, 4);
	// The report lists every cause, in that order, each naming its step.
	const lines = end.report.split("\n");
	const at = (pattern) => lines.findIndex((line) => pattern.test(line));
	const order = [/Step 4.*timeout/, /Step 2.*snapshot/, /Step 3.*failed/, /\/t4:review.*verdict/].map(at);
	assert.ok(order.every((index) => index >= 0), `the report does not list every cause: ${JSON.stringify(order)}`);
	assert.deepEqual([...order].sort((a, b) => a - b), order, "the report lists the causes out of order");
});
test("outcome", "verdict-invalid-is-not-approve", () => {
	ender();
	const dir = repo("oc-invalid", {});
	const loop = require(path.join(dir, "ai-factory/make/loop.js"));
	const finished = () => {
		const state = schedState([[1, true, null]]);
		state.loop_id = "loop-20261025T000000Z-0000bb";
		assert.equal(loop.next(state).action, "review");
		return state;
	};
	const blocker = '{"verdict":"approve","summary":"s","findings":[{"severity":"blocker","file":"a","line":1,"issue":"i","suggestion":"s"}]}';
	const cases = [
		["{ not json", false, false],
		["", false, false],
		['{"verdict":"approve"}', false, false],
		['{"verdict":"lgtm","summary":"s","findings":[]}', false, false],
		[blocker, true, false],
		[CHANGES, true, false],
		[APPROVE, true, true],
		["```json\n" + APPROVE.trim() + "\n```", true, true],
	];
	for (const [text, valid, approved] of cases) {
		const enforced = finished();
		const answer = loop.verdict(enforced, text, { root: dir, env: { GATE_ENFORCE: "1" } });
		assert.deepEqual([answer.valid, answer.approved], [valid, approved], `verdict ${JSON.stringify(text)} is read wrongly`);
		const end = loop.end(enforced, { root: dir, env: { GATE_ENFORCE: "1" } });
		assert.equal(end.code, approved ? 0 : 5, `verdict ${JSON.stringify(text)} under GATE_ENFORCE=1 does not exit ${approved ? 0 : 5}`);
		assert.equal(end.verdict.raw, text, "the verdict is not kept unchanged");
		const advisory = finished();
		loop.verdict(advisory, text, { root: dir, env: {} });
		assert.equal(loop.end(advisory, { root: dir, env: {} }).code, 0, "without GATE_ENFORCE=1 the verdict changed the exit code");
	}
	// No verdict at the check point is no approval when the gate is enforced.
	assert.equal(loop.end(finished(), { root: dir, env: { GATE_ENFORCE: "1" } }).code, 5, "a missing verdict counts as approval");
	assert.equal(loop.end(finished(), { root: dir, env: {} }).code, 0);
});
test("outcome", "outcome-record-path", () => {
	ender();
	const dir = repo("oc-record", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const loopId = expectStarted(dir, ["0001"]).json.loop_id;
	runLegacy(dir, loopId);
	sendVerdict(dir, loopId, APPROVE);
	const target = path.join(dir, "ai-factory/runs/tmp/runner-outcome.json");
	const end = endLoop(dir, loopId, { T4_LOOP_RESULT: target });
	assert.equal(end.record, target, "end does not name the record it wrote");
	const record = JSON.parse(fs.readFileSync(target, "utf8"));
	assert.deepEqual([record.schema, record.loop_id, record.code], ["t4-loop-outcome", loopId, 0]);
	assert.ok(!fs.existsSync(outcomeFile(dir, loopId)), "with T4_LOOP_RESULT set, the record also went to the default path");
	// Unset, the record goes beside the state.
	const fallback = endLoop(dir, loopId);
	assert.equal(fallback.record, `ai-factory/runs/tmp/loop/${loopId}/outcome.json`);
	assert.equal(JSON.parse(fs.readFileSync(outcomeFile(dir, loopId), "utf8")).code, 0);
	// A relative T4_LOOP_RESULT is refused rather than guessed at.
	assert.equal(cliWith(dir, ["end", loopId], { env: { T4_LOOP_RESULT: "out.json" } }).status, 2);
	// end refuses before the loop has ended: a step still running, or steps left to start.
	const other = repo("oc-record-running", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const id = expectStarted(other, ["0001"]).json.loop_id;
	assert.equal(cliWith(other, ["end", id]).status, 2, "end ran with steps still to start");
	cli(other, "next", id);
	assert.equal(cliWith(other, ["end", id]).status, 2, "end ran while a step was running");
});

// ---- headless (plan 0022 Step 8; AC11, AC47–AC52, AC67, AC68) -----------------------------
// `node ai-factory/make/runner.js ai` with TASK=loop, in a fixture holding the whole template
// make/ directory and a fixture tasks/loop.md. The host is a fake CLI named by CMD, as in
// check-start-routing.sh: it records that it launched and the prompt it received, then plays a
// session by driving the fixture's real loop.js (`loop` actions, with $ID for the loop ID the
// runner handed it), ticking the plan (`tick`), or writing a scripted outcome record (`record`).
// No model CLI runs.
const FAKE_HOST = `#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
let input = Buffer.alloc(0);
process.stdin.on("data", (chunk) => { input = Buffer.concat([input, chunk]); });
process.stdin.on("end", () => {
	fs.appendFileSync("launched", (process.env.TOOL || "") + "\\n");
	fs.writeFileSync("captured-prompt.txt", input);
	fs.writeFileSync("captured-env.json", JSON.stringify({ id: process.env.T4_LOOP_ID || null, result: process.env.T4_LOOP_RESULT || null }));
	const id = process.env.T4_LOOP_ID;
	for (const act of JSON.parse(process.env.FAKE_SCRIPT || "[]")) {
		if (act.tick) {
			const file = path.join("ai-factory/plans", act.plan);
			fs.writeFileSync(file, fs.readFileSync(file, "utf8").replace("- [ ] Step " + act.tick + " ", "- [x] Step " + act.tick + " "));
		} else if ("exit" in act) {
			process.exitCode = act.exit;
		} else if ("record" in act) {
			fs.writeFileSync(process.env.T4_LOOP_RESULT, typeof act.record === "string" ? act.record : JSON.stringify(act.record).split("$ID").join(id));
		} else {
			const args = act.loop.map((arg) => (arg === "$ID" ? id : arg));
			const run = spawnSync(process.execPath, ["ai-factory/make/loop.js", ...args], { input: act.input || "", encoding: "utf8" });
			if (run.status !== 0) {
				process.stderr.write("fake host: loop.js " + args.join(" ") + " exited " + run.status + ": " + run.stdout + run.stderr);
				process.exitCode = 9;
				return;
			}
		}
	}
	const args = process.argv.slice(2);
	if (args.includes("-o")) fs.writeFileSync(args[args.indexOf("-o") + 1], "done");
	process.stdout.write(JSON.stringify({ session_id: "fixture", result: "done" }));
});
`;
const LOOP_TASK = "fixture loop task\n";
function headlessRepo(name, files) {
	const dir = repo(name, files);
	fs.cpSync(MAKE, path.join(dir, "ai-factory/make"), { recursive: true });
	fs.mkdirSync(path.join(dir, "ai-factory/tasks"), { recursive: true });
	fs.writeFileSync(path.join(dir, "ai-factory/tasks/loop.md"), LOOP_TASK);
	fs.copyFileSync(path.join(PLUGIN, "skills/ai-layout/templates/ai-factory/models.yaml"), path.join(dir, "ai-factory/models.yaml"));
	fs.writeFileSync(path.join(dir, "fake-host"), FAKE_HOST, { mode: 0o700 });
	return dir;
}
// Everything a host or a hook could have inherited is cleared; `env` sets what a case needs.
const headlessEnv = (dir, input, env = {}) => ({
	...ENV,
	TOOL: "claude",
	TASK: "loop",
	CMD: path.join(dir, "fake-host"),
	INPUT: input,
	INPUT_FILE: "",
	MODEL: "",
	GATE_ENFORCE: "",
	T4_LOOP_ID: "",
	T4_LOOP_RESULT: "",
	T4_LIFECYCLE_RUN: "",
	CLAUDE_CODE_SUBAGENT_MODEL: "",
	DELIVERY: "",
	STEP: "",
	MAKEFLAGS: "",
	MAKEOVERRIDES: "",
	FAKE_SCRIPT: "[]",
	...env,
});
function runner(dir, input, { script = [], env = {} } = {}) {
	return spawnSync(process.execPath, ["ai-factory/make/runner.js", "ai"], {
		cwd: dir,
		encoding: "utf8",
		env: headlessEnv(dir, input, { FAKE_SCRIPT: JSON.stringify(script), ...env }),
	});
}
const launches = (dir) => (fs.existsSync(path.join(dir, "launched")) ? fs.readFileSync(path.join(dir, "launched"), "utf8").split("\n").filter(Boolean).length : 0);
const loopIds = (dir) => {
	try {
		return fs.readdirSync(path.join(dir, "ai-factory/runs/tmp/loop")).sort();
	} catch {
		return [];
	}
};
function expectExit(run, code, label) {
	assert.equal(run.status, code, `${label}: the runner exited ${run.status}, not ${code}: ${(run.stderr || "").trim().split("\n").slice(-2).join(" | ")}`);
}
// Nothing launched and nothing written: no host, no run file, no loop state.
function expectRefused(dir, run, code, label) {
	expectExit(run, code, label);
	assert.equal(launches(dir), 0, `${label}: a host was launched`);
	assert.ok(!fs.existsSync(path.join(dir, "ai-factory/runs")), `${label}: the runner wrote under ai-factory/runs/`);
}
// The legacy plan's Steps 2 and 3 in the main tree, the fake ticking each, then the verdict.
const DRIVE_MET = (verdictText) => [
	{ loop: ["next", "$ID"] },
	{ tick: 2, plan: "0001-legacy.md" },
	{ loop: ["finish", "$ID", "2", "--result", "met"] },
	{ loop: ["next", "$ID"] },
	{ tick: 3, plan: "0001-legacy.md" },
	{ loop: ["finish", "$ID", "3", "--result", "met"] },
	{ loop: ["next", "$ID"] },
	{ loop: ["verdict", "$ID"], input: verdictText },
	{ loop: ["end", "$ID"] },
];
// Step 2 fails; the loop stops, optionally still taking the verdict, and ends.
const DRIVE_FAILED = (verdictText) => [
	{ loop: ["next", "$ID"] },
	{ loop: ["finish", "$ID", "2", "--result", "failed"] },
	{ loop: ["next", "$ID"] },
	...(verdictText === undefined ? [] : [{ loop: ["verdict", "$ID"], input: verdictText }]),
	{ loop: ["end", "$ID"] },
];
const RECORD = (code, causes) => [{ record: { schema: "t4-loop-outcome", version: 1, loop_id: "$ID", code, causes, report: `scripted report, code ${code}\n` } }];
const INVALID_PLAN = plan("Missing", "- [x] Step 1 — A.", "", "- [ ] Step 2 — B.", "  - Depends on: 1, 9");

test("headless", "headless-validation-3", () => {
	const dir = headlessRepo("hl-invalid", { "ai-factory/plans/0001-missing.md": INVALID_PLAN });
	for (const tool of ["claude", "codex"]) {
		const run = runner(dir, "0001", { env: { TOOL: tool } });
		expectRefused(dir, run, 3, `an invalid plan (${tool})`);
		assert.match(run.stderr, /Step 2\b.*\b9\b/, "the validation problem is not reported");
	}
});
test("headless", "headless-usage-2", () => {
	const dir = headlessRepo("hl-usage", { "ai-factory/plans/0001-legacy.md": LEGACY, "ai-factory/plans/0002-missing.md": INVALID_PLAN });
	for (const input of ["0001 --max-parallel 0", "0001 --step-timeout 241", "0001 --max-parallel", "0001 --bogus 1", "0001 0002", "0001 --host codex", "0001 --host=headless", "0002 --max-parallel x"]) {
		const run = runner(dir, input);
		expectRefused(dir, run, 2, `INPUT '${input}'`);
		assert.match(run.stderr, /usage: loop\.js start/, `INPUT '${input}': the usage is not shown`);
	}
});
test("headless", "headless-listing-0", () => {
	const dir = headlessRepo("hl-list", { "ai-factory/plans/0001-legacy.md": LEGACY });
	for (const input of ["", "0042", "  \n"]) {
		const run = runner(dir, input);
		expectRefused(dir, run, 0, `INPUT '${input}'`);
		assert.ok(run.stdout.startsWith(`${require(LOOP).HEADER}\n`), `INPUT '${input}': the candidate listing is not printed`);
		assert.match(run.stdout, /0001-legacy\.md/);
		assert.match(run.stderr, /nothing was launched/);
	}
});
test("headless", "headless-failure-1", () => {
	const dir = headlessRepo("hl-failed", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const run = runner(dir, "0001", { script: DRIVE_FAILED() });
	expectExit(run, 1, "a failed step");
	assert.equal(launches(dir), 1);
	assert.match(run.stderr, /exit code 1\b/);
	assert.match(run.stdout, /Step 2 — failed/, "the report does not name the failed step");
	assert.match(run.stdout, /Still unticked: 2, 3/, "the report does not list the unticked steps");
	// A timeout is the same exit code.
	const timed = headlessRepo("hl-timeout", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const script = DRIVE_FAILED().map((act) => (act.loop && act.loop[0] === "finish" ? { loop: ["finish", "$ID", "2", "--result", "timeout"] } : act));
	expectExit(runner(timed, "0001", { script }), 1, "a timed-out step");
});
test("headless", "headless-conflict-4", () => {
	const dir = headlessRepo("hl-conflict", { "ai-factory/plans/0001-legacy.md": LEGACY });
	for (const causes of [[{ kind: "conflict", step: 2, files: ["a.txt"] }], [{ kind: "snapshot", step: 2, message: "fatal" }], [{ kind: "refused", step: 3, files: ["b.txt"] }]]) {
		const run = runner(dir, "0001", { script: RECORD(4, causes) });
		expectExit(run, 4, `a ${causes[0].kind} cause`);
		assert.match(run.stderr, /exit code 4\b/);
	}
});
test("headless", "headless-approve-0", () => {
	for (const [tool, gate] of [["claude", ""], ["claude", "1"], ["codex", "1"]]) {
		const dir = headlessRepo(`hl-approve-${tool}${gate}`, { "ai-factory/plans/0001-legacy.md": LEGACY });
		const run = runner(dir, "0001", { script: DRIVE_MET(APPROVE), env: { TOOL: tool, GATE_ENFORCE: gate } });
		expectExit(run, 0, `every step ticked and approved (${tool}, GATE_ENFORCE=${gate})`);
		const text = fs.readFileSync(path.join(dir, "ai-factory/plans/0001-legacy.md"), "utf8");
		assert.ok(tickedIn(text, 2) && tickedIn(text, 3), "the steps are not ticked");
		assert.ok(run.stdout.includes(APPROVE.trimEnd()), "the verdict is not reported");
		// The runner's own scratch, the outcome record with it, is gone; the loop state is kept.
		assert.deepEqual(fs.readdirSync(path.join(dir, "ai-factory/runs/tmp")), ["loop"]);
		assert.equal(loopIds(dir).length, 1);
		if (tool === "codex") assert.match(run.stdout, /sequential(ly)? on Codex/);
	}
});
test("headless", "headless-gate-5", () => {
	for (const text of [CHANGES, "{ not json", '{"verdict":"approve","summary":"s","findings":[{"severity":"blocker","file":"a","line":1,"issue":"i","suggestion":"s"}]}']) {
		const dir = headlessRepo("hl-gate", { "ai-factory/plans/0001-legacy.md": LEGACY });
		const run = runner(dir, "0001", { script: DRIVE_MET(text), env: { GATE_ENFORCE: "1" } });
		expectExit(run, 5, `verdict ${JSON.stringify(text.slice(0, 30))} with GATE_ENFORCE=1`);
		assert.match(run.stderr, /exit code 5\b/);
	}
});
test("headless", "headless-no-gate-0", () => {
	const dir = headlessRepo("hl-advisory", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const run = runner(dir, "0001", { script: DRIVE_MET(CHANGES) });
	expectExit(run, 0, "a request_changes verdict without GATE_ENFORCE=1");
	assert.ok(run.stdout.includes(CHANGES), "the non-approving verdict is not reported");
});
test("headless", "headless-priority", () => {
	const dir = headlessRepo("hl-priority", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const failed = { kind: "failed", step: 3 };
	for (const causes of [[{ kind: "conflict", step: 2, files: ["a"] }, failed], [failed, { kind: "conflict", step: 2, files: ["a"] }], [{ kind: "timeout", step: 3 }, { kind: "snapshot", step: 2 }], [{ kind: "snapshot", step: 2 }, { kind: "timeout", step: 3 }, { kind: "verdict", step: null }]])
		expectExit(runner(dir, "0001", { script: RECORD(4, causes), env: { GATE_ENFORCE: "1" } }), 4, `causes ${causes.map((c) => c.kind).join(", ")}`);
	// AC68 through the real helper: a failure and a non-approving verdict under GATE_ENFORCE=1.
	const real = headlessRepo("hl-priority-real", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const run = runner(real, "0001", { script: DRIVE_FAILED(CHANGES), env: { GATE_ENFORCE: "1" } });
	expectExit(run, 1, "a failure with a request_changes verdict under GATE_ENFORCE=1");
	assert.match(run.stdout, /verdict not approved/, "the verdict cause is not reported with the failure");
});
test("headless", "headless-missing-outcome-1", () => {
	const dir = headlessRepo("hl-missing", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const none = runner(dir, "0001");
	expectExit(none, 1, "no outcome record");
	assert.match(none.stderr, /no readable outcome record/);
	const bad = [
		[[{ record: "{ not json" }], /no readable outcome record/],
		[[{ record: { schema: "other", loop_id: "$ID", code: 0, causes: [] } }], /not a t4-loop-outcome record/],
		[[{ record: { schema: "t4-loop-outcome", loop_id: "loop-20200101T000000Z-000000", code: 0, causes: [] } }], /names loop/],
		[RECORD(0, [{ kind: "failed", step: 2 }]), /does not follow from its causes/],
		[RECORD(3, []), /is not 0, 1, 4 or 5/],
	];
	for (const [script, message] of bad) {
		const run = runner(dir, "0001", { script });
		expectExit(run, 1, `record ${JSON.stringify(script).slice(0, 60)}`);
		assert.match(run.stderr, message);
	}
});
test("headless", "headless-host-fails-after-end", () => {
	// The host exits non-zero after loop.js end wrote a valid outcome record: the record's code
	// wins, and the host's failure is still said on stderr.
	const cases = [
		["a conflict record", [...RECORD(4, [{ kind: "conflict", step: 2, files: ["a.txt"] }]), { exit: 7 }], 4],
		["a real failed loop", [...DRIVE_FAILED(), { exit: 7 }], 1],
		["a real approved loop", [...DRIVE_MET(APPROVE), { exit: 7 }], 0],
	];
	for (const [label, script, code] of cases) {
		const dir = headlessRepo("hl-host-fails", { "ai-factory/plans/0001-legacy.md": LEGACY });
		const run = runner(dir, "0001", { script });
		expectExit(run, code, `${label}, then the host exits 7`);
		assert.match(run.stderr, /CLI failed \(7\)/, `${label}: the host's failure is not reported`);
		assert.match(run.stderr, new RegExp(`exit code ${code}\\b`), `${label}: the record's code is not reported`);
		assert.ok(fs.readdirSync(path.join(dir, "ai-factory/runs/tmp")).every((name) => name === "loop"), `${label}: the runner's scratch was left behind`);
	}
	// With no record, a failing host is still exit 1.
	const none = headlessRepo("hl-host-fails-none", { "ai-factory/plans/0001-legacy.md": LEGACY });
	expectExit(runner(none, "0001", { script: [{ exit: 7 }] }), 1, "no record and a failing host");
});
test("headless", "headless-no-question", () => {
	const dir = headlessRepo("hl-prompt", { "ai-factory/plans/0001-legacy.md": LEGACY });
	expectExit(runner(dir, "0001 --max-parallel 2", { script: DRIVE_MET(APPROVE) }), 0, "an approved loop");
	const [loopId] = loopIds(dir);
	const prompt = fs.readFileSync(path.join(dir, "captured-prompt.txt"), "utf8");
	assert.ok(prompt.startsWith(`${LOOP_TASK}\n## Input\n0001 --max-parallel 2`), "the task and input are not passed unchanged");
	assert.match(prompt, /headless run: ask no question and wait for no answer/, "the prompt lacks the headless instruction");
	assert.ok(prompt.includes(`Loop ID: ${loopId}`), "the prompt does not name the started loop");
	assert.match(prompt, /do not run start again/);
	const seen = JSON.parse(fs.readFileSync(path.join(dir, "captured-env.json"), "utf8"));
	assert.equal(seen.id, loopId, "T4_LOOP_ID is not the started loop");
	assert.ok(path.isAbsolute(seen.result) && seen.result.startsWith(path.join(fs.realpathSync(dir), "ai-factory/runs/tmp/")), `T4_LOOP_RESULT is not an absolute path in the runner's scratch: ${seen.result}`);
	assert.equal(readLoopState(dir, loopId).max_parallel, 2);
	assert.equal(readLoopState(dir, loopId).host, "headless");
});
test("headless", "make-collapses-status", () => {
	// GNU make turns every failing recipe into its own status 2 (plan 0022, Ambiguity 2; AC71).
	const dir = headlessRepo("hl-make", { "ai-factory/plans/0001-legacy.md": LEGACY });
	const make = (script) => spawnSync("make", ["-f", "ai-factory/make/ai.mk", "ai"], { cwd: dir, encoding: "utf8", env: headlessEnv(dir, "0001", { FAKE_SCRIPT: JSON.stringify(script) }) });
	const conflict = make(RECORD(4, [{ kind: "conflict", step: 2, files: ["a"] }]));
	assert.equal(conflict.status, 2, `make exited ${conflict.status}, not 2: ${conflict.stderr}`);
	assert.match(conflict.stderr, /runner: TASK=loop \S+ exit code 4\b/, "make's stderr does not show the runner's code");
	const ok = make(RECORD(0, []));
	assert.equal(ok.status, 0, `make exited ${ok.status} on success: ${ok.stderr}`);
});

// ---- procedures (plan 0022 Step 9; AC13, AC17–AC20, AC27, AC34, AC44, AC54, AC59, AC60, AC65) -
// Static checks of tasks/loop.md and its generated entries. They pin what the procedure says;
// its behaviour on a real host is proved by plan 0022 Step 13's runs, never here.
const LOOP_TASK_FILE = "skills/ai-layout/templates/ai-factory/tasks/loop.md";
function loopTask() {
	if (!fs.existsSync(LOOP_TASK_FILE)) throw new Error("tasks/loop.md does not exist");
	return fs.readFileSync(LOOP_TASK_FILE, "utf8");
}
// The body without the frontmatter, and its lines that mention a pattern.
const taskBody = (text) => text.replace(/^---\n[\s\S]*?\n---\n/, "");
const linesWith = (text, pattern) => text.split("\n").filter((line) => pattern.test(line));
// A sentence-level prohibition: every line naming the pattern also says not/never/no.
function onlyForbidden(text, pattern, label) {
	const lines = linesWith(text, pattern);
	assert.ok(lines.length, `tasks/loop.md does not mention ${label} at all, so it does not forbid it`);
	for (const line of lines) assert.match(line, /\b(?:[Nn]ever|[Nn]ot|[Nn]o|[Dd]o not|nor)\b/, `tasks/loop.md names ${label} without forbidding it: ${line.trim()}`);
}

test("procedures", "loop-delegates-implementer", () => {
	const text = loopTask();
	const body = taskBody(text);
	assert.match(text, /^description: .+$/m, "tasks/loop.md has no description");
	assert.match(text, /^argument-hint: .*plan number or path/m, "the argument hint does not say 'plan number or path'");
	for (const sub of ["start", "next", "prepare", "finish", "verdict", "end"])
		assert.ok(body.includes(`node ai-factory/make/loop.js ${sub}`), `tasks/loop.md does not call loop.js ${sub}`);
	assert.match(body, /`implementer` subagent/, "the steps are not delegated to the implementer subagent");
	assert.match(body, /own (?:verification )?phase/, "a step is not delegated under its own phase");
	for (const phase of ["red", "step", "final"]) assert.ok(body.includes(`\`${phase}\``), `the phase ${phase} is not named`);
	assert.match(body, /[Dd]o not implement anything yourself/, "the task does not forbid implementing in the session");
	// The task never starts or chains a step on its own: next decides.
	assert.match(body, /only the steps? (?:that )?`next` (?:names|starts)/i, "the task does not limit starts to what next names");
	// AC17: a step that runs alone runs in the main tree and is ticked exactly as /t4:run ticks it.
	assert.match(body, /`main`[^\n]*\n?[^\n]*as under `\/t4:run`/, "a main-tree step is not ticked as under /t4:run");
	// The implementer's output of a failed step is relayed through finish --output-file.
	assert.ok(body.includes("--output-file"), "a step's output is not passed to finish --output-file");
	assert.match(body, /never (?:through|in) a shell string/i, "the implementer's output may be written through a shell string");
});
test("procedures", "loop-worktree-mode-delegation", () => {
	const body = taskBody(loopTask());
	assert.ok(body.includes("worktree mode"), "the delegation does not say worktree mode");
	const worktree = linesWith(body, /worktree mode/).join(" ");
	assert.match(body, /worktree root/, "the delegation does not name the worktree root");
	assert.match(body, /do not tick/i, "a worktree-mode implementer is not told not to tick");
	assert.match(body, /report (?:the|its) phase result/i, "a worktree-mode implementer is not told to report its phase result");
	assert.ok(worktree.length, "no line says worktree mode");
	assert.match(body, /`prepare`[\s\S]{0,200}`snapshot-failed`/, "a failed snapshot copy is not handled");
	onlyForbidden(body, /git worktree remove/, "removing a worktree");
});
// Case IDs keep the name plan 0022 records; the task they test is now /t4:review.
test("procedures", "loop-runs-check-once", () => {
	const body = taskBody(loopTask());
	assert.match(body, /`\/t4:review` once/, "the loop does not run /t4:review once");
	assert.match(body, /`reviewer` subagent/, "/t4:review does not go through the reviewer");
	assert.match(body, /`review` \(every step ticked/, "the review answer of next is not handled");
	assert.match(body, /`tasks\/review\.md`/, "the loop does not follow tasks/review.md");
	assert.doesNotMatch(body, /\/t4:check|tasks\/check\.md|--phase check/, "the loop still names the review task by its deprecated name");
	// AC19: an already fully ticked plan still gets the one review, and no step runs.
	assert.match(body, /already ticked/i, "the fully ticked plan is not covered");
	assert.ok(body.includes("node ai-factory/make/loop.js verdict"), "the verdict is not passed to loop.js verdict");
	assert.match(body, /unchanged/, "the verdict or the report is not relayed unchanged");
	assert.match(body, /node ai-factory\/make\/loop\.js end[\s\S]{0,400}(?:report|record)/, "end's report is not relayed");
	// Exactly one review: the procedure never says to run it per step or again.
	assert.doesNotMatch(body, /\/t4:review` (?:after|for) each step/i);
});
test("procedures", "loop-no-test-gaps", () => {
	const body = taskBody(loopTask());
	onlyForbidden(body, /\/t4:test/, "/t4:test");
	onlyForbidden(body, /\/t4:report/, "/t4:report");
	onlyForbidden(body, /git commit|`commit`|\bcommit\b/, "committing");
	onlyForbidden(body, /\breset\b/, "a reset");
	assert.doesNotMatch(body, /\btest gaps\b(?![^\n]*\b(?:never|not|no)\b)/i, "test gaps is run");
});
test("procedures", "loop-timeout-claude", () => {
	const body = taskBody(loopTask());
	assert.match(body, /step_timeout/, "the started loop's step timeout is not used");
	assert.ok(body.includes("--result timeout"), "a timed-out step is not finished as a timeout");
	assert.match(body, /[Ss]top (?:that|its|the) (?:implementer|delegation)/, "the task does not stop an implementer past its timeout");
	assert.match(body, /background/, "steps are not started as background delegations, so nothing can wait on a timeout");
	assert.match(body, /Claude Code/, "the timeout is not tied to Claude Code");
	// No silent downgrade (plan 0022, Risks): a host that cannot stop a delegation is said, not hidden.
	assert.match(body, /cannot stop[\s\S]{0,300}(?:say so|report)/i, "a host that cannot stop a delegation is not reported");
});
test("procedures", "loop-codex-notes", () => {
	const body = taskBody(loopTask());
	assert.match(body, /--host codex/, "the Codex host is not passed to start");
	assert.match(body, /Codex[\s\S]{0,300}one (?:step )?at a time/i, "Codex does not run one step at a time");
	assert.match(body, /[Nn]ever (?:send|pass|use) `--result timeout` on Codex|on Codex[^\n]*never[^\n]*`--result timeout`/, "Codex may send --result timeout");
	assert.match(body, /not enforced/i, "the report's Codex timeout note is not mentioned");
});
test("procedures", "loop-assurance-contracts", () => {
	const body = taskBody(loopTask());
	assert.ok(body.includes("node ai-factory/make/assurance.js show"), "assurance is not shown as /t4:run shows it");
	assert.ok(body.includes("ai-factory/assurance.json"), "assurance is not conditional on ai-factory/assurance.json");
	assert.ok(body.includes("ai-factory/contracts/config.json"), "contracts are not conditional on their configuration");
	assert.match(body, /--delivery <id> --phase/, "a worktree step's evidence is not routed through finish --delivery");
	assert.match(body, /contract evidence/i);
	assert.match(body, /\.contract\.json/, "the delivery ID's source is not named");
	// Lifecycle: the loop run, each step's run with its parent, and the review with its parent (AC58).
	assert.ok(body.includes("lifecycle.js start --phase loop"), "the loop does not open a loop lifecycle run");
	assert.match(body, /lifecycle\.js start --phase run --delivery <id> --step S<N> --parent-run <loop run>/, "a step's run is not linked to the loop run");
	assert.match(body, /lifecycle\.js start --phase review --delivery <id> --parent-run <loop run>/, "the review run is not linked to the loop run");
});
test("procedures", "loop-headless", () => {
	const body = taskBody(loopTask());
	assert.ok(body.includes("T4_LOOP_ID"), "a headless run does not resume from T4_LOOP_ID");
	assert.match(body, /## Headless loop/, "the runner's headless section is not recognised");
	assert.match(body, /do not run (?:`?start`? again|`node ai-factory\/make\/loop\.js start`)/i, "a headless run may start a second loop");
	assert.match(body, /headless[\s\S]{0,200}(?:ask no question|never ask)/i, "a headless run may ask");
	assert.match(body, /[Aa]lways (?:finish|end) with `node ai-factory\/make\/loop\.js end/, "the loop does not always end with loop.js end");
	assert.match(body, /[Nn]ever (?:decide|compute|choose) (?:the )?exit code/, "the session may decide the exit code itself");
});
test("procedures", "run-unchanged", () => {
	for (const file of [`${"skills/ai-layout/templates/ai-factory"}/tasks/run.md`, "commands/run.md"]) {
		const main = spawnSync("git", ["show", `main:${file}`], { env: ENV, encoding: "utf8" });
		assert.equal(main.status, 0, `git show main:${file} failed: ${main.stderr.trim()}`);
		assert.equal(fs.readFileSync(file, "utf8"), main.stdout, `${file} differs from main`);
	}
});
test("procedures", "loop-session-owned", () => {
	loopTask();
	const models = require(path.join(MAKE, "models.js"));
	const dir = fs.mkdtempSync(path.join(SCRATCH, "loop-models-"));
	fixtures.push(dir);
	fs.cpSync(MAKE, path.join(dir, "ai-factory/make"), { recursive: true });
	fs.mkdirSync(path.join(dir, "ai-factory/tasks"), { recursive: true });
	for (const name of ["loop", "run", "review"]) fs.copyFileSync(path.join(PLUGIN, `skills/ai-layout/templates/ai-factory/tasks/${name}.md`), path.join(dir, `ai-factory/tasks/${name}.md`));
	fs.writeFileSync(path.join(dir, "ai-factory/models.yaml"), "claude: gateway/session-claude\ncodex: gateway/session-codex\nreview:\nrouting:\n  enabled: true\n  tasks:\n    loop:\n      claude: gateway/loop-claude\n      codex: gateway/loop-codex\n    run:\n      claude: gateway/run-claude\n      codex: gateway/run-codex\n");
	const sync = spawnSync(process.execPath, ["ai-factory/make/sync-adapters.js", "--adapters=routing"], { cwd: dir, encoding: "utf8", env: ENV });
	assert.equal(sync.status, 0, sync.stderr);
	for (const host of ["claude", "codex"]) {
		const agents = path.join(dir, models.ADAPTER_DIRS[host]);
		assert.deepEqual((fs.existsSync(agents) ? fs.readdirSync(agents) : []).filter((name) => name.startsWith("t4-route-loop-")), [], `a ${host} loop route agent was generated`);
		const run = spawnSync(process.execPath, ["ai-factory/make/models.js", "dispatch", "--host", host, "--task", "loop"], { cwd: dir, encoding: "utf8", env: { ...ENV, CLAUDE_CODE_SUBAGENT_MODEL: "" } });
		assert.equal(run.status, 0, run.stdout + run.stderr);
		assert.match(run.stdout, /directive: session/, `loop on ${host} is not session-owned`);
		assert.doesNotMatch(run.stdout, /directive: route|subagent_type|spawn_agent|t4-route-/, `loop on ${host} is routed to a worker`);
		assert.ok(run.stdout.includes(`gateway/loop-${host} is not used`), "the ignored loop mapping is not named");
		assert.match(run.stdout, /run task's own model policy/, "the directive does not say each step follows run's policy");
		assert.doesNotMatch(run.stdout, /continue\.js|continuation/, "the loop directive carries continue's text");
		const override = spawnSync(process.execPath, ["ai-factory/make/models.js", "dispatch", "--host", host, "--task", "loop", "--task-model", "gateway/other"], { cwd: dir, encoding: "utf8", env: { ...ENV, CLAUDE_CODE_SUBAGENT_MODEL: "" } });
		assert.notEqual(override.status, 0, "a concrete loop model override is accepted");
		assert.match(override.stdout, /loop does not take a model override/);
	}
	const doctor = spawnSync(process.execPath, ["ai-factory/make/models.js", "doctor"], { cwd: dir, encoding: "utf8", env: ENV });
	assert.match(doctor.stdout, /finding\|routing\|routing\.tasks\.loop is ignored/, "a loop mapping is not a doctor finding");
	// The generated entries exist and run the loop's routing step; the plugin's command wins.
	assert.ok(fs.readFileSync("commands/loop.md", "utf8").includes("models.js dispatch --host claude --task loop"), "commands/loop.md is missing or stale");
	assert.ok(fs.readFileSync("codex-skills/t4-loop/SKILL.md", "utf8").includes("models.js dispatch --host codex --task loop"), "codex-skills/t4-loop/SKILL.md is missing or stale");
	assert.match(fs.readFileSync(path.join(MAKE, "sync-adapters.js"), "utf8"), /^\t"loop",$/m, "loop is not a native Claude command");
});
test("procedures", "no-nnnn-counting", () => {
	const text = loopTask();
	for (const [i, line] of text.split("\n").entries())
		assert.ok(!/<NNNN>-|\bNNNN-|next free number/i.test(line), `tasks/loop.md:${i + 1} counts plan numbers: ${line.trim()}`);
	assert.match(text, /plan number or path/, "the task does not say 'plan number or path'");
});

// ---- procedures (plan 0022 Step 10; AC38 review side, AC56, AC57) -------------------------
// The planner and the plan template define `Depends on:`, the implementer carries one
// worktree-mode line, and /t4:review never collects the loop's worktrees. Each prompt is read
// as its source and as the adopted copy materialize-agents.js delivers.
const TEMPLATE_AGENTS = "skills/ai-layout/templates/ai-factory/agents";
const agentCopies = (name) => [`agents/${name}.md`, `${TEMPLATE_AGENTS}/${name}.md`].map((rel) => [rel, fs.readFileSync(rel, "utf8")]);
// The paragraph or list item (blank line or list marker bounded) that holds the first match.
function passage(text, pattern) {
	const blocks = text.split(/\n(?=\s*\n|\s*(?:[-*+]|\d+\.) )/);
	return blocks.find((block) => pattern.test(block)) || "";
}
// AC56: what the planner and the plan template must both say about the line.
function assertDependsOn(rel, text) {
	assert.ok(text.includes("`Depends on: N, M`"), `${rel} does not define the \`Depends on: N, M\` line`);
	const rule = passage(text, /`Depends on: N, M`/).replace(/\s+/g, " ");
	assert.match(rule, /optional/i, `${rel}: the Depends on: line is not optional`);
	assert.match(rule, /without it waits for (?:all|every) earlier steps?/i, `${rel}: a step without the line does not wait for all earlier steps`);
	assert.match(rule, /where steps are independent/i, `${rel}: the line is not written where steps are independent`);
	assert.match(rule, /only (?:to )?existing earlier step numbers/i, `${rel}: the line may cite a step that is not an existing earlier one`);
	assert.match(rule, /never (?:form(?:ing)? )?a cycle/i, `${rel}: the line may form a cycle`);
}
test("procedures", "planner-depends-on", () => {
	for (const [rel, text] of agentCopies("planner")) assertDependsOn(rel, text);
});
test("procedures", "plan-template-depends-on", () => {
	assertDependsOn("tasks/plan.md", fs.readFileSync("skills/ai-layout/templates/ai-factory/tasks/plan.md", "utf8"));
});
test("procedures", "implementer-worktree-line", () => {
	// AC57: exactly one added line against the commit before plan 0022 (64ad3bc), in the source
	// and in the adopted copy. Not `main`: once 0022 merged, main already holds the line.
	const BASELINE = "64ad3bcd2c5a8df3d40a3046fc87df6d0278a8a5";
	for (const rel of ["agents/implementer.md", `${TEMPLATE_AGENTS}/implementer.md`]) {
		const diff = spawnSync("git", ["diff", "--no-color", "--unified=0", BASELINE, "--", rel], { env: ENV, encoding: "utf8" });
		assert.equal(diff.status, 0, `git diff ${BASELINE} -- ${rel} failed: ${diff.stderr.trim()}`);
		const changed = diff.stdout.split("\n").filter((line) => /^[-+]/.test(line) && !/^(?:---|\+\+\+) /.test(line));
		assert.equal(changed.length, 1, `${rel} differs from the pre-0022 baseline by ${changed.length} lines, not one added line: ${changed.join(" | ")}`);
		const [line] = changed;
		assert.ok(line.startsWith("+"), `${rel}: the change against the pre-0022 baseline is not an added line: ${line}`);
		assert.match(line, /worktree mode/, `${rel}: the added line does not say worktree mode`);
		assert.match(line, /do not tick the step/i, `${rel}: a worktree-mode implementer is not told not to tick`);
		assert.match(line, /report the phase result/i, `${rel}: a worktree-mode implementer is not told to report the phase result`);
		// Consistent with tasks/loop.md: the loop records a worktree step's evidence after the apply.
		assert.match(line, /do not record contract evidence|record no contract evidence/i, `${rel}: a worktree-mode implementer may record contract evidence`);
	}
	const delegation = linesWith(taskBody(loopTask()), /worktree mode|do not tick|contract evidence, and report/).join(" ");
	assert.match(delegation, /do not record contract evidence/, "tasks/loop.md no longer tells a worktree step not to record contract evidence");
});
test("procedures", "check-skips-worktrees", () => {
	// AC38, review side: the subtree is named only to be excluded. commands/review.md, the deprecated
	// commands/check.md and the Codex skills only point at tasks/review.md, so the task file is where the rule lives.
	const files = [["tasks/review.md", fs.readFileSync("skills/ai-layout/templates/ai-factory/tasks/review.md", "utf8")], ...agentCopies("reviewer")];
	for (const [rel, text] of files) {
		const rule = passage(text, /ai-factory\/runs\/tmp\/worktrees\//).replace(/\s+/g, " ");
		assert.ok(rule, `${rel} does not name ai-factory/runs/tmp/worktrees/`);
		assert.match(rule, /[Nn]ever collect or read[^.]*`ai-factory\/runs\/tmp\/worktrees\/`/, `${rel} does not say never to collect or read ai-factory/runs/tmp/worktrees/`);
	}
});

// ---- the worktree step's contract evidence (plan 0022 Step 9, Ambiguity 5; AC60) ---------
// With artifact contracts on, a worktree step's evidence is recorded in the main tree after its
// clean apply, and the step is ticked only when `make verify` exits 0. The fixture's ai.mk
// stands in for the real target: it logs the selections make received and fails on demand.
const FAKE_VERIFY_MK = "verify:\n\t@echo \"$(DELIVERY)|$(STEP)|$(PHASE)\" >> \"$(CURDIR)/.git/verify.log\"\n\t@test ! -e \"$(CURDIR)/.git/verify-fails\"\n";
test("apply", "worktree-contract-verify-gates-tick", () => {
	const { dir, loopId, tree } = preparedPair("ap-contract", { "ai-factory/make/ai.mk": FAKE_VERIFY_MK });
	const log = () => (fs.existsSync(path.join(dir, ".git/verify.log")) ? fs.readFileSync(path.join(dir, ".git/verify.log"), "utf8").split("\n").filter(Boolean) : []);
	fs.writeFileSync(path.join(tree(2), "two.txt"), "two\n");
	fs.writeFileSync(path.join(tree(3), "three.txt"), "three\n");
	// Refused before anything is recorded: a malformed delivery, a phase alone, an unknown phase.
	for (const flags of [["--delivery", "d-1"], ["--phase", "red"], ["--delivery", "d-20260101-abcdef", "--phase", "gaps"], ["--delivery"]]) {
		const refused = cliWith(dir, ["finish", loopId, "2", "--result", "met", ...flags]);
		assert.equal(refused.status, 2, `finish ${flags.join(" ")} exited ${refused.status}, not 2`);
	}
	assert.deepEqual(readLoopState(dir, loopId).running.map((entry) => entry.step), [2, 3], "a refused finish changed the running steps");
	assert.deepEqual(log(), [], "make verify ran for a refused finish");
	// A final step records its step phase, then the delivery's final verification, then ticks.
	const two = cli(dir, "finish", loopId, "2", "--result", "met", "--delivery", "d-20260101-abcdef", "--phase", "final");
	assert.equal(two.status, 0, two.stderr);
	assert.deepEqual(two.json.ticked, [2], "a verified worktree step was not ticked");
	assert.deepEqual(log(), ["d-20260101-abcdef|S2|", "d-20260101-abcdef||final"], "the evidence recorded is not the step's then the final verification");
	// A red step whose recording fails: its delta is in the main tree, unticked, worktree kept.
	fs.writeFileSync(path.join(dir, ".git/verify-fails"), "");
	const three = cli(dir, "finish", loopId, "3", "--result", "met", "--delivery", "d-20260101-abcdef", "--phase", "red");
	assert.equal(three.status, 0, three.stderr);
	assert.deepEqual(log().slice(2), ["d-20260101-abcdef|S3|red"], "a red step did not record PHASE=red");
	assert.deepEqual(three.json.ticked, [], "a step whose evidence failed was ticked");
	assert.ok(!tickedIn(planText(dir), 3), "a step whose evidence failed is ticked in the plan");
	assert.ok(fs.existsSync(path.join(dir, "three.txt")), "the applied delta is missing");
	const cause = three.json.causes.find((entry) => entry.step === 3);
	assert.deepEqual([cause && cause.kind, cause && cause.worktree], ["failed", `ai-factory/runs/tmp/worktrees/${loopId}-S3`], "the failed recording is not a failed cause with its worktree");
	assert.ok(fs.existsSync(tree(3)), "the worktree of a step whose evidence failed was removed");
	assert.equal(cli(dir, "next", loopId).json.action, "stop");
	// A main-tree step's implementer records its own evidence: --delivery is refused there.
	const main = repo("ap-contract-main", { "ai-factory/plans/0001-legacy.md": LEGACY, "ai-factory/make/ai.mk": FAKE_VERIFY_MK });
	const id = expectStarted(main, ["0001"]).json.loop_id;
	cli(main, "next", id);
	assert.equal(cliWith(main, ["finish", id, "2", "--result", "met", "--delivery", "d-20260101-abcdef"]).status, 2, "--delivery was accepted for a main-tree step");
	assert.ok(!fs.existsSync(path.join(main, ".git/verify.log")), "make verify ran for a main-tree step");
});

// ---- docs (plan 0022 Step 12; AC40, AC55) --------------------------------------------------
// The loop's exception to "one step per /t4:run" is named where developers and agents read the
// rules, test tools are told to skip the worktree subtree, and the CHANGELOG says the template
// change is breaking. Every assertion runs over one section or block and over sentences, never
// over a whole file: prose wraps, and the same words elsewhere in a long file prove nothing.
const WORKFLOW_DOC = "ai-factory/docs/workflow.md";
const AGENTS_DOCS = ["ai-factory/AGENTS.md", "skills/ai-layout/templates/ai-factory/AGENTS.md"];
const readDoc = (rel) => {
	if (!fs.existsSync(rel)) throw new Error(`${rel} does not exist`);
	return fs.readFileSync(rel, "utf8");
};
// The lines under the first heading of `level` (e.g. "##") matching `pattern`, up to the next
// heading of the same or a higher level.
function docSection(text, level, pattern) {
	const lines = text.split("\n");
	const start = lines.findIndex((line) => line.startsWith(`${level} `) && pattern.test(line));
	if (start < 0) return "";
	const depth = level.length;
	let end = lines.slice(start + 1).findIndex((line) => {
		const heading = /^(#+) /.exec(line);
		return heading && heading[1].length <= depth;
	});
	end = end < 0 ? lines.length : start + 1 + end;
	return lines.slice(start, end).join("\n");
}
// Bold and code markers dropped, newlines folded, one sentence per entry.
const docSentences = (text) =>
	text
		.replace(/\*\*/g, "")
		.replace(/\s+/g, " ")
		.split(/(?<=[.!?])\s+(?=[A-Z`/(])/);
const WORKTREE_SUBTREE = "ai-factory/runs/tmp/worktrees/";
// "One step per /t4:run" with /t4:loop named as its exception, in one sentence.
const namesException = (sentence) =>
	/\/t4:loop\b/.test(sentence) && /\bexception\b/i.test(sentence) && /one (?:named )?step per `?\/t4:run`?/i.test(sentence);

test("docs", "workflow-exception", () => {
	// AC55: the exception sits under "The rules that make it work", and /t4:run keeps its halt.
	const rules = docSection(readDoc(WORKFLOW_DOC), "###", /The rules that make it work/);
	assert.ok(rules, `${WORKFLOW_DOC} has no "The rules that make it work" section`);
	const sentences = docSentences(rules);
	assert.ok(sentences.some(namesException), `${WORKFLOW_DOC}'s rules do not name /t4:loop as the exception to one step per /t4:run`);
	assert.ok(
		sentences.some((s) => /`?\/t4:run`? (?:is unchanged|still (?:halts|stops) after one step)/i.test(s)),
		`${WORKFLOW_DOC}'s rules do not say /t4:run itself still stops after one step`,
	);
	assert.ok(
		sentences.some((s) => /\/t4:loop\b|\bthe loop\b/i.test(s) && /never commits? on (?:your|the developer's) branch/i.test(s)),
		`${WORKFLOW_DOC}'s rules do not say the loop never commits on the developer's branch`,
	);
	assert.match(rules, /adr\/ETT683-loop-halt-and-commit-exceptions\.md/, `${WORKFLOW_DOC}'s rules do not link the loop's ADR`);
	// The command table lists the loop with what it never does.
	const table = docSection(readDoc(WORKFLOW_DOC), "###", /Project tasks/);
	const row = linesWith(table, /^\| `\/t4:loop/)[0];
	assert.ok(row, `${WORKFLOW_DOC}'s project task table has no /t4:loop row`);
	assert.match(row, /commit on (?:your|the developer's) branch/i, `${WORKFLOW_DOC}'s /t4:loop row does not say it never commits on the branch`);
});
test("docs", "agents-md-exception-and-command", () => {
	// AC55, both files: this repo's AGENTS.md and the template every adopted repo receives.
	for (const rel of AGENTS_DOCS) {
		const text = readDoc(rel);
		const slash = linesWith(text, /^Slash commands:/);
		assert.equal(slash.length, 1, `${rel} has ${slash.length} "Slash commands:" lines, not one`);
		assert.ok(slash[0].split(/\s+/).includes("/t4:loop"), `${rel} does not list /t4:loop among the slash commands`);
		const workflow = docSection(text, "##", /^## Workflow$/);
		assert.ok(workflow, `${rel} has no "## Workflow" section`);
		assert.ok(docSentences(workflow).some(namesException), `${rel}'s Workflow does not name /t4:loop as the exception to one step per /t4:run`);
		// SKILL.md's rule for AGENTS.md: under 60 lines, so the exception cannot cost the cache.
		assert.ok(text.replace(/\n$/, "").split("\n").length < 60, `${rel} is 60 lines or more`);
	}
});
test("docs", "tools-exclude-worktrees", () => {
	// AC40: test, lint and typecheck tools are told to skip the loop's worktrees; AC71: only the
	// runner returns the distinct codes, and make reports every failure as 2.
	const text = readDoc(WORKFLOW_DOC);
	const sentences = docSentences(text);
	assert.ok(
		sentences.some((s) => s.includes(WORKTREE_SUBTREE) && /\btest\b/i.test(s) && /\blint\b/i.test(s) && /\btypecheck\b/i.test(s) && /\bmust exclude\b/i.test(s)),
		`${WORKFLOW_DOC} does not state that test, lint and typecheck tools must exclude ${WORKTREE_SUBTREE}`,
	);
	const headless = docSection(text, "##", /^## 6\. Headless/);
	assert.ok(headless, `${WORKFLOW_DOC} has no "## 6. Headless" section`);
	for (const [code, cause] of [[1, /fail|timeout/i], [2, /usage/i], [3, /validat/i], [4, /conflict/i], [5, /GATE_ENFORCE=1/]])
		assert.ok(
			headless.split("\n").some((line) => new RegExp(`(?:^|\\|)\\s*\`?${code}\`?\\s*(?:\\||—|:)`).test(line) && cause.test(line)),
			`${WORKFLOW_DOC}'s headless section does not give exit code ${code} with its cause`,
		);
	const flat = docSentences(headless);
	assert.ok(
		flat.some((s) => s.includes("node ai-factory/make/runner.js ai") && /\bonly\b/i.test(s) && /\b1 to 5\b/.test(s)),
		`${WORKFLOW_DOC} does not say only node ai-factory/make/runner.js ai returns the codes 1 to 5`,
	);
	assert.ok(
		flat.some((s) => /make[^.]*TASK=loop/.test(s) && /every failure as 2|any failure as 2|2 for every failure/i.test(s)),
		`${WORKFLOW_DOC} does not say make ai TASK=loop reports every failure as 2`,
	);
});
test("docs", "changelog-breaking-loop", () => {
	// The template change is breaking for every adopted repo (ai-factory/AGENTS.md), so the top
	// entry carries a plan 0022 block (Unreleased, or under its released heading) that says so and names what changed.
	const text = readDoc("CHANGELOG.md");
	const top = text.split(/\n(?=## )/).find((part) => part.startsWith("## ")) || "";
	const blocks = top.split(/\n(?=\*\*[^*\n]+\*\*\n)/);
	const block = blocks.find((part) => /^\*\*(?:Unreleased — plan|Plan) 0022\b/.test(part));
	assert.ok(block, "CHANGELOG.md's top entry has no plan 0022 block");
	const flat = block.replace(/\s+/g, " ");
	assert.match(flat, /Breaking for adopted repos/, "the plan 0022 block is not marked breaking for adopted repos");
	// Each change is one list item: its lead names it, and its body carries the fact.
	const items = block.split(/\n(?=- )/).slice(1).map((item) => item.replace(/\s+/g, " "));
	for (const [what, lead, fact] of [
		["the new command", /`\/t4:loop/, /`\/t4:run` is unchanged/],
		["the new helper", /make\/loop\.js/, /exit code/],
		["the headless exit codes", /TASK=loop/, /\b1 step failure or timeout\b[^]*\b4 conflict/],
		["the guard exception", /guard exception/i, /ai-factory\/runs\/tmp\/worktrees\//],
		["log writes through the git common dir", /git common dir/i, /git rev-parse --git-common-dir/],
		["the Depends on: grammar", /Depends on:/, /`Depends on: N, M`/],
		["the implementer line", /implementer line/i, /worktree mode/],
		["the migration", /Migration/, /\/t4:sync-sdlc/],
	]) {
		const item = items.find((text) => lead.test(text.slice(0, 80)));
		assert.ok(item, `the plan 0022 block has no item for ${what}`);
		assert.match(item, fact, `the plan 0022 block's item for ${what} does not say ${fact}`);
	}
});

// ---- groups that later steps of plan 0022 fill --------------------------------------------
const later = { apply: 5, outcome: 6, headless: 8, procedures: 9, docs: 12 };

try {
	for (const c of cases) {
		if (!want(c.group)) continue;
		try {
			c.fn();
			passed++;
			if (process.env.VERBOSE) console.log(`ok: ${c.group}/${c.name}`);
		} catch (error) {
			failures.push(`${c.group}/${c.name}: ${error.message.split("\n")[0]}`);
		}
	}
} finally {
	for (const dir of fixtures) fs.rmSync(dir, { recursive: true, force: true });
}
for (const [name, step] of Object.entries(later))
	if (want(name) && !cases.some((c) => c.group === name))
		failures.push(`${name}: no cases yet (plan 0022 Step ${step} adds them)`);
for (const line of failures) console.error(`FAIL ${line}`);
if (failures.length) process.exitCode = 1;
else console.log(`loop ok — ${passed} cases (${selected})`);
NODE
