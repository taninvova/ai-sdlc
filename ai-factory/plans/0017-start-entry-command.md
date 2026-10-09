# Unified start entry command

## Goal and spec

Add one entry that explains an appropriate existing workflow and hands the original request to its first task, while retaining that task's model policy and stopping rules.

Spec: [0017-start-entry-command.md](../specs/0017-start-entry-command.md).

This is an implementation plan, not implementation authorization. All steps are complete. The owner waived Step 2's paired real-host runs and Step 4's host transcript evaluation and independent review of the final diff (2026-10-05).

## Design decisions

- Start performs classification only. Its result is a bounded, in-memory recommendation: `status` (`route`, `question`, or `blocked`), an allowlisted task when routed, and a short reason or question. It never supplies executable commands, rewritten task input, model options, or a next-phase chain. The invoking session retains the original input separately.
- Allow `quick`, `fix`, `chore`, `analyse`, `design`, `explore`, and `spec`. Use `spec` only when requirements and architecture are settled and no prerequisite is missing. An explicitly chosen incompatible workflow is clarified rather than silently overridden. Existing artifacts inform classification; start does not automatically resume a delivery.
- Preserve normal start model dispatch for legacy, inherit and configured native routing. A leading explicit start override is parsed once: `--task-model=inherit` classifies in the session, while a concrete `--task-model=<id>` start override is blocked before launch, because the host's generic override worker cannot enforce the classifier's read-only profile (revised during implementation after review; see the delivery report). A routed start worker only classifies and returns its result; it never dispatches, delegates, or implements. Give this worker a start-specific classification instruction and read-only tool profile. Keep generic worker restrictions unchanged. The session's start-specific completion branch validates the result and owns the one destination handoff, instead of the generic terminal-report branch. Legacy/inherit start uses the same classifier/result convention in the session.
- Invoke the selected task's existing dispatch directly with its own task name and no forwarded start override. After its directive succeeds, execute the selected project procedure with the retained input verbatim. Do not pass the retained text through entry-option parsing again: a leading flag in that text is task data. Preserve existing routed-worker failure, question/resume, accounting, and final-report behavior.
- Reject headless `TASK=start` explicitly before launching a CLI or creating run artifacts. Explain that v1 requires an interactive session and that CI must name a destination task. Headless classification or redispatch is outside this change.
- Empty input asks for the change and expected result and stops. Missing workspace/task follows adoption/drift guidance. No implicit adapter sync, host writes, persistent router state, or new agents.

## Files

Create:

- `skills/ai-layout/templates/ai-factory/tasks/start.md` — concise project-owned classification procedure and output contract.
- `commands/start.md`, `codex-skills/t4-start/SKILL.md` — generated host entries that own classification and destination handoff.
- `skills/ai-layout/scripts/check-start-routing.sh` — focused regression checks with named `dispatch`, `entry`, and `headless` groups; this script does not exist yet.
- `skills/ai-layout/fixtures/start-routing/cases.md` — fixed requests, fixture setup, expected decisions, and host transcript evaluation rubric; this is not a new evaluation framework.

Modify:

- `skills/ai-layout/templates/ai-factory/make/models.js` — bounded result validation, start-only read-only worker instructions and completion directive, and shared start entry guidance; retain other task semantics.
- `skills/ai-layout/scripts/sync-claude-commands.js`, `sync-codex-skills.js` — generate the start session handoff without changing direct task entry behavior.
- `skills/ai-layout/templates/ai-factory/make/runner.js` — explicit early headless rejection.
- `skills/ai-layout/scripts/check-interactive-model-routing.sh`, `check-plugin-hosts.sh`, `check-manifest.sh`, `check-runner-security.sh` — exercise existing host, adoption, routing and runner seams for start.
- `README.md`, `skills/ai-layout/templates/ai-factory/AGENTS.md`, `ai-factory/AGENTS.md`, `CHANGELOG.md` — entry examples, routing limits, direct-task availability and template-upgrade impact.
- Generated existing command/skill wrappers only if the shared generator output changes; inspect every such diff for unintended behavior changes. Use `sync-self.js` to create this checkout's start task symlink, never a regular file under protected `ai-factory/tasks/`.

