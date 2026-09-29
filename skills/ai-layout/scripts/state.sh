#!/usr/bin/env bash
# The scan behind /t4:state: lists this repo's outstanding specs and plans, one row per listed
# thing, and exits 0 whatever it finds. It reports only — it creates nothing, edits nothing and
# ticks nothing (AC8, AC9). The prompt renders these rows; it does not decide which items are
# outstanding (AC14).
#
# Usage: state.sh [repo-root] [plugin-root] [flag…]
#   repo-root   defaults to the current directory
#   plugin-root defaults to $CLAUDE_PLUGIN_ROOT, else the plugin this script lives in.
#               Accepted for symmetry with doctor.sh's signature; nothing under it is read.
#   flag        --done lists what is finished INSTEAD of what is outstanding. --next names the
#               one artefact to pick up — the most recently modified, by git commit date — as a
#               single row of the default listing plus one line saying why it was chosen. The
#               two do not compose: --done --next, in either order, is refused in one line.
#               A flag that is neither is named back in one line with the flags that exist.
#               Both answers exit 0 and print no rows — a refused result is an answer.
#
# Output: a tab-separated table — a header row, then one row per listed thing:
#
#   kind  number  state  path  step  detail
#
# One row builder, one sort and one header serve both listings: every artefact becomes a row
# carrying its state, and the flag chooses which states are printed. The two listings are
# therefore the same rows filtered two ways and cannot drift apart (plan 0010, Step 5).
#
# WHICH of those become table columns, in what order, and whether the table is sectioned by
# kind, is plan 0010's Ambiguity B and belongs to commands/state.md, not here. This script's
# contract is the FIELDS, not their presentation.
#
# A note on set -e: as in doctor.sh, this deliberately uses `set -uo pipefail` WITHOUT -e. One
# artefact that cannot be read or interpreted must not stop the others; it becomes an `unknown`
# row with a reason and every other artefact is still listed (AC12).
set -uo pipefail
shopt -s nullglob

# --- arguments ---------------------------------------------------------------------------
# Positional in doctor.sh's order, with flags accepted anywhere so `state.sh --done` from a
# terminal behaves the same as the prompt's `state.sh . "$CLAUDE_PLUGIN_ROOT" --done`.
#
# Each argument is classified as it is read rather than by matching the joined string, so
# `--done --next` and `--next --done` reach the same answer: order carries no meaning here.
REPO=""; PLUGIN=""; EXTRA=""; HAS_DONE=0; HAS_NEXT=0; UNKNOWN=""
for arg in "$@"; do
  case "$arg" in
    -*)
      EXTRA="${EXTRA:+$EXTRA }$arg"
      case "$arg" in
        --done) HAS_DONE=1 ;;
        --next) HAS_NEXT=1 ;;
        *)      UNKNOWN="${UNKNOWN:+$UNKNOWN }$arg" ;;
      esac ;;
    *)
      if   [ -z "$REPO" ];   then REPO=$arg
      elif [ -z "$PLUGIN" ]; then PLUGIN=$arg
      else EXTRA="${EXTRA:+$EXTRA }$arg"
           UNKNOWN="${UNKNOWN:+$UNKNOWN }$arg"
      fi ;;
  esac
done
: "$EXTRA"  # kept for readers of a trace; the classification above is what decides
REPO=${REPO:-.}
PLUGIN=${PLUGIN:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}}
: "$PLUGIN"  # read by nothing here; see the signature note above (AC14, AC15)

