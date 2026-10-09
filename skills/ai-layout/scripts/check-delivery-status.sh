#!/usr/bin/env bash
# Compact delivery status (spec 0019, plan 0019). Acceptance fixtures written before the feature:
# Step 1 writes this file, Step 2 makes the `helper` group green, Step 3 makes the `cli` group green.
#
# Groups: helper, cli (default: both; an unknown group exits 2).
#   helper — skills/ai-layout/templates/ai-factory/make/delivery-status.js, copied into each fixture
#            and run as `node ai-factory/make/delivery-status.js <delivery id>`.
#   cli    — skills/ai-layout/scripts/state.sh <repo> <plugin> --delivery <delivery id>, which runs
#            the fixture workspace's adopted helper; plus argument collisions and legacy listings.
#
# Every fixture is a disposable Git repository under ai-factory/runs/tmp/, built from
# skills/ai-layout/fixtures/contracts/ with evidence produced by contracts.js itself (the pattern of
# check-delivery-report.sh and check-continuation.sh). Every read is wrapped: the fixture tree is
# compared before and after, and the declared verification commands plus stand-ins for `make`,
# `claude` and `codex` append to a sentinel file if anything executes them (AC5).
#
# INTERFACE PINNED HERE. The spec proposes these defaults; where it left a name or wording open,
# the choice below is this file's and is flagged as such.
#   Helper exit codes: 0 when a status is shown, whatever the readiness; 2 for a refusal (no ID, a
#     malformed ID or path selector, an unknown ID, a duplicate delivery identity, contracts not
#     enabled or an unreadable contracts config) with stdout empty and one line on stderr.
#   Output: a tab-separated two-column table. First line exactly `field<TAB>value`; every later line
#     is one field and one value. Field names (chosen; the spec names the content, not the names):
#       delivery             the delivery ID
#       kind                 planned | quick
#       progress             evidence-derived progress, first token one of: planning,
#                            implementation, verification-unproven, review-pending, ready, unknown
#       readiness            first token the existing evaluator status: ready, incomplete,
#                            unverified, blocked
#       steps | checks       planned | quick: "<ticked> of <active> ticked" — recorded progress only;
#                            a plan with withdrawn steps also says "withdrawn"
#       verified, attested,  criterion IDs grouped; every declared ID appears in exactly one group;
#       remaining, unknown   an empty group reads "none". Mapping of evaluator results (chosen):
#                            passed→verified, attested→attested, pending/failed/uncovered→remaining
#                            written "<ID> (<result>)" so a failure stays visible, e.g. "AC2 (failed)",
#                            unverified→unknown
#       latest verification  latest non-review evidence by valid finished_at, ties broken by
#                            ascending evidence path: its path, phase, "expects pass|fail", status
#                            and freshness (valid|stale|invalid); "interrupted" when a signal stopped
#                            it; "none" when nothing is recorded; first token "unknown" whenever any
#                            evidence timestamp is invalid or unreadable — including malformed
#                            evidence files (chosen: an unparsable record's time is unknown, so it
#                            may be the latest)
#       review               verdict/status/freshness, "N blocking" when findings block; "not
#                            recorded" when absent
#       blockers             evaluator reasons in state `blocked` as "CODE: message (ref)", or text
#                            starting "none" (chosen wording; absence never proves readiness)
#       limitations          every other evaluator reason, same format (chosen name: holds missing,
#                            stale, malformed and unfinished evidence and attestation notes)
#       source               one row per source artifact, naming its Markdown and sidecar paths
#   state.sh --delivery (plan Step 3): the same table on stdout, byte-identical to the helper's; a
#     refusal is one line on stdout with exit 0 and no tab (the existing refusal convention); a
#     helper runtime failure exits non-zero; a missing helper names /t4:sync-sdlc. Chosen wordings:
#     combined modes say they "do not combine" (or "cannot be combined"/"mutually exclusive"), a
#     missing ID says "delivery ID", a malformed one shows the form d-YYYYMMDD-xxxxxx, a repeated
#     --delivery says "once"/"more than one"/"twice"/"duplicate".
set -euo pipefail
cd "$(dirname "$0")/../../.."
group="${1:-all}"
case "$group" in
	all | helper | cli) ;;
	*) echo "check-delivery-status: unknown group '$group' (expected: helper, cli)" >&2; exit 2 ;;
esac
# Disposable fixtures stay in the project workspace.
export TMPDIR="$PWD/ai-factory/runs/tmp"
mkdir -p "$TMPDIR"
DELIVERY_STATUS_GROUP="$group" node <<'NODE'
"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const { spawn, spawnSync, execFileSync } = require("node:child_process");

const PLUGIN = process.cwd();
const MAKE = path.join(PLUGIN, "skills/ai-layout/templates/ai-factory/make");
const HELPER = path.join(MAKE, "delivery-status.js");
const HELPER_REL = "skills/ai-layout/templates/ai-factory/make/delivery-status.js";
const STATE = path.join(PLUGIN, "skills/ai-layout/scripts/state.sh");
const FIXTURES = path.join(PLUGIN, "skills/ai-layout/fixtures/contracts");
const contracts = require(path.join(MAKE, "contracts.js"));
const { boundary } = require(path.join(MAKE, "safe-files.js"));
const GROUP = process.env.DELIVERY_STATUS_GROUP || "all";
const scratch = boundary(path.join(PLUGIN, "ai-factory")).scratch(path.join(PLUGIN, "ai-factory/runs/tmp"));

const clean = { ...process.env };
for (const key of ["JSON", "DELIVERY", "STEP", "PHASE", "REQUIRE", "CONTRACT_FIXTURE_EXIT", "CONTRACT_FIXTURE_RED_EXIT", "CLAUDE_PLUGIN_ROOT", "STATUS_SENTINEL", "GIT_DIR", "GIT_WORK_TREE"])
	delete clean[key];

const SPEC = "ai-factory/specs/0001-csv-export.md";
const PLAN = "ai-factory/plans/0001-csv-export.md";
const SPEC_SIDE = "ai-factory/specs/0001-csv-export.contract.json";
const PLAN_SIDE = "ai-factory/plans/0001-csv-export.contract.json";
const QUICK = "ai-factory/quick/fix-date-format.md";
const QUICK_SIDE = "ai-factory/quick/fix-date-format.contract.json";
const ACS = ["AC1", "AC2", "AC3"];
const QCS = ["QC1", "QC2"];
const FIELDS = ["delivery", "kind", "progress", "readiness", "verified", "attested", "remaining", "unknown", "latest verification", "review", "blockers", "limitations"];
const PROGRESS = ["planning", "implementation", "verification-unproven", "review-pending", "ready", "unknown"];
const READINESS = ["ready", "incomplete", "unverified", "blocked"];

