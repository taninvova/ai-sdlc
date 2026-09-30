# Small-task benchmark protocol

Plan 0011 requires model evidence in addition to deterministic script fixtures. The harness
is `skills/ai-layout/scripts/benchmark-small-tasks.js`; it is opt-in and is never invoked
by adoption or the ordinary check suite. It uses the existing configured Codex CLI, Node,
Git and Make, with no dependency installation.

Run from the plugin repository with `node skills/ai-layout/scripts/benchmark-small-tasks.js --real`.
This performs 14 external model calls and consumes model usage. The user approved that
fixed set on 2026-09-29 after automatic approval review initially refused external egress
and usage without explicit authorization. That refusal was not bypassed.

## Matched inputs

- Baseline: committed HEAD, resolved to an exact commit and saved in the metadata.
- Candidate: current task and agent templates, copied and hashed before the runs begin.
- Each invocation gets a separate synthetic Git repository under `ai-factory/runs/tmp/`.
- Both variants use the same CLI configuration, model, verification commands and starting
  application content. Optional integrations and package installation are forbidden.
- The task prompts are replayed explicitly. This measures the supplied workflow instructions;
  it does not prove native slash-command registration or independent agent behavior.
- Pairs alternate order. Two jobs run concurrently by default; startup load, scheduling and
  inherited host context can affect elapsed times. Cache state is not controlled.

| Scenario | Repetitions per variant | Required outcome |
|---|---:|---|
| Documentation typo | 3 | Exact corrected text; application code unchanged |
| One-function bug | 1 | Empty input fixed, ordinary input preserved, new regression test fails without fix |
| Small enhancement | 1 | Requested fallback added with meaningful coverage; prior behavior preserved |
| Two-step feature | 1 | Only Step 1 implemented and ticked; Step 2 stays failing, unchanged and unticked |
| Mixed pre-commit review | 1 | Staged, unstaged and untracked defects reported; files and index preserved |

## Evidence and interpretation

The harness retains prompt snapshots, raw events, final responses, diffs, status, model/CLI
settings, elapsed times, token fields, call counts and quality assertions beneath
`ai-factory/runs/small-task-benchmark-<timestamp>/`. Generated records are local evidence,
not telemetry sent by the plugin. Fixtures remain in ignored workspace scratch for inspection.

Verification-call counts are a documented command-text heuristic. Phase timing and human
waiting are unavailable. There is one top-level CLI invocation per replay. The completed
inline enhancement pair records six baseline task procedures versus one candidate quick
procedure; this does not measure native UI interactions or reduce CLI process count.

Report median and range only for the three documentation repetitions. Other pairs provide
behavioral observations, not reliable latency estimates. Compare speed only when both
variants satisfy the same quality assertions. A timeout, failure or omitted workflow is
not a speedup. No general model-quality or plugin-performance guarantee follows from these
small synthetic fixtures.

The initial set is saved under `ai-factory/runs/small-task-benchmark-2026-09-29T17-25-02-260Z/`.
Several delegated workflows returned `no thread id`; both phased runs were incomplete.
Those are runtime failures, not timing evidence. The user separately approved six replacement
calls on enhancement, phased work and review with the documented Codex inline-agent mode:
`node skills/ai-layout/scripts/benchmark-small-tasks.js --real --inline-agents --scenarios=enhancement,two-step,review`.
That mode follows the named agent procedure in the current session and labels review as a
self-check. Original failures remain recorded. Replacement results are saved under
`ai-factory/runs/small-task-benchmark-2026-09-29T17-34-13-577Z/`.

The final interpretation is recorded in `ai-factory/runs/0011-verification.md`.

Five additional behavior controls were explicitly approved and completed as scenario selections:
`--scenarios=escalation,dirty,retry,unexpected,red --inline-agents`. They require ten
baseline/candidate calls and are excluded from the default 14-call set. They test unresolved
authorization/public-contract decisions, preservation of staged/unstaged/untracked user work
during implementation, bounded retries of an unchanged infrastructure failure, refusal to
tick a step with a failure outside the recorded baseline, and completion of an expected-red
test-authoring step. The red-test control also checks that the new test passes with the
missing behavior supplied, so an arbitrary failing test cannot satisfy the assertion.

Results are saved under `ai-factory/runs/small-task-benchmark-2026-09-30T00-26-38-593Z/`.
All five candidate controls pass. Baseline escalation, retry and unexpected-regression
controls pass; the dirty-worktree baseline times out incomplete and the red baseline
fails to mark its valid expected-red step complete. The timeout is excluded from speed
comparisons. Across the three sets, 30 real calls were executed; failed runs remain in
the evidence. No further calls are needed to complete plan 0011.
Claude preflight was unauthenticated. Codex preflight succeeded after its local service was
allowed outside the workspace sandbox; model work itself requests a workspace-write sandbox.
