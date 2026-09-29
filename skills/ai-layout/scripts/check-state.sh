#!/usr/bin/env bash
# Pins state.sh — the scan behind /t4:state — against fixture repos whose answers are known by
# construction.
#
# Written before state.sh exists. Until Step 2 of plan 0010 lands, this check is red on purpose,
# and the guard below says so by name rather than letting bash report a missing file forty times.
#
# Every fixture is synthetic and built under a mktemp -d. Nothing here reads this repo's own
# records. The queue moves while the feature is being built — two plans were filed between one
# directory listing and the next — so an assertion over the live tree would flake within the hour,
# and a fixture that encoded today's listing would be wrong before anyone ran it. The feature is
# specified by rules; the rules are what get pinned. Every repository-relative literal below is a
# FIXTURE path: it is joined to a $TMP-rooted directory before any filesystem access.
#
# The output FORMAT is deliberately not pinned. Which fields become columns, in what order, and
# whether the table is sectioned by kind is still an open question (plan 0010, Ambiguity B), so
# every assertion is about which artefacts, which steps and which reasons reach a row — never
# about separators, column positions or the header's wording. Those belong to Steps 3 and 5.
#
# One rule here is derived rather than quoted, and is marked where it is used: pairing a spec to a
# plan by the plan's **Spec:** line (plan 0010, Ambiguity E, still unconfirmed). Section 6 pins the
# derivation, not a decision; if the answer comes back different, section 6 is the one place to
# change.
#
# A note on set -e: as in doctor.sh, this file uses `set -uo pipefail` without -e, because several
# assertions are written as `grep … && fail`, whose non-matching half is the passing case.
set -uo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."
ROOT=$PWD
STATE=skills/ai-layout/scripts/state.sh
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# Red for the right reason. Without the script under test every case below would fail for the
# same uninformative reason, so name the one thing that is missing and stop.
[ -f "$ROOT/$STATE" ] || fail "$STATE does not exist yet.
It is written by Step 2 of plan 0010; Step 1 only writes this check. Every case below needs it,
so a non-zero exit here is the expected result of Step 1, not a broken harness."

# run <repo-dir> [arg…] — state.sh over a fixture, invoked the way commands/doctor.md invokes
# doctor.sh: [repo-root] [plugin-root]. stdout and stderr together, because that is what a
# session sees.
run() { local d=$1; shift; bash "$ROOT/$STATE" "$d" "$ROOT" "$@" 2>&1; }

# lines <output> — non-empty lines, so "one line" means one line of substance.
lines() { grep -c . <<<"$1"; }
# hits <output> <literal> — how many lines carry the literal.
hits() { grep -cF -- "$2" <<<"$1"; }
# row <output> <literal> — the first line carrying the literal.
row() { grep -F -- "$2" <<<"$1" | head -1; }
# no_absolute <output> <dir> — a repository-relative listing never names the repo root it was
# handed (AC3). Both spellings are checked: mktemp -d hands back a symlinked path on macOS
# (/var/folders/…) while a script that resolves its own cwd answers with the physical one
# (/private/var/folders/…), so checking one of them would miss half the leaks.
no_absolute() {
  local out=$1 d=$2 phys
  phys=$(cd "$d" && pwd -P)
  grep -qF -- "$d" <<<"$out" && fail "the listing names an absolute path, not a repository-relative one (AC3): $d
$out"
  [ "$phys" = "$d" ] && return 0
  grep -qF -- "$phys" <<<"$out" && fail "the listing names the resolved absolute path, not a repository-relative one (AC3): $phys
$out"
  return 0
}

# --- 1. a repo with no layout at all — one line, exit 0 (AC11) --------------------------------
# An empty result is a valid answer, not an error and not silence.
mkdir -p "$TMP/bare"
out=$(run "$TMP/bare"); st=$?
[ "$st" = 0 ] || fail "state exited $st on a repo with no layout; an empty result is an answer, not an error (AC11)"
[ "$(lines "$out")" = 1 ] || fail "a repo with no layout should be answered in one line, got $(lines "$out") (AC11):
$out"

