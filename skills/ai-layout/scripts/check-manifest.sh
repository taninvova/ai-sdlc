#!/usr/bin/env bash
# Exercises manifest.js against a throwaway adopted repo and a throwaway copy of the plugin,
# so upstream edits can be simulated without touching this one.
set -euo pipefail
cd "$(dirname "$0")/../../.."   # repo root
# Disposable fixtures stay in the project workspace, including default mktemp calls.
export TMPDIR="$PWD/ai-factory/runs/tmp"
mkdir -p "$TMPDIR"
M=skills/ai-layout/scripts/manifest.js
TMP=$(mktemp -d)
# A failing assertion exits before any inline cleanup, so a test that provokes a manifest into
# this repo would leave it behind. The trap is the only place that reliably runs.
HAD_MANIFEST=$([ -f ai-factory/.sdlc.json ] && echo yes || echo no)
trap 'rm -rf "$TMP"; [ "$HAD_MANIFEST" = no ] && rm -f ai-factory/.sdlc.json' EXIT
REPO=$TMP/app; PLUG=$TMP/plugin
fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -q -- "$2" "$1" || fail "expected \"$2\" in output:$(printf '\n'; cat "$1")"; }
hasnt() { if grep -q -- "$2" "$1"; then fail "did not expect \"$2\" in output:$(printf '\n'; cat "$1")"; fi; }

# A copy of the plugin we may edit, and a repo "adopted" from it (placeholders substituted,
# exactly as /t4:adopt-sdlc does — this is what makes the two-hash design necessary).
mkdir -p "$PLUG" "$REPO"
cp -R .claude-plugin skills "$PLUG/"
cp -R "$PLUG/skills/ai-layout/templates/." "$REPO/"
sed -i '' 's/{{app}}/demo/g; s/{{stack}}/node/g; s/{{owner}}/dev/g' "$REPO/ai-factory/AGENTS.md"
mkdir -p "$REPO/ai-factory/runs"; : > "$REPO/ai-factory/runs/log.csv"

echo "== write =="
node "$M" write "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "wrote ai-factory/.sdlc.json"
[ -f "$REPO/ai-factory/.sdlc.json" ] || fail "no manifest written"
node -e 'const m=require(process.argv[1]);
  if(m.schema!==1||m.plugin!=="ai-sdlc")throw new Error("bad header");
  const f=m.files["ai-factory/AGENTS.md"];
  if(!f||!f.received||!f.template)throw new Error("both hashes required");
  if(f.received===f.template)throw new Error("substituted file must differ from its template");
  if(Object.keys(m.files).some(k=>k.startsWith("ai-factory/runs/")))throw new Error("ai-factory/runs must be skipped");
' "$REPO/ai-factory/.sdlc.json"

echo "== start adoption and drift preserve local work =="
node - "$REPO" "$PLUG" "$TMP" "$M" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const [fresh, plugin, tmp, manifest] = process.argv.slice(2);
const task = 'ai-factory/tasks/start.md';
assert.ok(fs.existsSync(path.join(fresh, task)), 'fresh adoption includes start');
assert.ok(JSON.parse(fs.readFileSync(path.join(fresh,'ai-factory/.sdlc.json'))).files[task], 'manifest discovers start');
for (const file of ['ai-factory/tasks/continue.md', 'ai-factory/make/continue.js', 'ai-factory/make/delivery-status.js', 'ai-factory/make/assurance.js']) {
 assert.ok(fs.existsSync(path.join(fresh, file)), `fresh adoption includes ${file}`);
 assert.ok(JSON.parse(fs.readFileSync(path.join(fresh,'ai-factory/.sdlc.json'))).files[file], `manifest discovers ${file}`);
}
function snapshot(root) {
 return fs.readdirSync(root, {withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name)).map(e => {
  const file = path.join(root,e.name);
  return [e.name,e.isDirectory() ? snapshot(file) : fs.readFileSync(file).toString('base64')];
 });
}
for (const mode of ['older', 'modified']) {
 const repo = path.join(tmp, `start-${mode}`);
 fs.cpSync(fresh,repo,{recursive:true});
 if (mode === 'older') {
  fs.unlinkSync(path.join(repo, task));
  const file = path.join(repo,'ai-factory/.sdlc.json');
  const value = JSON.parse(fs.readFileSync(file)); delete value.files[task]; fs.writeFileSync(file,JSON.stringify(value));
 } else fs.appendFileSync(path.join(repo,task),'\nLocal classification rule.\n');
 fs.writeFileSync(path.join(repo,'untracked-user-note'),'preserve me');
 const before = snapshot(repo);
 const result = spawnSync(process.execPath,[manifest,'check',repo,plugin],{encoding:'utf8'});
 assert.equal(result.status,0,result.stderr);
 assert.match(result.stdout,/ai-factory\/tasks\/start\.md/);
 assert.match(result.stdout,mode === 'older' ? /new upstream/ : /locally modified/);
 assert.deepEqual(snapshot(repo),before,'drift inspection changed user files or generated adapters');
 for (const host of ['.claude','.codex','.cursor']) assert.equal(fs.existsSync(path.join(repo,host)),false);
}
NODE

