#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
node skills/ai-layout/scripts/materialize-agents.js --check
# No project pointer is generated for an agent the plugin ships, so the plugin's own copy is what
# runs — and it must hand over to the repo's copy, which is where the Project additions live.
for agent in agents/*.md; do
  name=$(basename "$agent" .md)
  grep -qF "ai-factory/agents/$name.md" "$agent" \
    || { echo "FAIL: $agent never defers to ai-factory/agents/$name.md — a repo's Project additions would be ignored" >&2; exit 1; }
done
node <<'NODE'
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { adopt } = require('./skills/ai-layout/scripts/adopt');
const root = process.cwd(), base = path.join(root, 'ai-factory/runs/tmp');
fs.mkdirSync(base, {recursive:true});
const tmp = fs.mkdtempSync(path.join(base, 'workspace-'));
let cases = 0;
function snapshot(dir) {
 const result = {};
 function walk(at) { for (const ent of fs.readdirSync(at,{withFileTypes:true})) {
  const file = path.join(at,ent.name), rel=path.relative(dir,file);
  if (rel==='ai-factory') continue;
  if (ent.isDirectory()) walk(file);
  else result[rel]=ent.isSymbolicLink()?fs.readlinkSync(file):fs.readFileSync(file,'utf8');
 }} walk(dir); return result;
}
function sync(repo,...args) { return spawnSync(process.execPath,[path.join(repo,'ai-factory/make/sync-adapters.js'),...args],{cwd:repo,encoding:'utf8'}); }
try {
 for (const kind of ['node','python','docs']) {
  const repo=path.join(tmp,kind);fs.mkdirSync(repo);
  for(const name of ['AGENTS.md','CLAUDE.md','Makefile','.gitignore','.gitattributes']) fs.writeFileSync(path.join(repo,name),`user-owned ${name}\n`);
  if(kind==='node')fs.writeFileSync(path.join(repo,'package.json'),JSON.stringify({scripts:{test:'node --test'},packageManager:'npm@10'}));
  if(kind==='python')fs.writeFileSync(path.join(repo,'pyproject.toml'),'[project]\nname="fixture"\n');
  const before=snapshot(repo); adopt(repo,root,'Fixture Owner');
  assert.deepEqual(snapshot(repo),before);cases++;
  const instructions=fs.readFileSync(path.join(repo,'ai-factory/AGENTS.md'),'utf8');
  assert(!instructions.includes('{{'));assert(!instructions.includes('pnpm'));cases++;
  const manifest=JSON.parse(fs.readFileSync(path.join(repo,'ai-factory/.sdlc.json')));
  assert(Object.keys(manifest.files).every(f=>f.startsWith('ai-factory/')));cases++;
  for(const name of fs.readdirSync(path.join(root,'agents')))if(name.endsWith('.md')) {
   const canonical=fs.readFileSync(path.join(root,'agents',name),'utf8').trimEnd();
   assert(fs.readFileSync(path.join(repo,'ai-factory/agents',name),'utf8').startsWith(canonical));
  }cases++;
  for(let i=0;i<2;i++){const result=sync(repo);assert.equal(result.status,0,result.stderr);assert.deepEqual(snapshot(repo),before);}cases++;
  assert.throws(()=>adopt(repo,root),'existing workspace must refuse');cases++;
 }
 const repo=path.join(tmp,'node');
 const selected=sync(repo,'--adapters=codex');assert.equal(selected.status,0,selected.stderr);
 assert(!fs.existsSync(path.join(repo,'.claude')));assert(!fs.existsSync(path.join(repo,'.cursor')));cases++;
 const first=snapshot(repo);assert.equal(sync(repo,'--adapters=codex').status,0);assert.deepEqual(snapshot(repo),first);cases++;
 const owned=path.join(repo,'.codex/skills/t4-run/SKILL.md');fs.writeFileSync(owned,'A hand-authored skill.\n');
 const beforeCollision=snapshot(repo);assert.notEqual(sync(repo,'--adapters=codex').status,0);assert.deepEqual(snapshot(repo),beforeCollision);assert.equal(fs.readFileSync(owned,'utf8'),'A hand-authored skill.\n');cases++;
 const claudeRepo=path.join(tmp,'docs');fs.mkdirSync(path.join(claudeRepo,'.claude/commands'),{recursive:true});
 const custom=path.join(claudeRepo,'.claude/commands/custom.md');const customText='My own instructions\n@../../ai-factory/tasks/run.md\nKeep this content.\n';fs.writeFileSync(custom,customText);
 assert.equal(sync(claudeRepo,'--adapters=claude').status,0);assert.equal(fs.readFileSync(custom,'utf8'),customText);cases++;
 // The plugin registers its own agents as t4:<name>; a pointer would put a second agent with the
 // same role in the picker, so none is generated for them. An agent this project added is the
 // opposite case — the pointer is the only thing that makes it selectable.
 for(const name of fs.readdirSync(path.join(root,'agents')))if(name.endsWith('.md'))
  assert(!fs.existsSync(path.join(claudeRepo,'.claude/agents',name)),`${name} duplicates the plugin's own t4:${path.basename(name,'.md')}`);
 cases++;
 const projectAgent=path.join(claudeRepo,'ai-factory/agents/domain-expert.md');
 fs.writeFileSync(projectAgent,'---\nname: domain-expert\ndescription: Project agent, not shipped by the plugin\n---\nProcedure.\n');
 assert.equal(sync(claudeRepo,'--adapters=claude').status,0);
 const projectPointer=fs.readFileSync(path.join(claudeRepo,'.claude/agents/domain-expert.md'),'utf8');
 assert(projectPointer.includes('name: domain-expert')&&projectPointer.includes('Read ai-factory/agents/domain-expert.md'));
 fs.unlinkSync(projectAgent);
 assert.equal(sync(claudeRepo,'--adapters=claude').status,0);
 assert(!fs.existsSync(path.join(claudeRepo,'.claude/agents/domain-expert.md')),'a removed project agent must not leave its pointer behind');
 cases++;
 const outside=path.join(tmp,'outside');fs.mkdirSync(outside);
 fs.symlinkSync(outside,path.join(repo,'.claude'));
 assert.notEqual(sync(repo,'--adapters=claude').status,0);assert.deepEqual(fs.readdirSync(outside),[]);cases++;
 const manifestFile=path.join(claudeRepo,'ai-factory/.sdlc.json');
const manifestSaved=fs.readFileSync(manifestFile,'utf8');
const manifestOutside=path.join(tmp,'manifest-outside');fs.writeFileSync(manifestOutside,'manifest sentinel');
fs.unlinkSync(manifestFile);fs.symlinkSync(manifestOutside,manifestFile);
const rejectedManifest=spawnSync(process.execPath,[path.join(root,'skills/ai-layout/scripts/manifest.js'),'write',claudeRepo,root],{encoding:'utf8'});
assert.notEqual(rejectedManifest.status,0,'manifest writer must refuse a symlink');
assert.equal(fs.readFileSync(manifestOutside,'utf8'),'manifest sentinel');cases++;
fs.unlinkSync(manifestFile);fs.writeFileSync(manifestFile,manifestSaved);
const sharedAdapter=path.join(claudeRepo,'.claude/commands/t4/spec.md');
const adapterOutside=path.join(tmp,'adapter-outside');
const sharedBody=fs.readFileSync(sharedAdapter,'utf8')+'External sentinel must survive.\n';
fs.writeFileSync(adapterOutside,sharedBody);fs.unlinkSync(sharedAdapter);fs.linkSync(adapterOutside,sharedAdapter);
const beforeShared=snapshot(claudeRepo);
assert.notEqual(sync(claudeRepo,'--adapters=claude').status,0,'adapter generator must refuse a hard link');
assert.equal(fs.readFileSync(adapterOutside,'utf8'),sharedBody);
assert.deepEqual(snapshot(claudeRepo),beforeShared);cases++;
console.log(`workspace ok — ${cases} cases: strict adoption, complete agents, manifest ownership, idempotence, explicit adapters and collision protection`);
}finally{fs.rmSync(tmp,{recursive:true,force:true});}
NODE
