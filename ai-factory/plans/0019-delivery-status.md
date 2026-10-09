# 0019 — Compact delivery status

Goal: add one evidence-based delivery view without changing existing state listings or executing work.
Spec: [0019-delivery-status](../specs/0019-delivery-status.md).

## Design defaults

Use `state --delivery <contract-id>` for planned and quick contract deliveries. Keep legacy default/`--done`/`--next` output intact; reject combined modes, missing IDs and duplicate identities without guessing. These are the spec's proposed defaults, not additional user requirements.

Use a presentation helper around existing `delivery-report.collect` and `evaluate`, never `generate`, `save` or report snapshots. It computes no next action: continuation 0018 remains independently deliverable. Show evidence-derived progress or unknown, never infer an active agent or completed gaps testing. No assurance-preset dependency.

## Files and components

- Create `skills/ai-layout/templates/ai-factory/make/delivery-status.js`: in-memory collection and compact field/value output using existing readiness semantics.
- Modify `skills/ai-layout/scripts/state.sh`: parse the mutually exclusive detail mode and pass literal arguments to the adopted helper; retain the existing listing path.
- Modify `commands/state.md`; regenerate `codex-skills/t4-state/SKILL.md` through `skills/ai-layout/scripts/sync-codex-skills.js`: present the selected mode's header and rows without inference.
- Create `skills/ai-layout/scripts/check-delivery-status.sh`; extend existing `check-state.sh` and adoption/entry-point checks as needed: acceptance fixtures and compatibility coverage.
- Update `README.md`, `ai-factory/docs/workflow.md` and `CHANGELOG.md`: explain opt-in contracts, detail invocation, unknowns and template impact.
- Use existing `contracts.js`, `delivery-report.js`, `safe-files.js` and `fixtures/contracts/` unchanged where possible; edit canonical targets only, never protected `ai-factory/make/` symlinks.

All components are local CLI/library code using Node's standard library. There is no server, browser client, external service or new persisted state.

## Steps

- [x] Step 1 — Write independent delivery-status acceptance fixtures (AC1–AC6).
  Add `check-delivery-status.sh` with planned/quick/legacy fixtures and expected field/value rows; extend `check-state.sh` with argument collisions and unchanged legacy output snapshots. Cover missing/duplicate IDs, disabled contracts, absent helper, traversal/symlink boundaries, malformed evidence, drift, interrupted verification, approval with blockers, attestation, expected-red, timestamp ties and unknown chronology.
  Compare fixture trees before/after each read and use sentinel verification commands to prove inspection never executes them. Exercise blank, completed and withdrawn plans; ticks/mappings/lifecycle success alone must not prove ACs passed.
  Give the new fixture script explicit `helper` and `cli` groups; put new mode cases there so existing state checks remain independently green. Test observable missing behavior through runnable entry points; a missing helper import or broken fixture setup alone is not acceptance-red evidence.
  Verify (red): `bash skills/ai-layout/scripts/check-delivery-status.sh cli` — named detail-output and no-false-success cases fail because state refuses the new mode; fixture setup succeeds.
  Verify (step): `bash skills/ai-layout/scripts/check-state.sh` — existing listing cases stay green.

- [x] Step 2 — Build the read-only delivery presentation helper (AC1–AC5).
  Validate identity and existing contract configuration, then collect/evaluate once with existing consistency retries and guarded readers. Report readiness reasons and source paths; show all criterion IDs grouped as verified, attested, remaining or unknown, preserving explicit failed results. Missing artifacts cannot produce an empty successful delivery.
  Define and test a conservative progress table from available artifacts/evidence: spec only → planning; unfinished plan → implementation progress; complete marks without valid final evidence → verification unproven; valid final evidence with missing required review → review pending; evaluator-ready → ready under policy; contradictory/insufficient facts → unknown. None asserts current execution or a resume action.
  Select latest non-review verification by valid `finished_at`, then ascending evidence path on ties. Show phase, expected outcome and freshness; any invalid/missing timestamp that prevents a reliable comparison leaves latest chronology unknown. Never substitute file modification time, run logs or today's time. Render review separately, including freshness and blockers.
  Verify (step): `bash skills/ai-layout/scripts/check-delivery-status.sh helper` — helper cases exit zero; CLI integration remains for Step 3.
  Verify (step): `bash skills/ai-layout/scripts/check-delivery-report.sh` — report interpretation remains unchanged.
  Verify (step): `bash skills/ai-layout/scripts/check-contracts.sh` — contract interpretation remains unchanged.

- [x] Step 3 — Connect state and both hosts without changing legacy listings (AC1, AC4–AC6).
  Add isolated argument parsing and invoke the workspace's adopted helper with literal argv. Missing/outdated helpers receive sync guidance without file writes or fallback to a different mode. Preserve listing columns, order, withdrawal handling and selection for existing valid calls. Keep one-line refusal conventions; surface runtime failure distinctly.
  Update the canonical command to render each mode's actual header; generated Codex keeps the same shared procedure. Verify adoption copies the new helper through existing mechanisms; do not generate host adapters during status execution.
  Run `node skills/ai-layout/scripts/sync-codex-skills.js` for generated package entries.
  Verify (step): `bash skills/ai-layout/scripts/check-state.sh` — legacy cases remain green.
  Verify (step): `bash skills/ai-layout/scripts/check-delivery-status.sh` — both groups green, repeated/headless output identical.
  Verify (step): `bash skills/ai-layout/scripts/check-adapters.sh`.
  Verify (step): `bash skills/ai-layout/scripts/check-entrypoints.sh`.

- [x] Step 4 — Document limits, record host proof and complete checks (AC1–AC6).
  Document the proposed interface and examples for missing evidence, stale review and attested criteria. Record before/after Claude and Codex transcripts proving argument forwarding, accurate presentation and no mutations. Record evidence under the delivery report; do not claim host proof from string checks alone.
  Document adopted-template impact in the changelog. Version bumps and release publication remain outside feature implementation.
  Verify (final): `node skills/ai-layout/scripts/sync-codex-skills.js --check`.
  Verify (final): `node skills/ai-layout/scripts/sync-claude-commands.js --check`.
  Verify (final): `make check` — full repository checks, including both new fixture groups, must pass.

## Risks and checks

- False green: test missing, stale, failed and contradictory evidence independently of checked boxes or AC coverage mappings; compare interpretation with existing evaluator results.
- Side effects: tree snapshots and execution sentinels prove collection produces no reports, evidence, adapters or workflow activity, including error paths.
- Compatibility: legacy golden outputs and host transcripts cover unchanged listing selection and presentation; detail mode uses its own table shape.
- Concurrent writers and unsafe paths: reuse collector retries and path guards; test changed snapshots, symlinks and duplicate delivery identities without trusting arbitrary artifact text.

## Assumptions

No blocking spec questions. Planned and quick contract deliveries are in scope; legacy detail and path selectors are deferred. A claimed phase means observed progress only. Final completion requires every listed check and host transcript; unavailable host proof remains explicitly outstanding.
