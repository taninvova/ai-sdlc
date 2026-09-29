#!/usr/bin/env bash
# Exercises manifest.js against a throwaway adopted repo and a throwaway copy of the plugin,
# so upstream edits can be simulated without touching this one.
set -euo pipefail
cd "$(dirname "$0")/../../.."   # repo root
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

echo "== clean check =="
node "$M" check "$REPO" "$PLUG" > "$TMP/o"; has "$TMP/o" "up to date"
hasnt "$TMP/o" "upstream changed"

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
