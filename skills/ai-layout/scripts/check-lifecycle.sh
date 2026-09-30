#!/usr/bin/env bash
# Lifecycle telemetry (spec 0015): event store, hook and headless instrumentation, attribution,
# interval arithmetic, pricing coverage and failure isolation. Every case runs in disposable
# workspaces under ai-factory/runs/tmp/; expected values are calculated by hand in the comments.
set -euo pipefail
cd "$(dirname "$0")/../../.."
node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, spawnSync, execFileSync } = require("node:child_process");
const { boundary } = require("./skills/ai-layout/templates/ai-factory/make/safe-files.js");
const MAKE = path.resolve("skills/ai-layout/templates/ai-factory/make");
const HOOKS = path.resolve("skills/ai-hooks/scripts");
const FIXTURES = path.resolve("skills/ai-hooks/fixtures");
const store = require(path.join(MAKE, "lifecycle-events.js"))({ boundary });
const lifecycle = require(path.join(MAKE, "lifecycle.js"));
const safe = boundary(path.resolve("ai-factory"));
const scratch = safe.scratch(path.resolve("ai-factory/runs/tmp"));
let cases = 0;
const ok = (label) => {
	cases++;
	if (process.env.VERBOSE) console.log(`ok: ${label}`);
};
const clean = { ...process.env };
for (const key of ["JSON", "DELIVERY", "STEP", "PHASE", "T4_LIFECYCLE_RUN"]) delete clean[key];
const D1 = "d-20260930-aaaaaa";
const D2 = "d-20260930-bbbbbb";
const T0 = Date.parse("2026-09-30T10:00:00.000Z");
const at = (seconds) => new Date(T0 + seconds * 1000).toISOString();
const wall = null; // clock: null forces wall-clock arithmetic, as across two processes
function workspace(name, { enabled = true, completion } = {}) {
	const dir = fs.mkdtempSync(path.join(scratch, `${name}-`));
	fs.mkdirSync(path.join(dir, "ai-factory/contracts"), { recursive: true });
	fs.mkdirSync(path.join(dir, "ai-factory/runs"), { recursive: true });
	execFileSync("git", ["init", "-q"], { cwd: dir });
	fs.writeFileSync(path.join(dir, "ai-factory/contracts/config.json"), JSON.stringify({ schema: "t4-contracts-config", version: 1, code_scope: { include: ["**"] }, ...(enabled === null ? {} : { lifecycle: { enabled } }), ...(completion ? { completion } : {}) }));
	return { dir, ai: path.join(dir, "ai-factory") };
}
const emit = (ai, fields) => store.emit(ai, { host: "cli", clock: wall, ...fields });
function run(ai, { id = store.newId("r"), delivery = D1, start, end, outcome = "succeeded", phase = "run", step = null, session = null, parent = null, attempt = store.newId("a") }) {
	emit(ai, { type: "run_started", run_id: id, delivery_id: delivery, phase, step, session_id: session, parent_run_id: parent, at: at(start) });
	emit(ai, { type: "phase_started", run_id: id, attempt_id: attempt, delivery_id: delivery, phase, step, at: at(start) });
	if (end !== undefined) {
		emit(ai, { type: "phase_ended", run_id: id, attempt_id: attempt, outcome, at: at(end) });
		emit(ai, { type: "run_ended", run_id: id, outcome, at: at(end) });
	}
	return id;
}
let usageCounter = 0;
function usage(ai, { run: runId = null, session = null, time, source = "session", first, last, tokens = 100, cost = 0.01, provenance = "estimated:models.yaml", key, child }) {
	const record = key || require("node:crypto").createHash("sha256").update(`u${usageCounter++}`).digest("hex");
	return emit(ai, {
		event_id: store.hashId("usage", record),
		type: "usage_linked",
		run_id: runId,
		session_id: session,
		at: at(time),
		usage: { source, agent: source === "agent" ? "implementer" : null, model: "m", turns: 1, input_tokens: tokens, output_tokens: 10, cache_read_tokens: 0, cache_write_tokens: 0, cost_usd: cost, cost_provenance: cost === null ? null : provenance, record_key: record, dedupable: true, first_at: first === undefined ? null : at(first), last_at: last === undefined ? null : at(last), ...(child ? { child_session: child } : {}) },
	});
}
const report = (ai, delivery) => lifecycle.aggregate({ ai, delivery, now: T0 + 3600 * 1000 });
const one = (ai, delivery = D1) => report(ai, delivery).deliveries[0];
function hook(name, event, dir, env = {}) {
	return spawnSync(process.execPath, [path.join(HOOKS, `${name}.js`)], { cwd: dir, input: JSON.stringify(event), encoding: "utf8", env: { ...clean, ...env } });
}
const events = (ai) => store.read(ai).events;
const eventFiles = (ai) => (fs.existsSync(store.directory(ai)) ? fs.readdirSync(store.directory(ai)).filter((n) => !n.startsWith(".")) : []);

