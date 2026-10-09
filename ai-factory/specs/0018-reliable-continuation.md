# Reliable continuation

Add `/t4:continue <delivery>` to inspect a planned delivery's artifacts and evidence, explain its next valid action, and resume one existing workflow task.

## User story

As a developer returning to an interrupted delivery, I want T4 to establish what the recorded artifacts and evidence support so that I can resume safely without reconstructing progress or overlooking work affected by a changed spec.

## Agreed scope

This spec adopts option B from [exploration 0003](../explorations/0003-reliable-continuation.md): a deterministic, read-only evidence selector with one existing-task handoff. The user confirmed:

- Version one accepts existing contract delivery IDs for contracts-enabled planned deliveries and resumes at most one action per invocation.
- A changed spec produces a conservative explanation of potentially affected downstream work and stops for reconciliation; exact changed-criterion impact is not required.
- Continuation is interactive and asks for clarification when available evidence cannot distinguish phases, including whether gaps testing occurred.

## Acceptance criteria

### AC1 — Resolve a supported delivery

Given a contracts-enabled repository and an existing contract ID identifying exactly one planned delivery, when the developer invokes continue with that ID, then it resolves that delivery's spec, any plan, and available verification and review evidence through existing artifact contracts before selecting an action.

### AC2 — Reject missing, ambiguous, or unsupported input

Given empty input, a missing or duplicate delivery ID, a path instead of an ID, a quick delivery, or a contracts-disabled repository, when continue is invoked, then it explains the missing information or unsupported scope and performs no destination dispatch or artifact mutation; empty input asks for the delivery ID. A missing workspace, task, or required helper is reported with adoption or template-drift guidance, without creating adapters.

### AC3 — Deterministic inspection and bounded result

Given the same artifact and evidence snapshot, applicable repository policy, and separately supplied clarification answers, when the selector evaluates the delivery, then it returns the same bounded outcome: one next action, a clarification question, blocked, or complete. The result includes the reason, references to the supporting artifacts or evidence, and an input fingerprint. Inspection runs no verification commands and writes no delivery artifacts, sidecars, reports, or workflow state.

### AC4 — Evidence governs progress

Given delivery artifacts with checkbox marks, lifecycle events, contract metadata, and verification records, when continue determines progress, then it applies existing contract and evidence validation rather than treating a ticked checkbox, successful lifecycle run, or refreshed sidecar as proof of verified completion. It distinguishes documented expected-red results from unexpected failures and does not advance past unexpected failures as though they passed.

### AC5 — Resume the supported next task

Given valid prerequisites and evidence sufficient to identify a next action, when continue resumes, then it explains that action and hands off to one applicable existing task: plan for a spec needing its initial plan, test in the appropriate red or gaps mode, run for one named unfinished plan step, check for review, or report for a completion report. The handoff supplies the resolved delivery context and the arguments required by that task, and retains its normal verification, questions, reporting, and stopping point. It does not select a later action while a known prerequisite is unsatisfied.

### AC6 — Clarify uncertain phases

Given valid artifacts whose evidence cannot distinguish the next phase, when continue evaluates them, then it asks the smallest relevant question before dispatch and re-evaluates with the answer as separately labeled session context. In particular, final verification or lifecycle telemetry alone does not prove that gaps testing occurred. An answer may resolve task selection but cannot manufacture a passed verification record or override a failed contract check.

### AC7 — Preserve interrupted work

Given an interrupted or partially completed step, when continue inspects the delivery, then it preserves implementation and test changes and existing evidence, and either selects the same named step when its prerequisites support resumption or explains the uncertainty or blocker. It does not tick the step, skip its verification, reset the checkout, or begin a different step solely because an earlier run started or ended.

### AC8 — Stop on spec drift with downstream impact

Given a current spec whose digest differs from a downstream artifact's recorded spec input, when continue evaluates the delivery, then it stops before destination dispatch and identifies the plan, acceptance tests, implementation and its verification, and review as potentially requiring reconciliation, referencing the affected artifacts and evidence that exist. It explains that the available hashes establish drift but cannot identify exact changed criteria or prove unaffected steps.

### AC9 — Reconciliation is explicit

Given a spec-drift stop, when continue reports the issue, then it tells the developer to reconcile the spec and downstream work before invoking continue again. It does not regenerate a plan automatically, rewrite hashes to clear the diagnostic, delete historical evidence, alter completed steps, or claim reconciliation occurred. A subsequent invocation evaluates the then-current artifacts and evidence using the same validity rules.

