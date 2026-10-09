# Plan 0018 — Reliable continuation

**Goal:** Add `/t4:continue <delivery>` to inspect contract-backed evidence, explain the next supported action, and resume at most one existing workflow task safely.

**Spec:** [0018-reliable-continuation.md](../specs/0018-reliable-continuation.md)

**Status:** All steps complete. The owner marked Step 5 complete on 2026-10-05 with the real Claude Code and Codex host transcripts and the independent review waived; the review performed was a self-check (see [delivery report](../reports/0018-reliable-continuation.md)). Implementation is limited to this plugin and its generated layout templates.

## Design decisions

- Implement a deterministic selector in a canonical `continue.js` helper. Its precedence table must be explicit and testable: reject unsupported input/workspace first; resolve exactly one planned contract delivery; validate its contract/evidence; stop on spec drift or blocking diagnostics; establish readiness only through existing report evaluation; otherwise choose the earliest valid prerequisite action. If evidence leaves a phase uncertain, return a clarification question before dispatch. Never treat lifecycle events, ticks, or sidecar refreshes as verification.
- Return a bounded JSON result with an allowlisted outcome (`action`, `question`, `blocked`, `complete`), reason, evidence references, input fingerprint, and structured arguments only for `plan`, `test`, `run`, `check`, or `report`. The host validates the schema and allowlist, then rechecks the fingerprint immediately before the one destination dispatch. Result, artifact and answer text remain data.
- Reuse `contracts.js` validation and `delivery-report.js` collection/evaluation through read-only APIs or narrowly added read-only exports. Continuation must not call report generation, verification commands, lifecycle mutations, or contract initialization. If existing APIs cannot safely provide a required signal, expose a focused read-only interface; do not copy or weaken their validity rules.
- Preserve the original invocation input separately from clarification answers. A spec-drift result stops and names all potentially affected downstream work; it does not infer criterion-level impact or reconcile artifacts.
- Claude Code and Codex entries share the same selector contract. Only the invoking session performs the single destination dispatch, using that task's existing model policy; no continuation-specific model override, fallback, or chained workflow. The headless runner rejects `continue` explicitly.
- The plugin has no `ai-factory/contracts/config.json`; exercise contracts-enabled planned deliveries in disposable fixtures. `ai-factory/skills/` is absent, so no overlay skills apply. Edit template targets under `skills/ai-layout/templates/`, never the protected `ai-factory/make/` or `ai-factory/tasks/` symlinks.

## Files

Create:

- `skills/ai-layout/templates/ai-factory/make/continue.js` — read-only delivery resolver, evidence selector, bounded-result validator, and fingerprint recheck.
- `skills/ai-layout/templates/ai-factory/tasks/continue.md` — interactive continuation procedure, clarification loop, and one-action stopping boundary.
- `skills/ai-layout/scripts/check-continuation.sh` — named regression groups for selector, validation, handoff and headless behavior.
- `skills/ai-layout/fixtures/continuation/cases.md` — disposable delivery fixtures and required Claude/Codex transcript scenarios.
- `commands/continue.md`, `codex-skills/t4-continue/SKILL.md` — generated host entry points for the shared procedure.

Modify:

- `skills/ai-layout/templates/ai-factory/make/contracts.js` — expose only any missing read-only delivery index/validation data required by the selector; preserve validation semantics.
- `skills/ai-layout/templates/ai-factory/make/delivery-report.js` — expose existing collection/evaluation in memory without writing reports or running checks, if the current interface is insufficient.
- `skills/ai-layout/templates/ai-factory/make/models.js` — include continuation in task dispatch policy and provide the existing destination-task directive path without letting the continuation result select arbitrary work.
- `skills/ai-layout/templates/ai-factory/make/runner.js` — reject unsupported headless continuation before launching a task or creating run artifacts.
- `skills/ai-layout/templates/ai-factory/make/sync-adapters.js` — add continue to the native-command exclusion set so Claude adapter sync does not duplicate the plugin's `/t4:continue`.
- `skills/ai-layout/scripts/sync-claude-commands.js`, `sync-codex-skills.js` — generate the two new entries and preserve current direct-task behavior.
- `skills/ai-layout/scripts/sync-self.js` — materialize the checkout's generated task link safely, without creating a regular file under protected `ai-factory/tasks/`.
- Existing focused checks (`check-contracts.sh`, `check-delivery-report.sh`, `check-interactive-model-routing.sh`, `check-runner-security.sh`, `check-plugin-hosts.sh`, `check-manifest.sh`, `check-entrypoints.sh`, `check-start-routing.sh`, and `check-release-docs.sh`) — cover unchanged contracts/report behavior, dispatch policy, host/adoption discovery, and documentation/release requirements.
- `README.md`, `ai-factory/docs/workflow.md` (no template copy exists under `skills/ai-layout/templates/ai-factory/docs/`), `skills/ai-layout/templates/ai-factory/AGENTS.md`, `ai-factory/AGENTS.md`, `FACTORY.md` (command count), `CHANGELOG.md` — document invocation, supported inputs and interactive-only behavior, preserve direct tasks, and identify template upgrade impact.
- Generated host wrappers only when generator output requires it; inspect every generated diff for unrelated changes.