// --- sentinels: anything executed during a read leaves a line behind -------------------------
const BIN = path.join(scratch, "sentinel-bin");
fs.mkdirSync(BIN);
for (const name of ["make", "claude", "codex"])
	fs.writeFileSync(path.join(BIN, name), `#!/bin/sh\nprintf '%s %s\\n' "${name}" "$*" >> "\${STATUS_SENTINEL:-/dev/null}"\nexit 97\n`, { mode: 0o755 });
const sentinelCommand = (exit) =>
	"// Fixture verification command. It appends to STATUS_SENTINEL when that is set — only the\n" +
	"// status checks set it, so a status read that executed a declared verification is caught.\n" +
	"const sentinel = process.env.STATUS_SENTINEL;\n" +
	'if (sentinel) require("node:fs").appendFileSync(sentinel, `verification ${process.argv.slice(2).join(" ")}\\n`);\n' +
	`process.exit(${exit});\n`;

// --- fixtures ------------------------------------------------------------------------------
const git = (dir, ...args) =>
	execFileSync("git", ["-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", ...args], { cwd: dir, stdio: "pipe" });
const read = (dir, file) => fs.readFileSync(path.join(dir, file), "utf8");
const write = (dir, file, text) => fs.writeFileSync(path.join(dir, file), text);
const json = (dir, file) => JSON.parse(read(dir, file));
const writeJson = (dir, file, value) => write(dir, file, `${JSON.stringify(value, null, 2)}\n`);
const CONFIG = { schema: "t4-contracts-config", version: 1, code_scope: { include: ["**"], exclude: [] } };

function project(name, { helper = true } = {}) {
	const dir = fs.mkdtempSync(path.join(scratch, `${name}-`));
	fs.cpSync(path.join(FIXTURES, name), dir, { recursive: true });
	fs.mkdirSync(path.join(dir, "test"), { recursive: true });
	write(dir, "test/pass.js", sentinelCommand("Number(process.env.CONTRACT_FIXTURE_EXIT || 0)"));
	if (name === "planned") write(dir, "test/red.js", sentinelCommand("Number(process.env.CONTRACT_FIXTURE_RED_EXIT ?? 1)"));
	fs.mkdirSync(path.join(dir, "ai-factory/make"), { recursive: true });
	for (const file of ["contracts.js", "gate.js", "safe-files.js", "delivery-report.js"])
		fs.copyFileSync(path.join(MAKE, file), path.join(dir, "ai-factory/make", file));
	if (helper && fs.existsSync(HELPER)) fs.copyFileSync(HELPER, path.join(dir, "ai-factory/make/delivery-status.js"));
	fs.mkdirSync(path.join(dir, "ai-factory/contracts"), { recursive: true });
	writeJson(dir, "ai-factory/contracts/config.json", CONFIG);
	git(dir, "init", "-q", "-b", "main");
	git(dir, "add", "-A");
	git(dir, "commit", "-q", "-m", "fixture");
	return dir;
}
function policy(dir, completion) {
	writeJson(dir, "ai-factory/contracts/config.json", { ...json(dir, "ai-factory/contracts/config.json"), completion });
}
async function record(dir, id, { step, phase, exit, redExit, notRun, reason } = {}) {
	const saved = { ...process.env };
	if (exit !== undefined) process.env.CONTRACT_FIXTURE_EXIT = String(exit);
	if (redExit !== undefined) process.env.CONTRACT_FIXTURE_RED_EXIT = String(redExit);
	try {
		return await contracts.record({ ctx: contracts.context(dir), delivery: id, step, phase, notRun, reason });
	} finally {
		for (const key of Object.keys(process.env)) if (!(key in saved)) delete process.env[key];
		Object.assign(process.env, saved);
	}
}
const tick = (dir, step, mark = "x") =>
	write(dir, PLAN, read(dir, PLAN).replace(new RegExp(`^- \\[.\\] \\*\\*Step ${step} `, "m"), `- [${mark}] **Step ${step} `));
function review(dir, id, { verdict = "approve", findings = [] } = {}) {
	const approved = verdict === "approve" && !findings.some((f) => f.severity === "blocker");
	contracts.recordReview({ root: dir, delivery: id, approved, verdict, findings, tool: "claude", outputHash: "0".repeat(64) });
}
async function planned({ red = false, steps = 0, ticks = steps, final = false, reviewed = false, plan = true, prepare, helper = true } = {}) {
	const dir = project("planned", { helper });
	if (prepare) prepare(dir);
	contracts.init("spec", SPEC, { ctx: contracts.context(dir) });
	if (plan) contracts.init("plan", PLAN, { ctx: contracts.context(dir), spec: SPEC });
	const id = json(dir, SPEC_SIDE).delivery_id;
	if (red) await record(dir, id, { step: "S1", phase: "red" });
	for (let step = 1; step <= steps; step++) await record(dir, id, { step: `S${step}` });
	for (let step = 1; step <= ticks; step++) tick(dir, step);
	if (final) await record(dir, id, { phase: "final" });
	if (reviewed) review(dir, id);
	return { dir, id };
}
function quick({ helper = true } = {}) {
	const dir = project("quick", { helper });
	contracts.init("quick", QUICK, { ctx: contracts.context(dir) });
	return { dir, id: json(dir, QUICK_SIDE).delivery_id };
}
const evidence = (id, name) => `ai-factory/evidence/${id}/${name}`;
function stamp(dir, id, name, finishedAt) {
	const file = evidence(id, name);
	writeJson(dir, file, { ...json(dir, file), finished_at: finishedAt });
}
function touchLater(dir, file, seconds) {
	const at = new Date(Date.now() + seconds * 1000);
	fs.utimesSync(path.join(dir, file), at, at);
}

