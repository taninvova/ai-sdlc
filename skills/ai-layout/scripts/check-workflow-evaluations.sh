#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
# Offline workflow-evaluation checks; never invokes a model.
# Groups: quality, pairing, report, harness (default: every group). The harness group drives the
# live --real path against a fake codex executable on PATH, in a scratch copy of the harness.
group="${1:-all}"
case "$group" in
	all | quality | pairing | report | harness) ;;
	*) echo "check-workflow-evaluations: unknown group '$group' (expected: quality|pairing|report|harness)" >&2; exit 2 ;;
esac
EVALUATION_GROUP="$group" node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const { execFileSync, spawnSync } = require("node:child_process");
const bench = require("./skills/ai-layout/scripts/benchmark-small-tasks.js");
const fixtures = path.resolve("skills/ai-layout/fixtures/workflow-evaluations");
const rubricFile = path.join(fixtures, "rubric.json");
const rubric = JSON.parse(fs.readFileSync(rubricFile, "utf8"));
const synthetic = JSON.parse(fs.readFileSync(path.join(fixtures, "results.json"), "utf8"));
const results = synthetic.records;
const pairing = synthetic.pairing;
const base = fs.mkdtempSync(path.join(os.tmpdir(), "t4-evaluations-"));
const sha = (value) => crypto.createHash("sha256").update(value).digest("hex");
const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
	entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.join(dir, entry.name)]);
const want = (name) => process.env.EVALUATION_GROUP === "all" || process.env.EVALUATION_GROUP === name;
const passed = [], failed = [];
function check(groupName, label, fn) {
	if (!want(groupName)) return;
	try { fn(); passed.push(label); }
	catch (error) { failed.push(label); console.error(`FAIL ${label}: ${error.message.split("\n")[0]}`); }
}
function need(name) {
	assert.equal(typeof bench[name], "function", `benchmark harness exports no ${name}(): that harness behavior is not implemented`);
	return bench[name];
}
// Apply one synthetic final state over a fresh benchmark fixture, as a model run would leave it.
let runs = 0;
function materialize(id) {
	const result = results.find((r) => r.id === id);
	assert.ok(result, `synthetic result ${id}`);
	const dir = path.join(base, `${id}-${++runs}`);
	const initial = bench.makeFixture(dir, {}, bench.scenarios[result.scenario], "baseline");
	for (const [file, body] of Object.entries(result.files)) {
		fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
		fs.writeFileSync(path.join(dir, file), body);
	}
	return { result, dir, initial };
}
function run(id, options = {}) {
	const evaluateRun = need("evaluateRun");
	const oracle = options.oracle || need("loadOracle")(rubricFile);
	const { result, dir, initial } = materialize(id);
	const evaluation = evaluateRun({
		dir, scenario: result.scenario, initial, final: result.final, exit: result.exit,
		timedOut: result.timedOut, oracle, adjudication: options.adjudication,
	});
	return { evaluation, dir, initial, result };
}
const OUTCOMES = ["satisfied", "unmet", "unassessed"];
const byId = (evaluation) => Object.fromEntries(evaluation.items.map((item) => [item.id, item]));

check("quality", "requirement-evidence", () => {
	const clean = run("bug-completed-clean").evaluation;
	assert.deepEqual(clean.items.map((i) => i.id), rubric.scenarios.bug.map((i) => i.id), "one outcome per rubric item");
	for (const item of clean.items) {
		assert.ok(OUTCOMES.includes(item.outcome), `${item.id} outcome ${item.outcome}`);
		assert.ok(["requirement", "defect"].includes(item.kind), `${item.id} kind`);
		assert.ok(item.evidence && item.evidence.check, `${item.id} has evidence naming its check`);
		assert.equal(item.outcome, "satisfied", `${item.id} satisfied: ${JSON.stringify(item.evidence)}`);
	}
	assert.deepEqual(clean.missedRequirements, { count: 0, unmet: [], unassessed: [] });
	assert.equal(clean.rubric.version, rubric.version);
	// An unmet requirement carries the evaluator evidence that failed it.
	const docs = byId(run("docs-failed").evaluation);
	assert.equal(docs["docs-spelling"].outcome, "unmet");
	assert.equal(docs["docs-spelling"].evidence.exitCode, 1);
	assert.equal(docs["docs-other-content"].outcome, "unmet");
	assert.match(docs["docs-other-content"].evidence.actualSha256, /^[a-f0-9]{64}$/);
	// An evaluator error is unassessed, never unmet, and leaves the missed total unknown.
	const broken = JSON.parse(JSON.stringify(rubric));
	broken.scenarios.docs[0].check = { type: "no-such-check" };
	const brokenFile = path.join(base, "broken-rubric.json");
	fs.writeFileSync(brokenFile, JSON.stringify(broken));
	const partial = run("docs-ambiguous-claim", { oracle: need("loadOracle")(brokenFile) }).evaluation;
	const items = byId(partial);
	assert.equal(items["docs-spelling"].outcome, "unassessed");
	assert.match(items["docs-spelling"].evidence.error, /no-such-check/);
	assert.equal(items["docs-other-content"].outcome, "satisfied");
	assert.equal(partial.missedRequirements.count, null, "partially assessed requirements have no known total");
	assert.deepEqual(partial.missedRequirements.unassessed, ["docs-spelling"]);
	// A scenario without a rubric reports explicit unassessed metrics.
	const none = run("review-no-rubric").evaluation;
	assert.equal(none.rubric, null);
	assert.deepEqual(none.items, []);
	assert.equal(none.missedRequirements.count, null);
	assert.equal(none.escapedDefects.count, null);
	assert.match(none.missedRequirements.reason, /no rubric/);
});

check("quality", "escaped-defect-after-completion", () => {
	const escape = run("bug-completed-escape").evaluation;
	assert.equal(escape.completion.status, "completed");
	const items = byId(escape);
	assert.equal(items["bug-empty-sum"].outcome, "satisfied");
	assert.equal(items["bug-input-not-mutated"].outcome, "unmet");
	assert.equal(escape.escapedDefects.count, 1);
	assert.equal(escape.escapedDefects.origin, "fixture-detected");
	assert.deepEqual(escape.escapedDefects.items.map((i) => i.id), ["bug-input-not-mutated"]);
	assert.ok(escape.escapedDefects.items[0].evidence.check, "escape keeps its evidence");
	assert.equal(run("bug-completed-clean").evaluation.escapedDefects.count, 0);
});

check("quality", "exit-zero-blocked", () => {
	const blocked = run("escalation-exit-zero-blocked").evaluation;
	assert.equal(blocked.completion.process.ok, true, "the CLI exited 0");
	assert.equal(blocked.completion.reported, "blocked");
	assert.equal(blocked.completion.status, "blocked", "exit 0 alone is not completion");
	assert.equal(blocked.escapedDefects.count, null, "no escape total without reported completion");
	assert.match(blocked.escapedDefects.reason, /blocked/);
	assert.equal(byId(blocked)["esc-production-preserved"].outcome, "satisfied", "findings are retained");
	assert.equal(byId(blocked)["esc-decision-reported"].outcome, "satisfied");
	const interrupted = run("enhancement-interrupted").evaluation;
	assert.equal(interrupted.completion.status, "interrupted", "a timeout is never completion, whatever it claims");
	assert.equal(interrupted.escapedDefects.count, null);
	assert.ok(interrupted.items.length > 0, "an interrupted run keeps its findings");
	const failedRun = run("docs-failed").evaluation;
	assert.equal(failedRun.completion.status, "failed");
	assert.equal(failedRun.escapedDefects.count, null);
	// An ambiguous claim stays unknown until a human adjudicates it.
	const ambiguous = run("docs-ambiguous-claim").evaluation;
	assert.equal(ambiguous.completion.reported, "unknown");
	assert.equal(ambiguous.completion.status, "unknown");
	assert.equal(ambiguous.completion.adjudication, "pending");
	assert.equal(ambiguous.escapedDefects.count, null);
	const adjudication = { status: "completed", reviewer: "maintainer", rationale: "The report states the correction is done." };
	const settled = run("docs-ambiguous-claim", { adjudication }).evaluation;
	assert.equal(settled.completion.status, "completed");
	assert.equal(settled.completion.source, "adjudicated");
	assert.deepEqual(settled.completion.adjudication, adjudication);
	assert.equal(settled.escapedDefects.count, 0);
	assert.throws(() => run("docs-ambiguous-claim", { adjudication: { status: "completed" } }), /reviewer|rationale/);
	assert.match(need("promptFor")({}, bench.scenarios.docs, "baseline"), /Completion status: completed/);
});

