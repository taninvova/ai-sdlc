#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { boundary } = require("./skills/ai-layout/templates/ai-factory/make/safe-files.js");
const gateFile = path.resolve("skills/ai-layout/templates/ai-factory/make/gate.js");
const { digest, evaluate } = require(gateFile);
const safe = boundary(path.resolve("ai-factory"));
const scratch = safe.scratch(path.resolve("ai-factory/runs/tmp"));
const file = path.join(scratch,"run.json");
const approved = {verdict:"approve",findings:[],summary:"No findings."};
const finding = {severity:"minor",file:"source.js",line:0,issue:"Issue",suggestion:"Fix"};
function gate(args = [], mode = "1") {
 const env = {...process.env};
 if(mode === undefined) delete env.GATE_ENFORCE; else env.GATE_ENFORCE=mode;
 return spawnSync(process.execPath,[gateFile,file,...args],{env,encoding:"utf8"});
}
function write(verdict) {fs.writeFileSync(file,JSON.stringify({result:JSON.stringify(verdict)}));}
function code(result, expected) {assert.equal(result.status,expected,`${result.stdout}\n${result.stderr}`);}
try {
 write(approved);code(gate(),0);
 for(const severity of ["minor","major"]) {write({...approved,findings:[{...finding,severity}]});code(gate(),0);}
 write({...approved,findings:[{...finding,severity:"blocker"}]});code(gate(),1);code(gate([],"0"),0);
 write({...approved,verdict:"request_changes"});code(gate(),1);code(gate([],""),0);
 for(const invalid of [
  {...approved,verdict:"invalid-verdict"},{...approved,verdict:undefined},
  {...approved,summary:undefined},{...approved,summary:7},{...approved,findings:undefined},
  {...approved,findings:{}},{...approved,findings:[null]},
  {...approved,findings:[{...finding,severity:"warning"}]},
  {...approved,findings:[{...finding,file:undefined}]},
  {...approved,findings:[{...finding,issue:3}]},
  {...approved,findings:[{...finding,suggestion:undefined}]},
  {...approved,findings:[{...finding,line:-1}]},
  {...approved,findings:[{...finding,line:0.5}]},[],null,
 ]) {
  write(invalid);code(gate(),1);
  const advisory=gate([],"0");code(advisory,0);assert.match(advisory.stderr,/advisory.*invalid review, no approval/);
 }
 for(const invalid of ["", "not json", JSON.stringify({result:""}), JSON.stringify({result:JSON.stringify(approved)+"\n"+JSON.stringify(approved)}),JSON.stringify({is_error:true,result:JSON.stringify(approved)})]) {
  fs.writeFileSync(file,invalid);code(gate(),1);
 }
 fs.unlinkSync(file);code(gate(),1);
 write(approved);
 for(const setting of ["false","true","2","yes"]) code(gate([],setting),2);
 fs.writeFileSync(file,JSON.stringify({result:`\`\`\`json\n${JSON.stringify(approved)}\n\`\`\``}));code(gate(),0);
 // A stale sibling sidecar must never override Claude's actual result.
 fs.writeFileSync(`${file}.last.txt`,JSON.stringify(approved));
 write({...approved,verdict:"request_changes"});code(gate(),1);
 const staleHash = digest(fs.readFileSync(file));
 write(approved);code(gate(["--output-sha256",staleHash]),1);
 const stream = JSON.stringify({type:"thread.started",thread_id:"one"})+"\n"+JSON.stringify({type:"turn.completed",usage:{input_tokens:1,output_tokens:1}})+"\n";
 fs.writeFileSync(file,stream);
 fs.writeFileSync(`${file}.last.txt`,JSON.stringify(approved));
 const bound = ["--tool","codex","--sidecar",`${file}.last.txt`,"--output-sha256",digest(fs.readFileSync(file)),"--sidecar-sha256",digest(fs.readFileSync(`${file}.last.txt`))];
 code(gate(bound),0);
 code(gate(["--tool","codex"]),1);
 const other = path.join(scratch,"old-run.json.last.txt");fs.writeFileSync(other,JSON.stringify(approved));
 const wrong=[...bound];wrong[3]=other;code(gate(wrong),1);
 fs.writeFileSync(`${file}.last.txt`,JSON.stringify({...approved,summary:"An older review"}));code(gate(bound),1);
 fs.unlinkSync(`${file}.last.txt`);code(gate(bound),1);
 fs.writeFileSync(`${file}.last.txt`,JSON.stringify(approved));
 for(const text of ["not JSONL\n",JSON.stringify({type:"turn.failed"})+"\n",stream+JSON.stringify({type:"error"})+"\n"]) {
  fs.writeFileSync(file,text);const invalid=[...bound];invalid[5]=digest(fs.readFileSync(file));code(gate(invalid),1);
 }
 // Assurance presets (spec 0021) share one enforcement rule; without a preset nothing changes.
 write({...approved,verdict:"request_changes"});
 const legacyText=evaluate({file},"").message.split("\n").at(-1);
 assert.equal(legacyText,"gate: advisory — approval requirements not met","legacy advisory text is unchanged");
 const standard=evaluate({file},"","standard");
 assert.equal(standard.code,0,"standard keeps an advisory gate");
 assert.match(standard.message,/gate: advisory \(preset standard\) — approval requirements not met; an advisory exit is not approval/);
 assert.equal(evaluate({file},"1","standard").code,1,"a stricter GATE_ENFORCE=1 applies under standard");
 assert.equal(evaluate({file},"","strict").code,1,"strict enforces without GATE_ENFORCE");
 assert.equal(evaluate({file},"1","strict").code,1);
 const conflict=evaluate({file},"0","strict");
 assert.equal(conflict.code,2);assert.match(conflict.message,/E_GATE_CONFLICT/);
 assert.equal(evaluate({file},"yes","standard").code,2,"invalid GATE_ENFORCE stays an error under a preset");
 assert.doesNotMatch(evaluate({file},"","light").message,/not approval/,"light requires no review, so no approval note");
 write(approved);assert.equal(evaluate({file},"","strict").code,0,"strict accepts a valid approval");
 console.log("PASS: strict review schema, advisory/enforced settings, current-run hashes, and Codex sidecar identity; preset enforcement (advisory standard, enforced strict, GATE_ENFORCE=0 conflict)");
} finally { fs.rmSync(scratch,{recursive:true,force:true}); }
NODE
