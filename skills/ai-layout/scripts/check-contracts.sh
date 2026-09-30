#!/usr/bin/env bash
# Artifact contracts (spec 0013): every case runs contracts.js in a disposable Git repository
# under ai-factory/runs/tmp/, built from skills/ai-layout/fixtures/contracts/.
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
const SCHEMA = path.resolve("skills/ai-layout/templates/ai-factory/contracts/schema");
const CONTRACTS = path.join(MAKE, "contracts.js");
assert.ok(fs.existsSync(CONTRACTS), "FAIL: make/contracts.js is not implemented yet");
const safe = boundary(path.resolve("ai-factory"));
const scratch = safe.scratch(path.resolve("ai-factory/runs/tmp"));
let cases = 0;
const ok = (label) => {
	cases++;
	if (process.env.VERBOSE) console.log(`ok: ${label}`);
};
const git = (dir, ...args) =>
	execFileSync("git", ["-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", ...args], { cwd: dir, stdio: "pipe" });
function project(name) {
	const dir = fs.mkdtempSync(path.join(scratch, `${name}-`));
	fs.cpSync(path.join(FIXTURES, name), dir, { recursive: true });
	fs.mkdirSync(path.join(dir, "ai-factory/make"), { recursive: true });
	for (const file of ["contracts.js", "gate.js", "safe-files.js"])
		fs.copyFileSync(path.join(MAKE, file), path.join(dir, "ai-factory/make", file));
	git(dir, "init", "-q");
	git(dir, "add", "-A");
	git(dir, "commit", "-q", "-m", "fixture");
	return dir;
}
const clean = { ...process.env };
for (const key of ["JSON", "DELIVERY", "STEP", "PHASE", "REQUIRE", "CONTRACT_FIXTURE_EXIT", "CONTRACT_FIXTURE_RED_EXIT"]) delete clean[key];
const run = (dir, args, env = {}) =>
	spawnSync(process.execPath, [path.join(dir, "ai-factory/make/contracts.js"), ...args], { cwd: dir, env: { ...clean, ...env }, encoding: "utf8" });
function expect(result, status, label) {
	assert.equal(result.status, status, `${label}\nstdout:${result.stdout}\nstderr:${result.stderr}`);
	return result;
}
function doc(dir, args = ["--all"], status) {
	const result = run(dir, ["validate", ...args, "--json"]);
	// JSON mode: stdout is exactly one document.
	const value = JSON.parse(result.stdout);
	assert.equal(value.schema, "t4-contract-diagnostics");
	assert.match(value.note, /Structural validation only/);
	if (status !== undefined) assert.equal(result.status, status, `${args.join(" ")}\n${result.stdout}`);
	return value;
}
const codes = (value) => value.artifacts.flatMap((item) => item.diagnostics.map((d) => d.code));
const has = (value, code, pathPart) =>
	value.artifacts.some((item) => item.diagnostics.some((d) => d.code === code && (!pathPart || d.path.includes(pathPart))));
const read = (dir, file) => fs.readFileSync(path.join(dir, file), "utf8");
const write = (dir, file, text) => fs.writeFileSync(path.join(dir, file), text);
const json = (dir, file) => JSON.parse(read(dir, file));
const writeJson = (dir, file, value) => write(dir, file, `${JSON.stringify(value, null, 2)}\n`);
const SPEC = "ai-factory/specs/0001-csv-export.md";
const PLAN = "ai-factory/plans/0001-csv-export.md";
const SPEC_SIDE = "ai-factory/specs/0001-csv-export.contract.json";
const PLAN_SIDE = "ai-factory/plans/0001-csv-export.contract.json";
const tick = (dir, step, mark = "x") => write(dir, PLAN, read(dir, PLAN).replace(new RegExp(`^- \\[.\\] \\*\\*Step ${step} `, "m"), `- [${mark}] **Step ${step} `));
function planned({ enable = true } = {}) {
	const dir = project("planned");
	if (enable) expect(run(dir, ["enable"]), 0, "enable");
	expect(run(dir, ["init", "spec", SPEC]), 0, "init spec");
	expect(run(dir, ["init", "plan", PLAN, "--spec", SPEC]), 0, "init plan");
	return { dir, id: json(dir, SPEC_SIDE).delivery_id };
}
function tree(dir) {
	const out = [];
	const walk = (at) => {
		for (const entry of fs.readdirSync(at, { withFileTypes: true })) {
			if (entry.name === ".git") continue;
			const file = path.join(at, entry.name);
			const stat = fs.lstatSync(file);
			out.push(`${path.relative(dir, file)} ${stat.mtimeMs} ${stat.size}`);
			if (entry.isDirectory()) walk(file);
		}
	};
	walk(dir);
	return out.sort().join("\n");
}