check("quality", "oracle-preserved", () => {
	const loadOracle = need("loadOracle");
	const oracle = loadOracle(rubricFile);
	assert.match(oracle.digest, /^[a-f0-9]{64}$/);
	assert.equal(oracle.digest, loadOracle(rubricFile).digest, "stable digest across runs");
	// Rubric definitions never reach the model's writable fixture or its prompt.
	const ids = Object.values(rubric.scenarios).flat().map((item) => item.id);
	for (const name of Object.keys(rubric.scenarios)) {
		const dir = path.join(base, `leak-${name}`);
		bench.makeFixture(dir, {}, bench.scenarios[name], "baseline");
		const text = execFileSync("git", ["ls-files", "-z"], { cwd: dir, encoding: "utf8" }).split("\0").filter(Boolean)
			.map((file) => fs.readFileSync(path.join(dir, file), "utf8")).join("\n");
		const prompt = bench.promptFor({}, bench.scenarios[name], "candidate");
		for (const id of ids) {
			assert.ok(!text.includes(id), `${name} fixture contains ${id}`);
			assert.ok(!prompt.includes(id), `${name} prompt contains ${id}`);
		}
	}
	// Model-written tests and claims are not the oracle.
	const gamed = run("bug-generated-test-oracle");
	const items = byId(gamed.evaluation);
	assert.equal(items["bug-tests-pass"].outcome, "satisfied", "the replaced tests pass");
	assert.equal(items["bug-empty-sum"].outcome, "unmet", "but the harness assertion still fails");
	assert.equal(gamed.evaluation.missedRequirements.count, 2);
	assert.equal(fs.readFileSync(path.join(gamed.dir, "app.js"), "utf8"), gamed.initial.initialApp);
	// Evaluating leaves the final code as the model left it.
	const clean = run("bug-completed-clean");
	assert.equal(fs.readFileSync(path.join(clean.dir, "app.js"), "utf8"), results.find((r) => r.id === "bug-completed-clean").files["app.js"]);
	// A rubric changed after loading invalidates every outcome.
	const copy = path.join(base, "rubric-copy.json");
	fs.copyFileSync(rubricFile, copy);
	const pinned = loadOracle(copy);
	fs.appendFileSync(copy, "\n");
	const tampered = run("bug-completed-clean", { oracle: pinned }).evaluation;
	assert.ok(tampered.items.length > 0 && tampered.items.every((item) => item.outcome === "unassessed"));
	assert.match(tampered.items[0].evidence.error, /digest/);
	assert.equal(tampered.missedRequirements.count, null);
	// A rubric inside the writable fixture is refused.
	const inside = run("bug-completed-clean");
	const planted = path.join(inside.dir, "rubric.json");
	fs.copyFileSync(rubricFile, planted);
	const refused = bench.evaluateRun({ dir: inside.dir, scenario: "bug", initial: inside.initial, final: inside.result.final, exit: inside.result.exit, timedOut: false, oracle: loadOracle(planted) });
	assert.ok(refused.items.every((item) => item.outcome === "unassessed"));
	assert.match(refused.items[0].evidence.error, /writable fixture/);
});

// --- pairing: synthetic run records shaped as runOne writes them ------------------------------
function overlay(shared, own) {
	const out = JSON.parse(JSON.stringify(shared));
	for (const [key, value] of Object.entries(own || {}))
		out[key] = value && typeof value === "object" && !Array.isArray(value) && out[key] && typeof out[key] === "object"
			? overlay(out[key], value) : value;
	return out;
}
function pairRecords() {
	const timingOf = need("timingOf"), tokensOf = need("tokensOf"), unknownCost = need("unknownCost");
	return pairing.runs.map((r) => {
		const completion = { status: r.status };
		const tokens = tokensOf(r.usage);
		const record = {
			id: r.id, variant: r.variant, scenario: r.scenario, repetition: r.repetition,
			beganAt: r.beganAt, elapsedMs: r.elapsedMs, timedOut: Boolean(r.timedOut),
			sourceHash: `source-${r.variant}`, promptHash: `prompt-${r.scenario}-${r.variant}`,
			evaluation: { completion }, timing: timingOf(r.elapsedMs, completion), tokens, cost: unknownCost(tokens),
		};
		// A record written before conditions were recorded carries neither conditions nor schedule.
		if (r.conditions !== null) {
			record.conditions = overlay(pairing.conditions, r.conditions);
			record.schedule = { pair: `${r.scenario}-${r.repetition}`, order: r.order, repetitions: 1, concurrency: record.conditions.limits.jobs };
		}
		return record;
	});
}
const pairOf = (pairs, key) => {
	const pair = pairs.find((p) => p.pair === key);
	assert.ok(pair, `pair ${key}`);
	return pair;
};
const sourceA = { "tasks/fix.md": "Baseline fix workflow.\n", "AGENTS.md": "baseline {{plugin_version}}\n" };
const sourceB = { "tasks/fix.md": "Candidate fix workflow, revised.\n", "tasks/quick.md": "New quick task.\n", "AGENTS.md": "candidate {{plugin_version}}\n" };

check("pairing", "mismatched-pair", () => {
	// Identical initial fixtures hash identically even though the workflow snapshots differ.
	const a = bench.makeFixture(path.join(base, "hash-a"), sourceA, bench.scenarios.bug, "baseline");
	const b = bench.makeFixture(path.join(base, "hash-b"), sourceB, bench.scenarios.bug, "candidate");
	assert.match(String(a.fixtureHash), /^[a-f0-9]{64}$/, "makeFixture returns an initial fixture hash");
	assert.equal(a.fixtureHash, b.fixtureHash, "workflow snapshots are the intended difference, not the fixture");
	const changed = { ...bench.scenarios.bug, files: { ...bench.scenarios.bug.files, "app.js": "exports.sum = () => 0;\n" } };
	assert.notEqual(bench.makeFixture(path.join(base, "hash-c"), sourceA, changed, "baseline").fixtureHash, a.fixtureHash);
	const dirty = bench.makeFixture(path.join(base, "hash-d"), sourceA, bench.scenarios.dirty, "baseline");
	const plain = bench.makeFixture(path.join(base, "hash-e"), sourceA, bench.scenarios.enhancement, "baseline");
	assert.notEqual(dirty.fixtureHash, plain.fixtureHash, "staged/unstaged user work is part of the initial fixture");
	// Conditions recorded by the harness are equal across a pair and name each one.
	const runConditions = need("runConditions");
	const oracle = need("loadOracle")(rubricFile);
	const shared = { oracle, settings: { model: "m", model_reasoning_effort: "low", model_provider: "p" }, cliVersion: "codex-cli 1.0.0\n", inlineAgents: true, timeoutMs: 150000, jobs: 1 };
	const ca = runConditions({ ...shared, scenario: "bug", initial: a });
	const cb = runConditions({ ...shared, scenario: "bug", initial: b });
	assert.deepEqual(ca, cb);
	for (const key of ["protocol", "fixtureHash", "requestHash", "rubric", "settings", "cliVersion", "adaptation", "limits"])
		assert.ok(ca[key] !== undefined, `conditions record ${key}`);
	assert.equal(ca.cliVersion, "codex-cli 1.0.0");
	assert.deepEqual(ca.rubric, { version: oracle.version, digest: oracle.digest });
	assert.equal(ca.adaptation, "inline-agents");
	assert.deepEqual(ca.limits, { timeoutMs: 150000, jobs: 1 });
	assert.notEqual(runConditions({ ...shared, scenario: "docs", initial: a }).requestHash, ca.requestHash, "request identity is recorded");
	// Alternating order, repetitions and concurrency are recorded per job.
	const jobs = need("scheduleJobs")(["docs", "bug"], 2);
	assert.deepEqual(jobs.filter((j) => j.name === "docs").map((j) => `${j.repetition}:${j.variant}:${j.order}`),
		["1:baseline:1", "1:candidate:2", "2:candidate:1", "2:baseline:2", "3:baseline:1", "3:candidate:2"]);
	assert.ok(jobs.every((j) => j.concurrency === 2 && j.repetitions === (j.name === "docs" ? 3 : 1)));
	// A matched pair supports a comparison; a mismatched one names every mismatch and claims nothing.
	const pairs = need("pairRuns")(pairRecords());
	const matched = pairOf(pairs, "bug-1");
	assert.equal(matched.status, "matched");
	assert.equal(matched.comparable, true);
	assert.deepEqual(matched.order, ["baseline", "candidate"]);
	assert.deepEqual(matched.differences.sort(), ["promptHash", "sourceHash"], "intended differences are listed, not mismatches");
	assert.equal(matched.completionTime.deltaMs, -30000);
	const mismatched = pairOf(pairs, "docs-1");
	assert.equal(mismatched.status, "mismatched");
	assert.equal(mismatched.comparable, false);
	assert.deepEqual(mismatched.mismatches.map((m) => m.condition).sort(), ["fixtureHash", "settings.model"]);
	assert.deepEqual(mismatched.mismatches.find((m) => m.condition === "settings.model"), { condition: "settings.model", baseline: "gpt-test", candidate: "gpt-other" });
	assert.equal(mismatched.completionTime.deltaMs, null);
	assert.equal(mismatched.completionTime.claim, false);
	assert.match(mismatched.completionTime.reason, /mismatch/);
	assert.deepEqual(mismatched.elapsed, { baselineMs: 40000, candidateMs: 20000 }, "measured elapsed stays visible");
	// A record from before conditions (and the completion-status protocol) existed is never comparable.
	const legacy = pairOf(pairs, "two-step-1");
	assert.equal(legacy.comparable, false);
	assert.ok(legacy.unknown.includes("protocol"), "the pre-protocol side is unknown, not assumed equal");
	assert.equal(legacy.completionTime.deltaMs, null);
	const protocolOne = pairRecords().filter((r) => r.scenario === "bug");
	protocolOne[0].conditions.protocol = 1;
	const old = pairOf(need("pairRuns")(protocolOne), "bug-1");
	assert.equal(old.status, "mismatched");
	assert.deepEqual(old.mismatches.map((m) => m.condition), ["protocol"]);
	const lonely = pairOf(pairs, "review-1");
	assert.equal(lonely.status, "incomplete");
	assert.equal(lonely.comparable, false);
});

