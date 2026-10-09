# Workflow outcome evaluations

Evaluate representative T4 tasks against a baseline using delivery quality, questions, completion time, and cost.

## User story
As a T4 maintainer, I want comparable evidence about workflow outcomes so that workflow changes are judged by their effect on delivery as well as regression checks.

## Requested scope
Plan option 5: run representative tasks through T4 and measure missed requirements, escaped defects, unnecessary questions, completion time, and cost. This document supports planning; no implementation or paid benchmark run is requested now.

## Acceptance criteria
### AC1 — Representative outcomes
Given a selected set of representative tasks, when an evaluation finishes, then its report identifies each task and workflow and reports missed requirements, escaped defects, unnecessary questions, completion time, and cost, with evidence or an explicit unknown for each metric.

### AC2 — Requirement coverage
Given a task with stated requirements and evaluation evidence, when requirements are assessed, then each requirement's outcome can be traced to that evidence and unmet requirements are distinguishable from requirements that were not assessed.

### AC3 — Defects after workflow completion
Given a workflow that reports completion, when subsequent evaluator checks identify defects, then the report identifies those defects and their evidence as escapes from that workflow; a failed or interrupted workflow is not reported as successfully completed.

### AC4 — Questions
Given recorded questions raised during a task, when the evaluation reports unnecessary questions, then it distinguishes the observed questions from the judgment that a question was unnecessary and records the judgment's rationale; absent assessment is not zero unnecessary questions.

### AC5 — Completion time and cost
Given measured execution and usage records, when time and cost are reported, then their measurement boundaries and cost source are identified; missing timing, usage, or pricing is reported as unknown instead of zero or an unsupported total.

## Proposed defaults for the implementation plan
These are bounded engineering recommendations, not additional user-approved requirements.
- Extend `skills/ai-layout/scripts/benchmark-small-tasks.js` and its existing isolated fixture scenarios, paired baseline/candidate runs, snapshots, JSON records, and Markdown summary. Avoid a new orchestration system.
- Keep real-model runs explicitly opt-in and bounded by selected scenarios, repetitions, timeout, and concurrency. Ordinary checks exercise deterministic evaluator fixtures without model calls.
- Match the task inputs, starting fixture, model, reasoning settings, runtime, and evaluation criteria across each pair; record baseline revision and candidate snapshot. Label unmatched or unknown conditions and avoid attributing their differences to T4.
- Use a small fixed rubric outside the model's writable fixture for requirement coverage and post-completion defect checks. Distinguish seeded or fixture-detected escapes from real production defects; no production defect rate is claimed.
- Store human question judgments alongside run evidence, with a short rubric and rationale. Do not infer necessity from question counts or a text-pattern match alone.
- Reuse measured elapsed time and usage from benchmark records; use lifecycle output when available with reliable attribution. `make cost` currently reports tokens and turns, not money: preserve that interface. Monetary figures require recorded pricing/provenance or remain unknown; distinguish estimates from billed amounts.
- Retain explicit failed, timed-out, blocked, and incomplete outcomes. Compare speed/cost as improvements only alongside comparable quality outcomes; report sample size and limitations without inventing pass thresholds or statistical claims.
- Preserve the current benchmark disclaimer: fixture prompt replay does not establish native slash-command dispatch or independent-agent behavior. Label the exercised runtime honestly.

## Out of scope
Production monitoring, public leaderboards, autonomous scoring agents, a dashboard, paid runs in every `make check`, new runtime dependencies, and numerical release gates or success thresholds.

## Open questions
None blocking this bounded draft plan. The initial scenario subset and rubric wording are proposed implementation choices to review with the resulting change; no success threshold has been requested.

## Data touched
Existing benchmark metadata, per-run records, transcripts, and summaries; proposed per-requirement outcomes, post-completion findings, question judgments, and cost provenance. Generated evaluation output stays within the existing `ai-factory/` boundary.

## Routes touched
Existing opt-in benchmark CLI; no new slash command or external service is proposed.

## Components likely involved
`skills/ai-layout/scripts/benchmark-small-tasks.js`, focused offline evaluator fixtures/checks, benchmark usage documentation, and optional read-only consumption of `skills/ai-layout/templates/ai-factory/make/lifecycle.js` output. Reuse cost/usage semantics without changing existing reporting contracts. Shipped prompt/template changes, if needed, retain repository before/after evidence and release-note requirements.
