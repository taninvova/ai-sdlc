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
fs.writeFileSync(path.join(payload,"tasks/review.md"),"Return exactly one review JSON object.");
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
 // make review and make ai TASK=review run the same review task under the same model, and stay
 // distinct: only the make target selects the change and gates the verdict. TASK=check, the
 // deprecated name, runs TASK=review and says so; a models.yaml that still maps check: is read as review.
 const modelArg=(args,flag)=>args.flatMap((arg,i)=>arg===flag?[args[i+1]]:[]);
 const direct=(task,extra)=>spawnSync("make",["-f","ai-factory/make/ai.mk","ai",`TASK=${task}`],{cwd:root,env:{...env,INPUT:"direct review input",...extra},encoding:"utf8"});
 const logTasks=()=>fs.readFileSync(path.join(payload,"runs/log.csv"),"utf8").trim().split("\n").slice(1).map(row=>row.split(",")[5]);
 for(const key of ["review","check"]){
  fs.writeFileSync(path.join(payload,"models.yaml"),`claude:\ncodex:\nreview: review/default\nrouting:\n  enabled: true\n  tasks:\n    ${key}:\n      codex: gateway/review-codex\n`);
  for(const [tool,flag,expected] of [["codex","-m","gateway/review-codex"],["claude","--model","review/default"]]){
   const reviewed=review({TOOL:tool});ok(reviewed);
   assert.deepEqual(modelArg(capture().at(-1).args,flag),[expected],`make review ${tool} (${key}:)`);
   assert.match(capture().at(-1).input,/Review scope: working-tree/);
   assert.match(reviewed.stdout+reviewed.stderr,/gate: /,"make review gates the verdict");
   const prompt=capture().at(-1).input;
   for(const task of ["review","check"]){
    const ran=direct(task,{TOOL:tool});ok(ran);
    assert.deepEqual(modelArg(capture().at(-1).args,flag),[expected],`make ai TASK=${task} ${tool} (${key}:)`);
    assert.equal(reviewed.stderr.match(/model: .*\n/)[0],ran.stderr.match(/model: .*\n/)[0]);
    assert.match(ran.stderr,/model: review \//,`TASK=${task} selects the review task`);
    const taskPrompt=capture().at(-1).input;
    assert.ok(taskPrompt.startsWith("Return exactly one review JSON object.")&&taskPrompt.endsWith("direct review input"),`TASK=${task} runs tasks/review.md on the supplied input`);
    assert.ok(!/Review scope:/.test(taskPrompt)&&/Review scope:/.test(prompt),"TASK=review selects no change: that is the make review target's job");
    assert.doesNotMatch(ran.stdout+ran.stderr,/gate: /,`TASK=${task} is not gated`);
    if(task==="check")assert.match(ran.stderr,/runner: TASK=check is deprecated; running TASK=review/);
    else assert.doesNotMatch(ran.stderr,/deprecated/);
    assert.equal(logTasks().at(-1),"review",`TASK=${task} logs the review task`);
   }
  }
 }
 assert.notEqual(review({TOOL:"codex",FAKE_VERDICT:"request_changes"}).status,0,"routing must not change gate enforcement");
 // worktree-excluded (spec 0022 AC38): /t4:loop's kept worktrees under ai-factory/runs/tmp/worktrees/
 // add no selected path and no content, under the template's ignore rules and with that subtree un-ignored.
 const selectedPaths=input=>/Selected paths: (.*)/.exec(input)[1];
 const worktrees=path.join(payload,"runs/tmp/worktrees");
 fs.rmSync(input,{force:true});
 for(const [label,ignore] of [["template ignore",fs.readFileSync(path.join(repo,"skills/ai-layout/templates/ai-factory/.gitignore"),"utf8")],["subtree not ignored","/runs/*\n!/runs/tmp/\n/runs/tmp/*\n!/runs/tmp/worktrees/\n"]]){
  fs.writeFileSync(path.join(payload,".gitignore"),ignore);
  ok(review());const before=capture().at(-1).input;
  const name=`L1-S${label.length}`;const tree=path.join(worktrees,name);
  git(["worktree","add","-q","-b",`t4-loop/L1/${name}`,tree,"HEAD"]);
  fs.writeFileSync(path.join(tree,"committed.txt"),"worktree tracked marker\n");
  fs.writeFileSync(path.join(tree,"worktree only.txt"),"worktree untracked marker\n");
  fs.mkdirSync(path.join(worktrees,"plain"),{recursive:true});fs.writeFileSync(path.join(worktrees,"plain/left.txt"),"worktree leftover marker\n");
  try{
   ok(review());const after=capture().at(-1).input;
   assert.equal(selectedPaths(after),selectedPaths(before),`${label}: a populated worktree subtree changed the selected paths`);
   assert.ok(!/runs\/tmp\/worktrees/.test(selectedPaths(after)),`${label}: a worktree path was selected`);
   for(const marker of ["worktree tracked marker","worktree untracked marker","worktree leftover marker"])assert.ok(!after.includes(marker),`${label}: review read ${marker}`);
  }finally{git(["worktree","remove","--force",tree]);git(["branch","-D",`t4-loop/L1/${name}`]);fs.rmSync(worktrees,{recursive:true,force:true});}
 }
 assert.equal(git(["worktree","list","--porcelain"]).match(/^worktree /gm).length,1,"no fixture worktree left");
 console.log("PASS: empty, staged, unstaged, untracked, mixed, branch, supplied, Codex, failed and concurrent review scopes; index/worktree preserved; make review and make ai TASK=review (and deprecated TASK=check) share the routed review model and stay distinct; loop worktrees under ai-factory/runs/tmp/worktrees/ excluded");
}finally{fs.rmSync(scratch,{recursive:true,force:true});}})().catch(error=>{console.error(error);process.exitCode=1;});
NODE
