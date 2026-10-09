# Reliable continuation

## Request

Add `/t4:continue <delivery>` to inspect a delivery's artifacts and verification evidence, explain the next valid action, and resume through the existing workflow. When its spec has changed, explain which downstream artifacts and evidence require reconsideration before proceeding.

## What exists today

- `skills/ai-layout/templates/ai-factory/make/contracts.js` already resolves delivery IDs (`d-YYYYMMDD-xxxxxx`), validates spec/plan/quick sidecars, maps plan steps to acceptance criteria, and checks verification evidence. `checkPlan` reports `S_SPEC_CHANGED` when the current spec digest differs from the plan's recorded input. `checkEvidence` checks spec/plan/code digests; completed-step code changes can be informational because final verification covers the current code. Checkbox ticks are normalized out of plan content hashes. Contracts are opt-in.
- `skills/ai-layout/templates/ai-factory/make/delivery-report.js` exports `collect` and `evaluate`: collection retries if the evidence fingerprint changes, and evaluation explains readiness with evidence references. The report task writes a snapshot but deliberately runs no checks. Readiness is not a next-action selector.
- `skills/ai-layout/templates/ai-factory/tasks/{plan,test,run,check,report}.md` define existing stopping points. `run` implements one named step; `test` separates `red` and `gaps`. `agents/planner.md` cannot edit a stale spec. A continuation cannot simply route every stale artifact to plan generation.
- `skills/ai-layout/templates/ai-factory/make/models.js` provides model dispatch and a validated, allowlisted handoff for `start`. Its start destinations exclude continuation phases; a continue result needs its own contract. Generated surfaces come from `skills/ai-layout/scripts/sync-{claude-commands,codex-skills}.js` and workspace adapter generation. No continue task exists today.
- Lifecycle telemetry is optional (`make/lifecycle.js`); it records runs, not authoritative completion. Existing evidence stores whole-artifact hashes, not historical spec text or per-criterion revisions. A changed hash proves drift, not exactly which requirement changed.

## Options

### A — Prompt-driven inspector and handoff

Add a continue task and generated entry points. Its agent reads the existing validators and Markdown, explains drift, and selects an existing task without new persisted state.

**Effort: S**, mostly prompts and host integration. **Risk:** ambiguous or contradictory evidence can produce different decisions across runs; selection safety depends on prompt adherence. Easy to revise or remove; harder to prove consistent behavior across hosts. No migration or dependency; no architectural change requiring an ADR is apparent. Requires before/after transcripts and dispatch checks.

### B — Deterministic selector with one task handoff

Add a read-only continuation helper under the canonical `skills/ai-layout/templates/ai-factory/make/` and a thin continue task. Reuse contract validation and report collection to return a bounded result: next action, clarification, blocked, or complete, with artifact/evidence references and an input fingerprint. The host validates the result, rechecks its inputs before dispatch, and invokes one existing task with structured arguments, honoring that task's model and stopping point.

**Effort: M**, because evidence precedence, stale-input repair and phase selection need explicit rules and fixtures. **Risk:** current evidence does not prove every workflow phase occurred; unsupported states must be explained instead of inferred. Conservatively identify plan, tests, implementation verification and review affected by spec drift, without claiming criterion-level precision or rewriting hashes to clear it. Keep historical evidence and existing work intact. Easier to test and extend; future selective invalidation needs richer lineage. No new dependency or mandatory data migration; proposing a contracts-enabled first version requires agreement. An ADR is appropriate if the new handoff and invalidation policy becomes a durable contract.

### C — Persisted workflow state and revision graph

Introduce versioned continuation state and spec revisions, then update task/agent writers, contract schemas, lifecycle integration and the runner to track phase completion and dependency edges explicitly. Continue follows that graph and may execute multiple phases under a bounded resume policy.

**Effort: L**, because every writer and interruption path must preserve consistent state. **Risk:** partial writes, concurrent sessions, migration, and competing sources of truth. Enables precise downstream impact and longer resumptions; makes adoption and recovery harder. Requires schema migration and an ADR for state ownership/revision semantics; can still use Node's standard library.

## Comparison

| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A: prompt inspector | S | Variable decisions | High | Yes: existing prompts/helpers | Prototype only |
| B: deterministic selector | M | Missing-state handling | High; no new authoritative state | Yes: local helpers and task dispatch | Recommended |
| C: revision graph | L | State consistency/migration | Lower | Requires documented extension | Defer |

## Recommendation

**Recommend B** (design judgment): reliability should come from explicit evidence rules, while execution stays with existing tasks. Propose one next action per invocation, contracts-enabled planned deliveries first, and clear stops for ambiguous or stale inputs. Never equate a checkbox, successful lifecycle run, or refreshed sidecar with verified completion. Reuse collection and diagnostics without changing the read-only report task. Choose C instead if exact changed-criterion impact or unattended multi-phase execution is required.

Verification should cover missing/duplicate delivery IDs, legacy artifacts, stale specs/plans, expected red versus unexpected failures, interrupted steps, missing/stale final or review evidence, already complete deliveries, changed inputs before dispatch, routing rejection, and preserving user work. Add host transcripts for both successful continuation and a spec-change stop.

## Open questions

1. Does `<delivery>` mean only the existing contract ID, or also a spec/plan path? Must quick and contracts-disabled deliveries work in version one?
2. Is one existing workflow action per invocation sufficient, or must continue run until blocked or complete?
3. Is conservative downstream impact enough, or must it identify exact changed criteria and unaffected steps? Existing hashes cannot establish that precision.
4. Who reconciles changed specs and completed plan steps, and what evidence records that reconciliation? Existing plan generation is not an explicit revision workflow.
5. Must gaps testing be independently recorded before review, and is headless continuation required? Current phase evidence and optional telemetry cannot establish every such transition reliably.

These are scope/policy decisions for the spec; the recommendation is not an accepted requirement.

## Next

`/t4:spec Use ai-factory/explorations/0003-reliable-continuation.md, option B, to specify /t4:continue <delivery>; resolve its open questions before finalizing acceptance criteria.`
