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

# --- 9. the command is named where a developer will find it (AC16, the docs half) -------------
# A command nobody can find is not shipped. README.md is the plugin's own inventory of what it
# provides, and ai-factory/docs/workflow.md is the document every repo is pointed at to learn what
# the commands are and the order to run them in. A /t4:state that appears in neither is invisible
# to the developer it was built for, however well the script behind it works.
#
# These two assertions run against this repo's own files rather than a fixture — the one place in
# this check that does, and deliberately so: the subject here IS this repo's documentation, not a
# rule about arbitrary repos, so a fixture could only restate itself. Nor can it flake the way an
# assertion over ai-factory/specs/ or ai-factory/plans/ would: those move whenever the queue
# moves, while these two files move only when someone edits them.
#
# Deliberately NOT asserted: where in either file the mention sits, what it says, or that §5's
# plugin-level table is complete. That table already omits /t4:doctor and /t4:setup-tracker;
# widening it is a separate chore (plan 0010, Step 4), and asserting its contents here would
# quietly make that chore this check's business.
#
# Also NOT asserted, because it is NOT met: the rest of AC16 — the generated .claude/, .cursor/
# and .codex/ adapters, and ai-factory/.sdlc.json. sync-adapters.sh builds the adapters from
# ai-factory/tasks/, the skills and the agents and never reads commands/, and manifest.js hashes
# only files under skills/ai-layout/templates/, so a plugin command is invisible to both by
# construction (plan 0010, Ambiguity G). An assertion here would fail for a reason Step 4 cannot
# fix; a silent one would claim a coverage this feature does not have.
for doc in README.md ai-factory/docs/workflow.md; do
  [ -f "$ROOT/$doc" ] || fail "$doc does not exist, so the assertion below would pass over nothing
rather than prove anything about it (AC16, the docs half)."
  grep -qF -- '/t4:state' "$ROOT/$doc" \
    || fail "$doc does not name /t4:state. A command missing from the file a developer reads to
find out which commands exist cannot be found by the developer it is for (AC16, the docs half)."
done

# --- 10. `--done` replaces the default listing, and widens nothing (AC5, AC7) -----------------
# Ambiguity C, answered 2026-09-29: --done REPLACES the default listing. It lists the items whose
# every step is complete, in the same shape, and it does not widen the listing to everything with
# a state shown per row. So the two listings over one fixture are mirror images: every artefact
# reaches exactly one of them, and nothing reaches both.
#
# Still NOT asserted, because Ambiguity B is still open: which fields are columns, in what order,
# or what the header says. What IS asserted is that --done's header line is byte-identical to the
# default's and that both carry the same number of fields per row — a statement about SAMENESS,
# which holds whatever the answer to B turns out to be, and which is exactly what "no column the
# default listing does not already carry" means.
#
# The unreadable-shaped plan is in this fixture on purpose. Under a widening --done it would
# appear with its `unknown` state beside the complete ones; under the answer given it must not
# appear at all, because unknown is not complete and AC12 forbids ever calling it that.

# rows <output> — how many rows a listing has, the header line dropped.
rows() { tail -n +2 <<<"$1" | grep -c .; }
# widths <output> — the distinct field counts in a listing, counted with the separator the header
# itself uses. Deliberately blind to WHICH columns exist (Ambiguity B) and sharp about how many.
widths() { awk -F'\t' 'NF{print NF}' <<<"$1" | LC_ALL=C sort -u; }

DONEFIX=$TMP/done-filter
mkdir -p "$DONEFIX/ai-factory/specs" "$DONEFIX/ai-factory/plans"
DONE_PLAN=ai-factory/plans/0060-shipped.md
DONE_SPEC=ai-factory/specs/0060-shipped.md
OPEN_PLAN=ai-factory/plans/0061-still-going.md
OPEN_SPEC=ai-factory/specs/0061-still-going.md
MURK_PLAN=ai-factory/plans/0062-no-rule-covers-these.md

printf '# 0060 — shipped\n'     > "$DONEFIX/$DONE_SPEC"
printf '# 0061 — still going\n' > "$DONEFIX/$OPEN_SPEC"