No application models, persisted workflow state, dependency, migration, or release version bump is required. If a release is prepared later, use the existing synchronized-version checks.

## Server versus client

There is no application server or client in this plugin. The local Node helper reads delivery artifacts and produces a deterministic result; the interactive model session handles clarification and the single destination handoff. Generated Claude/Codex entries are host clients of the same helper contract. No application component or package is needed.

## Steps

- [x] Step 1 — Define and test read-only delivery inspection (AC1, AC2, AC3, AC4, AC8, AC10).
  Build fixture deliveries with contracts enabled in temporary workspaces. Add `selector-resolution`, `selector-reject-input`, `selector-drift-stop`, `selector-evidence-validation`, and `selector-read-only` cases to `check-continuation.sh selector`; expected-red tests are scoped to this step. Then implement delivery-ID resolution, documented precedence, bounded selector outcomes, supporting references, and fingerprint generation by reusing existing validators/evaluators. Cover missing/duplicate IDs, path/quick/unsupported delivery, expected-red versus unexpected failures, stale/malformed/contradictory evidence, spec drift, no writes, and no verification execution.
  Verify (red): `bash skills/ai-layout/scripts/check-continuation.sh selector` — the five named selector cases fail because the helper and selector contract do not exist.
  Verify (step): `bash skills/ai-layout/scripts/check-continuation.sh selector`
  Verify (step): `bash skills/ai-layout/scripts/check-contracts.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-delivery-report.sh`

- [x] Step 2 — Select valid existing tasks and handle ambiguity (AC5, AC6, AC7, AC10, AC13).
  Add `selector-action-precedence`, `selector-clarify-gaps`, `selector-interrupted-step`, and `selector-complete-from-report` cases to the selector group, then implement the earliest-prerequisite precedence table. Cover initial plan, appropriate red/gaps test, one named unfinished run step, review check, report, complete, and blocked. Require clarification if evidence cannot establish whether gaps testing occurred; clarification cannot convert failures into passes. Verify interrupted work remains untouched and report evaluation remains in memory.
  Verify (red): `bash skills/ai-layout/scripts/check-continuation.sh selector` — the four named phase-selection cases fail because no phase table or uncertain-phase outcome exists.
  Verify (step): `bash skills/ai-layout/scripts/check-continuation.sh selector`

- [x] Step 3 — Validate result and protect the single handoff (AC3, AC5, AC8, AC9, AC11, AC12).
  Add `handoff-result-schema`, `handoff-allowlist`, `handoff-fingerprint-recheck`, `handoff-data-is-not-code`, `handoff-single-dispatch`, and `handoff-destination-model-policy` cases. Implement schema validation, task-specific argument validation, clarification answer separation, and an immediate input fingerprint recheck before exactly one dispatch. Prove invalid results, changed inputs, drift, dispatch rejection, unavailable workers, failures, and cancellations stop without fallback; success stops at the destination boundary.
  Verify (red): `bash skills/ai-layout/scripts/check-continuation.sh handoff` — the six named handoff cases fail before validation and one-dispatch handling are added.
  Verify (step): `bash skills/ai-layout/scripts/check-continuation.sh handoff`
  Verify (step): `bash skills/ai-layout/scripts/check-interactive-model-routing.sh`