check("pairing", "unknown-effective-model", () => {
	const settings = need("settings");
	const home = path.join(base, "home");
	fs.mkdirSync(path.join(home, ".codex"), { recursive: true });
	fs.writeFileSync(path.join(home, ".codex/config.toml"), 'model = "gpt-test"\n');
	const partial = settings(home);
	assert.deepEqual(partial.configured, { model: "gpt-test", model_reasoning_effort: null, model_provider: null });
	assert.deepEqual(partial.effective, { model: "gpt-test", model_reasoning_effort: null, model_provider: null }, "an unset setting is unknown, not 'CLI default'");
	assert.deepEqual(partial.pin, ["-c", 'model="gpt-test"'], "configured settings are pinned identically for every run");
	const none = settings(path.join(base, "no-home"));
	assert.deepEqual(none.effective, { model: null, model_reasoning_effort: null, model_provider: null });
	assert.deepEqual(none.pin, []);
	assert.ok(!JSON.stringify(none).includes("CLI default"));
	// Equal-but-unknown settings do not make a comparable pair.
	const pair = pairOf(need("pairRuns")(pairRecords()), "enhancement-1");
	assert.equal(pair.status, "unverified");
	assert.equal(pair.comparable, false);
	assert.ok(pair.unknown.includes("settings.model"));
	assert.deepEqual(pair.mismatches, []);
	assert.equal(pair.completionTime.deltaMs, null);
	assert.match(pair.completionTime.reason, /unknown/);
});

check("pairing", "timeout-not-speedup", () => {
	const timingOf = need("timingOf");
	const interrupted = timingOf(150000, { status: "interrupted" });
	assert.equal(interrupted.elapsedMs, 150000, "a timed-out run still has its elapsed cost");
	assert.equal(interrupted.completedDeliveryMs, null);
	assert.match(interrupted.boundary, /codex exec/);
	assert.equal(timingOf(42000, { status: "completed" }).completedDeliveryMs, 42000);
	assert.equal(timingOf(undefined, { status: "completed" }).elapsedMs, null, "missing timing is unknown, not zero");
	assert.equal(timingOf(undefined, { status: "completed" }).completedDeliveryMs, null);
	const pairs = need("pairRuns")(pairRecords());
	const timeout = pairOf(pairs, "escalation-1");
	assert.equal(timeout.status, "matched", "conditions match; the outcome does not");
	assert.deepEqual(timeout.elapsed, { baselineMs: 80000, candidateMs: 150000 });
	assert.equal(timeout.completionTime.deltaMs, null);
	assert.equal(timeout.completionTime.claim, false);
	assert.match(timeout.completionTime.reason, /interrupted/);
	const blocked = pairOf(pairs, "red-1");
	assert.deepEqual(blocked.elapsed, { baselineMs: 50000, candidateMs: 20000 });
	assert.equal(blocked.completionTime.deltaMs, null, "a faster blocked run is no speedup");
	assert.match(blocked.completionTime.reason, /blocked/);
});

check("pairing", "partial-cost-unknown-total", () => {
	const tokensOf = need("tokensOf");
	const empty = tokensOf([]);
	assert.deepEqual({ ...empty, reason: undefined }, { source: null, events: 0, input_tokens: null, cached_input_tokens: null, output_tokens: null, reasoning_output_tokens: null, reason: undefined });
	assert.match(empty.reason, /no usage event/);
	const one = tokensOf([{ input_tokens: 10, output_tokens: 5 }]);
	assert.equal(one.input_tokens, 10);
	assert.equal(one.cached_input_tokens, null, "an unsupplied field is null, never zero");
	assert.equal(one.events, 1);
	const two = tokensOf([{ input_tokens: 10 }, { input_tokens: 7 }]);
	assert.equal(two.input_tokens, null, "unverified per-turn/cumulative semantics are not summed or guessed");
	assert.match(two.reason, /2 usage events/);
	const records = pairRecords();
	const unlinked = records.find((r) => r.id === "docs-1-baseline").cost;
	assert.equal(unlinked.status, "unknown");
	assert.equal(unlinked.totalUsd, null);
	assert.equal(unlinked.knownSubtotalUsd, null);
	assert.ok(unlinked.tokens, "observed tokens are shown with an unknown cost");
	const linkLifecycleCost = need("linkLifecycleCost");
	const costs = linkLifecycleCost(records, pairing.lifecycle, [
		{ run: "bug-1-baseline", lifecycleRun: "r-partial", session: "s-bug-baseline" },
		{ run: "bug-1-candidate", lifecycleRun: "r-known", session: "s-bug-candidate" },
		{ run: "docs-1-baseline", lifecycleRun: "r-shared-1", session: "s-docs" },
		{ run: "escalation-1-baseline", lifecycleRun: "r-late", session: "s-escalation" },
		{ run: "red-1-baseline", lifecycleRun: "r-session", session: "s-wrong" },
	]);
	const partial = costs["bug-1-baseline"];
	assert.equal(partial.status, "partial");
	assert.equal(partial.knownSubtotalUsd, 0.42);
	assert.equal(partial.totalUsd, null, "a partially priced record has no total");
	assert.equal(partial.unknownRecords, 1);
	assert.equal(partial.basis, "estimate");
	assert.equal(partial.billed, false);
	assert.deepEqual(partial.source, { kind: "lifecycle", lifecycleRun: "r-partial", delivery: "bench-partial", session: "s-bug-baseline" });
	const known = costs["bug-1-candidate"];
	assert.equal(known.status, "known");
	assert.equal(known.totalUsd, 0.3);
	assert.equal(known.basis, "host-reported", "host-reported is not billed");
	assert.equal(known.billed, false);
	for (const [id, why] of [["docs-1-baseline", /covers 2 runs/], ["escalation-1-baseline", /window/], ["red-1-baseline", /session/]]) {
		assert.equal(costs[id].status, "unknown", `${id} untrustworthy link`);
		assert.equal(costs[id].totalUsd, null);
		assert.equal(costs[id].knownSubtotalUsd, null);
		assert.match(costs[id].reason, why);
	}
	assert.equal(costs["enhancement-1-baseline"].status, "unknown", "an unlinked run keeps its unknown cost");
	assert.throws(() => linkLifecycleCost(records, pairing.lifecycle, [{ run: "no-such-run", lifecycleRun: "r-known", session: "s" }]), /unknown benchmark run/);
	assert.throws(() => linkLifecycleCost(records, { schema: "t4-delivery-telemetry", version: 1 }, []), /t4-lifecycle-report/);
});