# Two ticked steps, so a --done that emitted one row per COMPLETED step rather than one row per
# complete item is caught by the row count below.
{ printf '# Plan 0060 — shipped\n\n'
  printf '**Spec:** `%s`\n\n## Steps\n\n' "$DONE_SPEC"
  printf -- '- [x] **Step 1 — the lock gates hung.** Proved by a fixture.\n'
  printf -- '- [x] **Step 2 — the basin flooded.** Proved by a fixture.\n'
} > "$DONEFIX/$DONE_PLAN"

{ printf '# Plan 0061 — still going\n\n'
  printf '**Spec:** `%s`\n\n## Steps\n\n' "$OPEN_SPEC"
  printf -- '- [x] **Step 1 — the towpath cleared.** Proved by a fixture.\n'
  printf -- '- [ ] **Step 2 — the aqueduct surveyed.** Proved by a fixture.\n'
} > "$DONEFIX/$OPEN_PLAN"

{ printf '# Plan 0062 — no rule covers these\n\n'
  printf '## Steps\n\n'
  printf -- '- [?] **Step 1 — the marker nothing defines.** Proved by a fixture.\n'
} > "$DONEFIX/$MURK_PLAN"

out_def=$(run "$DONEFIX");        st=$?
[ "$st" = 0 ] || fail "state exited $st over the --done fixture's default listing:
$out_def"
out_done=$(run "$DONEFIX" --done); st=$?
[ "$st" = 0 ] || fail "state exited $st on --done; it always exits 0 (AC5, AC11):
$out_done"

# AC7 — the same table shape. The header line byte for byte, and the same field count per row.
[ "$(head -1 <<<"$out_done")" = "$(head -1 <<<"$out_def")" ] \
  || fail "--done's header line is not byte-identical to the default listing's; --done shows the
same columns in the same order, whatever those columns turn out to be (AC5, AC7):
--done:  $(head -1 <<<"$out_done")
default: $(head -1 <<<"$out_def")"
[ "$(widths "$out_done")" = "$(widths "$out_def")" ] \
  || fail "--done's rows do not carry the same number of fields as the default listing's, so it has
widened or narrowed the table rather than filtering it (AC5, AC7):
--done:  $(widths "$out_done")
default: $(widths "$out_def")"

# AC5 — the complete items, and only those. The two listings are mirror images over one fixture.
for p in "$DONE_PLAN" "$DONE_SPEC"; do
  [ "$(hits "$out_done" "$p")" = 1 ] \
    || fail "--done did not list a complete item exactly once, got $(hits "$out_done" "$p") (AC5): $p
$out_done"
  [ "$(hits "$out_def" "$p")" = 0 ] \
    || fail "a complete item appeared in the DEFAULT listing, so this fixture cannot prove --done is
its mirror image (AC4): $p
$out_def"
done
for p in "$OPEN_PLAN" "$OPEN_SPEC"; do
  [ "$(hits "$out_done" "$p")" = 0 ] \
    || fail "--done listed an item that is not finished; it replaces the default listing rather than
widening it to everything with a state (plan 0010, Ambiguity C): $p
$out_done"
  [ "$(hits "$out_def" "$p")" = 1 ] \
    || fail "an outstanding item was not in the default listing, so this fixture proves nothing about
the mirror image (AC2): $p
$out_def"
done
[ "$(hits "$out_done" "$MURK_PLAN")" = 0 ] \
  || fail "--done listed an artefact whose steps match no rule. An artefact that cannot be
interpreted has a state, but that state is not complete, and it is never reported as one (AC12):
$out_done"
[ "$(hits "$out_def" "$MURK_PLAN")" = 1 ] \
  || fail "the unanswerable plan was not in the default listing, so the assertion above proves
nothing about --done (AC12):
$out_def"

# It widens nothing: one row per complete item, and no item that has no state.
[ "$(rows "$out_done")" = 2 ] \
  || fail "--done emitted $(rows "$out_done") rows over a fixture holding exactly two complete items