Manifest task discovery is dynamic; test adoption of the new task rather than inventing a static task registry. No release/version bump is required by this plan; if releasing, follow the existing synchronized-version checks in a separate release step.

## Server versus client

Neither: this plugin consists of prompts, local Node scripts, and generated host entries. Classification belongs to the model session; deterministic validation, dispatch and headless rejection belong to the existing local scripts. No application component or dependency is needed.

## Steps

- [x] Step 1 — Specify and prove the bounded classifier dispatch (AC1, AC2, AC6).
  Add the canonical start task and fixture requests. Add the new check script's `dispatch` group, scoped to this step: `start-read-only`, `start-result-validation`, `start-session-handoff`, `destination-model-independent`, and `other-workers-unchanged`. Then implement start-specific worker/result/completion handling in `models.js`. Reject unknown tasks, malformed/contradictory results and extra executable fields without dispatch. Test legacy, inherit, configured and invocation-override starts, including distinct start/destination models, unavailable workers, stale adapters and worker failure. No destination execution occurs inside the classifier.
  Verify (red): `bash skills/ai-layout/scripts/check-start-routing.sh dispatch` — after adding tests but before changing `models.js`, the named start-specific tests fail because workers have generic write permissions/terminal completion and no validated classifier result. An absent script is not a valid expected-red result.
  Verify (step): `bash skills/ai-layout/scripts/check-start-routing.sh dispatch`
  Verify (step): `bash skills/ai-layout/scripts/check-interactive-model-routing.sh`

- [x] Step 2 — Expose and complete the interactive handoff (AC1, AC2, AC3, AC4, AC5, AC6, AC7).
  Generate both entries, preserve the original request in session memory, separate explanation from input, and call exactly one destination dispatch after validation. Test independent target selection, no second option parsing, exact multiline/quotes/backticks/flag preservation, blocked/question outcomes, empty input, missing workspace/task, no silent sync, and unchanged direct entries. Run both generators and `node skills/ai-layout/scripts/sync-self.js`; verify repeat generation has no additional diff. Add the `entry` test group before implementing generator changes. Perform the paired host runs below; static wording assertions alone do not prove the routing rules.
  Verify (red): `bash skills/ai-layout/scripts/check-start-routing.sh entry` — named `start-wrapper-handoff`, `original-input-preserved`, and `target-override-not-inherited` fail on the pre-change generated entry behavior.
  Verify (step): `bash skills/ai-layout/scripts/check-start-routing.sh entry`
  Verify (step): `node skills/ai-layout/scripts/sync-claude-commands.js --check`
  Verify (step): `node skills/ai-layout/scripts/sync-codex-skills.js --check`
  Verify (step): `bash skills/ai-layout/scripts/check-plugin-hosts.sh`
  **Marked complete by the owner (2026-10-05).** Deterministic phase passed (`entry` 4/4 incl. `direct-entries-unchanged`, both generator checks, plugin hosts; `dispatch` and `headless` groups and interactive routing still pass). The paired real-host runs were waived: only the cases recorded in `ai-factory/reports/0017-start-entry-command.md` were run, and the remaining before/after cases stay unverified on both hosts. Actual multiline/quote/backtick/flag preservation is asserted by wrapper wording only.

- [x] Step 3 — Close the headless and adoption paths (AC5, AC6, AC7).
  Add `headless-start-refused-before-launch` and direct-task control fixtures using fake host CLIs. Reject start before provider invocation and run-file creation, with an actionable interactive/direct-task message. Extend manifest fixtures to prove fresh adoption includes start and an older/local-modified workspace reports drift without replacing local files or generating adapters. Preserve existing runner tasks.
  Verify (red): `bash skills/ai-layout/scripts/check-start-routing.sh headless` — the named rejection case fails because the current generic runner attempts to launch start.
  Verify (step): `bash skills/ai-layout/scripts/check-start-routing.sh headless`
  Verify (step): `bash skills/ai-layout/scripts/check-runner-security.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-manifest.sh`
  Verify (step): `bash skills/ai-layout/scripts/check-workspace.sh`

