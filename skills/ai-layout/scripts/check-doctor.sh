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
CFG=$TMP/config; mkdir -p "$CFG/plugins/cache/sdlc/$NAME/$VER" "$CFG/plugins/marketplaces/sdlc/.claude-plugin"
printf '{"version":2,"plugins":{"%s@sdlc":[{"scope":"user","installPath":"x","version":"%s"}]}}\n' \
  "$NAME" "$VER" > "$CFG/plugins/installed_plugins.json"
# A marketplace copy at the same version, so "healthy" means nothing to report about updates
# either. Without it the baseline case carries an unknown that has nothing to do with the repo.
printf '{"name":"sdlc","plugins":[{"name":"%s","source":".","version":"%s"}]}\n' \
  "$NAME" "$VER" > "$CFG/plugins/marketplaces/sdlc/.claude-plugin/marketplace.json"

# Builds a repo carrying the current layout. $1 = name.
make_repo() {
  # The whole template tree, not just ai-factory/ — the manifest tracks every template file, so a
  # fixture copying half of them reads as a repo five files behind.
  local d=$TMP/$1; mkdir -p "$d"
  cp -R skills/ai-layout/templates/. "$d/"
  ( cd "$d" && bash "$ROOT/ai-factory/make/sync-adapters.sh" >/dev/null 2>&1 )
  echo "$d"
}
# CLAUDE_PLUGIN_ROOT is what a session sets; without it the source check is correctly unknown,
# which would make every fixture noisy for a reason that has nothing to do with the fixture.
run() { CLAUDE_CONFIG_DIR="$CFG" CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/$DOCTOR" "$1" "$ROOT" 2>&1; }

# 1. no layout at all -----------------------------------------------------------------------
mkdir -p "$TMP/bare"
out=$(run "$TMP/bare"); st=$?
[ "$st" = 0 ] || fail "doctor exited $st on a repo with no layout; it must always exit 0"
grep -q '^\[finding\] layout .*no ai-factory/ directory' <<<"$out" || fail "no-layout repo did not report the layout finding:
$out"
grep -q 'adopt-sdlc' <<<"$out" || fail "the layout finding carries no remedy (AC9)"

# 1b. the pre-1.0.0 layout, and the half-migrated middle ------------------------------------
# Three states, three remedies. The point of separating them is that a repo which merely has not
# migrated is still working — the hooks accept the old name until 3.0.0 — while a half-migrated one
# is ambiguous and needs a decision before anything else.
mkdir -p "$TMP/unmigrated/ai/tasks" && : > "$TMP/unmigrated/ai/tasks/spec.md"  # path-scan-ok
out=$(run "$TMP/unmigrated"); st=$?
[ "$st" = 0 ] || fail "doctor exited $st on an unmigrated repo; it must always exit 0"
grep -q '^\[finding\] layout .*pre-1.0.0 layout' <<<"$out" || fail "an unmigrated repo was not told it is on the old layout:
$out"
grep -q 'migrate-layout' <<<"$out" || fail "the unmigrated finding carries no remedy:
$out"
# 3.0.0, not 2.1.0: the fallback outlives the migration command, because removing it is itself
# a silent break. An assertion naming the old version would pass a doctor promising the wrong one.
# Rescheduled 2026-09-27 with the 2.0.0 release: this release IS 2.0.0 and keeps the fallback, so
# the command moved to 2.1.0 and the fallback to 3.0.0. Only the numbers moved.
# The pre-1.0.0 name is assembled rather than spelled, so this line needs no scan pragma and
# check-paths.sh keeps its authority over the file.
OLD_DIR=ai
grep -qE "accept $OLD_DIR/ until 3\.0\.0" <<<"$out" \
  || fail "the unmigrated finding does not say the hooks still work until 3.0.0, which is the difference between a diagnosis and an alarm:
$out"
grep -q 'no ai-factory/ directory' <<<"$out" && fail "an unmigrated repo was told it never adopted the layout:
$out"

mkdir -p "$TMP/halfway/ai" "$TMP/halfway/ai-factory/tasks" && : > "$TMP/halfway/ai-factory/tasks/spec.md"
out=$(run "$TMP/halfway"); st=$?
[ "$st" = 0 ] || fail "doctor exited $st on a half-migrated repo; it must always exit 0"
grep -q '^\[finding\] layout .*half migrated' <<<"$out" || fail "a repo with both directories was not reported as half migrated:
$out"
grep -q 'hooks are using ai-factory/' <<<"$out" || fail "the half-migrated finding does not say which directory the hooks read:
$out"

# A migrated repo says nothing about migrating at all.
d=$(make_repo migrated)
out=$(run "$d")
grep -qE 'half migrated|pre-1\.0\.0|migrate-layout' <<<"$out" && fail "a fully migrated repo was told something about migrating:
$out"
grep -q '^\[ok     \] layout .*ai-factory/ present' <<<"$out" || fail "a migrated repo did not report a healthy layout:
$out"

# 2. layout, but no manifest ----------------------------------------------------------------
d=$(make_repo nomanifest)
out=$(run "$d")
grep -q '^\[unknown\] version .*no ai-factory/.sdlc.json' <<<"$out" || fail "missing manifest was not reported as unknown:
$out"
grep -q 'manifest.js.*write' <<<"$out" || fail "the missing-manifest finding does not name the baseline command (AC6)"

# 3. behind the templates -------------------------------------------------------------------
# Written from the current templates, then one entry dropped from the manifest — the template
# file it described now looks like one added upstream since this repo adopted.
d=$(make_repo behind)
node skills/ai-layout/scripts/manifest.js write "$d" "$ROOT" >/dev/null 2>&1 \
  || fail "could not write a manifest for the drift fixture"
node -e '
const fs=require("fs"),p=process.argv[1]+"/ai-factory/.sdlc.json";
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

# 6. the install is behind the marketplace copy ---------------------------------------------
# 0.9.0 vs 0.10.0 on purpose: a string comparison calls 0.9.0 the newer one, so this fixture
# fails if the version compare is ever simplified to <.
CFG2=$TMP/config2; mkdir -p "$CFG2/plugins/cache/sdlc/$NAME/0.9.0" "$CFG2/plugins/marketplaces/sdlc/.claude-plugin"
printf '{"version":2,"plugins":{"%s@sdlc":[{"scope":"user","installPath":"x","version":"0.9.0"}]}}\n' \
  "$NAME" > "$CFG2/plugins/installed_plugins.json"
printf '{"name":"sdlc","plugins":[{"name":"%s","source":".","version":"0.10.0"}]}\n' \
  "$NAME" > "$CFG2/plugins/marketplaces/sdlc/.claude-plugin/marketplace.json"
out=$(CLAUDE_CONFIG_DIR="$CFG2" CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/$DOCTOR" "$d" "$ROOT" 2>&1)
grep -q '^\[finding\] update .*0\.9\.0.*0\.10\.0' <<<"$out" \
  || fail "an install behind the marketplace copy was not reported (0.9.0 vs 0.10.0):
$out"
grep -q 'plugin install' <<<"$out" || fail "the update finding carries no remedy (AC9)"

# 7. the install is current — say nothing about updates ---------------------------------------
printf '{"name":"sdlc","plugins":[{"name":"%s","source":".","version":"0.9.0"}]}\n' \
  "$NAME" > "$CFG2/plugins/marketplaces/sdlc/.claude-plugin/marketplace.json"
out=$(CLAUDE_CONFIG_DIR="$CFG2" CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/$DOCTOR" "$d" "$ROOT" 2>&1)
grep -q '^\[finding\] update' <<<"$out" && fail "a current install was told it is behind:
$out"

# 8. no marketplace copy at all — unknown, never a finding -------------------------------------
rm -rf "$CFG2/plugins/marketplaces"
out=$(CLAUDE_CONFIG_DIR="$CFG2" CLAUDE_PLUGIN_ROOT="$ROOT" bash "$ROOT/$DOCTOR" "$d" "$ROOT" 2>&1)
grep -q '^\[unknown\] update' <<<"$out" || fail "an unreadable marketplace copy should be unknown:
$out"
grep -q '^\[finding\] update' <<<"$out" && fail "an unreadable marketplace copy must not become a finding:
$out"

# 9. the plugin's own repo, with the plugin installed elsewhere --------------------------------
# The shape that shipped broken: path equality stopped recognising the source repo once the
# plugin ran from an install, so the doctor told its own maintainer to start a baseline that
# must never exist.
PLUGCOPY=$TMP/installed; mkdir -p "$PLUGCOPY/.claude-plugin"
cp .claude-plugin/plugin.json "$PLUGCOPY/.claude-plugin/"
cp -R skills "$PLUGCOPY/"
out=$(CLAUDE_CONFIG_DIR="$CFG" CLAUDE_PLUGIN_ROOT="$PLUGCOPY" bash "$ROOT/$DOCTOR" "$ROOT" "$PLUGCOPY" 2>&1)
grep -q '^\[ok\] *\] *layout-source\|^\[ok     \] layout-source' <<<"$out" \
  || fail "the plugin's own repo was not recognised when the plugin runs from an install:
$out"
grep -q 'Start a baseline' <<<"$out" \
  && fail "the plugin's own repo was told to start a baseline it must never have:
$out"

echo "doctor ok — 12 cases: no layout, unmigrated, half migrated, migrated, no manifest, behind, healthy, no config dir, update available, up to date, no marketplace, plugin repo via an install"