— one complete plan and the spec it finishes. One row per complete item, not one per completed step
and not one per artefact in the repo (AC5):
$out_done"
[ "$(rows "$out_def")" = 3 ] \
  || fail "the default listing emitted $(rows "$out_def") rows where three were expected — the one
incomplete step, its spec, and the unanswerable plan. The mirror-image assertions above rest on it:
$out_def"
no_absolute "$out_done" "$DONEFIX"

# --- 11. checkboxes still beat the directory, under the filter too (AC10) ---------------------
# The settled rule is that nothing is inferred from a plan's location. It has to hold in --done as
# well, or the filter would quietly reintroduce the inference the default listing refuses to make:
# a complete plan that was never filed would go missing from --done, and an unfinished one sitting
# in done/ would be reported as finished — the precise error AC10 exists to forbid.
PLACE=$TMP/placement
mkdir -p "$PLACE/ai-factory/plans/done"
LOOSE_DONE=ai-factory/plans/0070-complete-but-never-filed.md
FILED_OPEN=ai-factory/plans/done/0071-filed-but-unfinished.md

{ printf '# Plan 0070 — complete but never filed\n\n## Steps\n\n'
  printf -- '- [x] **Step 1 — the weir rebuilt.** Proved by a fixture.\n'
} > "$PLACE/$LOOSE_DONE"
{ printf '# Plan 0071 — filed but unfinished\n\n## Steps\n\n'
  printf -- '- [x] **Step 1 — the sluice cast.** Proved by a fixture.\n'
  printf -- '- [~] **Step 2 — the sluice hung.** Partly proved; one criterion outstanding.\n'
} > "$PLACE/$FILED_OPEN"

out_done=$(run "$PLACE" --done); st=$?
[ "$st" = 0 ] || fail "state exited $st on --done over the placement fixture:
$out_done"
out_def=$(run "$PLACE"); st=$?
[ "$st" = 0 ] || fail "state exited $st over the placement fixture's default listing:
$out_def"

[ "$(hits "$out_done" "$LOOSE_DONE")" = 1 ] \
  || fail "--done did not list a plan whose every step is [x] because it sits in ai-factory/plans/
rather than done/. A plan's checkboxes decide its state; its directory decides nothing (AC10):
$out_done"
[ "$(hits "$out_done" "$FILED_OPEN")" = 0 ] \
  || fail "--done listed a plan filed under done/ whose last step is still [~]. Filing a plan does
not finish it — the checkboxes do (AC10):
$out_done"
[ "$(hits "$out_def" "$FILED_OPEN")" = 1 ] \
  || fail "the default listing dropped the filed-but-unfinished plan, so the assertion above proves
nothing (AC10):
$out_def"
[ "$(hits "$out_def" "$LOOSE_DONE")" = 0 ] \
  || fail "the default listing carried a plan whose every step is [x] (AC4):
$out_def"

# --- 12. --done over a repo with nothing complete is an answer, not silence (AC11) ------------
# An empty result is a valid answer under the filter for the same reason it is without one.
NONE=$TMP/none-complete
mkdir -p "$NONE/ai-factory/plans"
NONE_PLAN=ai-factory/plans/0080-nothing-here-is-finished.md
{ printf '# Plan 0080 — nothing here is finished\n\n## Steps\n\n'
  printf -- '- [ ] **Step 1 — the tunnel bored.** Proved by a fixture.\n'
} > "$NONE/$NONE_PLAN"

out=$(run "$NONE" --done); st=$?
[ "$st" = 0 ] || fail "--done exited $st over a repo with nothing complete; an empty result is an
answer, not an error (AC11):
$out"
[ "$(lines "$out")" = 1 ] \
  || fail "--done over a repo with nothing complete should answer in one line, got $(lines "$out") (AC11):
$out"
[ "$(hits "$out" "$NONE_PLAN")" = 0 ] \
  || fail "--done's empty answer named an artefact that is not complete (AC5, AC11):
$out"
[ "$(head -1 <<<"$out")" = "$(head -1 <<<"$(run "$NONE")")" ] \
  && fail "--done answered a repo with nothing complete with the listing's header row rather than a
line saying so. An empty table is not an answer (AC11):
$out"

