#!/usr/bin/env bash
# The documents that record the 1.0.0 rename and tell a repo what to do about it. Three of them,
# each carrying a clause a later edit can quietly drop:
#
#   ai-factory/adr/0008     the decision, the blast radius, the bounded exception to
#                           /t4:sync-sdlc's rule that taking an upstream change is a separate
#                           reviewable edit, and the two removal versions (AC8, AC24);
#   CHANGELOG.md            its top entry: breaking, run the migration, the hooks keep working
#                           meanwhile, grep your own CI, and the same deprecation notice
#                           (AC21, AC24);
#   commands/sync-sdlc.md   the branch that stops a repo which has not migrated, instead of
#                           syncing adapters out of a directory the prompts no longer name (AC17).
#
# None of this reads well as a grep over a whole file, so every assertion is scoped to the section
# that must carry it: the CHANGELOG's top entry rather than the file, whose released 0.2x entries
# name the same command; one bullet of the sync prompt rather than the prompt, which names the
# migration in three places; the ADR's own sections rather than the ADR.
#
# And every assertion that pairs two facts runs over sentences, not lines. Prose wraps, so a clause
# and the fact it carries routinely sit on different lines — and the pairing that matters most here,
# which transitional piece goes in which version, survives a whole-file grep for both numbers even
# when the two have been SWAPPED.
#
# What this does NOT do: prove the sync prompt behaves this way under a model. That is a run
# transcript, per the coding standards. It proves the branch is there, reachable before the two
# things it exists to prevent, and says the three things AC17 requires.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."
fail() { echo "FAIL: $*" >&2; exit 1; }

# The subject of these documents is the pre-1.0.0 layout, so this file never spells that
# directory: where a pattern needs it, it is assembled. check-paths.sh scans this file too.
OLD=ai

# The lines under the first "## " heading matching $2, up to the next one, heading included.
section() { awk -v h="$2" '/^## /{inside = ($0 ~ h)} inside' "$1"; }

# Bold markers dropped, newlines folded, one sentence per line — see the header.
sentences() { tr '\n' ' ' | sed -E 's/\*\*//g' | sed -E 's/([.!?]) +/\1\n/g'; }
says() {  # says <text> <extended-regex> <what is missing>
  printf '%s\n' "$1" | sentences | grep -qiE "$2" || fail "$3"
}

# --- 1. ADR 0008 — the decision and its bounds (AC8, AC24) ------------------------------------
ADRS=(ai-factory/adr/0008-*.md)
[ "${#ADRS[@]}" = 1 ] \
  || fail "expected exactly one ai-factory/adr/0008-*.md recording the rename, found ${#ADRS[@]}"
ADR=${ADRS[0]}
adr=$(cat "$ADR")

grep -qE '^Date: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$ADR" \
  || fail "$ADR carries no Date: line — an undated decision cannot be placed in the sequence"
for h in Context Decision Consequences; do
  grep -qE "^## $h" "$ADR" || fail "$ADR has no \"## $h\" section"
done

# The decision itself: one directory, and the three paths that stay outside it.
dec=$(section "$ADR" '^## Decision')
[ -n "$dec" ] || fail "$ADR's Decision section is empty"
for p in 'ai-factory/' 'ai-factory/specs/' 'ai-factory/adr/'; do
  grep -qF -- "$p" <<<"$dec" \
    || fail "$ADR's Decision does not say that $p is where the loop's files live"
done
for r in AGENTS.md CLAUDE.md Makefile; do
  grep -qF -- "$r" <<<"$dec" \
    || fail "$ADR's Decision does not name $r as one of the three paths that stay at the repo root"
done

# The blast radius, and why it is not silent.
con=$(section "$ADR" '^## Consequences')
[ -n "$con" ] || fail "$ADR's Consequences section is empty"
says "$con" 'breaking' \
  "$ADR's Consequences does not say the change is breaking for every adopted repo"
