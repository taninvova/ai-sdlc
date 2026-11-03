# ASD-001 — Effort and risk triage
Created: 2026-10-29T19:42:06.587Z

**Goal:** Explorations and specs rate effort S/M/L/XL against one shared rubric and triage risk triggers, specs carry a labelled feature-level time range and a revise-in-place re-run, plan steps carry an `Effort: … · Estimate: …` line, and `/fc:start` takes a named spec's or exploration's effort into account, all without duplicating `/fc:risk`.

**Spec:** `ai-factory/specs/ASD-001-effort-and-risk-triage.md` (parent: `ai-factory/explorations/ASD-001-complexity-and-risk-in-explore-and-spec.md`, option A, D1–D7).

No `ai-factory/risks/ASD-001-*.md` exists, so no mitigation is carried into this plan. Artifact contracts are not enabled in this repo.

## Design

- **One rubric, three copies.** A `## Effort rubric` section, word for word the same, is added to `agents/explorer.md`, `agents/specifier.md` and `agents/planner.md`. It runs from that heading to the next `## ` heading. It holds the size table (AC2), the uncertainty table (AC3), and the sentence "the final effort is the higher of the two" (AC1). The equality check compares those sections byte for byte across the three canonical agents and their materialized copies under `skills/ai-layout/templates/ai-factory/agents/` (AC4).
- **The risk passage must stay one block.** `check-risk.sh` `riskPassage()` requires exactly one paragraph or list item in the specifier and in the planner that contains the literal `ai-factory/risks/`, ending with "No applicable assessment: nothing here changes." The triage paragraph (AC11–AC15) and the re-run section (AC18–AC20) therefore:
  - sit in their own blocks, directly after the existing risk paragraph;
  - never repeat the literal `ai-factory/risks/` and refer instead to "the risk file the rule above names".

  This keeps `check-risk.sh` 706–712 passing without edits (AC15).
- **The specifier re-run has its own section.** `check-ids.sh` `specifier-parent-rule` forbids a sentence in `## What you may write` that pairs "exit 3" with "report" or "write nothing". So:
  - The exit-3 bullet gains only the clause AC16 needs: the run is a re-run only when the request names the existing spec's path. Otherwise it keeps today's behaviour: run the helper again without `--id`, take the next free ID and cite the parent's path.
  - A new `## Re-run on an existing spec` section holds AC18–AC22. On a re-run the specifier does not call `ids.js` at all, because the spec already exists.
- **Start: a new rule 7, rules 1–6 untouched.** `check-risk.sh` `start-allowlist-unchanged` compares rule 6 with the baseline, and `start-rule3-suggests-risk` allows `/fc:risk` only in rule 3 and the one exception sentence. The effort rule is therefore appended as rule 7. It says it is applied only after rule 3 (AC34) and names no `/fc:risk`.
  - The "Use only these fields." line gains the optional `effort` field. The "Never return commands … it is never the routed task." sentence stays byte-identical.
- **Start result validator.** `validateStartResult` in `skills/ai-layout/templates/ai-factory/make/models.js` accepts one optional key, `effort`, with value `S`, `M`, `L` or `XL`, on any status. It returns `effort` only when the input had it. Every other key, length and allowlist rule is unchanged (AC38).
  - This deliberately breaks the byte-equality assertion `validateStartResult differs from main` in `check-risk.sh` `start-allowlist-unchanged`. That assertion is replaced with behavioural equality: every legacy shape validates and is rejected as before, `START_TASKS` is unchanged, and `effort` is the only new key. It is a changed expectation and goes in the MR (AC40).