# A repo with no layout at all answers identically with or without the filter: there is nothing to
# list either way, and the one-line answer to that question does not depend on the flag.
if ! diff <(run "$TMP/bare") <(run "$TMP/bare" --done) >/dev/null; then
  fail "--done and the default listing gave different answers for a repo with no layout at all; the
empty answer is the same one line either way (AC11):
$(diff <(run "$TMP/bare") <(run "$TMP/bare" --done))"
fi

# --- 13. the prompt hands the developer's argument to the script (AC14) -----------------------
# Found during Step 3 and added to Step 5's scope: nothing in the plan ever forwarded the
# developer's argument. The prompt fixes the invocation as `state.sh . "${CLAUDE_PLUGIN_ROOT}"`,
# so without this the script could grow --done, --next and their refusal while `/t4:state --done`
# typed by a developer still rendered the default listing — half-wired, with every check green,
# because no assertion covered the seam between the two halves.
#
# Two assertions, and they pull against each other on purpose.
#
# One — the step that runs the script must say that the developer's argument goes with it. Without
# that sentence the flag is accepted by the script and never reaches it.
#
# Two — `$ARGUMENTS` must remain LAST in the file, and appear once. Step 3 put it at the end so
# everything above it is a stable cached prefix. The obvious way to wire the hand-off — interpolate
# `$ARGUMENTS` into the invocation line — trades this gap for a silent caching regression: every
# token after it varies per invocation. The instruction refers to the trailing line instead, which
# is why assertion one looks for the reference rather than for the variable.
inv_line=$(grep -nF -- "$STATE" "$ROOT/$PROMPT" | head -1 | cut -d: -f1)
[ -n "$inv_line" ] || fail "$PROMPT does not name $STATE, so there is no invocation to hand an
argument to (AC14)."
from=$(( inv_line > 3 ? inv_line - 3 : 1 ))
window=$(sed -n "${from},$(( inv_line + 8 ))p" "$ROOT/$PROMPT")

grep -qi -- 'argument' <<<"$window" \
  || fail "$PROMPT runs $STATE without ever mentioning the developer's argument beside it, so