says "$con" '/t4:migrate-layout' \
  "$ADR's Consequences does not name /t4:migrate-layout as the move an adopted repo makes"
says "$con" 'hooks[^.]*(work|accept|keep|still)' \
  "$ADR's Consequences does not say the hooks keep working until a repo migrates — the reason nothing breaks silently in between"

# The exception this decision makes to the sync rule, and what bounds it (AC24).
exc=$(section "$ADR" '[Ee]xception')
[ -n "$exc" ] \
  || fail "$ADR records no exception to /t4:sync-sdlc's rule that taking an upstream change is a separate reviewable edit — the migration rewrites a repo's own prompts and that has to be recorded"
says "$exc" 'sync-sdlc.*reviewable' \
  "$ADR does not attribute the separate-reviewable-edit rule to /t4:sync-sdlc, so what the exception is an exception TO is not recorded"
says "$exc" 'path strings' \
  "$ADR does not bound the exception to path strings — unbounded, it is /t4:sync-sdlc in disguise"
says "$exc" '(no longer exist|does not exist|orphan)' \
  "$ADR does not record why the exception is taken: without the rewrite the move leaves every prompt in the repo pointing at a directory that is gone"

# Both transitional pieces, and they do not expire together (AC24).
says "$adr" 'transitional' \
  "$ADR does not record /t4:migrate-layout and the hooks' fallback as transitional"
says "$adr" '(command|migrate-layout)[^.]*1\.1\.0' \
  "$ADR does not say that /t4:migrate-layout goes in 1.1.0"
says "$adr" 'fallback[^.]*2\.0\.0' \
  "$ADR does not say that the hooks' fallback is kept until 2.0.0 — dropping it sooner is itself a silent break"

# --- 2. CHANGELOG, top entry only (AC21, AC24) ------------------------------------------------
top=$(awk '/^## /{n++} n==1' CHANGELOG.md)
[ -n "$top" ] || fail "CHANGELOG.md has no versioned entry"
ver=$(sed -E -n '1s/^## +([^ ]+).*/\1/p' <<<"$top")
[ -n "$ver" ] \
  || fail "CHANGELOG.md's top entry does not begin with a version: $(head -1 <<<"$top")"
lines=$(grep -c '' <<<"$top")
[ "$lines" -ge 10 ] \
  || fail "CHANGELOG.md's $ver entry is $lines lines — too short to carry what a breaking release must say"

# check-versions.sh proves the manifests agree with each other; this ties the entry to them, so a
# release cannot ship a version the changelog does not describe.
pv=$(node -e 'const fs=require("fs");process.stdout.write(String(JSON.parse(fs.readFileSync(".claude-plugin/plugin.json","utf8")).version||""))')
[ -n "$pv" ] || fail ".claude-plugin/plugin.json carries no version"
[ "$ver" = "$pv" ] \
  || fail "CHANGELOG.md's top entry is $ver but .claude-plugin/plugin.json is $pv — the release the manifests ship is not the one the changelog describes"

says "$top" 'breaking' \
  "CHANGELOG.md's $ver entry does not mark the change breaking"
says "$top" '(run|in each|each repo)[^.]*/t4:migrate-layout' \
  "CHANGELOG.md's $ver entry does not tell an adopted repo to run /t4:migrate-layout"
says "$top" 'hooks[^.]*(accept|keep)[^.]*(guard|log)' \
  "CHANGELOG.md's $ver entry does not say the hooks keep working in the meantime — with the dont-touch guard and the run log they carry"
says "$top" 'grep[^.]*(CI|pipeline|tooling)' \
  "CHANGELOG.md's $ver entry does not tell the developer to grep their own CI, pipeline and tooling config — paths the plugin cannot see and does not touch"
says "$top" '(command|migrate-layout)[^.]*1\.1\.0' \
  "CHANGELOG.md's $ver entry does not carry the deprecation notice for /t4:migrate-layout, removed in 1.1.0"