# MODE is the listing the flags ask for. --done replaces the default listing with the finished
# items rather than widening it to everything-with-a-state (plan 0010, Ambiguity C, answered
# 2026-09-29). --next narrows it to one row — the most recently modified artefact, by git commit
# date (Ambiguity A, answered 2026-09-29). The two do NOT compose (Ambiguity D, answered
# 2026-09-29): asked for together they are refused rather than silently reduced to one of them.
#
# Both refusals print ONE line and exit 0, and neither prints a row. A refused result is an
# answer, not a crash — the same treatment an unknown flag gets, and the reason /t4:state can be
# run before anyone knows what the repo holds.
#
# They are two messages, not one, because they are two situations. `--done --next` is a pair of
# flags that both exist and cannot be asked together; an unrecognised token is a flag that does
# not exist at all. Telling the first developer their flag is unknown would be false, and telling
# the second that --done and --next do not combine would diagnose a mistake they did not make.
# The fix differs too — drop one flag, as against correct a misspelt one — so the line that names
# the problem names the right one.
MODE=default
if [ -n "$UNKNOWN" ]; then
  # An unrecognised token: say what it is, and what this command does take. The rules for --done
  # and --next are settled and implemented, so this line no longer claims anything is undecided.
  echo "'$UNKNOWN' is not a flag /t4:state takes — it takes --done, which lists what is finished instead of what is outstanding, or --next, which names the single item to pick up next; with no flag at all it lists everything outstanding. Nothing was listed."
  exit 0
elif [ "$HAS_DONE" = 1 ] && [ "$HAS_NEXT" = 1 ]; then
  # Both flags, in either order. Neither wins: the combination is refused outright.
  echo "--done and --next do not combine — asking for both at once is not a meaningful question, so ask one at a time: --done lists what is finished instead of what is outstanding, and --next names the single item to pick up next. Nothing was listed."
  exit 0
elif [ "$HAS_DONE" = 1 ]; then
  MODE=done
elif [ "$HAS_NEXT" = 1 ]; then
  MODE=next
fi

[ -d "$REPO" ] || { echo "nothing to list — no such directory: $REPO"; exit 0; }
# Everything below is read relative to the repo root and nothing resolves above it, so a run in
# one repo of a workspace never reads a sibling (AC15).
cd "$REPO" || { echo "nothing to list — cannot enter that directory"; exit 0; }

TAB=$'\t'
ROWS=""           # sort key, tab, sort key, tab, the row itself — sorted and cut below

# add <path> <stepnum> <kind> <number> <state> <step> <detail>
# The first two fields are the sort key: path, then step number. Nothing but the bytes on disk
# feeds it, so two runs over an unchanged tree agree (AC13).
add() {
  local n=$2
  n=$(printf '%s' "$n" | sed -e 's/[^0-9]//g' -e 's/^0*\([0-9]\)/\1/')
  ROWS="$ROWS$1$TAB$(printf '%04d' "${n:-0}")$TAB$3$TAB$4$TAB$5$TAB$1$TAB$6$TAB$7
"
}

# clean <text> — collapse whitespace, drop bold markers, trim. Keeps every row on one line and
# keeps tabs out of the fields.
clean() {
  printf '%s' "$1" | sed -e 's/\*\*//g' -e 's/[[:space:]][[:space:]]*/ /g' \
                         -e 's/^ //' -e 's/ $//'
}

