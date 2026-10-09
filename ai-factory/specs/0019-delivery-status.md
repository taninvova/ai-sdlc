# 0019 — Compact delivery status

Show a delivery's progress and supporting evidence together through the existing state command.

Status: draft for planning; proposed defaults below guide the implementation plan.

## User story

As a developer returning to a delivery, I want a compact status with its phase, remaining acceptance criteria, verification, review and blockers so I can understand what remains without opening every artifact.

## Requested behavior

Extend the existing read-only state surface using repository artifacts and evidence. Preserve its default listing and `--done` / `--next` behavior. Missing evidence means unknown or unverified, never success.

## Acceptance criteria

- **AC1** Given an identified delivery, When its status is requested, Then one compact view shows its phase, remaining acceptance criteria, latest recorded verification, review status and blocking reason, with source paths.
- **AC2** Given evidence that is missing, stale, malformed or contradictory, When status is shown, Then affected fields explain the limitation and do not claim verified completion or approval.
- **AC3** Given plan checkboxes or lifecycle events without current verification, When status is shown, Then recorded progress remains distinct from proven acceptance criteria; a successful run or checked step alone does not prove delivery completion.
- **AC4** Given the same repository contents, When status runs interactively or headlessly, Then a deterministic reader produces the same result without relying on conversation history.
- **AC5** Given any status request, When it completes, Then no files are created, modified or deleted and no tests, review, workflow dispatch or continuation are started.
- **AC6** Given existing default, `--done` and `--next` invocations, When the feature is installed, Then their selection, ordering, withdrawal handling and output remain unchanged.

## Proposed defaults — recommended implementation choices

- Add `state --delivery <contract-id>` as a separate mode, mutually exclusive with existing flags. Support planned and quick contract deliveries; reject ambiguous or missing IDs with an explanation. Legacy listings remain available.
- Reuse the report collector/evaluator in memory; never invoke report generation or save a report. Read current artifacts rather than trusting a saved report snapshot.
- Present a two-column field/value table. Show criterion IDs grouped by verified, attested, remaining and unknown; attestation remains visibly distinct from executable proof.
- Label phase as evidence-derived progress, not a claim that an agent is currently running. Use `unknown` when artifacts do not establish a phase.
- Determine latest verification from its recorded timestamp, with a stable path tie-break. Display its purpose, expected result and freshness; expected-red evidence is not final verification. Missing/invalid timestamps leave chronology unknown.
- Use existing readiness reasons and severity rules. Report known blockers separately from missing evidence; absence of a recorded blocker does not prove readiness.
- Reuse existing contract policy; assurance presets are not a prerequisite. No dependency on the proposed continuation command.

## Out of scope

A dashboard, persisted workflow state, new completion policy, automatic continuation, workflow routing, executing checks, or changing existing reports and historical artifacts.

## Open questions

None blocking planning. Use the proposed contract-ID detail mode, existing legacy listings, evidence-derived phase, timestamp/path ordering and separate attestation display as draft design defaults. These are implementation recommendations rather than additional user requirements; path selectors and richer legacy detail can be considered separately.

## Data, routes and components

Data: read existing specs, plans, quick artifacts, contract sidecars, verification and review evidence; no new persisted data. Routes: none.

Likely components: `skills/ai-layout/scripts/state.sh`, `commands/state.md`, generated Codex state entry point, and canonical `skills/ai-layout/templates/ai-factory/make/{contracts,delivery-report}.js`; state fixtures and documentation.

Context: spec 0010 defines existing state behavior; specs 0013–0014 define contracts and report readiness. Exploration 0003 describes related continuation ideas, not approved requirements for this feature.