- **Plan step line.** The format is `Effort: <S|M|L|XL> · Estimate: dev <range> h, /fc:run ~<range> min (assumption: <what it rests on>)`, in the indented body, never in the title. The line contains no `AC<n>` and no `Verify`. `parsePlanSteps`, `loop.js` and `state.sh` are not changed (out of scope). The new tests prove they are unaffected (AC28).
- **`tasks/plan.md` wording limit.** `check-risk.sh` `plan-task-unchanged` forbids `/fc:risk`, `risks/`, `` `risk` ``, "assessment" and "mitigation" in `tasks/plan.md`, so its new clause uses none of them.

## Files

| File | Why |
|---|---|
| `agents/explorer.md` | Rubric; per-option effort S/M/L/XL with a reason (renaming the old "S/M/L"); `Effort and risk` subsection for the recommended option, no time figure; present triggers recommend `/fc:risk` once the spec exists, never in Open questions (AC1–AC8). |
| `agents/specifier.md` | Rubric; `Effort and risk` section before Open questions (one rating, feature-level dev-hours and `/fc:run` ranges labelled as assumptions, independent of plan steps); triage of 8 categories and 6 triggers; the "Run `/fc:risk <spec path>`" open question; the exit-3 clause; the re-run section (AC1–AC5, AC9–AC22). |
| `agents/planner.md` | Rubric; the per-step `Effort: … · Estimate: …` line and its rules (AC1–AC5, AC25–AC29). |
| `skills/ai-layout/templates/ai-factory/agents/{explorer,specifier,planner}.md` | Materialized copies, regenerated by `materialize-agents.js`, never hand-edited. |
| `skills/ai-layout/templates/ai-factory/tasks/spec.md` | Re-run rule (AC16) and `Effort and risk` named in the delegation instruction (AC24). |
| `skills/ai-layout/templates/ai-factory/tasks/plan.md` | The step line, its placement, ranges and assumption labels, never summed or dated (AC25, AC27, AC29). |
| `skills/ai-layout/templates/ai-factory/tasks/start.md` | Rule 7 (AC32–AC37, AC39) and the optional `effort` field (AC38). |
| `skills/ai-layout/templates/ai-factory/make/models.js` | `validateStartResult` and `validate-start` accept and pass through optional `effort` (AC38). |
| `skills/ai-layout/scripts/check-effort.sh` (new) | Groups `rubric`, `explorer`, `specifier`, `rerun`, `planner`, `readers`, `docs`: the rubric-equality check (AC4) and the static and fixture assertions for this spec. `make check` picks it up through its glob. |
| `skills/ai-layout/fixtures/effort/` (new) | Fixture specs (with and without the section, with and without the "Run `/fc:risk`" line), fixture risk files (open blocker/major, mitigated/accepted/minor, with and without `## Reassessment`), and a fixture plan with and without the step line (AC23, AC28, AC41). |
| `skills/ai-layout/scripts/check-loop.sh` | New `procedures` case `planner-effort-line` for the AC25 format in both planner copies and `tasks/plan.md`; the existing `planner-depends-on` stays (AC30). |
| `skills/ai-layout/scripts/check-contracts.sh` | Planner needle list adds the step-line format; existing needles stay (AC30). |
| `skills/ai-layout/scripts/check-start-routing.sh` | New `dispatch` checks for AC33, AC35–AC38 (AC40). |
| `skills/ai-layout/fixtures/start-routing/cases.md` | Host-run rows for the effort cases (AC33, AC35–AC37, AC39); static checks do not prove classification. |
| `skills/ai-layout/scripts/check-risk.sh` | `start-allowlist-unchanged`: the validator byte-equality assertion becomes behavioural equality plus `effort` (listed in the MR). Lines 706–712 are not touched. |
| `ai-factory/docs/workflow.md`, `README.md` | Only where they describe `/fc:start`'s result or a plan step's body: name the optional `effort` field and the step line. |
| `CHANGELOG.md` | Breaking template change entry (AC42); see Ambiguity 6. |