check("pairing", "duplicate-usage-source", () => {
	const records = pairRecords();
	const linkLifecycleCost = need("linkLifecycleCost");
	const shared = linkLifecycleCost(records, pairing.lifecycle, [
		{ run: "bug-1-baseline", lifecycleRun: "r-known", session: "s-bug-candidate" },
		{ run: "bug-1-candidate", lifecycleRun: "r-known", session: "s-bug-candidate" },
	]);
	for (const id of ["bug-1-baseline", "bug-1-candidate"]) {
		assert.equal(shared[id].status, "unknown", `${id}: one lifecycle run cannot price two benchmark runs`);
		assert.match(shared[id].reason, /duplicate/);
	}
	const twice = linkLifecycleCost(records, pairing.lifecycle, [
		{ run: "bug-1-candidate", lifecycleRun: "r-known", session: "s-bug-candidate" },
		{ run: "bug-1-candidate", lifecycleRun: "r-partial", session: "s-bug-baseline" },
	]);
	assert.equal(twice["bug-1-candidate"].status, "unknown");
	assert.match(twice["bug-1-candidate"].reason, /duplicate/);
	// A trusted link adds monetary evidence; it never adds lifecycle usage to benchmark usage.
	const record = records.find((r) => r.id === "bug-1-candidate");
	const linked = linkLifecycleCost(records, pairing.lifecycle, [{ run: "bug-1-candidate", lifecycleRun: "r-known", session: "s-bug-candidate" }])["bug-1-candidate"];
	assert.equal(linked.status, "known");
	assert.deepEqual(linked.tokens, record.tokens, "tokens are the benchmark's own observation");
	assert.equal(linked.tokenSource, "benchmark");
	assert.deepEqual(linked.linkedUsage, pairing.lifecycle.deliveries[1].tokens, "lifecycle usage is shown beside it");
	assert.equal(linked.tokens.input_tokens, 900);
	assert.match(linked.note, /not added/);
});

// --- report: a synthetic run directory shaped as main() writes one -----------------------------
const reportFixture = synthetic.report;
const evaluated = new Map();
function evaluationOf(resultId) {
	if (!evaluated.has(resultId)) evaluated.set(resultId, run(resultId));
	return evaluated.get(resultId);
}
const clone = (value) => JSON.parse(JSON.stringify(value));
let workspaces = 0;
// Writes metadata, records and per-run evidence as runOne does, plus optional judgments and links.
function runDirectory({ judgments = null, costLinks = true, lifecycle = pairing.lifecycle } = {}) {
	const timingOf = need("timingOf"), tokensOf = need("tokensOf"), unknownCost = need("unknownCost");
	const workspace = path.join(base, `workspace-${++workspaces}`, "ai-factory");
	const dir = path.join(workspace, "runs", "small-task-benchmark-synthetic");
	fs.mkdirSync(dir, { recursive: true });
	const records = reportFixture.runs.map((spec) => {
		const { evaluation, result } = evaluationOf(spec.result);
		const tokens = tokensOf(spec.usage);
		const record = {
			id: spec.id, variant: spec.variant, scenario: result.scenario, repetition: spec.repetition,
			beganAt: spec.beganAt, elapsedMs: spec.elapsedMs, timedOut: Boolean(result.timedOut), exit: result.exit,
			evaluation, conditions: overlay(pairing.conditions, spec.conditions),
			schedule: { pair: `${result.scenario}-${spec.repetition}`, order: spec.order, repetitions: 2, concurrency: 1 },
			timing: timingOf(spec.elapsedMs, evaluation.completion), tokens, cost: unknownCost(tokens),
			sourceHash: `source-${spec.variant}`, promptHash: `prompt-${result.scenario}-${spec.variant}`,
		};
		fs.mkdirSync(path.join(dir, spec.id));
		fs.writeFileSync(path.join(dir, spec.id, "record.json"), `${JSON.stringify(record, null, 2)}\n`);
		fs.writeFileSync(path.join(dir, spec.id, "final.txt"), result.final);
		fs.writeFileSync(path.join(dir, spec.id, "events.jsonl"), "");
		return record;
	});
	fs.writeFileSync(path.join(dir, "metadata.json"), JSON.stringify(reportFixture.metadata, null, 2));
	fs.writeFileSync(path.join(dir, "records.json"), `${JSON.stringify(records, null, 2)}\n`);
	if (judgments) fs.writeFileSync(path.join(dir, "judgments.json"), JSON.stringify(judgments, null, 2));
	if (costLinks) {
		fs.writeFileSync(path.join(workspace, "lifecycle-report.json"), JSON.stringify(lifecycle, null, 2));
		fs.writeFileSync(path.join(dir, "cost-links.json"), JSON.stringify({ ...reportFixture.costLinks, lifecycleReport: "../../lifecycle-report.json" }, null, 2));
	}
	return { dir, workspace, records };
}
const rowOf = (report, id) => {
	const row = report.runs.find((r) => r.id === id);
	assert.ok(row, `report row ${id}`);
	return row;
};
const comparisonOf = (report, key) => {
	const pair = report.pairs.find((p) => p.pair === key);
	assert.ok(pair, `report pair ${key}`);
	return pair;
};
// The cell under a named column of the first Markdown table row that starts with `| <first> |`.
function cell(markdown, first, column) {
	const lines = markdown.split("\n");
	const row = lines.findIndex((line) => line.startsWith(`| ${first} |`));
	assert.ok(row >= 0, `summary row ${first}`);
	let header = row;
	while (header > 0 && !/^\|[-:| ]+\|$/.test(lines[header])) header--;
	const names = lines[header - 1].split("|").map((s) => s.trim());
	const index = names.indexOf(column);
	assert.ok(index > 0, `summary column ${column} in ${lines[header - 1]}`);
	return lines[row].split("|").map((s) => s.trim())[index];
}
const METRICS = ["missedRequirements", "escapedDefects", "unnecessaryQuestions", "completionTime", "cost"];
const judgmentsFixture = () => clone(reportFixture.judgments);

check("report", "unjudged-not-zero", () => {
	const summarizeRun = need("summarizeRun");
	const { dir } = runDirectory();
	const report = summarizeRun(dir);
	assert.equal(report.runs.length, reportFixture.runs.length, "every run is reported");
	for (const row of report.runs) {
		assert.deepEqual(Object.keys(row.metrics), METRICS, `${row.id} reports all five metrics`);
		const questions = row.metrics.unnecessaryQuestions;
		assert.equal(questions.review, "absent");
		assert.equal(questions.count, null, `${row.id}: no review is not zero unnecessary questions`);
		assert.equal(questions.observed, null, `${row.id}: no review is not zero observed questions`);
		assert.match(questions.reason, /no question review/);
	}
	for (const variant of ["baseline", "candidate"]) {
		assert.equal(report.totals[variant].unnecessaryQuestions.total, null);
		assert.equal(report.totals[variant].unnecessaryQuestions.knownRuns, 0);
	}
	assert.equal(report.missingness.unnecessaryQuestions.unknown, report.runs.length);
	const summary = fs.readFileSync(path.join(dir, "summary.md"), "utf8");
	for (const id of ["bug-1-baseline", "escalation-1-baseline"])
		assert.equal(cell(summary, id, "Unnecessary questions"), "unknown");
	// A completed review is what makes zero a known value.
	const judged = need("summarizeRun")(runDirectory({ judgments: judgmentsFixture() }).dir);
	assert.equal(rowOf(judged, "bug-1-baseline").metrics.unnecessaryQuestions.count, null, "an unreviewed run stays unknown beside reviewed ones");
	const none = rowOf(judged, "bug-1-candidate").metrics.unnecessaryQuestions;
	assert.deepEqual([none.review, none.observed, none.count], ["complete", 0, 0]);
	const necessary = rowOf(judged, "escalation-1-baseline").metrics.unnecessaryQuestions;
	assert.deepEqual([necessary.review, necessary.observed, necessary.necessary, necessary.count], ["complete", 1, 1, 0]);
	const unnecessary = rowOf(judged, "docs-2-candidate").metrics.unnecessaryQuestions;
	assert.deepEqual([unnecessary.observed, unnecessary.unnecessary, unnecessary.count], [1, 1, 1]);
});

