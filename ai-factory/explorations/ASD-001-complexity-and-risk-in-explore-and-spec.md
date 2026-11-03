# ASD-001 — Complexity estimate and risk assessment in explorations and specs
Created: 2026-10-29T19:12:43.221Z

## Request
Explorations (`explorer`) and specs (`specifier`) should state how much work a feature is and what its risks are.
Plans (`planner`) and `/fc:start` should use that rating. These are template changes, so they reach every adopted repo.
They must not duplicate `/fc:risk` (spec 0023), which already does full security and delivery risk assessment into `ai-factory/risks/`.

## What exists today
- **Explorer.** It rates each option's effort as `S/M/L with a reason` and gives a risk table (`agents/explorer.md:37-41`).
  There is no rubric, no fixed risk categories and no rating for the feature as a whole.
- **Specifier.** It has no effort or risk section.
  - It lifts open blocker and major findings from a risk file into Open questions (`agents/specifier.md:20-23`; asserted by `check-risk.sh:706-712`).
  - When `ids.js` exits 3 (a spec already has the parent's ID), it writes a *new* spec under the next free ID (`agents/specifier.md:40`). It never revises an existing spec in place.
- **Planner.** It has a free-form Risks list and no sizing.
  It turns risk-file mitigations into steps (`agents/planner.md:17-20`).
  A spec's open questions only become named ambiguities (`:56`); nothing blocks on them.
- **Plan step grammar.** `parsePlanSteps` (`make/contracts.js:271-302`) is shared with `loop.js` and `state.sh`.
  - It takes the title from the `- [ ] Step N` line and reads the indented body.
  - In the body, `Depends on:` (`loop.js:391`), `Verify (...)` and every `AC\d+` (counted as covered, `contracts.js:1046,1353`) are parsed.
  - The planner's wording is asserted by `check-loop.sh:2136` and `check-contracts.sh:581`.
- **Risk agent.** It assesses eight categories and records severity and status, in one file per spec ID.
  Only a spec's ID can be reused (`make/ids.js:66`), so an exploration has no risk file. It gates nothing.
- **Start.** It applies "risk before size" and names `/fc:risk` only when a trigger is present (`tasks/start.md:27-31`).
- **Analyst rule.** "No invented effort, cost, ROI, dates or story points" (`agents/analyst.md:50-51`).

## Decisions (owner, 2026-10-29)
- **D1.** Effort is rated S/M/L/XL against one written rubric, per feature in explorations and specs. It is not rated per acceptance criterion.
- **D2.** The specifier's triage sits next to its existing reading of risk files. `check-risk.sh:706-712` stays unchanged.
- **D3.** If the triage finds any trigger present, "Run `/fc:risk <spec path>`" goes under Open questions, and the spec is not buildable until that is done.
- **D4.** The planner and `/fc:start` read the effort rating. Every plan step gets an effort rating and a time estimate.
- **D5.** The rating is called **effort** everywhere, including the explorer's existing per-option column.
  Effort and complexity are the same concept here: the explorer's S/M/L already sizes the work, and the rubric's drivers cover complexity.
  Those drivers are areas touched, unknowns, new artefacts or schemas, and breaking template changes.
- **D6.** Each plan step's estimate carries two ranges: developer hours and the expected elapsed time of one `/fc:run`.
  - Both are labelled as assumptions and are never summed.
  - Format, in the step's indented body: `Effort: M · Estimate: dev 1–3 h, /fc:run ~10–20 min (assumption: …)`
- **D7.** When the specifier is re-run and finds a risk file for the spec's ID, it removes the "Run `/fc:risk`" open question.

**Tension with the analyst rule, stated openly.** D4 and D6 introduce the time figures that `analyst.md:50-51` forbids.
The proposed framing (opinion) is:
- Time figures appear only in plans, per step.
- They are always ranges and always labelled `(assumption: …)`, naming what they rest on.
- They are never totalled into a feature figure or a date.
- The plan's Risks section names the steps with the widest ranges.

The analyst rule itself is unchanged: analyses, explorations and specs carry the S/M/L/XL rating and no time.

## Options
**A. One rubric and a risk-trigger triage in the explorer, specifier and planner prompts; `/fc:start` reads the rating; full assessment stays with `/fc:risk`.**
- **Rubric.** The same S/M/L/XL rubric, word for word, in the three agents. A static check asserts the copies are equal.
- **Explorer.** Option effort uses the rubric. A new `Effort and risk` subsection covers the recommended option.
- **Specifier.** A new `Effort and risk` section holds the feature's effort and a triage.
  - The triage marks each of the eight risk categories and each start trigger as `present` or `absent`, with one line of evidence. It carries no severity, status or mitigation.
  - A present trigger adds the D3 open question; D7 removes it.
  - **D7 needs a new specifier path.** Today a re-run cannot revise a spec: an `ids.js` exit 3 makes a new spec under a new ID, and that spec would not match the risk file's ID.
  - So A adds a revise-in-place rule. When the exploration's or analysis's spec already exists, the specifier edits that spec's Open questions and nothing else. Where contracts are enabled, it re-runs `contracts.js init spec` afterwards, because the digest changes.
- **Planner.** It adds the D6 line to each step's indented body and never to the title. The line must not contain `AC<n>` or `Verify`. `tasks/plan.md` carries the same clause.
- **Start.** It reads an existing effort rating only after rule 3. L or XL never routes to `/fc:quick`, and risk still wins over size.
- **Changes.** The explorer, specifier and planner agents, `tasks/plan.md`, `tasks/spec.md` (the re-run wording) and `tasks/start.md`. Also their materialized copies, the planner checks in `check-loop.sh` and `check-contracts.sh`, a rubric-equality check, a revise-in-place fixture, the `check-start-routing.sh` evaluations, CHANGELOG, and before/after runs.
- **Effort: M.** That is four prompts and one new specifier behaviour, each with a before/after run.
- **Risk: medium.**
  - Time ranges may be read as commitments.
  - D3 blocks only by convention.
  - Revise-in-place is a new write path in the specifier, so it must touch only Open questions.
  - Routing evaluations may shift.
- **ADR.** None. It is a breaking template change in CHANGELOG terms.

**B. `/fc:spec` chains the risk agent after the specifier, and the prompts carry effort only (D4 and D6 still apply).**
- **Effort: M–L.** It means two delegates in one task, plus headless and lifecycle handling.
- **Risk.** It costs about twice as much per spec, reverses 0023's optional `/fc:risk`, and gives explorations no risk view.
  D3 and D7 become unnecessary.

**C. Structured `effort`, `risk_triggers` and step estimates in the spec and plan contract sidecars, acted on by the delivery report and the assurance presets.**
- **Effort: L.** It is a schema change, reaches contracts-enabled repos only, and reopens specs 0014, 0021 and 0023.
- **Risk.** A structured field reads as assurance, and it is the hardest option to reverse.

## Comparison
| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A: rubric, triage and step estimates in the prompts; start reads the rating | M | medium | high (prompt text and checks) | yes | **recommended** |
| B: spec chains the risk agent | M–L | medium (doubles spec cost; reverses 0023) | medium | changes a task's single-delegate shape | no, for now |
| C: contract fields | L | medium–high | low | contracts-only; needs a spec extending 0014 and 0021 | later, on top of A |

## Recommendation (opinion)
**Option A, with D1–D7.**
- It covers every decision with prompt text and static checks.
- It reuses one risk vocabulary: the risk agent's categories and start's triggers.
- It leaves severity and mitigation to `/fc:risk`.

What would change my mind:
- Choose B if every spec must carry a full assessment automatically.
- Specify C after A if estimates must be reported or enforced.

## Open questions
None blocking a spec. D7's revise-in-place rule is a design consequence for the spec to define, not an open owner question.

## Next
`/fc:spec Add an S/M/L/XL effort rubric and a risk-trigger triage to explorations and specs (a present trigger adds "Run /fc:risk" under Open questions; a specifier re-run that finds the spec's risk file removes it in place), per-step "Effort: M · Estimate: dev <range> h, /fc:run ~<range> min (assumption: …)" lines in plans, and effort-aware routing in /fc:start, via agents/explorer.md, agents/specifier.md, agents/planner.md, tasks/spec.md, tasks/plan.md and tasks/start.md (exploration ASD-001, option A with decisions D1–D7)`