async function main() {
	// --- the hook copy of the event store is byte-identical ---------------------------------
	assert.deepEqual(fs.readFileSync(path.join(HOOKS, "_lifecycle-events.js")), fs.readFileSync(path.join(MAKE, "lifecycle-events.js")), "skills/ai-hooks/scripts/_lifecycle-events.js must equal make/lifecycle-events.js");
	ok("hook and template event stores are identical");

	// --- writer and reader ------------------------------------------------------------------
	{
		const { ai } = workspace("store");
		const first = emit(ai, { event_id: store.hashId("fixed"), type: "run_started", run_id: "r-0000000000000001", phase: "run", at: at(0) });
		const again = emit(ai, { event_id: store.hashId("fixed"), type: "run_started", run_id: "r-0000000000000001", phase: "run", at: at(5) });
		assert.equal(first.duplicate, false);
		assert.equal(again.duplicate, true, "a replayed event is idempotent");
		assert.equal(eventFiles(ai).length, 1);
		for (const bad of [{ run_id: "../../x" }, { delivery_id: "d-1/../../x" }, { session_id: "a b" }, { phase: "Run Step" }, { reason: "x".repeat(201) }, { outcome: "maybe" }, { type: "guess" }])
			assert.throws(() => emit(ai, { type: "run_started", run_id: "r-0000000000000002", phase: "run", ...bad }), /refused/, JSON.stringify(bad));
		fs.writeFileSync(path.join(store.directory(ai), `${store.hashId("torn")}.json`), '{"schema":"t4-lifecycle-event"');
		fs.writeFileSync(path.join(store.directory(ai), `${store.hashId("future")}.json`), JSON.stringify({ schema: "t4-lifecycle-event", version: 2, event_id: store.hashId("future") }));
		fs.writeFileSync(path.join(store.directory(ai), "notes.txt"), "x");
		const read = store.read(ai);
		assert.equal(read.events.length, 1);
		assert.equal(read.corrupt.length, 2, "a torn file and a stray entry are reported, not dropped");
		assert.equal(read.unsupported.length, 1, "an unknown version is unsupported, not interpreted");
		assert.match(lifecycle.human(report(ai)), /corrupt events: 2/);
		// Concurrent writers: twenty processes, twenty distinct events, none lost.
		const writer = `const {boundary}=require(${JSON.stringify(path.join(MAKE, "safe-files.js"))});const s=require(${JSON.stringify(path.join(MAKE, "lifecycle-events.js"))})({boundary});s.emit(process.argv[1],{host:"cli",type:"run_started",run_id:s.newId("r"),phase:"run"});`;
		const { ai: busy } = workspace("busy");
		await Promise.all(Array.from({ length: 20 }, () => new Promise((resolve, reject) => spawn(process.execPath, ["-e", writer, busy], { stdio: "inherit" }).on("close", (code) => (code === 0 ? resolve() : reject(new Error(`writer ${code}`)))))));
		assert.equal(store.read(busy).events.length, 20);
		assert.deepEqual(fs.readdirSync(store.directory(busy)).filter((n) => n.startsWith(".")), [], "no staged files left behind");
		// A symlinked events directory and an unwritable one are refused.
		const { ai: linked } = workspace("linked");
		fs.mkdirSync(path.join(linked, "runs/lifecycle"), { recursive: true });
		const sink = fs.mkdtempSync(path.join(scratch, "sink-"));
		fs.symlinkSync(sink, store.directory(linked));
		assert.throws(() => emit(linked, { type: "run_started", run_id: "r-0000000000000003", phase: "run" }), /symlink/i);
		assert.deepEqual(fs.readdirSync(sink), []);
		const { ai: locked } = workspace("locked");
		fs.mkdirSync(store.directory(locked), { recursive: true });
		fs.chmodSync(store.directory(locked), 0o500);
		try {
			assert.throws(() => emit(locked, { type: "run_started", run_id: "r-0000000000000004", phase: "run" }));
		} finally {
			fs.chmodSync(store.directory(locked), 0o700);
		}
		ok("writer/reader: idempotent replay, validation, torn and unsupported files, concurrency, symlink and permission refusal");
	}

	// --- AC4 and interval arithmetic --------------------------------------------------------
	{
		const { ai } = workspace("intervals");
		// Two overlapping runs: [0,100] and [50,150] → elapsed is the union, 150 s, not 200 s.
		const a = run(ai, { start: 0, end: 100 });
		run(ai, { start: 50, end: 150, step: "S2" });
		// Waits in run a: [10,30] and [20,40] → union [10,40] = 30 s.
		for (const [s, e] of [[10, 30], [20, 40]]) {
			const w = store.newId("w");
			emit(ai, { type: "wait_started", run_id: a, wait_id: w, at: at(s), reason: "awaiting developer" });
			emit(ai, { type: "wait_ended", run_id: a, wait_id: w, at: at(e) });
		}
		// Two agents working in parallel for 100 s each → effort 200 s, above the 150 s elapsed.
		usage(ai, { run: a, source: "agent", time: 100, first: 0, last: 100 });
		usage(ai, { run: a, source: "agent", time: 100, first: 0, last: 100 });
		const d = one(ai);
		assert.equal(d.metrics.elapsed_s, 150);
		assert.equal(d.metrics.waiting_s, 30);
		// Active: attempts [0,100] ∪ [50,150] = 150 s, minus waits 30 s = 120 s.
		assert.equal(d.metrics.active_s, 120);
		assert.equal(d.metrics.agent_effort_s, 200, "agent effort is labelled and may exceed elapsed");
		assert.ok(d.metrics.agent_effort_s > d.metrics.elapsed_s);
		assert.equal(lifecycle.total([[0, 10], [5, 15], [20, 25]]), 20);
		ok("union arithmetic: parallel runs, overlapping waits, active time and agent effort");
	}

	// --- AC5: partial and unknown, never fabricated -----------------------------------------
	{
		const { ai } = workspace("partial");
		run(ai, { start: 0, end: 60 });
		const open = run(ai, { start: 30 }); // crashed: no end
		let d = one(ai);
		assert.equal(d.metrics.elapsed_s, null, "an open run leaves elapsed unknown");
		assert.equal(d.metrics.elapsed_known_s, 60, "only the measured part is shown, labelled");
		assert.ok(d.metrics.open_run_age_s > 0, "the open run's age is separate");
		assert.ok(d.quality.includes("open_runs"));
		assert.equal(d.metrics.active_s, null);
		assert.equal(d.runs.find((r) => r.run_id === open).ended_at, null, "no end time is invented");
		const w = store.newId("w");
		emit(ai, { type: "wait_started", run_id: open, wait_id: w, at: at(35) });
		d = one(ai);
		assert.equal(d.metrics.waiting_s, null, "a wait with no end leaves waiting unknown");
		const { ai: clock } = workspace("clock");
		run(ai === clock ? ai : clock, { start: 100, end: 40 }); // ends before it starts across processes
		d = one(clock);
		assert.equal(d.runs[0].status, "invalid_clock");
		assert.equal(d.metrics.elapsed_s, null);
		assert.ok(d.quality.includes("invalid_clock"));
		// Same process: the monotonic clock wins even when the wall clock jumps backwards.
		const { ai: mono } = workspace("mono");
		const id = store.newId("r");
		emit(mono, { type: "run_started", run_id: id, delivery_id: D1, phase: "run", at: at(100), clock: { process: "p-0000000000000001", mono_ms: 1000 } });
		emit(mono, { type: "run_ended", run_id: id, outcome: "succeeded", at: at(10), clock: { process: "p-0000000000000001", mono_ms: 6000 } });
		assert.equal(one(mono).runs[0].elapsed_s, 5);
		assert.equal(one(mono).runs[0].timing_quality, "monotonic");
		// A delivery with no runs reports unknown, never zero.
		const { ai: empty } = workspace("empty");
		const e = one(empty, D2);
		assert.deepEqual([e.metrics.elapsed_s, e.metrics.retries, e.tokens.input_tokens, e.cost.known_usd], [null, null, null, null]);
		ok("open runs, open waits, invalid and monotonic clocks, and empty deliveries stay unknown");
	}

	// --- retries, resumptions and reruns ----------------------------------------------------
	{
		const { ai } = workspace("retries");
		run(ai, { start: 0, end: 10, outcome: "failed", step: "S1" });
		run(ai, { start: 20, end: 30, outcome: "succeeded", step: "S1" }); // retry after failure
		run(ai, { start: 40, end: 50, outcome: "succeeded", step: "S1" }); // rerun after success
		run(ai, { start: 0, end: 10, outcome: "interrupted", step: "S2" });
		run(ai, { start: 20, end: 30, outcome: "succeeded", step: "S2" }); // resumption, not a retry
		const d = one(ai);
		assert.deepEqual([d.metrics.retries, d.metrics.resumed, d.metrics.reruns], [1, 1, 1]);
		assert.deepEqual(d.outcomes, { failed: 1, succeeded: 3, interrupted: 1 });
		ok("retries count failures only; resumptions and reruns are separate");
	}

	// --- AC2, AC6: explicit attribution only ------------------------------------------------
	{
		const { ai } = workspace("attribution");
		const r1 = run(ai, { start: 0, end: 100, delivery: D1 });
		const r2 = run(ai, { start: 50, end: 200, delivery: D2 });
		const loose = run(ai, { start: 0, end: 10, delivery: null });
		emit(ai, { event_id: store.hashId("bind", "sess-1", r1), type: "session_bound", session_id: "sess-1", run_id: r1, at: at(1) });
		emit(ai, { event_id: store.hashId("bind", "sess-1", r2), type: "session_bound", session_id: "sess-1", run_id: r2, at: at(51) });
		usage(ai, { session: "sess-1", time: 20, first: 10, last: 20 }); // only r1 overlaps → D1
		usage(ai, { session: "sess-1", time: 70, first: 60, last: 70 }); // both overlap → ambiguous
		usage(ai, { session: "sess-1", time: 180, first: 150, last: 180 }); // only r2 → D2
		usage(ai, { session: "sess-2", time: 20 }); // unbound session
		usage(ai, { run: r2, source: "agent", time: 90 }); // delegated agent names its run explicitly
		const all = report(ai);
		const d1 = all.deliveries.find((d) => d.delivery_id === D1);
		const d2 = all.deliveries.find((d) => d.delivery_id === D2);
		assert.equal(d1.tokens.records, 1);
		assert.equal(d2.tokens.records, 2);
		assert.deepEqual(d2.attribution, { session_binding: 1, explicit: 1 });
		assert.equal(all.unattributed.usage.records, 2, "ambiguous and unbound usage stays visible");
		assert.deepEqual(Object.keys(all.unattributed.reasons).sort(), ["ambiguous: 2 runs bound to this session overlap it", "no run is bound to this session"]);
		assert.deepEqual(all.unattributed.runs.map((r) => r.run_id), [loose], "runs without a delivery are listed");
		// A child run delegated from a D1 run belongs to D1 through its explicit parent only.
		run(ai, { start: 5, end: 8, delivery: null, parent: r1 });
		assert.equal(one(ai).coverage.runs, 2);
		ok("attribution: explicit runs and bindings only; ambiguous overlap and unbound sessions unattributed");
	}

	// --- AC7: pricing coverage --------------------------------------------------------------
	{
		const { ai } = workspace("pricing");
		const r = run(ai, { start: 0, end: 10 });
		usage(ai, { run: r, time: 5, cost: 0.25 });
		usage(ai, { run: r, time: 5, cost: 0, provenance: "estimated:models.yaml" });
		usage(ai, { run: r, time: 5, cost: null });
		const d = one(ai);
		assert.equal(d.cost.known_usd, 0.25);
		assert.equal(d.cost.total_usd, null, "unknown pricing leaves the total unknown");
		assert.deepEqual([d.cost.zero_priced_records, d.cost.unknown_records], [1, 1], "zero-priced and unpriced are distinct");
		const t = lifecycle.telemetryFor({ ai, delivery: D1 });
		assert.equal(t.metrics.cost_usd, null);
		assert.equal(t.metrics.cost_usd_known, 0.25);
		assert.equal(t.metrics.cost_unknown_records, 1);
		ok("pricing: known subtotal, unknown remainder, zero-priced distinct from missing");
	}

	// --- AC1, AC3, AC8, AC9: hooks write the same rows and link usage once ------------------
	{
		const transcript = (dir, name, records) => {
			const file = path.join(dir, name);
			fs.writeFileSync(file, records.map((r) => JSON.stringify(r)).join("\n") + "\n");
			return file;
		};
		const records = [
			{ type: "assistant", uuid: "t-1", timestamp: at(20), message: { model: "claude-sonnet-4-5", usage: { input_tokens: 100, output_tokens: 10, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } } },
			{ type: "user", uuid: "t-2", timestamp: at(21), message: { role: "user", content: "SECRET-PROMPT-TEXT" } },
			{ type: "assistant", uuid: "t-3", timestamp: at(30), message: { model: "claude-sonnet-4-5", usage: { input_tokens: 50, output_tokens: 5, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } } },
		];
		const rows = {};
		for (const enabled of [false, true, null]) {
			const { dir, ai } = workspace(`hooks-${enabled}`, { enabled });
			const file = transcript(dir, "t.jsonl", records);
			const stop = hook("session-stop", { session_id: "sess-h", cwd: dir, transcript_path: file, hook_event_name: "Stop" }, dir);
			assert.equal(stop.status, 0);
			assert.equal(stop.stderr, "", stop.stderr);
			const agent = transcript(dir, "a.jsonl", [{ type: "assistant", uuid: "g-1", timestamp: at(22), message: { model: "claude-sonnet-4-5", usage: { input_tokens: 7, output_tokens: 1, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } } }]);
			hook("subagent-stop", { session_id: "sess-h", cwd: dir, agent_id: "agent-1", agent_type: "implementer", agent_transcript_path: agent }, dir);
			rows[enabled] = fs.readFileSync(path.join(ai, "runs/log.pending.csv"), "utf8").split("\n").map((line) => line.replace(/^[^,]+,/, "")).join("\n");
			if (enabled) {
				assert.equal(events(ai).length, 2, "one usage link per row");
				// Replay: the same Stop again claims nothing new, writes no row and no event.
				hook("session-stop", { session_id: "sess-h", cwd: dir, transcript_path: file }, dir);
				hook("subagent-stop", { session_id: "sess-h", cwd: dir, agent_id: "agent-1", agent_type: "implementer", agent_transcript_path: agent }, dir);
				assert.equal(events(ai).length, 2);
				// A copied transcript under another session re-counts in the CSV (unchanged behaviour),
				// but the lifecycle link is keyed by the source records, so it is counted once.
				hook("session-stop", { session_id: "sess-copy", cwd: dir, transcript_path: file }, dir);
				const agg = report(ai);
				assert.equal(agg.deduplicated.replayed_records, 0);
				assert.equal(eventFiles(ai).length, 2, "the copied transcript produced no second link");
				const text = eventFiles(ai).map((name) => fs.readFileSync(path.join(store.directory(ai), name), "utf8")).join("");
				assert.ok(!text.includes("SECRET-PROMPT-TEXT"), "events never carry transcript content");
				const link = events(ai).find((e) => e.usage.source === "session");
				assert.deepEqual([link.usage.input_tokens, link.usage.first_at, link.usage.last_at], [150, at(20), at(30)]);
				assert.equal(link.usage.cost_provenance, "estimated:built-in-rates");
			} else assert.equal(eventFiles(ai).length, 0, "disabled or absent config writes no lifecycle event");
		}
		assert.equal(rows[true], rows[false], "the run-log rows are identical with lifecycle on and off");
		assert.equal(rows[null], rows[false]);
		// A telemetry write failure never costs the row or fails the hook.
		const { dir, ai } = workspace("hook-fail");
		fs.mkdirSync(path.join(ai, "runs/lifecycle"), { recursive: true });
		fs.symlinkSync(fs.mkdtempSync(path.join(scratch, "sink-")), store.directory(ai));
		const file = transcript(dir, "t.jsonl", records);
		const failed = hook("session-stop", { session_id: "sess-f", cwd: dir, transcript_path: file }, dir);
		assert.equal(failed.status, 0);
		assert.equal(failed.stdout, "", "hooks keep stdout clean");
		assert.match(failed.stderr, /Lifecycle event not recorded/);
		assert.equal(fs.readFileSync(path.join(ai, "runs/log.pending.csv"), "utf8").trim().split("\n").length, 2, "header and the row are still written");
		// A malformed lifecycle config is ignored with one diagnostic, the row still lands.
		const { dir: d2, ai: a2 } = workspace("hook-config");
		fs.writeFileSync(path.join(a2, "contracts/config.json"), JSON.stringify({ lifecycle: { enabled: "yes" } }));
		const bad = hook("session-stop", { session_id: "sess-c", cwd: d2, transcript_path: transcript(d2, "t.jsonl", records) }, d2);
		assert.match(bad.stderr, /Lifecycle config ignored/);
		assert.ok(fs.existsSync(path.join(a2, "runs/log.pending.csv")));
		ok("hooks: identical rows on/off, one link per unique record, replay and copies deduplicated, no content, failures isolated");
	}

	// --- interactive binding through the command hook --------------------------------------
	{
		const { dir, ai } = workspace("binding2");
		fs.mkdirSync(path.join(ai, "make"), { recursive: true });
		for (const file of ["lifecycle.js", "lifecycle-events.js", "safe-files.js"]) fs.copyFileSync(path.join(MAKE, file), path.join(ai, "make", file));
		const cli = (...args) => spawnSync(process.execPath, [path.join(ai, "make/lifecycle.js"), ...args], { cwd: dir, env: clean, encoding: "utf8" });
		const started = cli("start", "--phase", "run", "--delivery", D1, "--step", "S1");
		assert.equal(started.status, 0, started.stderr);
		const runId = /started run (r-[0-9a-f]{16})/.exec(started.stdout)[1];
		const cmd = hook("log-cmd", { session_id: "sess-i", cwd: dir, tool_name: "Bash", tool_input: { command: "node ai-factory/make/lifecycle.js start --phase run --delivery d-20260930-aaaaaa --step S1" }, tool_response: { stdout: started.stdout, stderr: "" } }, dir);
		assert.equal(cmd.status, 0);
		assert.equal(cmd.stdout, "");
		assert.equal(events(ai).filter((e) => e.type === "session_bound").length, 1);
		const now = new Date().toISOString();
		fs.writeFileSync(path.join(dir, "t.jsonl"), JSON.stringify({ type: "assistant", uuid: "i-1", timestamp: now, message: { model: "claude-sonnet-4-5", usage: { input_tokens: 9, output_tokens: 1, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } } }) + "\n");
		hook("session-stop", { session_id: "sess-i", cwd: dir, transcript_path: path.join(dir, "t.jsonl") }, dir);
		assert.equal(cli("end", "--run", runId, "--outcome", "succeeded").status, 0);
		const d = lifecycle.aggregate({ ai, delivery: D1 }).deliveries[0];
		assert.equal(d.tokens.input_tokens, 9);
		assert.deepEqual(d.attribution, { session_binding: 1 });
		assert.equal(d.runs[0].outcome, "succeeded");
		assert.equal(cli("end", "--run", runId, "--outcome", "failed").stdout.trim(), `lifecycle: run ${runId} had already ended`);
		const w = /wait (w-[0-9a-f]{16})/.exec(cli("wait-start", "--run", runId, "--reason", "review").stdout)[1];
		assert.equal(cli("wait-end", "--run", runId, "--wait", w).status, 0);
		// Disabled: recording commands exit 0 with a stderr note and write nothing.
		fs.writeFileSync(path.join(ai, "contracts/config.json"), JSON.stringify({ schema: "t4-contracts-config", version: 1, code_scope: {} }));
		const before = eventFiles(ai).length;
		const off = cli("start", "--phase", "run");
		assert.equal(off.status, 0);
		assert.equal(off.stdout, "");
		assert.match(off.stderr, /not enabled/);
		assert.equal(eventFiles(ai).length, before);
		assert.equal(cli("start").status, 2, "a missing argument is an invocation error");
		assert.equal(cli("start", "--phase", "run", "--delivery", "../x").status, 2);
		// Report JSON: stdout is one document, diagnostics stay on stderr.
		const json = cli("report", "--json");
		assert.equal(json.status, 0);
		assert.equal(JSON.parse(json.stdout).schema, "t4-lifecycle-report");
		ok("interactive binding via the command hook; CLI best effort, disabled no-op, JSON stdout");
	}

	// --- headless runner: explicit run identity, outcomes, no prompt content ---------------
	{
		const { dir, ai } = workspace("headless");
		fs.cpSync(MAKE, path.join(ai, "make"), { recursive: true });
		fs.mkdirSync(path.join(ai, "tasks"));
		fs.writeFileSync(path.join(ai, "tasks/chore.md"), "Do the chore.");
		fs.writeFileSync(path.join(ai, "models.yaml"), "claude:\ncodex:\nreview:\n");
		const fake = path.join(ai, "fake-cli");
		fs.writeFileSync(fake, `#!/usr/bin/env node
const fs=require('node:fs');let input='';process.stdin.on('data',c=>input+=c);process.stdin.on('end',()=>{
 fs.writeFileSync('ai-factory/runs/child-env.txt',String(process.env.T4_LIFECYCLE_RUN||''));
 if(process.env.FAIL_CLI){process.exitCode=3;return;}
 process.stdout.write(JSON.stringify({session_id:'child-sess',num_turns:2,total_cost_usd:0.5,result:'done',usage:{input_tokens:40,output_tokens:4,cache_read_input_tokens:0,cache_creation_input_tokens:0}}));
});
`, { mode: 0o700 });
		const env = { ...clean, TOOL: "claude", CMD: fake, MODEL: "", INPUT: "SECRET-INPUT-TEXT", INPUT_FILE: "", DELIVERY: D1, STEP: "S2", MAKEFLAGS: "", MAKEOVERRIDES: "" };
		const okRun = spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", "ai", "TASK=chore"], { cwd: dir, env, encoding: "utf8" });
		assert.equal(okRun.status, 0, okRun.stderr);
		const runStart = events(ai).find((e) => e.type === "run_started");
		assert.equal(fs.readFileSync(path.join(ai, "runs/child-env.txt"), "utf8"), runStart.run_id, "the child inherits its run identity");
		assert.deepEqual([runStart.host, runStart.delivery_id, runStart.step, runStart.task], ["headless", D1, "S2", "chore"]);
		let d = lifecycle.aggregate({ ai, delivery: D1 }).deliveries[0];
		assert.deepEqual([d.runs[0].outcome, d.tokens.input_tokens, d.cost.known_usd, d.cost.provenance["host-reported"]], ["succeeded", 40, 0.5, 1]);
		// The child's own hooks saw the same session: the headless envelope drops out, no double count.
		usage(ai, { session: "child-sess", run: runStart.run_id, time: 0, tokens: 40 });
		const agg = lifecycle.aggregate({ ai, delivery: D1 });
		assert.equal(agg.deliveries[0].tokens.input_tokens, 40);
		assert.equal(agg.deduplicated.headless_seen_by_hooks, 1);
		const failed = spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", "ai", "TASK=chore"], { cwd: dir, env: { ...env, FAIL_CLI: "1" }, encoding: "utf8" });
		assert.notEqual(failed.status, 0, "telemetry never turns a failed run into a pass");
		d = lifecycle.aggregate({ ai, delivery: D1 }).deliveries[0];
		assert.equal(d.outcomes.failed, 1);
		const text = eventFiles(ai).map((name) => fs.readFileSync(path.join(store.directory(ai), name), "utf8")).join("");
		assert.ok(!text.includes("SECRET-INPUT-TEXT") && !text.includes("done"), "no prompt or output content in events");
		// A broken lifecycle store does not fail an otherwise successful run.
		fs.rmSync(path.join(ai, "runs/lifecycle"), { recursive: true });
		fs.mkdirSync(path.join(ai, "runs/lifecycle"));
		fs.symlinkSync(fs.mkdtempSync(path.join(scratch, "sink-")), path.join(ai, "runs/lifecycle/events"));
		const isolated = spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", "ai", "TASK=chore"], { cwd: dir, env, encoding: "utf8" });
		assert.equal(isolated.status, 0, isolated.stderr);
		assert.match(isolated.stderr, /lifecycle: event not recorded/);
		assert.match(isolated.stdout, /^run saved:/m, "stdout carries only the runner's own output");
		ok("headless: inherited run identity, outcomes, host-reported cost, dedupe with hooks, isolation, no content");
	}

	// --- AC1: make cost is unchanged ---------------------------------------------------------
	{
		const outputs = [];
		for (const enabled of [false, true]) {
			const { dir, ai } = workspace(`cost-${enabled}`, { enabled });
			fs.copyFileSync(path.join(FIXTURES, "cost/two-tools.csv"), path.join(ai, "runs/log.csv"));
			if (enabled) run(ai, { start: 0, end: 10 });
			const result = spawnSync(process.execPath, [path.join(MAKE, "cost.js"), path.join(ai, "runs/log.csv")], { cwd: dir, env: { ...clean, JSON: "1" }, encoding: "utf8" });
			assert.equal(result.status, 0, result.stderr);
			outputs.push(result.stdout.replace(/"log": "[^"]+"/, ""));
		}
		assert.equal(outputs[0], outputs[1], "make cost JSON is identical with lifecycle on and off");
		ok("make cost export unchanged");
	}

	// --- export, completion report and retention --------------------------------------------
	{
		const { dir, ai } = workspace("export");
		fs.mkdirSync(path.join(ai, "make"), { recursive: true });
		for (const file of ["lifecycle.js", "lifecycle-events.js", "safe-files.js"]) fs.copyFileSync(path.join(MAKE, file), path.join(ai, "make", file));
		const r = run(ai, { start: 0, end: 30 });
		usage(ai, { run: r, time: 10, cost: null });
		const exported = spawnSync(process.execPath, [path.join(ai, "make/lifecycle.js"), "export", "--json"], { cwd: dir, env: { ...clean, DELIVERY: D1 }, encoding: "utf8" });
		assert.equal(exported.status, 0, exported.stderr);
		const doc = JSON.parse(exported.stdout);
		assert.deepEqual([doc.schema, doc.version, doc.coverage.measured, doc.coverage.total, doc.metrics.elapsed_s, doc.metrics.cost_usd], ["t4-delivery-telemetry", 1, 1, 1, 30, null]);
		for (const value of Object.values(doc.metrics)) assert.ok(value === null || typeof value === "number");
		assert.deepEqual(JSON.parse(fs.readFileSync(path.join(ai, `runs/telemetry/${D1}.json`), "utf8")), doc);
		// Retention: D1 (with a saved report) keeps its old events; D2 loses them, recorded.
		const old = { start: -200 * 86400, end: -200 * 86400 + 10 };
		run(ai, { ...old, delivery: D2 });
		run(ai, { ...old, delivery: D1 });
		fs.mkdirSync(path.join(ai, `reports/${D1}`), { recursive: true });
		const now = T0;
		const dry = lifecycle.prune({ ai, days: 90, now });
		assert.deepEqual([dry.events, dry.deliveries, dry.write], [4, [D2], false]);
		const before = eventFiles(ai).length;
		assert.equal(eventFiles(ai).length, before, "a dry run removes nothing");
		lifecycle.prune({ ai, days: 90, now, write: true });
		assert.equal(eventFiles(ai).length, before - 4);
		assert.ok(one(ai, D2).quality.includes("detail_pruned"), "removed detail is marked, not read as zero");
		assert.equal(one(ai, D1).coverage.runs, 2, "a delivery with a saved report keeps its events");
		ok("export matches the telemetry contract; retention keeps reported deliveries and marks pruned detail");
	}
	{
		// The completion report computes telemetry from live events when lifecycle is enabled.
		const dir = fs.mkdtempSync(path.join(scratch, "report-"));
		fs.cpSync(path.resolve("skills/ai-layout/fixtures/contracts/planned"), dir, { recursive: true });
		fs.cpSync(MAKE, path.join(dir, "ai-factory/make"), { recursive: true });
		const git = (...args) => execFileSync("git", ["-c", "user.name=f", "-c", "user.email=f@example.invalid", "-c", "commit.gpgsign=false", ...args], { cwd: dir, stdio: "pipe" });
		git("init", "-q", "-b", "main");
		git("add", "-A");
		git("commit", "-q", "-m", "fixture");
		const c = (...args) => {
			const result = spawnSync(process.execPath, [path.join(dir, "ai-factory/make/contracts.js"), ...args], { cwd: dir, env: clean, encoding: "utf8" });
			assert.equal(result.status, 0, `${args.join(" ")}\n${result.stderr}`);
			return result;
		};
		c("enable");
		const config = JSON.parse(fs.readFileSync(path.join(dir, "ai-factory/contracts/config.json"), "utf8"));
		fs.writeFileSync(path.join(dir, "ai-factory/contracts/config.json"), JSON.stringify({ ...config, completion: { require_review: false }, lifecycle: { enabled: true } }));
		c("init", "spec", "ai-factory/specs/0001-csv-export.md");
		c("init", "plan", "ai-factory/plans/0001-csv-export.md", "--spec", "ai-factory/specs/0001-csv-export.md");
		const id = JSON.parse(fs.readFileSync(path.join(dir, "ai-factory/specs/0001-csv-export.contract.json"), "utf8")).delivery_id;
		const planFile = path.join(dir, "ai-factory/plans/0001-csv-export.md");
		for (const step of [1, 2, 3]) {
			c("record", "--delivery", id, "--step", `S${step}`);
			fs.writeFileSync(planFile, fs.readFileSync(planFile, "utf8").replace(new RegExp(`^- \\[ \\] \\*\\*Step ${step} `, "m"), `- [x] **Step ${step} `));
		}
		c("record", "--delivery", id, "--phase", "final");
		const report = () => {
			const result = spawnSync(process.execPath, [path.join(dir, "ai-factory/make/delivery-report.js"), id, "--json"], { cwd: dir, env: clean, encoding: "utf8" });
			assert.equal(result.status, 0, result.stderr);
			return JSON.parse(result.stdout);
		};
		let value = report();
		assert.equal(value.telemetry.status, "unavailable", "enabled but no runs yet: unavailable, not zero");
		const ai = path.join(dir, "ai-factory");
		const r = run(ai, { start: 0, end: 30, delivery: id });
		usage(ai, { run: r, time: 10, cost: 0.02 });
		value = report();
		assert.equal(value.status, "ready", "telemetry never changes readiness");
		assert.equal(value.telemetry.status, "available");
		assert.match(value.telemetry.source, /lifecycle events/);
		assert.deepEqual([value.telemetry.metrics.elapsed_s, value.telemetry.metrics.cost_usd], [30, 0.02]);
		const second = run(ai, { start: 40, delivery: id }); // an open run: partial, still ready
		void second;
		value = report();
		assert.equal(value.status, "ready");
		assert.equal(value.telemetry.status, "partial");
		assert.equal(value.telemetry.metrics.elapsed_s, null);
		assert.match(fs.readFileSync(path.join(ai, `reports/${id}/completion.md`), "utf8"), /- elapsed_s: unknown/);
		ok("completion report consumes live lifecycle telemetry without changing readiness");
	}
}
main()
	.then(() => console.log(`lifecycle ok — ${cases} cases: event store, interval arithmetic, partial and unknown metrics, retries, explicit attribution, pricing coverage, hooks unchanged and deduplicated, interactive binding, headless runs, make cost unchanged, export and retention`))
	.catch((error) => {
		console.error(`FAIL: ${error.message}`);
		if (process.env.VERBOSE) console.error(error.stack);
		process.exitCode = 1;
	})
	.finally(() => fs.rmSync(scratch, { recursive: true, force: true }));
NODE