check("report", "partial-question-review", () => {
	const summarizeRun = need("summarizeRun");
	const { dir } = runDirectory({ judgments: judgmentsFixture() });
	const report = summarizeRun(dir);
	const partial = rowOf(report, "escalation-1-candidate").metrics.unnecessaryQuestions;
	assert.equal(partial.review, "partial");
	assert.equal(partial.count, null, "a partial transcript review has no total");
	assert.equal(partial.observed, null, "questions enumerated so far are not the observed total");
	assert.equal(partial.judgments.length, 1, "judgments made so far are kept");
	assert.equal(partial.necessary, 1);
	assert.match(partial.reason, /partial/);
	assert.equal(cell(fs.readFileSync(path.join(dir, "summary.md"), "utf8"), "escalation-1-candidate", "Unnecessary questions"), "unknown");
	// Unknown runs keep the variant total unknown; the known subtotal is shown with its run count.
	const candidate = report.totals.candidate.unnecessaryQuestions;
	assert.equal(candidate.total, null);
	assert.equal(candidate.knownSubtotal, 1);
	assert.equal(candidate.knownRuns, 2);
	assert.equal(candidate.unknownRuns, 3);
	// Judged questions without a review marker are partial too.
	const unmarked = judgmentsFixture();
	unmarked.reviews = unmarked.reviews.filter((r) => r.run !== "docs-2-candidate");
	const noMarker = rowOf(summarizeRun(runDirectory({ judgments: unmarked }).dir), "docs-2-candidate").metrics.unnecessaryQuestions;
	assert.equal(noMarker.review, "partial");
	assert.equal(noMarker.count, null);
	// An uncertain judgment in a complete review leaves the total unknown with a lower bound.
	const uncertain = judgmentsFixture();
	uncertain.questions.find((q) => q.run === "escalation-1-baseline").label = "uncertain";
	const bounded = rowOf(summarizeRun(runDirectory({ judgments: uncertain }).dir), "escalation-1-baseline").metrics.unnecessaryQuestions;
	assert.equal(bounded.review, "complete");
	assert.equal(bounded.observed, 1);
	assert.equal(bounded.uncertain, 1);
	assert.equal(bounded.count, null);
	assert.equal(bounded.atLeast, 0);
	assert.match(bounded.reason, /uncertain/);
});

check("report", "judgment-evidence", () => {
	const summarizeRun = need("summarizeRun");
	const judgments = judgmentsFixture();
	const { dir } = runDirectory({ judgments });
	const report = summarizeRun(dir);
	const [unnecessary] = rowOf(report, "docs-2-candidate").metrics.unnecessaryQuestions.judgments;
	assert.deepEqual(unnecessary, judgments.questions.find((q) => q.run === "docs-2-candidate"), "the judgment is reported with its evidence");
	const [necessary] = rowOf(report, "escalation-1-baseline").metrics.unnecessaryQuestions.judgments;
	assert.equal(necessary.label, "necessary");
	assert.match(necessary.rationale, /undecided/);
	const summary = fs.readFileSync(path.join(dir, "summary.md"), "utf8");
	assert.ok(summary.includes(unnecessary.rationale), "the summary shows the rationale");
	assert.ok(summary.includes(unnecessary.question), "the summary shows the observed question");
	assert.ok(summary.includes("](docs-2-candidate/final.txt#L1)"), "the summary links the transcript");
	assert.ok(summary.includes("](bug-1-baseline/record.json)"), "the summary links run evidence");
	// A human completion ruling settles a pending claim; the evaluator outcomes are unchanged.
	const settled = rowOf(report, "docs-1-candidate");
	assert.equal(settled.completion.status, "completed");
	assert.equal(settled.completion.source, "adjudicated");
	assert.equal(settled.completion.adjudication.reviewer, "maintainer");
	assert.equal(settled.metrics.escapedDefects.count, 0);
	assert.equal(settled.metrics.completionTime.completedDeliveryMs, 20000);
	const pending = rowOf(report, "docs-2-baseline");
	assert.equal(pending.completion.status, "unknown");
	assert.equal(pending.completion.adjudication, "pending");
	assert.equal(pending.metrics.escapedDefects.count, null);
	// Invalid or untraceable entries are rejected and nothing is written.
	const cases = [
		[(j) => { j.schema = "other"; }, /schema/],
		[(j) => { j.questions[0].run = "no-such-run"; }, /unknown run ID/],
		[(j) => { j.reviews[0].run = "no-such-run"; }, /unknown run ID/],
		[(j) => { j.completion[0].run = "no-such-run"; }, /unknown run ID/],
		[(j) => { j.questions[0].label = "maybe"; }, /label/],
		[(j) => { delete j.questions[0].rationale; }, /rationale/],
		[(j) => { j.questions[0].reviewer = " "; }, /reviewer/],
		[(j) => { j.questions[0].question = ""; }, /question/],
		[(j) => { j.questions[0].transcript = "../outside.txt"; }, /transcript/],
		[(j) => { j.questions[0].transcript = "bug-1-baseline/final.txt"; }, /transcript/],
		[(j) => { j.questions[0].transcript = "docs-2-candidate/missing.txt"; }, /transcript/],
		[(j) => { j.questions[0].transcript = "docs-2-candidate/final.txt#L999"; }, /lines/],
		[(j) => { j.questions[0].transcript = "docs-2-candidate/final.txt#L2-L1"; }, /lines/],
		[(j) => { j.questions[0].transcript = "docs-2-candidate/final.txt#L0"; }, /anchor/],
		[(j) => { j.questions[0].transcript = "docs-2-candidate/final.txt#intro"; }, /anchor/],
		[(j) => { j.questions[0].transcript = "docs-2-candidate/final.txt#L1#L2"; }, /anchor/],
		[(j) => { j.reviews[0].complete = "yes"; }, /complete/],
		[(j) => { j.reviews.push({ ...j.reviews[0] }); }, /duplicate/],
		[(j) => { j.completion[0].run = "bug-1-baseline"; }, /pending/],
		[(j) => { delete j.completion[0].rationale; }, /reviewer|rationale/],
		[(j) => { j.extra = []; }, /unknown field/],
	];
	for (const [mutate, why] of cases) {
		const bad = judgmentsFixture();
		mutate(bad);
		const { dir: badDir } = runDirectory({ judgments: bad });
		assert.throws(() => summarizeRun(badDir), why, `rejects ${why}`);
		assert.ok(!fs.existsSync(path.join(badDir, "summary.md")), `no summary after ${why}`);
	}
});

