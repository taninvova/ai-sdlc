# Spec 0014 — Delivery completion report

**Summary:** A local, reproducible report per delivery that shows what was requested, what changed, which checks actually ran, what review found and what remains open. It is written as Markdown and JSON from one model, with one status: `ready`, `incomplete`, `blocked` or `unverified`, each with its reasons.

**Source:** The owner's P1 "Delivery completion report" implementation plan (2026-09-30). It builds on the artifact contracts of spec 0013.

## Scope and boundary

- Entry points:
  - `/t4:report` in Claude, `t4-report` in Codex;
  - `make -f ai-factory/make/ai.mk delivery-report DELIVERY=<id>`.
- Outputs: `ai-factory/reports/<id>/completion.{md,json}`.
- The report only reads existing evidence and writes those two files. It never runs a check, edits a source artifact, posts to a tracker, opens an MR, commits, merges or deploys.
- `ready` means ready for delivery handoff. It does not mean merged or deployed.
- Telemetry is optional. Until a per-delivery export exists, the report says so.

## Acceptance criteria

| ID | Given / When / Then |
|---|---|
| AC1 | Given a delivery, when its report is generated, then every criterion appears exactly once, uncovered ones included, and a criterion is mapped only to the plan steps its sidecar names, never by similar wording. |
| AC2 | Given missing or stale required evidence, when the report is generated, then the status is not `ready`; generating the report executes no test and alters no source artifact. |
| AC3 | Given failed checks, unresolved review blockers or interrupted verification, when the report is generated, then each stays visible with a reference to its evidence. |
| AC4 | Given a generated report, when its Markdown and JSON are compared, then the statuses, counts and evidence identifiers are identical, and the JSON carries an explicit schema version. |
| AC5 | Given a quick delivery, when its report is generated, then its acceptance checklist is used and no full spec is fabricated. |
| AC6 | Given missing, partial or incompatible telemetry, when the report is generated, then the telemetry section says so, and absent values are never shown as zero cost or zero duration. |
| AC7 | Given an unsafe ID, an external path or a symlink escape, when the report is generated, then it is rejected; the report includes selected summaries only, never raw transcripts, credentials or full tool output. |
| AC8 | Given Claude or Codex, when either requests the report, then both wrappers delegate to the same implementation, and nothing is published externally. |

## Defined behavior

- **Status precedence.** A known required-check failure or a blocking review finding makes the delivery `blocked`. Otherwise, missing, malformed or stale required evidence makes it `unverified`. Otherwise, valid evidence of unfinished work makes it `incomplete`. Only a fully satisfied delivery is `ready`. Every contributing reason is listed.
- **Completion policy.** It lives in the `completion` block of `ai-factory/contracts/config.json`:
  - `require_review` (default true);
  - `require_review_quick` (default false);
  - `blocking_severities` (default `["blocker"]`);
  - `allow_attestation` (default false).
- **Human attestation.** Attestation records the actor, time, rationale and source. It counts only when the policy allows it, and never over a failed check.
- **Output.** Both files are written atomically. Repeated generation with identical evidence differs only in `generated_at`. If evidence changes during collection, collection retries a bounded number of times, then aborts without writing.

## Out of scope

Publishing, MR creation, and producing lifecycle telemetry. The telemetry export is a separate plan; this spec defines only the reader.

## Open questions

None blocking.
