#!/usr/bin/env bash
# Moves an adopted repo from the pre-1.0.0 layout to ai-factory/: ai/ -> ai-factory/,
# specs/ -> ai-factory/specs/, docs/adr/ -> ai-factory/adr/, then rewrites the paths those files
# name, regenerates the adapters and refreshes the manifest.
#
# Runs in the developer's own repo, from its root, and only because they ran it. ADR 0002 stands:
# ai-sdlc keeps no registry of adopters and never reaches into one. Nothing here is committed —
# the move is staged for review, which is the whole point of it being a separate command.
#
# The rewrite is bounded to path strings (ADR 0008). It does not deliver new prompt text: taking
# an upstream change is /t4:sync-sdlc's job and a separate, reviewable edit. Without it, though,
# every prompt in the repo would point at a directory that no longer exists, so the move and the
# rewrite are one operation.
set -euo pipefail
shopt -s nullglob
PLUGIN=$(cd "$(dirname "$0")/../../.." && pwd)
refuse() { echo "migrate-layout: $*" >&2; exit 1; }

# --- refusals, all of them before the first write ------------------------------------------
git rev-parse --git-dir >/dev/null 2>&1 \
  || refuse "not a git repository. The move is made with git mv so that history follows the files."

nonempty() { [ -d "$1" ] && [ -n "$(ls -A "$1" 2>/dev/null)" ]; }

if [ ! -d ai ] && [ ! -d ai-factory ]; then
  refuse "no layout in this repo — neither ai/ nor ai-factory/ exists. Run /t4:adopt-sdlc to add one."
fi