# --- 2. the default listing (AC2, AC3, AC4, AC10) ---------------------------------------------
# One repo carrying every shape the default listing has to decide about. The step descriptions
# are deliberately unique sentences: "Step 2 was not listed" is only provable if no other line
# could have carried it.
QUEUE=$TMP/queue
mkdir -p "$QUEUE/ai-factory/specs" "$QUEUE/ai-factory/plans/done" "$QUEUE/ai-factory/tasks"

SPEC_ALONE=ai-factory/specs/0001-no-plan-yet.md
SPEC_PART=ai-factory/specs/0002-partly-built.md
SPEC_DONE=ai-factory/specs/0003-all-built.md
SPEC_FILED=ai-factory/specs/0004-filed-but-unfinished.md
PLAN_PART=ai-factory/plans/0002-partly-built.md
PLAN_DONE=ai-factory/plans/0003-all-built.md
PLAN_FILED=ai-factory/plans/done/0004-filed-but-unfinished.md
TASKS=ai-factory/tasks

printf '# 0001 — no plan yet\n'            > "$QUEUE/$SPEC_ALONE"
printf '# 0002 — partly built\n'           > "$QUEUE/$SPEC_PART"
printf '# 0003 — all built\n'              > "$QUEUE/$SPEC_DONE"
printf '# 0004 — filed but unfinished\n'   > "$QUEUE/$SPEC_FILED"

{ printf '# Plan 0002 — partly built\n\n'
  printf '**Spec:** `%s`\n\n## Steps\n\n' "$SPEC_PART"
  printf -- '- [x] **Step 1 — the trial balance reconciled.** Proved by a fixture.\n'
  printf -- '- [x] **Step 2 — the ledger exported.** Proved by a fixture.\n'
  printf -- '- [ ] **Step 3 — the audit trail written.** Proved by a fixture.\n'
} > "$QUEUE/$PLAN_PART"

{ printf '# Plan 0003 — all built\n\n'
  printf '**Spec:** `%s`\n\n## Steps\n\n' "$SPEC_DONE"
  printf -- '- [x] **Step 1 — the meter installed.** Proved by a fixture.\n'
  printf -- '- [x] **Step 2 — the meter read.** Proved by a fixture.\n'
} > "$QUEUE/$PLAN_DONE"

# Filed under done/ and still outstanding: AC10's `- [~]`, and the settled rule that a plan's
# checkboxes beat its directory. Both of this repo's real `- [~]` steps sit in filed plans, so a
# reader that inferred completeness from the directory would call this one done.
{ printf '# Plan 0004 — filed but unfinished\n\n'
  printf '**Spec:** `%s`\n\n## Steps\n\n' "$SPEC_FILED"
  printf -- '- [x] **Step 1 — the kiln fired.** Proved by a fixture.\n'
  printf -- '- [x] **Step 2 — the glaze mixed.** Proved by a fixture.\n'
  printf -- '- [~] **Step 3 — the second firing.** Partly proved; one criterion outstanding.\n'
} > "$QUEUE/$PLAN_FILED"

# Prompts, not units of work. They carry checkbox lines on purpose: a scan that globbed too
# widely would find them, and the whole point of AC2's last sentence is that it must not.
printf -- '- [ ] **Step 1 — this line is bait and must never be listed.**\n' > "$QUEUE/$TASKS/spec.md"
printf -- '- [ ] **Step 1 — so is this one.**\n'                             > "$QUEUE/$TASKS/run.md"

# Section 4's subject, taken NOW, before the script has ever been pointed at this fixture. A copy
# made later would already carry anything the first run dropped, and the read-only assertion would
# pass over the exact thing it exists to catch. Proved by mutation: a script creating one file per
# run is caught from this baseline and is not caught from one taken after a run.
RO=$TMP/read-only
cp -R "$QUEUE" "$RO"

out=$(run "$QUEUE"); st=$?
[ "$st" = 0 ] || fail "state exited $st over the default-listing fixture; it must always exit 0:
$out"

# AC2 — every outstanding artefact appears exactly once, and nothing complete appears at all.
[ "$(hits "$out" "$SPEC_ALONE")" = 1 ] \
  || fail "a spec with no plan should be listed exactly once, got $(hits "$out" "$SPEC_ALONE") (AC2):