// --- observation: every read is proved read-only and non-executing --------------------------
function tree(dir) {
	const out = [];
	const walk = (at) => {
		for (const name of fs.readdirSync(at).sort()) {
			if (at === dir && name === ".git") continue;
			const file = path.join(at, name);
			const rel = path.relative(dir, file);
			const stat = fs.lstatSync(file);
			if (stat.isSymbolicLink()) out.push(`L ${rel} -> ${fs.readlinkSync(file)}`);
			else if (stat.isDirectory()) {
				out.push(`D ${rel}`);
				walk(file);
			} else out.push(`F ${rel} ${stat.mode.toString(8)} ${crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex")}`);
		}
	};
	walk(dir);
	return out;
}
function sameTree(before, after, label) {
	const a = new Set(before);
	const b = new Set(after);
	const gone = before.filter((line) => !b.has(line));
	const added = after.filter((line) => !a.has(line));
	assert.ok(!gone.length && !added.length, `${label}: the read created, changed or deleted files — status is read-only (AC5)\n${[...gone.map((l) => `- ${l}`), ...added.map((l) => `+ ${l}`)].slice(0, 12).join("\n")}`);
}
let serial = 0;
function observed(dirs, label, run) {
	const sentinel = path.join(scratch, `sentinel-${++serial}`);
	const before = dirs.map(tree);
	const env = { ...clean, PATH: `${BIN}${path.delimiter}${process.env.PATH}`, STATUS_SENTINEL: sentinel };
	const result = run(env);
	dirs.forEach((dir, index) => sameTree(before[index], tree(dir), label));
	assert.ok(
		!fs.existsSync(sentinel),
		`${label}: the read executed a verification command or dispatched work; inspection must never run tests, review or workflow tasks (AC5):\n${fs.existsSync(sentinel) ? fs.readFileSync(sentinel, "utf8") : ""}`,
	);
	return { status: result.status, signal: result.signal, stdout: result.stdout || "", stderr: result.stderr || "" };
}
function helper(dir, args, { cwd, env: extra = {}, also = [] } = {}) {
	assert.ok(fs.existsSync(HELPER), `${HELPER_REL} does not exist yet — the read-only presentation helper is plan 0019 Step 2; fixture setup for this case succeeded`);
	const file = path.join(dir, "ai-factory/make/delivery-status.js");
	assert.ok(fs.existsSync(file), "the fixture did not receive a copy of the helper");
	return observed([dir, ...also], `delivery-status.js ${args.join(" ")}`, (env) =>
		spawnSync(process.execPath, [file, ...args], { cwd: cwd || dir, env: { ...env, ...extra }, encoding: "utf8" }),
	);
}
function state(dir, args, { argv, cwd, env: extra = {}, also = [] } = {}) {
	return observed([dir, ...also], `state.sh ${args.join(" ")}`, (env) =>
		spawnSync("bash", [STATE, ...(argv || [dir, PLUGIN, ...args])], { cwd: cwd || PLUGIN, env: { ...env, ...extra }, encoding: "utf8" }),
	);
}
const both = (result) => `${result.stdout}${result.stderr}`;
const lines = (text) => text.split("\n").filter((line) => line.trim());
function noAbsolute(text, dir, label) {
	for (const form of new Set([dir, fs.realpathSync(dir), scratch, fs.realpathSync(scratch)]))
		assert.ok(!text.includes(form), `${label}: output names an absolute path (${form}); sources are repository-relative\n${text}`);
}

// --- the table -----------------------------------------------------------------------------
function table(text, label) {
	const all = text.replace(/\n$/, "").split("\n");
	assert.equal(all[0], "field\tvalue", `${label}: expected the detail table's header "field<TAB>value" on the first line, got:\n${text}`);
	const rows = all.slice(1).map((line, index) => {
		const parts = line.split("\t");
		assert.equal(parts.length, 2, `${label}: line ${index + 2} is not one field and one value: ${JSON.stringify(line)}`);
		return parts;
	});
	const count = (name) => rows.filter(([field]) => field === name).length;
	for (const name of FIELDS) assert.equal(count(name), 1, `${label}: field "${name}" must appear exactly once\n${text}`);
	assert.ok(count("source") >= 1, `${label}: no source row names the artifacts this status was read from (AC1)\n${text}`);
	const get = (name) => rows.find(([field]) => field === name)?.[1];
	const progress = get("progress").split(/\s/)[0];
	const readiness = get("readiness").split(/\s/)[0];
	assert.ok(PROGRESS.includes(progress), `${label}: progress "${get("progress")}" does not start with one of ${PROGRESS.join(", ")}`);
	assert.ok(READINESS.includes(readiness), `${label}: readiness "${get("readiness")}" does not start with one of ${READINESS.join(", ")}`);
	return { text, rows, get, all: (name) => rows.filter(([field]) => field === name).map(([, v]) => v), progress, readiness };
}
function detail(dir, id, label = "status") {
	const result = helper(dir, [id]);
	assert.equal(result.status, 0, `${label}: the helper exited ${result.status}; a shown status exits 0 whatever its readiness\nstdout:${result.stdout}\nstderr:${result.stderr}`);
	assert.equal(result.stderr, "", `${label}: a shown status writes nothing to stderr: ${result.stderr}`);
	const t = table(result.stdout, label);
	assert.equal(t.get("delivery"), id, `${label}: the delivery row does not name ${id}`);
	noAbsolute(result.stdout, dir, label);
	return t;
}
const idsIn = (value) => value.match(/\b(?:AC|QC)\d+\b/g) || [];
function groups(t, declared, label = "status") {
	const g = {};
	for (const name of ["verified", "attested", "remaining", "unknown"]) {
		g[name] = idsIn(t.get(name));
		if (!g[name].length) assert.match(t.get(name), /^none\b/, `${label}: an empty ${name} group reads "none", got "${t.get(name)}"`);
	}
	const seen = [...g.verified, ...g.attested, ...g.remaining, ...g.unknown];
	assert.deepEqual([...seen].sort(), [...declared].sort(), `${label}: every declared criterion appears in exactly one group (AC1)\n${t.text}`);
	return g;
}
function refusal(result, label) {
	assert.equal(result.status, 2, `${label}: a refusal exits 2\nstdout:${result.stdout}\nstderr:${result.stderr}`);
	assert.equal(result.stdout, "", `${label}: a refusal prints no table: ${result.stdout}`);
	assert.equal(lines(result.stderr).length, 1, `${label}: a refusal is one line on stderr: ${result.stderr}`);
	return result.stderr;
}
const notReady = (t, label) => {
	assert.notEqual(t.readiness, "ready", `${label}: readiness claims ready\n${t.text}`);
	assert.notEqual(t.progress, "ready", `${label}: progress claims ready\n${t.text}`);
};

// --- registry ------------------------------------------------------------------------------
const cases = [];
const test = (group, name, fn) => cases.push({ group, name, fn });

