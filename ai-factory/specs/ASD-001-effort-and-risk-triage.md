# ASD-001 — Effort rubric and risk-trigger triage in explorations, specs, plans and start
Created: 2026-10-29T19:26:04.234Z

Explorations and specs rate a feature's effort S/M/L/XL against one shared size-and-uncertainty rubric and triage its risk triggers, specs also carry a labelled feature-level time range, plans give every step an effort rating and two labelled time ranges, and `/fc:start` takes an effort rating from a named spec or exploration into account when it routes.

Parent: ai-factory/explorations/ASD-001-complexity-and-risk-in-explore-and-spec.md (option A, decisions D1–D7; the owner accepted the specifier revise-in-place rule described there).
Departure from the exploration: D6 and its accompanying framing allowed time figures in plan steps only. The owner decided on 2026-10-29, answering this spec's open questions, that a spec may also carry a feature-level time range (AC9). Explorations still carry no time figures, and plan steps are still never summed.

## User story
As a developer using the ai-sdlc workflow, I want explorations, specs and plans to state how much work a feature is and which risk triggers it carries, so that I can see the size before I commit to it, know when to run `/fc:risk`, and let `/fc:start` avoid shortcuts for large work, without duplicating the full assessment `/fc:risk` (spec 0023) already does.

## Acceptance criteria
Paths are the canonical files (`agents/…`, `skills/ai-layout/templates/ai-factory/tasks/…`); `ai-factory/agents/` and `ai-factory/tasks/` in this repo are symlinks to them.

**Rubric**
- **AC1.** Given `agents/explorer.md`, `agents/specifier.md` and `agents/planner.md`, when they are read, then each one contains an effort rubric with two dimensions, size and uncertainty, each rated S, M, L or XL, and states that the final effort is the higher of the two.
- **AC2.** Given the rubric, when its size dimension is read, then it defines S as 1 file, under 50 lines and no new tests; M as 2–5 files with tests; L as more than 5 files or a new artefact or check; and XL as cross-cutting work, or work that needs an ADR or a migration.
- **AC3.** Given the rubric, when its uncertainty dimension is read, then it defines S as a known pattern with no unknowns; M as a known pattern with minor unknowns; L as a new pattern or several unknowns; and XL as unknowns that need an exploration or a spike.
- **AC4.** Given the three agent files, when the new static check runs, then it passes only when the rubric text is identical in all three, and fails when any one copy differs by a single character.
- **AC5.** Given the three agent files and `tasks/plan.md`, when they are read, then the rating is called "effort" everywhere, including the explorer's per-option column, which no longer says "S/M/L" without XL.

**Explorer**
- **AC6.** Given the explorer procedure, when it describes an option, then the option's effort is one of S, M, L or XL, rated against the rubric, with a reason.
- **AC7.** Given the explorer procedure, when it describes the exploration's sections, then it requires an `Effort and risk` subsection for the recommended option, holding that option's effort rating and a risk-trigger triage, and no time figure.
- **AC8.** Given an exploration whose triage marks at least one trigger `present`, when the explorer writes it, then the exploration names each present trigger and recommends running `/fc:risk` once the spec exists, and adds nothing about `/fc:risk` or the triage to the exploration's Open questions.

**Specifier: first run**
- **AC9.** Given the specifier procedure, when it lists the spec's sections, then it requires an `Effort and risk` section placed immediately before Open questions, holding one effort rating (S, M, L or XL) for the whole feature, not one per acceptance criterion, and a feature-level time range in developer hours and in `/fc:run` time, each a range labelled as an assumption.
- **AC10.** Given the specifier procedure, when it describes the feature-level time range, then it states that the range is an independent estimate of the feature and not a sum of plan steps.
- **AC11.** Given the specifier procedure, when it describes the triage, then the triage marks each of the eight risk categories (authorization, data exposure, secrets, injection, dependency/supply chain, migrations, rollback, blast radius) and each `/fc:start` risk trigger (uncertain requirements, authorization, public contracts, migrations, dependencies, service ownership) as `present` or `absent`, each with one line of evidence.
- **AC12.** Given the specifier procedure, when it describes the triage, then it states that the triage carries no severity, no status and no mitigation.
- **AC13.** Given a spec whose triage marks at least one item `present` and no `ai-factory/risks/<spec ID>-*.md` exists, when the specifier writes it, then its Open questions contain "Run `/fc:risk <spec path>`".
- **AC14.** Given a spec whose triage marks every item `absent`, when the specifier writes it, then its Open questions do not contain a "Run `/fc:risk`" line.
- **AC15.** Given the specifier procedure, when it describes the `Effort and risk` section, then the triage instruction sits next to the existing instruction for reading `ai-factory/risks/<ID>-*.md`, and that existing instruction is unchanged, so `skills/ai-layout/scripts/check-risk.sh` lines 706–712 pass without edits.

