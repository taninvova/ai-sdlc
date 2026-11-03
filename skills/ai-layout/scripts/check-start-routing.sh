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
const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "fc-start-")));
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
  const entries = m.TOOLS.map(host => ({ host, file: host === "claude" ? "commands/start.md" : "codex-skills/fc-start/SKILL.md" }));
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
    ...fs.readdirSync("codex-skills").filter(d => d.startsWith("fc-") && !["fc-start", "fc-continue"].includes(d)).map(d => ({ host: "codex", task: d.slice(3), file: path.join("codex-skills", d, "SKILL.md") })),
   ].filter(({ file }) => read(file).includes("ai-factory/make/models.js dispatch"));
   assert.ok(direct.length >= 2 * 13, "expected routed direct entries on both hosts");
   for (const { host, task: entry, file } of direct) {
    const text = read(file);
    // A deprecated entry (/fc:check, $fc-check) dispatches the task it now names, and says so first.
    const task = m.canonicalTask(entry);
    if (task !== entry) assert.ok(text.includes(m.aliasNotice(host, entry)), `${file} does not say it is deprecated`);
    assert.doesNotMatch(text, /validate-start|retained original input|destination dispatch|tasks\/start\.md/, file);
    assert.ok(text.includes(`dispatch --host ${host} --task ${task}\``), `${file} dispatches its own task`);
    assert.ok(text.includes(m.entryPreamble(host, task)), `${file} carries the unchanged shared preamble`);
   }
   assert.ok(direct.some(({ task }) => task === "check") && direct.some(({ task }) => task === "review"), "the deprecated and the current review entries are both routed");
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
 // ---- effort (spec ASD-001 AC32–AC40) ----------------------------------------------------
 // Static reads of start.md rule 7 and the cases.md host rows; classification itself is proved
 // only by host runs. The validator cases run the real validateStartResult and validate-start.
 const START_MD = path.join(template, "tasks/start.md");
 const CASES_MD = "skills/ai-layout/fixtures/start-routing/cases.md";
 const flat = text => text.replace(/\s+/g, " ");
 const startText = () => { assert.ok(fs.existsSync(START_MD), `${START_MD} does not exist`); return fs.readFileSync(START_MD, "utf8"); };
 // A numbered rule, from "N. " at a line start to the next rule, a blank line or the end.
 const startRule = (text, n) => {
  const match = new RegExp(`^${n}\\. [\\s\\S]*?(?=\\n\\d+\\. |\\n\\s*\\n|(?![\\s\\S]))`, "m").exec(text);
  assert.ok(match, `start.md has no rule ${n}`);
  return flat(match[0]).trim();
 };
 // The commit before plan ASD-001. Rules 1–6 are compared with it, never with HEAD, so that
 // committing the delivery does not turn the comparison into one of the file with itself.
 // The full SHA, as check-risk.sh's BASELINE: an abbreviation can turn ambiguous as history grows.
 const PRE_ASD001 = "1111ef8f0b422bf5d87f0bd9ffc75a554c1a39f5";
 const baseStart = () => {
  const present = spawnSync("git", ["cat-file", "-e", `${PRE_ASD001}^{commit}`], { encoding: "utf8" });
  assert.equal(present.status, 0, `commit ${PRE_ASD001} (the commit before plan ASD-001) is not in this clone; a shallow clone lacks it, so fetch it (git fetch --unshallow) and run again`);
  const shown = spawnSync("git", ["show", `${PRE_ASD001}:skills/ai-layout/templates/ai-factory/tasks/start.md`], { encoding: "utf8" });
  assert.equal(shown.status, 0, `git show ${PRE_ASD001} start.md failed: ${shown.stderr}`);
  return shown.stdout;
 };
 check("start-effort-source", () => {
  const rule = startRule(startText(), 7);
  assert.match(rule, /\beffort rating only from a spec or exploration whose path the request names\b/, "rule 7 does not limit the source to a named spec or exploration path");
  assert.match(rule, /\bnever from any other artifact\b/, "rule 7 does not exclude every other artifact");
  assert.match(rule, /\bwhen both are named, the spec's rating wins\b/, "rule 7 does not let the spec's rating win over the exploration's (AC33)");
 });
 check("start-effort-after-rule3", () => {
  const text = startText(), base = baseStart();
  for (let n = 1; n <= 6; n++) assert.equal(startRule(text, n), startRule(base, n), `rule ${n} differs from ${PRE_ASD001}`);
  // The control: one word changed in rule 3 must be caught by the same comparison.
  const changed = text.replace(/^3\. (\S+)/m, "3. Changed $1");
  assert.notEqual(changed, text, "the control could not change rule 3");
  assert.notEqual(startRule(changed, 3), startRule(base, 3), `the control: a changed rule 3 still equals ${PRE_ASD001}'s`);
  const rule = startRule(text, 7);
  assert.ok(text.indexOf("\n7. ") > text.indexOf("\n6. "), "rule 7 does not follow rule 6");
  assert.match(rule, /^7\. Apply effort only after rule 3, so a present risk trigger still routes to planned work whatever the rating\./, "rule 7 does not say it applies only after rule 3 (AC34)");
  assert.doesNotMatch(rule, /\/fc:risk/, "rule 7 names /fc:risk");
 });
 check("start-effort-large", () => {
  const rule = startRule(startText(), 7);
  assert.match(rule, /\bA rating of L or XL never routes to quick or chore; fix stays allowed\./, "rule 7 does not rule out quick and chore for L/XL while allowing fix (AC35)");
  assert.match(rule, /\bchoose spec when a spec already exists for the request, otherwise explore\b/, "rule 7 does not name spec, else explore, as the replacement (AC37)");
 });
 check("start-effort-small-neutral", () => {
  const rule = startRule(startText(), 7);
  assert.match(rule, /\bA rating of S or M changes nothing: choose what you would choose with no rating\./, "rule 7 does not keep S/M neutral (AC36)");
 });
 check("start-effort-field", () => {
  const text = flat(startText());
  assert.match(text, /Use only these fields, plus "effort" \(S, M, L or XL\) on any of them only when rule 7 read a rating; omit it otherwise\./, "start.md does not name the optional effort field");
  assert.match(text, /Never return commands, rewritten input, model options, or a next-phase chain\. The one exception is the optional \/fc:risk mention that rule 3 allows in reason; it is never the routed task\./, "the 'Never return commands' sentence changed");
  const legacy = [{ status: "route", task: "quick", reason: "local" }, { status: "question", reason: "Need details" }, { status: "blocked", reason: "Missing layout" }];
  for (const base of legacy) {
   assert.deepEqual(m.validateStartResult(base), base, "a result without effort changed");
   assert.equal("effort" in m.validateStartResult(base), false, "a result without effort gained an effort key");
   for (const effort of ["S", "M", "L", "XL"]) assert.deepEqual(m.validateStartResult({ ...base, effort }), { ...base, effort }, `effort ${effort} on ${base.status} is not accepted and returned`);
   for (const effort of ["XXL", "m", 1, null, "", undefined]) assert.throws(() => m.validateStartResult({ ...base, effort }), /invalid start result/, `effort ${JSON.stringify(effort)} on ${base.status} is accepted`);
  }
  for (const value of [{ status: "route", task: "quick", reason: "x", effort: "L", command: "touch pwned" }, { status: "route", task: "quick", reason: "x", effort: "L", model: "other" }, { status: "question", task: "quick", reason: "x", effort: "S" }, { status: "route", task: "run", reason: "x", effort: "M" }, { status: "route", task: "quick", reason: "", effort: "M" }])
   assert.throws(() => m.validateStartResult(value), /invalid start result/, `accepted ${JSON.stringify(value)}`);
  const cli = input => spawnSync(process.execPath, [path.join(root, "ai-factory/make/models.js"), "validate-start"], { input, encoding: "utf8" });
  const good = cli('{"status":"route","task":"spec","reason":"Rated L","effort":"L"}');
  assert.equal(good.status, 0, good.stderr);
  assert.deepEqual(JSON.parse(good.stdout), { status: "route", task: "spec", reason: "Rated L", effort: "L" });
  const plain = cli('{"status":"question","reason":"Which file?"}');
  assert.equal(plain.status, 0, plain.stderr);
  assert.deepEqual(JSON.parse(plain.stdout), { status: "question", reason: "Which file?" });
  for (const bad of ['"XXL"', '"m"', "1", "null"]) assert.notEqual(cli(`{"status":"route","task":"quick","reason":"x","effort":${bad}}`).status, 0, `validate-start accepts effort ${bad}`);
 });
 check("start-effort-reason", () => {
  const rule = startRule(startText(), 7);
  assert.match(rule, /\bWhen the rating changed the destination, reason mentions the rating; otherwise reason need not mention it\./, "rule 7 does not require reason to mention a rating that changed the destination (AC39)");
  assert.match(rule, /\bReturn the rating read in effort\./, "rule 7 does not return the rating in effort (AC38)");
 });
 check("start-effort-host-cases", () => {
  assert.ok(fs.existsSync(CASES_MD), `${CASES_MD} does not exist`);
  const rows = new Map(fs.readFileSync(CASES_MD, "utf8").split("\n").filter(line => /^\| [a-z0-9-]+ \|/.test(line)).map(line => [line.split("|")[1].trim(), line]));
  const expected = { "effort-spec-wins": /\bM\b.*\bXL\b.*effort M/, "effort-large-no-quick": /\bL\b.*spec; effort L; never quick or chore/, "effort-large-fix": /\bXL\b.*fix; effort XL/, "effort-small": /\bS\b.*quick; effort S/, "effort-large-explore": /\bL\b.*explore; effort L/, "effort-reason": /reason names the L rating/ };
  for (const [id, pattern] of Object.entries(expected)) {
   assert.ok(rows.has(id), `${CASES_MD} has no ${id} row`);
   assert.match(rows.get(id), pattern, `${CASES_MD} row ${id} does not state its expected decision`);
  }
 });
}
} finally { fs.rmSync(root, { recursive: true, force: true }); }
if (failures.length) process.exitCode = 1;
NODE