echo "== clean check =="
node "$M" check "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "up to date"
hasnt "$TMP/o" "upstream changed"

echo "== assurance selection, local configuration and evidence stay the adopter's =="
# Opt-in presets: adoption ships no selection; check and a manifest rewrite neither track nor touch
# ai-factory/assurance.json, a customized contracts configuration or recorded evidence.
[ ! -e "$REPO/ai-factory/assurance.json" ] || fail "adoption selected an assurance preset"
SEL=$TMP/selected; cp -R "$REPO" "$SEL"
mkdir -p "$SEL/ai-factory/contracts" "$SEL/ai-factory/evidence/d-20260101-abcdef"
printf '{"schema":"t4-assurance","version":1,"preset":"standard"}\n' > "$SEL/ai-factory/assurance.json"
printf '{"schema":"t4-contracts-config","version":1,"code_scope":{"include":["src/**"],"exclude":[]},"completion":{"require_review_quick":true}}\n' > "$SEL/ai-factory/contracts/config.json"
printf '{"recorded":true}\n' > "$SEL/ai-factory/evidence/d-20260101-abcdef/final.json"
KEPT=$(cd "$SEL" && shasum ai-factory/assurance.json ai-factory/contracts/config.json ai-factory/evidence/d-20260101-abcdef/final.json)
BEFORE=$(find "$SEL" -type f -exec shasum {} \; | sort | shasum)
node "$M" check "$SEL" "$PLUG" > "$TMP/o"; has "$TMP/o" "up to date"
hasnt "$TMP/o" "assurance.json"; hasnt "$TMP/o" "ai-factory/evidence/"; hasnt "$TMP/o" "contracts/config.json"
[ "$BEFORE" = "$(find "$SEL" -type f -exec shasum {} \; | sort | shasum)" ] || fail "check modified a repo with a preset selected"
node "$M" write "$SEL" "$PLUG" > /dev/null
[ "$KEPT" = "$(cd "$SEL" && shasum ai-factory/assurance.json ai-factory/contracts/config.json ai-factory/evidence/d-20260101-abcdef/final.json)" ] || fail "a manifest rewrite changed the selection, configuration or evidence"
node -e 'const m=require(process.argv[1]);
  for(const k of Object.keys(m.files))if(k==="ai-factory/assurance.json"||k.startsWith("ai-factory/evidence/")||k==="ai-factory/contracts/config.json")throw new Error(`manifest tracks adopter-owned ${k}`);
  if(!m.files["ai-factory/make/assurance.js"])throw new Error("manifest does not track the assurance helper");
' "$SEL/ai-factory/.sdlc.json"

echo "== locally modified =="
echo "a local rule" >> "$REPO/ai-factory/docs/coding-standards.md"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"
has "$TMP/o" "locally modified (1)"; has "$TMP/o" "ai-factory/docs/coding-standards.md"
has "$TMP/o" "up to date with upstream"

echo "== upstream changed =="
echo "an upstream rule" >> "$PLUG/skills/ai-layout/templates/ai-factory/tasks/spec.md"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"
has "$TMP/o" "upstream changed (1)"; has "$TMP/o" "ai-factory/tasks/spec.md"

echo "== both changed =="
echo "x" >> "$PLUG/skills/ai-layout/templates/ai-factory/tasks/plan.md"
echo "y" >> "$REPO/ai-factory/tasks/plan.md"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"
has "$TMP/o" "both changed (1)"; has "$TMP/o" "ai-factory/tasks/plan.md"

echo "== new upstream / removed upstream / missing locally =="
echo "new" > "$PLUG/skills/ai-layout/templates/ai-factory/tasks/brandnew.md"
rm "$PLUG/skills/ai-layout/templates/ai-factory/tasks/chore.md"
rm "$REPO/ai-factory/tasks/fix.md"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"
has "$TMP/o" "new upstream (1)";    has "$TMP/o" "ai-factory/tasks/brandnew.md"
has "$TMP/o" "removed upstream (1)"; has "$TMP/o" "ai-factory/tasks/chore.md"
has "$TMP/o" "missing locally (1)";  has "$TMP/o" "ai-factory/tasks/fix.md"

echo "== version drift is surfaced =="
node -e 'const f=process.argv[1],p=require("fs");const j=JSON.parse(p.readFileSync(f));j.version="0.0.1";p.writeFileSync(f,JSON.stringify(j))' "$REPO/ai-factory/.sdlc.json"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "versions differ"

echo "== check never mutates the repo =="
BEFORE=$(find "$REPO" -type f -exec shasum {} \; | sort | shasum)
node "$M" check "$REPO" "$PLUG" > /dev/null
[ "$BEFORE" = "$(find "$REPO" -type f -exec shasum {} \; | sort | shasum)" ] || fail "check modified the repo"

