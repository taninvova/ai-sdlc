# Workflow evaluation: 2026-10-06T19:45:13.187Z

Offline report of recorded benchmark evidence, regenerated with `node skills/ai-layout/scripts/benchmark-small-tasks.js --summarize=<this directory>`; summarizing never launches a model.

Baseline 8c68cb20282ae897a9f2a3dccbcaa1d50ca5af1a; candidate snapshot hashes in records.json. Settings (null is unpinned, unknown): {"model":"gpt-6-luna","model_reasoning_effort":"medium","model_provider":null}; prompt protocol 2; CLI codex-cli 0.160.0; rubric version 1, digest 04dbe6439a0f0955221c7331bc9d9efe1946845c4ea09b38fb3a807084077a00; runtime inline-agents.

## Sample

- Runs: 2 (baseline 1, candidate 1); scenarios: bug.
- Pairs: 1 (matched 0, mismatched 0, unverified 1, incomplete 0); eligible for time/cost comparison (matched, both completed, quality criteria satisfied): 0.
- Concurrency (jobs): 1; timeout per run: 150000 ms.

## Per-run outcomes

| Run | Scenario | Variant | Completion | Missed requirements | Escaped defects | Unnecessary questions | Completion time (s) | Elapsed (s) | Cost | Tokens in/out | Evidence |
|---|---|---|---|---:|---:|---:|---:|---:|---|---|---|
| bug-1-baseline | bug | baseline | completed | 0 | 0 | unknown | 34.21 | 34.21 | unknown | 195341/1128 | [record.json](bug-1-baseline/record.json) · [final.txt](bug-1-baseline/final.txt) · [events.jsonl](bug-1-baseline/events.jsonl) · [stderr.txt](bug-1-baseline/stderr.txt) · [diff.patch](bug-1-baseline/diff.patch) · [status.txt](bug-1-baseline/status.txt) · [prompt.txt](bug-1-baseline/prompt.txt) |
| bug-1-candidate | bug | candidate | completed | 0 | 0 | unknown | 43.61 | 43.61 | unknown | 192826/1684 | [record.json](bug-1-candidate/record.json) · [final.txt](bug-1-candidate/final.txt) · [events.jsonl](bug-1-candidate/events.jsonl) · [stderr.txt](bug-1-candidate/stderr.txt) · [diff.patch](bug-1-candidate/diff.patch) · [status.txt](bug-1-candidate/status.txt) · [prompt.txt](bug-1-candidate/prompt.txt) |

Unmet requirements and escaped defects per run:


## Raw outcome counts

| Variant | Runs | Completed | Blocked | Failed | Interrupted | Unknown | Requirements satisfied/unmet/unassessed | Defect checks satisfied/unmet/unassessed | Missed requirements | Escaped defects | Unnecessary questions | Questions observed | Judged necessary/unnecessary/uncertain | Legacy assertions |
|---|---:|---:|---:|---:|---:|---:|---|---|---|---|---|---|---|---|
| baseline | 1 | 1 | 0 | 0 | 0 | 0 | 3/0/0 | 2/0/0 | 0 | 0 | unknown (1 runs) | unknown (1 runs) | 0/0/0 | 1/1 passed |
| candidate | 1 | 1 | 0 | 0 | 0 | 0 | 3/0/0 | 2/0/0 | 0 | 0 | unknown (1 runs) | unknown (1 runs) | 0/0/0 | 1/1 passed |

Legacy assertions are the earlier per-scenario checks, kept as raw counts; they are not a quality criterion for comparisons.

## Pair comparisons

Time and cost are compared only for matched pairs whose runs both completed with every quality criterion satisfied and whose corresponding measurements are known. A negative delta means the candidate took less.

| Pair | Status | Order | Baseline quality | Candidate quality | Completion time delta (s) | Cost delta (USD) | Reason |
|---|---|---|---|---|---:|---:|---|
| bug-1 | unverified | baseline then candidate | satisfied | satisfied | none | none | no comparison: unknown conditions (settings.model_provider) |

Mismatched or unknown pair conditions:

- bug-1: settings.model_provider unknown.

## Question judgments

No judgments.json beside records.json: no transcript was reviewed, so every unnecessary-question count is unknown, not zero.

## Missingness

- Missed requirements: unknown for 0 of 2 runs.
- Escaped defects: unknown for 0 of 2 runs.
- Unnecessary questions: unknown for 2 of 2 runs.
  - bug-1-baseline: unknown: no question review recorded; an absent review is not zero
  - bug-1-candidate: unknown: no question review recorded; an absent review is not zero
- Completion time: unknown for 0 of 2 runs.
- Cost: unknown for 2 of 2 runs.
  - bug-1-baseline: unknown: no linked monetary evidence; tokens are observed, not priced
  - bug-1-candidate: unknown: no linked monetary evidence; tokens are observed, not priced

## Measurement boundaries and limitations

- Completion time: codex exec process: spawn to close, including CLI startup and model scheduling; excludes fixture setup, evaluation and human waiting. Completed-delivery time exists only for completed runs; elapsed time is shown for every run, including failed, blocked and interrupted ones.
- Cost: no linked lifecycle evidence: every cost is unknown; observed tokens are shown, not priced, and no figure is a billed amount.
- Escaped defects are fixture-detected: evaluator defect checks that failed after the run reported completion; not production defects.
- Unnecessary questions come only from human transcript review in judgments.json; question text is never classified automatically.
- These runs are workflow-prompt replays (one prompt replay per run) in isolated fixture repositories; native slash-command dispatch and independent delegation are not established.
- Runtime: inline-agent adaptation; role procedures ran inline in one session, so any inline review is a self-check, not independent review.
- Cache state, CLI startup, model scheduling and concurrently active runs affect elapsed time; no cache control was applied.
- Human waiting and internal phase timings are unmeasured.
- Small samples describe these fixtures only: no aggregate rating, pass mark or statistical claim is made, and no general workflow speedup is established.