# number_of <path> — the leading four-digit number of an artefact's basename, or "-". Never
# assume the numbers are dense: this is read off the name, never counted.
number_of() {
  local b=${1##*/} n
  n=$(printf '%s' "$b" | sed -n 's/^\([0-9][0-9][0-9][0-9]\).*/\1/p')
  printf '%s' "${n:--}"
}

# norm_spec <ref> — the repository-relative spec path a plan's **Spec:** line points at.
# Three forms exist in this repo's filed plans and all three land here: a backticked
# repo-relative path, a markdown link whose target climbs out of the plan's own directory with
# `../../specs/…`, and the pre-1.0.0 bare form six of the filed plans still carry.  path-scan-ok
# Anchoring on the last path segment before the filename normalises all three without resolving
# anything outside the repo root. The patterns below name the old layout on purpose — it is what
# the old records are read THROUGH, not a reference a task follows — so each carries the pragma.
norm_spec() {
  case "$1" in
    */specs/*) printf 'ai-factory/specs/%s' "${1##*/specs/}" ;;  # path-scan-ok
    specs/*)   printf 'ai-factory/%s' "$1" ;;                    # path-scan-ok
    *)         printf '%s' "$1" ;;
  esac
}

# spec_ref_of <plan-file> — the plan's **Spec:** target, or "". The first backticked token wins
# over the markdown link target, because the markdown form spells the repo-relative path in its
# label and the relative one in its target. Anchored at `^[^`]*` so the FIRST backticked token is
# taken: four filed plans continue the line with a second backticked reference — an ADR, a
# decision record — and a greedy match would pair the plan to whichever came last.
spec_ref_of() {
  local line rest tok
  line=$(grep -m1 -- '\*\*Spec:\*\*' "$1" 2>/dev/null)
  [ -n "$line" ] || { printf ''; return 0; }
  rest=${line#*\*\*Spec:\*\*}
  tok=$(printf '%s' "$rest" | sed -n 's/^[^`]*`\([^`]*\)`.*/\1/p')
  [ -n "$tok" ] || tok=$(printf '%s' "$rest" | sed -n 's/^[^]]*](\([^)]*\)).*/\1/p')
  [ -n "$tok" ] || tok=$(printf '%s' "$rest" | awk '{print $1}')
  [ -n "$tok" ] || { printf ''; return 0; }
  norm_spec "$tok"
}

# title_of <file> — the first `# …` heading, for the detail column of a spec row.
title_of() {
  [ -r "$1" ] || { printf ''; return 0; }
  clean "$(sed -n 's/^# \(.*\)/\1/p' "$1" 2>/dev/null | head -1)"
}

# --- 1. the plans -------------------------------------------------------------------------
# Glob and sort; never iterate a counter. The numbers are not dense — ai-factory/plans/ can hold
# none at all while done/ holds nine — and a plan's DIRECTORY says nothing about its state: a
# plan filed under done/ with one `- [~]` step is outstanding (AC10). Only the checkboxes decide.
PLAN_SPEC=(); PLAN_STATE=(); NP=0

plan_list=$( { for f in ai-factory/plans/*.md ai-factory/plans/*/*.md; do
                 printf '%s\n' "$f"
               done; } | LC_ALL=C sort -u )

while IFS= read -r plan; do
  [ -n "$plan" ] || continue
  pnum=$(number_of "$plan")
  state=""; reason=""; specref=""
  open_rows=""        # the incomplete steps, held back until the plan's own state is known

  if [ ! -r "$plan" ]; then
    # AC12: unreadable is unknown with a reason, and never complete.
    state=unknown; reason="the file could not be read — check its permissions"
  else
    specref=$(spec_ref_of "$plan")
    [ -n "$specref" ] || {
      # Fall back to the leading four-digit number, and only then: the **Spec:** line is the
      # pairing, the number is the guess (plan 0010, Ambiguity E).
      for cand in ai-factory/specs/"$pnum"-*.md; do specref=$cand; break; done
    }

    ok=0; bad=0; incomplete=0
    while IFS= read -r line; do
      case "$line" in
        '- ['*) ;;
        *) continue ;;
      esac
      inner=${line#- \[}
      mark=${inner%%\]*}
      rest=${inner#*\]}
      # A marker is one character at most. Anything longer is an ordinary markdown link bullet
      # — `- [label](url)` — not a step, and must not make a plan unreadable.
      [ "${#mark}" -le 1 ] || continue

      case "$mark" in
        x|X) ok=$((ok + 1)); continue ;;     # AC4: a ticked step is not shown, in any form
        ' '|'~') ok=$((ok + 1)) ;;           # both incomplete (AC10)
        *) bad=$((bad + 1)); continue ;;     # a shape no rule covers (AC12)
      esac

      # The bold title is the step's one-line description; a wrapped plan continues on the next
      # line, which is not part of it. Fall back to the rest of the line when there is no bold.
      title=$(printf '%s' "$rest" | sed -n 's/^[^*]*\*\*\([^*]*\)\*\*.*/\1/p')
      [ -n "$title" ] || title=$rest
      title=$(clean "$title")

      ident=""; detail=$title
      for dash in ' — ' ' – ' ' - '; do
        [ "${title%%$dash*}" != "$title" ] || continue
        lead=${title%%$dash*}
        case "$lead" in
          Step\ *) ident=$lead; detail=${title#*$dash} ;;
        esac
        break
      done
      if [ -z "$ident" ]; then
        case "$title" in Step\ *) ident="Step $(printf '%s' "$title" | awk '{print $2}')" ;; esac
      fi
      [ -n "$ident" ] || ident="(step)"
      snum=$(printf '%s' "$ident" | sed 's/[^0-9]//g')

      case "$mark" in
        '~') sstate=part-done ;;
        *)   sstate=not-started ;;
      esac
      incomplete=$((incomplete + 1))
      open_rows="$open_rows$plan|${snum:-0}|$pnum|$sstate|$ident|$detail