Not touched: `agents/analyst.md` (AC31), `agents/risk.md`, `make/contracts.js`, `make/loop.js`, `state.sh` (unless Step 6 proves a reader differs; see AC41), `check-risk.sh` lines 706–712, generated `commands/` and `codex-skills/`. Those reference `ai-factory/tasks/<task>.md` and do not embed task text; they are verified by `--check`, and regenerated only if `--check` reports drift.

## Server versus client

N/A. There is no application, UI or service. These are markdown prompts, one Node validator in a template make script, and bash/Node checks.

## Steps

- [x] Step 1 — Harness, shared rubric and the explorer (AC1–AC8).
  - Create `check-effort.sh` with every group listed in Files. A group a later step fills fails with "no cases yet". Each case reports a missing file or section as its own failure, never as a crash.
  - Write the `rubric` and `explorer` groups first. Then add `## Effort rubric` to the three agents, and change the explorer: the effort column, the `Effort and risk` subsection, and the present-trigger recommendation. Run `node skills/ai-layout/scripts/materialize-agents.js`.
  - Tests:
    - `rubric` group:
      - `rubric-present` (AC1): both dimensions, S–XL, "higher of the two"
      - `rubric-size` (AC2)
      - `rubric-uncertainty` (AC3)
      - `rubric-identical` (AC4): all six copies are equal; a copy mutated by one character in memory makes the comparator fail
      - `effort-named` (AC5): the three agents say "effort"; the explorer no longer says `S/M/L` without XL
    - `explorer` group:
      - `explorer-option-effort` (AC6)
      - `explorer-effort-and-risk` (AC7): the subsection, the rating, the triage and a "no time figure" prohibition
      - `explorer-present-triggers` (AC8): names present triggers, recommends `/fc:risk` once the spec exists, and keeps it out of Open questions
  - Verify (red): `bash skills/ai-layout/scripts/check-effort.sh rubric` and `bash skills/ai-layout/scripts/check-effort.sh explorer`. Every case listed fails because the agents have no `## Effort rubric` section and the explorer still says "effort (S/M/L with a reason)". A missing `check-effort.sh` is not red evidence.
  - Verify (step):
    - the same two commands pass
    - `node skills/ai-layout/scripts/materialize-agents.js --check`
    - `bash skills/ai-layout/scripts/check-ids.sh procedures`: the explorer still calls the helper and does not count

