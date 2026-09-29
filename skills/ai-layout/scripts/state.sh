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
#   flag        --done / --next are not decided yet (spec 0010's open questions); any flag
#               prints one line saying so and exits 0.
#
# Output: a tab-separated table — a header row, then one row per listed thing:
#
#   kind  number  state  path  step  detail
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
REPO=""; PLUGIN=""; EXTRA=""
for arg in "$@"; do
  case "$arg" in
    -*) EXTRA="${EXTRA:+$EXTRA }$arg" ;;
    *)
      if   [ -z "$REPO" ];   then REPO=$arg
      elif [ -z "$PLUGIN" ]; then PLUGIN=$arg
      else EXTRA="${EXTRA:+$EXTRA }$arg"
      fi ;;
  esac
done
REPO=${REPO:-.}
PLUGIN=${PLUGIN:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}}
: "$PLUGIN"  # read by nothing here; see the signature note above (AC14, AC15)

if [ -n "$EXTRA" ]; then
  echo "the rule for '$EXTRA' is not decided yet — spec 0010 leaves open what --next selects, whether --done replaces or widens the listing, and whether the two combine, so /t4:state answers only the default listing for now"
  exit 0
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
    *) : ;;   # complete: AC4 — not struck through, not greyed, absent
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
  fi
  # every paired plan complete: the spec is complete and is not listed (AC4)
done <<EOF_SPECS
$spec_list
EOF_SPECS

# --- 3. the answer ------------------------------------------------------------------------
# An empty result is an answer, not an error and not silence: one line, exit 0 (AC11).
if [ -z "$ROWS" ]; then
  if [ ! -d ai-factory/specs ] && [ ! -d ai-factory/plans ]; then
    echo "nothing to list — this repo has no ai-factory/specs or ai-factory/plans directory"
  else
    echo "nothing outstanding — every spec and plan in this repo is complete"
  fi
  exit 0
fi

printf 'kind\tnumber\tstate\tpath\tstep\tdetail\n'
printf '%s' "$ROWS" | grep -v '^$' | LC_ALL=C sort | cut -f3-
exit 0