"
    done < "$plan"

    if [ "$bad" -gt 0 ]; then
      # Conservative, and the same direction AC12 points: a plan carrying a step marker no rule
      # covers is unknown as a whole, never complete, and its steps are not guessed at.
      state=unknown
      reason="$bad step line(s) carry a marker no rule covers — expected - [ ], - [x] or - [~]"
    elif [ "$ok" -eq 0 ]; then
      state=unknown; reason="no step lines were found in this plan"
    elif [ "$incomplete" -eq 0 ]; then
      state=complete
    else
      state=outstanding
    fi
  fi

  PLAN_SPEC[$NP]=$specref; PLAN_STATE[$NP]=$state; NP=$((NP + 1))

  case "$state" in
    unknown)
      add "$plan" 0 plan "$pnum" unknown "-" "$reason" ;;
    outstanding)
      while IFS='|' read -r p sn nu st id de; do
        [ -n "$p" ] || continue
        add "$p" "$sn" plan "$nu" "$st" "$id" "$de"
      done <<EOF_STEPS
$open_rows
EOF_STEPS
      ;;
    complete)
      # One row for the plan, not one per ticked step: --done lists the finished ITEM. The
      # default listing drops it at the filter below, where AC4 is enforced in one place for
      # every kind of row rather than by never building it.
      add "$plan" 0 plan "$pnum" complete "-" "$(title_of "$plan")" ;;
  esac
done <<EOF_PLANS
$plan_list
EOF_PLANS

