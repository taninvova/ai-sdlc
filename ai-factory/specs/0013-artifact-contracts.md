# Spec 0013 — Validated artifact contracts

**Summary:** Add deterministic, read-only validation between workflow steps so malformed, incomplete or stale specs, plans, quick checklists and verification evidence cannot silently become the next step's input. Markdown remains the working surface; versioned JSON sidecars carry the machine-checkable metadata.

**Source:** The P1 "Validated artifact contracts" implementation plan supplied by the owner on 2026-09-30. Its design defaults are adopted here; they were not previously approved repository decisions.

## Scope and boundary

- Planned workflows (spec → plan → test → run → check) and a small acceptance-checklist contract for `/t4:quick`.
- Structural validity only. A valid contract proves consistency of IDs, references, digests and recorded execution, never the truth or quality of a requirement. All output says so.
- Opt-in per project (`ai-factory/contracts/config.json`). Projects that have not adopted contracts keep today's workflow unchanged.
- Node built-ins and the existing `safe-files.js` boundary only; no schema package.

## Acceptance criteria

| ID | Given / When / Then |
|---|---|
| AC1 | Given a valid spec, plan and evidence chain, when it is validated, then the validator prints stable JSON diagnostics (JSON mode) or a readable summary and exits 0. |
| AC2 | Given duplicate or missing criterion IDs, unknown references, missing verification commands, malformed sidecars or an unsupported schema version, when validated, then it exits nonzero naming the artifact path and an actionable reason. |
| AC3 | Given an edited spec, when validated, then dependent plans and evidence are stale; given edited in-scope code, then the corresponding test and review evidence is stale. A timestamp alone never proves freshness. |
| AC4 | Given required evidence, when validated, then `passed`, `failed`, `not_run` and `unavailable` are distinguished; a checked Markdown box is never execution proof, and an expected red failure never satisfies final verification. |
| AC5 | Given any validation, when it runs, then it writes nothing; paths escaping the project boundaries, including symlink escapes, are rejected; files merely mentioned in artifact prose are never read. |
| AC6 | Given contracts are adopted, when quick work completes, then its acceptance checklist and focused evidence validate without a full spec or plan. |
| AC7 | Given Claude or Codex, when either runs the workflow, then both use the same validator and diagnostic schema. Legacy migration is explicit, idempotent, and preserves customized prose byte-for-byte. |

## Defined behavior

- Every delivery has a stable local `delivery_id` (`d-YYYYMMDD-xxxxxx`), independent of an optional tracker key and of file names, so renames and `plans/done/` moves keep the chain.
- Sidecars live beside their artifact as `<name>.contract.json`; evidence lives under `ai-factory/evidence/<delivery_id>/`.
- States: `valid`, `invalid`, `stale`, `legacy_unverified`. Missing or unsupported metadata is never valid.
- Freshness is SHA-256 of the Markdown and of an explicit code snapshot (tracked, modified and untracked-but-not-ignored files within the configured scope). `ai-factory/` is never part of the code snapshot, so producing reports or evidence cannot invalidate itself.
- Verification commands are argv arrays executed without a shell.
- Migration drafts sidecars marked for review; it never invents IDs silently, never invents evidence, never edits Markdown.

## Out of scope

A pipeline orchestrator, tracker integration, automatic repair, semantic requirement checks, and a mandatory full spec for quick work.

## Open questions

None blocking. Real-host smoke tests depend on available credentials and are reported separately from deterministic fixtures.
