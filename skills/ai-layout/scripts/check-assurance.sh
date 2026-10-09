#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
# Assurance presets (spec 0021). Offline; never invokes a model or a host.
# Groups: policy, runtime, procedures, docs (default: every group). Each case builds its own
# disposable project under the system temp directory from the shipped make/ helpers; runtime
# cases drive the headless runner with a fake host CLI and never call a model.
# A group with no implemented cases fails: an empty group is never reported as a pass.
group="${1:-all}"
case "$group" in
	all | policy | runtime | procedures | docs) ;;
	*) echo "check-assurance: unknown group '$group' (expected: policy|runtime|procedures|docs)" >&2; exit 2 ;;
esac
ASSURANCE_GROUP="$group" node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync, execFileSync } = require("node:child_process");
// ASSURANCE_MAKE points the cases at another make/ directory (for example a baseline copy, to
// show the red phase); by default they run the shipped templates.
const MAKE = path.resolve(process.env.ASSURANCE_MAKE || "skills/ai-layout/templates/ai-factory/make");
const HELPER = path.join(MAKE, "assurance.js");
const GROUPS = ["policy", "runtime", "procedures", "docs"];
const selected = process.env.ASSURANCE_GROUP;
const want = (name) => selected === "all" || selected === name;
const base = fs.mkdtempSync(path.join(os.tmpdir(), "t4-assurance-"));
const passed = [], failed = [], ran = new Set();
function check(groupName, label, fn) {
	if (!want(groupName)) return;
	ran.add(groupName);
	try { fn(); passed.push(label); }
	catch (error) { failed.push(label); console.error(`FAIL ${label}: ${String(error.message).split("\n")[0]}`); if (process.env.VERBOSE) console.error(error.stack); }
}
// A missing helper or export is the missing behavior itself, reported per case, never a crash.
function helper() {
	assert.ok(fs.existsSync(HELPER), "make/assurance.js does not exist: preset resolution is not implemented");
	return require(HELPER);
}
function need(name) {
	const value = helper()[name];
	assert.equal(typeof value, "function", `assurance.js exports no ${name}(): that behavior is not implemented`);
	return value;
}
const CONFIG = { schema: "t4-contracts-config", version: 1, code_scope: { include: ["**"], exclude: [] } };
let projects = 0;
function project({ config, selection, manifest = true } = {}) {
	const dir = path.join(base, `p${++projects}`);
	fs.mkdirSync(path.join(dir, "ai-factory/make"), { recursive: true });
	for (const file of ["assurance.js", "contracts.js", "gate.js", "safe-files.js"])
		if (fs.existsSync(path.join(MAKE, file)))
			fs.copyFileSync(path.join(MAKE, file), path.join(dir, "ai-factory/make", file));
	if (manifest) writeJson(dir, "ai-factory/.sdlc.json", { version: "fixture" });
	if (config) writeJson(dir, "ai-factory/contracts/config.json", config);
	if (selection !== undefined)
		write(dir, "ai-factory/assurance.json", typeof selection === "string" ? selection : `${JSON.stringify(selection)}\n`);
	return dir;
}
function write(dir, file, text) {
	fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
	fs.writeFileSync(path.join(dir, file), text);
}
const writeJson = (dir, file, value) => write(dir, file, `${JSON.stringify(value, null, 2)}\n`);
const exists = (dir, file) => fs.existsSync(path.join(dir, file));
const readJson = (dir, file) => JSON.parse(fs.readFileSync(path.join(dir, file), "utf8"));
const selection = (preset) => ({ schema: "t4-assurance", version: 1, preset });
// Every file below ai-factory/ with its bytes: proves a command wrote nothing.
function tree(dir) {
	const out = {};
	const walk = (rel) => {
		for (const entry of fs.readdirSync(path.join(dir, rel), { withFileTypes: true })) {
			const child = path.join(rel, entry.name);
			if (entry.isSymbolicLink()) out[child] = `link:${fs.readlinkSync(path.join(dir, child))}`;
			else if (entry.isDirectory()) { out[`${child}/`] = "dir"; walk(child); }
			else out[child] = fs.readFileSync(path.join(dir, child), "utf8");
		}
	};
	walk("ai-factory");
	return out;
}
const clean = { ...process.env };
for (const key of ["GATE_ENFORCE", "JSON"]) delete clean[key];
function cli(dir, args, env = {}) {
	assert.ok(exists(dir, "ai-factory/make/assurance.js"), "make/assurance.js does not exist: the assurance command is not implemented");
	return spawnSync(process.execPath, [path.join(dir, "ai-factory/make/assurance.js"), ...args], { cwd: dir, env: { ...clean, ...env }, encoding: "utf8" });
}
function expectExit(result, status, label) {
	assert.equal(result.status, status, `${label}: exit ${result.status}\nstdout:${result.stdout}\nstderr:${result.stderr}`);
	return result;
}
const jsonOf = (result) => JSON.parse(result.stdout);
const show = (dir, env, status = 0) => jsonOf(expectExit(cli(dir, ["show", "--json"], env), status, "show"));
const legacyContracts = (overrides = {}) => ({ adopted: false, code_scope: { include: ["**"], exclude: [] }, completion: { require_review: true, require_review_quick: false, blocking_severities: ["blocker"], allow_attestation: false }, ...overrides });
const adoptedContracts = (completion = {}, code_scope = { include: ["**"], exclude: [] }) =>
	legacyContracts({ adopted: true, code_scope, completion: { ...legacyContracts().completion, ...completion } });

// --- policy (Step 1): resolution, display, explicit selection --------------------------------
check("policy", "preset-resolution", () => {
	const resolve = need("resolve");
	const { PRESETS } = helper();
	assert.deepEqual(Object.keys(PRESETS), ["light", "standard", "strict"]);
	const values = (preset) => Object.fromEntries(Object.entries(resolve({ preset, contracts: adoptedContracts({ require_review: false }), env: {} }).settings).map(([key, item]) => [key, item.value]));
	// Over a permissive base each preset's own requirements show through unchanged.
	const light = resolve({ preset: "light", contracts: legacyContracts(), env: {} });
	assert.equal(light.preset, "light");
	assert.equal(light.status, "active");
	assert.equal(light.settings.contracts.value, false);
	assert.equal(light.settings.final_verification.value, false);
	assert.equal(light.settings.review_required.value, false);
	assert.equal(light.settings.review_independence.value, "self");
	assert.equal(light.settings.gate.value, "advisory");
	assert.equal(light.settings.completion.value, "summary");
	const standard = values("standard");
	assert.equal(standard.contracts, true);
	assert.equal(standard.final_verification, true);
	assert.equal(standard.review_required, true);
	assert.equal(standard.review_required_quick, true, "standard requires independent review for quick deliveries too");
	assert.equal(standard.review_independence, "independent");
	assert.equal(standard.gate, "advisory");
	assert.equal(standard.completion, "recorded_checks");
	const strict = values("strict");
	assert.deepEqual({ ...strict, gate: undefined, completion: undefined }, { ...standard, gate: undefined, completion: undefined }, "strict contracts/verification/review equal standard");
	assert.equal(strict.gate, "enforced");
	assert.equal(strict.completion, "fresh_ready_report");
	// The resolver is deterministic and produces one shared document shape.
	const again = resolve({ preset: "strict", contracts: adoptedContracts(), env: {} });
	assert.deepEqual(again, resolve({ preset: "strict", contracts: adoptedContracts(), env: {} }));
	assert.equal(again.schema, "t4-assurance-policy");
	assert.match(again.note, /project rules/i, "the policy states project rules still apply");
	// Unknown preset names are rejected by the resolver, not mapped to a default.
	assert.throws(() => resolve({ preset: "paranoid", contracts: adoptedContracts(), env: {} }), /unknown preset/i);
	// An explicit selection on disk resolves through show.
	const dir = project({ config: CONFIG, selection: selection("standard") });
	const shown = show(dir);
	assert.equal(shown.preset, "standard");
	assert.equal(shown.status, "active");
	assert.equal(shown.settings.review_independence.value, "independent");
	const human = expectExit(cli(dir, ["show"]), 0, "human show").stdout;
	assert.match(human, /preset standard/);
	assert.match(human, /review_independence\s+independent/);
});