**Specifier: re-run**
- **AC16.** Given the specifier procedure, when it describes `ids.js` exit 3, then it states that exit 3 alone never makes a re-run; that a run is a re-run only when the request names an existing spec's path and that spec is the one being revised, meaning the request asks to revise or re-run it, or it is the spec the helper prints on exit 3 for the parent's ID, so a request that cites that same spec, even only as context, makes the run a re-run; and that otherwise exit 3 keeps today's behaviour: run the helper again without `--id`, take the next free ID, cite the parent's path and leave the existing spec unchanged.
- **AC17.** Given a request that names no existing spec's path, or cites a spec path only as context and that spec is not the one the helper prints on exit 3, and `ids.js new spec --id <parent ID>` exits 3, when the specifier runs, then it writes a new spec under the next free ID and leaves the existing spec unchanged.
- **AC18.** Given a re-run as AC16 defines it, and no `ai-factory/risks/<that spec's ID>-*.md` exists, when the specifier runs, then the spec is left byte-for-byte unchanged and no new spec is created; if its Open questions contain "Run `/fc:risk <spec path>`", the report says that `/fc:risk <spec path>` still has to be run, and if they hold no such line, as when every triage item is `absent`, the report says there is nothing to revise.
- **AC19.** Given a request that names an existing spec's path whose Open questions contain "Run `/fc:risk <spec path>`", and `ai-factory/risks/<that spec's ID>-*.md` exists, when the specifier runs, then it edits that spec in place, removes the "Run `/fc:risk`" line, and creates no new spec.
- **AC20.** Given the re-run in AC19 where the risk file's latest `## Reassessment` section (or the body above the first one, when there is none) holds `open` findings of severity `blocker` or `major`, when the spec is edited, then each such finding is added to Open questions and the spec cites the risk file's path, and no `mitigated`, `accepted` or `minor` finding is added.
- **AC21.** Given the re-run in AC19, when it finishes, then the triage and every part of the spec other than the "Run `/fc:risk`" line and the added findings in Open questions are byte-for-byte unchanged, including the heading and the `Created:` line.
- **AC22.** Given the re-run in AC19 in a repo where `ai-factory/contracts/config.json` exists, when the spec has been edited, then the specifier runs `node ai-factory/make/contracts.js init spec <spec path>` again so the sidecar's digest matches the edited spec.
- **AC23.** Given fixture specs and risk files covering AC17, AC18, AC19, AC20 and AC22, when the revise-in-place fixture check runs, then it asserts the specifier procedure's wording for each of those cases.
- **AC24.** Given `tasks/spec.md`, when it is read, then it describes the re-run rule of AC16 and its delegation instruction names the `Effort and risk` section among the spec's sections.

**Planner**
- **AC25.** Given the planner procedure and `tasks/plan.md`, when they describe a step, then every step's indented body carries one line in the form `Effort: <S|M|L|XL> · Estimate: dev <range> h, /fc:run ~<range> min (assumption: <what it rests on>)`.
- **AC26.** Given the planner procedure, when it describes a step's `Effort:`, then it states that the step is rated with the same rubric as the feature, applied to the step's own scope.
- **AC27.** Given the planner procedure and `tasks/plan.md`, when they describe the estimate line, then they state that it never goes in the `- [ ] Step N` title line and never contains `AC<n>` or `Verify`.
- **AC28.** Given a plan whose steps carry the AC25 line, when `parsePlanSteps` in `make/contracts.js`, `make/loop.js` and `skills/ai-layout/scripts/state.sh` read it, then step titles, `Depends on:`, `Verify (…)` commands and covered AC IDs are the same as for the plan without those lines.
- **AC29.** Given the planner procedure and `tasks/plan.md`, when they describe the estimates, then they state that both ranges are ranges, are labelled as assumptions, and are never summed into a feature total or turned into a date.
- **AC30.** Given `skills/ai-layout/scripts/check-loop.sh` and `skills/ai-layout/scripts/check-contracts.sh`, when they run after the change, then their assertions on the planner's wording (today `check-loop.sh:2136` and `check-contracts.sh:581`) pass against the new planner text, and a new assertion checks for the AC25 line format.
- **AC31.** Given `agents/analyst.md`, when the change is complete, then its rule "no invented effort, cost, ROI, dates or story points" is unchanged.