// ============================== helper group (plan 0019 Step 2) ==============================
test("helper", "helper-planned-detail", async () => {
	const { dir, id } = await planned({ red: true, steps: 3, final: true, reviewed: true });
	const t = detail(dir, id, "complete planned delivery");
	assert.equal(t.get("kind"), "planned");
	assert.equal(t.readiness, "ready", t.text);
	assert.equal(t.progress, "ready", t.text);
	assert.match(t.get("steps"), /^3 of 3 ticked/, t.text);
	assert.deepEqual(groups(t, ACS).verified, ACS);
	const latest = t.get("latest verification");
	for (const part of [evidence(id, "final.json"), "final", "expects pass", "passed", "valid"]) assert.ok(latest.includes(part), `latest verification lacks "${part}": ${latest}`);
	assert.ok(!latest.includes("review.json"), "review is not verification");
	assert.match(t.get("review"), /approve/);
	assert.match(t.get("review"), /valid/);
	assert.match(t.get("blockers"), /^none/);
	const sources = t.all("source").join("\n");
	for (const file of [SPEC, PLAN, SPEC_SIDE, PLAN_SIDE]) assert.ok(sources.includes(file), `source rows do not name ${file}:\n${sources}`);
});
test("helper", "helper-quick-detail", async () => {
	const { dir, id } = quick();
	let t = detail(dir, id, "unticked quick delivery");
	assert.equal(t.get("kind"), "quick");
	assert.equal(t.progress, "implementation", t.text);
	assert.match(t.get("checks"), /^0 of 2 ticked/, t.text);
	assert.deepEqual(groups(t, QCS).remaining, QCS);
	assert.ok(!t.text.includes("ai-factory/specs/"), "no spec is fabricated for quick work");
	assert.ok(t.all("source").join("\n").includes(QUICK));
	assert.match(t.get("review"), /not recorded/);
	write(dir, QUICK, read(dir, QUICK).replace(/- \[ \]/g, "- [x]"));
	t = detail(dir, id, "ticked quick delivery without evidence");
	assert.equal(t.progress, "verification-unproven", t.text);
	assert.deepEqual(groups(t, QCS).verified, [], "ticked checks alone verify nothing (AC3)");
	notReady(t, "ticked quick delivery without evidence");
	await record(dir, id, {});
	t = detail(dir, id, "verified quick delivery");
	assert.equal(t.readiness, "ready", t.text);
	assert.equal(t.progress, "ready", t.text);
	assert.deepEqual(groups(t, QCS).verified, QCS);
	assert.ok(t.get("latest verification").includes(evidence(id, "quick.json")));
});
test("helper", "helper-legacy-migrated", async () => {
	const dir = project("legacy");
	contracts.migrate({ root: dir, write: true });
	const id = json(dir, "ai-factory/specs/0001-old-feature.contract.json").delivery_id;
	const t = detail(dir, id, "migrated legacy delivery");
	notReady(t, "migrated legacy delivery");
	assert.ok(t.text.includes("L_REVIEW_REQUIRED"), `a migrated draft names its review requirement:\n${t.text}`);
	assert.deepEqual(groups(t, ["AC1", "AC2"]).verified, [], "a migrated, done plan proves nothing (AC3)");
});
test("helper", "helper-refuses-identity", async () => {
	const { dir, id } = await planned({ steps: 1 });
	refusal(helper(dir, []), "no delivery ID");
	for (const bad of ["../../etc", "d-2026-bad", "d-20260930-ABCDEF", "", "d-20260930-000000/../x", SPEC, `${id} extra`])
		refusal(helper(dir, [bad]), `malformed ID ${JSON.stringify(bad)}`);
	refusal(helper(dir, [id, id]), "two IDs");
	assert.match(refusal(helper(dir, ["d-20260930-000000"]), "unknown delivery"), /d-20260930-000000/);
	refusal(helper(dir, ["$(touch pwned)"]), "shell text");
	assert.ok(!fs.existsSync(path.join(dir, "pwned")), "an argument was evaluated by a shell");
});
test("helper", "helper-duplicate-identity", async () => {
	const { dir, id } = await planned({ steps: 3, final: true, reviewed: true });
	fs.copyFileSync(path.join(dir, SPEC), path.join(dir, "ai-factory/specs/0002-copy.md"));
	fs.copyFileSync(path.join(dir, SPEC_SIDE), path.join(dir, "ai-factory/specs/0002-copy.contract.json"));
	const message = refusal(helper(dir, [id]), "two specs claim one delivery");
	for (const name of ["0001-csv-export", "0002-copy"]) assert.ok(message.includes(name), `the duplicate refusal names ${name}: ${message}`);
});
test("helper", "helper-contracts-disabled", async () => {
	const { dir, id } = await planned({ steps: 3, final: true, reviewed: true });
	fs.unlinkSync(path.join(dir, "ai-factory/contracts/config.json"));
	assert.match(refusal(helper(dir, [id]), "contracts not enabled"), /contracts[\s\S]*enable|enable[\s\S]*contracts/i);
	write(dir, "ai-factory/contracts/config.json", "{");
	assert.match(refusal(helper(dir, [id]), "unreadable contracts config"), /config\.json/);
});
test("helper", "helper-boundaries", async () => {
	const { dir, id } = await planned({ steps: 3, final: true, reviewed: true });
	const sink = fs.mkdtempSync(path.join(scratch, "sink-"));
	fs.renameSync(path.join(dir, `ai-factory/evidence/${id}`), path.join(sink, "evidence"));
	fs.symlinkSync(path.join(sink, "evidence"), path.join(dir, `ai-factory/evidence/${id}`));
	let result = helper(dir, [id], { also: [sink] });
	let t = table(result.stdout, "symlinked evidence directory");
	notReady(t, "symlinked evidence directory");
	assert.ok(t.text.includes("E_SYMLINK"), t.text);
	assert.deepEqual(groups(t, ACS).verified, [], "evidence behind a symlink proves nothing");
	noAbsolute(t.text, dir, "symlinked evidence directory");
	fs.unlinkSync(path.join(dir, `ai-factory/evidence/${id}`));
	fs.renameSync(path.join(sink, "evidence"), path.join(dir, `ai-factory/evidence/${id}`));
	const final = json(dir, evidence(id, "final.json"));
	writeJson(dir, evidence(id, "final.json"), { ...final, output_ref: "ai-factory/runs/evidence/../../../etc/passwd" });
	t = detail(dir, id, "escaping output reference");
	notReady(t, "escaping output reference");
	assert.ok(t.text.includes("E_PATH_ESCAPE"), t.text);
	assert.ok(!t.text.includes("/etc/passwd") || t.text.includes("E_PATH_ESCAPE"), "an escaping reference is never followed");
	writeJson(dir, evidence(id, "final.json"), final);
	fs.copyFileSync(path.join(dir, SPEC), path.join(sink, "spec.md"));
	fs.unlinkSync(path.join(dir, SPEC));
	fs.symlinkSync(path.join(sink, "spec.md"), path.join(dir, SPEC));
	result = helper(dir, [id], { also: [sink] });
	t = table(result.stdout, "symlinked spec");
	notReady(t, "symlinked spec");
	assert.ok(t.text.includes("E_SYMLINK"), t.text);
	noAbsolute(t.text, dir, "symlinked spec");
});
test("helper", "helper-malformed-evidence", async () => {
	const { dir, id } = await planned({ steps: 3, final: true, reviewed: true });
	write(dir, evidence(id, "S2-step.json"), "{");
	const t = detail(dir, id, "malformed evidence");
	notReady(t, "malformed evidence");
	assert.ok(t.get("limitations").includes("E_MALFORMED") && t.get("limitations").includes("S2-step.json"), `limitations name the malformed record:\n${t.text}`);
	assert.ok(!groups(t, ACS).verified.includes("AC2"), "malformed evidence verifies nothing");
	assert.match(t.get("latest verification"), /^unknown\b/, "a record whose time cannot be read leaves chronology unknown");
});
test("helper", "helper-drift", async () => {
	let { dir, id } = await planned({ steps: 3, final: true, reviewed: true });
	write(dir, SPEC, read(dir, SPEC).replace("one line per row", "one line per row, in order"));
	let t = detail(dir, id, "spec changed after verification");
	notReady(t, "spec drift");
	assert.equal(t.readiness, "unverified", t.text);
	assert.ok(t.get("limitations").includes("S_SPEC_CHANGED"), t.text);
	assert.deepEqual(groups(t, ACS).verified, [], "stale evidence verifies nothing (AC2)");
	assert.match(t.get("latest verification"), /stale/);
	({ dir, id } = await planned({ steps: 3, final: true, reviewed: true }));
	write(dir, "src/export.js", `${read(dir, "src/export.js")}// later edit\n`);
	t = detail(dir, id, "code changed after verification and review");
	notReady(t, "code drift");
	assert.ok(t.get("limitations").includes("S_CODE_CHANGED"), t.text);
	assert.match(t.get("review"), /stale/, "a review of older code is stale");
});
test("helper", "helper-failed-check", async () => {
	const { dir, id } = await planned({ steps: 1 });
	await record(dir, id, { step: "S2", exit: 3 });
	tick(dir, 2);
	const t = detail(dir, id, "failed required check");
	assert.equal(t.readiness, "blocked", t.text);
	assert.ok(t.get("blockers").includes("E_EVIDENCE_FAILED") && t.get("blockers").includes(evidence(id, "S2-step.json")), t.text);
	assert.ok(t.get("remaining").includes("AC2 (failed)"), `an explicit failure stays visible as failed:\n${t.text}`);
	assert.match(t.get("latest verification"), /S2-step\.json.*failed/, t.text);
	assert.equal(t.progress, "implementation", t.text);
});
test("helper", "helper-interrupted-verification", async () => {
	const { dir, id } = await planned({ steps: 3 });
	const plan = json(dir, PLAN_SIDE);
	plan.steps[2].verify = [{ argv: ["node", "test/slow.js"], phase: "final" }];
	writeJson(dir, PLAN_SIDE, plan);
	const child = spawn(process.execPath, [path.join(dir, "ai-factory/make/contracts.js"), "record", "--delivery", id, "--phase", "final"], { cwd: dir, env: clean, stdio: "ignore" });
	await new Promise((resolve) => setTimeout(resolve, 700));
	child.kill("SIGINT");
	assert.equal(await new Promise((resolve) => child.once("close", resolve)), 130, "fixture: the final run was interrupted");
	review(dir, id);
	const t = detail(dir, id, "interrupted final verification");
	notReady(t, "interrupted verification");
	assert.ok(t.get("limitations").includes("INTERRUPTED"), t.text);
	assert.ok(!t.get("blockers").includes("E_EVIDENCE_FAILED"), "an interruption is not a known failure");
	assert.match(t.get("latest verification"), /interrupted/i);
	assert.deepEqual(groups(t, ACS).verified, [], "an interrupted run proves nothing");
});
test("helper", "helper-approval-with-blockers", async () => {
	const { dir, id } = await planned({ steps: 3, final: true });
	review(dir, id, { verdict: "approve", findings: [{ severity: "blocker", file: "src/export.js", line: 1, issue: "Rows lose their order" }] });
	let t = detail(dir, id, "approval carrying a blocker");
	assert.equal(t.readiness, "blocked", t.text);
	notReady(t, "approval with blockers");
	assert.ok(t.get("blockers").includes("REVIEW_BLOCKER") && t.get("blockers").includes(evidence(id, "review.json")), t.text);
	assert.match(t.get("review"), /approve/);
	assert.match(t.get("review"), /1 blocking/);
	review(dir, id, { verdict: "request_changes", findings: [{ severity: "major", file: "src/export.js", line: 2, issue: "Naming" }] });
	t = detail(dir, id, "changes requested");
	assert.equal(t.readiness, "incomplete", t.text);
	assert.ok(t.get("limitations").includes("REVIEW_CHANGES"), t.text);
	assert.match(t.get("blockers"), /^none/);
});
test("helper", "helper-attestation", async () => {
	const { dir, id } = await planned({ steps: 1, ticks: 1 });
	await record(dir, id, { step: "S2", notRun: true, reason: "needs a printer" });
	tick(dir, 2);
	await record(dir, id, { step: "S3" });
	tick(dir, 3);
	await record(dir, id, { phase: "final" });
	review(dir, id);
	contracts.attest({ root: dir, delivery: id, criterion: "AC2", actor: "QA lead", rationale: "Printed output checked by hand", source: "DEMO-12 comment 3" });
	let t = detail(dir, id, "attestation policy off");
	let g = groups(t, ACS);
	assert.deepEqual(g.attested, [], "an attestation policy does not allow is not counted");
	assert.ok(g.unknown.includes("AC2"), t.text);
	assert.ok(t.text.includes("ATTESTATION_IGNORED"), "an ignored attestation stays visible");
	notReady(t, "attestation policy off");
	policy(dir, { allow_attestation: true });
	t = detail(dir, id, "attestation policy on");
	g = groups(t, ACS);
	assert.deepEqual(g.attested, ["AC2"], t.text);
	assert.deepEqual(g.verified, ["AC1", "AC3"], "attestation is visibly distinct from executable proof");
	assert.equal(t.readiness, "ready", t.text);
});
test("helper", "helper-expected-red", async () => {
	let { dir, id } = await planned({ red: true });
	let t = detail(dir, id, "red evidence only");
	const latest = t.get("latest verification");
	for (const part of [evidence(id, "S1-red.json"), "red", "expects fail"]) assert.ok(latest.includes(part), `latest verification lacks "${part}": ${latest}`);
	assert.ok(!/\bfinal\b/.test(latest), "expected-red evidence is not final verification");
	assert.deepEqual(groups(t, ACS).verified, [], "a red run proves no criterion");
	assert.equal(t.progress, "implementation", t.text);
	({ dir, id } = await planned({}));
	await record(dir, id, { step: "S1", phase: "red", redExit: 0 });
	t = detail(dir, id, "red tests that passed");
	assert.ok(t.get("blockers").includes("E_RED_PASSED"), t.text);
	notReady(t, "red passed");
});
test("helper", "helper-chronology", async () => {
	const { dir, id } = await planned({ red: true, steps: 3 });
	review(dir, id);
	stamp(dir, id, "S1-red.json", "2026-01-01T00:00:01Z");
	stamp(dir, id, "S1-step.json", "2026-01-01T00:00:03Z");
	stamp(dir, id, "S2-step.json", "2026-01-01T00:00:05Z");
	stamp(dir, id, "S3-step.json", "2026-01-01T00:00:04Z");
	stamp(dir, id, "review.json", "2026-01-02T00:00:00Z");
	touchLater(dir, evidence(id, "S1-step.json"), 3600);
	let latest = detail(dir, id, "distinct timestamps").get("latest verification");
	assert.ok(latest.includes(evidence(id, "S2-step.json")), `the newest finished_at wins, never file mtime or review: ${latest}`);
	stamp(dir, id, "S3-step.json", "2026-01-01T01:00:00+01:00");
	touchLater(dir, evidence(id, "S3-step.json"), 7200);
	latest = detail(dir, id, "offset timestamp").get("latest verification");
	assert.ok(latest.includes(evidence(id, "S2-step.json")), `timestamps compare as instants, not strings: ${latest}`);
	stamp(dir, id, "S3-step.json", "2026-01-01T00:00:05Z");
	latest = detail(dir, id, "tied timestamps").get("latest verification");
	assert.ok(latest.includes(evidence(id, "S2-step.json")), `a tie breaks on ascending evidence path: ${latest}`);
	stamp(dir, id, "S3-step.json", "sometime on Tuesday");
	latest = detail(dir, id, "invalid timestamp").get("latest verification");
	assert.match(latest, /^unknown\b/, `an invalid timestamp leaves chronology unknown: ${latest}`);
});
test("helper", "helper-progress-table", async () => {
	let { dir, id } = await planned({ plan: false });
	let t = detail(dir, id, "spec only");
	assert.equal(t.progress, "planning", t.text);
	assert.deepEqual(groups(t, ACS).remaining, ACS);
	({ dir, id } = await planned({}));
	t = detail(dir, id, "blank plan");
	assert.equal(t.progress, "implementation", t.text);
	assert.match(t.get("steps"), /^0 of 3 ticked/, t.text);
	assert.deepEqual(groups(t, ACS).remaining, ACS);
	({ dir, id } = await planned({ steps: 1 }));
	t = detail(dir, id, "one step done");
	assert.equal(t.progress, "implementation", t.text);
	assert.match(t.get("steps"), /^1 of 3 ticked/, t.text);
	assert.ok(!groups(t, ACS).verified.includes("AC1"), "a passing step before final verification is not a verified criterion");
	({ dir, id } = await planned({ steps: 0, ticks: 3 }));
	t = detail(dir, id, "every box ticked, nothing recorded");
	assert.equal(t.progress, "verification-unproven", t.text);
	assert.deepEqual(groups(t, ACS).verified, []);
	({ dir, id } = await planned({ steps: 3, final: true }));
	t = detail(dir, id, "verified, review missing");
	assert.equal(t.progress, "review-pending", t.text);
	assert.match(t.get("review"), /not recorded/);
	notReady(t, "review missing");
	review(dir, id);
	assert.equal(detail(dir, id, "reviewed").progress, "ready");
	({ dir, id } = await planned({ steps: 3, final: true, reviewed: true }));
	write(dir, PLAN, "# Plan 0001 — CSV export\n\n**Spec:** `ai-factory/specs/0001-csv-export.md`\n");
	t = detail(dir, id, "plan emptied after verification");
	assert.equal(t.progress, "unknown", `a plan whose steps vanished is contradictory, not finished:\n${t.text}`);
	notReady(t, "emptied plan");
	assert.deepEqual(groups(t, ACS).verified, []);
});
test("helper", "helper-withdrawn-plan", async () => {
	const { dir, id } = await planned({
		prepare: (d) => write(d, PLAN, read(d, PLAN).replace(/(\*\*Step 2 — Quote commas\.\*\*.*\n)/, "$1  **Result — Step 2 withdrawn; not run.**\n")),
	});
	for (const step of [1, 3]) {
		await record(dir, id, { step: `S${step}` });
		tick(dir, step);
	}
	await record(dir, id, { phase: "final" });
	review(dir, id);
	const t = detail(dir, id, "plan with a withdrawn step");
	assert.match(t.get("steps"), /^2 of 2 ticked/, t.text);
	assert.match(t.get("steps"), /withdrawn/, t.text);
	const g = groups(t, ACS);
	assert.ok(!g.verified.includes("AC2") && !g.attested.includes("AC2"), "withdrawing a step never proves its criterion");
	assert.ok(t.get("remaining").includes("AC2 (uncovered)"), t.text);
	notReady(t, "withdrawn step");
});
test("helper", "helper-no-false-success", async () => {
	let { dir, id } = await planned({ steps: 0, ticks: 3 });
	const before = helper(dir, [id]).stdout;
	let t = table(before, "ticks and mappings only");
	notReady(t, "ticks and mappings only");
	assert.deepEqual(groups(t, ACS).verified, [], "ticks and AC mappings alone prove nothing (AC3)");
	fs.mkdirSync(path.join(dir, `ai-factory/reports/${id}`), { recursive: true });
	writeJson(dir, `ai-factory/reports/${id}/completion.json`, { schema: "t4-delivery-report", version: 1, status: "ready", criteria: ACS.map((ac) => ({ id: ac, result: "passed" })) });
	fs.mkdirSync(path.join(dir, "ai-factory/runs/lifecycle/events"), { recursive: true });
	write(dir, "ai-factory/runs/lifecycle/events/run-1.jsonl", `${JSON.stringify({ delivery_id: id, task: "run", outcome: "success" })}\n`);
	write(dir, "ai-factory/runs/log.csv", `2026-01-01T00:00:00Z,run,${id},success\n2026-01-01T00:01:00Z,check,${id},success\n`);
	assert.equal(helper(dir, [id]).stdout, before, "a saved report, lifecycle success or run log changed the status; only current artifacts and evidence count");
	({ dir, id } = await planned({ steps: 3, final: true, reviewed: true }));
	fs.unlinkSync(path.join(dir, PLAN));
	t = detail(dir, id, "plan deleted");
	notReady(t, "plan deleted");
	assert.ok(t.text.includes("E_MISSING_FILE"), t.text);
	assert.deepEqual(groups(t, ACS).verified, []);
	({ dir, id } = await planned({ steps: 3, final: true, reviewed: true }));
	for (const file of [SPEC, SPEC_SIDE, PLAN, PLAN_SIDE]) fs.unlinkSync(path.join(dir, file));
	const orphan = helper(dir, [id]);
	// Chosen latitude: an evidence-only delivery may be refused or shown — never as a success.
	if (orphan.status === 0) {
		t = table(orphan.stdout, "evidence without artifacts");
		notReady(t, "evidence without artifacts");
		assert.equal(t.progress, "unknown", t.text);
		assert.ok(!idsIn(t.get("verified")).length, t.text);
	} else refusal(orphan, "evidence without artifacts");
});
test("helper", "helper-deterministic", async () => {
	const { dir, id } = await planned({ red: true, steps: 2 });
	const first = helper(dir, [id]);
	assert.equal(first.status, 0, first.stderr);
	assert.equal(helper(dir, [id]).stdout, first.stdout, "two reads of the same tree differ (AC4)");
	assert.equal(helper(dir, [id], { cwd: os.tmpdir() }).stdout, first.stdout, "the working directory changed the answer (AC4)");
	assert.equal(helper(dir, [id], { env: { CI: "1", TERM: "dumb" } }).stdout, first.stdout, "a headless environment changed the answer (AC4)");
	table(first.stdout, "deterministic read");
});