check("policy", "effective-sources", () => {
	const resolve = need("resolve");
	// Custom controls stronger than the preset are retained and attributed to their source.
	const custom = adoptedContracts({ require_review_quick: true, blocking_severities: ["blocker", "major"], allow_attestation: true }, { include: ["src/**"], exclude: ["dist/**"] });
	const standard = resolve({ preset: "standard", contracts: custom, env: { GATE_ENFORCE: "1" } });
	assert.equal(standard.status, "active");
	assert.deepEqual(standard.settings.blocking_severities, { value: ["blocker", "major"], source: "ai-factory/contracts/config.json", retained: true });
	assert.deepEqual(standard.settings.gate, { value: "enforced", source: "GATE_ENFORCE", retained: true });
	assert.deepEqual(standard.settings.code_scope.value, { include: ["src/**"], exclude: ["dist/**"] });
	assert.equal(standard.settings.code_scope.source, "ai-factory/contracts/config.json");
	assert.equal(standard.settings.allow_attestation.value, true, "custom attestation policy is preserved");
	assert.equal(standard.settings.allow_attestation.source, "ai-factory/contracts/config.json");
	assert.equal(standard.settings.review_required.source, "preset:standard");
	assert.equal(standard.settings.contracts.source, "preset:standard");
	// A weaker custom setting never lowers the preset's minimum.
	const weak = resolve({ preset: "standard", contracts: adoptedContracts({ require_review: false, blocking_severities: [] }), env: { GATE_ENFORCE: "0" } });
	assert.equal(weak.settings.review_required.value, true);
	assert.equal(weak.settings.review_required.source, "preset:standard");
	assert.deepEqual(weak.settings.blocking_severities.value, ["blocker"]);
	assert.equal(weak.settings.gate.value, "advisory");
	assert.deepEqual(weak.conflicts, [], "GATE_ENFORCE=0 is compatible with standard's advisory gate");
	// Under light, contracts' stricter completion policy stays and is labelled retained.
	const light = resolve({ preset: "light", contracts: custom, env: {} });
	assert.deepEqual(light.settings.review_required_quick, { value: true, source: "ai-factory/contracts/config.json", retained: true });
	assert.deepEqual(light.settings.blocking_severities.value, ["blocker", "major"]);
	// Every setting names a source; the human view shows the same sources.
	for (const [key, item] of Object.entries(standard.settings))
		assert.ok(typeof item.source === "string" && item.source, `${key} has a source`);
	const dir = project({ config: { ...CONFIG, code_scope: { include: ["src/**"], exclude: ["dist/**"] }, completion: { blocking_severities: ["blocker", "major"] } }, selection: selection("standard") });
	const human = expectExit(cli(dir, ["show"], { GATE_ENFORCE: "1" }), 0, "human show").stdout;
	assert.match(human, /gate\s+enforced\s+\(GATE_ENFORCE, retained above preset\)/);
	assert.match(human, /blocking_severities\s+blocker,major\s+\(ai-factory\/contracts\/config\.json, retained above preset\)/);
	assert.deepEqual(show(dir, { GATE_ENFORCE: "1" }).settings.gate, { value: "enforced", source: "GATE_ENFORCE", retained: true });
});

check("policy", "light-retains-contracts", () => {
	need("setup");
	// Selecting light over enabled contracts keeps configuration and evidence byte-for-byte.
	const config = { ...CONFIG, completion: { require_review_quick: true } };
	const dir = project({ config, selection: selection("strict") });
	write(dir, "ai-factory/evidence/d-20260101-abcdef/final.json", "{\"recorded\":true}\n");
	const before = tree(dir);
	const preview = jsonOf(expectExit(cli(dir, ["set", "light", "--json"]), 0, "preview light"));
	assert.equal(preview.applied, false);
	assert.ok(!preview.changes.some((change) => change.action !== "select"), `light only changes the selection: ${JSON.stringify(preview.changes)}`);
	assert.ok(preview.retained.some((note) => /contracts/i.test(note)), "preview names the retained contracts configuration");
	const applied = jsonOf(expectExit(cli(dir, ["set", "light", "--apply", "--json"]), 0, "apply light"));
	assert.equal(applied.applied, true);
	const after = tree(dir);
	assert.deepEqual(readJson(dir, "ai-factory/assurance.json"), selection("light"));
	for (const key of Object.keys(before).filter((key) => key !== "ai-factory/assurance.json"))
		assert.equal(after[key], before[key], `${key} unchanged after switching down`);
	const shown = show(dir);
	assert.equal(shown.preset, "light");
	assert.deepEqual(shown.settings.contracts, { value: true, source: "ai-factory/contracts/config.json", retained: true });
	assert.equal(shown.settings.final_verification.retained, true);
	assert.equal(shown.settings.review_required_quick.value, true);
	const human = expectExit(cli(dir, ["show"]), 0, "human show").stdout;
	assert.match(human, /contracts\s+true\s+\(ai-factory\/contracts\/config\.json, retained above preset\)/);
});

check("policy", "strict-conflict", () => {
	const resolve = need("resolve");
	const conflict = resolve({ preset: "strict", contracts: adoptedContracts(), env: { GATE_ENFORCE: "0" } });
	assert.equal(conflict.status, "conflict");
	assert.deepEqual(conflict.conflicts.map((item) => item.code), ["E_GATE_CONFLICT"]);
	assert.match(conflict.conflicts[0].message, /GATE_ENFORCE=0/);
	assert.ok(conflict.conflicts[0].hint, "the conflict is actionable");
	assert.equal(conflict.settings.gate.value, "enforced", "the conflict never silently weakens strict");
	// Stricter override is allowed and shown.
	assert.deepEqual(resolve({ preset: "strict", contracts: adoptedContracts(), env: { GATE_ENFORCE: "1" } }).conflicts, []);
	// show reports the conflict and exits nonzero, in both views.
	const dir = project({ config: CONFIG, selection: selection("strict") });
	const shown = show(dir, { GATE_ENFORCE: "0" }, 1);
	assert.equal(shown.status, "conflict");
	const human = expectExit(cli(dir, ["show"], { GATE_ENFORCE: "0" }), 1, "human conflict");
	assert.match(human.stderr, /E_GATE_CONFLICT/);
	assert.doesNotMatch(human.stdout + human.stderr, /strict — active/);
	// Selecting strict under the conflicting override is refused before any write.
	const fresh = project({ config: CONFIG });
	const before = tree(fresh);
	const refused = cli(fresh, ["set", "strict", "--apply", "--json"], { GATE_ENFORCE: "0" });
	expectExit(refused, 1, "apply strict under GATE_ENFORCE=0");
	assert.equal(jsonOf(refused).applied, false);
	assert.deepEqual(tree(fresh), before, "a refused selection writes nothing");
	// Without a preset the same override keeps its existing meaning: no conflict.
	assert.deepEqual(resolve({ preset: null, contracts: adoptedContracts(), env: { GATE_ENFORCE: "0" } }).conflicts, []);
});

check("policy", "legacy-unset", () => {
	const resolve = need("resolve");
	// No selection: existing configuration is reported as-is, with no preset claimed.
	const legacy = resolve({ preset: null, contracts: adoptedContracts({ require_review: false }), env: { GATE_ENFORCE: "1" } });
	assert.equal(legacy.mode, "legacy");
	assert.equal(legacy.preset, null);
	assert.equal(legacy.status, "legacy");
	assert.equal(legacy.settings.review_required.value, false, "legacy reports the configured value, no preset minimum");
	assert.equal(legacy.settings.gate.value, "enforced");
	assert.equal(legacy.settings.gate.source, "GATE_ENFORCE");
	assert.ok(Object.values(legacy.settings).every((item) => !item.source.startsWith("preset:")));
	const bare = resolve({ preset: null, contracts: legacyContracts(), env: {} });
	assert.equal(bare.settings.contracts.value, false);
	assert.deepEqual(bare.unmet, []);
	for (const dir of [project({}), project({ config: CONFIG })]) {
		const before = tree(dir);
		const shown = show(dir);
		assert.equal(shown.mode, "legacy");
		assert.equal(shown.preset, null);
		const human = expectExit(cli(dir, ["show"]), 0, "legacy human").stdout;
		assert.match(human, /no preset selected/);
		assert.deepEqual(tree(dir), before, "show never creates a selection");
	}
});

check("policy", "invalid-input", () => {
	need("setup");
	for (const [label, body] of [
		["not json", "{"],
		["array", "[]\n"],
		["wrong schema", `${JSON.stringify({ schema: "other", version: 1, preset: "light" })}\n`],
		["wrong version", `${JSON.stringify({ schema: "t4-assurance", version: 2, preset: "light" })}\n`],
		["unknown preset", `${JSON.stringify(selection("paranoid"))}\n`],
		["extra keys", `${JSON.stringify({ ...selection("light"), review: "none" })}\n`],
	]) {
		const dir = project({ config: CONFIG, selection: body });
		const before = tree(dir);
		const shown = expectExit(cli(dir, ["show"]), 2, `show with ${label}`);
		assert.match(shown.stderr, /ai-factory\/assurance\.json/, `${label} names the file`);
		expectExit(cli(dir, ["set", "standard", "--apply"]), 2, `set over ${label}`);
		assert.deepEqual(tree(dir), before, `${label}: nothing written`);
	}
	// Unknown preset and malformed arguments stop before reading or writing anything.
	const dir = project({ config: CONFIG });
	const before = tree(dir);
	assert.match(expectExit(cli(dir, ["set", "paranoid", "--apply"]), 2, "unknown preset").stderr, /light, standard, strict/);
	expectExit(cli(dir, ["set"]), 2, "missing preset");
	expectExit(cli(dir, ["set", "light", "--bogus"]), 2, "unknown flag");
	expectExit(cli(dir, ["frobnicate"]), 2, "unknown command");
	expectExit(cli(dir, ["show"], { GATE_ENFORCE: "yes" }), 1, "invalid GATE_ENFORCE is a reported conflict");
	assert.deepEqual(tree(dir), before);
	// A malformed contracts configuration stops setup before any write.
	const broken = project({ config: { schema: "t4-contracts-config", version: 1 } });
	const brokenBefore = tree(broken);
	assert.match(expectExit(cli(broken, ["set", "standard", "--apply"]), 2, "malformed config").stderr, /config\.json/);
	assert.deepEqual(tree(broken), brokenBefore);
});

