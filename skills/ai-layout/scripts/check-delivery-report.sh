#!/usr/bin/env bash
# Delivery completion report (spec 0014). Each scenario's expected status is fixed here first;
# evidence is produced by contracts.js in disposable Git repositories under ai-factory/runs/tmp/.
set -euo pipefail
cd "$(dirname "$0")/../../.."
node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, spawnSync, execFileSync } = require("node:child_process");
const { boundary } = require("./skills/ai-layout/templates/ai-factory/make/safe-files.js");
const MAKE = path.resolve("skills/ai-layout/templates/ai-factory/make");
const FIXTURES = path.resolve("skills/ai-layout/fixtures/contracts");
const SCHEMA = path.resolve("skills/ai-layout/templates/ai-factory/contracts/schema/report.v1.json");
assert.ok(fs.existsSync(path.join(MAKE, "delivery-report.js")), "FAIL: make/delivery-report.js is not implemented yet");
const safe = boundary(path.resolve("ai-factory"));
const scratch = safe.scratch(path.resolve("ai-factory/runs/tmp"));
let cases = 0;
const ok = (label) => {
	cases++;
	if (process.env.VERBOSE) console.log(`ok: ${label}`);
};
const clean = { ...process.env };
for (const key of ["JSON", "DELIVERY", "STEP", "PHASE", "REQUIRE", "CONTRACT_FIXTURE_EXIT", "CONTRACT_FIXTURE_RED_EXIT"]) delete clean[key];
const git = (dir, ...args) => execFileSync("git", ["-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", ...args], { cwd: dir, stdio: "pipe" });
const read = (dir, file) => fs.readFileSync(path.join(dir, file), "utf8");
const write = (dir, file, text) => fs.writeFileSync(path.join(dir, file), text);
const json = (dir, file) => JSON.parse(read(dir, file));
const writeJson = (dir, file, value) => write(dir, file, `${JSON.stringify(value, null, 2)}\n`);
const SPEC = "ai-factory/specs/0001-csv-export.md";
const PLAN = "ai-factory/plans/0001-csv-export.md";
const SPEC_SIDE = "ai-factory/specs/0001-csv-export.contract.json";
const PLAN_SIDE = "ai-factory/plans/0001-csv-export.contract.json";
const QUICK = "ai-factory/quick/fix-date-format.md";
function project(name) {
	const dir = fs.mkdtempSync(path.join(scratch, `${name}-`));
	fs.cpSync(path.join(FIXTURES, name), dir, { recursive: true });
	fs.mkdirSync(path.join(dir, "ai-factory/make"), { recursive: true });
	for (const file of ["contracts.js", "gate.js", "safe-files.js", "delivery-report.js"])
		fs.copyFileSync(path.join(MAKE, file), path.join(dir, "ai-factory/make", file));
	git(dir, "init", "-q", "-b", "main");
	git(dir, "add", "-A");
	git(dir, "commit", "-q", "-m", "fixture");
	git(dir, "checkout", "-q", "-b", "feature");
	return dir;
}
const node = (dir, script, args, env = {}) => spawnSync(process.execPath, [path.join(dir, "ai-factory/make", script), ...args], { cwd: dir, env: { ...clean, ...env }, encoding: "utf8" });
function expect(result, status, label) {
	assert.equal(result.status, status, `${label}\nstdout:${result.stdout}\nstderr:${result.stderr}`);
	return result;
}
const c = (dir, args, env, status = 0) => expect(node(dir, "contracts.js", args, env), status, `contracts ${args.join(" ")}`);
const tick = (dir, step, mark = "x") => write(dir, PLAN, read(dir, PLAN).replace(new RegExp(`^- \\[.\\] \\*\\*Step ${step} `, "m"), `- [${mark}] **Step ${step} `));
function policy(dir, completion) {
	const config = json(dir, "ai-factory/contracts/config.json");
	writeJson(dir, "ai-factory/contracts/config.json", { ...config, completion });
}
function review(dir, id, { verdict = "approve", findings = [] } = {}) {
	const { recordReview } = require(path.join(dir, "ai-factory/make/contracts.js"));
	const approved = verdict === "approve" && !findings.some((f) => f.severity === "blocker");
	recordReview({ root: dir, delivery: id, approved, verdict, findings, tool: "claude", outputHash: "0".repeat(64) });
}
function planned({ steps = 0, final = false, reviewed = false } = {}) {
	const dir = project("planned");
	c(dir, ["enable"]);
	c(dir, ["init", "spec", SPEC]);
	c(dir, ["init", "plan", PLAN, "--spec", SPEC]);
	const id = json(dir, SPEC_SIDE).delivery_id;
	for (let step = 1; step <= steps; step++) {
		c(dir, ["record", "--delivery", id, "--step", `S${step}`]);
		tick(dir, step);
	}
	if (final) c(dir, ["record", "--delivery", id, "--phase", "final"]);
	if (reviewed) review(dir, id);
	return { dir, id };
}
function report(dir, id, status) {
	const result = node(dir, "delivery-report.js", [id, "--json"]);
	assert.ok([0, 1].includes(result.status), `report exits 0/1\n${result.stdout}\n${result.stderr}`);
	const value = JSON.parse(result.stdout);
	if (status !== undefined) assert.equal(value.status, status, JSON.stringify(value.reasons, null, 1));
	assert.equal(result.status, value.status === "ready" ? 0 : 1, "exit 0 only when ready");
	return value;
}
const has = (value, code, ref) => value.reasons.some((item) => item.code === code && (!ref || String(item.evidence_ref).includes(ref)));
function tree(dir, skip = []) {
	const out = [];
	const walk = (at) => {
		for (const entry of fs.readdirSync(at, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
			const file = path.join(at, entry.name);
			const relative = path.relative(dir, file);
			if (entry.name === ".git" || skip.some((prefix) => relative.startsWith(prefix))) continue;
			const stat = fs.lstatSync(file);
			// Directories by name only: creating ai-factory/reports/ touches its parent's mtime.
			if (entry.isDirectory()) {
				out.push(`${relative}/`);
				walk(file);
			} else out.push(`${relative} ${stat.mtimeMs} ${stat.size}`);
		}
	};
	walk(dir);
	return out.join("\n");
}
// Markdown and JSON must agree on status, counts and evidence identifiers.
function parity(dir, id) {
	const value = json(dir, `ai-factory/reports/${id}/completion.json`);
	const md = read(dir, `ai-factory/reports/${id}/completion.md`);
	assert.equal(md.match(/^\*\*Status:\*\* (\S+)$/m)[1], value.status);
	const counts = md.match(/^\*\*Criteria:\*\* (\d+) \(passed (\d+), attested (\d+), pending (\d+), failed (\d+), uncovered (\d+), unverified (\d+)\)$/m).slice(1).map(Number);
	assert.deepEqual(counts, ["criteria", "passed", "attested", "pending", "failed", "uncovered", "unverified"].map((key) => value.counts[key]));
	const refs = new Set([...value.verification.map((item) => item.evidence), ...value.criteria.flatMap((row) => row.evidence), ...value.reasons.map((item) => item.evidence_ref).filter(Boolean)]);
	for (const ref of refs) assert.ok(md.includes(ref), `Markdown names ${ref}`);
	for (const row of value.criteria) assert.match(md, new RegExp(`^\\| ${row.id} \\|.*\\| ${row.result} \\| ${row.basis} \\|`, "m"), `row ${row.id}`);
	for (const item of value.reasons) assert.ok(md.includes(`| ${item.state} | ${item.code} |`), `reason ${item.code}`);
	return { value, md };
}

async function main() {
	// --- the JSON schema document matches what is produced ----------------------------------
	const schema = JSON.parse(fs.readFileSync(SCHEMA, "utf8"));
	{
		const { dir, id } = planned({ steps: 3, final: true, reviewed: true });
		const before = tree(dir, ["ai-factory/reports"]);
		const value = report(dir, id, "ready");
		for (const key of schema.required) assert.ok(Object.hasOwn(value, key), `report has ${key}`);
		assert.equal(value.schema, "t4-delivery-report");
		assert.equal(value.version, 1);
		assert.deepEqual(value.counts, { criteria: 3, passed: 3, attested: 0, pending: 0, failed: 0, uncovered: 0, unverified: 0 });
		assert.deepEqual(value.criteria.map((row) => [row.id, row.steps, row.basis]), [["AC1", ["S1"], "automated"], ["AC2", ["S2"], "automated"], ["AC3", ["S3"], "automated"]]);
		assert.equal(value.delivery.tracker_key, "DEMO-12");
		assert.equal(value.review.verdict, "approve");
		assert.equal(value.mr_draft.draft, true);
		assert.match(value.mr_draft.body, /Draft generated from local evidence/);
		assert.equal(tree(dir, ["ai-factory/reports"]), before, "reporting changes nothing but ai-factory/reports/");
		assert.equal(node(dir, "contracts.js", ["validate", id]).status, 0, "writing the report does not make evidence stale");
		parity(dir, id);
		// Regeneration over identical evidence differs only in generated_at.
		const first = read(dir, `ai-factory/reports/${id}/completion.json`).replace(/"generated_at": "[^"]+"/, "");
		const firstMd = read(dir, `ai-factory/reports/${id}/completion.md`).replace(/^\*\*Generated:\*\* \S+/m, "");
		report(dir, id, "ready");
		assert.equal(read(dir, `ai-factory/reports/${id}/completion.json`).replace(/"generated_at": "[^"]+"/, ""), first);
		assert.equal(read(dir, `ai-factory/reports/${id}/completion.md`).replace(/^\*\*Generated:\*\* \S+/m, ""), firstMd);
		assert.deepEqual(fs.readdirSync(path.join(dir, `ai-factory/reports/${id}`)).sort(), ["completion.json", "completion.md"], "no temporary files left behind");
		// Human mode names the files and says nothing was published.
		const human = node(dir, "delivery-report.js", [id]);
		assert.equal(human.status, 0);
		assert.match(human.stdout, /^delivery-report: ready/);
		assert.match(human.stdout, /nothing was published/);
		ok("complete delivery → ready; parity, stability, read-only sources");
	}

	// --- negative paths: each prevents ready, with its reason and evidence ------------------
	{
		const { dir, id } = planned({ steps: 1 });
		const value = report(dir, id, "incomplete");
		assert.ok(has(value, "UNFINISHED"));
		assert.deepEqual(value.criteria.map((row) => row.result), ["pending", "pending", "pending"]);
		assert.ok(has(value, "REVIEW_PENDING"));
		parity(dir, id);
		ok("unfinished → incomplete");
	}
	{
		const { dir, id } = planned({ steps: 1 });
		c(dir, ["record", "--delivery", id, "--step", "S2"], { CONTRACT_FIXTURE_EXIT: "3" }, 1);
		tick(dir, 2);
		const value = report(dir, id, "blocked");
		assert.ok(has(value, "E_EVIDENCE_FAILED", "S2-step.json"), "the failed check stays visible with its evidence");
		assert.ok(has(value, "UNFINISHED"), "every contributing reason is listed, not only the winner");
		assert.equal(value.criteria.find((row) => row.id === "AC2").result, "failed");
		parity(dir, id);
		ok("failed required check → blocked");
	}
	{
		const { dir, id } = planned({ steps: 3, final: true, reviewed: true });
		write(dir, SPEC, read(dir, SPEC).replace("one line per row", "one line per row, in order"));
		const value = report(dir, id, "unverified");
		assert.ok(has(value, "S_ARTIFACT_CHANGED") && has(value, "S_SPEC_CHANGED"));
		ok("stale spec → unverified");
	}
	{
		const { dir, id } = planned({ steps: 3, final: true, reviewed: true });
		write(dir, "src/export.js", `${read(dir, "src/export.js")}// later edit\n`);
		const value = report(dir, id, "unverified");
		assert.ok(has(value, "S_CODE_CHANGED", "final.json"));
		assert.ok(has(value, "REVIEW_STALE", "review.json"));
		ok("code changed after final and review → unverified");
	}
	{
		const { dir, id } = planned({ steps: 3, final: false });
		const value = report(dir, id, "unverified");
		assert.ok(has(value, "E_EVIDENCE_NOT_RUN", "final.json"), "missing final evidence");
		assert.ok(has(value, "E_EVIDENCE_NOT_RUN", "review.json"), "review is required by default");
		ok("missing required evidence → unverified");
	}
	{
		const { dir, id } = planned({ steps: 3, final: true });
		policy(dir, { require_review: false });
		report(dir, id, "ready");
		ok("policy can waive review for planned work");
	}
	{
		const { dir, id } = planned({ steps: 3 });
		const plan = json(dir, PLAN_SIDE);
		plan.steps[2].verify = [{ argv: ["node", "test/slow.js"], phase: "final" }];
		writeJson(dir, PLAN_SIDE, plan);
		const child = spawn(process.execPath, [path.join(dir, "ai-factory/make/contracts.js"), "record", "--delivery", id, "--phase", "final"], { cwd: dir, env: clean, stdio: "ignore" });
		await new Promise((resolve) => setTimeout(resolve, 700));
		child.kill("SIGINT");
		assert.equal(await new Promise((resolve) => child.once("close", resolve)), 130);
		review(dir, id);
		const value = report(dir, id, "unverified");
		assert.ok(has(value, "INTERRUPTED", "final.json"), "interruption is visible and is not a known failure");
		assert.ok(!has(value, "E_EVIDENCE_FAILED"));
		ok("interrupted verification → unverified");
	}
	{
		const { dir, id } = planned({ steps: 3, final: true });
		review(dir, id, { verdict: "request_changes", findings: [{ severity: "blocker", file: "src/export.js", line: 1, issue: "Rows lose their order", suggestion: "Keep the order" }] });
		let value = report(dir, id, "blocked");
		assert.ok(has(value, "REVIEW_BLOCKER", "review.json"));
		assert.deepEqual(value.review.findings.map((f) => [f.severity, f.blocking, f.issue]), [["blocker", true, "Rows lose their order"]]);
		assert.ok(!JSON.stringify(value).includes("Keep the order"), "only the selected finding summary is kept");
		review(dir, id, { verdict: "request_changes", findings: [{ severity: "major", file: "src/export.js", line: 2, issue: "Naming", suggestion: "x" }] });
		value = report(dir, id, "incomplete");
		assert.ok(has(value, "REVIEW_CHANGES"));
		policy(dir, { blocking_severities: ["blocker", "major"] });
		value = report(dir, id, "blocked");
		assert.equal(value.review.findings[0].blocking, true, "blocking severities follow policy");
		parity(dir, id);
		ok("review blocker → blocked; request_changes → incomplete; severity policy");
	}

	// --- attestation: visible always, counts only by policy and never over a failure --------
	{
		const { dir, id } = planned({ steps: 1 });
		c(dir, ["record", "--delivery", id, "--step", "S2", "--not-run", "--reason", "needs a printer"], {}, 1);
		tick(dir, 2);
		c(dir, ["record", "--delivery", id, "--step", "S3"]);
		tick(dir, 3);
		c(dir, ["record", "--delivery", id, "--phase", "final"]);
		review(dir, id);
		c(dir, ["attest", "--delivery", id, "--criterion", "AC2", "--actor", "QA lead", "--rationale", "Printed output checked by hand", "--source", "DEMO-12 comment 3"]);
		c(dir, ["attest", "--delivery", id, "--criterion", "AC9", "--actor", "x", "--rationale", "y", "--source", "z"], {}, 2);
		let value = report(dir, id, "unverified");
		assert.ok(has(value, "ATTESTATION_IGNORED"), "an attestation is shown even when it cannot count");
		assert.equal(value.criteria.find((row) => row.id === "AC2").basis, "none");
		policy(dir, { allow_attestation: true });
		value = report(dir, id, "ready");
		const row = value.criteria.find((item) => item.id === "AC2");
		assert.deepEqual([row.result, row.basis], ["attested", "attested"]);
		assert.equal(value.attestations[0].actor, "QA lead");
		assert.ok(has(value, "ATTESTED", "S2-step.json"));
		const { md } = parity(dir, id);
		assert.match(md, /### Attestations/);
		// An attestation never converts a failed check into a pass.
		c(dir, ["record", "--delivery", id, "--step", "S2"], { CONTRACT_FIXTURE_EXIT: "1" }, 1);
		value = report(dir, id, "blocked");
		assert.equal(value.criteria.find((item) => item.id === "AC2").result, "failed");
		// Editing the spec makes the attestation stale.
		c(dir, ["record", "--delivery", id, "--step", "S2", "--not-run", "--reason", "needs a printer"], {}, 1);
		write(dir, SPEC, `${read(dir, SPEC)}\n`);
		c(dir, ["init", "spec", SPEC]);
		assert.ok(has(report(dir, id), "S_SPEC_CHANGED", "AC2-attest.json"));
		ok("attestation: ignored by default, counts by policy, never over a failure, goes stale");
	}

	// --- mapping comes from the sidecar, never from wording --------------------------------
	{
		const { dir, id } = planned({ steps: 3, final: true, reviewed: true });
		const plan = json(dir, PLAN_SIDE);
		plan.steps[0].criteria = [];
		writeJson(dir, PLAN_SIDE, plan);
		const value = report(dir, id, "unverified");
		assert.deepEqual(value.criteria.map((row) => row.id), ["AC1", "AC2", "AC3"], "every criterion appears exactly once");
		assert.equal(value.criteria[0].result, "uncovered", "the step line still says AC1, but the sidecar does not map it");
		assert.ok(has(value, "E_UNCOVERED_AC"));
		ok("no mapping by similar wording; uncovered criteria listed");
	}

	// --- quick delivery: checklist only -----------------------------------------------------
	{
		const dir = project("quick");
		c(dir, ["enable"]);
		c(dir, ["init", "quick", QUICK]);
		const id = json(dir, "ai-factory/quick/fix-date-format.contract.json").delivery_id;
		let value = report(dir, id, "incomplete");
		write(dir, QUICK, read(dir, QUICK).replace(/- \[ \]/g, "- [x]"));
		value = report(dir, id, "unverified");
		assert.ok(has(value, "E_EVIDENCE_NOT_RUN", "quick.json"));
		c(dir, ["record", "--delivery", id]);
		value = report(dir, id, "ready");
		assert.equal(value.delivery.kind, "quick");
		assert.deepEqual(value.criteria.map((row) => [row.id, row.result]), [["QC1", "passed"], ["QC2", "passed"]]);
		assert.deepEqual(value.delivery.sources.map((s) => s.kind), ["quick"], "no spec is fabricated");
		assert.ok(!fs.existsSync(path.join(dir, "ai-factory/specs")));
		assert.equal(value.review.required, false, "quick work needs no independent review by default");
		parity(dir, id);
		ok("quick delivery uses its checklist");
	}

	// --- legacy, conflicts and deleted files ------------------------------------------------
	{
		const dir = project("legacy");
		c(dir, ["migrate", "--write"]);
		const id = json(dir, "ai-factory/specs/0001-old-feature.contract.json").delivery_id;
		const value = report(dir, id, "unverified");
		assert.ok(has(value, "L_REVIEW_REQUIRED"));
		ok("legacy draft → unverified");
	}
	{
		const { dir, id } = planned({ steps: 3, final: true, reviewed: true });
		fs.mkdirSync(path.join(dir, "ai-factory/specs/old"), { recursive: true });
		fs.copyFileSync(path.join(dir, SPEC), path.join(dir, "ai-factory/specs/0002-copy.md"));
		fs.copyFileSync(path.join(dir, SPEC_SIDE), path.join(dir, "ai-factory/specs/0002-copy.contract.json"));
		assert.ok(has(report(dir, id, "unverified"), "E_DUP_ID"), "two specs claiming one delivery");
		fs.unlinkSync(path.join(dir, "ai-factory/specs/0002-copy.md"));
		fs.unlinkSync(path.join(dir, "ai-factory/specs/0002-copy.contract.json"));
		fs.unlinkSync(path.join(dir, PLAN));
		assert.ok(has(report(dir, id, "unverified"), "E_MISSING_FILE"), "a deleted plan");
		ok("conflicting IDs and deleted files → unverified");
	}

	// --- read-only, no execution, no raw output, bounded paths ------------------------------
	{
		const { dir, id } = planned({ steps: 3 });
		const plan = json(dir, PLAN_SIDE);
		plan.steps[2].verify = [{ argv: ["node", "test/noisy.js"], phase: "final" }, { argv: ["node", "test/marker.js"], phase: "final" }];
		writeJson(dir, PLAN_SIDE, plan);
		c(dir, ["record", "--delivery", id, "--phase", "final"]);
		review(dir, id);
		fs.unlinkSync(path.join(dir, "ran.marker"));
		assert.ok(read(dir, json(dir, `ai-factory/evidence/${id}/final.json`).output_ref).includes("SENTINEL-LOG-CONTENT-4242"));
		const value = report(dir, id);
		assert.ok(!fs.existsSync(path.join(dir, "ran.marker")), "the report executed no verification");
		for (const file of ["completion.json", "completion.md"])
			assert.ok(!read(dir, `ai-factory/reports/${id}/${file}`).includes("SENTINEL-LOG-CONTENT-4242"), `${file} never inlines logs`);
		assert.ok(value.verification.some((item) => item.output_ref), "logs are referenced, not included");
		ok("no execution and no raw output");
	}
	{
		const { dir, id } = planned({ steps: 3, final: true, reviewed: true });
		for (const bad of ["../../etc", "d-2026-bad", "d-20260930-ABCDEF", "", "d-20260930-000000/../x"])
			expect(node(dir, "delivery-report.js", [bad]), 2, `unsafe id ${bad}`);
		expect(node(dir, "delivery-report.js", ["d-20260930-000000"]), 2, "unknown delivery");
		expect(node(dir, "delivery-report.js", [], { DELIVERY: `$(touch pwned)` }), 2, "literal environment");
		assert.ok(!fs.existsSync(path.join(dir, "pwned")));
		// A redirected report destination is refused and nothing lands through the link.
		const sink = fs.mkdtempSync(path.join(scratch, "sink-"));
		fs.symlinkSync(sink, path.join(dir, "ai-factory/reports"));
		expect(node(dir, "delivery-report.js", [id]), 2, "symlinked reports directory");
		assert.deepEqual(fs.readdirSync(sink), []);
		fs.unlinkSync(path.join(dir, "ai-factory/reports"));
		// A symlinked evidence directory is reported, never followed.
		fs.renameSync(path.join(dir, `ai-factory/evidence/${id}`), path.join(sink, "evidence"));
		fs.symlinkSync(path.join(sink, "evidence"), path.join(dir, `ai-factory/evidence/${id}`));
		assert.ok(has(report(dir, id, "unverified"), "E_SYMLINK"));
		fs.unlinkSync(path.join(dir, `ai-factory/evidence/${id}`));
		fs.renameSync(path.join(sink, "evidence"), path.join(dir, `ai-factory/evidence/${id}`));
		// An output reference that escapes is flagged.
		const final = json(dir, `ai-factory/evidence/${id}/final.json`);
		writeJson(dir, `ai-factory/evidence/${id}/final.json`, { ...final, output_ref: "ai-factory/runs/evidence/../../../etc/passwd" });
		assert.ok(has(report(dir, id, "unverified"), "E_PATH_ESCAPE"));
		ok("unsafe IDs, symlinks and escaping references rejected");
	}
	{
		const { dir, id } = planned({ steps: 3, final: true, reviewed: true });
		report(dir, id, "ready");
		const reports = path.join(dir, `ai-factory/reports/${id}`);
		const previous = read(dir, `ai-factory/reports/${id}/completion.json`);
		fs.chmodSync(reports, 0o500);
		try {
			tick(dir, 3, " ");
			expect(node(dir, "delivery-report.js", [id]), 2, "unwritable report directory");
		} finally {
			fs.chmodSync(reports, 0o700);
		}
		assert.equal(read(dir, `ai-factory/reports/${id}/completion.json`), previous, "a failed write keeps the previous report");
		assert.deepEqual(fs.readdirSync(reports).sort(), ["completion.json", "completion.md"]);
		ok("atomic write: failure keeps the previous report");
	}
	{
		const { dir, id } = planned({ steps: 3, final: true, reviewed: true });
		const { generate } = require(path.join(dir, "ai-factory/make/delivery-report.js"));
		const mutate = () => write(dir, `ai-factory/evidence/${id}/S1-red.json`, JSON.stringify({ changed: Date.now() + Math.random() }));
		assert.throws(() => generate({ root: dir, delivery: id, onAttempt: mutate }), /changed during collection/);
		assert.ok(!fs.existsSync(path.join(dir, "ai-factory/reports")), "nothing written after an aborted collection");
		fs.unlinkSync(path.join(dir, `ai-factory/evidence/${id}/S1-red.json`));
		let calls = 0;
		const once = generate({ root: dir, delivery: id, onAttempt: () => calls++ === 0 && mutate() });
		assert.ok(once.report.snapshot.fingerprint, "a transient change is retried");
		ok("concurrent mutation aborts or retries without mixing snapshots");
	}

	// --- AC8: an adopted workspace reports through make; both hosts use one task -----------
	{
		const plugin = process.cwd();
		const claude = fs.readFileSync(path.join(plugin, "commands/report.md"), "utf8");
		const codex = fs.readFileSync(path.join(plugin, "codex-skills/t4-report/SKILL.md"), "utf8");
		for (const wrapper of [claude, codex]) assert.match(wrapper, /ai-factory\/tasks\/report\.md/, "wrapper reads the shared task");
		const task = fs.readFileSync(path.join(plugin, "skills/ai-layout/templates/ai-factory/tasks/report.md"), "utf8");
		assert.match(task, /make -f ai-factory\/make\/ai\.mk delivery-report DELIVERY=<id>/);
		assert.match(task, /publish nothing/);
		const { adopt } = require(path.resolve("skills/ai-layout/scripts/adopt.js"));
		const dir = fs.mkdtempSync(path.join(scratch, "adopted-"));
		git(dir, "init", "-q", "-b", "main");
		adopt(dir, plugin, "Fixture Owner");
		for (const name of ["planned", "quick"]) fs.cpSync(path.join(FIXTURES, name), dir, { recursive: true });
		git(dir, "add", "-A");
		git(dir, "commit", "-q", "-m", "adopted");
		const make = (...args) => spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", ...args], { cwd: dir, env: { ...clean, MAKEFLAGS: "", MAKEOVERRIDES: "" }, encoding: "utf8" });
		c(dir, ["enable"]);
		c(dir, ["init", "spec", SPEC]);
		c(dir, ["init", "plan", PLAN, "--spec", SPEC]);
		const id = json(dir, SPEC_SIDE).delivery_id;
		for (const step of [1, 2, 3]) {
			expect(make("verify", `DELIVERY=${id}`, `STEP=S${step}`), 0, `verify S${step}`);
			tick(dir, step);
		}
		expect(make("verify", `DELIVERY=${id}`, "PHASE=final"), 0, "final");
		policy(dir, { require_review: false });
		const planned = expect(make("delivery-report", `DELIVERY=${id}`, "JSON=1"), 0, "make delivery-report");
		assert.equal(JSON.parse(planned.stdout).status, "ready", "JSON=1 prints one document");
		assert.ok(fs.existsSync(path.join(dir, `ai-factory/reports/${id}/completion.md`)));
		c(dir, ["init", "quick", QUICK]);
		const quick = json(dir, "ai-factory/quick/fix-date-format.contract.json").delivery_id;
		write(dir, QUICK, read(dir, QUICK).replace(/- \[ \]/g, "- [x]"));
		expect(make("verify", `DELIVERY=${quick}`), 0, "quick verify");
		assert.match(expect(make("delivery-report", `DELIVERY=${quick}`), 0, "quick report").stdout, /^delivery-report: ready — .*\(quick\)/);
		expect(make("delivery-report"), 2, "no delivery named");
		ok("adopted workspace: make delivery-report for planned and quick; one task behind both hosts");
	}

	// --- telemetry: optional, never zero, never affects status -----------------------------
	{
		const { dir, id } = planned({ steps: 3, final: true, reviewed: true });
		let value = report(dir, id, "ready");
		assert.equal(value.telemetry.status, "unavailable");
		assert.equal(value.telemetry.metrics, null);
		const md = () => read(dir, `ai-factory/reports/${id}/completion.md`);
		assert.match(md(), /Status: \*\*unavailable\*\*/);
		fs.mkdirSync(path.join(dir, "ai-factory/runs/telemetry"), { recursive: true });
		const file = `ai-factory/runs/telemetry/${id}.json`;
		const base = { schema: "t4-delivery-telemetry", version: 1, delivery_id: id, coverage: { measured: 1, total: 3 }, metrics: { cost_usd: null, duration_s: 42.5 }, pricing: { source: "models.yaml" } };
		writeJson(dir, file, base);
		value = report(dir, id, "ready");
		assert.equal(value.telemetry.status, "partial");
		assert.equal(value.telemetry.metrics.cost_usd, null);
		assert.match(md(), /- cost_usd: unknown/);
		assert.ok(!/cost_usd: 0\b/.test(md()), "unknown is never rendered as zero");
		assert.match(md(), /1 of 3 runs measured/);
		writeJson(dir, file, { ...base, coverage: { measured: 3, total: 3 }, metrics: { cost_usd: 0.12 } });
		assert.equal(report(dir, id, "ready").telemetry.status, "available");
		for (const [label, text] of [
			["malformed", "{"],
			["version 2", JSON.stringify({ ...base, version: 2 })],
			["other schema", JSON.stringify({ ...base, schema: "ai-sdlc-cost" })],
			["other delivery", JSON.stringify({ ...base, delivery_id: "d-20260101-000000" })],
			["string metric", JSON.stringify({ ...base, metrics: { cost_usd: "0" } })],
			["bad coverage", JSON.stringify({ ...base, coverage: { measured: 4, total: 3 } })],
		]) {
			write(dir, file, text);
			value = report(dir, id, "ready");
			assert.equal(value.telemetry.status, "incompatible", label);
			assert.equal(value.telemetry.metrics, null, label);
		}
		ok("telemetry missing, partial, available and incompatible; status unchanged");
	}
}
main()
	.then(() => console.log(`delivery report ok — ${cases} cases: ready, incomplete, blocked, unverified, attestation policy, quick, legacy, parity, read-only collection, path safety, atomic writes, concurrency and telemetry`))
	.catch((error) => {
		console.error(`FAIL: ${error.message}`);
		process.exitCode = 1;
	})
	.finally(() => fs.rmSync(scratch, { recursive: true, force: true }));
NODE
