#!/usr/bin/env bash
# models.yaml parsing and the model resolution contract, for both tools, with routing absent,
# disabled and enabled. Pure resolution: check-runner-security.sh proves the argv a CLI receives.
set -euo pipefail
cd "$(dirname "$0")/../../.."
node <<'NODE'
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const {boundary}=require("./skills/ai-layout/templates/ai-factory/make/safe-files.js");
const safe=boundary(path.resolve("ai-factory"));
const scratch=safe.scratch(path.resolve("ai-factory/runs/tmp"));
try {
 const payload=path.join(scratch,"ai-factory");
 fs.mkdirSync(payload);
 fs.cpSync("skills/ai-layout/templates/ai-factory/make",path.join(payload,"make"),{recursive:true});
 const {resolveModel}=require(path.join(payload,"make/runner.js"));
 const models=require(path.join(payload,"make/models.js"));
 const configure=body=>fs.writeFileSync(path.join(payload,"models.yaml"),body);
 const select=(tool,task,env={})=>models.selectModel({root:scratch,tool,task,env});

 // --- AC2: the pre-routing contract, unchanged -------------------------------------------------
 for(const tool of ["claude","codex"]) {
  configure(`${tool}: gateway/tool-alias\nreview: gateway/review-alias\n`);
  assert.equal(resolveModel(tool,false,{}),"gateway/tool-alias");
  assert.equal(resolveModel(tool,true,{}),"gateway/review-alias");
  assert.equal(resolveModel(tool,true,{MODEL:"explicit/override"}),"explicit/override");
  assert.equal(resolveModel(tool,true,{MODEL:"",SDLC_MODEL_EXPLICIT:"1"}),"");
  configure(`${tool}: gateway/tool-alias\nreview: # inherit tool\n`);
  assert.equal(resolveModel(tool,true,{}),"gateway/tool-alias");
  configure(`${tool}:\nreview:\n`);
  assert.equal(resolveModel(tool,true,{}),"");
  assert.equal(resolveModel(tool,false,{}),"");
  configure(`${tool}: 'alias with spaces and $() and doubled ''quote'''\n`);
  assert.equal(resolveModel(tool,false,{}),"alias with spaces and $() and doubled 'quote'");
 }
 fs.unlinkSync(path.join(payload,"models.yaml"));
 assert.equal(resolveModel("claude",true,{}),"");
 assert.equal(select("claude","plan").source,"cli-default");

 // --- AC1: the shipped template, and every value form ----------------------------------------
 const template=fs.readFileSync("skills/ai-layout/templates/ai-factory/models.yaml","utf8");
 const shipped=models.parseModels(template);
 assert.deepEqual(shipped.routing,{present:true,enabled:false,tasks:{risk:{claude:"claude-opus-5-5",codex:""}},aliased:[]},"the template must ship routing disabled, with only the risk entry (spec 0023 AC32)");
 // Spec 0023 AC33: the shipped risk entry has no effect while routing is disabled.
 configure(template);
 for(const tool of ["claude","codex"]) {
  const s=select(tool,"risk");
  assert.deepEqual([s.model,s.source,s.fallback,s.routing_enabled],["","cli-default",null,false],`${tool} risk under the shipped template`);
 }
 // Turned on, it routes Claude and the blank codex entry falls back, disclosed.
 configure(template.replace(/^  enabled: false$/m,"  enabled: true"));
 assert.deepEqual([select("claude","risk").model,select("claude","risk").source],["claude-opus-5-5","task"]);
 assert.deepEqual([select("codex","risk").model,select("codex","risk").source,select("codex","risk").fallback],["","cli-default","no codex model for risk"]);
 const routed=(enabled,extra="")=>`claude: tool/claude\ncodex: tool/codex\nreview: tool/review\n\nrouting:\n  enabled: ${enabled}   # opt-in\n  tasks:\n    plan:\n      claude: gateway/planning-claude\n      codex: "gateway/planning codex"\n    test:\n      claude: 'gateway/testing ''claude'''\n      codex: gateway/testing-codex # trailing comment\n    review:\n      claude: gateway/review-claude\n      codex:\n    my-custom-task:\n      codex: custom/model\n    fix:\n${extra}\npricing:\n  default: { input: 3, output: 15 }\n  gateway/planning-claude: { input: 1, output: 2 }\n`;
 const parsed=models.parseModels(routed("true"));
 assert.deepEqual(parsed.routing.tasks,{
  plan:{claude:"gateway/planning-claude",codex:"gateway/planning codex"},
  test:{claude:"gateway/testing 'claude'",codex:"gateway/testing-codex"},
  review:{claude:"gateway/review-claude",codex:""},
  "my-custom-task":{codex:"custom/model"},
  fix:{},
 });
 assert.equal(parsed.routing.enabled,true);
 assert.deepEqual(parsed.routing.aliased,[],"a current task name is no alias");
 assert.equal(parsed.claude,"tool/claude");

 // --- AC3/AC5: enabled resolution and its sources -------------------------------------------
 configure(routed("true"));
 const matrix=[
  ["claude","plan","gateway/planning-claude","task",null],
  ["codex","plan","gateway/planning codex","task",null],
  ["claude","test","gateway/testing 'claude'","task",null],
  ["codex","test","gateway/testing-codex","task",null],
  ["claude","review","gateway/review-claude","task",null],
  ["codex","review","tool/review","review-default","no codex model for review"],
  // check is the deprecated name of review: it selects review's mapping and records review.
  ["claude","check","gateway/review-claude","task",null],
  ["codex","check","tool/review","review-default","no codex model for review"],
  ["claude","my-custom-task","tool/claude","tool-default","no claude model for my-custom-task"],
  ["codex","my-custom-task","custom/model","task",null],
  ["claude","fix","tool/claude","tool-default","no claude model for fix"],
  ["codex","run","tool/codex","tool-default","no run mapping"],
 ];
 for(const [tool,task,model,source,fallback] of matrix) {
  const s=select(tool,task);
  assert.equal(s.model,model,`${tool} ${task}`);
  assert.equal(s.source,source,`${tool} ${task} source`);
  assert.equal(s.fallback,fallback,`${tool} ${task} fallback`);
  assert.equal(s.routing_enabled,true);
  assert.equal(s.task,task==="check"?"review":task);
  assert.match(s.config_digest,/^[0-9a-f]{12}$/);
  assert.equal(s.schema,"fc.model-selection.v1");
 }
 assert.notEqual(select("claude","plan").model,select("claude","test").model,"plan and test must select different models");
 assert.equal(models.describe(select("codex","plan")),"plan / codex: gateway/planning codex (task default)");
 assert.equal(models.describe(select("codex","run")),"run / codex: tool/codex (tool default; routing fallback: no run mapping)");
 // Back-to-back: each call resolves its own task; nothing carries over.
 const sequence=["plan","test","plan","test"].map(task=>select("claude",task).model);
 assert.deepEqual(sequence,["gateway/planning-claude","gateway/testing 'claude'","gateway/planning-claude","gateway/testing 'claude'"]);
 // Blank everywhere: CLI inheritance, disclosed.
 configure("claude:\ncodex:\nreview:\nrouting:\n  enabled: true\n  tasks:\n    plan:\n      claude:\n");
 assert.deepEqual([select("claude","plan").model,select("claude","plan").source,select("claude","plan").fallback],["","cli-default","no claude model for plan"]);
 assert.equal(models.describe(select("claude","plan")),"plan / claude: CLI's own configuration (CLI default; routing fallback: no claude model for plan)");

 // --- AC4: overrides beat mappings ----------------------------------------------------------
 configure(routed("true"));
 for(const tool of ["claude","codex"]) {
  assert.deepEqual([select(tool,"plan",{MODEL:"explicit/x"}).model,select(tool,"plan",{MODEL:"explicit/x"}).source],["explicit/x","explicit"]);
  assert.deepEqual([select(tool,"plan",{MODEL:"",SDLC_MODEL_EXPLICIT:"1"}).model,select(tool,"plan",{MODEL:"",SDLC_MODEL_EXPLICIT:"1"}).source],["","explicit-inherit"]);
  assert.equal(resolveModel(tool,false,{MODEL:"",SDLC_MODEL_EXPLICIT:"1"},"plan"),"");
 }
 // An explicit override never needs the file, preserving override-first behavior.
 configure("claude: |\n  broken\n");
 assert.equal(select("claude","plan",{MODEL:"explicit/x"}).model,"explicit/x");
 assert.equal(select("claude","plan",{MODEL:"",SDLC_MODEL_EXPLICIT:"1"}).model,"");

 // --- AC2: disabled routing has no effect ---------------------------------------------------
 configure(routed("false"));
 for(const [tool,task] of [["claude","plan"],["codex","test"],["claude","run"]]) {
  const s=select(tool,task);
  assert.deepEqual([s.model,s.source,s.fallback,s.routing_enabled],[`tool/${tool}`,"tool-default",null,false]);
 }
 assert.deepEqual([select("codex","review").model,select("codex","review").source],["tool/review","review-default"]);
 assert.deepEqual([select("codex","check").model,select("codex","check").source],["tool/review","review-default"]);

 // --- deprecated routing key: an adopted repo's routing.tasks.check is read as review ----------
 const legacy=`claude: tool/claude\ncodex: tool/codex\nreview: tool/review\nrouting:\n  enabled: true\n  tasks:\n    check:\n      claude: gateway/legacy-review\n    plan:\n      claude: gateway/planning-claude\n`;
 configure(legacy);
 const legacyParsed=models.parseModels(legacy);
 assert.deepEqual(legacyParsed.routing.tasks,{review:{claude:"gateway/legacy-review"},plan:{claude:"gateway/planning-claude"}},"check: is stored as review");
 assert.deepEqual(legacyParsed.routing.aliased,["check"]);
 for(const task of ["review","check"]) {
  const s=select("claude",task);
  assert.deepEqual([s.task,s.model,s.source],["review","gateway/legacy-review","task"],`${task} under a legacy check: key`);
 }
 assert.deepEqual([select("codex","review").model,select("codex","review").source,select("codex","review").fallback],["tool/review","review-default","no codex model for review"]);
 fs.mkdirSync(path.join(payload,"tasks"),{recursive:true});
 fs.writeFileSync(path.join(payload,"tasks/review.md"),"Delegate to the `reviewer` subagent.\n");
 fs.writeFileSync(path.join(payload,"tasks/plan.md"),"Plan.\n");
 const findings=models.doctor(scratch,{}).filter(([level])=>level==="finding").map(([, ,text])=>text);
 assert.ok(findings.some(text=>/routing\.tasks\.check uses the deprecated name of review and is read as routing\.tasks\.review — rename the key to review/.test(text)),`doctor suggests the rename: ${JSON.stringify(findings)}`);
 assert.ok(!findings.some(text=>/no ai-factory\/tasks\/<task>\.md/.test(text)),"a legacy key is no orphan mapping once review.md exists");
 // The finding stands while routing is off too: the key is still read when it is turned on.
 configure(legacy.replace("enabled: true","enabled: false"));
 assert.ok(models.doctor(scratch,{}).some(([level,,text])=>level==="finding"&&/deprecated name of review/.test(text)));
 configure(routed("true"));
 assert.ok(!models.doctor(scratch,{}).some(([,,text])=>/deprecated name/.test(text)),"no finding for a current key");
 fs.rmSync(path.join(payload,"tasks"),{recursive:true});

 // --- AC7: invalid configuration names its line and never selects a model -------------------
 const invalid=[
  ["routing:\n  enabled: ture\n",/line 2: routing.enabled must be true or false/],
  ["routing:\n  enabled: \"true\"\n",/line 2: routing.enabled must be true or false/],
  ["routing:\n  enabled: yes\n",/line 2/],
  ["routing:\n  enabled:\n",/line 2/],
  ["routing:\n  enabled: true\n  enabled: false\n",/line 3: duplicate routing setting/],
  ["routing:\n  enabled: true\nrouting:\n  enabled: true\n",/line 3: duplicate setting `routing`/],
  ["routing:\n  tasks:\n    plan:\n      claude: a\n      claude: b\n",/line 5: duplicate claude model/],
  ["routing:\n  tasks:\n    plan:\n      claude: a\n    plan:\n      codex: b\n",/line 5: duplicate task `plan`/],
  ["routing:\n  tasks:\n    plan:\n      gemini: a\n",/line 4: unknown tool `gemini`/],
  ["routing:\n  tasks:\n    plan: gateway/x\n",/line 3: routing.tasks.plan must be an indented mapping/],
  ["routing:\n  tasks:\n    plan: { claude: x }\n",/line 3/],
  ["routing:\n  tasks: { plan: x }\n",/line 2: routing.tasks must be an indented mapping/],
  ["routing: { enabled: true }\n",/line 1: routing must be an indented mapping/],
  ["routing:\n  tasks:\n    review:\n      claude: x\n    check:\n      codex: y\n",/line 5: duplicate task `review`: `check` is its deprecated name, so map only `review`/],
  ["routing:\n  tasks:\n    check:\n      claude: x\n    review:\n      codex: y\n",/line 5: duplicate task `review`/],
  ["routing:\n  tasks:\n    Plan:\n      claude: x\n",/line 3: invalid task name/],
  ["routing:\n  tasks:\n    plan:\n      claude: [a, b]\n",/Unsupported model syntax on line 4/],
  ["routing:\n  tasks:\n    plan:\n      claude: |\n",/Unsupported model syntax on line 4/],
  ["routing:\n  tasks:\n    plan:\n      claude: \"unterminated\n",/Invalid quoted model on line 4/],
  ["routing:\n  tasks:\n    plan:\n       claude: x\n",/line 4: unsupported indentation/],
  ["routing:\n   enabled: true\n",/line 2: unsupported indentation/],
  ["routing:\n\tenabled: true\n",/line 2: tabs are not supported/],
  ["routing:\n  enabled: true\n  models:\n",/line 3: unknown routing setting `models`/],
  ["routing:\n  enabled: true\n    plan:\n",/line 3: unexpected indentation/],
  ["routing:\n  tasks:\n      claude: x\n",/line 3: unexpected indentation/],
  ["claude: a\n  nested: b\n",/line 2: unexpected indentation/],
  ["claude: one\nclaude: two\n",/line 2: duplicate setting `claude`/],
  ["unknown: alias\n",/line 1: unknown setting `unknown`/],
  ["pricing:\n    deep: { input: 1 }\n",/line 2: unexpected indentation/],
 ];
 for(const [body,message] of invalid) {
  configure(body);
  assert.throws(()=>select("claude","plan"),message,JSON.stringify(body));
 }
 // A malformed section fails even while disabled: nothing proves it was meant to be off.
 configure("routing:\n  enabled: false\n  tasks:\n    plan:\n      claude: a\n      claude: b\n");
 assert.throws(()=>select("claude","run"),/duplicate claude model/);
 // Missing is not invalid: a task mapping that is absent falls back; a missing file inherits.
 fs.unlinkSync(path.join(payload,"models.yaml"));
 assert.deepEqual([select("codex","plan").model,select("codex","plan").source,select("codex","plan").routing_enabled],["","cli-default",false]);
 console.log("PASS: parser (template with the risk entry, quoting, comments, custom tasks, pricing kept), 13-row enabled matrix with fallback sources, deprecated check key read as review with a doctor finding, overrides, disabled and absent routing unchanged, 29 invalid configurations rejected by line");
} finally {fs.rmSync(scratch,{recursive:true,force:true});}
NODE