check("policy", "preview-read-only", () => {
	need("setup");
	const dir = project({});
	const before = tree(dir);
	const preview = jsonOf(expectExit(cli(dir, ["set", "standard", "--json"]), 0, "preview"));
	assert.equal(preview.applied, false);
	assert.deepEqual(preview.changes.map((change) => change.action).sort(), ["enable_contracts", "select"]);
	assert.equal(preview.policy.preset, "standard");
	assert.equal(preview.policy.settings.contracts.value, true, "the preview resolves the policy as it would be after applying");
	assert.deepEqual(tree(dir), before, "preview writes nothing");
	const human = expectExit(cli(dir, ["set", "standard"]), 0, "human preview").stdout;
	assert.match(human, /--apply/);
	assert.deepEqual(tree(dir), before);
});

check("policy", "explicit-apply", () => {
	need("setup");
	const dir = project({});
	const result = jsonOf(expectExit(cli(dir, ["set", "standard", "--apply", "--json"]), 0, "apply standard"));
	assert.equal(result.applied, true);
	assert.deepEqual(readJson(dir, "ai-factory/assurance.json"), selection("standard"));
	assert.equal(readJson(dir, "ai-factory/contracts/config.json").schema, "t4-contracts-config", "standard enables contracts through the existing helper");
	assert.deepEqual(readJson(dir, "ai-factory/.sdlc.json").capabilities, { contracts: { version: 1 } });
	assert.equal(show(dir).status, "active");
	// Reapplying the same preset is a no-op; a custom config is never rewritten.
	const custom = { ...CONFIG, code_scope: { include: ["src/**"], exclude: [] }, completion: { allow_attestation: true } };
	const kept = project({ config: custom });
	const configBytes = fs.readFileSync(path.join(kept, "ai-factory/contracts/config.json"), "utf8");
	expectExit(cli(kept, ["set", "strict", "--apply"]), 0, "apply strict");
	assert.equal(fs.readFileSync(path.join(kept, "ai-factory/contracts/config.json"), "utf8"), configBytes);
	const once = tree(kept);
	const again = jsonOf(expectExit(cli(kept, ["set", "strict", "--apply", "--json"]), 0, "reapply"));
	assert.deepEqual(again.changes, []);
	assert.deepEqual(tree(kept), once, "reapplying writes nothing");
	// A selection whose contracts were removed afterwards reports drift, not an active preset.
	fs.rmSync(path.join(kept, "ai-factory/contracts/config.json"));
	const drift = show(kept, {}, 1);
	assert.equal(drift.status, "incomplete");
	assert.deepEqual(drift.unmet.map((item) => item.code), ["U_CONTRACTS_NOT_ENABLED"]);
	assert.equal(drift.settings.contracts.value, false, "never claims contracts it does not have");
});

check("policy", "failed-apply", () => {
	need("setup");
	if (process.getuid && process.getuid() === 0) return; // permissions do not bind root
	// Enabling contracts fails: nothing is selected.
	const blocked = project({});
	fs.mkdirSync(path.join(blocked, "ai-factory/contracts"));
	fs.chmodSync(path.join(blocked, "ai-factory/contracts"), 0o500);
	const before = tree(blocked);
	const first = cli(blocked, ["set", "standard", "--apply", "--json"]);
	fs.chmodSync(path.join(blocked, "ai-factory/contracts"), 0o700);
	expectExit(first, 1, "enable fails");
	const value = jsonOf(first);
	assert.equal(value.applied, false);
	assert.equal(value.failed.step, "enable_contracts");
	assert.deepEqual(value.partial, []);
	assert.deepEqual(tree(blocked), before, "a failed enable leaves no selection");
	// Writing the selection fails after contracts were enabled: partial setup, never activation.
	const partial = project({});
	fs.mkdirSync(path.join(partial, "ai-factory/contracts"));
	fs.chmodSync(path.join(partial, "ai-factory"), 0o500);
	const second = cli(partial, ["set", "standard", "--apply"]);
	fs.chmodSync(path.join(partial, "ai-factory"), 0o700);
	expectExit(second, 1, "selection write fails");
	assert.match(second.stderr, /not active/);
	assert.match(second.stderr, /enable_contracts/);
	assert.doesNotMatch(second.stdout, /standard — active/);
	assert.ok(!exists(partial, "ai-factory/assurance.json"));
	assert.equal(show(partial).mode, "legacy");
});

check("policy", "safe-paths", () => {
	need("setup");
	// A symlinked selection is never read or written through.
	const outside = path.join(base, "outside.json");
	fs.writeFileSync(outside, `${JSON.stringify(selection("strict"))}\n`);
	const dir = project({ config: CONFIG });
	fs.symlinkSync(outside, path.join(dir, "ai-factory/assurance.json"));
	assert.match(expectExit(cli(dir, ["show"]), 2, "symlinked selection").stderr, /symlink/i);
	expectExit(cli(dir, ["set", "light", "--apply"]), 2, "set through symlink");
	assert.deepEqual(JSON.parse(fs.readFileSync(outside, "utf8")), selection("strict"), "the link target is untouched");
	// A hard-linked selection is refused too.
	const hard = project({ config: CONFIG });
	fs.linkSync(outside, path.join(hard, "ai-factory/assurance.json"));
	expectExit(cli(hard, ["set", "light", "--apply"]), 2, "hard-linked selection");
	assert.deepEqual(JSON.parse(fs.readFileSync(outside, "utf8")), selection("strict"));
	// A symlinked contracts configuration stops setup before anything is written.
	const linked = project({});
	fs.mkdirSync(path.join(linked, "ai-factory/contracts"));
	fs.writeFileSync(path.join(base, "outside-config.json"), `${JSON.stringify(CONFIG)}\n`);
	fs.symlinkSync(path.join(base, "outside-config.json"), path.join(linked, "ai-factory/contracts/config.json"));
	const before = tree(linked);
	expectExit(cli(linked, ["set", "standard", "--apply"]), 2, "symlinked config");
	assert.deepEqual(tree(linked), before);
});