$out"
[ "$(hits "$out" "$SPEC_PART")" = 1 ] \
  || fail "a spec whose plan has an incomplete step should be listed exactly once, got $(hits "$out" "$SPEC_PART") (AC2):
$out"
[ "$(hits "$out" "$SPEC_FILED")" = 1 ] \
  || fail "a spec whose filed plan still has a [~] step should be listed exactly once, got $(hits "$out" "$SPEC_FILED") (AC2, AC10):
$out"
[ "$(hits "$out" "$PLAN_PART")" = 1 ] \
  || fail "a plan with one incomplete step should be listed exactly once, got $(hits "$out" "$PLAN_PART") (AC2):
$out"
[ "$(hits "$out" "$PLAN_FILED")" = 1 ] \
  || fail "a plan whose every step is [x] except one [~] is outstanding, not done, and is listed once — got $(hits "$out" "$PLAN_FILED") (AC10):
$out"

# AC4 — a complete item does not appear at all. Not struck through, not greyed, not marked done.
[ "$(hits "$out" "$PLAN_DONE")" = 0 ] \
  || fail "a plan whose every step is [x] appeared in the default listing (AC4):
$out"
[ "$(hits "$out" "$SPEC_DONE")" = 0 ] \
  || fail "a spec whose only plan is complete appeared in the default listing (AC4):
$out"

# AC3 — a plan carries step-level detail: the incomplete step's identifier AND its one-line
# description, on the row that names the plan. A title with no steps does not satisfy AC3.
r=$(row "$out" "$PLAN_PART")
grep -qF -- 'Step 3' <<<"$r" \
  || fail "the outstanding plan's row does not name the incomplete step's identifier (AC3):
$r"
grep -qF -- 'the audit trail written' <<<"$r" \
  || fail "the outstanding plan's row does not carry the incomplete step's one-line description (AC3):
$r"
r=$(row "$out" "$PLAN_FILED")
grep -qF -- 'Step 3' <<<"$r" \
  || fail "the [~] plan's row does not name the incomplete step's identifier (AC3, AC10):
$r"
grep -qF -- 'the second firing' <<<"$r" \
  || fail "the [~] plan's row does not carry the incomplete step's one-line description (AC3, AC10):
$r"

# AC4 again, at step level — a ticked step is not shown anywhere, in any form.
for finished in 'the trial balance reconciled' 'the ledger exported' 'the meter installed' \
                'the meter read' 'the kiln fired' 'the glaze mixed'; do
  grep -qF -- "$finished" <<<"$out" \
    && fail "a completed step was shown in the default listing (AC4): $finished
$out"
done

# AC2's last sentence — the prompt files are never listed, nor is their bait.
grep -qF -- "$TASKS/" <<<"$out" && fail "a prompt file was listed; those have no completion state (AC2):
$out"
grep -qF -- 'bait and must never be listed' <<<"$out" \
  && fail "a step line from a prompt file reached the listing (AC2):
$out"

# AC3 — identified by repository-relative path.
no_absolute "$out" "$QUEUE"

# --- 3. the same tree, twice, byte for byte (AC13) --------------------------------------------
if ! diff <(run "$QUEUE") <(run "$QUEUE") >/dev/null; then
  fail "two runs over the same unchanged fixture disagreed (AC13):
$(diff <(run "$QUEUE") <(run "$QUEUE"))"
fi

# --- 4. read-only, proved by snapshot (AC8, AC9) ----------------------------------------------
# Two snapshots, because AC8 and AC9 are two different claims. The filesystem snapshot is the set
# of paths — it catches a report, a cache or an export appearing, and anything disappearing. The
# content snapshot is every file's bytes — it catches a checkbox ticked, a plan rewritten in
# place, or a file moved between the queue and its done/ subdirectory.
#
# Known limit, stated rather than hidden: neither form catches a scratch file created and deleted
# again within one run, because both are built from the surviving entries. Catching that needs the
# containing directories' own mtimes, which `find` cannot print portably.
fs_snap()      { find "$1" | sort | shasum | cut -d' ' -f1; }
content_snap() { find "$1" -type f -exec shasum {} + | sort | shasum | cut -d' ' -f1; }