# --- 2. the specs -------------------------------------------------------------------------
# Nothing in spec 0010 defines a complete spec, so this rule is DERIVED — from AC4's "not
# started yet" and "part done", and from the spec's instruction to read the **Goal:** and
# **Spec:** lines each plan opens with. A spec with no plan is not started; a spec whose paired
# plan still has incomplete steps is part done; a spec whose every paired plan is complete is
# itself complete and is not listed. Plan 0010's Ambiguity E; still awaiting confirmation.
spec_list=$( { for f in ai-factory/specs/*.md; do printf '%s\n' "$f"; done; } | LC_ALL=C sort -u )
while IFS= read -r spec; do
  [ -n "$spec" ] || continue
  snum=$(number_of "$spec")
  if [ ! -r "$spec" ]; then
    add "$spec" 0 spec "$snum" unknown "-" "the file could not be read — check its permissions"
    continue
  fi

  paired=0; any_open=0; any_unknown=0
  i=0
  while [ "$i" -lt "$NP" ]; do
    if [ "${PLAN_SPEC[$i]}" = "$spec" ]; then
      paired=$((paired + 1))
      case "${PLAN_STATE[$i]}" in
        unknown)     any_unknown=1 ;;
        outstanding) any_open=1 ;;
      esac
    fi
    i=$((i + 1))
  done

  if [ "$paired" -eq 0 ]; then
    add "$spec" 0 spec "$snum" not-started "-" "$(title_of "$spec")"
  elif [ "$any_unknown" -eq 1 ]; then
    add "$spec" 0 spec "$snum" unknown "-" "its plan could not be read or interpreted"
  elif [ "$any_open" -eq 1 ]; then
    add "$spec" 0 spec "$snum" part-done "-" "$(title_of "$spec")"
  else
    # Every paired plan is complete, so the spec is: a row --done prints and the default
    # listing filters out (AC4, AC5).
    add "$spec" 0 spec "$snum" complete "-" "$(title_of "$spec")"
  fi
done <<EOF_SPECS
$spec_list
EOF_SPECS

# --- 3. the answer ------------------------------------------------------------------------
# Every artefact above became a row carrying its state, whatever that state is. The flag picks
# which states are printed, and nothing else differs: same builder, same sort, same header, same
# fields. The default listing shows what is not complete — AC4's "not struck through, not greyed,
# not shown with a done marker" is this one comparison — and --done shows what is, which is the
# mirror image over any tree (AC5). `unknown` is neither, so it appears in the default listing and
# never under --done: an artefact that could not be read or interpreted is never complete (AC12).
SELECTED=$(printf '%s' "$ROWS" | grep -v '^$' | LC_ALL=C sort \
  | awk -F'\t' -v mode="$MODE" '{ done_row = ($5 == "complete"); if ((mode == "done") == done_row) print }')

# An empty result is an answer, not an error and not silence: one line, exit 0 (AC11).
if [ -z "$SELECTED" ]; then
  if [ ! -d ai-factory/specs ] && [ ! -d ai-factory/plans ]; then
    echo "nothing to list — this repo has no ai-factory/specs or ai-factory/plans directory"
  elif [ "$MODE" = done ]; then
    echo "nothing finished yet — no spec or plan in this repo has every step complete"
  else
    echo "nothing outstanding — every spec and plan in this repo is complete"
  fi
  exit 0
fi

HEADER=$'kind\tnumber\tstate\tpath\tstep\tdetail'

# --- 4. --next: the one artefact to pick up -----------------------------------------------
# Plan 0010's Ambiguity A, answered 2026-09-29. The key is the artefact's last commit date,
# `git log -1 --format=%ct -- <path>`, in seconds, read with the repo root as the working
# directory. WHY A COMMIT DATE AND NOT AN MTIME: an mtime does not survive a clone, so two
# developers sitting on the same commit would get different answers out of the same tree, while a
# commit date is identical in every clone. AC13 — the same tree, run twice, nothing changed in
# between — holds under either measure, so this is cross-clone agreement and not an AC13 fix.
#
# An artefact the command answers with an empty string — uncommitted, or untracked — sorts as the
# NEWEST thing in the tree. Highest key wins; ties break on the artefact's leading four-digit
# number lowest first, then on path, then on step number, so the order is total and exactly one
# row can win. The row itself is byte-identical to the row the default listing produces for the
# same artefact, which is what makes the answer a strict subset of it (AC6).
if [ "$MODE" = next ]; then

  # git_q — git with the ambient GIT_DIR and GIT_WORK_TREE removed. A run started from inside a
  # git hook inherits both, and either would point these reads at a repository this run was never
  # given (AC15).
  git_q() { ( unset GIT_DIR GIT_WORK_TREE; git "$@" ); }

  # THE GUARD THIS RULE NEEDS. `git` walks UP: run in a directory that is not itself a repository
  # it answers out of the nearest ancestor that is, so `git log` under a plain directory nested in
  # some other repo would read that repo's history and could name an artefact from outside the
  # tree this run was handed — an AC15 break. Verified 2026-09-29: `git rev-parse --show-toplevel`
  # from `skills/` in this plugin's own repo answers with the repo root, not with `skills/`.
  # `pwd -P`, physical, because `mktemp -d` hands back `/var/folders/…` on macOS while
  # `--show-toplevel` answers with `/private/var/folders/…`, and a logical comparison would report
  # every fixture repo as somebody else's.
  git_usable() {
    command -v git >/dev/null 2>&1 || return 1
    [ "$(git_q rev-parse --show-toplevel 2>/dev/null)" = "$(pwd -P)" ]
  }
  if git_usable; then NOCOMMITS=0; else NOCOMMITS=1; fi

  # The key an artefact with no commit date gets. Uncommitted work is the newest thing in the
  # tree, so it sorts above every real timestamp; ten digits of 9s is past the year 2286.
  UNCOMMITTED=9999999999

  # One `git log` per artefact, memoised on the previous path: SELECTED is sorted by path, so a
  # plan's several step rows are adjacent and ask the same question once.
  keyed=""; cache_p=""; cache_ct=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    p=${line%%"$TAB"*}
    if [ "$p" = "$cache_p" ]; then
      ct=$cache_ct
    else
      ct=""
      [ "$NOCOMMITS" = 1 ] || ct=$(git_q log -1 --format=%ct -- "$p" 2>/dev/null)
      # Empty, or anything that is not a plain number, is treated as no commit date at all.
      case "$ct" in ''|*[!0-9]*) ct=$UNCOMMITTED ;; esac
      cache_p=$p; cache_ct=$ct
    fi
    keyed="$keyed$ct$TAB$line
"
  done <<EOF_NEXT
$SELECTED
EOF_NEXT

  # Fields, once the key is in front: 1 key · 2 path · 3 step number · 4 kind · 5 number ·
  # 6 state · 7 path · 8 step · 9 detail. Highest key first, then the three tiebreaks in the
  # order the rule fixes — number lowest first, then path, then step number.
  ranked=$(printf '%s' "$keyed" | grep -v '^$' \
           | LC_ALL=C sort -t"$TAB" -k1,1nr -k5,5 -k2,2 -k3,3)
  win=$(printf '%s\n' "$ranked" | head -1)

  wkey=$(printf '%s' "$win" | cut -f1)
  wpath=$(printf '%s' "$win" | cut -f2)
  wnum=$(printf '%s' "$win" | cut -f5)
  wstep=$(printf '%s' "$win" | cut -f8)
  label=$wpath
  case "$wstep" in ''|'-') ;; *) label="$wpath $wstep" ;; esac

  # Which tiebreak decided, if one did: the runner-up shares the winner's key exactly when the
  # commit date alone did not settle it.
  runner=$(printf '%s\n' "$ranked" | sed -n '2p')
  tiebreak=""
  if [ -n "$runner" ] && [ "$(printf '%s' "$runner" | cut -f1)" = "$wkey" ]; then
    if   [ "$wnum"  != "$(printf '%s' "$runner" | cut -f5)" ]; then tiebreak="the lower number"
    elif [ "$wpath" != "$(printf '%s' "$runner" | cut -f2)" ]; then tiebreak="the earlier path"
    else                                                            tiebreak="the lower step number"
    fi
  fi

  if [ "$NOCOMMITS" = 1 ]; then
    why="no commit dates were available — this directory is not the root of a git repository, or git is not installed"
    [ -z "$tiebreak" ] || why="$why, so $tiebreak decided"
  elif [ "$wkey" = "$UNCOMMITTED" ]; then
    why="it is uncommitted or untracked, which sorts newest"
    [ -z "$tiebreak" ] || why="$why, and $tiebreak decided between those tied there"
  else
    why="it carries the newest commit date of anything outstanding"
    [ -z "$tiebreak" ] || why="$why, and $tiebreak decided between those tied on it"
  fi

  printf '%s\n' "$HEADER"
  printf '%s\n' "$win" | cut -f4-
  printf 'next: %s — %s\n' "$label" "$why"
  exit 0
fi

printf '%s\n' "$HEADER"
printf '%s\n' "$SELECTED" | cut -f3-
exit 0