// --- runtime (Step 2): gate, runner, completion evidence and reports ---------------------------
// Each case is a disposable Git repository built from the contract fixtures with the whole make/
// directory, a check task and a fake host CLI that records each launch and returns a canned review.
const FIXTURES = path.resolve("skills/ai-layout/fixtures/contracts");
// Canonical procedures: the task templates and the plugin's own agents (the template agents are
// these plus the Project additions section, kept in step by materialize-agents.js).
const TASKS = path.resolve("skills/ai-layout/templates/ai-factory/tasks");
const TEMPLATE_AGENTS = path.resolve("skills/ai-layout/templates/ai-factory/agents");
const AGENTS = path.resolve("agents");
const REPORT_SCHEMA = path.resolve("skills/ai-layout/templates/ai-factory/contracts/schema/report.v1.json");
const SPEC = "ai-factory/specs/0001-csv-export.md";
const PLAN = "ai-factory/plans/0001-csv-export.md";
const QUICK = "ai-factory/quick/fix-date-format.md";
const CONFIG_FILE = "ai-factory/contracts/config.json";
const FAKE_CLI = `#!/usr/bin/env node
const fs=require('node:fs');let input='';process.stdin.on('data',c=>input+=c);process.stdin.on('end',()=>{
 fs.appendFileSync('ai-factory/capture.jsonl',JSON.stringify({args:process.argv.slice(2),input})+'\\n');
 const findings=process.env.FAKE_BLOCKER?[{severity:'blocker',file:'src/export.js',line:1,issue:'x',suggestion:'y'}]:[];
 const final=JSON.stringify({verdict:process.env.FAKE_VERDICT||'approve',findings,summary:'Fixture review'});
 process.stdout.write(JSON.stringify({result:final,usage:{input_tokens:1,output_tokens:1}}));
});
`;
const bare = { ...clean };
for (const key of ["DELIVERY", "STEP", "PHASE", "REQUIRE", "TASK", "TOOL", "CMD", "MODEL", "INPUT", "INPUT_FILE", "REVIEW_SCOPE", "CONTRACT_FIXTURE_EXIT", "CONTRACT_FIXTURE_RED_EXIT", "CLAUDE_CODE_SUBAGENT_MODEL", "T4_LIFECYCLE_RUN", "FAKE_VERDICT", "FAKE_BLOCKER"]) delete bare[key];
const gitIn = (dir, ...args) => execFileSync("git", ["-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", ...args], { cwd: dir, stdio: "pipe" });
const readText = (dir, file) => fs.readFileSync(path.join(dir, file), "utf8");
// `procedures: true` ships the canonical task procedures and agents instead of the stubs.
function workspace(fixture, { preset, contracts = !preset, procedures = false } = {}) {
	const dir = path.join(base, `r${++projects}-${fixture}`);
	fs.cpSync(path.join(FIXTURES, fixture), dir, { recursive: true });
	fs.cpSync(MAKE, path.join(dir, "ai-factory/make"), { recursive: true });
	if (procedures) {
		fs.cpSync(TASKS, path.join(dir, "ai-factory/tasks"), { recursive: true });
		fs.cpSync(TEMPLATE_AGENTS, path.join(dir, "ai-factory/agents"), { recursive: true });
	} else {
		write(dir, "ai-factory/tasks/check.md", "Return exactly one review JSON object.\n");
		write(dir, "ai-factory/tasks/quick.md", "Quick task fixture.\n");
	}
	write(dir, "ai-factory/models.yaml", "claude:\ncodex:\nreview:\n");
	write(dir, "ai-factory/.gitignore", "/runs/\n");
	writeJson(dir, "ai-factory/.sdlc.json", { version: "fixture" });
	fs.writeFileSync(path.join(dir, "ai-factory/fake-cli"), FAKE_CLI, { mode: 0o700 });
	gitIn(dir, "init", "-q", "-b", "main");
	gitIn(dir, "add", "-A");
	gitIn(dir, "commit", "-q", "-m", "fixture");
	gitIn(dir, "checkout", "-q", "-b", "feature");
	if (contracts) expectExit(contractsCli(dir, ["enable"]), 0, "contracts enable");
	if (preset) expectExit(cli(dir, ["set", preset, "--apply"]), 0, `select ${preset}`);
	return dir;
}
const contractsCli = (dir, args, env = {}) => spawnSync(process.execPath, [path.join(dir, "ai-factory/make/contracts.js"), ...args], { cwd: dir, env: { ...bare, ...env }, encoding: "utf8" });
const hostEnv = (dir, extra) => ({ ...bare, TOOL: "claude", CMD: path.join(dir, "ai-factory/fake-cli"), MODEL: "", INPUT: "", INPUT_FILE: "", REVIEW_SCOPE: "", ...extra });
const runner = (dir, action, extra = {}) => spawnSync(process.execPath, [path.join(dir, "ai-factory/make/runner.js"), action], { cwd: dir, env: hostEnv(dir, extra), encoding: "utf8" });
const gate = (dir, file, extra = {}) => spawnSync(process.execPath, [path.join(dir, "ai-factory/make/gate.js"), file], { cwd: dir, env: { ...bare, ...extra }, encoding: "utf8" });
const launches = (dir) => (exists(dir, "ai-factory/capture.jsonl") ? readText(dir, "ai-factory/capture.jsonl").trim().split("\n").filter(Boolean).length : 0);
const tickStep = (dir, step) => write(dir, PLAN, readText(dir, PLAN).replace(new RegExp(`^- \\[.\\] \\*\\*Step ${step} `, "m"), `- [x] **Step ${step} `));
const touch = (dir, file, note) => write(dir, file, `${readText(dir, file)}// ${note}\n`);
// A finished delivery: every step (or checklist item) done with passing recorded verification.
function delivery(dir, kind = "planned") {
	touch(dir, kind === "planned" ? "src/export.js" : "src/footer.js", "delivered change");
	if (kind === "quick") {
		expectExit(contractsCli(dir, ["init", "quick", QUICK]), 0, "init quick");
		const id = readJson(dir, "ai-factory/quick/fix-date-format.contract.json").delivery_id;
		write(dir, QUICK, readText(dir, QUICK).replace(/- \[ \]/g, "- [x]"));
		expectExit(contractsCli(dir, ["record", "--delivery", id]), 0, "quick verify");
		return id;
	}
	expectExit(contractsCli(dir, ["init", "spec", SPEC]), 0, "init spec");
	expectExit(contractsCli(dir, ["init", "plan", PLAN, "--spec", SPEC]), 0, "init plan");
	const id = readJson(dir, "ai-factory/specs/0001-csv-export.contract.json").delivery_id;
	for (const step of [1, 2, 3]) {
		expectExit(contractsCli(dir, ["record", "--delivery", id, "--step", `S${step}`]), 0, `verify S${step}`);
		tickStep(dir, step);
	}
	expectExit(contractsCli(dir, ["record", "--delivery", id, "--phase", "final"]), 0, "final verify");
	return id;
}
// An approval recorded without the headless review boundary: the caller reviewed its own work.
function selfReview(dir, id) {
	const { recordReview } = require(path.join(dir, "ai-factory/make/contracts.js"));
	recordReview({ root: dir, delivery: id, approved: true, verdict: "approve", findings: [], tool: "claude", outputHash: "0".repeat(64) });
}
function reportOf(dir, id, env = {}) {
	const result = spawnSync(process.execPath, [path.join(dir, "ai-factory/make/delivery-report.js"), id, "--json"], { cwd: dir, env: { ...bare, ...env }, encoding: "utf8" });
	assert.ok([0, 1].includes(result.status), `delivery-report exits 0/1\nstdout:${result.stdout}\nstderr:${result.stderr}`);
	return JSON.parse(result.stdout);
}
function completion(dir, id, env, status) {
	const result = expectExit(cli(dir, ["complete", id, "--json"], env), status, `complete ${id}`);
	const value = jsonOf(result);
	assert.equal(value.claimable, status === 0, "exit 0 exactly when completion may be claimed");
	return value;
}
const reasonCodes = (value) => (value.reasons || value.open).map((item) => item.code);
const reviewFile = (id) => `ai-factory/evidence/${id}/review.json`;

check("runtime", "standard-advisory-not-approval", () => {
	const dir = workspace("planned", { preset: "standard" });
	// A weaker custom setting stays on disk; the preset's minimum applies on top of it.
	writeJson(dir, CONFIG_FILE, { ...readJson(dir, CONFIG_FILE), completion: { require_review: false } });
	const id = delivery(dir);
	let value = reportOf(dir, id);
	assert.equal(value.assurance?.preset, "standard", "the report names the preset it applied");
	assert.equal(value.review.required, true, "standard requires review over a weaker configuration");
	assert.equal(value.policy.require_review, true, "the report shows the effective completion policy");
	assert.notEqual(value.status, "ready", "no review recorded: not ready");
	assert.deepEqual(readJson(dir, CONFIG_FILE).completion, { require_review: false }, "the custom configuration is not rewritten");
	// An approval recorded outside the review boundary is not independent review.
	selfReview(dir, id);
	value = reportOf(dir, id);
	assert.equal(value.review.independence, "unspecified");
	assert.ok(reasonCodes(value).includes("REVIEW_NOT_INDEPENDENT"), `self-review never counts: ${reasonCodes(value)}`);
	assert.notEqual(value.status, "ready");
	completion(dir, id, {}, 1);
	// The advisory gate exits zero on a rejection and says that is not approval.
	const rejected = expectExit(runner(dir, "review", { DELIVERY: id, FAKE_VERDICT: "request_changes" }), 0, "advisory rejection");
	assert.match(rejected.stderr, /assurance: preset standard — active: .*review_independence=independent .*gate=advisory/);
	assert.match(rejected.stdout, /gate: advisory \(preset standard\) — approval requirements not met; an advisory exit is not approval/);
	assert.equal(readJson(dir, reviewFile(id)).status, "failed");
	value = reportOf(dir, id);
	assert.notEqual(value.status, "ready", "an advisory exit 0 is not approval");
	assert.ok(reasonCodes(value).includes("REVIEW_CHANGES"));
	const refused = completion(dir, id, {}, 1);
	assert.equal(refused.requirement, "recorded_checks");
	assert.ok(refused.open.some((item) => item.code === "REVIEW_CHANGES"));
	// An approving independent review satisfies standard; no report has to be saved.
	expectExit(runner(dir, "review", { DELIVERY: id }), 0, "approving review");
	const record = readJson(dir, reviewFile(id));
	assert.equal(record.review.independence, "independent");
	assert.equal(record.review.boundary, "make review");
	// The saved report from the earlier rejection is neither read nor rewritten.
	const saved = readText(dir, `ai-factory/reports/${id}/completion.json`);
	assert.equal(JSON.parse(saved).status === "ready", false);
	const done = completion(dir, id, {}, 0);
	assert.equal(done.report_status, "ready");
	assert.deepEqual(done.written, [], "standard neither needs nor writes a saved report");
	assert.equal(readText(dir, `ai-factory/reports/${id}/completion.json`), saved);
});

