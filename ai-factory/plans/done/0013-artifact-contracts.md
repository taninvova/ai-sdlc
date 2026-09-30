# Plan 0013 — Validated artifact contracts

**Status:** Done. All six steps are checked off, and the verification evidence and its limits are recorded below.

**Goal:** Deterministic, read-only validation of the spec → plan → evidence handoff and of quick-work checklists, shared by Claude and Codex.

**Spec:** `ai-factory/specs/0013-artifact-contracts.md`

**Branch:** `feat/artifact-contracts`, one commit per step, released as 2.5.0.

## Execution status — 2026-09-30

- **Local verification.** `make check` passes, including the new
  `skills/ai-layout/scripts/check-contracts.sh` with 37 cases.
  - The cases run in disposable Git repositories under `ai-factory/runs/tmp/`.
  - Covered: an invalid handoff, stale handoffs from spec, plan and code edits, a successful
    planned flow, a successful quick flow, and a legacy migration run twice.
  - Also covered: an adopted workspace running both flows through `make verify` and
    `make contracts`, plus doctor and review-evidence integration.
- **Syntax and generation checks.** `node --check` and `bash -n` pass on the new scripts, and
  the host generators pass `--check` (Claude commands, Codex skills, materialized agents).
- **Commit layout.** Steps 2 and 3 share one commit because freshness lives in the same module
  as the validator.
- **Not run.** Real-host smoke tests, meaning a live Claude or Codex session driving
  `/t4:spec` … `/t4:check` with contracts enabled, were not run. `make review DELIVERY=…` was
  exercised only against a fake CLI.
- **This repository does not opt in.** It carries no `ai-factory/contracts/config.json`, so its
  own specs and plans stay `legacy_unverified` under an explicit `validate --all`.
- **Structural only.** Every result says so; the validator judges no requirement's quality.

## Implementation sequence

- [x] **Step 1 — Specify schemas and fixtures.** AC1, AC2, AC5, AC6. Add `skills/ai-layout/templates/ai-factory/contracts/` (README plus informative v1 JSON Schema documents) and fixtures under `skills/ai-layout/fixtures/contracts/`. Add `skills/ai-layout/scripts/check-contracts.sh`. **Verify:** `bash skills/ai-layout/scripts/check-contracts.sh` fails only because the validator does not exist yet.
- [x] **Step 2 — Build the validator.** AC1, AC2, AC5, AC7. Add `make/contracts.js` (validate, snapshot, init) and the `make contracts` target. **Verify:** malformed, traversal and symlink fixtures fail with a path and code; JSON mode stdout parses.
- [x] **Step 3 — Implement freshness checks.** AC3. Code snapshot and stale propagation. **Verify:** mutating each upstream input produces the expected `S_*` diagnostic; excluded files and mtime-only changes do not.
- [x] **Step 4 — Capture verification evidence.** AC4. `contracts.js record` and `make verify`; review evidence from `runner.js review()`. **Verify:** nonzero exit, interruption, unavailable commands and expected red failures never become final passes.
- [x] **Step 5 — Integrate task handoffs.** AC6, AC7. Update spec, plan, test, run, check and quick procedures and agents; regenerate host entry points. **Verify:** a scratch adopted project completes planned and quick flows; host sync checks pass.
- [x] **Step 6 — Add adoption and documentation.** AC7. `contracts.js enable` and `migrate`, `/t4:sync-sdlc` and doctor integration, inventories, docs, 2.5.0 release metadata. **Verify:** migration twice is idempotent, customized Markdown survives, `make check` passes.

## Risks

- Overclaiming semantic correctness from structural checks: every summary carries the structural-only note.
- Excessive freshness invalidation: the code scope is explicit in `config.json` and tested.
- Rollback: disabling contracts leaves Markdown, sidecars and evidence in place and never reinterprets them as verified.
