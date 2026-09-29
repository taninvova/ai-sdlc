#!/usr/bin/env bash
# The documents that record the 1.0.0 rename and tell a repo what to do about it. Three of them,
# each carrying a clause a later edit can quietly drop:
#
#   ai-factory/adr/0008     the decision, the blast radius, the bounded exception to
#                           /t4:sync-sdlc's rule that taking an upstream change is a separate
#                           reviewable edit, and the two removal versions (AC8, AC24);
#   CHANGELOG.md            its 2.0.0 entry, found by version wherever that entry has drifted to
#                           in the file: breaking, run the migration, the hooks keep working
#                           meanwhile, grep your own CI, and the same deprecation notice
#                           (AC21, AC24). Of its TOP entry only what is true of every release —
#                           that there is one, and that it is the version the manifests ship;
#   commands/sync-sdlc.md   the branch that stops a repo which has not migrated, instead of
#                           syncing adapters out of a directory the prompts no longer name (AC17).
#
# None of this reads well as a grep over a whole file, so every assertion is scoped to the section
# that must carry it: the CHANGELOG's 2.0.0 entry rather than the file, whose 1.0.0 and released
# 0.2x entries name the same command — 1.0.0 with the removal versions 2.0.0 superseded; one
# bullet of the sync prompt rather than the prompt, which names the migration in three places; the
# ADR's own sections rather than the ADR.
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
says "$adr" '(command|migrate-layout)[^.]*2\.1\.0' \
  "$ADR does not say that /t4:migrate-layout goes in 2.1.0"
says "$adr" 'fallback[^.]*3\.0\.0' \
  "$ADR does not say that the hooks' fallback is kept until 3.0.0 — dropping it sooner is itself a silent break"

# --- 2. CHANGELOG (AC21, AC24) ----------------------------------------------------------------
# Two subjects in one file, and they are deliberately kept apart.
#
# The TOP entry is whatever release is being shipped right now, so the only things asserted of it
# are things true of EVERY release: that there is a versioned entry, that it begins with a version,
# and that the version is the one the manifests ship. Anything release-specific asserted here would
# fail the first release that is not that kind of release — which is precisely what "the top entry
# must say it is breaking and explain the rename" did to the first ordinary patch to land on top.
#
# The 2.0.0 entry is the rename RECORD — the same subject as ADR 0008 above — and it is found BY
# VERSION, wherever it has since drifted to in the file. The six statements below belong to that
# one entry permanently: five of the six are instructions for that one migration. Bound to "the top
# entry" the record's guard expired the moment a newer entry landed on top of it; bound to "any
# entry marked breaking" it would conscript every later breaking release — 3.0.0 dropping the
# fallback, say — into reciting 2.0.0's migration notes, which is a worse fault than the one it
# would fix. Bound to the version, the record stays pinned and a new release is simply not this
# section's business.
#
# Why 2.0.0 and not 1.0.0, where the rename actually shipped: 1.0.0's deprecation notices name
# 1.1.0 and 2.0.0, and the 2.0.0 entry revised both to 2.1.0 and 3.0.0. The current removal
# versions — the ones ADR 0008 and section 1 above assert — live in the 2.0.0 entry, so that is the
# entry that has to keep carrying them.
RENAME_ENTRY=2.0.0

# entry <version> — the lines under "## <version> …", up to the next "## " heading, heading
# included. Matched by prefix rather than as a regex so a version's dots stay literal, and "2.0.0 "
# rather than "2.0.0" so a 2.0.0-rc1 heading is not mistaken for it.
entry() {
  awk -v v="$1" '/^## /{ inside = ($0 == "## " v || index($0, "## " v " ") == 1) } inside' CHANGELOG.md
}

top=$(awk '/^## /{n++} n==1' CHANGELOG.md)
[ -n "$top" ] || fail "CHANGELOG.md has no versioned entry"
ver=$(sed -E -n '1s/^## +([^ ]+).*/\1/p' <<<"$top")
[ -n "$ver" ] \
  || fail "CHANGELOG.md's top entry does not begin with a version: $(head -1 <<<"$top")"

# check-versions.sh proves the manifests agree with each other; this ties the entry to them, so a
# release cannot ship a version the changelog does not describe.
pv=$(node -e 'const fs=require("fs");process.stdout.write(String(JSON.parse(fs.readFileSync(".claude-plugin/plugin.json","utf8")).version||""))')
[ -n "$pv" ] || fail ".claude-plugin/plugin.json carries no version"
[ "$ver" = "$pv" ] \
  || fail "CHANGELOG.md's top entry is $ver but .claude-plugin/plugin.json is $pv — the release the manifests ship is not the one the changelog describes"

# The record itself. An absent entry is the way a lookup by version fails silently — nothing left
# to assert against, and six assertions that pass over nothing — so it is the first thing checked.
rec=$(entry "$RENAME_ENTRY")
[ -n "$rec" ] \
  || fail "CHANGELOG.md has no \"## $RENAME_ENTRY\" entry — the rename record the six assertions below are written against is gone, and with it every clause they exist to hold in place"
