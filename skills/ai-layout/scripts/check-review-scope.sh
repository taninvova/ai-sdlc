#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
node <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {spawn,spawnSync,execFileSync} = require("node:child_process");
const {boundary} = require("./skills/ai-layout/templates/ai-factory/make/safe-files.js");
const repo=process.cwd();
const safe=boundary(path.join(repo,"ai-factory"));
const scratch=safe.scratch(path.join(repo,"ai-factory/runs/tmp"));
const root=path.join(scratch,"project with spaces");
const payload=path.join(root,"ai-factory");
fs.mkdirSync(path.join(payload,"tasks"),{recursive:true});
fs.cpSync(path.join(repo,"skills/ai-layout/templates/ai-factory/make"),path.join(payload,"make"),{recursive:true});
fs.writeFileSync(path.join(payload,"tasks/check.md"),"Return exactly one review JSON object.");
fs.writeFileSync(path.join(payload,"models.yaml"),"claude:\ncodex:\nreview:\n");
fs.writeFileSync(path.join(payload,".gitignore"),"/runs/\n");
fs.writeFileSync(path.join(root,".gitignore"),".env\n");
const fake=path.join(payload,"fake cli");
fs.writeFileSync(fake,`#!/usr/bin/env node
const fs=require('node:fs');let input='';process.stdin.setEncoding('utf8');process.stdin.on('data',chunk=>input+=chunk);process.stdin.on('end',()=>{
 const args=process.argv.slice(2);fs.appendFileSync('ai-factory/runs/capture.jsonl',JSON.stringify({args,input})+'\\n');
 if(process.env.FAIL_CLI){process.exitCode=3;return;}
 const final=JSON.stringify({verdict:process.env.FAKE_VERDICT||'approve',findings:[],summary:'Fixture review'});
 setTimeout(()=>{if(args[0]==='exec') {fs.writeFileSync(args[args.indexOf('-o')+1],final);process.stdout.write(JSON.stringify({type:'turn.completed',usage:{input_tokens:1,output_tokens:1}})+'\\n');}else process.stdout.write(JSON.stringify({result:final,usage:{input_tokens:1,output_tokens:1}}));}, Number(process.env.DELAY||0));
});
`,{mode:0o700});
const env={...process.env,TOOL:"claude",CMD:fake,MODEL:"",INPUT:"",INPUT_FILE:"",GATE_ENFORCE:"1",REVIEW_SCOPE:"",MAKEFLAGS:"",MAKEOVERRIDES:""};
const args=["-f","ai-factory/make/ai.mk","review"];
function git(args){return execFileSync("git",args,{cwd:root,encoding:"utf8",stdio:["ignore","pipe","pipe"]});}
function write(file,body){fs.writeFileSync(path.join(root,file),body);}
function capture(){const file=path.join(payload,"runs/capture.jsonl");return fs.existsSync(file)?fs.readFileSync(file,"utf8").trim().split("\n").filter(Boolean).map(JSON.parse):[];}
function snapshot(){
 const hash=crypto.createHash("sha256");
 function walk(dir){for(const entry of fs.readdirSync(dir).sort()){const file=path.join(dir,entry);const relative=path.relative(root,file);if(relative===".git"||relative===path.join("ai-factory","runs"))continue;hash.update(relative);const stat=fs.lstatSync(file);if(stat.isDirectory())walk(file);else if(stat.isSymbolicLink())hash.update(fs.readlinkSync(file));else hash.update(fs.readFileSync(file));}}
 walk(root);hash.update(fs.readFileSync(path.join(root,".git/index")));return hash.digest("hex");
}
function review(extra={}){
 const before=snapshot();
 const result=spawnSync("make",args,{cwd:root,env:{...env,...extra},encoding:"utf8"});
 assert.equal(snapshot(),before,"review changed working files or the index");
 return result;
}
function ok(result){assert.equal(result.status,0,result.stderr||result.stdout);}
async function asyncReview(extra){return new Promise((resolve,reject)=>{const child=spawn("make",args,{cwd:root,env:{...env,...extra},stdio:["ignore","pipe","pipe"]});let out="";child.stdout.on("data",b=>out+=b);child.stderr.on("data",b=>out+=b);child.on("error",reject);child.on("close",status=>resolve({status,stdout:out}));});}
(async()=>{try{
 git(["init","-b","main"]);git(["config","user.name","Fixture"]);git(["config","user.email","fixture@example.invalid"]);
 for(const file of ["staged.txt","unstaged.txt","mixed.txt","committed.txt"])write(file,`original ${file}\n`);
 git(["add","."]);git(["commit","-m","baseline"]);git(["checkout","-b","feature"]);
 write("committed.txt","committed feature change\n");git(["add","committed.txt"]);git(["commit","-m","feature"]);
 const empty=review();ok(empty);assert.match(empty.stdout,/No selected changes/);assert.equal(capture().length,0);
 ok(review({REVIEW_SCOPE:"branch"}));assert.match(capture().at(-1).input,/committed feature change/);assert.match(capture().at(-1).input,/Selected paths: \["committed.txt"\]/);
 write("staged.txt","staged-only marker\n");git(["add","staged.txt"]);
 write("unstaged.txt","unstaged-only marker\n");write("mixed.txt","mixed staged marker\n");git(["add","mixed.txt"]);write("mixed.txt","mixed unstaged marker\n");
 write("new file.txt","untracked marker\n");write(".env","ignored secret must never be read\n");
 ok(review());const prompt=capture().at(-1).input;
 for(const marker of ["staged-only marker","unstaged-only marker","mixed staged marker","mixed unstaged marker","untracked marker"])assert.ok(prompt.includes(marker),marker);
 assert.ok(!prompt.includes("committed feature change"));assert.ok(!prompt.includes("ignored secret"));
 assert.match(prompt,/Selected paths: \["mixed.txt","new file.txt","staged.txt","unstaged.txt"\]/);
 const scopes=fs.readdirSync(path.join(payload,"runs")).filter(name=>name.endsWith(".scope.json")).map(name=>JSON.parse(fs.readFileSync(path.join(payload,"runs",name),"utf8")));
 assert.ok(scopes.some(scope=>scope.scope==="working-tree"&&scope.paths.includes("new file.txt")));
 ok(review({TOOL:"codex"}));assert.equal(capture().at(-1).args[0],"exec");
 ok(review({REVIEW_SCOPE:"branch"}));assert.ok(!capture().at(-1).input.includes("untracked marker"));assert.ok(capture().at(-1).input.includes("committed feature change"));
 const supplied="diff --git a/supplied.txt b/supplied.txt\n--- a/supplied.txt\n+++ b/supplied.txt\n@@ -1 +1 @@\n-old\n+supplied-only marker\n";
 const input=path.join(payload,"runs/supplied diff.txt");fs.writeFileSync(input,supplied);
 ok(review({INPUT_FILE:input,REVIEW_SCOPE:"branch"}));assert.match(capture().at(-1).input,/Review scope: supplied/);assert.ok(capture().at(-1).input.endsWith(supplied));assert.ok(!capture().at(-1).input.includes("staged-only marker"));
 const count=capture().length;assert.notEqual(review({REVIEW_SCOPE:"invalid"}).status,0);assert.equal(capture().length,count);
 assert.notEqual(review({FAIL_CLI:"1"}).status,0,"failed review reused older valid output");
 const concurrent=await Promise.all([asyncReview({TOOL:"codex",FAKE_VERDICT:"approve",DELAY:"150"}),asyncReview({TOOL:"codex",FAKE_VERDICT:"request_changes",DELAY:"30"})]);
 ok(concurrent[0]);assert.notEqual(concurrent[1].status,0,"concurrent review used another invocation's approval");
 assert.deepEqual(fs.readdirSync(path.join(payload,"runs/tmp")),[]);
 // make review and make ai TASK=check resolve the same task model; scope and gate are unchanged.
 fs.writeFileSync(path.join(payload,"models.yaml"),"claude:\ncodex:\nreview: review/default\nrouting:\n  enabled: true\n  tasks:\n    check:\n      codex: gateway/review-codex\n");
 const modelArg=(args,flag)=>args.flatMap((arg,i)=>arg===flag?[args[i+1]]:[]);
 const direct=extra=>spawnSync("make",["-f","ai-factory/make/ai.mk","ai","TASK=check"],{cwd:root,env:{...env,INPUT:"direct check",...extra},encoding:"utf8"});
 for(const [tool,flag,expected] of [["codex","-m","gateway/review-codex"],["claude","--model","review/default"]]){
  const reviewed=review({TOOL:tool});ok(reviewed);
  assert.deepEqual(modelArg(capture().at(-1).args,flag),[expected],`make review ${tool}`);
  assert.match(capture().at(-1).input,/Review scope: working-tree/);
  const checked=direct({TOOL:tool});ok(checked);
  assert.deepEqual(modelArg(capture().at(-1).args,flag),[expected],`make ai TASK=check ${tool}`);
  assert.equal(reviewed.stderr.match(/model: .*\n/)[0],checked.stderr.match(/model: .*\n/)[0]);
 }
 assert.notEqual(review({TOOL:"codex",FAKE_VERDICT:"request_changes"}).status,0,"routing must not change gate enforcement");
 console.log("PASS: empty, staged, unstaged, untracked, mixed, branch, supplied, Codex, failed and concurrent review scopes; index/worktree preserved; make review and make ai TASK=check share the routed check model");
}finally{fs.rmSync(scratch,{recursive:true,force:true});}})().catch(error=>{console.error(error);process.exitCode=1;});
NODE