- [x] Step 2 — Specifier first run: the `Effort and risk` section and the triage (AC9–AC15, the section half of AC24).
  - Depends on: 1
  - Add the section to `## The spec`, directly before Open questions. Add the triage paragraph as a separate block right after the existing risk-file paragraph, which stays byte-identical and is never re-quoted (see Design).
  - Add the AC13 and AC14 open-question rule. In `tasks/spec.md`, name `Effort and risk` in the delegation's section list. Materialize the agents.
  - Tests, in the `specifier` group:
    - `spec-section` (AC9): placed before Open questions; one feature rating, not per AC; dev-hours and `/fc:run` ranges, each labelled as an assumption
    - `spec-range-independent` (AC10)
    - `spec-triage-items` (AC11): all 8 categories and 6 triggers by name; `present`/`absent`; one line of evidence each
    - `spec-triage-no-severity` (AC12)
    - `spec-run-risk-question` (AC13): the exact "Run `/fc:risk <spec path>`" text, conditional on a present item and no risk file
    - `spec-no-run-risk-when-absent` (AC14)
    - `spec-triage-beside-risk-rule` (AC15): the triage block is the block right after the risk passage, and the risk passage is byte-identical to `git show HEAD:agents/specifier.md`'s
    - `spec-task-names-section` (AC24, first half)
  - Verify (red): `bash skills/ai-layout/scripts/check-effort.sh specifier`. Every case fails because the specifier has no `Effort and risk` section or triage text. `spec-triage-beside-risk-rule` fails on the missing triage block.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-effort.sh specifier`
    - `bash skills/ai-layout/scripts/check-effort.sh rubric`
    - `bash skills/ai-layout/scripts/check-risk.sh consumers` (AC15, unedited)
    - `bash skills/ai-layout/scripts/check-ids.sh procedures`
    - `node skills/ai-layout/scripts/materialize-agents.js --check`

- [x] Step 3 — Specifier re-run: revise in place (AC16–AC23, the re-run half of AC24).
  - Depends on: 2
  - Add the AC16 clause to the exit-3 bullet. Add the `## Re-run on an existing spec` section:
    - no risk file: leave the spec byte-for-byte unchanged and report that `/fc:risk <spec path>` still has to be run;
    - a risk file present: remove the "Run `/fc:risk`" line and add the open blocker/major findings from the latest Reassessment (or the body above the first one), citing the risk file's path;
    - leave everything else unchanged, the heading and `Created:` included;
    - rerun `contracts.js init spec` when `ai-factory/contracts/config.json` exists.
  - In `tasks/spec.md`, describe the AC16 rule. Add the fixtures under `skills/ai-layout/fixtures/effort/rerun/`. Materialize.
  - Tests, in the `rerun` group (AC23: each case loads its fixture and asserts the procedure's wording for that case):
    - `rerun-only-when-named` (AC16)
    - `rerun-unnamed-new-id` (AC17)
    - `rerun-no-risk-file-unchanged` (AC18)
    - `rerun-removes-line` (AC19)
    - `rerun-adds-open-findings` (AC20): the fixture holds open blocker, open major, mitigated, accepted and minor findings across an initial body and two Reassessments; only the latest section's open blocker/major are named
    - `rerun-rest-unchanged` (AC21)
    - `rerun-contracts-digest` (AC22)
    - `rerun-task-rule` (AC24, second half)
  - Verify (red): `bash skills/ai-layout/scripts/check-effort.sh rerun`. Every case fails because the specifier has no re-run section and its exit-3 bullet does not mention a named spec path.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-effort.sh rerun`
    - `bash skills/ai-layout/scripts/check-effort.sh specifier`
    - `bash skills/ai-layout/scripts/check-ids.sh procedures` (`specifier-parent-rule` must still pass: no exit-3 sentence says "report" or "write nothing")
    - `bash skills/ai-layout/scripts/check-risk.sh consumers`
    - `node skills/ai-layout/scripts/materialize-agents.js --check`

- [x] Step 4 — Planner step line and `tasks/plan.md` (AC25–AC31).
  - Depends on: 1
  - Add the line format, rubric reuse on the step's own scope, its placement (body, never the title, no `AC<n>`/`Verify`), and "ranges, labelled as assumptions, never summed or turned into a date" to `agents/planner.md` and `tasks/plan.md`. Keep `tasks/plan.md` free of the words `check-risk.sh` `plan-task-unchanged` forbids. Add `skills/ai-layout/fixtures/effort/plan-with-effort.md` and its twin without the lines. Materialize.
  - Tests:
    - `check-effort.sh planner` group:
      - `planner-step-line` (AC25): the format, in the planner and `tasks/plan.md`
      - `planner-same-rubric` (AC26)
      - `planner-line-placement` (AC27)
      - `planner-ranges-never-summed` (AC29)
      - `analyst-rule-unchanged` (AC31): the exact sentence in `agents/analyst.md`, and the file unchanged against `HEAD`
      - `effort-named-plan-task` (AC5, `tasks/plan.md`)
      - `parse-invariant` (AC28): the two fixture plans give equal results for `parsePlanSteps` titles, bodies' `Depends on:`, `draftVerify` commands and covered AC IDs, `loop.js` schedule validation, and `state.sh` rows for that plan
    - `check-loop.sh procedures` `planner-effort-line` (AC30, the new assertion); `planner-depends-on` and `plan-template-depends-on` unchanged
    - `check-contracts.sh`: the planner needle list gains the line format (AC30)
  - Verify (red): `bash skills/ai-layout/scripts/check-effort.sh planner` and `bash skills/ai-layout/scripts/check-loop.sh procedures`.
    - The `planner` cases except `analyst-rule-unchanged` and `parse-invariant` fail because the planner and `tasks/plan.md` do not define the line. `planner-effort-line` fails for the same reason.
    - `analyst-rule-unchanged` and `parse-invariant` are expected to pass in red: they guard behaviour that must not change.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-effort.sh planner`
    - `bash skills/ai-layout/scripts/check-effort.sh rubric`
    - `bash skills/ai-layout/scripts/check-loop.sh procedures`
    - `bash skills/ai-layout/scripts/check-contracts.sh`
    - `bash skills/ai-layout/scripts/check-risk.sh consumers` (`plan-task-unchanged`, `planner-mitigations`)
    - `bash skills/ai-layout/scripts/check-ids.sh procedures`
    - `node skills/ai-layout/scripts/materialize-agents.js --check`

- [x] Step 5 — `/fc:start` reads effort (AC32–AC40).
  - Depends on: 1
  - Append rule 7 to `tasks/start.md`. It says:
    - read a rating only from a spec or exploration path the request names;
    - the spec's rating wins over the exploration's;
    - apply it only after rule 3;
    - L or XL is never quick or chore, and fix is allowed; the replacement is spec when a spec exists, otherwise explore;
    - S or M changes nothing;
    - when the rating changed the destination, reason mentions it.

    Extend the field list with optional `effort`. Change `validateStartResult` and the `validate-start` CLI. Update `check-risk.sh` `start-allowlist-unchanged` as Design says, and add the effort rows to `fixtures/start-routing/cases.md`.
  - Tests, in `check-start-routing.sh dispatch`:
    - `start-effort-source` (AC32, AC33): static rule 7 wording
    - `start-effort-after-rule3` (AC34): rule 7 follows rule 3 and says so; rules 1–6 are byte-equal to `HEAD`
    - `start-effort-large` (AC35, AC37)
    - `start-effort-small-neutral` (AC36)
    - `start-effort-field` (AC38): `validateStartResult` and `validate-start` accept `effort` S/M/L/XL on each status and return it; they reject `effort: "XXL"`, `"m"`, `1` and `null`; a result without it returns no `effort` key; every legacy accept/reject case is unchanged
    - `start-effort-reason` (AC39): static
    - `start-effort-host-cases` (AC33, AC35–AC37, AC39): `cases.md` has rows `effort-spec-wins`, `effort-large-no-quick`, `effort-large-fix`, `effort-small`, `effort-large-explore`, `effort-reason`
  - Verify (red): `bash skills/ai-layout/scripts/check-start-routing.sh dispatch`.
    - The new cases fail: start.md has no rule 7, `validateStartResult` rejects the `effort` key as an extra field, and `cases.md` has no effort rows.
    - The existing cases (`start-read-only`, `start-result-validation`, `start-session-handoff`, `destination-model-independent`, `other-workers-unchanged`) pass.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-start-routing.sh` (all groups)
    - `bash skills/ai-layout/scripts/check-risk.sh start`
    - `node --check skills/ai-layout/templates/ai-factory/make/models.js`
    - `bash skills/ai-layout/scripts/check-interactive-model-routing.sh`
    - `node skills/ai-layout/scripts/sync-claude-commands.js --check`
    - `node skills/ai-layout/scripts/sync-codex-skills.js --check`

- [x] Step 6 — Readers of the new spec section (AC41).
  - Depends on: 2
  - Add `readers` cases. A contracts-enabled scratch fixture runs `contracts.js init spec` on a spec with the `Effort and risk` section and on the same spec without it. The triage evidence lines include an `AC3`-style mention inside a list item, and a line that begins `- authorization: present — …`.
  - Expected: the same AC IDs and no new diagnostics. `continue.js` reports the same drift result for an unchanged spec, and `S_SPEC_CHANGED` after the section is edited, as for any other edit.
  - If a reader differs, fix the reader in this step and record which of the two outcomes applied for the MR (AC41).
  - Tests, in the `readers` group:
    - `readers-ac-ids` (AC41)
    - `readers-drift` (AC41)
  - Verify (red): none expected. This step proves existing behaviour, so a passing first run is the expected outcome, recorded as "readers unchanged". Only a failing case leads to a reader change.
  - Verify (step):
    - `bash skills/ai-layout/scripts/check-effort.sh readers`
    - `bash skills/ai-layout/scripts/check-continuation.sh`
    - `bash skills/ai-layout/scripts/check-contracts.sh`

- [x] Step 7 — Docs, CHANGELOG, before/after runs and final verification (AC42, AC43).
  - Update `ai-factory/docs/workflow.md` and `README.md` only where they describe `/fc:start`'s result or a plan step's body. Add the CHANGELOG entry, marked breaking for adopted repos (placement: Ambiguity 6). It names:
    - the rubric;
    - the spec section and the re-run;
    - the plan step line;
    - the optional `effort` field.
  - **Host runs.** In a scratch adopted repo, record a before/after run for each changed prompt and link them in the MR:
    - `/fc:explore`, `/fc:spec` (first run with a present trigger; first run all absent; re-run named with and without a risk file);
    - `/fc:plan`;
    - `/fc:start` (an L spec on a quick-shaped request; spec plus exploration with different ratings; an S spec).

    If the developer waives them, record which ACs then rest only on static checks: AC6–AC8, AC13, AC14, AC17–AC22, AC25, AC33, AC35–AC37, AC39.
  - The MR lists the changed check expectation (`check-risk.sh` `start-allowlist-unchanged`) and the AC41 outcome from Step 6.
  - Tests, in the `docs` group:
    - `changelog-breaking` (AC42): the entry exists, says breaking, and names the four changes
    - `docs-start-effort`
  - Verify (red): `bash skills/ai-layout/scripts/check-effort.sh docs`. Both cases fail because the CHANGELOG and docs carry no entry for this change.
  - Verify (final), all required:
    - `for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done`
    - `node --check skills/ai-layout/templates/ai-factory/make/models.js`
    - `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`
    - `bash -n skills/ai-layout/scripts/check-effort.sh`
    - `node skills/ai-layout/scripts/materialize-agents.js --check`
    - `node skills/ai-layout/scripts/sync-claude-commands.js --check` (AC43)
    - `node skills/ai-layout/scripts/sync-codex-skills.js --check` (AC43)
    - `bash skills/ai-layout/scripts/check-effort.sh` (all groups; AC1–AC29, AC31, AC41, AC42)
    - `for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f" || echo "FAIL $f"; done`: no `FAIL` line (AC30, AC40, AC43; never piped to `tail`)
    - `make check` (stops at the first failing script)
    - `git diff HEAD -- agents/analyst.md agents/risk.md`: the output must be empty (AC31, out of scope)
    - `git diff HEAD -- skills/ai-layout/templates/ai-factory/make/contracts.js skills/ai-layout/templates/ai-factory/make/loop.js skills/ai-layout/scripts/state.sh`: the output must be empty, unless Step 6 recorded a reader change
    - `node skills/ai-hooks/scripts/session-stop.js < skills/ai-hooks/fixtures/stop.json`

## Risks and how each is checked

- **The triage or re-run text splits the risk passage.** A second block naming `ai-factory/risks/` makes `riskPassage` throw, and a block appended to the passage breaks "ends with No applicable assessment". Checked by `check-risk.sh consumers` in the step verification of Steps 2–4, and by `spec-triage-beside-risk-rule`.
- **The re-run wording trips `check-ids.sh` `specifier-parent-rule`.** That happens if an exit-3 sentence in "What you may write" says "report" or "write nothing". Checked by `check-ids.sh procedures` in Step 3.
- **Revise-in-place damages a spec.** It is a new write path. AC21 limits it to Open questions; `rerun-rest-unchanged` checks the wording, and the Step 7 re-run transcript checks the behaviour with a byte diff of the spec outside Open questions.
- **The validator change weakens the start contract.** The only new key is `effort`, with a closed value set. `start-effort-field` rejects other values, and `start-result-validation` (unchanged) still rejects `command` and `model`. The replaced byte-equality assertion is listed in the MR.
- **Rule 7 shifts existing routing.** Rules 1–6 stay byte-equal, which `start-effort-after-rule3` and `check-risk.sh start` check. Classification shifts are visible only in host runs; the `cases.md` rows and the Step 7 `/fc:start` runs cover them.
- **The step line changes plan parsing.** `parse-invariant` (Step 4) compares the parsers with and without the line, and `check-loop.sh` and `check-state.sh` run in final.
- **Time ranges read as commitments.** The wording requires ranges and an `(assumption: …)` label, never summed or dated. `planner-ranges-never-summed` and `spec-section` check it. The analyst rule stays, checked by `analyst-rule-unchanged`.
- **"Not buildable" is a convention only (D3).** The spec puts enforcement out of scope, so no check is added. The MR says so.
- **The materialized copies drift.** Checked by `materialize-agents.js --check` in every step, and by `rubric-identical` across all six copies.
- **The template change breaks adopted repos.** The CHANGELOG entry (AC42) is checked by `changelog-breaking`. `check-release-docs.sh` (final) keeps the top entry's version aligned with `plugin.json`.
- **The full suite is red between steps** while later `check-effort.sh` groups are unfilled. Each step's verification names its groups; the full suite is required only in final.

## Ambiguities in the spec

1. **AC37 with only an exploration named.** If a request names only an L/XL exploration, AC37 routes to `explore` even though that exploration already exists. `spec` might fit better there. The plan follows AC37 literally. AC37 also does not say how it interacts with rule 5's analyse/design prerequisites; the plan applies AC37 only where start would otherwise have chosen quick or chore.
2. **Chore ruled out by L/XL.** AC35 forbids `chore`, but AC37 names a replacement only for a ruled-out `quick`. The plan gives a ruled-out `chore` the same replacement (`spec` if a spec exists, otherwise `explore`).
3. **`effort` on non-route results.** AC38 says the field is present whenever a rating was read, without limiting it to `status: route`. The plan accepts it on `route`, `question` and `blocked` alike.
4. **AC40 "evaluations".** `check-start-routing.sh` cannot run the classifier, because it is offline and static. The plan reads "evaluations" as static assertions on rule 7, validator cases and `cases.md` host-run rows. Classification itself is proved only by the Step 7 host runs.
5. **Re-run with a risk file but no "Run `/fc:risk`" line.** No AC covers it, for example when every triage item was `absent` but a risk file was written anyway. The plan leaves the spec unchanged and has the report say there is nothing to revise.
6. **CHANGELOG placement.** `check-release-docs.sh` requires the top `## ` entry to be a version matching `.claude-plugin/plugin.json`, so a bare `## Unreleased` heading fails it. The plan adds an unreleased block inside the top entry, as earlier deliveries did. Whether this ships as a version bump is a release decision outside this plan.
7. **The re-run does not call `ids.js`.** AC16 phrases the re-run rule under exit 3, but a request naming an existing spec's path needs no new file. The plan has the specifier skip the helper on a re-run, and keeps the exit-3 clause only to tell the two cases apart.
8. **AC41 outcome.** By reading the code (`parseIds` only counts lines whose first token is `AC<n>`; the drift digest covers the whole spec), the plan expects "unchanged". Step 6 confirms this; a triage evidence line that starts with an AC ID would be the one way to break it, so the specifier wording tells evidence lines to start with the item name.