**Start**
- **AC32.** Given `tasks/start.md`, when it describes reading an effort rating, then it reads one only from a spec or exploration whose path the request names, and from no other artefact.
- **AC33.** Given a request that names both a spec path and an exploration path whose effort ratings differ, when `/fc:start` classifies it, then it uses the spec's rating.
- **AC34.** Given `tasks/start.md`, when it is read, then it applies the effort rating only after rule 3, so a present risk trigger still routes to planned work whatever the rating.
- **AC35.** Given a request naming a spec or exploration rated L or XL, when `/fc:start` classifies it, then the destination is never `quick` and never `chore`, and `fix` remains allowed.
- **AC36.** Given a request naming a spec or exploration rated S or M, when `/fc:start` classifies it, then the destination is the same as it would be with no rating read.
- **AC37.** Given a request whose rating of L or XL rules out `quick`, when `/fc:start` classifies it, then the destination is `spec` when a spec already exists for it, and `explore` otherwise.
- **AC38.** Given `/fc:start` read an effort rating, when it returns its JSON result, then the result carries an optional `effort` field with that rating (S, M, L or XL); given it read no rating, then the result has no `effort` field; and in both cases the existing fields and their rules are unchanged.
- **AC39.** Given the rating changed the destination from the one start would have chosen without it, when `/fc:start` returns, then `reason` mentions the rating; given the rating did not change the destination, then `reason` need not mention it.
- **AC40.** Given `skills/ai-layout/scripts/check-start-routing.sh`, when it runs after the change, then it includes evaluations for AC33, AC35, AC36, AC37 and AC38, and its existing evaluations pass or each changed expectation is listed in the MR.

**Readers of the new spec section**
- **AC41.** Given a spec carrying the `Effort and risk` section, when `/fc:continue`'s spec-drift check and `make/contracts.js` spec parsing (AC IDs, digest) run on it in a contracts-enabled fixture, then they report the same AC IDs and the same drift result as for that spec without the section, or they are changed so that they do; the MR states which of the two applied.

**Delivery**
- **AC42.** Given the change and the owner's decision of 2026-10-29 to waive the before/after host runs for this delivery, when its MR is opened, then CHANGELOG records it as a breaking template change, and instead of before/after run links the MR records that waiver and lists the acceptance criteria that rest on static checks only: AC6–AC8, AC13, AC14, AC17–AC22, AC25, AC33, AC35–AC37 and AC39.
- **AC43.** Given the change, when every check in `skills/ai-layout/scripts/check-*.sh` and `skills/ai-hooks/fixtures/check-*.sh` runs, then each exits 0, and the generated command and Codex skill copies of the changed tasks match their templates.

## Out of scope
- Option B: `/fc:spec` chaining the risk agent after the specifier.
- Option C: structured `effort`, `risk_triggers` or estimate fields in contract sidecars, the delivery report or assurance presets.
- Any change to `agents/risk.md`, its categories, severities, statuses or file format, and any change to what makes `/fc:risk` optional.
- A risk file for an exploration (`make/ids.js` reuse rules are unchanged).
- Any change to `agents/analyst.md` or to analyses.
- Effort ratings per acceptance criterion.
- Time figures in explorations; dates anywhere; summing plan steps into a total.
- Requiring the plan's Risks section to name the steps with the widest ranges.
- Re-evaluating the triage on a specifier re-run.
- Reading an effort rating in `/fc:start` from anything but a spec or exploration path named in the request.
- Changes to `parsePlanSteps` or the plan step grammar.
- Enforcing "not buildable" by a gate or hook; it stays a convention as it is for any open question today.

## Open questions
None.

## Data touched
- Spec markdown: new `Effort and risk` section immediately before Open questions (effort rating; feature-level dev-hours and `/fc:run` time ranges labelled as assumptions; triage of the eight categories and six start triggers, present/absent with one evidence line). Open questions gains or loses "Run `/fc:risk <spec path>`" and gains open blocker/major findings on a re-run.
- Exploration markdown: per-option effort S/M/L/XL; new `Effort and risk` subsection for the recommended option, naming present triggers and recommending `/fc:risk` once the spec exists.
- Plan markdown: one `Effort: … · Estimate: …` line in each step's indented body.
- `/fc:start` JSON result: new optional `effort` field.
- Spec contract sidecar (`.contract.json`) digest, refreshed by `contracts.js init spec` after an in-place edit where contracts are enabled. No schema change.

## Routes touched
- `/fc:explore`, `/fc:spec`, `/fc:plan`, `/fc:start` (prompt behaviour; start's result gains an optional field). `/fc:risk` unchanged. `/fc:continue` to verify (AC41).

## Components likely involved
- `agents/explorer.md`, `agents/specifier.md`, `agents/planner.md`
- `skills/ai-layout/templates/ai-factory/tasks/spec.md`, `plan.md`, `start.md`
- Generated copies: `commands/*.md` and `codex-skills/` entries for spec, plan and start (and explore if regenerated)
- Checks: `skills/ai-layout/scripts/check-loop.sh` (around line 2136), `check-contracts.sh` (around 581), `check-risk.sh` (706–712, must stay unchanged), `check-start-routing.sh`, a new rubric-equality check, a new revise-in-place fixture
- Anything that consumes `/fc:start`'s JSON result and validates its fields (must accept the optional `effort` field)
- To verify and change if needed (AC41): `/fc:continue`'s spec-drift check (`skills/ai-layout/templates/ai-factory/tasks/continue.md`, `skills/ai-layout/scripts/check-continuation.sh`) and `make/contracts.js` spec parsing
- Readers that must stay unaffected: `make/contracts.js` `parsePlanSteps`, `make/loop.js`, `skills/ai-layout/scripts/state.sh`
- `CHANGELOG.md`