# The canaries. Without them both assertions could pass vacuously — a snapshot blind to the verb
# it is meant to catch reports "untouched" for a directory that has been rifled.
CAN=$TMP/canary
rm -rf "$CAN"; cp -R "$QUEUE" "$CAN"
base_fs=$(fs_snap "$CAN"); base_c=$(content_snap "$CAN")
: > "$CAN/report.txt"
[ "$(fs_snap "$CAN")" != "$base_fs" ] \
  || fail "the filesystem snapshot does not notice a created file, so AC8's assertion would pass vacuously"
rm -f "$CAN/report.txt"
[ "$(fs_snap "$CAN")" = "$base_fs" ] \
  || fail "the filesystem snapshot is not stable across a create-then-delete, so its own baseline is unreliable"
printf -- '- [x] **Step 3 — the audit trail written.**\n' >> "$CAN/$PLAN_PART"
[ "$(content_snap "$CAN")" != "$base_c" ] \
  || fail "the content snapshot does not notice an edited file, so AC9's assertion would pass vacuously"
rm -rf "$CAN"

# $RO is the untouched copy taken in section 2, before the first run. Both runs below are
# therefore a first run as far as this directory is concerned, and a second one after it.
before_fs=$(fs_snap "$RO"); before_c=$(content_snap "$RO")
for pass in first second; do
  run "$RO" >/dev/null; st=$?
  [ "$st" = 0 ] || fail "state exited $st on the $pass read-only run"
  [ "$(fs_snap "$RO")" = "$before_fs" ] \
    || fail "the $pass run created or removed a file under the repo it listed — no report, no cache, no export (AC8)"
  [ "$(content_snap "$RO")" = "$before_c" ] \
    || fail "the $pass run edited a file under the repo it listed — no checkbox ticked, no plan moved (AC9)"
done

# --- 5. what cannot be read or interpreted is unknown, with a reason (AC12) --------------------
# First prove the unreadable case is exercisable at all. root, and anything else holding
# CAP_DAC_OVERRIDE, reads a chmod 000 file regardless, and an assertion about an unreadable file
# that is not actually unreadable proves nothing.
probe=$TMP/probe; printf 'x\n' > "$probe"; chmod 000 "$probe"
if cat "$probe" >/dev/null 2>&1; then
  chmod 644 "$probe"
  fail "this user can read a chmod 000 file — running as root, or on a filesystem that ignores
permissions. AC12's unreadable-artefact case cannot be exercised here, and asserting it anyway
would pass vacuously. Run this check as an unprivileged user."
fi
chmod 644 "$probe"; rm -f "$probe"

MURKY=$TMP/murky
mkdir -p "$MURKY/ai-factory/specs" "$MURKY/ai-factory/plans"
PLAN_LOCKED=ai-factory/plans/0020-cannot-be-read.md
PLAN_SHAPELESS=ai-factory/plans/0021-no-rule-covers-these.md
SPEC_OK=ai-factory/specs/0022-still-listed-regardless.md
PLAN_OK=ai-factory/plans/0023-also-still-listed.md
SPEC_OK2=ai-factory/specs/0023-also-still-listed.md

printf '# 0022 — still listed regardless\n' > "$MURKY/$SPEC_OK"
printf '# 0023 — also still listed\n'       > "$MURKY/$SPEC_OK2"
{ printf '# Plan 0023 — also still listed\n\n'
  printf '**Spec:** `%s`\n\n## Steps\n\n' "$SPEC_OK2"
  printf -- '- [ ] **Step 1 — the harbour dredged.** Proved by a fixture.\n'
} > "$MURKY/$PLAN_OK"

# Step lines in a shape no rule covers: neither [ ], [x] nor [~]. Not a plan with no steps — a
# plan whose steps cannot be classified, which is the case AC12 names.
{ printf '# Plan 0021 — no rule covers these\n\n'
  printf '## Steps\n\n'
  printf -- '- [?] **Step 1 — the marker nothing defines.** Proved by a fixture.\n'
  printf -- '- [] **Step 2 — the marker with nothing in it.** Proved by a fixture.\n'
} > "$MURKY/$PLAN_SHAPELESS"