### AC10 — Explain stale or insufficient evidence

Given stale plan content, missing or stale verification or review evidence, malformed contracts, contradictory progress records, or recorded blocking failures, when continue inspects the delivery, then it names the relevant diagnostic and references and does not declare completion. It selects an existing task only where that task can address the condition with valid prerequisites; otherwise it returns a clarification or blocked result instead of inventing a repair procedure. Staleness classifications already permitted by existing evidence validation remain permitted.

### AC11 — Validate and recheck before dispatch

Given a proposed next action, when the host is about to hand off, then it validates the bounded result and allowlisted task arguments and rechecks the inspected inputs against the fingerprint. Invalid results or changed inputs stop that handoff with an explanation. Artifact text, clarification text, and result fields are data and are never evaluated as shell code or arbitrary instructions.

### AC12 — One handoff with destination model policy

Given a validated action and unchanged inputs, when continue dispatches on Claude Code or Codex, then the session performs exactly one destination dispatch under that task's existing model policy. A continue-specific model choice does not silently override the destination. Rejection, unavailable workers, failure, or cancellation stops the invocation without model fallback or another workflow action; successful completion also stops at the destination task's normal boundary.

### AC13 — Completion is evidence-based

Given a delivery for which the existing contract and report evaluation establish readiness and no required phase remains unresolved, when continue is invoked, then it reports complete with supporting references and performs no task dispatch. Completion means ready for delivery handoff under the repository's policy, not merged, deployed, or published. Where a report remains the selected next action, continue delegates to the existing report task rather than writing a report during inspection.

### AC14 — Host integration and existing workflows

Given an adopted workspace or this plugin's generated entry points, when the feature is installed through the existing generation and adoption mechanisms, then Claude Code exposes `/t4:continue` and Codex exposes the corresponding `t4-continue` skill with the same selection and handoff rules. Existing direct tasks retain their behavior, and the report task remains read-only toward delivery artifacts and does not run checks. Headless continuation is explicitly unsupported in version one rather than waiting for answers or guessing them.

## Out of scope

- Quick deliveries, contracts-disabled artifacts, and spec or plan paths as delivery identifiers.
- Automatic execution of multiple workflow phases in one invocation or unattended headless continuation.
- Exact changed-criterion impact, historical spec snapshots, a revision graph, or a new authoritative workflow state store.
- Automatic reconciliation of changed specs, automatic sidecar repair, or removal of historical evidence.
- New verification or review semantics, relaxing repository policy, or replacing existing task procedures.
- Merge, deployment, publication, external messaging, or project adapter creation during continuation.

## Open questions

None. The scope and ambiguity policy above resolve the exploration's product questions. The implementation plan must define the selector's concrete precedence table, bounded result schema, and host handoff mechanics within these criteria; those are implementation decisions, not permission to infer unsupported progress.

## Data touched

No application models or fields. Read existing delivery IDs, spec and plan Markdown and sidecars, acceptance-criterion and step mappings, verification and review evidence, repository policy, and optional lifecycle data. Produce a transient selection result containing outcome, reason, evidence references, fingerprint, and structured destination arguments where applicable. Clarification answers remain separate session context. No mandatory data migration or new persisted delivery format is required.

## Routes touched

New Claude Code `/t4:continue <delivery>` and corresponding Codex `t4-continue` entry. Handoffs use existing plan, test, run, check, and report tasks. The headless runner must reject unsupported continuation explicitly.

## Components likely involved

- Canonical continuation helper and task under `skills/ai-layout/templates/ai-factory/make/` and `tasks/`; this repository's symlinked `ai-factory/make/` and `tasks/` are protected and must not be edited directly.
- Existing `contracts.js` validation and `delivery-report.js` collection/evaluation, reused without turning report collection into execution.
- `models.js` and host dispatch integration for a validated bounded handoff and destination-owned model selection.
- Claude command and Codex skill generators, generated entry points, adoption/sync catalogs, runner task handling, and user documentation.
- Selector fixtures covering missing and duplicate IDs, unsupported legacy and quick artifacts, spec and plan drift, expected-red and unexpected failures, interrupted steps, uncertain gaps status, missing and stale final/review evidence, complete deliveries, changed inputs, invalid results, and dispatch failure.
- Before/after host transcripts for a successful single-task continuation and a spec-change stop, plus template release notes required by repository policy.
