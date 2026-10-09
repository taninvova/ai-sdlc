# Continuation host fixtures

Use disposable adopted repositories with artifact contracts enabled, on both hosts (Claude Code
`/t4:continue <delivery>`, Codex `$t4-continue <delivery>`). Build each delivery from
`skills/ai-layout/fixtures/contracts/planned` the way `check-continuation.sh` does: copy it, add
`ai-factory/contracts/config.json`, `git init`, then `contracts.js init spec` and `init plan` for
`ai-factory/specs/0001-csv-export.md` and `ai-factory/plans/0001-csv-export.md`. Record evidence only
through `make -f ai-factory/make/ai.mk verify` (or `contracts.js` record), never by hand.

Record for every run: host and version, model, fixture state (which steps are ticked, which
evidence files exist, whether the spec was edited after planning), the exact input, the helper's
outcome, reason and evidence references, the fingerprint, any question and answer, the one
destination directive and `Destination input:` line, observed writes, and where the invocation
stopped. Static checks and `check-continuation.sh` prove the selector and handoff mechanics only;
they are not host runs and must never be reported as one.

Before: the same fixture state without `/t4:continue` — record the manual sequence a developer
uses today (read the plan, open the evidence directory, run `make … contracts DELIVERY=<id>`,
decide the phase, invoke the direct task). After: invoke continue with the same state.

## Required transcript scenarios

| ID | Fixture state | Expected after-run behavior |
| --- | --- | --- |
| single-action-resume | Planned delivery; S1 red and step evidence recorded and S1 ticked; S2 not started (no red phase declared) | outcome `action`, task `run`, `Destination input: <plan> S2`; exactly one dispatch under run's own model policy; the run task keeps its own verification and stops after S2; continue selects nothing further |
| spec-drift-stop | Same delivery after planning; append a line to the spec so its digest differs from the plan sidecar's recorded spec input | outcome `blocked` with `S_SPEC_CHANGED`; names plan, acceptance tests, implementation and its verification, and review as potentially affected; says hashes show drift but not which criteria changed; tells the developer to reconcile before continuing; no dispatch, no hash rewrite, no plan regeneration, no evidence deleted |

## Supporting scenarios

| ID | Setup and input | Expected |
| --- | --- | --- |
| empty | `/t4:continue` with nothing after it | asks for the delivery ID; no helper call, dispatch or writes |
| path | `/t4:continue ai-factory/specs/0001-csv-export.md` | unsupported input; stop |
| unknown | a well-formed ID that matches no sidecar, or a quick delivery's ID | `blocked`: no contract-backed planned delivery; stop |
| disabled | no `ai-factory/contracts/config.json` | `blocked`: contracts not enabled; stop |
| gaps-question | every step done, final evidence recorded, no review | `question` with `clarify: gaps_tested`; the answer is passed as `--answer gaps_tested=yes|no`; `no` selects `test … gaps`, `yes` selects `check working-tree …` |
| red-question | a step declaring red is started (`[~]` or step evidence) without red evidence | `question` with `clarify: red:S<N>`; only `red:S<N>=proceed` resumes `run <plan> S<N>`; no red evidence is created |
| changed | edit an artifact between inspection and handoff | handoff stops `changed`; nothing dispatched; invoke continue again |
| routed | `routing.tasks.continue` mapped, `routing.tasks.run` mapped | continue selects in the session; the run destination uses run's mapping; doctor flags the continue mapping as ignored |
| headless | `make -f ai-factory/make/ai.mk ai TASK=continue INPUT=<id>` | rejected before any CLI launch or run artifact; names plan, test, run, check or report |
| complete | report evaluation ready and a matching `ai-factory/reports/<id>/completion.json` | `complete` (ready for handoff, not merged or deployed); no dispatch |

Pass rubric: the outcome and task match the table; the reason cites real evidence references;
answers stay separate from the original input; at most one destination dispatch; the destination
keeps its own model policy and stopping point. Fail on a guessed answer, a dispatched `blocked` or
`question`, chained phases, any write by continue itself, a cleared drift diagnostic or a model
fallback. Retain failed and corrected runs.