{ printf '# Plan 0020 — cannot be read\n\n'
  printf -- '- [ ] **Step 1 — unreachable behind its permissions.**\n'
} > "$MURKY/$PLAN_LOCKED"
chmod 000 "$MURKY/$PLAN_LOCKED"

out=$(run "$MURKY"); st=$?
chmod 644 "$MURKY/$PLAN_LOCKED"
[ "$st" = 0 ] || fail "state exited $st over a repo holding an unanswerable artefact; one artefact it
cannot read must not stop the others (AC12):
$out"

# reason_of <row> <path> — what survives a row once its path and the word "unknown" are removed
# and every separator and punctuation mark is squeezed out. Non-empty means a reason was given;
# this is deliberately blind to the row's format, which Ambiguity B has not settled.
reason_of() {
  printf '%s' "$1" | sed -e "s|$2||g" -e 's/[Uu]nknown//g' -e 's/[^[:alnum:]]//g'
}
for pair in "$PLAN_LOCKED|an unreadable file" "$PLAN_SHAPELESS|a plan whose step lines match no rule"; do
  p=${pair%%|*}; what=${pair#*|}
  [ "$(hits "$out" "$p")" = 1 ] \
    || fail "$what should be reported exactly once, got $(hits "$out" "$p") (AC12):
$out"
  r=$(row "$out" "$p")
  grep -qi -- 'unknown' <<<"$r" || fail "$what was not reported as unknown (AC12):
$r"
  reason=$(reason_of "$r" "$p")
  [ "${#reason}" -ge 4 ] \
    || fail "$what was reported unknown with no reason beside it (AC12):
$r"
  grep -qiE 'complete|\bdone\b' <<<"$r" \
    && fail "$what was reported as complete; an artefact that cannot be read is never complete (AC12):
$r"
done

# ...and every other artefact is still listed.
[ "$(hits "$out" "$SPEC_OK")" = 1 ] \
  || fail "a healthy spec stopped being listed because another artefact was unreadable (AC12):
$out"
[ "$(hits "$out" "$PLAN_OK")" = 1 ] \
  || fail "a healthy plan stopped being listed because another artefact was unreadable (AC12):
$out"
no_absolute "$out" "$MURKY"

# --- 6. pairing a spec to a plan by the plan's **Spec:** line (Ambiguity E's derivation) -------
# THIS SECTION PINS A DERIVATION, NOT A DECISION. Nothing in spec 0010 defines a complete spec;
# the rule below is reasoned from AC4 and from the spec's instruction to read the **Goal:** and
# **Spec:** lines each plan opens with, and it is still awaiting the developer's confirmation.
#
# Three link forms exist in this repo's filed plans, and all three must pair: a backticked
# repository-relative path, a markdown link whose target is relative to the plan's own directory,
# and the pre-1.0.0 bare form six of the filed plans still carry. The bare and relative forms are
# assembled from the first rather than spelled out, so this file names no stale path.
#
# The fixture's numbers deliberately disagree — plan 0099 against spec 0040 — so the fallback to
# the leading four-digit number cannot pair them. Only the **Spec:** line can. The plan is
# complete, so a spec that paired disappears from the listing and a spec that did not pair stays
# in it: the assertion fails loudly in the direction that matters.
LINKED=ai-factory/specs/0040-linked-by-its-spec-line.md
BARE=${LINKED#ai-factory/}
REL=../../$BARE
CONTROL=ai-factory/specs/0041-named-by-no-plan.md
PAIRED_PLAN=ai-factory/plans/done/0099-the-number-does-not-match.md

for form in backticked mdlink bare; do
  d=$TMP/pair-$form
  mkdir -p "$d/ai-factory/specs" "$d/ai-factory/plans/done"
  printf '# 0040 — linked by its spec line\n' > "$d/$LINKED"
  printf '# 0041 — named by no plan\n'        > "$d/$CONTROL"
  { printf '# Plan 0099 — the number does not match\n\n'
    case $form in
      backticked) printf '**Spec:** `%s`\n\n' "$LINKED" ;;
      mdlink)     printf '**Spec:** [`%s`](%s)\n\n' "$LINKED" "$REL" ;;
      bare)       printf '**Spec:** `%s`\n\n' "$BARE" ;;
    esac
    printf '## Steps\n\n'
    printf -- '- [x] **Step 1 — the only step, and it is done.** Proved by a fixture.\n'
  } > "$d/$PAIRED_PLAN"

  out=$(run "$d"); st=$?
  [ "$st" = 0 ] || fail "state exited $st over the $form pairing fixture:
