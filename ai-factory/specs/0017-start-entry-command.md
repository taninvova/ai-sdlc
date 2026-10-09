# Unified start entry command

Add `/t4:start <request>` to recommend the appropriate existing T4 workflow, briefly explain the choice, and hand the request to its first task.

## User story

As a developer bringing a change to T4, I want one entry command that chooses an appropriate existing procedure so that I can begin without learning every task name.

## Request and status

The user requested a plan for the previously proposed option: “One entry command: `/t4:start <request>` recommends `quick`, `fix`, `chore`, or the planned workflow. Explains the choice briefly and invokes existing procedures. Direct commands remain available.”

This is a draft prerequisite for that plan, not authorization to implement. Acceptance criteria below express that requested behavior and existing repository constraints. Proposed details are separated below and are not represented as independently approved requirements.

## Acceptance criteria

### AC1 — Unified entry

Given a repository with the applicable T4 workspace procedures, when a developer supplies a change request to the new start entry, then it selects an existing `quick`, `fix`, `chore`, or planned-workflow entry task and explains the choice briefly before handing off.

### AC2 — Existing procedure handoff

Given a selected task, when start hands off, then that task receives the original request and follows its existing project procedure, including its verification and reporting requirements; routing does not substitute a newly invented implementation procedure.

### AC3 — Small-change safeguards

Given a request with uncertain requirements or changes to authorization, public contracts, migrations, dependencies, or service ownership, when start assesses the request, then it preserves the repository's normal-workflow requirements instead of selecting a shortcut on the basis of file count or superficial size.

### AC4 — Respect prerequisite tasks

Given a request that needs business clarification, service placement, or implementation exploration under the existing `analyse`, `design`, or `explore` procedures, when start chooses the planned-workflow entry, then it selects the applicable prerequisite instead of silently treating undecided requirements or architecture as settled.

### AC5 — Direct commands remain available

Given a developer who invokes an existing task directly, when the start entry is installed, then that direct task retains its existing entry behavior and remains callable without going through start.

### AC6 — Existing host and model policy

Given a selected task with model-routing configuration, when start invokes it on Claude Code or Codex, then the selected task's existing host dispatch policy is honored, including failure handling; start does not silently bypass a selected model or proceed after a dispatch error.

### AC7 — Project boundaries and existing work

Given an existing checkout, when start inspects and routes a request, then it preserves local changes and follows the existing protection and workspace-boundary rules; a missing workspace or task is reported through the existing adoption or drift guidance without silently creating project adapters.

## Proposed design defaults for the implementation plan

These choices make the proposal concrete and reviewable; they are recommendations, not previously agreed product requirements.

- Keep start limited to classification and one initial handoff. A chosen `quick`, `fix`, or `chore` task can finish its normal work; a chosen prerequisite task ends at its existing stopping point. Do not automatically chain a complete delivery lifecycle.
- First apply project risk and explicit workflow constraints, then use `fix` for a understood defect, `chore` for understood maintenance without behavior drift, and `quick` for other understood local changes. Risk-bearing maintenance or defects must not evade normal-workflow requirements merely through their labels.
- For planned work, choose `analyse` for unsettled business requirements, `design` for unsettled placement or cross-service contracts, and `explore` for implementation uncertainty. Where multiple apply, start with the unresolved decision on which the others depend. Existing suitable artifacts can avoid repeating settled work.
- For empty input, ask for the change and expected result and stop without mutations. For genuinely ambiguous intent, ask the smallest question needed; do not turn ordinary implementation choices into mandatory approvals.
- Preserve the request as data. Keep the concise route explanation separate from the original text, and do not reinterpret embedded flags or commands as router options.
- Keep the first version prompt-driven with existing entry generators and procedures. Add no new persisted router state, assurance preset, or autonomous workflow engine.
- The session should own the final destination dispatch. Current `models.js` worker instructions prohibit a routed worker from redispatching or delegating. The implementation plan must provide a bounded classifier-result/session-handoff mechanism, or an equally explicit compatible design; it must not globally weaken existing worker restrictions. A model override used for start should not silently override the selected destination task's model.

## Out of scope

- Reliable continuation, a new status dashboard, assurance presets, operational acceptance, and workflow evaluation infrastructure from the other improvement options.
- Replacing existing tasks, relaxing their safety or review requirements, or creating additional specialist agents.
- Automatic implementation of every phase after an initial planned-workflow handoff.
- New business data, external integrations, external messaging, or host configuration writes.

## Open questions

None blocking this draft implementation plan. The proposed defaults above remain reviewable design choices. In particular, nested dispatch needs an explicit implementation design and validation before shipping; this is an engineering dependency rather than missing user intent.

## Data touched

No application models or fields. Existing task input, host dispatch directives, and possibly a bounded classification result are involved. No new persistent delivery format is proposed.

## Routes touched

New Claude Code `/t4:start` command and corresponding Codex `t4-start` skill; initial handoff to existing tasks. Any headless exposure must obey existing runner restrictions and cannot assume interactive clarification is available.

## Components likely involved

- Canonical task template under `skills/ai-layout/templates/ai-factory/tasks/`; this repository's `ai-factory/tasks/` is a protected symlink and must not be edited directly.
- `skills/ai-layout/scripts/sync-claude-commands.js` and `sync-codex-skills.js`, plus generated `commands/` and `codex-skills/` entries.
- `skills/ai-layout/templates/ai-factory/make/models.js` and existing host-routing checks, for explicit classifier and destination dispatch ownership.
- Relevant manifests, adoption/sync behavior, task catalogs, entrypoint and host checks, and user documentation as discovered during planning.
- Before/after prompt-run evidence and release notes required by repository policy for shipped task/template changes.
