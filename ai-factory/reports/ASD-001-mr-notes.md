# ASD-001 — Effort rubric and risk-trigger triage: MR description

Spec: `ai-factory/specs/ASD-001-effort-and-risk-triage.md` · Plan:
`ai-factory/plans/ASD-001-effort-and-risk-triage.md` · Exploration:
`ai-factory/explorations/ASD-001-complexity-and-risk-in-explore-and-spec.md` (option A).

## What changes

- One `## Effort rubric` (size and uncertainty, each S/M/L/XL, final effort the higher of the two),
  word for word the same in the explorer, specifier and planner agents and their materialized
  template copies.
- Explorations rate each option S/M/L/XL with a reason and add an `Effort and risk` subsection
  for the recommended option (no time figure).
- Specs gain a `## Effort and risk` section before Open questions: one feature rating, labelled
  dev-hours and `/fc:run` ranges, and a triage of the eight risk categories and six `/fc:start`
  risk triggers. A present item with no risk assessment adds "Run `/fc:risk <spec path>`" to Open
  questions.
- `/fc:spec` asked to revise an existing spec, by its path, re-runs on it and revises it in place;
  a spec path cited only as context still gets a new spec.
- Plan steps carry `Effort: <S|M|L|XL> · Estimate: dev <range> h, /fc:run ~<range> min (assumption: <what it rests on>)`
  in their indented body.
- `/fc:start` gains rule 7 (effort after risk) and an optional `effort` result field, accepted by
  `validateStartResult` and `models.js validate-start`.
- New check `skills/ai-layout/scripts/check-effort.sh` (groups rubric, explorer, specifier, rerun,
  planner, readers, docs) and fixtures under `skills/ai-layout/fixtures/effort/`.

## Breaking for adopted repos

Template changes are breaking for every adopted repo: `agents/explorer.md`, `agents/specifier.md`,
`agents/planner.md` and `tasks/spec.md`, `tasks/plan.md`, `tasks/start.md` and `make/models.js`
under `skills/ai-layout/templates/ai-factory/` change. Adopted repos take them with
`/fc:sync-sdlc` and must preserve their local edits. The CHANGELOG records this inside the top
`4.0.0` entry as an unreleased block (no version bump; a bare `## Unreleased` heading would fail
`check-release-docs.sh`).

## Changed check expectation

- `check-risk.sh` `start-allowlist-unchanged` (plan Step 5): the assertion that
  `validateStartResult` is **byte-equal** to `main` was replaced by a **behavioural** comparison.
  Main's function is run with main's allowlist over every legacy accept/reject shape and must
  give the same result as the new one; `START_TASKS` is still compared as before; and `effort`
  (S, M, L or XL, on any status) is the only key newly accepted, with `XXL`, `m`, `1` and `null`
  rejected. This is a deliberate change of expectation, required by AC38.
- `check-effort.sh` `spec-triage-beside-risk-rule` and `analyst-rule-unchanged`, and
  `check-start-routing.sh` `start-effort-after-rule3`, compare against the pre-change commit
  `1111ef8f0b422bf5d87f0bd9ffc75a554c1a39f5`, not `HEAD`, so they stay meaningful after this delivery is committed. Each now also
  proves in memory that a changed passage fails the comparison.

## AC41 outcome

**Readers unchanged** (plan Step 6). `contracts.js` (AC IDs, digest, validation),
`delivery-report.js` and `continue.js` give the same results for a spec with the
`Effort and risk` section as for the same spec without it, and report `S_SPEC_CHANGED` after an
edit to the section exactly as after any other spec edit. No reader was changed:
`make/contracts.js`, `make/loop.js` and `scripts/state.sh` have no diff.

## Before/after runs: waived

The before/after host runs that plan Step 7 calls for (`/fc:explore`; `/fc:spec` first run with a
present trigger, first run all absent, re-run named with and without a risk file; `/fc:plan`;
`/fc:start` on an L spec with a quick-shaped request, on a spec plus exploration with different
ratings, and on an S spec) were **waived by the developer**. No transcript is linked. The waiver
is now part of the spec: AC42 is amended to record the owner's waiver of the host runs.

These acceptance criteria therefore rest on static checks only (the wording of the procedures,
fixtures and validator cases), not on observed agent behaviour:
AC6, AC7, AC8, AC13, AC14, AC17, AC18, AC19, AC20, AC21, AC22, AC25, AC33, AC35, AC36, AC37 and AC39.
The host-run rows for the `/fc:start` cases are listed in
`skills/ai-layout/fixtures/start-routing/cases.md` for a later run.

The "not buildable" convention for a spec carrying "Run `/fc:risk`" (D3) is a convention only;
the spec puts enforcement out of scope, so no check enforces it.

## Review fixes

1. **Re-run trigger narrowed** (major). Naming a spec's path no longer makes a re-run by itself:
   the named spec must be the one being revised, because the request asks to revise or re-run it
   or it holds the parent's ID the helper reports as taken (exit 3). A spec path cited as context
   leads to a new spec by the exit-3 rule. Changed: `agents/specifier.md` (exit-3 rule and
   `Re-run on an existing spec`), `tasks/spec.md`; fixture case `cites-other-spec-new-id` and the
   `check-effort.sh rerun` case `rerun-cited-spec-new-id`.
2. **`/fc:risk` report only when the spec asks for it** (major). With no risk file, the re-run
   reports that `/fc:risk` is still due only when Open questions contain
   "Run `/fc:risk <spec path>`"; otherwise (for example an all-absent triage) it reports that there is nothing to
   revise and leaves the spec unchanged. Fixture case `named-no-risk-file-all-absent` and the
   `check-effort.sh rerun` case `rerun-no-risk-file-nothing-to-revise`.
4. **Full baseline SHA** (minor). `check-effort.sh` and `check-start-routing.sh` name the
   pre-change commit by its full SHA and fail with a clear message when it is missing, such as in
   a shallow clone, following `check-risk.sh`.
5. **CHANGELOG pointer** (minor). The CHANGELOG points at this file, not the plan, for the
   acceptance criteria that rest on static checks only.

## Spec notes

- AC31 now quotes the analyst's rule in its real, lowercase form: "no invented effort, cost, ROI,
  dates or story points". `agents/analyst.md` and `agents/risk.md` are unchanged.
- AC16–AC18 were amended after review to match the narrowed re-run rule (review fixes 1 and 2),
  including the owner-confirmed edge case: a request that cites the spec the helper reports on
  exit 3, even only as context, is a re-run. No fixture case covers that edge case yet.
