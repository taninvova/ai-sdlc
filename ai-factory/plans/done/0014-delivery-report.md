# Plan 0014 — Delivery completion report

**Status:** Done. All seven steps are checked off, and the verification evidence and its limits are recorded below.

**Goal:** Assemble contract evidence into one reproducible Markdown + JSON completion report with a single status calculation.

**Spec:** `ai-factory/specs/0014-delivery-report.md`

**Branch:** `feat/delivery-report`, released as 2.6.0.

## Execution status — 2026-09-30

- **Checks.** `make check` passes. The new `skills/ai-layout/scripts/check-delivery-report.sh` has 20 cases, run in disposable Git repositories under `ai-factory/runs/tmp/`:
  - planned deliveries reaching `ready`, `incomplete`, `blocked` and `unverified`;
  - a quick delivery reaching `ready` from its checklist alone;
  - a legacy migration draft, which stays `unverified`;
  - the review blocker, `request_changes` and severity-policy cases;
  - attestation with policy off and on, over a failed check, and after the spec changed;
  - Markdown/JSON parity, and regeneration that differs only in `generated_at`;
  - no execution during collection and no inlined logs;
  - unsafe IDs, symlinked destinations and escaping references;
  - atomic-write failure;
  - mutation during collection, both aborted and retried;
  - five kinds of telemetry input;
  - an adopted workspace running `make delivery-report` for planned and quick deliveries.
- **Contracts regression.** `check-contracts.sh` still passes 37 cases, and its schema drift check now covers the attestation schema.
- **Commit layout.** Steps 2–4 and 6 share one commit because they live in one module, `make/delivery-report.js`.
- **Not run.** Real-host smoke tests, meaning a live `/t4:report` in Claude and `t4-report` in Codex, were not run. Wrapper equivalence is checked statically. No telemetry producer exists yet; the reader is covered by fixture exports.
- **Structural only.** The report never runs checks, and its MR description is a draft.

## Implementation sequence

- [x] **Step 1 — Define the report contract.** AC1, AC4, AC6. Add `contracts/schema/report.v1.json` and `attestation.v1.json`, and document them. Add `skills/ai-layout/scripts/check-delivery-report.sh`, with the expected status of each fixture scenario written down first. **Verify:** the check fails only because `delivery-report.js` is missing.
- [x] **Step 2 — Build the read-only evidence collector.** AC2, AC7. Add `make/delivery-report.js` `collect()`: a fingerprint and bounded retry, and read-only git for the changed files. Add contracts attestation evidence, review findings and a completion policy. **Verify:** conflicting IDs, deleted files, concurrent mutation, out-of-bound references and symlinks are all handled; the project tree is unchanged.
- [x] **Step 3 — Implement readiness calculation.** AC1, AC2, AC3, AC5. Build the criterion matrix and apply the status precedence and policy. **Verify:** every negative fixture prevents `ready`; there is no mapping by wording.
- [x] **Step 4 — Render and save both formats.** AC4, AC7. Render Markdown and JSON from one model and write both atomically. **Verify:** the two formats agree, ordering is stable, text is escaped, a failed write keeps the previous report, and no raw output is included.
- [x] **Step 5 — Add workflow entry points.** AC8. Add the `delivery-report` make target, the `report` task, and the generated Claude and Codex wrappers. **Verify:** both wrappers delegate to the same task; an adopted scratch project generates reports.
- [x] **Step 6 — Integrate optional telemetry.** AC6. Read `ai-factory/runs/telemetry/<id>.json` when it exists. **Verify:** missing, partial, malformed and incompatible telemetry never changes the status and never shows as zero.
- [x] **Step 7 — Validate and document the release.** AC1–AC8. Update the docs, inventories and 2.6.0 release metadata. **Verify:** `make check` passes.

## Risks

- Treating a polished summary as proof. Every readiness claim links to current evidence and names the checks that were unavailable.
- Accidental disclosure. The report reads only sources selected explicitly for this delivery, includes summaries only, and never inlines logs.