// ================================ cli group (plan 0019 Step 3) ================================
const NOT_A_FLAG = /is not a flag/;
const LISTING_HEADER = "kind\tnumber\tstate\tpath\tstep\tdetail";
function cliTable(dir, id, label, options) {
	const result = state(dir, ["--delivery", id], options);
	assert.equal(result.status, 0, `${label}: state --delivery exited ${result.status}\n${both(result)}`);
	assert.ok(!result.stdout.startsWith(LISTING_HEADER), `${label}: state answered --delivery with the legacy listing:\n${result.stdout}`);
	const t = table(result.stdout, `${label} (state --delivery)`);
	assert.equal(t.get("delivery"), id);
	noAbsolute(both(result), dir, label);
	return { t, result };
}
function oneLine(result, label) {
	const text = both(result);
	assert.equal(result.status, 0, `${label}: a refusal exits 0 like the other state refusals\n${text}`);
	assert.equal(lines(text).length, 1, `${label}: a refusal is exactly one line:\n${text}`);
	assert.ok(!text.includes("\t"), `${label}: a refusal prints no table row:\n${text}`);
	return text.trim();
}
test("cli", "cli-detail-planned", async () => {
	const { dir, id } = await planned({ red: true, steps: 3, final: true, reviewed: true });
	const { t, result } = cliTable(dir, id, "planned detail");
	assert.equal(t.readiness, "ready", t.text);
	assert.equal(result.stderr, "", result.stderr);
	assert.equal(result.stdout, helper(dir, [id]).stdout, "state shows the helper's table byte for byte");
});
test("cli", "cli-detail-quick", async () => {
	const { dir, id } = quick();
	const { t } = cliTable(dir, id, "quick detail");
	assert.equal(t.get("kind"), "quick");
	assert.deepEqual(groups(t, QCS).remaining, QCS);
});
test("cli", "cli-no-false-success-ticks", async () => {
	const { dir, id } = await planned({ steps: 0, ticks: 3 });
	const { t } = cliTable(dir, id, "ticked without evidence");
	notReady(t, "ticked without evidence");
	assert.equal(t.progress, "verification-unproven", t.text);
	assert.deepEqual(groups(t, ACS).verified, [], "checked boxes alone prove nothing (AC3)");
});
test("cli", "cli-no-false-success-saved-report", async () => {
	const { dir, id } = await planned({ steps: 3 });
	fs.mkdirSync(path.join(dir, `ai-factory/reports/${id}`), { recursive: true });
	writeJson(dir, `ai-factory/reports/${id}/completion.json`, { schema: "t4-delivery-report", version: 1, status: "ready" });
	const { t } = cliTable(dir, id, "saved ready report, no final evidence");
	notReady(t, "saved report");
	assert.deepEqual(groups(t, ACS).verified, [], "a saved report snapshot is not current evidence");
});
test("cli", "cli-headless-identical", async () => {
	const { dir, id } = await planned({ red: true, steps: 2 });
	const { result } = cliTable(dir, id, "headless detail");
	const again = (argv, extra = {}) => state(dir, ["--delivery", id], { argv, ...extra }).stdout;
	assert.equal(again(undefined), result.stdout, "two runs differ (AC4)");
	assert.equal(again(undefined, { cwd: os.tmpdir(), env: { CI: "1" } }), result.stdout, "cwd or CI changed the answer (AC4)");
	assert.equal(again([dir, "--delivery", id]), result.stdout, "omitting the plugin root changed the answer");
	assert.equal(again(["--delivery", id, dir, PLUGIN]), result.stdout, "argument order changed the answer");
	assert.equal(result.stdout, helper(dir, [id]).stdout, "interactive (state) and direct helper output differ (AC4)");
});
test("cli", "cli-collisions", async () => {
	const { dir, id } = await planned({ steps: 1 });
	const listing = state(dir, []).stdout;
	for (const flag of ["--done", "--next"]) {
		const a = oneLine(state(dir, ["--delivery", id, flag]), `--delivery ${flag}`);
		const b = oneLine(state(dir, [flag, "--delivery", id]), `${flag} --delivery`);
		assert.equal(a, b, `--delivery with ${flag} answers differently by order`);
		assert.match(a, /do(es)? not combine|cannot be combined|mutually exclusive/i, `--delivery with ${flag} must say the modes do not combine: ${a}`);
		assert.ok(!NOT_A_FLAG.test(a), `--delivery is a flag; calling it unknown is false: ${a}`);
		for (const name of ["--delivery", flag]) assert.ok(a.includes(name), `the refusal names ${name}: ${a}`);
		assert.notEqual(a, listing.trim());
	}
});
test("cli", "cli-missing-or-repeated-id", async () => {
	const { dir, id } = await planned({ steps: 1 });
	for (const args of [["--delivery"], ["--delivery", "--done"]]) {
		const text = oneLine(state(dir, args), args.join(" "));
		assert.match(text, /delivery id/i, `a missing ID is named as such: ${text}`);
		assert.ok(!NOT_A_FLAG.test(text), `--delivery is a flag: ${text}`);
	}
	const twice = oneLine(state(dir, ["--delivery", id, "--delivery", "d-20260101-abcdef"]), "--delivery twice");
	assert.match(twice, /once|more than one|twice|duplicate/i, twice);
});
test("cli", "cli-invalid-id", async () => {
	const { dir } = await planned({ steps: 1 });
	for (const bad of ["../../etc", SPEC, "$(touch pwned)", "d-20260930-ABCDEF"]) {
		const text = oneLine(state(dir, ["--delivery", bad]), `--delivery ${bad}`);
		assert.match(text, /d-YYYYMMDD-xxxxxx/, `a malformed ID shows the expected form: ${text}`);
		assert.ok(!NOT_A_FLAG.test(text), text);
	}
	assert.ok(!fs.existsSync(path.join(dir, "pwned")) && !fs.existsSync(path.join(PLUGIN, "pwned")), "an argument reached a shell");
});
test("cli", "cli-refusals-passed-through", async () => {
	let { dir, id } = await planned({ steps: 1 });
	let text = oneLine(state(dir, ["--delivery", "d-20260930-000000"]), "unknown delivery");
	assert.match(text, /d-20260930-000000/);
	assert.ok(!NOT_A_FLAG.test(text), text);
	fs.copyFileSync(path.join(dir, SPEC), path.join(dir, "ai-factory/specs/0002-copy.md"));
	fs.copyFileSync(path.join(dir, SPEC_SIDE), path.join(dir, "ai-factory/specs/0002-copy.contract.json"));
	text = oneLine(state(dir, ["--delivery", id]), "duplicate identity");
	assert.ok(text.includes("0002-copy"), text);
	({ dir, id } = await planned({ steps: 1 }));
	fs.unlinkSync(path.join(dir, "ai-factory/contracts/config.json"));
	text = oneLine(state(dir, ["--delivery", id]), "contracts disabled");
	assert.match(text, /contracts/i);
	assert.ok(!NOT_A_FLAG.test(text), text);
});
test("cli", "cli-absent-helper", async () => {
	const { dir, id } = await planned({ steps: 1, helper: false });
	assert.ok(!fs.existsSync(path.join(dir, "ai-factory/make/delivery-status.js")), "fixture: no helper installed");
	const text = oneLine(state(dir, ["--delivery", id]), "absent helper");
	assert.match(text, /sync-sdlc/, `a missing helper names /t4:sync-sdlc: ${text}`);
	assert.match(text, /delivery-status/, text);
	assert.ok(!NOT_A_FLAG.test(text), text);
});
test("cli", "cli-outdated-helper-modules", async () => {
	// A helper received without the make/ modules it requires is an outdated workspace: sync
	// guidance in one line, nothing written, and never a listing in its place.
	const { dir, id } = await planned({ steps: 1 });
	fs.unlinkSync(path.join(dir, "ai-factory/make/delivery-report.js"));
	const text = oneLine(state(dir, ["--delivery", id]), "outdated helper modules");
	assert.match(text, /sync-sdlc/, `an outdated workspace names /t4:sync-sdlc: ${text}`);
	assert.match(text, /delivery-report\.js/, text);
	assert.ok(!text.startsWith(LISTING_HEADER) && !NOT_A_FLAG.test(text), text);
});
test("cli", "cli-helper-runtime-failure", async () => {
	const { dir, id } = await planned({ steps: 1, helper: false });
	write(dir, "ai-factory/make/delivery-status.js", 'throw new Error("simulated helper crash");\n');
	const result = state(dir, ["--delivery", id]);
	const text = both(result);
	assert.notEqual(result.status, 0, `a helper crash is surfaced as a failure, not a refusal or a status:\n${text}`);
	assert.ok(!text.includes("\t"), `a crash prints no table:\n${text}`);
	assert.match(text, /delivery-status/, text);
});
test("cli", "cli-legacy-unchanged-with-helper", async () => {
	const { dir } = await planned({ steps: 1, helper: false });
	write(dir, "ai-factory/make/delivery-status.js", sentinelCommand(0));
	const withHelper = ["", "--done", "--next"].map((flag) => state(dir, flag ? [flag] : []).stdout);
	fs.unlinkSync(path.join(dir, "ai-factory/make/delivery-status.js"));
	const without = ["", "--done", "--next"].map((flag) => state(dir, flag ? [flag] : []).stdout);
	assert.deepEqual(withHelper, without, "an installed helper changed a legacy listing (AC6)");
	assert.ok(withHelper[0].startsWith(LISTING_HEADER), withHelper[0]);
});

// --- run -----------------------------------------------------------------------------------
(async () => {
	const selected = cases.filter((item) => GROUP === "all" || item.group === GROUP);
	const failed = [];
	for (const item of selected) {
		try {
			await item.fn();
			console.log(`ok ${item.name}`);
		} catch (error) {
			const message = String(error && error.message ? error.message : error).split("\n").slice(0, 14).join("\n    ");
			failed.push(item.name);
			console.log(`FAIL ${item.name}: ${message}`);
		}
	}
	fs.rmSync(scratch, { recursive: true, force: true });
	if (failed.length) {
		console.error(`delivery status (${GROUP}): ${failed.length} of ${selected.length} cases failed — ${failed.join(", ")}`);
		process.exitCode = 1;
	} else console.log(`delivery status ok (${GROUP}) — ${selected.length} cases`);
})().catch((error) => {
	console.error(`FAIL harness: ${error.stack || error}`);
	fs.rmSync(scratch, { recursive: true, force: true });
	process.exitCode = 1;
});
NODE