- [x] Step 4 — Document and verify the complete change (AC1, AC2, AC3, AC4, AC5, AC6, AC7).
  Update command catalogs and examples, explain start versus destination model scope and the interactive-only limit, and identify the template change/upgrade impact in CHANGELOG. Complete transcript evaluation and independent review of the actual diff. Record before/after transcript links and limitations in the implementation report/MR. Run all required final checks once; repeat affected checks only after subsequent edits. Do not report completion if a required host run or check is unavailable.
  Verify (final): `bash skills/ai-layout/scripts/check-start-routing.sh`
  Verify (final): `node skills/ai-layout/scripts/sync-claude-commands.js --check`
  Verify (final): `node skills/ai-layout/scripts/sync-codex-skills.js --check`
  Verify (final): `bash -n skills/ai-layout/templates/ai-factory/make/sync-adapters.sh`
  Verify (final): `bash -c 'set -euo pipefail; shopt -s nullglob; for f in skills/ai-hooks/scripts/*.js; do node --check "$f"; done; for f in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do bash "$f"; done'`
  This is the existing mandatory full suite, made fail-fast; do not pipe output to `tail` or mask failures. The new start script participates after it exists.
  **Marked complete by the owner (2026-10-05).** Docs complete and every Verify (final) command passed. Host transcript evaluation and independent review of the final diff were waived and not performed; see the report's "Step 4 final verification" section.

## Behavioral before/after runs

Use disposable adopted repositories under `ai-factory/runs/tmp/`; preserve the developer's checkout. Capture actual host transcripts using each host's normal interactive invocation, with the same fixture input/configuration before and after. Before implementation, record the missing start entry and directly invoke the expected existing destination as the behavior baseline. After implementation, invoke `/t4:start` on Claude Code and `t4-start` on Codex. Record host/model, fixture state, original input, explanation, selected task, dispatch directive, received task input, observed writes and stopping point. Do not fabricate runs from test output.

Evaluate these cases on both hosts:

| Request/setup | Expected evidence | ACs |
| --- | --- | --- |
| Understood local wording change; understood reproducible defect; maintenance with no behavior drift | quick/fix/chore respectively; destination's normal verification/reporting retained | 1, 2, 5 |
| Unsettled user permissions; known authorization change; public API, migration, dependency or ownership changes disguised as one-line fixes | No shortcut; applicable normal entry and reason | 3 |
| Unsettled business outcome; unsettled service placement with settled business needs; settled business/placement but uncertain implementation | analyse/design/explore respectively; one initial handoff, stop at that task's normal boundary | 4 |
| Settled requirements/architecture with no missing prerequisite; existing relevant artifact; explicit user workflow choice | spec where suitable; no redundant prerequisite and no unrequested full lifecycle | 1, 4 |
| Empty/ambiguous input; missing workspace; missing selected task; dirty tracked and untracked fixture files | Minimal clarification or clear adoption/drift message; no unauthorized writes, reset or adapter creation | 7 |
| Distinct configured start/target models; start override; routing disabled; target dispatch rejected or worker unavailable | Classifier only on start model; a concrete start override is blocked (inherit classifies in session); destination's own model/directive honored; rejection stops without fallback | 6 |
| Multiline input with quotes, backticks and embedded or retained leading flags | Destination receives original task text exactly; no execution or second parsing of request options | 2, 6 |

Static/fixture checks prove deterministic dispatch mechanics and preservation; transcripts prove the model's classification and stopping behavior. Repeat a failed prompt case after a focused correction and retain both runs. If either host cannot be exercised, label its acceptance unverified rather than treating generated-text checks as a substitute.

## Risks and ambiguities

- The current generic worker must never redispatch or hand work back. Only start's classifier-result completion is exceptional; a regression fixture must prove every other worker retains the current restrictions. A returned recommendation is data, not authority to execute arbitrary tasks.
- A request can have several unresolved decisions. Route to the earliest dependency; ask only when intent cannot be resolved from available evidence. Before/after cases must include overlapping business and service uncertainty.
- Prompt routing is not a security boundary. Destination procedures still enforce scope and protected paths; fixture checks and host permissions remain required.
- Proposed defaults remain reviewable: bounded classification result, `spec` as the settled planned entry, and explicit headless rejection. No blocking product question was found. If the existing hosts cannot return a reliable bounded classifier result, stop with evidence rather than weakening all worker restrictions or silently bypassing model policy.