$out"
  [ "$(hits "$out" "$CONTROL")" = 1 ] \
    || fail "in the $form fixture the control spec — the one no plan names — was not listed, so the
fixture proves nothing about pairing:
$out"
  [ "$(hits "$out" "$PAIRED_PLAN")" = 0 ] \
    || fail "in the $form fixture a plan whose every step is [x] appeared in the default listing (AC4):
$out"
  [ "$(hits "$out" "$LINKED")" = 0 ] \
    || fail "the $form **Spec:** form did not pair the plan to its spec: the spec's only plan is
complete, yet the spec was still listed. The two numbers disagree on purpose, so nothing but the
**Spec:** line could have paired them (plan 0010, Ambiguity E):
$out"
done

# --- 7. a sibling repo is never read (AC15) ---------------------------------------------------
for s in a b; do
  mkdir -p "$TMP/sibling-$s/ai-factory/specs"
  printf '# 0050 — only in sibling %s\n' "$s" \
    > "$TMP/sibling-$s/ai-factory/specs/0050-only-in-sibling-$s.md"
done
out=$(run "$TMP/sibling-a"); st=$?
[ "$st" = 0 ] || fail "state exited $st in a workspace of sibling repos:
$out"
grep -qF -- 'only-in-sibling-a' <<<"$out" \
  || fail "the run did not list its own repo's spec, so the isolation assertion proves nothing (AC15):
$out"
grep -qF -- 'only-in-sibling-b' <<<"$out" \
  && fail "a run in one repo named an artefact belonging to its sibling; no sibling is read and no
aggregate is produced (AC15):
$out"
no_absolute "$out" "$TMP/sibling-a"

# --- 8. the prompt's own invariants (AC14, and the change-nothing instruction) ----------------
# commands/state.md is the other half of the feature: the script decides what is outstanding, the
# prompt presents it. Two things about that file are assertable without settling Ambiguity B, and
# both are pinned here rather than left to a reading.
#
# One — the prompt must name the script it drives. A prompt that lost the invocation would still
# read like a working command, and would answer out of the session's own reading of the layout,
# which is exactly what AC14 forbids and what AC13's determinism rests on.
#
# Two — the prompt must say, in words, that it changes nothing. AC8 and AC9 are proved of the
# SCRIPT in section 4, but nothing in a script stops a session that has just been handed a list of
# outstanding steps from starting one. Only the prompt can say not to.
#
# Deliberately NOT asserted here: the table's columns, their order, the header's wording, or
# whether the table is sectioned by kind. That is plan 0010's Ambiguity B, still open, and pinning
# it by fixture would settle in passing a question meant to be answered in writing.
PROMPT=commands/state.md
[ -f "$ROOT/$PROMPT" ] || fail "$PROMPT does not exist.
It is written by Step 3 of plan 0010 — the prompt that renders state.sh's rows (AC1, AC14)."

grep -qF -- "$STATE" "$ROOT/$PROMPT" \
  || fail "$PROMPT does not name $STATE. The prompt presents the script's rows and must not decide
for itself which items are outstanding, so that one invocation is the whole seam (AC14):
$(cat "$ROOT/$PROMPT")"

sed 's/\*//g' "$ROOT/$PROMPT" | grep -qi -- 'change nothing' \
  || fail "$PROMPT carries no explicit change-nothing instruction. /t4:state lists work and never
does any — no file edited, no checkbox ticked, no plan moved between plans/ and done/, no step
started — and the prompt is the only place that can say so to the session reading it (AC8, AC9):
$(cat "$ROOT/$PROMPT")"

echo "state ok — 8 sections: empty answer, the default listing with [~] and done/, determinism, \
the read-only snapshots, unknown-with-a-reason, the three **Spec:** link forms, sibling isolation, \
the prompt's two invariants"