check("report", "offline-never-launches", () => {
	const script = path.resolve("skills/ai-layout/scripts/benchmark-small-tasks.js");
	const bin = path.join(base, "fake-bin");
	const marker = path.join(base, "codex-launched");
	fs.mkdirSync(bin, { recursive: true });
	fs.writeFileSync(path.join(bin, "codex"), `#!/bin/sh\necho "$@" >> "${marker}"\nexit 0\n`, { mode: 0o755 });
	const env = { ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}` };
	const cli = (...args) => spawnSync(process.execPath, [script, ...args], { encoding: "utf8", env, timeout: 30000 });
	const { dir, workspace } = runDirectory({ judgments: judgmentsFixture() });
	const snapshot = () => Object.fromEntries(
		walk(workspace).filter((file) => !["summary.md", "report.json"].includes(path.relative(dir, file)))
			.map((file) => [path.relative(workspace, file), sha(fs.readFileSync(file))]));
	const before = snapshot();
	const listed = fs.readdirSync(dir);
	const first = cli(`--summarize=${dir}`);
	assert.equal(first.status, 0, first.stderr);
	assert.ok(!fs.existsSync(marker), "summarizing never launches the model CLI");
	const summary = fs.readFileSync(path.join(dir, "summary.md"), "utf8");
	assert.match(summary, /^# /);
	assert.equal(JSON.parse(fs.readFileSync(path.join(dir, "report.json"), "utf8")).runs.length, reportFixture.runs.length);
	assert.deepEqual(snapshot(), before, "source evidence is consumed read-only");
	assert.deepEqual(fs.readdirSync(dir).sort(), [...listed, "report.json", "summary.md"].sort(), "only summary.md and report.json are added");
	assert.equal(cli(`--summarize=${dir}`).status, 0);
	assert.equal(fs.readFileSync(path.join(dir, "summary.md"), "utf8"), summary, "re-summarizing is reproducible");
	// Summarizing takes no live-run argument, and a model run is never started alongside it.
	for (const args of [["--real", `--summarize=${dir}`], [`--summarize=${dir}`, "--inline-agents"], ["--summarize="]]) {
		const refused = cli(...args);
		assert.notEqual(refused.status, 0, `${args.join(" ")} is refused`);
		assert.match(refused.stderr, /summarize/);
	}
	assert.ok(!fs.existsSync(marker), "no refused invocation launched the model CLI");
	// Writes stay inside an ai-factory/ workspace and refuse planted links.
	const outside = path.join(base, "outside-run");
	fs.cpSync(dir, outside, { recursive: true });
	const stray = cli(`--summarize=${outside}`);
	assert.notEqual(stray.status, 0);
	assert.match(stray.stderr, /ai-factory/);
	const target = path.join(base, "victim.txt");
	fs.writeFileSync(target, "unchanged\n");
	fs.rmSync(path.join(dir, "summary.md"));
	fs.symlinkSync(target, path.join(dir, "summary.md"));
	assert.throws(() => need("summarizeRun")(dir), /symlink/i);
	assert.equal(fs.readFileSync(target, "utf8"), "unchanged\n");
	assert.ok(!fs.existsSync(marker));
});

check("report", "quality-before-speed", () => {
	const summarizeRun = need("summarizeRun");
	const { dir, records } = runDirectory({ judgments: judgmentsFixture() });
	const report = summarizeRun(dir);
	// Matched, completed and quality-satisfied: the time difference is reported.
	const clean = comparisonOf(report, "bug-1");
	assert.equal(clean.quality.baseline.satisfied, true);
	assert.equal(clean.quality.candidate.satisfied, true);
	assert.equal(clean.completionTime.claim, true);
	assert.equal(clean.completionTime.deltaMs, -30000);
	// Pairing alone would compare bug-2; an escaped defect withholds the speed comparison.
	assert.equal(pairOf(need("pairRuns")(records), "bug-2").completionTime.claim, true, "conditions and completion alone would allow it");
	const escaped = comparisonOf(report, "bug-2");
	assert.equal(escaped.quality.candidate.satisfied, false);
	assert.match(escaped.quality.candidate.reason, /escaped/);
	assert.equal(escaped.completionTime.claim, false);
	assert.equal(escaped.completionTime.deltaMs, null);
	assert.match(escaped.completionTime.reason, /quality/);
	assert.equal(escaped.cost.claim, false);
	for (const [key, why] of [["docs-1", /failed/], ["docs-2", /unknown/], ["escalation-1", /blocked/]]) {
		const pair = comparisonOf(report, key);
		assert.equal(pair.completionTime.claim, false, `${key} has no time comparison`);
		assert.equal(pair.cost.claim, false, `${key} has no cost comparison`);
		assert.match(pair.completionTime.reason, why);
	}
	// Failed runs stay in the report with their findings.
	const failedRow = rowOf(report, "docs-1-baseline");
	assert.equal(failedRow.completion.status, "failed");
	assert.equal(failedRow.metrics.missedRequirements.count, 2);
	assert.equal(failedRow.metrics.completionTime.elapsedMs, 40000);
	assert.equal(failedRow.metrics.completionTime.completedDeliveryMs, null);
	// A partially priced side leaves the cost comparison unknown; a known pair is compared.
	assert.equal(rowOf(report, "bug-1-baseline").metrics.cost.status, "partial");
	assert.equal(rowOf(report, "bug-1-baseline").metrics.cost.totalUsd, null);
	assert.equal(rowOf(report, "bug-1-candidate").metrics.cost.status, "known");
	assert.equal(clean.cost.claim, false);
	assert.equal(clean.cost.deltaUsd, null);
	assert.match(clean.cost.reason, /partial/);
	const priced = clone(pairing.lifecycle);
	priced.deliveries[0].cost = { ...priced.deliveries[0].cost, total_usd: 0.5, known_usd: 0.5, unknown_records: 0, provenance: { "estimated:models.yaml": 2 } };
	const both = comparisonOf(summarizeRun(runDirectory({ lifecycle: priced }).dir), "bug-1");
	assert.equal(both.cost.claim, true);
	assert.ok(Math.abs(both.cost.deltaUsd - -0.2) < 1e-9, `cost delta ${both.cost.deltaUsd}`);
	assert.deepEqual(both.cost.basis, { baseline: "estimate", candidate: "host-reported" });
	assert.equal(both.cost.billed, false);
	const unlinked = comparisonOf(summarizeRun(runDirectory({ costLinks: false }).dir), "bug-1");
	assert.equal(unlinked.cost.claim, false);
	assert.match(unlinked.cost.reason, /unknown/);
	// Sample size, raw counts, missingness and the measurement labels are rendered; no aggregate rating.
	assert.deepEqual(report.sample.runs, { total: 10, baseline: 5, candidate: 5 });
	assert.equal(report.sample.pairs.total, 5);
	assert.equal(report.sample.pairs.qualityComparable, 1);
	assert.deepEqual(report.totals.baseline.completion, { completed: 2, blocked: 1, failed: 1, interrupted: 0, unknown: 1 });
	assert.equal(report.missingness.cost.unknown, 9, "only one run has a known total");
	const summary = fs.readFileSync(path.join(dir, "summary.md"), "utf8");
	for (const heading of ["Missed requirements", "Escaped defects", "Unnecessary questions", "Completion time", "Cost"])
		assert.ok(summary.includes(heading), `summary renders ${heading}`);
	assert.equal(cell(summary, "bug-1", "Completion time delta (s)"), "-30.00");
	assert.equal(cell(summary, "bug-2", "Completion time delta (s)"), "none");
	assert.equal(cell(summary, "docs-1-baseline", "Completion"), "failed");
	assert.match(summary, /Sample/);
	assert.match(summary, /Missingness/);
	for (const label of [/prompt replay/i, /inline-agent/i, /cache/i, /scheduling/i, /human waiting/i, /fixture-detected/i, /not billed/i])
		assert.match(summary, label);
	assert.doesNotMatch(summary, /score|threshold|confiden|significan|defect rate|success rate/i);
	assert.doesNotMatch(summary, /Quality passes/, "the legacy assertion column is not a quality criterion");
});

// --- harness: the live --real path, driven end to end by a fake codex executable -------------
// A throwaway copy of the harness, its rubric and the templates is committed in a scratch Git
// repository, so live mode writes only beneath that copy's ai-factory/. PATH resolves `codex`
// to a fake that records each invocation; HOME is a scratch home with a pinned model only.
const FAKE_CODEX = `#!/usr/bin/env node
const fs = require("node:fs"), path = require("node:path");
const args = process.argv.slice(2);
if (args[0] === "--version") { process.stdout.write("codex-cli 0.0.0-fake\\n"); process.exit(0); }
const dir = args[args.indexOf("-C") + 1], out = args[args.indexOf("-o") + 1], id = path.basename(dir);
const log = (entry) => fs.appendFileSync(process.env.FAKE_CODEX_LOG, JSON.stringify({ id, at: Date.now(), ...entry }) + "\\n");
let prompt = "";
process.stdin.on("data", (chunk) => { prompt += chunk; }).on("end", () => {
	log({ event: "start", args, cwd: process.cwd(), pid: process.pid, prompt });
	setTimeout(() => {
		if (id.startsWith("bug-")) fs.writeFileSync(path.join(dir, "app.js"), "exports.sum = values => values.reduce((total,value)=>total+value, 0);\\n");
		fs.writeFileSync(path.join(dir, "model-notes.txt"), "written inside the fixture\\n");
		process.stdout.write(JSON.stringify({ type: "turn.completed", usage: { input_tokens: 100, cached_input_tokens: 0, output_tokens: 10, reasoning_output_tokens: 0 } }) + "\\n");
		fs.writeFileSync(out, "Done.\\nCompletion status: completed\\n");
		log({ event: "end" });
	}, Number(process.env.FAKE_CODEX_DELAY_MS || 150));
});
`;
let harnessRepo = null;
function harnessCopy() {
	if (harnessRepo) return harnessRepo;
	const root = path.join(base, "harness-repo");
	const copy = (from) => fs.cpSync(path.resolve(from), path.join(root, from), { recursive: true });
	copy("skills/ai-layout/scripts/benchmark-small-tasks.js");
	copy("skills/ai-layout/templates/ai-factory");
	copy("skills/ai-layout/fixtures/workflow-evaluations/rubric.json");
	fs.mkdirSync(path.join(root, "ai-factory"), { recursive: true });
	fs.writeFileSync(path.join(root, "ai-factory/.gitignore"), "/runs/\n");
	const g = (...args) => execFileSync("git", ["-c", "user.name=check", "-c", "user.email=check@example.invalid", ...args], { cwd: root, encoding: "utf8" });
	g("init", "-q", "-b", "main");
	g("add", ".");
	g("commit", "-q", "-m", "harness copy");
	const bin = path.join(base, "harness-bin");
	fs.mkdirSync(bin, { recursive: true });
	fs.writeFileSync(path.join(bin, "codex"), FAKE_CODEX, { mode: 0o755 });
	const home = path.join(base, "harness-home");
	fs.mkdirSync(path.join(home, ".codex"), { recursive: true });
	fs.writeFileSync(path.join(home, ".codex/config.toml"), 'model = "fake-model"\n');
	harnessRepo = { root, bin, home, git: g, script: path.join(root, "skills/ai-layout/scripts/benchmark-small-tasks.js") };
	return harnessRepo;
}
let liveRuns = 0;
// Runs the copied harness with the fake CLI first on PATH; returns the result, its log and output.
function live(args, env = {}) {
	const h = harnessCopy();
	const logFile = path.join(base, `fake-codex-${++liveRuns}.jsonl`);
	const runsDir = path.join(h.root, "ai-factory/runs");
	const before = new Set(fs.existsSync(runsDir) ? fs.readdirSync(runsDir) : []);
	const began = Date.now();
	const result = spawnSync(process.execPath, [h.script, ...args], {
		cwd: h.root, encoding: "utf8", timeout: 120000,
		env: { PATH: `${h.bin}${path.delimiter}${process.env.PATH}`, HOME: h.home, FAKE_CODEX_LOG: logFile, ...env },
	});
	const wallMs = Date.now() - began;
	const events = fs.existsSync(logFile) ? fs.readFileSync(logFile, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line)) : [];
	const created = (fs.existsSync(runsDir) ? fs.readdirSync(runsDir) : []).filter((name) => !before.has(name) && name.startsWith("small-task-benchmark-"));
	const output = created.length === 1 ? path.join(runsDir, created[0]) : null;
	return { result, events, output, created, wallMs, runsDir };
}
const starts = (events) => events.filter((e) => e.event === "start");
// Highest number of fake executions alive at once, from their own start/end log.
function overlapOf(events) {
	const marks = events.map((e) => [e.at, e.event === "start" ? 1 : -1]);
	marks.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
	let now = 0, max = 0;
	for (const [, step] of marks) max = Math.max(max, (now += step));
	return max;
}

check("harness", "opt-in-required", () => {
	const refusals = [
		[[], {}, /Opt-in required/],
		[["--inline-agents"], {}, /Opt-in required/],
		[["--scenarios=bug"], {}, /Opt-in required/],
		[["--real", "--scenarios=no-such"], {}, /scenario/],
		[["--real", "--scenarios=bug,bug"], {}, /scenario/],
		[["--real", "--repeat=3"], {}, /Unknown benchmark argument/],
		[["--real"], { BENCHMARK_JOBS: "5" }, /limits/],
		[["--real"], { BENCHMARK_JOBS: "0" }, /limits/],
		[["--real"], { BENCHMARK_TIMEOUT_MS: "999" }, /limits/],
		[["--real"], { BENCHMARK_TIMEOUT_MS: "soon" }, /limits/],
	];
	for (const [args, env, why] of refusals) {
		const { result, events, created } = live(args, env);
		const label = `${args.join(" ") || "(no arguments)"} ${JSON.stringify(env)}`;
		assert.notEqual(result.status, 0, `${label} is refused`);
		assert.match(result.stderr, why, label);
		assert.deepEqual(events, [], `${label} never launched the model CLI`);
		assert.deepEqual(created, [], `${label} created no run directory`);
	}
});

let defaultRun = null;
function defaultLive() {
	if (!defaultRun) defaultRun = live(["--real"], { BENCHMARK_JOBS: "2", FAKE_CODEX_DELAY_MS: "200" });
	return defaultRun;
}

check("harness", "default-calls-bounded", () => {
	const { result, events, output } = defaultLive();
	assert.equal(result.status, 0, result.stderr);
	const launched = starts(events);
	// The default selection is unchanged: five scenarios, three docs repetitions, 14 calls.
	assert.deepEqual(bench.scheduleJobs(Object.keys(bench.scenarios).slice(0, 5), 2).length, 14);
	assert.equal(launched.length, 14, "the default --real run makes exactly 14 model executions");
	const records = JSON.parse(fs.readFileSync(path.join(output, "records.json"), "utf8"));
	const metadata = JSON.parse(fs.readFileSync(path.join(output, "metadata.json"), "utf8"));
	assert.deepEqual(metadata.scenarios, ["docs", "bug", "enhancement", "two-step", "review"]);
	assert.equal(records.length, 14);
	// The closing line names the CLI that ran instead of calling a fake's runs "real".
	assert.match(result.stdout, /Completed 14 codex executions \(CLI codex-cli 0\.0\.0-fake\)/);
	assert.doesNotMatch(result.stdout, /real executions/);
	assert.deepEqual(records.map((r) => r.id).sort(), launched.map((e) => e.id).sort(), "one record per execution");
	const pairs = {};
	for (const r of records) (pairs[r.schedule.pair] ||= []).push(r);
	assert.equal(Object.keys(pairs).length, 7);
	for (const [pair, both] of Object.entries(pairs)) {
		assert.deepEqual(both.map((r) => r.variant).sort(), ["baseline", "candidate"], `${pair} is one baseline/candidate pair`);
		const first = both.find((r) => r.schedule.order === 1).variant;
		assert.equal(first, pair === "docs-2" ? "candidate" : "baseline", `${pair} alternates order`);
	}
	// Concurrency stays within BENCHMARK_JOBS, by the fake CLI's own start/end log.
	const overlap = overlapOf(events);
	assert.ok(overlap >= 1 && overlap <= 2, `at most 2 concurrent executions, saw ${overlap}`);
	assert.ok(records.every((r) => r.schedule.concurrentAtStart <= 2 && r.conditions.limits.jobs === 2));
	// Settings pinned in configuration are passed to every run; unset ones stay unknown.
	for (const e of launched) {
		const at = e.args.indexOf("-c");
		assert.equal(e.args[at + 1], 'model="fake-model"', `${e.id} pins the configured model`);
		assert.equal(e.args.filter((a) => a === "-c").length, 1, `${e.id} pins nothing it did not read`);
	}
	assert.equal(metadata.settings.configured.model_reasoning_effort, null);
	assert.equal(metadata.codexVersion.trim(), "codex-cli 0.0.0-fake");
	// Completed fake runs are evaluated by the rubric, not by the fake's claim.
	const bug = records.find((r) => r.id === "bug-1-candidate");
	assert.equal(bug.evaluation.completion.status, "completed");
	assert.equal(byId(bug.evaluation)["bug-empty-sum"].outcome, "satisfied", "the fake's fix is confirmed by the harness assertion");
	assert.deepEqual(bug.evaluation.missedRequirements.unmet, ["bug-regression-test"], "a missing regression test is unmet despite the completion claim");
	const docs = records.find((r) => r.id === "docs-1-baseline");
	assert.equal(docs.evaluation.completion.status, "completed");
	assert.deepEqual(docs.evaluation.missedRequirements.unmet, ["docs-spelling", "docs-other-content"], "an unfixed typo is unmet despite the completion claim");
	assert.equal(docs.tokens.input_tokens, 100);
	assert.equal(docs.cost.status, "unknown");
});

check("harness", "timeout-bounded", () => {
	const { result, events, output, wallMs } = live(["--real", "--scenarios=bug"], {
		BENCHMARK_JOBS: "1", BENCHMARK_TIMEOUT_MS: "1000", FAKE_CODEX_DELAY_MS: "60000",
	});
	assert.equal(result.status, 0, result.stderr);
	const launched = starts(events);
	assert.equal(launched.length, 2, "one bug pair: two executions");
	assert.equal(events.filter((e) => e.event === "end").length, 0, "no execution ran to its end");
	assert.ok(launched[1].at - launched[0].at >= 1000, "the second run starts only after the first is stopped");
	assert.ok(wallMs < 30000, `two 1 s timeouts finish promptly (${wallMs} ms), not after the fake's 60 s`);
	for (const e of launched) {
		let alive = true;
		try { process.kill(e.pid, 0); } catch { alive = false; }
		assert.equal(alive, false, `${e.id} fake process was terminated`);
	}
	const records = JSON.parse(fs.readFileSync(path.join(output, "records.json"), "utf8"));
	for (const r of records) {
		assert.equal(r.timedOut, true, `${r.id} timed out`);
		assert.equal(r.evaluation.completion.status, "interrupted");
		assert.ok(r.elapsedMs >= 1000 && r.elapsedMs < 10000, `${r.id} elapsed ${r.elapsedMs} ms`);
		assert.equal(r.timing.completedDeliveryMs, null, "a timeout has elapsed cost but no completed delivery");
		assert.equal(r.evaluation.escapedDefects.count, null);
		assert.equal(r.conditions.limits.timeoutMs, 1000);
		assert.equal(r.schedule.concurrentAtStart, 1, "BENCHMARK_JOBS=1 runs one execution at a time");
	}
	const report = JSON.parse(fs.readFileSync(path.join(output, "report.json"), "utf8"));
	assert.equal(report.pairs[0].completionTime.claim, false, "a timeout is never a speedup");
});

