#!/usr/bin/env bash
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
 const configure=body=>fs.writeFileSync(path.join(payload,"models.yaml"),body);
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
 console.log("PASS: both tools honor explicit override, explicit blank inheritance, review/tool defaults, missing config, and literal gateway aliases");
} finally {fs.rmSync(scratch,{recursive:true,force:true});}
NODE