lines=$(grep -c '' <<<"$rec")
[ "$lines" -ge 10 ] \
  || fail "CHANGELOG.md's $RENAME_ENTRY entry is $lines lines — too short to carry what a breaking release must say"

says "$rec" 'breaking' \
  "CHANGELOG.md's $RENAME_ENTRY entry does not mark the change breaking"
says "$rec" '(run|in each|each repo)[^.]*/t4:migrate-layout' \
  "CHANGELOG.md's $RENAME_ENTRY entry does not tell an adopted repo to run /t4:migrate-layout"
says "$rec" 'hooks[^.]*(accept|keep)[^.]*(guard|log)' \
  "CHANGELOG.md's $RENAME_ENTRY entry does not say the hooks keep working in the meantime — with the dont-touch guard and the run log they carry"
says "$rec" 'grep[^.]*(CI|pipeline|tooling)' \
  "CHANGELOG.md's $RENAME_ENTRY entry does not tell the developer to grep their own CI, pipeline and tooling config — paths the plugin cannot see and does not touch"
says "$rec" '(command|migrate-layout)[^.]*2\.1\.0' \
  "CHANGELOG.md's $RENAME_ENTRY entry does not carry the deprecation notice for /t4:migrate-layout, removed in 2.1.0"
says "$rec" 'fallback[^.]*3\.0\.0' \
  "CHANGELOG.md's $RENAME_ENTRY entry does not carry the deprecation notice for the hooks' fallback, kept until 3.0.0"

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