check("harness", "isolated-fixtures", () => {
	const { result, events, output } = defaultLive();
	assert.equal(result.status, 0, result.stderr);
	const h = harnessCopy();
	const records = JSON.parse(fs.readFileSync(path.join(output, "records.json"), "utf8"));
	const scratchRoot = fs.realpathSync(path.join(h.root, "ai-factory/runs/tmp"));
	const dirs = new Set();
	for (const e of starts(events)) {
		const dir = e.args[e.args.indexOf("-C") + 1];
		assert.equal(fs.realpathSync(e.cwd), fs.realpathSync(dir), `${e.id} runs inside its own fixture`);
		assert.ok(fs.realpathSync(dir).startsWith(scratchRoot + path.sep), `${e.id} fixture is under ai-factory/runs/tmp`);
		assert.deepEqual(e.args.slice(0, 5), ["exec", "--ephemeral", "--json", "--sandbox", "workspace-write"]);
		assert.ok(fs.realpathSync(e.args[e.args.indexOf("-o") + 1]).startsWith(fs.realpathSync(output) + path.sep), `${e.id} final message stays in the run directory`);
		dirs.add(fs.realpathSync(dir));
		// The evaluator rubric is outside the fixture and absent from the prompt.
		assert.ok(!fs.existsSync(path.join(dir, "rubric.json")));
		assert.ok(!e.prompt.includes("bug-empty-sum") && !e.prompt.includes("docs-spelling"), `${e.id} prompt omits rubric IDs`);
		assert.match(e.prompt, /Completion status: completed/);
		assert.ok(fs.existsSync(path.join(dir, "model-notes.txt")), `${e.id} model writes landed in its fixture`);
	}
	assert.equal(dirs.size, 14, "every execution has a separate fixture");
	// Model writes reached neither the harness repository nor its run evidence.
	assert.equal(h.git("status", "--porcelain"), "", "the harness repository is unchanged");
	assert.ok(!fs.existsSync(path.join(h.root, "model-notes.txt")));
	assert.ok(records.every((r) => fs.realpathSync(r.fixturePath).startsWith(scratchRoot + path.sep)));
	// Paired runs start from the same fixture and differ only in the workflow snapshot.
	const pair = ["bug-1-baseline", "bug-1-candidate"].map((id) => records.find((r) => r.id === id));
	assert.equal(pair[0].conditions.fixtureHash, pair[1].conditions.fixtureHash);
	assert.notEqual(pair[0].fixturePath, pair[1].fixturePath);
});