# What is left to do, rather than "has ai/ gone". The difference matters: if a run dies between the
# first git mv and the rewrite — which one could, before the refusal below existed — then ai/ is gone
# while specs/ is still at the root and every prompt still names the old paths. Asking only about ai/
# reports that repo as finished and exits 0, which is a broken repo plus a false all-clear. Asking
# what is left makes the command resumable and keeps AC16: with nothing outstanding it still exits 0
# before any write, and it is checked before the clean-tree refusal because the first run leaves the
# tree dirty by design.
TODO=()
[ -d ai ] && TODO+=("ai/")
nonempty specs && TODO+=("specs/")
nonempty docs/adr && TODO+=("docs/adr/")
if [ ${#TODO[@]} -eq 0 ]; then
  echo "migrate-layout: nothing to move — this repo is already on ai-factory/."
  exit 0
fi

nonempty specs && nonempty ai-factory/specs \
  && refuse "both specs/ and ai-factory/specs/ hold files. Merge them by hand and run this again; guessing which copy wins is not this command's decision."
nonempty docs/adr && nonempty ai-factory/adr \
  && refuse "both docs/adr/ and ai-factory/adr/ hold files. Merge them by hand and run this again."
[ -d ai ] && [ -d ai-factory ] \
  && refuse "both ai/ and ai-factory/ exist — this repo is half migrated. Decide which is current, remove the other, and run this again."

# A directory holding nothing but untracked files cannot be moved with git mv — "fatal: source
# directory is empty" — and that fatal used to land AFTER ai/ had already been moved, wrecking the
# repo and leaving the next run to report success. Checked here, before anything is written, so the
# refusal keeps AC15's promise that a refusal moves and rewrites nothing. Moving such a directory
# with plain mv instead was the alternative and is worse: the files would be outside the commit, so
# the move would not be reviewable and no history would follow it.
for d in ai specs docs/adr; do
  if nonempty "$d" && [ -z "$(git ls-files -- "$d")" ]; then
    refuse "$d/ holds files but none of them is tracked, so git mv cannot move it and the move could not be reviewed as a commit. Commit them first (git add $d && git commit), or move $d/ by hand and run this again."
  fi
done

# Tracked changes only. The refusal exists so the move is reviewable as a commit of its own, and
# work in flight on a tracked file is what threatens that. An untracked file cannot affect git mv or
# the rewrite — and refusing for one is not theoretical: in testing, an MCP server created a scratch
# directory mid-session and blocked a migration for a reason that had nothing to do with the repo.
# It is still worth naming, because the `git add -A` in the second commit below would sweep it in.
TRACKED=$(git status --porcelain | grep -v '^??' || true)
UNTRACKED=$(git status --porcelain | grep '^??' || true)
[ -z "$TRACKED" ] || refuse "the working tree has uncommitted changes to tracked files. Commit or stash them first: this move touches every prompt in the repo, and it is only reviewable as a commit of its own.
$TRACKED"
if [ -n "$UNTRACKED" ]; then
  echo "migrate-layout: proceeding, but this repo has untracked files. They are no part of the move," >&2
  echo "  and the 'git add -A' in the second commit below would include them. Ignore or remove first" >&2
  echo "  if you do not want them in the release commit:" >&2
  printf '%s\n' "$UNTRACKED" | sed 's/^/    /' >&2
fi

# --- the move ------------------------------------------------------------------------------
MOVED=()
move_into() {          # move_into <src-dir> <dest-dir>
  local src=$1 dest=$2 f
  nonempty "$src" || return 0
  if [ -e "$dest" ]; then                       # dest exists but is empty — move the contents
    # -k skips what git cannot move rather than aborting; whatever it skipped is untracked, and a
    # plain mv brings it across so the directory is not left half emptied.
    for f in "$src"/* "$src"/.[!.]*; do git mv -k -- "$f" "$dest/"; done
    for f in "$src"/* "$src"/.[!.]*; do mv -- "$f" "$dest/"; done
    rmdir "$src" 2>/dev/null || true
  else
    git mv -- "$src" "$dest"
  fi
  MOVED+=("$src/ -> $dest/")
}

if [ -d ai ]; then
  git mv -- ai ai-factory
  MOVED+=("ai/ -> ai-factory/")
fi
move_into specs ai-factory/specs
move_into docs/adr ai-factory/adr
# docs/ goes only if it held nothing but adr/; a repo's own docs are not this command's business.
[ -d docs ] && [ -z "$(ls -A docs 2>/dev/null)" ] && { rmdir docs; MOVED+=("docs/ (empty, removed)"); }

# --- the rewrite: path strings only ---------------------------------------------------------
# Every file the layout now holds, plus the five root files that name it. Not ai-factory/runs/
# (log data), not the manifest (regenerated below), not anything git does not track.
FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(
  git ls-files -- ai-factory AGENTS.md CLAUDE.md Makefile .gitignore .gitattributes \
    | grep -vE '^ai-factory/(runs/|\.sdlc\.json$)' || true
)

REWRITTEN=$(node "$PLUGIN/skills/ai-layout/scripts/rewrite-paths.js" "${FILES[@]}")

# --- adapters and manifest ------------------------------------------------------------------
# Both of these can fail, and the report below must not claim either happened. An abort would be
# worse than a warning: the moves and rewrites have already been made, and a developer who sees no
# summary does not know what state the repo is in.
ADAPTERS=ok
if [ -f ai-factory/make/sync-adapters.sh ]; then
  bash ai-factory/make/sync-adapters.sh >/dev/null 2>&1 || ADAPTERS=failed
else
  ADAPTERS=absent
fi
MANIFEST_STATE=ok
node "$PLUGIN/skills/ai-layout/scripts/manifest.js" write . "$PLUGIN" >/dev/null 2>&1 || MANIFEST_STATE=failed

# Deliberately NOT staged beyond the moves. `git mv` has put pure renames in the index; the
# rewrite, the adapters and the manifest sit in the working tree on top of them. That split is the
# whole point: committed as one change, the move and the rewrite together drop each file below
# git's rename threshold and `git log --follow` stops at the migration — for any file whose path
# lines are a large share of its content, which many prompts and stubs are. Longer files survive one
# commit; two make the outcome independent of file size. The report below asks for that order.

# --- report: what moved and what was rewritten, kept apart ----------------------------------
echo "migrate-layout: done. Nothing has been committed — review and commit this as its own change."
echo
echo "moved (${#MOVED[@]}):"
printf '  %s\n' "${MOVED[@]}"
n=$([ -n "$REWRITTEN" ] && printf '%s\n' "$REWRITTEN" | wc -l | tr -d ' ' || echo 0)
echo
echo "rewritten — path strings only, no new prompt text ($n):"
[ "$n" = 0 ] || printf '%s\n' "$REWRITTEN" | sed 's/^/  /'
echo
case $ADAPTERS in
  ok)     echo "adapters regenerated." ;;
  absent) echo "adapters NOT regenerated — ai-factory/make/sync-adapters.sh is not in this repo. Run /t4:sync-sdlc." ;;
  failed) echo "adapters NOT regenerated — ai-factory/make/sync-adapters.sh failed. Run it directly to see why." ;;
esac
if [ "$MANIFEST_STATE" = ok ]; then
  echo "ai-factory/.sdlc.json refreshed."
else
  echo "ai-factory/.sdlc.json NOT refreshed — it still records pre-1.0.0 paths, so /t4:sync-sdlc will"
  echo "  report drift on every file until you run:"
  echo "  node \"$PLUGIN/skills/ai-layout/scripts/manifest.js\" write . \"$PLUGIN\""
fi
echo
echo "Commit it as TWO commits, in this order — that is what keeps file history:"
echo "  git commit -m 'ai(chore): move the layout to ai-factory/ (paths unchanged)'"
echo "  git add -A && git commit -m 'ai(chore): point the prompts at ai-factory/'"
echo "The first is staged already and is nothing but renames, so git log --follow keeps working."
echo "One commit instead risks it: git pairs a rename by similarity, so any file whose path lines are"
echo "most of its content — a short prompt, a stub — drops below the threshold and loses its history."
echo
echo "Take upstream prompt changes separately with /t4:sync-sdlc."