check("runtime", "strict-enforced", () => {
	const dir = workspace("planned", { preset: "strict" });
	const id = delivery(dir);
	// Missing review: completion is refused.
	let refused = completion(dir, id, {}, 1);
	assert.ok(refused.open.some((item) => String(item.evidence_ref).endsWith("review.json")), `missing review is reported: ${reasonCodes(refused)}`);
	// Strict enforces the gate without GATE_ENFORCE: a rejection fails the review command.
	const rejected = runner(dir, "review", { DELIVERY: id, FAKE_VERDICT: "request_changes" });
	assert.notEqual(rejected.status, 0, "strict enforces the review gate");
	assert.match(rejected.stderr, /gate: enforced \(preset strict\) — approval requirements not met/);
	assert.equal(readJson(dir, reviewFile(id)).status, "failed", "the enforced failure is still recorded");
	refused = completion(dir, id, {}, 1);
	assert.ok(reasonCodes(refused).includes("REVIEW_CHANGES"));
	// The gate entry point applies the same rule.
	const output = path.join(dir, "ai-factory/review-output.json");
	fs.writeFileSync(output, JSON.stringify({ result: JSON.stringify({ verdict: "request_changes", findings: [], summary: "x" }) }));
	expectExit(gate(dir, output), 1, "gate under strict without GATE_ENFORCE");
	fs.writeFileSync(output, JSON.stringify({ result: JSON.stringify({ verdict: "approve", findings: [], summary: "x" }) }));
	expectExit(gate(dir, output, { GATE_ENFORCE: "1" }), 0, "stricter GATE_ENFORCE=1 is allowed");
	assert.match(expectExit(gate(dir, output, { GATE_ENFORCE: "0" }), 2, "gate conflict").stderr, /E_GATE_CONFLICT/);
	// GATE_ENFORCE=0 conflicts with strict and stops before any host runs, for reviews and tasks.
	const before = launches(dir);
	const conflict = runner(dir, "review", { DELIVERY: id, GATE_ENFORCE: "0" });
	assert.notEqual(conflict.status, 0);
	assert.match(conflict.stderr, /E_GATE_CONFLICT/);
	assert.match(conflict.stderr, /nothing was launched/);
	const task = runner(dir, "ai", { TASK: "quick", INPUT: "edit the footer", GATE_ENFORCE: "0" });
	assert.notEqual(task.status, 0);
	assert.match(task.stderr, /E_GATE_CONFLICT/);
	assert.equal(launches(dir), before, "no host was invoked under a conflicting configuration");
	const conflicted = completion(dir, id, { GATE_ENFORCE: "0" }, 1);
	assert.equal(conflicted.status, "conflict");
	assert.ok(reasonCodes(conflicted).includes("E_GATE_CONFLICT"));
	// An approving review completes; a later change makes it stale and completion is refused again.
	expectExit(runner(dir, "review", { DELIVERY: id }), 0, "enforced approval");
	assert.equal(completion(dir, id, {}, 0).report_status, "ready");
	touch(dir, "src/export.js", "after review");
	expectExit(contractsCli(dir, ["record", "--delivery", id, "--phase", "final"]), 0, "final verify again");
	refused = completion(dir, id, {}, 1);
	assert.ok(reasonCodes(refused).includes("REVIEW_STALE"), `stale review: ${reasonCodes(refused)}`);
	// A blocking finding is rejected too.
	assert.notEqual(runner(dir, "review", { DELIVERY: id, FAKE_BLOCKER: "1" }).status, 0);
	assert.ok(reasonCodes(completion(dir, id, {}, 1)).includes("REVIEW_BLOCKER"));
});

check("runtime", "quick-review-required", () => {
	const dir = workspace("quick", { preset: "standard" });
	const id = delivery(dir, "quick");
	let value = reportOf(dir, id);
	assert.equal(value.delivery.kind, "quick");
	assert.equal(value.review.required, true, "standard requires independent review for quick deliveries too");
	assert.equal(value.policy.require_review_quick, true);
	assert.notEqual(value.status, "ready", "quick work is not complete without review");
	completion(dir, id, {}, 1);
	selfReview(dir, id);
	value = reportOf(dir, id);
	assert.ok(reasonCodes(value).includes("REVIEW_NOT_INDEPENDENT"), "quick self-review cannot claim completion");
	completion(dir, id, {}, 1);
	expectExit(runner(dir, "review", { DELIVERY: id }), 0, "independent quick review");
	assert.equal(readJson(dir, reviewFile(id)).review.independence, "independent");
	value = reportOf(dir, id);
	assert.equal(value.status, "ready", JSON.stringify(value.reasons));
	assert.equal(value.review.independence, "independent");
	assert.equal(completion(dir, id, {}, 0).report_status, "ready");
	// Light keeps the configured quick policy: an unreviewed quick delivery may complete.
	const light = workspace("quick", { preset: "light", contracts: true });
	const lightId = delivery(light, "quick");
	value = reportOf(light, lightId);
	assert.equal(value.review.required, false);
	assert.equal(value.status, "ready", JSON.stringify(value.reasons));
	assert.equal(completion(light, lightId, {}, 0).requirement, "recorded_checks", "light retains the contracts completion requirement");
});