check("harness", "report-regeneration", () => {
	const { result, output } = defaultLive();
	assert.equal(result.status, 0, result.stderr);
	const h = harnessCopy();
	const read = (name) => fs.readFileSync(path.join(output, name), "utf8");
	const liveSummary = read("summary.md"), liveReport = read("report.json"), records = read("records.json");
	// Offline re-summarization of the same records reproduces the live report exactly.
	const offline = (env = {}) => spawnSync(process.execPath, [h.script, `--summarize=${output}`], {
		cwd: h.root, encoding: "utf8", env: { PATH: `${h.bin}${path.delimiter}${process.env.PATH}`, HOME: h.home, FAKE_CODEX_LOG: path.join(base, "offline-launch.jsonl"), ...env },
	});
	const again = offline();
	assert.equal(again.status, 0, again.stderr);
	assert.equal(read("summary.md"), liveSummary, "summary.md regenerates identically");
	assert.equal(read("report.json"), liveReport, "report.json regenerates identically");
	// Editing judgments.json changes only the judged metric; records stay as recorded.
	const before = JSON.parse(liveReport);
	assert.equal(rowOf(before, "docs-1-candidate").metrics.unnecessaryQuestions.count, null, "unreviewed questions are unknown");
	fs.writeFileSync(path.join(output, "judgments.json"), JSON.stringify({
		schema: "t4-workflow-judgments", version: 1,
		reviews: [{ run: "docs-1-candidate", transcript: "docs-1-candidate/final.txt", reviewer: "maintainer", complete: true }],
		questions: [], completion: [],
	}, null, 2));
	const judged = offline();
	assert.equal(judged.status, 0, judged.stderr);
	const after = JSON.parse(read("report.json"));
	const questions = rowOf(after, "docs-1-candidate").metrics.unnecessaryQuestions;
	assert.equal(questions.review, "complete");
	assert.equal(questions.count, 0, "a completed review with no questions is a known zero");
	assert.equal(rowOf(after, "docs-1-baseline").metrics.unnecessaryQuestions.count, null, "other runs stay unknown");
	assert.notEqual(read("summary.md"), liveSummary);
	assert.deepEqual(after.runs.map((r) => [r.id, r.metrics.missedRequirements]), before.runs.map((r) => [r.id, r.metrics.missedRequirements]), "evaluator outcomes are unchanged");
	assert.equal(read("records.json"), records, "records are consumed read-only");
	assert.ok(!fs.existsSync(path.join(base, "offline-launch.jsonl")), "re-summarizing never launched the model CLI");
});

fs.rmSync(base, { recursive: true, force: true });
if (failed.length) {
	console.error(`check-workflow-evaluations: ${failed.length} failed (${failed.join(", ")}); ${passed.length} passed`);
	process.exit(1);
}
console.error(`check-workflow-evaluations: ${passed.length} passed (${passed.join(", ")})`);
NODE
