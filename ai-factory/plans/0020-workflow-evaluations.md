# Workflow outcome evaluations

Goal: extend the existing opt-in benchmark with traceable quality, question, time, and cost outcomes for matched workflow comparisons.
Spec: [0020-workflow-evaluations.md](../specs/0020-workflow-evaluations.md). Steps 1–4 are implemented. The *Optional real smoke* was run before/after the `Completion status` prompt change on 2026-10-06 (codex-cli 0.160.0): before `ai-factory/runs/small-task-benchmark-2026-10-06T19-47-03-682Z-before-head/` (HEAD 8c68cb2 script), after `ai-factory/runs/small-task-benchmark-2026-10-06T19-45-13-186Z/`.

## Approach and files
- Modify `skills/ai-layout/scripts/benchmark-small-tasks.js` — retain its isolated fixtures, baseline/candidate snapshots, bounded execution and existing CLI; add rubric outcomes, evidence references and quality-first comparisons.
- Create `skills/ai-layout/fixtures/workflow-evaluations/rubric.json` — evaluator-owned requirement IDs and expected behaviors for the initial scenarios; never copy it into model-writable fixtures.
- Create `skills/ai-layout/fixtures/workflow-evaluations/results.json` — synthetic completed, blocked, interrupted, failed, mismatched, partial-cost and unjudged records for offline checks.
- Create `skills/ai-layout/scripts/check-workflow-evaluations.sh` — offline `quality`, `pairing`, and `report` groups, discovered by existing `make check`; no model calls.
- Modify `README.md` and `CHANGELOG.md` — concise evaluation instructions, a question-judgment example, scope and metric limitations. No new CLI framework, dashboard, dependency or agent.

Server versus client: neither. Evaluation belongs to local Node code and fixtures, outside the evaluated model's writable project. Reuse existing lifecycle JSON read-only when explicitly linked; do not modify lifecycle or `make cost` contracts.

## Steps
- [x] Step 1 — Record independently checked delivery quality (AC1, AC2, AC3).
  Add the rubric, synthetic results and new offline `quality` test group. Start with existing `docs` (spelling only), `bug` (empty sum and preserved nonempty sums), `enhancement` (whitespace label and trimming), and `escalation` (unsettled authorization preserves production code and reports the unresolved decision). Keep other benchmark scenarios working with explicit unassessed metrics where no rubric exists.
  Add per-requirement satisfied/unmet/unassessed outcomes with evidence. Execute evaluator assertions from the harness against final code after the model exits; neither generated tests nor model claims are the quality oracle. Keep rubric/check definitions outside writable fixtures and verify their digest across runs. Separate process exit from reported task completion and evaluator success: a successful CLI exit alone proves neither. Manually adjudicate ambiguous completion claims, leaving them unknown meanwhile. Count post-completion failed defect checks as fixture-detected escapes; blocked/failed runs retain findings without fabricated escape totals.
  Verify (red): `bash skills/ai-layout/scripts/check-workflow-evaluations.sh quality` — new named cases `requirement-evidence`, `escaped-defect-after-completion`, `exit-zero-blocked`, and `oracle-preserved` fail against the prior record/validation behavior, not because a file is missing.
  Verify (step): `bash skills/ai-layout/scripts/check-workflow-evaluations.sh quality`

- [x] Step 2 — Make pairs comparable and preserve measurement gaps (AC1, AC3, AC5).
  Add the `pairing` group before implementation. Record identical initial fixture hashes, request identity, rubric version, configured model/reasoning/provider, CLI version, adaptation mode and resource limits across each baseline/candidate pair; workflow snapshots/routes are the intended differences. Pin available execution settings consistently and mark unresolved effective settings as unknown. Preserve alternating order and record repetitions/concurrency; a mismatch suppresses comparative improvement claims. Store measured CLI elapsed duration separately from successful-completion duration; timed-out/blocked execution still has elapsed cost but no completed-delivery speedup.
  Keep token fields as supplied, with unavailable fields null. If explicitly associated lifecycle JSON is supplied to offline reporting, validate run/session provenance and use its existing monetary known-subtotal/unknown-remainder semantics; never add benchmark and lifecycle usage for the same run. Without trustworthy linked monetary evidence, cost remains unknown with observed tokens shown. `make cost` remains tokens/turns only. Distinguish recorded estimates from billed cost; no guessed rates or new rate service.
  Verify (red): `bash skills/ai-layout/scripts/check-workflow-evaluations.sh pairing` — new `mismatched-pair`, `unknown-effective-model`, `timeout-not-speedup`, `partial-cost-unknown-total`, and `duplicate-usage-source` expose unsupported comparisons or missing uncertainty handling.
  Verify (step): `bash skills/ai-layout/scripts/check-workflow-evaluations.sh pairing`
  Verify (step): `bash skills/ai-layout/scripts/check-lifecycle.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-cost.sh`