check("runtime", "fresh-ready-no-recursion", () => {
	const dir = workspace("planned", { preset: "strict" });
	const id = delivery(dir);
	expectExit(runner(dir, "review", { DELIVERY: id }), 0, "approving review");
	assert.ok(!exists(dir, "ai-factory/reports"), "no earlier report exists");
	// Readiness comes from current evidence; generating it never requires a previous report.
	const first = completion(dir, id, {}, 0);
	assert.equal(first.requirement, "fresh_ready_report");
	assert.deepEqual([...first.written].sort(), [`ai-factory/reports/${id}/completion.json`, `ai-factory/reports/${id}/completion.md`]);
	const saved = readJson(dir, `ai-factory/reports/${id}/completion.json`);
	assert.equal(saved.status, "ready");
	assert.equal(saved.assurance.preset, "strict");
	assert.equal(saved.assurance.settings.completion.value, "fresh_ready_report");
	assert.deepEqual(saved.reasons.filter((item) => item.state !== "ready"), []);
	assert.match(readText(dir, `ai-factory/reports/${id}/completion.md`), /## Assurance[\s\S]*Preset \*\*strict\*\*/);
	// A cached ready report authorizes nothing: after a change the fresh report replaces it.
	touch(dir, "src/export.js", "after the report");
	const second = completion(dir, id, {}, 1);
	assert.notEqual(second.report_status, "ready");
	assert.notEqual(readJson(dir, `ai-factory/reports/${id}/completion.json`).status, "ready", "the stale ready report was replaced");
	// Even a forged ready report is never read.
	writeJson(dir, `ai-factory/reports/${id}/completion.json`, { ...saved, generated_at: "2000-01-01T00:00:00.000Z" });
	completion(dir, id, {}, 1);
	assert.notEqual(readJson(dir, `ai-factory/reports/${id}/completion.json`).generated_at, "2000-01-01T00:00:00.000Z");
	// A report made under one selection never matches evidence under another.
	const strictPrint = reportOf(dir, id).snapshot.fingerprint;
	expectExit(cli(dir, ["set", "standard", "--apply"]), 0, "switch to standard");
	assert.notEqual(reportOf(dir, id).snapshot.fingerprint, strictPrint, "the selection is part of the evidence fingerprint");
});

check("runtime", "missing-contract-drift", () => {
	const dir = workspace("planned", { preset: "standard" });
	const id = delivery(dir);
	expectExit(runner(dir, "review", { DELIVERY: id }), 0, "approving review");
	completion(dir, id, {}, 0);
	fs.rmSync(path.join(dir, CONFIG_FILE));
	// Headless tasks still run, and show the unmet requirement before the host starts.
	const task = expectExit(runner(dir, "ai", { TASK: "quick", INPUT: "edit the footer" }), 0, "task with drift");
	assert.match(task.stderr, /assurance: preset standard — incomplete:/);
	assert.match(task.stderr, /unmet U_CONTRACTS_NOT_ENABLED/);
	const refused = completion(dir, id, {}, 1);
	assert.equal(refused.status, "incomplete");
	assert.ok(reasonCodes(refused).includes("U_CONTRACTS_NOT_ENABLED"));
	const value = reportOf(dir, id);
	assert.equal(value.assurance.settings.contracts.value, false, "the report never claims contracts it does not have");
});

check("runtime", "report-readers", () => {
	const schema = JSON.parse(fs.readFileSync(REPORT_SCHEMA, "utf8"));
	assert.ok(!schema.required.includes("assurance"), "assurance is optional in report v1");
	const assuranceSchema = schema.properties.assurance;
	assert.ok(assuranceSchema && Array.isArray(assuranceSchema.required), "report v1 documents the optional assurance field");
	// Legacy (old) report: no assurance field, configured policy, unchanged readiness.
	const legacy = workspace("planned");
	const legacyId = delivery(legacy);
	selfReview(legacy, legacyId);
	const old = reportOf(legacy, legacyId);
	assert.equal(old.status, "ready", "without a preset any recorded approval still counts, as before");
	assert.ok(!Object.hasOwn(old, "assurance"), "legacy reports carry no assurance field");
	assert.deepEqual(old.policy, { require_review: true, require_review_quick: false, blocking_severities: ["blocker"], allow_attestation: false });
	for (const key of schema.required) assert.ok(Object.hasOwn(old, key), `old report has ${key}`);
	assert.doesNotMatch(readText(legacy, `ai-factory/reports/${legacyId}/completion.md`), /## Assurance/);
	// New report: the optional field matches the schema; every required field is still present.
	const dir = workspace("planned", { preset: "standard" });
	const id = delivery(dir);
	expectExit(runner(dir, "review", { DELIVERY: id }), 0, "approving review");
	const fresh = reportOf(dir, id);
	assert.equal(fresh.status, "ready", JSON.stringify(fresh.reasons));
	assert.ok(fresh.assurance && typeof fresh.assurance === "object", "a report made under a preset carries the assurance field");
	for (const key of schema.required) assert.ok(Object.hasOwn(fresh, key), `new report has ${key}`);
	for (const key of assuranceSchema.required) assert.ok(Object.hasOwn(fresh.assurance, key), `assurance has ${key}`);
	assert.equal(fresh.assurance.schema, "t4-assurance-policy");
	assert.ok(assuranceSchema.properties.status.enum.includes(fresh.assurance.status));
	// Existing readers accept the new field: continuation sees the saved report, status reads it.
	const { inspect } = require(path.join(dir, "ai-factory/make/continue.js"));
	assert.equal(inspect({ root: dir, delivery: id, answers: { gaps_tested: true } }).outcome, "complete");
	expectExit(spawnSync(process.execPath, [path.join(dir, "ai-factory/make/delivery-status.js"), id], { cwd: dir, env: bare, encoding: "utf8" }), 0, "delivery-status");
});

check("runtime", "legacy-runtime-unchanged", () => {
	const dir = workspace("planned");
	const id = delivery(dir);
	const rejected = expectExit(runner(dir, "review", { DELIVERY: id, FAKE_VERDICT: "request_changes" }), 0, "legacy advisory rejection");
	assert.match(rejected.stdout, /^gate: advisory — approval requirements not met$/m, "legacy gate text is unchanged");
	assert.doesNotMatch(rejected.stdout + rejected.stderr, /assurance:|preset/);
	expectExit(runner(dir, "review", { DELIVERY: id, GATE_ENFORCE: "0" }), 0, "GATE_ENFORCE=0 keeps its meaning without a preset");
	const enforced = runner(dir, "review", { DELIVERY: id, GATE_ENFORCE: "1", FAKE_VERDICT: "request_changes" });
	assert.notEqual(enforced.status, 0, "GATE_ENFORCE=1 still enforces");
	assert.match(enforced.stderr, /^gate: enforced — approval requirements not met$/m);
	const task = expectExit(runner(dir, "ai", { TASK: "quick", INPUT: "edit" }), 0, "legacy task");
	assert.doesNotMatch(task.stderr, /assurance:/);
	const value = completion(dir, id, {}, 1);
	assert.equal(value.mode, "legacy");
	assert.equal(value.preset, null);
	assert.deepEqual(value.written, []);
	assert.ok(!exists(dir, "ai-factory/assurance.json"), "nothing selects a preset implicitly");
});

check("runtime", "missing-helper-with-selection", () => {
	const dir = workspace("planned", { preset: "standard" });
	const id = delivery(dir);
	fs.rmSync(path.join(dir, "ai-factory/make/assurance.js"));
	const output = path.join(dir, "ai-factory/review-output.json");
	fs.writeFileSync(output, JSON.stringify({ result: JSON.stringify({ verdict: "request_changes", findings: [], summary: "x" }) }));
	assert.match(expectExit(gate(dir, output), 2, "gate without the helper").stderr, /assurance\.js is missing/);
	const report = spawnSync(process.execPath, [path.join(dir, "ai-factory/make/delivery-report.js"), id], { cwd: dir, env: bare, encoding: "utf8" });
	assert.equal(report.status, 2, "a selection that cannot be read stops the report");
	assert.match(report.stderr, /assurance\.js is missing/);
	const before = launches(dir);
	assert.notEqual(runner(dir, "ai", { TASK: "quick", INPUT: "edit" }).status, 0);
	assert.equal(launches(dir), before, "no host runs while the selection cannot be applied");
});

// --- procedures (Step 3): task behavior, review coordination, risk routing and legacy ----------
// Wording is asserted only where it carries a requirement, and every command a procedure names is
// run as written. Whether a model follows the procedure is proved only by the paired host runs in
// skills/ai-layout/fixtures/assurance/cases.md, never by these checks.
const procedure = (name) => fs.readFileSync(path.join(TASKS, `${name}.md`), "utf8");
const agentText = (name) => fs.readFileSync(path.join(AGENTS, `${name}.md`), "utf8");
const CONSULT = "only when `ai-factory/assurance.json` exists";
const SHOW = "`node ai-factory/make/assurance.js show`";
const COMPLETE = "`node ai-factory/make/assurance.js complete <id>`";
const REVIEW = "`make -f ai-factory/make/ai.mk review DELIVERY=<id>`";
const NO_REVIEW_RUN = "Never run `make -f ai-factory/make/ai.mk review`";
const CLAIMING = ["quick", "fix", "chore"];
const CONSULTING = ["quick", "fix", "chore", "run", "check", "report"];
const ROLES = ["implementer", "reviewer"];
// Prompt lines wrap anywhere and sentences may start with a capital, so wording is compared with
// runs of whitespace collapsed and case folded.
const flat = (text) => text.replace(/\s+/g, " ").toLowerCase();
const says = (text, needle, what) => assert.ok(flat(text).includes(flat(needle)), `${what} does not say: ${needle}`);
// A command exactly as a procedure names it, with the delivery ID substituted; never a shell.
function named(dir, command, id, extra = {}) {
	const argv = command.slice(1, -1).replace("<id>", id).split(" ");
	return spawnSync(argv[0] === "node" ? process.execPath : argv[0], argv.slice(1), { cwd: dir, env: hostEnv(dir, extra), encoding: "utf8" });
}
const prompts = (dir) => (exists(dir, "ai-factory/capture.jsonl") ? readText(dir, "ai-factory/capture.jsonl").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line).input) : []);
const routedWorker = (dir, task) => {
	const models = require(path.join(dir, "ai-factory/make/models.js"));
	return models.workerInstructions(models.workerSpec(fs.realpathSync(dir), task));
};

check("procedures", "direct-policy-consult", () => {
	// Every task and role that verifies, reviews or completes work consults the effective settings,
	// and only when a preset is selected: legacy repositories read nothing new.
	for (const name of CONSULTING) {
		says(procedure(name), CONSULT, `tasks/${name}.md`);
		says(procedure(name), SHOW, `tasks/${name}.md`);
	}
	for (const name of ROLES) {
		says(agentText(name), CONSULT, `agents/${name}.md`);
		says(agentText(name), SHOW, `agents/${name}.md`);
		assert.ok(fs.readFileSync(path.join(TEMPLATE_AGENTS, `${name}.md`), "utf8").startsWith(agentText(name).trimEnd()), `templates agents/${name}.md delivers the canonical procedure`);
	}
	// A preset adds requirements; it never opens the shortcut route.
	says(procedure("quick"), "A preset only adds requirements: it never makes a request eligible for this route", "tasks/quick.md");
	// Direct commands, Codex skills and routed workers all carry out the same procedure file.
	const dir = workspace("quick", { preset: "standard", procedures: true });
	for (const name of CONSULTING) {
		assert.ok(fs.readFileSync(`commands/${name}.md`, "utf8").includes(`ai-factory/tasks/${name}.md`), `commands/${name}.md reads the task procedure`);
		assert.ok(fs.readFileSync(`codex-skills/t4-${name}/SKILL.md`, "utf8").includes(`ai-factory/tasks/${name}.md`), `t4-${name} reads the task procedure`);
		assert.ok(routedWorker(dir, name).includes(`Read \`ai-factory/tasks/${name}.md\``), `a routed ${name} worker reads the task procedure`);
	}
	// Headless: the runner shows the effective requirements, and the prompt is the procedure itself.
	const task = expectExit(runner(dir, "ai", { TASK: "quick", INPUT: "edit the footer" }), 0, "headless quick");
	assert.match(task.stderr, /assurance: preset standard — active: .*review_independence=independent/);
	const prompt = prompts(dir).at(-1);
	assert.equal(prompt, `${procedure("quick")}\n## Input\nedit the footer`, "the headless prompt is the canonical procedure");
	says(prompt, SHOW, "the headless quick prompt");
});