# --- 6. section 2's two bindings, proved in both directions -----------------------------------
# This is a release gate every adopted repo's release runs through, and section 2 now binds two
# groups of assertions to two different entries. A binding by version is the kind that stops
# checking anything without saying so — point it at an entry that is not there and six assertions
# pass over an empty string — so both directions are proved here rather than assumed.
#
# The fixtures are scratch repo roots under one temp dir. Each is this repo, symlinked path by
# path, with two exceptions it owns outright: `CHANGELOG.md`, which is the subject, and
# `.claude-plugin/`, copied so a fixture can name its own version without touching the real
# manifest. The script under test is then run through the scratch root's own `skills` symlink, so
# `cd "$(dirname "$0")/../../.."` lands in the fixture and every relative path it reads is the
# fixture's. Nothing here writes to this repo, and in particular nothing writes to its CHANGELOG.
#
# The seven one-statement cases — an intact record and the six with one clause each removed — are
# built from a purpose-made CHANGELOG rather than from this repo's, because each statement has to
# be removable ON ITS OWN: in the real 2.0.0 entry the words an assertion looks for recur in
# sentences that are about something else entirely, so "delete the statement" means deleting
# several unrelated paragraphs and the case stops proving which clause was lost. The real entry is
# proved instead by the case that matters most — case (a), where it sits below a newer entry and
# must still satisfy all six — and by this script's own run over this repo.
if [ -z "${RELEASE_DOCS_SELFTEST:-}" ]; then
  ROOT=$PWD
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

  # repo <name> — a scratch root, printed. Every path but the two it owns is this repo's.
  repo() {
    local d=$T/$1
    mkdir -p "$d"
    local p; for p in skills ai-factory commands agents hooks; do ln -s "$ROOT/$p" "$d/$p"; done
    cp -R "$ROOT/.claude-plugin" "$d/.claude-plugin"
    printf '%s' "$d"
  }
  # setver <root> <version> — what the fixture's manifests ship.
  setver() {
    node -e 'const fs=require("fs"),p=process.argv[1]+"/.claude-plugin/plugin.json";
      const j=JSON.parse(fs.readFileSync(p,"utf8")); j.version=process.argv[2];
      fs.writeFileSync(p, JSON.stringify(j,null,2)+"\n");' "$1" "$2"
  }
  # check <root> — the script under test, over one fixture. RELEASE_DOCS_SELFTEST stops the recursion.
  check() { RELEASE_DOCS_SELFTEST=1 bash "$1/skills/ai-layout/scripts/check-release-docs.sh" 2>&1; }
  # ok <what> <root>, and no <what> <root> <the message must name this>
  ok() {
    local out st; out=$(check "$2") && st=0 || st=$?
    [ "$st" = 0 ] || fail "self-test: $1 should pass, but the check exited $st:
$out"
  }
  no() {
    local out st; out=$(check "$2") && st=0 || st=$?
    [ "$st" != 0 ] || fail "self-test: $1 should have failed, but the check passed:
$out"
    grep -qF -- "$3" <<<"$out" || fail "self-test: $1 failed, but not for the reason it was built to fail.
  wanted the message to name: $3
  got:                        $out"
  }

  # (a) The case the old binding got wrong, and the whole reason for this section's shape: an
  # ordinary patch entry on top, with this repo's real 2.0.0 entry underneath it. Four lines long
  # and not breaking, so it proves the line floor and all six statements left the top entry — and
  # the entry below is the real record, not a sketch, so it proves the lookup finds that one.
  a=$(repo newer-on-top)
  { printf '# Changelog\n\n## 2.0.1 — 2026-10-01\n\n'
    printf 'A patch release. Nothing about the layout changes.\n'
    tail -n +2 "$ROOT/CHANGELOG.md"
  } > "$a/CHANGELOG.md"
  setver "$a" 2.0.1
  ok "an ordinary patch entry on top of the real 2.0.0 entry" "$a"

  # (b) The lookup's own failure mode: no 2.0.0 entry at all. This repo's CHANGELOG with that one
  # entry cut out, leaving 1.0.0 on top — an entry that names the migration and the hooks' fallback
  # too, with the removal versions 2.0.0 superseded. A binding that had quietly stopped resolving
  # would sail through this; it has to say the record is missing.
  b=$(repo no-record)
  awk -v v="$RENAME_ENTRY" '/^## /{ cut = ($0 == "## " v || index($0, "## " v " ") == 1) } !cut' \
    "$ROOT/CHANGELOG.md" > "$b/CHANGELOG.md"
  setver "$b" 1.0.0
  no "a CHANGELOG with the $RENAME_ENTRY entry removed" "$b" \
    "CHANGELOG.md has no \"## $RENAME_ENTRY\" entry"

  # (c) The top entry's one release-specific assertion still bites when the manifests disagree.
  c=$(repo version-drift)
  cp "$ROOT/CHANGELOG.md" "$c/CHANGELOG.md"
  setver "$c" 9.9.9
  no "a manifest version the changelog does not describe" "$c" \
    "the release the manifests ship is not the one the changelog describes"

  # (d) The six, one at a time. S1..S6 are the six statements, one line each, in the order section
  # 2 asserts them; no line satisfies any assertion but its own, so removing one names one.
  S1='**Breaking for every adopted repo.**'
  S2='Run `/t4:migrate-layout` once, in each repo.'
  S3='The hooks still accept the old directory name, so an unmigrated repo keeps its dont-touch guard and its run log.'
  S4='**Grep your own CI, pipeline config and tooling** for the old directory name.'
  S5='- `/t4:migrate-layout` — **removed in 2.1.0.**'
  S6="- The hooks' fallback to the old directory name — **kept until 3.0.0.**"
  # record <root> <statement to omit, or 0 for none> — the purpose-made CHANGELOG, written to
  # <root>. Fourteen lines with all six present, so every variant clears the ten-line floor and a
  # failure is never the floor's.
  record() {
    local d=$1 omit=$2 i v
    { printf '# Changelog\n\n## %s — 2026-09-27\n' "$RENAME_ENTRY"
      for i in 1 2 3 4 5 6; do
        [ "$i" = "$omit" ] && continue
        [ "$i" = 5 ] && printf '\n### Deprecated\n'
        v=S$i; printf '\n%s\n' "${!v}"
      done
    } > "$d/CHANGELOG.md"
  }
  base=$(repo record-intact); record "$base" 0
  ok "the purpose-made record with all six statements" "$base"

  wanted=(
    "does not mark the change breaking"
    "does not tell an adopted repo to run /t4:migrate-layout"
    "does not say the hooks keep working in the meantime"
    "does not tell the developer to grep their own CI"
    "does not carry the deprecation notice for /t4:migrate-layout, removed in 2.1.0"
    "does not carry the deprecation notice for the hooks' fallback, kept until 3.0.0"
  )
  for i in 1 2 3 4 5 6; do
    d=$(repo "record-without-$i"); record "$d" "$i"
    no "the record with statement $i removed" "$d" \
      "CHANGELOG.md's $RENAME_ENTRY entry ${wanted[i-1]}"
  done

  # (e) And the binding really did move: a complete, compliant entry on TOP cannot stand in for the
  # record below it. Without this the six could be reading the top entry again and every case above
  # would still pass.
  e=$(repo record-gutted-under-a-good-top)
  record "$e" 1
  { printf '# Changelog\n\n## 2.0.1 — 2026-10-01\n'
    for i in 1 2 3 4 5 6; do v=S$i; printf '\n%s\n' "${!v}"; done
    printf '\n'; tail -n +2 "$e/CHANGELOG.md"
  } > "$e/CHANGELOG.md.new"
  mv "$e/CHANGELOG.md.new" "$e/CHANGELOG.md"
  setver "$e" 2.0.1
  no "a compliant top entry over a $RENAME_ENTRY entry missing statement 1" "$e" \
    "CHANGELOG.md's $RENAME_ENTRY entry does not mark the change breaking"

  rm -rf "$T"; trap - EXIT
  SELFTEST_NOTE=" (and the CHANGELOG bindings proved over 11 scratch fixtures)"
fi

echo "release docs ok — ${ADR#ai-factory/adr/} records the decision, the bounded exception and both removal versions; CHANGELOG's top entry $ver is the version the manifests ship, and its $RENAME_ENTRY entry still carries breaking, the migration, the fallback and the CI warning wherever it now sits; /t4:sync-sdlc stops an unmigrated repo before it syncs or reports drift; no template cites an ADR by path; nothing but its own command names the migration script${SELFTEST_NOTE:-}"
