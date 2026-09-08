#!/usr/bin/env bash
# Pins doctor.sh against four repos whose answers are known by construction.
#
# The environment checks read the machine, so a fixture cannot be "healthy" on a machine where
# this plugin happens not to be installed for a scratch directory. Every case therefore runs
# against a synthetic CLAUDE_CONFIG_DIR built here — that makes the result the same on any
# machine and lets the install and cache branches be exercised deliberately rather than
# whenever the developer's own setup happens to hit them.
set -uo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."
ROOT=$PWD
DOCTOR=skills/ai-layout/scripts/doctor.sh
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# A config dir where the plugin IS installed at user scope, with exactly one cached copy.
NAME=$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
CFG=$TMP/config; mkdir -p "$CFG/plugins/cache/sdlc/$NAME/$VER"
printf '{"version":2,"plugins":{"%s@sdlc":[{"scope":"user","installPath":"x","version":"%s"}]}}\n' \
  "$NAME" "$VER" > "$CFG/plugins/installed_plugins.json"

# Builds a repo carrying the current layout. $1 = name.
make_repo() {
  # The whole template tree, not just ai/ — the manifest tracks every template file, so a
  # fixture copying half of them reads as a repo five files behind.
  local d=$TMP/$1; mkdir -p "$d"
  cp -R skills/ai-layout/templates/. "$d/"
  ( cd "$d" && bash "$ROOT/ai/make/sync-adapters.sh" >/dev/null 2>&1 )
  echo "$d"
}
# CLAUDE_PLUGIN_ROOT is what a session sets; without it the source check is correctly unknown,
# which would make every fixture noisy for a reason that has nothing to do with the fixture.
run() { CLAUDE_CONFIG_DIR="$CFG" CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/$DOCTOR" "$1" "$ROOT" 2>&1; }

# 1. no layout at all -----------------------------------------------------------------------
mkdir -p "$TMP/bare"
out=$(run "$TMP/bare"); st=$?
[ "$st" = 0 ] || fail "doctor exited $st on a repo with no layout; it must always exit 0"
grep -q '^\[finding\] layout .*no ai/ directory' <<<"$out" || fail "no-layout repo did not report the layout finding:
$out"
grep -q 'adopt-sdlc' <<<"$out" || fail "the layout finding carries no remedy (AC9)"

# 2. layout, but no manifest ----------------------------------------------------------------
d=$(make_repo nomanifest)
out=$(run "$d")
grep -q '^\[unknown\] version .*no ai/.sdlc.json' <<<"$out" || fail "missing manifest was not reported as unknown:
$out"
grep -q 'manifest.js.*write' <<<"$out" || fail "the missing-manifest finding does not name the baseline command (AC6)"

# 3. behind the templates -------------------------------------------------------------------
# Written from the current templates, then one entry dropped from the manifest — the template
# file it described now looks like one added upstream since this repo adopted.
d=$(make_repo behind)
node skills/ai-layout/scripts/manifest.js write "$d" "$ROOT" >/dev/null 2>&1 \
  || fail "could not write a manifest for the drift fixture"
node -e '
const fs=require("fs"),p=process.argv[1]+"/ai/.sdlc.json";
const m=JSON.parse(fs.readFileSync(p,"utf8"));
const k=Object.keys(m.files)[0]; delete m.files[k];
fs.writeFileSync(p,JSON.stringify(m,null,2));' "$d"
out=$(run "$d")
grep -q '^\[finding\] drift' <<<"$out" || fail "a repo behind the templates reported no drift finding:
$out"
grep -q 'sync-sdlc' <<<"$out" || fail "the drift finding carries no remedy (AC9)"

# 4. healthy ---------------------------------------------------------------------------------
d=$(make_repo healthy)
node skills/ai-layout/scripts/manifest.js write "$d" "$ROOT" >/dev/null 2>&1 \
  || fail "could not write a manifest for the healthy fixture"
out=$(run "$d")
grep -q '^summary: 0 finding(s), 0 unknown' <<<"$out" \
  || fail "a healthy repo reported something (AC11 wants one clean line):
$out"
grep -q '^\[finding\]' <<<"$out" && fail "healthy repo produced a finding:
$out"

# 5. the config dir is absent — Codex, or a machine with no plugins ---------------------------
# One unknown between install and cache, not one per check, and nothing else disturbed.
out=$(CLAUDE_CONFIG_DIR=$TMP/nope bash "$ROOT/$DOCTOR" "$d" "$ROOT" 2>&1); st=$?
[ "$st" = 0 ] || fail "doctor exited $st with no config dir; it must always exit 0"
[ "$(grep -c '^\[unknown\] install' <<<"$out")" = 1 ] || fail "absent config dir should report exactly one install unknown:
$out"
grep -q '^\[finding\]' <<<"$out" && fail "an absent config dir must not invent findings:
$out"

echo "doctor ok — 5 cases: no layout, no manifest, behind, healthy, no config dir"
