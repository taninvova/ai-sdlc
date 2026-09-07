#!/usr/bin/env bash
# Exercises manifest.js against a throwaway adopted repo and a throwaway copy of the plugin,
# so upstream edits can be simulated without touching this one.
set -euo pipefail
cd "$(dirname "$0")/../../.."   # repo root
M=skills/ai-layout/scripts/manifest.js
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
REPO=$TMP/app; PLUG=$TMP/plugin
fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -q -- "$2" "$1" || fail "expected \"$2\" in output:$(printf '\n'; cat "$1")"; }
hasnt() { if grep -q -- "$2" "$1"; then fail "did not expect \"$2\" in output:$(printf '\n'; cat "$1")"; fi; }

# A copy of the plugin we may edit, and a repo "adopted" from it (placeholders substituted,
# exactly as /t4:adopt-sdlc does — this is what makes the two-hash design necessary).
mkdir -p "$PLUG" "$REPO"
cp -R .claude-plugin skills "$PLUG/"
cp -R "$PLUG/skills/ai-layout/templates/." "$REPO/"
sed -i '' 's/{{app}}/demo/g; s/{{stack}}/node/g; s/{{owner}}/dev/g' "$REPO/ai/AGENTS.md"
mkdir -p "$REPO/ai/runs"; : > "$REPO/ai/runs/log.csv"

echo "== write =="
node "$M" write "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "wrote ai/.sdlc.json"
[ -f "$REPO/ai/.sdlc.json" ] || fail "no manifest written"
node -e 'const m=require(process.argv[1]);
  if(m.schema!==1||m.plugin!=="ai-sdlc")throw new Error("bad header");
  const f=m.files["ai/AGENTS.md"];
  if(!f||!f.received||!f.template)throw new Error("both hashes required");
  if(f.received===f.template)throw new Error("substituted file must differ from its template");
  if(Object.keys(m.files).some(k=>k.startsWith("ai/runs/")))throw new Error("ai/runs must be skipped");
' "$REPO/ai/.sdlc.json"

echo "== clean check =="
node "$M" check "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "up to date"
hasnt "$TMP/o" "upstream changed"

echo "== locally modified =="
echo "a local rule" >> "$REPO/ai/docs/coding-standards.md"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"
has "$TMP/o" "locally modified (1)"; has "$TMP/o" "ai/docs/coding-standards.md"
has "$TMP/o" "up to date with upstream"

echo "== upstream changed =="
echo "an upstream rule" >> "$PLUG/skills/ai-layout/templates/ai/tasks/spec.md"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"
has "$TMP/o" "upstream changed (1)"; has "$TMP/o" "ai/tasks/spec.md"

echo "== both changed =="
echo "x" >> "$PLUG/skills/ai-layout/templates/ai/tasks/plan.md"
echo "y" >> "$REPO/ai/tasks/plan.md"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"
has "$TMP/o" "both changed (1)"; has "$TMP/o" "ai/tasks/plan.md"

echo "== new upstream / removed upstream / missing locally =="
echo "new" > "$PLUG/skills/ai-layout/templates/ai/tasks/brandnew.md"
rm "$PLUG/skills/ai-layout/templates/ai/tasks/chore.md"
rm "$REPO/ai/tasks/fix.md"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"
has "$TMP/o" "new upstream (1)";    has "$TMP/o" "ai/tasks/brandnew.md"
has "$TMP/o" "removed upstream (1)"; has "$TMP/o" "ai/tasks/chore.md"
has "$TMP/o" "missing locally (1)";  has "$TMP/o" "ai/tasks/fix.md"

echo "== version drift is surfaced =="
node -e 'const f=process.argv[1],p=require("fs");const j=JSON.parse(p.readFileSync(f));j.version="0.0.1";p.writeFileSync(f,JSON.stringify(j))' "$REPO/ai/.sdlc.json"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "versions differ"

echo "== check never mutates the repo =="
BEFORE=$(find "$REPO" -type f -exec shasum {} \; | sort | shasum)
node "$M" check "$REPO" "$PLUG" > /dev/null
[ "$BEFORE" = "$(find "$REPO" -type f -exec shasum {} \; | sort | shasum)" ] || fail "check modified the repo"

echo "== no manifest: migration path, not an error =="
rm "$REPO/ai/.sdlc.json"
sed -i '' 's/Scaffolded with ai-sdlc {{plugin_version}}/Scaffolded with ai-sdlc 0.4.0/' "$REPO/ai/AGENTS.md" 2>/dev/null || true
node "$M" check "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "adopted before manifests existed"
has "$TMP/o" "manifest.js"

echo "== manifest newer than the plugin =="
node "$M" write "$REPO" "$PLUG" > /dev/null
node -e 'const f=process.argv[1],p=require("fs");const j=JSON.parse(p.readFileSync(f));j.schema=99;p.writeFileSync(f,JSON.stringify(j))' "$REPO/ai/.sdlc.json"
node "$M" check "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "newer than the plugin"

echo "== the plugin repo itself never gets a manifest =="
node "$M" write . . > "$TMP/o"; has "$TMP/o" "ai-sdlc plugin itself"
[ -f ai/.sdlc.json ] && fail "a manifest was written into the plugin repo"

echo "manifest ok — write, all six drift states, version drift, read-only, migration, schema guard"