check("procedures", "standard-quick-independent", () => {
	for (const name of CLAIMING) {
		const text = procedure(name);
		says(text, "self-review never satisfies review", `tasks/${name}.md`);
		says(text, `only ${REVIEW} records independent review`, `tasks/${name}.md`);
		says(text, "A routed worker or a headless run never runs it", `tasks/${name}.md`);
		says(text, "reports review as an unmet requirement naming that command", `tasks/${name}.md`);
		says(text, `claim completion only when ${COMPLETE} exits 0`, `tasks/${name}.md`);
		says(text, "Never record review evidence another way", `tasks/${name}.md`);
	}
	// fix and chore have no delivery of their own; under a preset they record one as quick does.
	for (const name of ["fix", "chore"]) says(procedure(name), "record the acceptance checklist as a quick delivery", `tasks/${name}.md`);
	// The commands the procedures name behave as they say, on a standard quick delivery.
	const dir = workspace("quick", { preset: "standard", procedures: true });
	const id = delivery(dir, "quick");
	selfReview(dir, id);
	const refused = expectExit(named(dir, COMPLETE, id), 1, "completion after self-review");
	assert.match(refused.stdout, /may NOT be claimed/);
	assert.match(refused.stderr, /REVIEW_NOT_INDEPENDENT/, "quick self-review cannot claim completion");
	const reviewed = expectExit(named(dir, REVIEW, id), 0, "the named review command");
	assert.match(reviewed.stdout, /review evidence: passed/);
	const record = readJson(dir, reviewFile(id)).review;
	assert.deepEqual([record.independence, record.boundary], ["independent", "make review"]);
	assert.match(expectExit(named(dir, COMPLETE, id), 0, "completion after independent review").stdout, /may be claimed/);
	assert.ok(!exists(dir, `ai-factory/reports/${id}`), "standard completion writes no report");
});