- [x] Step 3 — Produce a reviewable report and human question judgments (AC1, AC2, AC3, AC4, AC5).
  Add the `report` group and a simple offline `--summarize=<run-directory>` mode in the same benchmark script; this mode must never launch a model. Allow an optional `judgments.json` beside existing run records containing run ID, transcript reference, question text, necessary/unnecessary/uncertain label, reviewer and rationale; reject unknown run IDs and invalid entries. Human review enumerates questions and marks transcript review complete; partial or absent review keeps the total unknown. Asking about the unsettled policy in `escalation` is necessary; re-asking the already explicit spelling correction in `docs` is unnecessary. These are rubric examples, not automatic text-pattern judgments.
  Render all five metrics, raw outcome counts, evidence links, sample size and missingness. Preserve failed runs in the report. Restrict time/cost improvement comparisons to matched pairs with satisfied quality criteria and known corresponding measurements; do not create overall scores, success thresholds, confidence claims, or production-defect rates. Label prompt replays, inline-agent adaptation, cache/scheduling effects and unmeasured human waiting. Keep new report writes within the existing safe-files boundary and consume source evidence read-only.
  Verify (red): `bash skills/ai-layout/scripts/check-workflow-evaluations.sh report` — new `unjudged-not-zero`, `partial-question-review`, `judgment-evidence`, `offline-never-launches`, and `quality-before-speed` fail on current reporting behavior.
  Verify (step): `bash skills/ai-layout/scripts/check-workflow-evaluations.sh report`

- [x] Step 4 — Document and verify the bounded evaluation path (AC1–AC5).
  Document explicit opt-in, baseline selection, one compact smoke run, offline re-summarization and judgment editing. Use fake CLI executables and synthetic records in offline checks to prove no paid execution without `--real`, timeout/concurrency bounds, isolation and report regeneration. Preserve the existing default benchmark scenario/call behavior; do not add paid runs to `make check`. Collect before/after report evidence from identical synthetic inputs. If implementation changes prompts/templates, repository-required real before/after prompt evidence additionally applies; do not fabricate that evidence from offline tests.
  Verify (final): `node --check skills/ai-layout/scripts/benchmark-small-tasks.js`
  Verify (final): `bash skills/ai-layout/scripts/check-workflow-evaluations.sh`
  Verify (final): `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`
  Verify (final): `bash -c 'set -e; for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done'`
  Verify (final): `make check`

## Optional real smoke, after implementation and explicit opt-in
`BENCHMARK_BASELINE=HEAD BENCHMARK_TIMEOUT_MS=150000 BENCHMARK_JOBS=1 node skills/ai-layout/scripts/benchmark-small-tasks.js --real --inline-agents --scenarios=bug`
This existing invocation selects one scenario and one baseline/candidate pair (two model executions), bounded individually to 150 seconds. With HEAD as baseline it is harness smoke only, not evidence of an improved workflow. For a real comparison, choose the intended prior revision and record its resolved commit. No real run is performed by this plan; unavailable host evidence stays unverified. No cross-host matrix is required for this local benchmark extension.

## Risks and ambiguities
- Evaluator tampering or generated-test false confidence: external rubric, fixed assertions and digest checks; isolation is the host sandbox boundary, not a claim of adversarial secrecy.
- Incomparable data and double-counted usage: explicit pairing checks, source provenance and offline partial/missing/duplicate fixtures. Unknown values remain unknown through aggregation.
- Subjective question/ completion assessment: traceable human judgments and incomplete-review labels; evaluator errors become unassessed outcomes, not task defects.
- No blocking product ambiguity. Initial fixtures, linked lifecycle input and offline summarization are proposed implementation choices; they add no new workflow engine or release threshold. All new checks above must first be created; red results must demonstrate the named missing behavior.