echo "== no manifest: migration path, not an error =="
rm "$REPO/ai-factory/.sdlc.json"
sed -i '' 's/Scaffolded with ai-sdlc {{plugin_version}}/Scaffolded with ai-sdlc 0.4.0/' "$REPO/ai-factory/AGENTS.md" 2>/dev/null || true
node "$M" check "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "adopted before manifests existed"
has "$TMP/o" "manifest.js"

echo "== manifest newer than the plugin =="
node "$M" write "$REPO" "$PLUG" > /dev/null
node -e 'const f=process.argv[1],p=require("fs");const j=JSON.parse(p.readFileSync(f));j.schema=99;p.writeFileSync(f,JSON.stringify(j))' "$REPO/ai-factory/.sdlc.json"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "newer than the plugin"

echo "== the plugin repo itself never gets a manifest =="
node "$M" write . . > "$TMP/o"; has "$TMP/o" "ai-sdlc plugin itself"
[ -f ai-factory/.sdlc.json ] && { rm -f ai-factory/.sdlc.json; fail "a manifest was written into the plugin repo"; }

echo "== ...including when the plugin runs from an install elsewhere =="
# The case the check above cannot see. It passes repo-root and plugin-root as the same path,
# which is only true when the plugin is loaded from its working tree. Once it is installed,
# plugin-root is the cache, the two differ, and a path comparison stops recognising the source
# repo — so a manifest was written into it. $PLUG is a copy of this plugin, which is exactly
# the shape of an install.
node "$M" write . "$PLUG" > "$TMP/o-installed" 2>&1; has "$TMP/o-installed" "ai-sdlc plugin itself"
[ -f ai-factory/.sdlc.json ] && { rm -f ai-factory/.sdlc.json; fail "a manifest was written into the plugin repo when the plugin ran from an install"; }

# --- an unmigrated repo is told to migrate, not that it predates manifests --------------------
# MANIFEST moved to ai-factory/.sdlc.json in 1.0.0, so a 0.27.1 repo's own manifest is invisible to
# it. Left alone, check reports "adopted before manifests existed" — false — and then recommends a
# baseline write that refuses, and an adopt that would scaffold a second layout. One short-circuit
# replaces all three, and this is what keeps it there.
OLD=$TMP/unmigrated; mkdir -p "$OLD/ai/docs" "$OLD/specs" "$OLD/docs/adr"  # path-scan-ok
printf '# x\n' > "$OLD/ai/AGENTS.md"  # path-scan-ok
printf '{"schema":1,"plugin":"ai-sdlc","version":"0.27.1","files":{"ai/AGENTS.md":{"received":"sha256:a","template":"sha256:b"}}}\n' > "$OLD/ai/.sdlc.json"  # path-scan-ok
out=$(node "$M" check "$OLD" .)
grep -q 'pre-1.0.0 layout' <<<"$out" || fail "an unmigrated repo was not told it is on the old layout:
$out"
grep -q 'migrate-layout' <<<"$out" || fail "an unmigrated repo was not pointed at the migration:
$out"
# 2.1.0 removed the command. Pointing at a slash command that is not installed is a dead end, and
# the only reason ADR 0008 allowed the removal in a minor is that an older checkout still has it.
grep -qE 'checkout at 2\.0\.0 or earlier' <<<"$out" \
  || fail "an unmigrated repo was pointed at /t4:migrate-layout without being told where to get it — 2.1.0 removed the command:
$out"
# ...and the fallback's own version, which outlives the command by a major.
grep -qE 'old directory name until 3\.0\.0' <<<"$out" \
  || fail "the unmigrated report does not say the hooks accept the old name until 3.0.0:
$out"
grep -q 'adopted before manifests existed' <<<"$out" && fail "an unmigrated repo with a 0.27.1 manifest was told it predates manifests:
$out"
grep -qE 'removed upstream|new upstream' <<<"$out" && fail "an unmigrated repo got a per-file drift report across the rename:
$out"

# write, by hand, in the same repo: it must not send a repo that HAS a layout to /t4:adopt-sdlc,
# which would scaffold a second one beside the first. cmdCheck short-circuits; cmdWrite is what a
# developer reaches by running the baseline command this file used to print.
out=$(node "$M" write "$OLD" . 2>&1 || true)
grep -q 'migrate-layout' <<<"$out" || fail "manifest write does not point an unmigrated repo at the migration:
$out"
grep -qE 'checkout at 2\.0\.0 or earlier' <<<"$out" \
  || fail "manifest write points at /t4:migrate-layout without saying where to get it — 2.1.0 removed the command:
$out"
grep -q 'adopt-sdlc first' <<<"$out" && fail "manifest write still sends an unmigrated repo to /t4:adopt-sdlc, which would add a second layout:
$out"
[ ! -f "$OLD/ai-factory/.sdlc.json" ] || fail "manifest write created a manifest in an unmigrated repo"

echo "manifest ok — write, all six drift states, version drift, read-only, migration, schema guard"