\`/t4:state --done\` would render the default listing however well the script handles the flag. The
prompt is the only place that seam can be wired (AC14):
$window"
grep -qF -- 'Context' <<<"$window" \
  || fail "$PROMPT mentions an argument beside the invocation but does not point at the \`Context:\`
line that carries it, so nothing says WHERE the value the script is handed comes from (AC14):
$window"

n_args=$(grep -cF -- '$ARGUMENTS' "$ROOT/$PROMPT")
[ "$n_args" = 1 ] \
  || fail "\$ARGUMENTS occurs $n_args times in $PROMPT; it belongs exactly once, on the last line.
Every token after it varies per invocation, so a second occurrence higher up shortens the stable
cached prefix to whatever precedes it — which is the caching regression Step 3 placed it last to
avoid, traded for the hand-off rather than added to it (plan 0010, Step 5)."
last_line=$(grep -n . "$ROOT/$PROMPT" | tail -1 | cut -d: -f1)
args_line=$(grep -nF -- '$ARGUMENTS' "$ROOT/$PROMPT" | tail -1 | cut -d: -f1)
[ "$args_line" = "$last_line" ] \
  || fail "\$ARGUMENTS is on line $args_line of $PROMPT and the file's last line of substance is
$last_line. It must be last: everything above it is the cached prefix, and hoisting it up into the
invocation is not how this hand-off is wired (plan 0010, Step 5)."

# --- 14. `--next` names the most recently modified artefact, by git commit date (AC6, AC13, AC15)
# Plan 0010's Ambiguity A, answered 2026-09-29. Every fixture below has its answer fixed BY
# CONSTRUCTION: the commit dates are pinned to fixed instants, so nothing here depends on when the
# check is run, and the artefact that must win is the one the rule picks rather than the one that
# happens to sort first.
#
# Why a commit date and not an mtime: an mtime does not survive a clone, so two developers sitting
# on the same commit would get different answers out of the same tree. AC13 — the same tree, run
# twice, nothing changed in between — holds under either measure, so this is cross-clone
# agreement and NOT an AC13 fix; the determinism assertion below is AC13's, and it is separate.
#
# Every git invocation carries -c user.email and -c user.name, so no assertion depends on the
# developer's own git config, and -c commit.gpgsign=false so a developer who signs every commit by
# default does not have the fixtures fail on a missing key.
GIT_ID=(-c user.email=check-state@example.invalid -c user.name='check-state fixture'
        -c commit.gpgsign=false)
ginit() { git "${GIT_ID[@]}" -c init.defaultBranch=main init -q "$1" >/dev/null 2>&1; }
gadd()  { local d=$1; shift; git -C "$d" "${GIT_ID[@]}" add -- "$@" >/dev/null 2>&1; }
# commit_at <repo> <iso-instant> <message> — the assignments precede an EXTERNAL command on
# purpose: prefixing a shell function instead leaks them into the rest of the run in some shells.
commit_at() {
  GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" \
    git -C "$1" "${GIT_ID[@]}" commit -q -m "$3" >/dev/null 2>&1
}
ct_of() { git -C "$1" "${GIT_ID[@]}" log -1 --format=%ct -- "$2" 2>/dev/null; }

command -v git >/dev/null 2>&1 \
  || fail "git is not on PATH, so every fixture below would be indistinguishable from the no-git
case and the commit-date rule would go unproved rather than fail (plan 0010, Step 6)."

EARLY=2020-01-01T00:00:00Z
LATE=2021-06-01T00:00:00Z
SAME=2020-03-03T03:03:03Z

# 14a — two artefacts, two commits, two pinned instants: the later one wins.
NEXTA=$TMP/next-history
mkdir -p "$NEXTA/ai-factory/specs"
SPEC_EARLY=ai-factory/specs/0090-committed-first.md
SPEC_LATE=ai-factory/specs/0091-committed-later.md
SPEC_NEVER=ai-factory/specs/0092-never-committed.md
printf '# 0090 — committed first\n'  > "$NEXTA/$SPEC_EARLY"
printf '# 0091 — committed later\n'  > "$NEXTA/$SPEC_LATE"

ginit "$NEXTA" || fail "git init failed in $NEXTA, so no fixture below can be built."
gadd "$NEXTA" "$SPEC_EARLY"; commit_at "$NEXTA" "$EARLY" 'the earlier artefact'
gadd "$NEXTA" "$SPEC_LATE";  commit_at "$NEXTA" "$LATE"  'the later artefact'
[ -n "$(ct_of "$NEXTA" "$SPEC_EARLY")" ] && [ -n "$(ct_of "$NEXTA" "$SPEC_LATE")" ] \
  || fail "the history fixture has no commit dates — git init or commit failed, and every
assertion in 14a would then be proving the no-git case instead of the commit-date rule."
[ "$(ct_of "$NEXTA" "$SPEC_EARLY")" -lt "$(ct_of "$NEXTA" "$SPEC_LATE")" ] \
  || fail "the pinned instants did not survive into the fixture's history: $SPEC_EARLY is not
older than $SPEC_LATE, so 14a's answer is not fixed by construction."

RO_NEXT=$(fs_snap "$NEXTA/ai-factory"); RO_NEXT_C=$(content_snap "$NEXTA/ai-factory")
out_def=$(run "$NEXTA");         st=$?
[ "$st" = 0 ] || fail "state exited $st over the --next history fixture's default listing:
$out_def"
out_next=$(run "$NEXTA" --next); st=$?
[ "$st" = 0 ] || fail "--next exited $st; it always exits 0 (AC6, AC11):
$out_next"

# Exactly one row, and one line saying why — the header, the row, the reason.
[ "$(lines "$out_next")" = 3 ] \
  || fail "--next answered in $(lines "$out_next") lines where three were expected: the header, the
one row it selected, and the one line stating which item it selected and why (AC6):
$out_next"
[ "$(head -1 <<<"$out_next")" = "$(head -1 <<<"$out_def")" ] \
  || fail "--next's header line is not byte-identical to the default listing's, so its row is not
being presented in the same table shape the rest of the command uses (AC6, AC7):
--next:  $(head -1 <<<"$out_next")
default: $(head -1 <<<"$out_def")"

# AC6 — a strict subset: the row --next emits is byte-for-byte the row the default listing
# produces for the same artefact, never one the default listing omits.
[ "$(sed -n 2p <<<"$out_next")" = "$(row "$out_def" "$SPEC_LATE")" ] \
  || fail "--next's row is not byte-identical to the row the default listing produces for the same
artefact, so the output is not a strict subset of it (AC6):
--next:  $(sed -n 2p <<<"$out_next")
default: $(row "$out_def" "$SPEC_LATE")"
[ "$(hits "$out_next" "$SPEC_EARLY")" = 0 ] \
  || fail "--next picked, or named, the artefact committed at the EARLIER pinned instant. The rule
is the most recently modified artefact by git commit date, highest key first (plan 0010,
Ambiguity A):
$out_next"
grep -qF -- "$SPEC_LATE" <<<"$(sed -n 3p <<<"$out_next")" \
  || fail "--next's reason line does not name the artefact it selected; AC6 requires the command to
state in one line WHICH item it selected and why:
$(sed -n 3p <<<"$out_next")"
no_absolute "$out_next" "$NEXTA"

# AC13 — the same tree, twice, byte for byte, under the filter too.
if ! diff <(run "$NEXTA" --next) <(run "$NEXTA" --next) >/dev/null; then
  fail "two --next runs over the same unchanged fixture disagreed (AC13):
$(diff <(run "$NEXTA" --next) <(run "$NEXTA" --next))"
fi
# AC8, AC9 — reading a history is still only reading.
[ "$(fs_snap "$NEXTA/ai-factory")" = "$RO_NEXT" ] \
  || fail "--next created or removed a file under the repo it listed (AC8)"
[ "$(content_snap "$NEXTA/ai-factory")" = "$RO_NEXT_C" ] \
  || fail "--next edited a file under the repo it listed (AC9)"

# 14b — an uncommitted artefact sorts newest and displaces both committed ones.
printf '# 0092 — never committed\n' > "$NEXTA/$SPEC_NEVER"
out_next=$(run "$NEXTA" --next); st=$?
[ "$st" = 0 ] || fail "--next exited $st with an untracked artefact in the tree:
$out_next"
[ "$(lines "$out_next")" = 3 ] \
  || fail "--next answered in $(lines "$out_next") lines with an untracked artefact present; still
one header, one row and one reason (AC6):
$out_next"
[ "$(hits "$out_next" "$SPEC_NEVER")" = 2 ] \
  || fail "--next did not select the untracked artefact. An artefact git answers about with an
empty string — uncommitted, or untracked — sorts as the NEWEST thing in the tree and displaces
every committed one (plan 0010, Ambiguity A). Expected it on both the row and the reason line:
$out_next"
[ "$(hits "$out_next" "$SPEC_LATE")" = 0 ] && [ "$(hits "$out_next" "$SPEC_EARLY")" = 0 ] \
  || fail "--next named a committed artefact while an untracked one was present; the untracked one
sorts newest and wins outright:
$out_next"
out_def=$(run "$NEXTA")
[ "$(sed -n 2p <<<"$out_next")" = "$(row "$out_def" "$SPEC_NEVER")" ] \
  || fail "--next's row for the untracked artefact is not byte-identical to the default listing's
row for it (AC6):
--next:  $(sed -n 2p <<<"$out_next")
default: $(row "$out_def" "$SPEC_NEVER")"

# 14c — a directory that is not itself a repository, nested inside one that is (AC15).
# THIS IS THE GUARD THE RULE NEEDS. `git` walks UP: from a plain directory inside a repository it
# answers out of that repository, so an ungated `git log` here would read an ancestor's history
# for a tree this run was never given. The two artefacts below are committed INTO $NEXTA at
# different pinned instants and the later one carries the HIGHER number, so the two rules give
# different answers: gated, no artefact has a commit date and the tiebreak picks the lower number;
# ungated, the ancestor's history picks the higher one. Remove the gate from state.sh and this
# assertion fails — which is what makes it worth having.
NESTED=$NEXTA/nested
mkdir -p "$NESTED/ai-factory/specs"
SPEC_LOW=ai-factory/specs/0093-lower-number.md
SPEC_HIGH=ai-factory/specs/0094-higher-number-committed-later.md
printf '# 0093 — lower number\n'                   > "$NESTED/$SPEC_LOW"
printf '# 0094 — higher number, committed later\n' > "$NESTED/$SPEC_HIGH"
gadd "$NEXTA" "nested/$SPEC_LOW";  commit_at "$NEXTA" "$EARLY" 'the nested lower number'
gadd "$NEXTA" "nested/$SPEC_HIGH"; commit_at "$NEXTA" "$LATE"  'the nested higher number'
[ -n "$(ct_of "$NEXTA" "nested/$SPEC_HIGH")" ] \
  || fail "the nested artefacts are not in the ancestor's history, so 14c cannot tell a gated
\`git log\` from an ungated one and would pass whether or not state.sh has the guard."
[ ! -e "$NESTED/.git" ] \
  || fail "the nested fixture has a .git of its own; it must have none, or it is not the case
plan 0010's Step 6 gates against."

out_next=$(run "$NESTED" --next); st=$?
[ "$st" = 0 ] || fail "--next exited $st in a directory that is not the root of a git repository;
it still answers, and it still exits 0 (AC11):
$out_next"
[ "$(lines "$out_next")" = 3 ] \
  || fail "--next answered in $(lines "$out_next") lines in a non-repository directory; when no
artefact has a commit date the tiebreak alone decides, and exactly one row still wins:
$out_next"
[ "$(hits "$out_next" "$SPEC_LOW")" = 2 ] \
  || fail "--next did not select the lower-numbered artefact in a directory that is not a git
repository root. Every \`git log\` must be gated on \`[ \"\$(git rev-parse --show-toplevel)\" =
\"\$(pwd -P)\" ]\`: without it git walks up to the ancestor repository, where the HIGHER-numbered
artefact was committed later, and --next answers out of a history this run was never given
(AC15, plan 0010, Step 6):
$out_next"
[ "$(hits "$out_next" "$SPEC_HIGH")" = 0 ] \
  || fail "--next named the artefact the ANCESTOR repository committed later. That answer can only
have come from a history outside the tree this run was handed (AC15):
$out_next"
grep -qi -- 'no commit date' <<<"$(sed -n 3p <<<"$out_next")" \
  || fail "--next's reason line does not say that no commit dates were available. When the gate
fails, every key is empty and the tiebreak alone decides — and the line that states why must say
so rather than claim a newest commit date it never read (AC6):
$(sed -n 3p <<<"$out_next")"
for outside in "$SPEC_EARLY" "$SPEC_LATE" "$SPEC_NEVER"; do
  [ "$(hits "$out_next" "$outside")" = 0 ] \
    || fail "a run inside the nested directory named an artefact belonging to the repository above
it. It reads only paths inside the tree it was given (AC15): $outside
$out_next"
done
no_absolute "$out_next" "$NESTED"
if ! diff <(run "$NESTED" --next) <(run "$NESTED" --next) >/dev/null; then
  fail "two --next runs over the unchanged non-repository fixture disagreed; with no commit dates
at all the answer is still deterministic (AC13):
$(diff <(run "$NESTED" --next) <(run "$NESTED" --next))"
fi

# 14d — two artefacts committed at the SAME pinned instant: the lower number wins.
# The lower number is the SPEC and the higher is the PLAN, so path order and number order
# disagree: `ai-factory/plans/…` sorts before `ai-factory/specs/…`, which means an implementation
# that broke the tie on path — or simply answered with the default listing's first row — would
# name the plan. Only the number rule names the spec.
NEXTTIE=$TMP/next-tie
mkdir -p "$NEXTTIE/ai-factory/specs" "$NEXTTIE/ai-factory/plans"
TIE_SPEC=ai-factory/specs/0095-lower-number.md
TIE_PLAN=ai-factory/plans/0096-higher-number.md
printf '# 0095 — lower number\n' > "$NEXTTIE/$TIE_SPEC"
{ printf '# Plan 0096 — higher number\n\n## Steps\n\n'
  printf -- '- [ ] **Step 1 — the culvert lined.** Proved by a fixture.\n'
} > "$NEXTTIE/$TIE_PLAN"

ginit "$NEXTTIE" || fail "git init failed in $NEXTTIE."
gadd "$NEXTTIE" "$TIE_PLAN"; commit_at "$NEXTTIE" "$SAME" 'the higher number, committed first'
gadd "$NEXTTIE" "$TIE_SPEC"; commit_at "$NEXTTIE" "$SAME" 'the lower number, committed second'
[ -n "$(ct_of "$NEXTTIE" "$TIE_SPEC")" ] \
  || fail "the tie fixture has no commit dates, so it would prove the no-git case instead of the
tiebreak."
[ "$(ct_of "$NEXTTIE" "$TIE_SPEC")" = "$(ct_of "$NEXTTIE" "$TIE_PLAN")" ] \
  || fail "the two artefacts in the tie fixture do not share a commit date — $(ct_of "$NEXTTIE" "$TIE_SPEC")
against $(ct_of "$NEXTTIE" "$TIE_PLAN") — so there is no tie to break and the assertion below would
pass on the commit date alone."

out_def=$(run "$NEXTTIE")
grep -qF -- "$TIE_PLAN" <<<"$(sed -n 2p <<<"$out_def")" \
  || fail "the default listing's first row is not the higher-numbered plan, so 14d no longer
distinguishes the number tiebreak from answering with the first row of the default listing:
$out_def"
out_next=$(run "$NEXTTIE" --next); st=$?
[ "$st" = 0 ] || fail "--next exited $st over the tie fixture:
$out_next"
[ "$(lines "$out_next")" = 3 ] \
  || fail "--next answered in $(lines "$out_next") lines over the tie fixture; one header, one row,
one reason (AC6):
$out_next"
[ "$(hits "$out_next" "$TIE_SPEC")" = 2 ] \
  || fail "--next did not select the LOWER-numbered artefact when two share a commit date. Ties
break on the artefact's leading four-digit number, lowest first — and here the lower number sorts
LATER by path, so nothing but the number rule can have chosen it (plan 0010, Ambiguity A):
$out_next"
[ "$(hits "$out_next" "$TIE_PLAN")" = 0 ] \
  || fail "--next named the higher-numbered artefact, which is the answer a path tiebreak or a
first-row-of-the-listing rule gives:
$out_next"
[ "$(sed -n 2p <<<"$out_next")" = "$(row "$out_def" "$TIE_SPEC")" ] \
  || fail "--next's row over the tie fixture is not byte-identical to the default listing's row for
the same artefact (AC6):
--next:  $(sed -n 2p <<<"$out_next")
default: $(row "$out_def" "$TIE_SPEC")"
grep -qi -- 'number' <<<"$(sed -n 3p <<<"$out_next")" \
  || fail "--next's reason line does not say which tiebreak decided. AC6 requires the one line to
say WHY, and here the commit dates were equal — the number is the whole reason:
$(sed -n 3p <<<"$out_next")"

# --next over a repo with nothing outstanding is the same one-line answer the default listing
# gives: there is no item to pick up, and that is an answer rather than an error (AC11).
if ! diff <(run "$TMP/bare") <(run "$TMP/bare" --next) >/dev/null; then
  fail "--next and the default listing gave different answers for a repo with no layout at all;
the empty answer is the same one line either way (AC11):
$(diff <(run "$TMP/bare") <(run "$TMP/bare" --next))"
fi

echo "state ok — 14 sections: empty answer, the default listing with [~] and done/, determinism, \
the read-only snapshots, unknown-with-a-reason, the three **Spec:** link forms, sibling isolation, \
the prompt's two invariants, the command named in README.md and the workflow doc, --done as the \
default listing's mirror image, checkboxes over directory under the filter, --done's empty answer, \
the prompt's hand-off with \$ARGUMENTS still last, and --next by commit date with its untracked, \
non-repository and same-instant cases"
