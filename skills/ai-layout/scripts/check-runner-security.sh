#!/usr/bin/env bash
# Regression fixtures use fake CLIs; no model, network, or package installation.
set -euo pipefail
cd "$(dirname "$0")/../../.."
node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const { boundary } = require("./skills/ai-layout/templates/ai-factory/make/safe-files.js");
const repo = process.cwd();
const safe = boundary(path.join(repo, "ai-factory"));
const scratch = safe.scratch(path.join(repo, "ai-factory/runs/tmp"));
const root = path.join(scratch, "project with spaces");
const payload = path.join(root, "ai-factory");
const runs = path.join(payload, "runs");
const marker = path.join(root, "injected");
const capture = path.join(root, "capture.jsonl");
fs.mkdirSync(path.join(payload, "tasks"), { recursive: true });
fs.cpSync(path.join(repo, "skills/ai-layout/templates/ai-factory/make"), path.join(payload, "make"), { recursive: true });
fs.writeFileSync(path.join(payload, "tasks/chore.md"), "fixture task");
fs.writeFileSync(path.join(payload, "tasks/check.md"), "fixture check");
fs.writeFileSync(path.join(payload, "tasks/start.md"), "fixture classifier");
fs.writeFileSync(path.join(payload, "tasks/continue.md"), "fixture continuation");
const fake = path.join(root, "fake cli");
fs.writeFileSync(fake, `#!/usr/bin/env node
const fs = require('node:fs'), path = require('node:path');
let input = Buffer.alloc(0);
process.stdin.on('data', chunk => { input = Buffer.concat([input, chunk]); });
process.stdin.on('end', () => {
 const args = process.argv.slice(2);
 const privateFiles = fs.readdirSync('ai-factory/runs/tmp').every(name => {
  const dir = path.join('ai-factory/runs/tmp', name);
  return (fs.statSync(dir).mode & 0o777) === 0o700 &&
   fs.readdirSync(dir).every(file => (fs.statSync(path.join(dir,file)).mode & 0o777) === 0o600);
 });
 fs.appendFileSync(process.env.CAPTURE, JSON.stringify({args, input: input.toString('base64'), privateFiles}) + '\\n');
 if (process.env.WAIT_READY) { fs.writeFileSync(process.env.WAIT_READY, 'ready'); setInterval(() => {}, 1000); return; }
 setTimeout(() => {
  if (process.env.FAIL_CLI) { process.exitCode = 7; return; }
  if (args[0] === 'exec') {
   fs.writeFileSync(args[args.indexOf('-o') + 1], '{"verdict":"approve","findings":[]}');
   process.stdout.write(JSON.stringify({type:'thread.started', thread_id:'fake'})+'\\n'+JSON.stringify({type:'turn.completed',usage:{input_tokens:2,output_tokens:1}})+'\\n');
  } else process.stdout.write(JSON.stringify({session_id:'fake',usage:{input_tokens:2,output_tokens:1},total_cost_usd:0,...(process.env.REPORT_MODEL?{modelUsage:{[process.env.REPORT_MODEL]:{inputTokens:2}}}:{})}));
 }, Number(process.env.DELAY || 0));
});
`, { mode: 0o700 });
const env = { ...process.env, CAPTURE: capture, CMD: fake, TOOL: "claude", TASK: "chore", MODEL: "", INPUT_FILE: "", INPUT: "", MAKEFLAGS: "", MAKEOVERRIDES: "" };
const mk = ["-f", "ai-factory/make/ai.mk", "ai"];
function invoke(extra = {}, args = []) {
 return spawnSync("make", [...mk, ...args], { cwd: root, env: { ...env, ...extra }, encoding: "utf8" });
}
function ok(result) { assert.equal(result.status, 0, result.stderr || result.stdout); }
function captures() { return fs.existsSync(capture) ? fs.readFileSync(capture, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse) : []; }
function last() { return captures().at(-1); }
function rejected(extra = {}, args = []) {
 const before = captures().length;
 const result = invoke(extra, args);
 assert.notEqual(result.status, 0, "invalid selection unexpectedly succeeded");
 assert.equal(captures().length, before, "invalid selection reached CLI");
 assert.equal(fs.existsSync(marker), false, "configuration executed a command");
}
function noScratch() { assert.deepEqual(fs.readdirSync(path.join(runs, "tmp")), []); }
function modelFile(content) { fs.writeFileSync(path.join(payload, "models.yaml"), content); }
async function asyncRun(extra = {}) {
 return new Promise((resolve, reject) => {
  const child = spawn("make", mk, { cwd: root, env: { ...env, ...extra }, stdio: ["ignore", "pipe", "pipe"] });
  let stderr = "";
  child.stderr.on("data", data => { stderr += data; });
  child.stdout.resume();
  child.on("error", reject);
  child.on("close", code => resolve({status:code,stderr}));
 });
}
(async () => {
 try {
  for (const tool of ["claude", "codex"]) {
   const result = invoke({ TOOL: tool, TASK: "start" });
   assert.notEqual(result.status, 0);
   assert.match(result.stderr, /interactive.*destination task/s);
   assert.equal(captures().length, 0);
   assert.equal(fs.existsSync(runs), false, "start rejection creates no run artifacts");
  }
  for (const tool of ["claude", "codex"]) {
   const result = invoke({ TOOL: tool, TASK: "continue", INPUT: "d-20260101-abcdef" });
   assert.notEqual(result.status, 0);
   assert.match(result.stderr, /TASK=continue requires an interactive session.*plan, test, run, check or report/s);
   assert.equal(captures().length, 0, "continue rejection reaches no CLI");
   assert.equal(fs.existsSync(runs), false, "continue rejection creates no run artifacts");
  }
  for (const tool of ["claude", "codex"]) {
   for (const model of [`$(touch '${marker}')`, "`touch '" + marker + "'`", `alias with spaces; touch '${marker}'`, 'alias"quote']) {
    modelFile(`${tool}: ${JSON.stringify(model)}\n`);
    const input = "quotes '\" and $() and `literal`\nsecond line\n";
    ok(invoke({ TOOL: tool, INPUT: input }));
    const record = last();
    const flag = tool === "codex" ? "-m" : "--model";
    assert.equal(record.args[record.args.indexOf(flag) + 1], model);
    assert.equal(Buffer.from(record.input, "base64").toString(), `fixture task\n## Input\n${input}`);
    assert.equal(record.privateFiles, true);
    if (tool === "codex") {
     assert.deepEqual(record.args.slice(0,3), ["exec","--json","--skip-git-repo-check"]);
     assert.equal(record.args.at(-1), "-");
     assert.ok(record.args[record.args.indexOf("-o") + 1].startsWith(runs + path.sep));
    } else assert.deepEqual(record.args.slice(-2), ["--output-format","json"]);
    assert.equal(fs.existsSync(marker), false);
    noScratch();
   }
  }
  modelFile("claude: provider/alias\ncodex:\nreview: reviewer\npricing:\n  default: { input: 3, output: 15 }\n");
  ok(invoke({TASK:"check"})); assert.equal(last().args[2], "reviewer");
  ok(invoke({MODEL:"explicit",TASK:"check"})); assert.equal(last().args[2], "explicit");
  ok(invoke({TASK:"check"}, ["MODEL="])); assert.equal(last().args.includes("--model"), false);
  modelFile("claude: provider/alias\nreview:\n");
  ok(invoke({TASK:"check"})); assert.equal(last().args[2], "provider/alias");
  modelFile("claude:\ncodex:\n");
  ok(invoke()); assert.equal(last().args.includes("--model"), false);
  const literal = "$(shell touch '" + marker + "')";
  ok(invoke({}, [`INPUT=${literal}`, `MODEL=${literal}`]));
  assert.equal(last().args[2], literal);
  assert.equal(Buffer.from(last().input,"base64").toString(), `fixture task\n## Input\n${literal}`);
  assert.equal(fs.existsSync(marker), false);
  const inputFile = path.join(root, "input with spaces $(literal).txt");
  const bytes = Buffer.from([0, 255, 13, 10, 36, 40, 41]);
  fs.writeFileSync(inputFile, bytes);
  ok(invoke({INPUT_FILE:inputFile}));
  assert.deepEqual(Buffer.from(last().input,"base64"), Buffer.concat([Buffer.from("fixture task\n## Input\n"),bytes]));
  for (const extra of [{TOOL:"other"},{TOOL:literal},{TASK:"../chore"},{TASK:"missing"},{TASK:literal},{INPUT_FILE:"missing"},{INPUT_FILE:root},{CMD:`${fake}; touch '${marker}'`},{CMD:"echo unsafe"}]) rejected(extra);
  for (const config of ["claude: |\n  alias\n", "claude: one\nclaude: two\n", "unknown: alias\n", "claude: [a,b]\n"]) {
   modelFile(config); rejected();
  }
  modelFile("claude:\n");
  const beforeFailure = fs.readFileSync(path.join(runs,"log.csv"),"utf8");
  assert.notEqual(invoke({FAIL_CLI:"1"}).status, 0);
  assert.equal(fs.readFileSync(path.join(runs,"log.csv"),"utf8"),beforeFailure);
  noScratch();
  const parallel = await Promise.all(Array.from({length:4}, () => asyncRun({DELAY:"100"})));
  parallel.forEach(ok);
  noScratch();
  assert.equal(fs.readFileSync(path.join(runs,"log.csv"),"utf8").split("\n").length, beforeFailure.split("\n").length + 4);
  // The plugin's own checkout uses entry/task symlinks into its source templates.
  const sourceMake = path.join(root,"source-templates/make");
  fs.cpSync(path.join(payload,"make"),sourceMake,{recursive:true});
  fs.unlinkSync(path.join(payload,"make/runner.js"));
  fs.symlinkSync(path.join(sourceMake,"runner.js"),path.join(payload,"make/runner.js"));
  fs.renameSync(path.join(payload,"tasks/chore.md"),path.join(root,"shared-task.md"));
  fs.symlinkSync(path.join(root,"shared-task.md"),path.join(payload,"tasks/chore.md"));
  ok(invoke()); noScratch();
  fs.unlinkSync(path.join(payload,"tasks/chore.md"));
  fs.writeFileSync(path.join(scratch,"outside-task.md"),"outside instructions");
  fs.symlinkSync(path.join(scratch,"outside-task.md"),path.join(payload,"tasks/chore.md"));
  rejected();
  fs.unlinkSync(path.join(payload,"tasks/chore.md"));
  fs.symlinkSync(path.join(root,"shared-task.md"),path.join(payload,"tasks/chore.md"));
  const ready = path.join(root,"ready");
  const interrupted = spawn(process.execPath,["ai-factory/make/runner.js","ai"],{cwd:root,env:{...env,WAIT_READY:ready},stdio:"ignore"});
  const exited = new Promise(resolve => interrupted.once("close",resolve));
  for(let tries=0; !fs.existsSync(ready) && tries<200; tries++) await new Promise(resolve=>setTimeout(resolve,10));
  assert.ok(fs.existsSync(ready),"interrupt fixture never became ready");
  const logBeforeInterrupt = fs.readFileSync(path.join(runs,"log.csv"),"utf8");
  interrupted.kill("SIGTERM");
  assert.notEqual(await exited,0);
  assert.equal(fs.readFileSync(path.join(runs,"log.csv"),"utf8"),logBeforeInterrupt);
  noScratch();
  const sentinel = path.join(root,"outside"); fs.writeFileSync(sentinel,"unchanged");
  fs.renameSync(path.join(runs,"log.csv"),path.join(runs,"saved-log.csv"));
  fs.symlinkSync(sentinel,path.join(runs,"log.csv")); rejected();
  assert.equal(fs.readFileSync(sentinel,"utf8"),"unchanged");
  fs.unlinkSync(path.join(runs,"log.csv"));
  fs.renameSync(runs,`${runs}-saved`); fs.symlinkSync(`${runs}-saved`,runs); rejected();
  fs.unlinkSync(runs); fs.renameSync(`${runs}-saved`,runs);
  fs.renameSync(path.join(runs,"tmp"),path.join(runs,"tmp-saved"));
  fs.symlinkSync(path.join(runs,"tmp-saved"),path.join(runs,"tmp")); rejected();
  fs.unlinkSync(path.join(runs,"tmp"));
  fs.renameSync(path.join(runs,"tmp-saved"),path.join(runs,"tmp"));
  // --- per-task routing through make: exact argv, stderr, sidecar, no fallback launch ---------
  fs.writeFileSync(path.join(payload,"tasks/plan.md"),"fixture plan");
  fs.writeFileSync(path.join(payload,"tasks/test.md"),"fixture test");
  const hostile=`gateway/planning claude $(touch '${marker}')`;
  const routed=enabled=>`claude: tool/claude\ncodex: tool/codex\nreview:\nrouting:\n  enabled: ${enabled}\n  tasks:\n    plan:\n      claude: ${JSON.stringify(hostile)}\n      codex: gateway/planning-codex\n    test:\n      claude: gateway/testing-claude\n      codex: 'gateway/testing codex; touch ${marker}'\n`;
  const expected={claude:{plan:hostile,test:"gateway/testing-claude"},codex:{plan:"gateway/planning-codex",test:`gateway/testing codex; touch ${marker}`}};
  const sidecarOf=result=>{const saved=/run saved: (.+)\n/.exec(result.stdout)?.[1];assert.ok(saved,result.stdout);return JSON.parse(fs.readFileSync(path.join(root,saved+".model.json"),"utf8"));};
  const flagValues=(record,flag)=>record.args.flatMap((arg,i)=>arg===flag?[record.args[i+1]]:[]);
  modelFile(routed("true"));
  for (const tool of ["claude","codex"]) {
   const flag = tool === "codex" ? "-m" : "--model";
   for (const task of ["plan","test","plan","test"]) {
    const before=captures().length;
    const result=invoke({TOOL:tool,TASK:task});
    ok(result);
    assert.equal(captures().length,before+1,"exactly one launch per run");
    assert.deepEqual(flagValues(last(),flag),[expected[tool][task]],`${tool} ${task}: the model is one literal argument`);
    assert.ok(result.stderr.includes(`model: ${task} / ${tool}: ${expected[tool][task]} (task default)`),result.stderr);
    const record=sidecarOf(result);
    assert.equal(record.schema,"t4.model-selection.v1");
    assert.deepEqual([record.task,record.tool,record.requested_model,record.source,record.routing_enabled,record.outcome,record.model_argument,record.reported_models],[task,tool,expected[tool][task],"task",true,"succeeded","passed",null]);
    assert.equal(fs.existsSync(marker),false);
   }
  }
  // Requested and host-reported identities stay apart.
  const reported=invoke({TASK:"plan",REPORT_MODEL:"provider/underlying-model"});ok(reported);
  assert.deepEqual([sidecarOf(reported).requested_model,sidecarOf(reported).reported_models],[hostile,["provider/underlying-model"]]);
  // Unmapped task: disclosed fallback. Explicit value and explicit blank beat the mapping.
  const fallback=invoke({TASK:"chore"});ok(fallback);
  assert.deepEqual(flagValues(last(),"--model"),["tool/claude"]);
  assert.ok(fallback.stderr.includes("model: chore / claude: tool/claude (tool default; routing fallback: no chore mapping)"),fallback.stderr);
  ok(invoke({TASK:"plan",MODEL:"explicit/model"}));assert.deepEqual(flagValues(last(),"--model"),["explicit/model"]);
  const inherit=invoke({TASK:"plan"},["MODEL="]);ok(inherit);
  assert.equal(last().args.includes("--model"),false);
  assert.deepEqual([sidecarOf(inherit).source,sidecarOf(inherit).requested_model,sidecarOf(inherit).model_argument],["explicit-inherit",null,"omitted"]);
  // A rejected model is the result: one launch, no retry on another model, no log row.
  const logBeforeReject=fs.readFileSync(path.join(runs,"log.csv"),"utf8");
  const beforeReject=captures().length;
  const sidecarsBefore=new Set(fs.readdirSync(runs).filter(name=>name.endsWith(".model.json")));
  const rejectedRun=invoke({TASK:"test",TOOL:"codex",FAIL_CLI:"1"});
  assert.notEqual(rejectedRun.status,0);
  assert.equal(captures().length,beforeReject+1,"a failed model launch must not be retried");
  assert.deepEqual(flagValues(last(),"-m"),[expected.codex.test]);
  assert.equal(fs.readFileSync(path.join(runs,"log.csv"),"utf8"),logBeforeReject,"a failed run wrote a success row");
  const failedRecords=fs.readdirSync(runs).filter(name=>name.endsWith(".model.json")&&!sidecarsBefore.has(name)).map(name=>JSON.parse(fs.readFileSync(path.join(runs,name),"utf8"))).filter(r=>r.outcome==="failed");
  assert.equal(failedRecords.length,1);assert.equal(failedRecords[0].requested_model,expected.codex.test);
  // Disabled routing: the mapping has no effect.
  modelFile(routed("false"));
  ok(invoke({TASK:"plan"}));assert.deepEqual(flagValues(last(),"--model"),["tool/claude"]);
  ok(invoke({TASK:"test",TOOL:"codex"}));assert.deepEqual(flagValues(last(),"-m"),["tool/codex"]);
  // Invalid routing, or a host setting that would override the selection, launches nothing.
  for (const body of ["routing:\n  enabled: ture\n","routing:\n  tasks:\n    plan:\n      claude: a\n      claude: b\n","routing:\n  tasks:\n    plan: gateway/x\n"]) { modelFile(body); rejected({TASK:"plan"}); }
  modelFile(routed("true"));
  rejected({TASK:"plan",CLAUDE_CODE_SUBAGENT_MODEL:"other/model"});
  ok(invoke({TASK:"plan",TOOL:"codex",CLAUDE_CODE_SUBAGENT_MODEL:"other/model"}));
  noScratch();
  console.log("PASS: safe runner arguments, selection, input bytes, model precedence, private concurrent scratch, interruption, and symlink rejection; routed plan/test argv per tool through make, stderr and sidecar agree, reported identity kept apart, fallback disclosed, overrides win, one launch on failure, disabled and invalid routing");
 } finally { fs.rmSync(scratch,{recursive:true,force:true}); }
})().catch(error => { console.error(error); process.exitCode=1; });
NODE