- [x] Step 4 — Integrate Claude, Codex, adoption and headless behavior (AC2, AC5, AC11, AC12, AC14).
  Add `entry-claude`, `entry-codex`, `entry-adoption`, and `headless-reject` cases to the focused checker and extend the existing host, manifest, entrypoint and runner checks. Add the task template and generate both host entries. Confirm an adopted workspace discovers the task, direct existing tasks behave as before, the headless runner rejects continuation explicitly before launch/artifact creation, and neither host waits unattended or guesses. Keep generated checkout links consistent through the sync helper.
  Verify (red): `bash skills/ai-layout/scripts/check-continuation.sh integration` — the four named host/adoption/headless cases fail because entries and explicit headless handling are absent.
  Verify (step): `bash skills/ai-layout/scripts/check-continuation.sh integration`
  Verify (step): `bash skills/ai-layout/scripts/check-plugin-hosts.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-manifest.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-entrypoints.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-runner-security.sh`

- [x] Step 5 — Document the boundary and prove complete behavior (AC1–AC14).
  Add `spec-drift-stop` and `single-action-resume` host transcript cases to `skills/ai-layout/fixtures/continuation/cases.md`. Document supported contract IDs, clarifications, drift reconciliation, unsupported headless/quick/contracts-disabled cases, and template upgrade impact. Capture real before/after interactive transcripts for both hosts: before, show the existing manual sequence; after, show a supported one-action resume and a drift stop. Record host/version, fixture state, evidence references and stopping point; never present fixture checks as host runs. Review the complete diff independently where available; otherwise label the review self-check. Run required final checks and retain any unavailable host scenario as unverified.
  Verify (step): `bash skills/ai-layout/scripts/check-release-docs.sh`
  Verify (final): `bash skills/ai-layout/scripts/check-continuation.sh`
  Verify (final): `node skills/ai-layout/scripts/sync-claude-commands.js --check`
  Verify (final): `node skills/ai-layout/scripts/sync-codex-skills.js --check`
  Verify (final): `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`
  Verify (final): `bash -c 'set -euo pipefail; shopt -s nullglob; for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done; for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f"; done'`
  **Marked complete by the owner (2026-10-05).** Docs, transcript scenarios and every Verify command passed. Real host transcripts and an independent review were waived and not performed; host acceptance stays unverified on both hosts.

## Risks and how they are checked

| Risk | Check |
|---|---|
| Checkbox marks, lifecycle events or refreshed sidecars are mistaken for passed evidence | Fixtures `selector-evidence-validation` and `selector-read-only`; existing contracts and report checks |
| Selector precedence skips an unsatisfied prerequisite or guesses gaps-test status | `selector-action-precedence`, `selector-clarify-gaps`, and transcript `single-action-resume` |
| Existing collection or evaluation mutates reports or runs verification | Snapshot the disposable fixture before/after; assert no new report/evidence and use a command sentinel proving verification did not execute (`selector-read-only`) |
| Artifact text or malformed result influences shell execution or arbitrary dispatch | `handoff-data-is-not-code`, schema/allowlist cases, and `handoff-fingerprint-recheck` |
| Drift is silently cleared or described too precisely | `selector-drift-stop` and transcript `spec-drift-stop`; assert downstream impact list and explicit reconciliation instruction |
| Host behavior diverges or generated entries miss adoption | `entry-claude`, `entry-codex`, `entry-adoption`, generator checks, and real host transcripts |
| Template edit reaches all adopted repos unexpectedly | Changelog and workflow docs state the next adoption/sync upgrade impact; `check-release-docs.sh` |

## Verification commands

Red checks are intentionally limited to the next implementation step and must fail on named cases, not because the checker is absent. Final completion requires every final command below to pass and both host transcripts to be recorded or clearly marked unavailable.

```bash
bash skills/ai-layout/scripts/check-continuation.sh selector
bash skills/ai-layout/scripts/check-continuation.sh handoff
bash skills/ai-layout/scripts/check-continuation.sh integration
bash skills/ai-layout/scripts/check-contracts.sh
bash skills/ai-layout/scripts/check-delivery-report.sh
bash skills/ai-layout/scripts/check-interactive-model-routing.sh
bash skills/ai-layout/scripts/check-plugin-hosts.sh
bash skills/ai-layout/scripts/check-manifest.sh
bash skills/ai-layout/scripts/check-entrypoints.sh
bash skills/ai-layout/scripts/check-runner-security.sh
bash skills/ai-layout/scripts/check-release-docs.sh
bash skills/ai-layout/scripts/check-continuation.sh
node skills/ai-layout/scripts/sync-claude-commands.js --check
node skills/ai-layout/scripts/sync-codex-skills.js --check
bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh
bash -c 'set -euo pipefail; shopt -s nullglob; for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done; for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f"; done'
```