says "$top" 'fallback[^.]*2\.0\.0' \
  "CHANGELOG.md's $ver entry does not carry the deprecation notice for the hooks' fallback, kept until 2.0.0"

# --- 3. /t4:sync-sdlc stops a repo that has not migrated (AC17) -------------------------------
SYNC=commands/sync-sdlc.md
[ -f "$SYNC" ] || fail "$SYNC is missing"

# The bullet that detects the old layout: from the line naming its tasks directory to the next
# bullet, so nothing the rest of the prompt says can satisfy the three assertions below.
branch=$(awk -v pat="$OLD/tasks/" '
  !f && index($0, pat) { f = 1; print; next }
  f && /^[[:space:]]*- / { exit }
  f { print }
' "$SYNC")
[ -n "$branch" ] \
  || fail "$SYNC has no branch for a repo still on the pre-1.0.0 layout — it would generate adapters from a directory the prompts no longer name, and report drift on every path at once"
says "$branch" '/t4:migrate-layout' \
  "$SYNC's old-layout branch does not point at /t4:migrate-layout"
grep -q 'STOP' <<<"$branch" \
  || fail "$SYNC's old-layout branch does not STOP — the prompt carries on and syncs anyway"
says "$branch" '(not sync|without syncing|instead of syncing)' \
  "$SYNC's old-layout branch does not say that it must not sync"

# ...and the stop is reachable before the two things it exists to prevent.
line_of() { grep -n -- "$1" "$SYNC" | head -1 | cut -d: -f1 || true; }
b=$(line_of "$OLD/tasks/"); s=$(line_of 'sync-adapters.sh'); m=$(line_of 'manifest.js')
[ -n "$b" ] && [ -n "$s" ] && [ -n "$m" ] \
  || fail "$SYNC: cannot locate all three of the branch (${b:-none}), the adapter run (${s:-none}) and the drift report (${m:-none})"
[ "$b" -lt "$s" ] \
  || fail "$SYNC tells the session to run the adapters (line $s) before it checks for the old layout (line $b)"
[ "$b" -lt "$m" ] \
  || fail "$SYNC tells the session to report drift (line $m) before it checks for the old layout (line $b)"

# --- 4. a template may not cite an ADR by path (AC7) ------------------------------------------
# `see ai-factory/adr/0007` is a path, and inside an adopted repo it resolves to THAT repo's ADR 7 —
# nothing today, and something unrelated the moment they write their seventh. The number identifies
# an ai-sdlc decision the reader cannot open locally either way, so the plugin is named instead and
# the path dropped. The rename did not introduce this; it did not fix it either, until now.
cites=$(grep -rn "ai-factory/adr/[0-9]" skills/ai-layout/templates/ 2>/dev/null | grep -v "0000-template" || true)
[ -z "$cites" ] || fail "a template cites an ADR by path; inside an adopted repo that path is its own ADR directory. Name the plugin instead — \"ai-sdlc's ADR 0007\":
$cites"

# --- 5. nothing invokes the migration (AC13) ---------------------------------------------------
# Recommending /t4:migrate-layout is what doctor.sh, sync-sdlc.md and the release notes are for.
# Invoking migrate-layout.sh is the thing that must never happen on its own: it moves directories.
# The two are told apart by which name is used — the command, or the script.
callers=$(grep -rln "migrate-layout\.sh" \
  commands/ hooks/ ai-factory/tasks/ skills/ai-layout/templates/ agents/ 2>/dev/null \
  | grep -v "^commands/migrate-layout\.md$" || true)
[ -z "$callers" ] || fail "something other than its own command names migrate-layout.sh — a prompt or hook that can invoke it is a directory move nobody asked for:
$callers"

echo "release docs ok — ${ADR#ai-factory/adr/} records the decision, the bounded exception and both removal versions; CHANGELOG $ver matches the manifests and carries breaking, the migration, the fallback and the CI warning; /t4:sync-sdlc stops an unmigrated repo before it syncs or reports drift; no template cites an ADR by path; nothing but its own command names the migration script"