check("procedures", "strict-final-report", () => {
	const report = procedure("report");
	says(report, COMPLETE, "tasks/report.md");
	says(report, "only that fresh report, `ready`, permits completion", "tasks/report.md");
	says(report, "an earlier saved report never counts", "tasks/report.md");
	for (const name of CLAIMING) says(procedure(name), "Under strict it writes the fresh report, which must be `ready`; an earlier report never counts", `tasks/${name}.md`);
	says(agentText("implementer"), "a ticked final step is not a completed delivery", "agents/implementer.md");
	// The completion command the procedures name generates the fresh report from current evidence.
	const dir = workspace("planned", { preset: "strict", procedures: true });
	const id = delivery(dir);
	expectExit(named(dir, REVIEW, id), 0, "the named review command");
	const done = expectExit(named(dir, COMPLETE, id), 0, "strict completion");
	assert.match(done.stdout, /freshly generated: ai-factory\/reports\//);
	assert.equal(readJson(dir, `ai-factory/reports/${id}/completion.json`).status, "ready");
	touch(dir, "src/export.js", "after the report");
	expectExit(named(dir, COMPLETE, id), 1, "strict completion after a change");
	assert.notEqual(readJson(dir, `ai-factory/reports/${id}/completion.json`).status, "ready", "the earlier ready report was replaced, not trusted");
});

check("procedures", "worker-no-redispatch", () => {
	// Routed workers keep their prohibition on dispatch and delegation for every consulting task.
	const dir = workspace("quick", { preset: "strict", procedures: true });
	for (const name of CONSULTING)
		assert.match(routedWorker(dir, name), /Do not run `models\.js dispatch`, and never hand this task to another agent or back to the session\./, `${name} worker`);
	const models = require(path.join(dir, "ai-factory/make/models.js"));
	assert.equal(models.workerSpec(fs.realpathSync(dir), "check").readOnly, true, "the review worker stays read-only");
	// Independent-review coordination stays outside routed workers, the reviewer and the review run.
	for (const name of CLAIMING) says(procedure(name), "A routed worker or a headless run never runs it", `tasks/${name}.md`);
	says(procedure("check"), NO_REVIEW_RUN, "tasks/check.md");
	for (const name of ROLES) says(agentText(name), NO_REVIEW_RUN, `agents/${name}.md`);
	for (const text of [...CONSULTING.map(procedure), ...ROLES.map(agentText)])
		assert.doesNotMatch(text, /models\.js dispatch/, "no procedure tells a worker to dispatch");
});

check("procedures", "unavailable-coordination-unmet", () => {
	// When the review boundary cannot run, nothing records approval and the gate stays unmet.
	const dir = workspace("quick", { preset: "standard", procedures: true });
	const id = delivery(dir, "quick");
	const failed = runner(dir, "review", { DELIVERY: id, CMD: path.join(dir, "ai-factory/no-such-cli") });
	assert.notEqual(failed.status, 0, "an unavailable review host fails the review command");
	assert.ok(!exists(dir, reviewFile(id)), "an unavailable boundary records no review");
	const refused = completion(dir, id, {}, 1);
	assert.ok(refused.open.some((item) => String(item.evidence_ref).endsWith("review.json")), `unmet review is reported: ${reasonCodes(refused)}`);
	// A worker's own review in place of the boundary is still unmet.
	selfReview(dir, id);
	assert.ok(reasonCodes(completion(dir, id, {}, 1)).includes("REVIEW_NOT_INDEPENDENT"));
});

check("procedures", "risk-routing-retained", () => {
	// Control: the normal-workflow triggers stand in the procedures, and no preset touches routing.
	assert.match(procedure("quick"), /If requirements\s+are uncertain, or the change affects authorization, public contracts, migrations, dependencies\s+or service ownership, preserve current work and name the decision needing the normal workflow\./);
	assert.match(procedure("start"), /Apply risk before size: uncertain requirements, authorization, public contracts, migrations,\s+dependencies or service ownership require normal planned work\./);
	assert.doesNotMatch(procedure("start"), /assurance|preset/i, "classification never reads the preset");
	for (const [name, requirement] of Object.entries(helper().PRESETS))
		assert.deepEqual(Object.keys(requirement).filter((key) => /route|routing|workflow|risk|shortcut/.test(key)), [], `${name} sets no routing requirement`);
	const dir = workspace("quick", { preset: "light", contracts: true, procedures: true });
	const start = runner(dir, "ai", { TASK: "start", INPUT: "add an authorization check" });
	assert.notEqual(start.status, 0);
	assert.match(start.stderr, /TASK=start requires an interactive session/);
	assert.equal(launches(dir), 0, "light launches no shortcut classification headless");
});

check("procedures", "legacy-procedures-unchanged", () => {
	// Control: adoption never selects a preset, and a legacy run reads and prints nothing new.
	const { adopt } = require(path.resolve("skills/ai-layout/scripts/adopt.js"));
	const repo = path.join(base, `adopted${++projects}`);
	fs.mkdirSync(repo);
	adopt(repo, process.cwd(), "Fixture Owner");
	assert.ok(exists(repo, "ai-factory/make/assurance.js"), "adoption delivers the helper");
	assert.ok(!exists(repo, "ai-factory/assurance.json"), "adoption never selects a preset");
	assert.equal(show(repo).mode, "legacy");
	const dir = workspace("quick", { procedures: true });
	const task = expectExit(runner(dir, "ai", { TASK: "quick", INPUT: "edit" }), 0, "legacy headless quick");
	assert.doesNotMatch(task.stderr, /assurance:/);
	assert.equal(prompts(dir).at(-1), `${procedure("quick")}\n## Input\nedit`);
	says(procedure("quick"), "Clearly call this a self-review", "tasks/quick.md");
	says(procedure("quick"), "never imply independence", "tasks/quick.md");
	says(procedure("check"), "An in-session review is a self-check, not an independent opinion.", "tasks/check.md");
	assert.ok(!exists(dir, "ai-factory/assurance.json"));
});

check("procedures", "host-cases", () => {
	// The paired host runs this group cannot replace are named, with what each must show.
	const cases = fs.readFileSync("skills/ai-layout/fixtures/assurance/cases.md", "utf8");
	for (const id of ["unset-local-edit", "light-risk-route", "standard-quick", "strict-rejected-review", "strict-ready"])
		assert.match(cases, new RegExp(`^\\| ${id} \\|`, "m"), `cases.md names the required scenario ${id}`);
	assert.match(cases, /must never be reported as one/, "static checks are never reported as host runs");
});

// --- docs (Step 4): the documentation matches what ships -------------------------------------
// Document checks only: every documented helper command runs as written, the documented preset
// table and diagnostic codes match the shipped helpers, and each documented limitation is still
// the current behavior (fixing one fails here until the documentation is updated). None of this
// is evidence that a model follows the procedures.
const DOCS = {
	readme: "README.md",
	contracts: "skills/ai-layout/templates/ai-factory/contracts/README.md",
	changelog: "CHANGELOG.md",
	skill: "skills/ai-layout/SKILL.md",
};
const doc = (name) => fs.readFileSync(DOCS[name], "utf8");
// The 0021 entry only: from its heading to the next unreleased or released heading.
const changelogEntry = () => {
	const text = doc("changelog");
	const start = text.indexOf("**Unreleased — plan 0021 assurance presets");
	assert.ok(start >= 0, "CHANGELOG.md has no plan 0021 entry");
	const next = text.slice(start + 1).search(/^\*\*(Unreleased|\d)/m);
	return next < 0 ? text.slice(start) : text.slice(start, start + 1 + next);
};
const fenced = (text) => [...text.matchAll(/^```[a-z]*\n([\s\S]*?)^```/gm)].map((match) => match[1]).join("\n");

check("docs", "docs-commands-run", () => {
	const dir = workspace("planned");
	const id = delivery(dir);
	const commands = [];
	for (const name of ["readme", "contracts"])
		for (const line of fenced(doc(name)).split("\n"))
			if (line.startsWith("node ai-factory/make/assurance.js ")) commands.push([name, line.replace(/\s+#.*$/, "").trim()]);
	assert.ok(commands.length >= 8, `expected the documented assurance commands, found ${commands.length}`);
	const used = new Set();
	for (const [name, command] of commands) {
		const argv = command
			.replace(/<delivery id>|<id>/g, id)
			.replace(/light\|standard\|strict|<preset>/g, "standard")
			.replace(/\s*\[--json\]/g, "")
			.split(/\s+/)
			.slice(2);
		used.add(argv[0]);
		const result = cli(dir, argv);
		assert.ok([0, 1].includes(result.status), `${DOCS[name]}: \`${command}\` exits ${result.status}: ${result.stderr.trim()}`);
		assert.doesNotMatch(result.stderr, /usage:|invalid argument|takes/, `${DOCS[name]}: \`${command}\` is not a valid invocation`);
	}
	assert.deepEqual([...used].sort(), ["complete", "set", "show"], "the docs show every helper command");
	assert.equal(readJson(dir, "ai-factory/assurance.json").preset, "standard", "the documented --apply command selects the preset");
});

check("docs", "docs-preset-table", () => {
	const presets = helper().PRESETS;
	const names = ["light", "standard", "strict"];
	const rows = {};
	for (const line of doc("contracts").split("\n")) {
		const cells = line.split("|").slice(1, -1).map((cell) => cell.trim());
		if (cells.length === 4 && /^`[a-z_]+`/.test(cells[0])) for (const key of cells[0].match(/`([a-z_]+)`/g)) rows[key.slice(1, -1)] = cells.slice(1);
	}
	for (const key of ["contracts", "final_verification"])
		names.forEach((name, i) => assert.equal(rows[key]?.[i], presets[name][key] ? "required" : "not required", `contracts README: ${key} for ${name}`));
	for (const key of ["review_required", "review_required_quick"])
		names.forEach((name, i) => assert.ok(rows[key]?.[i]?.startsWith(presets[name][key] ? "yes" : "no"), `contracts README: ${key} for ${name}`));
	for (const key of ["review_independence", "gate", "completion"])
		names.forEach((name, i) => assert.ok(rows[key]?.[i]?.includes(presets[name][key]), `contracts README: ${key} for ${name} is ${presets[name][key]}`));
	names.forEach((name, i) => assert.equal(rows.blocking_severities?.[i]?.includes("`blocker`"), presets[name].blocking_severities.includes("blocker"), `contracts README: blocking_severities for ${name}`));
	// The README's summary table agrees on the gate and the review independence.
	const gateRow = doc("readme").split("\n").find((line) => line.startsWith("| Review gate |"));
	assert.deepEqual(gateRow?.split("|").slice(2, -1).map((cell) => cell.trim()), names.map((name) => presets[name].gate), "README review gate row");
});

check("docs", "docs-codes-and-claims", () => {
	const sources = ["assurance.js", "delivery-report.js", "gate.js", "contracts.js"].map((file) => fs.readFileSync(path.join(MAKE, file), "utf8")).join("\n");
	for (const code of ["U_CONTRACTS_NOT_ENABLED", "E_GATE_CONFLICT", "E_GATE_INVALID", "REVIEW_NOT_INDEPENDENT"]) {
		assert.ok(sources.includes(code), `${code} is documented but not produced by make/`);
		says(doc("contracts"), code, DOCS.contracts);
	}
	for (const [name, text] of [["readme", doc("readme")], ["contracts", doc("contracts")], ["changelog", changelogEntry()]]) {
		says(text, "is not approval", DOCS[name]);
		says(text, "a label, not proof", DOCS[name]);
		// The contracts README abbreviates `make -f ai-factory/make/ai.mk` to `make`, as it says.
		says(text, name === "contracts" ? "make review DELIVERY=<id>" : "make -f ai-factory/make/ai.mk review DELIVERY=<id>", DOCS[name]);
		assert.match(flat(text), /continue.{0,40}saved (completion )?report/, `${DOCS[name]} documents that continue still requires a saved report`);
		assert.match(flat(text), /(claude code|host).{0,80}(unverified|not (been )?exercised)|(unverified|not (been )?exercised).{0,80}(claude code|host)/, `${DOCS[name]} documents that host behavior is unverified`);
	}
	says(changelogEntry(), "Template upgrade impact", DOCS.changelog);
	says(changelogEntry(), "make/assurance.js", DOCS.changelog);
	says(changelogEntry(), "Adoption and sync never create a selection", DOCS.changelog);
	says(doc("contracts"), "reviewable design", DOCS.contracts);
	says(doc("readme"), "reviewable defaults", DOCS.readme);
});

check("docs", "docs-limitations-current", () => {
	// Provenance is a label: any caller of recordReview() can record "independent".
	const dir = workspace("quick", { preset: "standard" });
	const id = delivery(dir, "quick");
	const { recordReview } = require(path.join(dir, "ai-factory/make/contracts.js"));
	recordReview({ root: dir, delivery: id, approved: true, verdict: "approve", findings: [], tool: "claude", outputHash: "0".repeat(64), independence: "independent", boundary: "not make review" });
	assert.equal(readJson(dir, reviewFile(id)).review.independence, "independent", "documented limitation: recordReview() accepts independence from any caller");
	// continue.js still wants a saved report under standard, where assurance.js complete does not.
	const planned = workspace("planned", { preset: "standard" });
	const pid = delivery(planned);
	expectExit(named(planned, REVIEW, pid), 0, "independent review");
	assert.equal(completion(planned, pid, {}, 0).written.length, 0, "standard completion writes no report");
	const inspected = spawnSync(process.execPath, [path.join(planned, "ai-factory/make/continue.js"), pid, "--answer", "gaps_tested=yes"], { cwd: planned, env: bare, encoding: "utf8" });
	const result = JSON.parse(inspected.stdout);
	assert.equal(result.outcome, "action", `documented limitation: continue is not complete without a saved report (${inspected.stdout.trim().slice(0, 300)})`);
	assert.equal(result.task, "report", "documented limitation: continue hands off to report first");
});

check("docs", "docs-skill-lists-helpers", () => {
	const skill = doc("skill");
	for (const file of fs.readdirSync(MAKE).filter((name) => /\.(js|sh|mk)$/.test(name)))
		assert.match(skill, new RegExp(`(^|[\\s/])${file.replace(/\./g, "\\.")}(\\s|$)`, "m"), `skills/ai-layout/SKILL.md does not list make/${file}`);
	says(skill, "ai-factory/assurance.json", DOCS.skill);
});

const missing = GROUPS.filter((name) => want(name) && !ran.has(name));
for (const name of missing) console.error(`FAIL ${name}: no cases implemented for this group yet`);
if (passed.length) console.log(`PASS: ${passed.join(", ")}`);
fs.rmSync(base, { recursive: true, force: true });
if (failed.length || missing.length) {
	if (failed.length) console.error(`FAIL: ${failed.join(", ")}`);
	process.exit(1);
}
NODE
