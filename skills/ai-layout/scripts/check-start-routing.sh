#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -eq 0 ]; then
  for group in dispatch entry headless; do bash "$0" "$group"; done
  exit 0
fi
cd "$(dirname "$0")/../../.."
node - "${1:-dispatch}" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const template = path.resolve("skills/ai-layout/templates/ai-factory");
const m = require(path.join(template, "make/models.js"));
const group = process.argv[2];
assert.ok(["dispatch", "entry", "headless"].includes(group), "unknown test group");
const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "t4-start-")));
const failures = [];
function check(name, fn) { try { fn(); console.log(`PASS ${name}`); } catch (e) { failures.push(name); console.error(`FAIL ${name}: ${e.message}`); } }
try {
 if (group === "headless") {
  fs.cpSync(template, path.join(root, "ai-factory"), { recursive: true });
  fs.rmSync(path.join(root, "ai-factory/runs"), { recursive: true, force: true });
  const fake = path.join(root, "fake-host");
  fs.writeFileSync(fake, `#!/usr/bin/env node
const fs = require('node:fs');
fs.appendFileSync('launched', process.env.TOOL + '\\n');
process.stdin.resume();
process.stdin.on('end', () => {
 const args = process.argv.slice(2);
 if(args.includes('-o')) fs.writeFileSync(args[args.indexOf('-o')+1], 'done');
 process.stdout.write(JSON.stringify({session_id:'fixture',result:'done'}));
});
`, { mode: 0o700 });
  const invoke = (host, task) => spawnSync(process.execPath, [path.join(root, "ai-factory/make/runner.js"), "ai"], { cwd: root, encoding: "utf8", env: { ...process.env, TOOL: host, TASK: task, CMD: fake, INPUT: "fixture", INPUT_FILE: "", MODEL: "", CLAUDE_CODE_SUBAGENT_MODEL: "" } });
  check("headless-start-refused-before-launch", () => {
   for (const host of m.TOOLS) {
    const result = invoke(host, "start");
    assert.notEqual(result.status, 0, result.stdout);
    assert.match(result.stderr, /interactive.*destination task/s);
    assert.equal(fs.existsSync(path.join(root, "launched")), false);
    assert.equal(fs.existsSync(path.join(root, "ai-factory/runs")), false);
   }
  });
  check("headless-direct-task-control", () => {
   for (const host of m.TOOLS) {
    const before = fs.existsSync(path.join(root, "launched")) ? fs.readFileSync(path.join(root, "launched"), "utf8") : "";
    const result = invoke(host, "quick");
    assert.equal(result.status, 0, result.stderr);
    assert.equal(fs.readFileSync(path.join(root, "launched"), "utf8"), before + host + "\n");
   }
  });
 } else if (group === "entry") {
  const entries = m.TOOLS.map(host => ({ host, file: host === "claude" ? "commands/start.md" : "codex-skills/t4-start/SKILL.md" }));
  const read = file => fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";
  check("start-wrapper-handoff", () => {
   for (const { host, file } of entries) {
    const text = read(file);
    assert.match(text, /validate-start/, file);
    assert.match(text, /exactly one destination dispatch/, file);
    assert.match(text, /empty.*ask.*stop/is, file);
    assert.match(text, /missing.*adoption.*drift/is, file);
    assert.match(text, /Do not generate project adapters/, file);
    assert.ok(text.includes(`dispatch --host ${host} --task start`));
   }
  });
  check("original-input-preserved", () => {
   for (const { file } of entries) {
    const text = read(file);
    assert.match(text, /retained original input verbatim/);
    assert.match(text, /multiline.*quotes.*backticks.*leading flags/);
    assert.match(text, /clarification answers.*separately labeled/s);
    assert.match(text, /never interpolating it into shell code/);
   }
  });
  check("target-override-not-inherited", () => {
   for (const { file } of entries) {
    const text = read(file);
    assert.match(text, /Do not forward the start override or parse the retained input for options again/);
    assert.match(text, /Only after that directive succeeds/);
    assert.match(text, /no model fallback/);
   }
   for (const host of m.TOOLS) assert.doesNotMatch(m.entryPreamble(host, "quick"), /validate-start|retained original/);
  });
  check("direct-entries-unchanged", () => {
   const direct = [
    ...fs.readdirSync("commands").filter(f => f.endsWith(".md") && !["start.md", "continue.md"].includes(f)).map(f => ({ host: "claude", task: f.slice(0, -3), file: path.join("commands", f) })),
    ...fs.readdirSync("codex-skills").filter(d => d.startsWith("t4-") && !["t4-start", "t4-continue"].includes(d)).map(d => ({ host: "codex", task: d.slice(3), file: path.join("codex-skills", d, "SKILL.md") })),
   ].filter(({ file }) => read(file).includes("ai-factory/make/models.js dispatch"));
   assert.ok(direct.length >= 2 * 13, "expected routed direct entries on both hosts");
   for (const { host, task, file } of direct) {
    const text = read(file);
    assert.doesNotMatch(text, /validate-start|retained original input|destination dispatch|tasks\/start\.md/, file);
    assert.ok(text.includes(`dispatch --host ${host} --task ${task}\``), `${file} dispatches its own task`);
    assert.ok(text.includes(m.entryPreamble(host, task)), `${file} carries the unchanged shared preamble`);
   }
  });
 } else {
 fs.cpSync(template, path.join(root, "ai-factory"), { recursive: true });
 const yaml = path.join(root, "ai-factory/models.yaml");
 const config = enabled => fs.writeFileSync(yaml, `routing:\n  enabled: ${enabled}\n  tasks:\n    start:\n      claude: classifier\n      codex: classifier\n    quick:\n      claude: builder\n      codex: builder\n`);
 const dispatch = (host, task = "start", override) => m.dispatch({ root, host, task, override, env: {} });
 check("start-read-only", () => {
  const spec = m.workerSpec(root, "start");
  assert.equal(spec.tools, "Read, Grep, Glob"); assert.equal(spec.readOnly, true);
  for (const host of m.TOOLS) {
   const a = m.adapter(root, host, "start", "classifier");
   assert.match(a.instructions, /classification only/);
   assert.match(a.instructions, /never dispatch, delegate, or implement/);
   if (host === "codex") assert.match(a.body, /sandbox_mode = "read-only"/);
  }
 });
 check("start-result-validation", () => {
  for (const task of ["quick", "fix", "chore", "analyse", "design", "explore", "spec"]) assert.equal(m.validateStartResult({ status: "route", task, reason: "appropriate" }).task, task);
  for (const status of ["question", "blocked"]) assert.deepEqual(m.validateStartResult({ status, reason: "Need details" }), { status, reason: "Need details" });
  for (const value of [null, [], {}, { status: "route", task: "run", reason: "x" }, { status: "route", task: "../quick", reason: "x" }, { status: "question", task: "quick", reason: "x" }, { status: "route", task: "quick", reason: "" }, { status: "route", task: "quick", reason: "x", command: "touch pwned" }, { status: "route", task: "quick", reason: "x", model: "other" }, { status: "blocked", reason: "x".repeat(1001) }]) assert.throws(() => m.validateStartResult(value));
  const cli = input => spawnSync(process.execPath, [path.join(root, "ai-factory/make/models.js"), "validate-start"], { input, encoding: "utf8" });
  const good = cli('{"status":"route","task":"quick","reason":"local"}'); assert.equal(good.status, 0, good.stderr); assert.equal(JSON.parse(good.stdout).task, "quick");
  assert.notEqual(cli('{"status":"route","task":"run","reason":"x"}').status, 0);
  assert.notEqual(cli('not json').status, 0);
  assert.equal(fs.existsSync(path.join(root, "ai-factory/runs/routing.jsonl")), false);
 });
 check("start-session-handoff", () => {
  for (const host of m.TOOLS) {
   config(false); assert.match(m.directiveText(dispatch(host)), /validate-start/);
   assert.match(m.directiveText(dispatch(host, "start", "inherit")), /validate-start/);
   config(true);
   for (const task of ["start", "quick"]) { const a = m.adapter(root, host, task, task === "start" ? "classifier" : "builder"); fs.mkdirSync(path.dirname(path.join(root, a.file)), {recursive:true}); fs.writeFileSync(path.join(root, a.file), a.body); }
   assert.equal(dispatch(host, "start", "override").status, "blocked", "start override cannot use an unrestricted worker");
   assert.match(dispatch(host, "start", "override").reason, /native.*read-only/);
   for (const result of [dispatch(host)]) {
    const text = m.directiveText(result); assert.match(text, /validate-start/); assert.match(text, /exactly one destination dispatch/); assert.match(text, /fails.*no destination/s); assert.doesNotMatch(text, /Relay the worker's final report unchanged/); assert.match(text, /record --dispatch/); if (host === "codex") { assert.match(text, /exec_command.*read-only/); assert.doesNotMatch(text, /only Read, Grep and Glob/); } else assert.match(text, /only Read, Grep and Glob/); assert.match(text, result.strategy === "native-agent" ? /unknown/ : /rejects/);
   }
   const a = m.adapter(root, host, "start", "classifier"); fs.writeFileSync(path.join(root, a.file), "stale"); assert.equal(dispatch(host).status, "blocked"); fs.unlinkSync(path.join(root, a.file)); assert.equal(dispatch(host).status, "blocked");
  }
 });
 check("destination-model-independent", () => {
  config(true);
  for (const host of m.TOOLS) { assert.equal(dispatch(host, "start", "override").requested_model, "override"); assert.equal(dispatch(host, "quick").requested_model, "builder"); }
 });
 check("other-workers-unchanged", () => {
  const spec = m.workerSpec(root, "quick"); assert.equal(spec.readOnly, false); assert.match(m.workerInstructions(spec), /never hand this task to another agent or back to the session/);
  for (const host of m.TOOLS) assert.match(m.directiveText(dispatch(host, "quick", "builder")), /Relay the worker's final report unchanged/);
 });
}
} finally { fs.rmSync(root, { recursive: true, force: true }); }
if (failures.length) process.exitCode = 1;
NODE