async function main() {
	// --- schema documents and the validator agree on required fields ----------------------
	const { REQUIRED, SCHEMAS, parsePlanSteps } = require(CONTRACTS);
	for (const kind of ["config", "spec", "plan", "quick", "evidence", "attestation"]) {
		const schema = JSON.parse(fs.readFileSync(path.join(SCHEMA, `${kind}.v1.json`), "utf8"));
		assert.deepEqual(schema.required, REQUIRED[kind], `${kind} schema required list drifted`);
		assert.equal(schema.properties.schema.const, SCHEMAS[kind]);
	}
	ok("schema documents match validator");

	// --- AC1: a valid planned chain, readable and JSON -------------------------------------
	{
		const { dir, id } = planned();
		const spec = json(dir, SPEC_SIDE);
		assert.deepEqual(spec.criteria, ["AC1", "AC2", "AC3"], "fenced AC9 is not a declaration");
		assert.equal(spec.tracker_key, "DEMO-12");
		const plan = json(dir, PLAN_SIDE);
		assert.deepEqual(plan.steps.map((s) => [s.id, s.criteria, s.verify.map((v) => `${v.phase}:${v.argv.join(" ")}`)]), [
			["S1", ["AC1"], ["red:node test/red.js", "step:node test/pass.js rows"]],
			["S2", ["AC2"], ["step:node test/pass.js quote"]],
			["S3", ["AC3"], ["step:node test/pass.js empty", "final:node test/pass.js all"]],
		]);
		expect(run(dir, ["record", "--delivery", id, "--step", "S1", "--phase", "red"]), 0, "red run fails as expected");
		for (const step of [1, 2, 3]) {
			expect(run(dir, ["record", "--delivery", id, "--step", `S${step}`]), 0, `step ${step}`);
			tick(dir, step);
		}
		expect(run(dir, ["record", "--delivery", id, "--phase", "final"]), 0, "final");
		const value = doc(dir, [id], 0);
		assert.equal(value.status, "valid");
		assert.deepEqual(codes(value).filter((c) => !c.startsWith("I_")), []);
		// Stable: identical input gives identical output.
		assert.equal(run(dir, ["validate", id, "--json"]).stdout, run(dir, ["validate", id, "--json"]).stdout);
		const human = expect(run(dir, ["validate", id]), 0, "summary");
		assert.match(human.stdout, /^contracts: valid/);
		assert.match(human.stdout, /note: Structural validation only/);
		// JSON=1 from make is the same switch as --json.
		assert.equal(JSON.parse(run(dir, ["validate", id], { JSON: "1" }).stdout).status, "valid");
		// Validation by artifact path resolves to the same delivery, including after a rename.
		assert.equal(doc(dir, [SPEC], 0).delivery_id, id);
		fs.mkdirSync(path.join(dir, "ai-factory/plans/done"));
		for (const ext of [".md", ".contract.json"])
			fs.renameSync(path.join(dir, `ai-factory/plans/0001-csv-export${ext}`), path.join(dir, `ai-factory/plans/done/0001-renamed${ext}`));
		for (const ext of [".md", ".contract.json"])
			fs.renameSync(path.join(dir, `ai-factory/specs/0001-csv-export${ext}`), path.join(dir, `ai-factory/specs/0001-renamed${ext}`));
		assert.equal(doc(dir, [id], 0).status, "valid", "delivery_id survives renames and plans/done/");
		ok("valid chain, summary, JSON, rename");
		// Parser parity with /t4:state's step grammar.
		write(dir, "ai-factory/plans/done/0001-renamed.md", read(dir, "ai-factory/plans/done/0001-renamed.md").replace("- [x] **Step 2", "- [~] **Step 2").replace("- [x] **Step 3", "- [ ] **Step 3") + "\n**Result — Step 3 withdrawn; superseded.**\n- [label](https://example.invalid)\n");
		const listed = execFileSync("bash", [path.resolve("skills/ai-layout/scripts/state.sh"), dir], { encoding: "utf8" })
			.split("\n").filter((line) => line.startsWith("plan\t")).map((line) => line.split("\t")[4]);
		const parsed = parsePlanSteps(read(dir, "ai-factory/plans/done/0001-renamed.md")).filter((s) => !s.done && !s.withdrawn).map((s) => `Step ${s.number}`);
		assert.deepEqual(parsed, listed);
		ok("step grammar matches state.sh");
	}

	// --- AC2: invalid handoffs name the path and the reason ---------------------------------
	{
		const variants = [
			["duplicate AC", (dir) => write(dir, SPEC, read(dir, SPEC).replace("| AC3 |", "| AC2 |")), "E_DUP_ID", SPEC],
			["sidecar lists an undeclared AC", (dir) => { const v = json(dir, SPEC_SIDE); v.criteria.push("AC7"); writeJson(dir, SPEC_SIDE, v); }, "E_MISSING_ID", SPEC_SIDE],
			["sidecar misses a declared AC", (dir) => { const v = json(dir, SPEC_SIDE); v.criteria.pop(); writeJson(dir, SPEC_SIDE, v); }, "E_MISSING_ID", SPEC_SIDE],
			["unknown AC reference", (dir) => { const v = json(dir, PLAN_SIDE); v.steps[0].criteria.push("AC9"); writeJson(dir, PLAN_SIDE, v); }, "E_UNKNOWN_REF", PLAN_SIDE],
			["unknown step", (dir) => { const v = json(dir, PLAN_SIDE); v.steps.push({ ...v.steps[0], id: "S9" }); writeJson(dir, PLAN_SIDE, v); }, "E_UNKNOWN_REF", PLAN_SIDE],
			["uncovered AC", (dir) => { const v = json(dir, PLAN_SIDE); v.steps[2].criteria = []; writeJson(dir, PLAN_SIDE, v); }, "E_UNCOVERED_AC", PLAN_SIDE],
			["missing verification command", (dir) => { const v = json(dir, PLAN_SIDE); v.steps[1].verify = []; writeJson(dir, PLAN_SIDE, v); }, "E_NO_VERIFY", PLAN_SIDE],
			["no final verification", (dir) => { const v = json(dir, PLAN_SIDE); v.steps[2].verify = v.steps[2].verify.filter((e) => e.phase !== "final"); writeJson(dir, PLAN_SIDE, v); }, "E_NO_VERIFY", PLAN_SIDE],
			["malformed JSON", (dir) => write(dir, PLAN_SIDE, "{"), "E_MALFORMED", PLAN_SIDE],
			["wrong schema", (dir) => { const v = json(dir, SPEC_SIDE); v.schema = "t4-contract/plan"; writeJson(dir, SPEC_SIDE, v); }, "E_MALFORMED", SPEC_SIDE],
			["missing field", (dir) => { const v = json(dir, SPEC_SIDE); delete v.sha256; writeJson(dir, SPEC_SIDE, v); }, "E_MALFORMED", SPEC_SIDE],
			["unsupported version", (dir) => { const v = json(dir, SPEC_SIDE); v.version = 99; writeJson(dir, SPEC_SIDE, v); }, "E_SCHEMA_VERSION", SPEC_SIDE],
			["version zero", (dir) => { const v = json(dir, PLAN_SIDE); v.version = 0; writeJson(dir, PLAN_SIDE, v); }, "E_SCHEMA_VERSION", PLAN_SIDE],
			["argv is a shell string", (dir) => { const v = json(dir, PLAN_SIDE); v.steps[0].verify[0].argv = "node test/red.js"; writeJson(dir, PLAN_SIDE, v); }, "E_MALFORMED", PLAN_SIDE],
			["unknown phase", (dir) => { const v = json(dir, PLAN_SIDE); v.steps[0].verify[0].phase = "later"; writeJson(dir, PLAN_SIDE, v); }, "E_MALFORMED", PLAN_SIDE],
			["plan without spec", (dir) => fs.unlinkSync(path.join(dir, SPEC_SIDE)), "E_UNKNOWN_REF", PLAN_SIDE],
			["sidecar without Markdown", (dir) => fs.unlinkSync(path.join(dir, PLAN)), "E_MISSING_FILE", PLAN],
			["two plans for one delivery", (dir) => { fs.mkdirSync(path.join(dir, "ai-factory/plans/done")); fs.copyFileSync(path.join(dir, PLAN), path.join(dir, "ai-factory/plans/done/0001-copy.md")); fs.copyFileSync(path.join(dir, PLAN_SIDE), path.join(dir, "ai-factory/plans/done/0001-copy.contract.json")); }, "E_DUP_ID", "ai-factory/plans/"],
		];
		for (const [label, mutate, code, where] of variants) {
			const { dir } = planned();
			mutate(dir);
			const value = doc(dir, ["--all"], 1);
			assert.ok(has(value, code, where), `${label}: expected ${code} at ${where}\n${JSON.stringify(value, null, 1)}`);
			const item = value.artifacts.find((a) => a.diagnostics.some((d) => d.code === code));
			assert.equal(item.state, "invalid", label);
			assert.ok(item.diagnostics.find((d) => d.code === code).message.length > 5, `${label}: actionable message`);
			const human = run(dir, ["validate", "--all"]);
			assert.equal(human.status, 1);
			assert.match(human.stderr, new RegExp(code));
			ok(`invalid: ${label}`);
		}
		const { dir } = planned();
		write(dir, SPEC, read(dir, SPEC).replace("| AC3 |", "| AC1 |"));
		const refused = expect(run(dir, ["init", "spec", SPEC]), 1, "init reports duplicate IDs");
		assert.match(refused.stderr, /E_DUP_ID/);
		for (const args of [["validate", "a", "b"], ["validate", "--require", "everything"], ["frobnicate"], ["init", "spec"], ["init", "plan", SPEC], ["record", "--delivery", "nope"], ["validate", "--bogus"]])
			expect(run(dir, args), 2, `invocation error: ${args.join(" ")}`);
		write(dir, "ai-factory/contracts/config.json", "{");
		expect(run(dir, ["validate", "--all"]), 2, "malformed config is an invocation error");
		ok("invocation errors exit 2");
	}

	// --- AC3: freshness is content, never time ----------------------------------------------
	{
		const setup = () => {
			const { dir, id } = planned();
			expect(run(dir, ["record", "--delivery", id, "--step", "S1"]), 0, "S1");
			tick(dir, 1);
			expect(run(dir, ["record", "--delivery", id, "--phase", "final"]), 0, "final");
			writeJson(dir, "ai-factory/contracts/config.json", { ...json(dir, "ai-factory/contracts/config.json"), code_scope: { include: ["src/**", "test/**", "lib/**"], exclude: ["src/generated/**"] } });
			expect(run(dir, ["record", "--delivery", id, "--phase", "final"]), 0, "final with scope");
			assert.equal(doc(dir, [id], 0).status, "valid");
			return { dir, id };
		};
		{
			const { dir, id } = setup();
			write(dir, SPEC, read(dir, SPEC).replace("one line per row", "one line per row, in order"));
			const value = doc(dir, [id], 1);
			assert.equal(value.status, "stale");
			assert.ok(has(value, "S_ARTIFACT_CHANGED", "ai-factory/specs/"));
			assert.ok(has(value, "S_SPEC_CHANGED", PLAN_SIDE), "plan stale after spec edit");
			assert.ok(has(value, "S_SPEC_CHANGED", "S1-step.json"), "step evidence stale after spec edit");
			assert.ok(has(value, "S_SPEC_CHANGED", "final.json"), "final evidence stale after spec edit");
			// Refreshing the spec sidecar leaves the plan and evidence stale until re-derived.
			expect(run(dir, ["init", "spec", SPEC]), 0, "refresh spec");
			assert.ok(has(doc(dir, [id], 1), "S_SPEC_CHANGED", PLAN_SIDE));
			ok("spec edit propagates to plan and evidence");
		}
		{
			const { dir, id } = setup();
			write(dir, PLAN, read(dir, PLAN).replace("Rows to lines.", "Rows to lines, in order."));
			const value = doc(dir, [id], 1);
			assert.ok(has(value, "S_ARTIFACT_CHANGED", "ai-factory/plans/"));
			assert.ok(has(value, "S_PLAN_CHANGED", "S1-step.json"));
			assert.ok(has(value, "S_PLAN_CHANGED", "final.json"));
			ok("plan edit makes evidence stale");
		}
		{
			const { dir, id } = setup();
			tick(dir, 2, "~");
			assert.equal(doc(dir, [id], 0).status, "valid", "ticking progress is not a content change");
			const now = new Date(Date.now() + 60000);
			fs.utimesSync(path.join(dir, "src/export.js"), now, now);
			fs.utimesSync(path.join(dir, SPEC), now, now);
			assert.equal(doc(dir, [id], 0).status, "valid", "an mtime alone never changes freshness");
			for (const [file, text] of [
				["ai-factory/runs/report.html", "<p>report</p>"],
				["ai-factory/runs/log.csv", "ts\n"],
				["ai-factory/explorations/x.md", "notes"],
				["dist/bundle.js", "ignored by .gitignore"],
				["src/generated/out.js", "excluded by code_scope"],
				["docs/readme.md", "outside include"],
			]) {
				fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
				write(dir, file, text);
				assert.equal(doc(dir, [id], 0).status, "valid", `${file} must not invalidate evidence`);
			}
			ok("excluded, ignored, generated and mtime-only changes do not invalidate");
			write(dir, "src/export.js", `${read(dir, "src/export.js")}// edited\n`);
			let value = doc(dir, [id], 1);
			assert.ok(has(value, "S_CODE_CHANGED", "final.json"), "tracked code edit");
			assert.ok(has(value, "I_CODE_ADVANCED", "S1-step.json"), "step evidence notes the advance only");
			git(dir, "checkout", "--", "src/export.js");
			assert.equal(doc(dir, [id], 0).status, "valid", "restoring content restores freshness");
			fs.mkdirSync(path.join(dir, "lib"));
			write(dir, "lib/new.js", "module.exports = 1;\n");
			assert.ok(has(doc(dir, [id], 1), "S_CODE_CHANGED"), "untracked in-scope file");
			fs.unlinkSync(path.join(dir, "lib/new.js"));
			fs.unlinkSync(path.join(dir, "test/red.js"));
			assert.ok(has(doc(dir, [id], 1), "S_CODE_CHANGED"), "deleted tracked file");
			ok("in-scope code, untracked and deleted files make final evidence stale");
		}
	}

	// --- AC4: outcomes are distinguished; boxes are not proof -------------------------------
	{
		{
			const { dir, id } = planned();
			tick(dir, 1);
			let value = doc(dir, [id], 1);
			assert.ok(has(value, "E_EVIDENCE_NOT_RUN", "S1-step.json"), "a ticked box without evidence");
			expect(run(dir, ["record", "--delivery", id, "--step", "S1"], { CONTRACT_FIXTURE_EXIT: "3" }), 1, "nonzero exit");
			let evidence = json(dir, `ai-factory/evidence/${id}/S1-step.json`);
			assert.equal(evidence.status, "failed");
			assert.equal(evidence.commands[0].exit_code, 3);
			assert.match(evidence.output_ref, /^ai-factory\/runs\/evidence\//);
			assert.ok(has(doc(dir, [id], 1), "E_EVIDENCE_FAILED", "S1-step.json"));
			tick(dir, 1, " ");
			assert.ok(!doc(dir, [id]).artifacts.some((a) => a.state === "invalid"), "an unticked step's failed attempt is progress, not breakage");
			tick(dir, 1);
			expect(run(dir, ["record", "--delivery", id, "--step", "S1", "--not-run", "--reason", "CI runner offline"]), 1, "not_run");
			evidence = json(dir, `ai-factory/evidence/${id}/S1-step.json`);
			assert.equal(evidence.status, "not_run");
			value = doc(dir, [id], 1);
			assert.ok(value.artifacts.some((a) => a.diagnostics.some((d) => d.code === "E_EVIDENCE_NOT_RUN" && /CI runner offline/.test(d.message))));
			const plan = json(dir, PLAN_SIDE);
			plan.steps[0].verify = [{ argv: ["t4-contract-fixture-no-such-command"], phase: "step" }];
			writeJson(dir, PLAN_SIDE, plan);
			expect(run(dir, ["record", "--delivery", id, "--step", "S1"]), 1, "unavailable");
			evidence = json(dir, `ai-factory/evidence/${id}/S1-step.json`);
			assert.equal(evidence.status, "unavailable");
			assert.equal(evidence.commands[0].error, "ENOENT");
			assert.ok(has(doc(dir, [id], 1), "E_EVIDENCE_UNAVAILABLE"));
			ok("failed, not_run and unavailable are distinct and never valid");
		}
		{
			const { dir, id } = planned();
			expect(run(dir, ["record", "--delivery", id, "--step", "S1", "--phase", "red"]), 0, "expected red failure");
			const red = json(dir, `ai-factory/evidence/${id}/S1-red.json`);
			assert.equal(red.status, "failed");
			assert.equal(red.expected, "fail");
			for (const step of [1, 2, 3]) tick(dir, step);
			fs.copyFileSync(path.join(dir, `ai-factory/evidence/${id}/S1-red.json`), path.join(dir, `ai-factory/evidence/${id}/S1-step.json`));
			let value = doc(dir, [id], 1);
			assert.ok(has(value, "E_MALFORMED", "S1-step.json"), "red evidence cannot stand as step evidence");
			assert.ok(has(value, "E_EVIDENCE_NOT_RUN", "final.json"), "all ticked requires final");
			fs.copyFileSync(path.join(dir, `ai-factory/evidence/${id}/S1-red.json`), path.join(dir, `ai-factory/evidence/${id}/final.json`));
			assert.ok(has(doc(dir, [id], 1), "E_RED_NOT_FINAL", "final.json"), "red evidence never counts as final");
			expect(run(dir, ["record", "--delivery", id, "--step", "S1", "--phase", "red"], { CONTRACT_FIXTURE_RED_EXIT: "0" }), 1, "a red run that passes");
			assert.ok(has(doc(dir, [id], 1), "E_RED_PASSED", "S1-red.json"));
			expect(run(dir, ["record", "--delivery", id, "--step", "S1", "--phase", "final"]), 2, "final is not a step phase");
			ok("red expectations never become final passes");
		}
		{
			const { dir, id } = planned();
			const plan = json(dir, PLAN_SIDE);
			plan.steps[2].verify = [{ argv: ["node", "test/slow.js"], phase: "final" }];
			writeJson(dir, PLAN_SIDE, plan);
			const child = spawn(process.execPath, [path.join(dir, "ai-factory/make/contracts.js"), "record", "--delivery", id, "--phase", "final"], { cwd: dir, env: clean, stdio: "ignore" });
			await new Promise((resolve) => setTimeout(resolve, 700));
			child.kill("SIGINT");
			const code = await new Promise((resolve) => child.once("close", resolve));
			assert.equal(code, 130, "interrupted recording exits 130");
			const evidence = json(dir, `ai-factory/evidence/${id}/final.json`);
			assert.equal(evidence.status, "failed");
			assert.equal(evidence.commands[0].signal, "SIGINT");
			assert.ok(has(doc(dir, [id, "--require", "final"], 1), "E_EVIDENCE_FAILED", "final.json"));
			ok("interruption is recorded as failed, never passed");
		}
		{
			const { dir, id } = planned();
			const plan = json(dir, PLAN_SIDE);
			write(dir, "test/writes.js", "require('fs').writeFileSync('src/coverage.js', String(Date.now()));\n");
			git(dir, "add", "test/writes.js");
			plan.steps[2].verify.push({ argv: ["node", "test/writes.js"], phase: "final" });
			writeJson(dir, PLAN_SIDE, plan);
			expect(run(dir, ["record", "--delivery", id, "--phase", "final"]), 0, "final with in-scope output");
			assert.ok(has(doc(dir, [id], 1), "E_EVIDENCE_UNSTABLE", "final.json"), "verification that edits scoped code proves nothing");
			ok("unstable in-scope output is reported");
		}
		{
			const { dir, id } = planned();
			const record = (name, value) => { fs.mkdirSync(path.join(dir, `ai-factory/evidence/${id}`), { recursive: true }); writeJson(dir, `ai-factory/evidence/${id}/${name}`, value); };
			expect(run(dir, ["record", "--delivery", id, "--phase", "final"]), 0, "final");
			const final = json(dir, `ai-factory/evidence/${id}/final.json`);
			record("S7-step.json", { ...final, scope: { kind: "step", step: "S7" }, phase: "step" });
			assert.ok(has(doc(dir, [id], 1), "E_UNKNOWN_REF", "S7-step.json"), "evidence for an unknown step");
			fs.unlinkSync(path.join(dir, `ai-factory/evidence/${id}/S7-step.json`));
			record("final.json", { ...final, status: "maybe" });
			assert.ok(has(doc(dir, [id], 1), "E_MALFORMED", "final.json"));
			record("final.json", { ...final, version: 2 });
			assert.ok(has(doc(dir, [id], 1), "E_SCHEMA_VERSION", "final.json"));
			record("notes.json", final);
			assert.ok(has(doc(dir, [id], 1), "E_MALFORMED", "notes.json"));
			ok("hand-made evidence is checked like any other");
		}
	}

	// --- AC5: read-only, bounded, prose paths never read -----------------------------------
	{
		const { dir, id } = planned();
		expect(run(dir, ["record", "--delivery", id, "--phase", "final"]), 0, "final");
		const before = tree(dir);
		for (const args of [["validate", "--all"], ["validate", id, "--json"], ["validate", SPEC], ["snapshot", "--json"], ["migrate"]]) run(dir, args);
		assert.equal(tree(dir), before, "validate, snapshot and dry-run migrate write nothing");
		const outside = path.join(scratch, "outside.md");
		write(scratch, "outside.md", "| AC1 | outside |\n");
		for (const target of ["../outside.md", outside, "ai-factory/../../outside.md"]) {
			const value = doc(dir, [target], 1);
			assert.ok(has(value, "E_PATH_ESCAPE"), `escape: ${target}`);
		}
		// A final evidence output_ref that escapes is rejected, and never opened.
		const final = json(dir, `ai-factory/evidence/${id}/final.json`);
		writeJson(dir, `ai-factory/evidence/${id}/final.json`, { ...final, output_ref: "ai-factory/runs/evidence/../../../outside.md" });
		assert.ok(has(doc(dir, [id], 1), "E_PATH_ESCAPE", "final.json"));
		writeJson(dir, `ai-factory/evidence/${id}/final.json`, final);
		fs.renameSync(path.join(dir, SPEC), path.join(dir, "ai-factory/real-spec.md"));
		fs.symlinkSync("../real-spec.md", path.join(dir, SPEC));
		assert.ok(has(doc(dir, [id], 1), "E_SYMLINK", SPEC), "symlinked spec Markdown");
		fs.unlinkSync(path.join(dir, SPEC));
		fs.renameSync(path.join(dir, "ai-factory/real-spec.md"), path.join(dir, SPEC));
		fs.symlinkSync(outside, path.join(dir, "ai-factory/specs/0002-linked.md"));
		assert.ok(has(doc(dir, ["--all"], 1), "E_SYMLINK", "0002-linked.md"), "symlinked artifact entry");
		fs.unlinkSync(path.join(dir, "ai-factory/specs/0002-linked.md"));
		fs.renameSync(path.join(dir, "ai-factory/plans"), path.join(scratch, `plans-${id}`));
		fs.symlinkSync(path.join(scratch, `plans-${id}`), path.join(dir, "ai-factory/plans"));
		assert.ok(has(doc(dir, ["--all"], 1), "E_SYMLINK", "ai-factory/plans"), "symlinked plans directory");
		fs.unlinkSync(path.join(dir, "ai-factory/plans"));
		fs.renameSync(path.join(scratch, `plans-${id}`), path.join(dir, "ai-factory/plans"));
		fs.renameSync(path.join(dir, `ai-factory/evidence/${id}`), path.join(scratch, `evidence-${id}`));
		fs.symlinkSync(path.join(scratch, `evidence-${id}`), path.join(dir, `ai-factory/evidence/${id}`));
		assert.ok(has(doc(dir, [id], 1), "E_SYMLINK", "evidence"), "symlinked evidence directory");
		fs.unlinkSync(path.join(dir, `ai-factory/evidence/${id}`));
		fs.renameSync(path.join(scratch, `evidence-${id}`), path.join(dir, `ai-factory/evidence/${id}`));
		// A symlink inside the code scope is hashed by its target text and never followed.
		fs.symlinkSync(outside, path.join(dir, "src/link.js"));
		const first = JSON.parse(run(dir, ["snapshot", "--json"]).stdout).snapshot_sha256;
		write(scratch, "outside.md", "changed outside the project\n");
		assert.equal(JSON.parse(run(dir, ["snapshot", "--json"]).stdout).snapshot_sha256, first, "link target content is never read");
		// Recording refuses a redirected evidence destination.
		fs.unlinkSync(path.join(dir, "src/link.js"));
		fs.rmSync(path.join(dir, "ai-factory/evidence"), { recursive: true });
		fs.mkdirSync(path.join(scratch, `sink-${id}`));
		fs.symlinkSync(path.join(scratch, `sink-${id}`), path.join(dir, "ai-factory/evidence"));
		expect(run(dir, ["record", "--delivery", id, "--phase", "final"]), 2, "symlinked evidence destination");
		assert.deepEqual(fs.readdirSync(path.join(scratch, `sink-${id}`)), [], "nothing written through the link");
		ok("read-only validation, traversal and symlink rejection");
	}

	// --- AC6: quick work without a spec or plan --------------------------------------------
	{
		const dir = project("quick");
		expect(run(dir, ["enable"]), 0, "enable");
		const QUICK = "ai-factory/quick/fix-date-format.md";
		expect(run(dir, ["init", "quick", QUICK]), 0, "init quick");
		const side = json(dir, "ai-factory/quick/fix-date-format.contract.json");
		assert.deepEqual(side.checks, ["QC1", "QC2"]);
		assert.deepEqual(side.verify, [{ argv: ["node", "test/pass.js", "footer"], phase: "final" }]);
		const id = side.delivery_id;
		assert.equal(doc(dir, [id], 0).status, "valid", "a fresh checklist validates alone");
		write(dir, QUICK, read(dir, QUICK).replace(/- \[ \]/g, "- [x]"));
		assert.ok(has(doc(dir, [id], 1), "E_EVIDENCE_NOT_RUN", "quick.json"), "ticked checklist needs evidence");
		expect(run(dir, ["record", "--delivery", id, "--step", "S1"]), 2, "quick has no steps");
		expect(run(dir, ["record", "--delivery", id]), 0, "quick verification");
		assert.equal(doc(dir, [id], 0).status, "valid");
		write(dir, "src/footer.js", `${read(dir, "src/footer.js")}// edit\n`);
		assert.ok(has(doc(dir, [id], 1), "S_CODE_CHANGED", "quick.json"));
		write(dir, QUICK, read(dir, QUICK).replace("- [x] QC2", "- [x] QC1"));
		assert.ok(has(doc(dir, [id], 1), "E_DUP_ID"));
		ok("quick checklist and focused evidence");
	}

	// --- AC7: explicit, idempotent migration that preserves prose -------------------------
	{
		const dir = project("legacy");
		const original = {};
		for (const file of ["ai-factory/specs/0001-old-feature.md", "ai-factory/plans/done/0001-old-feature.md", "ai-factory/specs/0002-no-ids.md"])
			original[file] = fs.readFileSync(path.join(dir, file));
		let value = doc(dir, ["--all"], 1);
		assert.equal(value.adopted, false);
		assert.equal(value.status, "legacy_unverified", "unadopted projects report legacy artifacts, never valid");
		assert.ok(has(value, "L_NO_SIDECAR", "0001-old-feature.md"));
		const dry = JSON.parse(expect(run(dir, ["migrate", "--json"]), 0, "dry run").stdout);
		assert.equal(dry.write, false);
		assert.ok(dry.actions.some((a) => a.action === "skipped" && a.path.endsWith("0002-no-ids.md")), "no IDs are invented");
		assert.ok(!fs.existsSync(path.join(dir, "ai-factory/specs/0001-old-feature.contract.json")));
		const human = expect(run(dir, ["migrate", "--write"]), 0, "migrate");
		assert.match(human.stdout, /extracted criteria: AC1, AC2/);
		assert.match(human.stdout, /extracted steps: S1\[AC1,AC2\]/);
		const after = tree(dir);
		const again = expect(run(dir, ["migrate", "--write"]), 0, "second migrate");
		assert.equal(tree(dir), after, "migration twice is idempotent");
		assert.match(again.stdout, /skipped: ai-factory\/specs\/0002-no-ids.md/);
		for (const [file, bytes] of Object.entries(original)) assert.deepEqual(fs.readFileSync(path.join(dir, file)), bytes, `${file} unchanged`);
		assert.ok(!fs.existsSync(path.join(dir, "ai-factory/evidence")), "migration invents no evidence");
		value = doc(dir, ["--all"], 1);
		assert.ok(has(value, "L_REVIEW_REQUIRED", "ai-factory/specs/0001-old-feature.contract.json"));
		assert.ok(has(value, "E_EVIDENCE_NOT_RUN", "S1-step.json"), "a migrated ticked step still needs evidence");
		const spec = json(dir, "ai-factory/specs/0001-old-feature.contract.json");
		const plan = json(dir, "ai-factory/plans/done/0001-old-feature.contract.json");
		assert.equal(plan.delivery_id, spec.delivery_id, "plan joins its spec's delivery");
		assert.equal(spec.migrated, true);
		expect(run(dir, ["init", "spec", "ai-factory/specs/0001-old-feature.md"]), 0, "reviewed spec");
		assert.equal(json(dir, "ai-factory/specs/0001-old-feature.contract.json").delivery_id, spec.delivery_id, "init keeps the delivery ID");
		assert.equal(json(dir, "ai-factory/specs/0001-old-feature.contract.json").review_required, undefined);
		ok("migration: explicit, idempotent, prose-preserving, never valid by itself");
	}

	// --- make entry points and review evidence ---------------------------------------------
	{
		const { dir, id } = planned();
		fs.cpSync(MAKE, path.join(dir, "ai-factory/make"), { recursive: true });
		fs.mkdirSync(path.join(dir, "ai-factory/tasks"));
		write(dir, "ai-factory/tasks/check.md", "Return exactly one review JSON object.");
		write(dir, "ai-factory/models.yaml", "claude:\ncodex:\nreview:\n");
		write(dir, "ai-factory/.gitignore", "/runs/\n");
		const fake = path.join(dir, "ai-factory/fake-cli");
		fs.writeFileSync(fake, `#!/usr/bin/env node
let input='';process.stdin.on('data',c=>input+=c);process.stdin.on('end',()=>{
 const findings=process.env.FAKE_BLOCKER?[{severity:'blocker',file:'src/export.js',line:1,issue:'x',suggestion:'y'}]:[];
 const final=JSON.stringify({verdict:process.env.FAKE_VERDICT||'approve',findings,summary:'Fixture review'});
 process.stdout.write(JSON.stringify({result:final,usage:{input_tokens:1,output_tokens:1}}));
});
`, { mode: 0o700 });
		const makeEnv = { ...clean, TOOL: "claude", CMD: fake, MODEL: "", INPUT: "", INPUT_FILE: "", GATE_ENFORCE: "", REVIEW_SCOPE: "", MAKEFLAGS: "", MAKEOVERRIDES: "" };
		const make = (args, env = {}) => spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", ...args], { cwd: dir, env: { ...makeEnv, ...env }, encoding: "utf8" });
		expect(make(["verify", `DELIVERY=${id}`, "STEP=S1", "PHASE=red"]), 0, "make verify red");
		expect(make(["verify", `DELIVERY=${id}`, "STEP=S1"]), 0, "make verify step");
		const viaMake = make(["contracts", `DELIVERY=${id}`, "JSON=1"]);
		assert.equal(JSON.parse(viaMake.stdout).status, "valid", "make contracts JSON=1 prints one document");
		assert.equal(make(["contracts", "DELIVERY=$(shell touch pwned)"]).status, 2, "make values are literal data");
		assert.ok(!fs.existsSync(path.join(dir, "pwned")));
		write(dir, "src/export.js", `${read(dir, "src/export.js")}// reviewed change\n`);
		expect(make(["review", `DELIVERY=${id}`]), 0, "advisory review with evidence");
		let review = json(dir, `ai-factory/evidence/${id}/review.json`);
		assert.equal(review.status, "passed");
		assert.equal(review.review.verdict, "approve");
		assert.match(review.review.output_sha256, /^[0-9a-f]{64}$/);
		assert.ok(!doc(dir, [id, "--require", "review"]).artifacts.some((a) => a.path.endsWith("review.json") && a.state !== "valid"));
		write(dir, "src/export.js", `${read(dir, "src/export.js")}// after review\n`);
		assert.ok(has(doc(dir, [id, "--require", "review"], 1), "S_CODE_CHANGED", "review.json"), "code edited after review");
		expect(make(["review", `DELIVERY=${id}`], { FAKE_VERDICT: "request_changes" }), 0, "advisory request_changes");
		assert.equal(json(dir, `ai-factory/evidence/${id}/review.json`).status, "failed");
		assert.ok(has(doc(dir, [id, "--require", "review"], 1), "E_EVIDENCE_FAILED", "review.json"));
		assert.notEqual(make(["review", `DELIVERY=${id}`], { FAKE_BLOCKER: "1", GATE_ENFORCE: "1" }).status, 0, "enforced blocker");
		review = json(dir, `ai-factory/evidence/${id}/review.json`);
		assert.equal(review.status, "failed", "an enforced failure still records its evidence");
		expect(make(["review", `DELIVERY=${id}`], { GATE_ENFORCE: "1" }), 0, "enforced approval");
		assert.equal(json(dir, `ai-factory/evidence/${id}/review.json`).status, "passed");
		ok("make verify, make contracts and review evidence");
	}

	// --- AC7: an adopted workspace runs both flows through the documented commands ---------
	{
		const { adopt } = require(path.resolve("skills/ai-layout/scripts/adopt.js"));
		const plugin = process.cwd();
		const dir = fs.mkdtempSync(path.join(scratch, "adopted-"));
		git(dir, "init", "-q");
		adopt(dir, plugin, "Fixture Owner");
		const ai = path.join(dir, "ai-factory");
		// The procedures every host reads carry the same contract commands.
		const procedures = {
			"agents/specifier.md": ["contracts.js init spec"],
			"agents/planner.md": ["contracts.js init plan", "Verify (red|step|final)"],
			"agents/tester.md": ["verify DELIVERY=<id> STEP=S<N> PHASE=red", "contracts DELIVERY=<id>"],
			"agents/implementer.md": ["verify DELIVERY=<id> STEP=S<N>", "PHASE=final", "contracts DELIVERY=<id>"],
			"agents/reviewer.md": ["contracts.js validate"],
			"tasks/quick.md": ["contracts.js init quick", "verify DELIVERY=<id>"],
		};
		for (const [file, needles] of Object.entries(procedures)) {
			const text = fs.readFileSync(path.join(ai, file), "utf8");
			assert.match(text, /ai-factory\/contracts\/config\.json/, `${file} gates contracts on adoption`);
			for (const needle of needles) assert.ok(text.includes(needle), `${file} names ${needle}`);
		}
		for (const [task, agent] of [["spec", "specifier"], ["plan", "planner"], ["test", "tester"], ["run", "implementer"], ["check", "reviewer"]]) {
			assert.match(fs.readFileSync(path.join(plugin, "commands", `${task}.md`), "utf8"), new RegExp(`ai-factory/tasks/${task}\\.md`), `Claude ${task} reads the shared task`);
			assert.match(fs.readFileSync(path.join(plugin, "codex-skills", `t4-${task}`, "SKILL.md"), "utf8"), new RegExp(`ai-factory/agents/${agent}\\.md`), `Codex ${task} reads the shared procedure`);
		}
		assert.ok(fs.existsSync(path.join(ai, "make/contracts.js")) && fs.existsSync(path.join(ai, "contracts/README.md")));
		assert.ok(!fs.existsSync(path.join(ai, "contracts/config.json")), "adoption alone does not opt in");
		assert.ok(read(dir, "ai-factory/.gitignore").split("\n").includes("/runs/evidence/"));
		const doctor = () => execFileSync("bash", [path.join(plugin, "skills/ai-layout/scripts/doctor.sh"), dir, plugin], { encoding: "utf8", env: { ...clean, CLAUDE_CONFIG_DIR: path.join(scratch, "no-config") } }).split("\n").find((line) => / contracts /.test(line)) || "";
		assert.match(doctor(), /^\[ok\s*\] contracts\s+not enabled/, "doctor offers the opt-in");
		expect(spawnSync(process.execPath, ["ai-factory/make/contracts.js", "enable"], { cwd: dir, env: clean, encoding: "utf8" }), 0, "enable in adopted repo");
		execFileSync(process.execPath, [path.join(plugin, "skills/ai-layout/scripts/manifest.js"), "write", dir, plugin], { stdio: "pipe" });
		assert.deepEqual(json(dir, "ai-factory/.sdlc.json").capabilities, { contracts: { version: 1 } }, "manifest rewrite keeps the capability");
		fs.cpSync(path.join(FIXTURES, "planned"), dir, { recursive: true });
		fs.cpSync(path.join(FIXTURES, "quick"), dir, { recursive: true });
		git(dir, "add", "-A");
		git(dir, "commit", "-q", "-m", "adopted");
		const node = (...args) => expect(spawnSync(process.execPath, ["ai-factory/make/contracts.js", ...args], { cwd: dir, env: clean, encoding: "utf8" }), 0, args.join(" "));
		const make = (...args) => expect(spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", ...args], { cwd: dir, env: { ...clean, MAKEFLAGS: "", MAKEOVERRIDES: "" }, encoding: "utf8" }), 0, args.join(" "));
		node("init", "spec", SPEC);
		node("init", "plan", PLAN, "--spec", SPEC);
		const id = json(dir, SPEC_SIDE).delivery_id;
		make("verify", `DELIVERY=${id}`, "STEP=S1", "PHASE=red");
		for (const step of [1, 2, 3]) {
			make("verify", `DELIVERY=${id}`, `STEP=S${step}`);
			if (step === 3) make("verify", `DELIVERY=${id}`, "PHASE=final");
			tick(dir, step);
			make("contracts", `DELIVERY=${id}`);
		}
		node("init", "quick", "ai-factory/quick/fix-date-format.md");
		const quick = json(dir, "ai-factory/quick/fix-date-format.contract.json").delivery_id;
		write(dir, "ai-factory/quick/fix-date-format.md", read(dir, "ai-factory/quick/fix-date-format.md").replace(/- \[ \]/g, "- [x]"));
		make("verify", `DELIVERY=${quick}`);
		make("contracts", `DELIVERY=${quick}`);
		const all = JSON.parse(spawnSync("make", ["-s", "-f", "ai-factory/make/ai.mk", "contracts", "JSON=1"], { cwd: dir, env: clean, encoding: "utf8" }).stdout);
		assert.equal(all.status, "valid", JSON.stringify(all.artifacts.filter((a) => a.state !== "valid"), null, 1));
		assert.match(doctor(), /^\[ok\s*\] contracts\s+enabled \(capability v1\); every contract artifact is valid/);
		write(dir, "src/export.js", `${read(dir, "src/export.js")}// unverified edit\n`);
		assert.match(doctor(), /^\[finding\] contracts\s+enabled \(capability v1\); overall state is stale/, "doctor reports stale evidence");
		ok("adopted workspace: planned and quick flows through the shared procedures");
	}

	// --- enable records the capability and is idempotent -----------------------------------
	{
		const dir = project("planned");
		writeJson(dir, "ai-factory/.sdlc.json", { schema: 1, plugin: "ai-sdlc", version: "2.5.0", files: {} });
		expect(run(dir, ["enable"]), 0, "enable");
		const first = read(dir, "ai-factory/contracts/config.json");
		assert.deepEqual(json(dir, "ai-factory/.sdlc.json").capabilities, { contracts: { version: 1 } });
		assert.match(expect(run(dir, ["enable"]), 0, "enable again").stdout, /already enabled/);
		assert.equal(read(dir, "ai-factory/contracts/config.json"), first);
		ok("enable is idempotent and records the capability");
	}
}
main()
	.then(() => console.log(`contracts ok — ${cases} cases: schemas, valid chain, invalid handoffs, stale propagation, evidence outcomes, read-only boundaries, quick work and migration`))
	.catch((error) => {
		console.error(`FAIL: ${error.message}`);
		process.exitCode = 1;
	})
	.finally(() => fs.rmSync(scratch, { recursive: true, force: true }));
NODE
