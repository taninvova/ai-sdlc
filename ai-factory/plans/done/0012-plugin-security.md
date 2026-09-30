# Plan 0012 — Fix plugin security boundaries

**Status:** Done — all six steps are checked off, with verification evidence and host limitations recorded below.

**Goal:** Eliminate the reproduced command-execution and filesystem bypasses, make enforced reviews trustworthy as workflow gates, and accurately document host enforcement limits.

**Spec:** `ai-factory/specs/0012-plugin-security.md`

**Priority:** Security before performance optimization. Baseline inspected at HEAD `ab750a6`; existing work on `state.sh` belongs to plan 0010 and must be preserved.

**Relationship to plan 0011:** This is the implementation owner for SEC1–SEC4, shell-safe runner configuration, protected-path resolution, safe hook/runner writes, exact review-output binding, and review-result validation. Plan 0011 retains broader adoption/adapter containment, complete local agent instructions, the review's selected diff, model-precedence enhancements, and performance work. Do not implement the overlapping security changes twice. This plan is independent of the unresolved external-entry-file policy.


## Execution status — 2026-09-29

All six steps are implemented and locally verified. The 20-suite isolated regression is
green, including 36 guard cases, 62 writer-boundary cases and 26 workspace cases, runner injection protection,
strict review validation and accounting/schema compatibility. Hook and runner accounting
share one lock; the standalone flush waits for active hooks. Versioned manifests and the
changelog are prepared as 2.3.0. Nothing is committed or published.

Evidence: `ai-factory/runs/0011-verification.md`. Host boundary verification is limited to
synthetic hook invocations, registration inspection and Codex fixture runs. A live Claude
hook integration and adversarial host-sandbox races were not exercised; Step 5 explicitly
permits recording that limitation. This is not a general sandbox or penetration-test claim.
Static unsafe destinations fail safely; hostile ancestor races require host enforcement.
Accounting remains nontransactional across a crash/disk failure between usage claim and row
append. Supported normal and concurrent accounting paths pass; crash reconciliation is not
claimed. No known high-priority reproduced defect is hidden by these qualifications.

## Findings to close

| Finding | Reproduction already observed | Owner |
|---|---|---|
| SEC1 — shell interpretation | A model setting containing command substitution created a harmless marker using the real Make recipe and a fake CLI. | Step 1 |
| SEC2 — ineffective path protection | Direct protected path: exit 2. Symlink alias, nested cwd, and missing policy: exit 0. Bash is not covered by the edit guard. | Steps 2 and 5 |
| SEC3 — redirected workspace writes | A synthetic task-log event wrote outside its workspace through a symlinked runs directory. | Step 3 |
| SEC4 — invalid enforced verdict | An unknown verdict returned exit 0 with enforcement enabled. | Step 4 |

These are local reproductions, not evidence of an actual compromise. Exact-output review binding is additional hardening justified by the current latest-file selection; no concurrent-review exploit was reproduced during the original review.

## Implementation sequence

- [x] **Step 1 — Replace configuration interpolation with a safe launcher.** P1; AC1, AC2, AC6. Add a dependency-free Node launcher under `skills/ai-layout/templates/ai-factory/make/` and make `ai.mk` a thin entry point. The launcher reads configuration as data, validates the supported tool and existing task selection, and invokes the CLI with `spawn`/`execFile` argument arrays and `shell: false`. Feed prompts through stdin. Audit MODEL, TOOL, TASK, INPUT_FILE, executable selection, generated filenames, and logging calls, not just the reproduced model value. Do not interpolate raw values into the Make recipe or assume double quotes neutralize shell substitution. Preserve intentional trusted executable overrides as an executable path, not a shell fragment; handle model inheritance and provider aliases without adding a YAML package. Use explicit validation for the supported configuration syntax. Create private per-run scratch under `ai-factory/runs/tmp/`, validate output ancestors, and pass the run's exact output identity forward. Add `skills/ai-layout/scripts/check-runner-security.sh` with fake Claude/Codex executables. **Verify:** literal malicious-looking arguments never create sentinels, both CLI argument layouts are correct, ordinary input remains byte-correct, invalid selections fail before launch, paths with spaces work, and failed/interrupted/concurrent runs do not share or leak scratch. Reproduce the old defect first, then finish this step with its checks green.

- [x] **Step 2 — Resolve the repository and enforce its actual protection policy.** P1; AC3, AC4. Update `skills/ai-hooks/scripts/_common.js` and `guard-paths.js` to resolve the current Git repository/worktree from nested cwd without crossing its boundary. Preserve the documented no-layout no-op and transitional layout behavior. Resolve existing target ancestors and symlink destinations before applying protection rules, including a not-yet-created target below an existing parent. Parse the documented prefix syntax explicitly; report invalid rule entries, missing/unreadable policy, and an absent target on a guarded mutation as actionable failures in an adopted repo. Support the spec's explicit empty-policy marker. Keep blocker diagnostics on stderr and exit 2; never print hook content to stdout. Add `skills/ai-hooks/fixtures/check-guard-security.sh`. **Verify:** direct and aliased protected targets, nested cwd, worktree `.git` files, new paths, sibling isolation, bad/missing policy, explicit empty policy, unadopted repos, and ordinary allowed edits. Observe symlink behavior on the supported platforms rather than assuming path-string normalization is enforcement.

- [x] **Step 3 — Apply safe write rules to every hook and runner artifact.** P1; depends on Steps 1–2; AC5, AC6, AC10. Add a small reusable path/write helper in `skills/ai-hooks/scripts/` and a self-contained counterpart or generated copy in the adopted runner payload; fixture checks must prevent divergence without making adopted code import from an unavailable plugin path. Audit every writer: session/task/edit/command logs, usage claim ledgers, pending/final logs, schema rotation, flush, and runner prompt/diff/output files. Validate or safely encode event-derived filename components; reject traversal and symlinked mutable workspace/output ancestors. Use private permissions, exclusive creation where appropriate, no-follow operations where available, and validated atomic replacement where needed, preserving append-only accounting semantics. Unsafe logging must decline the write and report a concise diagnostic; a guard-policy failure still blocks the edit. Replace dynamic shell-based Git calls with argument arrays where applicable. Add `skills/ai-hooks/fixtures/check-write-boundary.sh`. **Verify:** directory and file symlinks, unsafe identifiers, external sentinels, pre-existing files, partial failures, concurrent writes/runs, and cleanup. Rerun accounting/schema fixtures to prove no lost or duplicated normal rows. Document residual race assumptions; do not claim leaf no-follow flags solve ancestor races.

- [x] **Step 4 — Validate and bind each enforced review.** P1; depends on Steps 1 and 3; AC7, AC8. Update `skills/ai-layout/templates/ai-factory/make/gate.js`, the launcher, and the `review` target. Parse the final review payload deterministically, validate the spec's schema, and return a diagnostic instead of accepting unknown verdicts or severities. In enforced mode, require valid approval and no blockers; missing/malformed output and `request_changes` fail. Keep advisory mode visibly separate and validate the enforcement setting itself. Feed the gate the exact current run's output and expected sidecar, never `ls -t` or a shared output filename. A failed CLI invocation cannot reuse an old successful report. Add `skills/ai-layout/scripts/check-review-gate.sh`. **Verify:** both supported output formats, approve/request_changes/blocker cases, unknown verdicts/severities, missing fields, invalid JSON, empty output, wrong-shaped findings, wrong/stale sidecars, failed invocations, and concurrent reviews. Include the previously reproduced invalid-verdict case. This step intentionally tightens enforced-mode behavior; preserve that fact in release notes.

- [x] **Step 5 — State and verify the host enforcement boundary.** P1; depends on Steps 2–4; AC9, AC10. Update `skills/ai-hooks/SKILL.md`, relevant template instructions, and `ai-factory/docs/workflow.md`/architecture documentation. Explain precisely which edit tools the guard covers, that shell writes depend on the host sandbox, and which runtimes actually register these hooks. Remove any claim that `dont-touch.md` alone protects arbitrary execution. Document existing host controls and explicit approval boundaries without changing the user's global settings or requesting blanket filesystem/network access. A missing enforcement capability must be reported honestly; do not add a command-string denylist as a substitute. **Verify:** before/after prompt transcripts for a blocked edit and a runtime without the hook; synthetic host checks where available. If a host sandbox cannot be exercised here, mark it unverified and limit claims to the tested environments. The independent code fixes need not wait for unavailable host integration tests.

- [x] **Step 6 — Run the complete security regression and package the change.** P1 completion gate; depends on Steps 1–5; AC1–AC10. Run all new security fixtures and the existing repository checks from a disposable checkout containing the implementation under ignored `ai-factory/runs/tmp/`. Keep fixture construction from copying its own scratch directory recursively. Confirm generated adapters are unchanged by a second generation where generation is supported and authorized; never hand-edit protected generated paths. Verify the installed-package/copy-of-workspace case with optional services absent, and preserve unrelated user changes. Record platform coverage, exact commands, before/after results, and remaining limitations under `ai-factory/runs/` using the sanctioned recording workflow. Update the changelog and all canonical manifests together at release time; coordinate the version with current 2.1.0/2.2.0 work rather than choosing a conflicting number now. State the stricter gate behavior, rejected symlinked write destinations, executable-override change, and adoption/restart requirements. **Done:** all reproduced defects fail safely, supported normal workflows pass, the full check suite is green, and no unresolved high-priority security defect is represented as fixed.

## Files and ownership

- Runner and gate source: `skills/ai-layout/templates/ai-factory/make/`.
- Hook source: `skills/ai-hooks/scripts/`; hook fixtures: `skills/ai-hooks/fixtures/`.
- Runner/review fixtures: `skills/ai-layout/scripts/`.
- Documentation: the relevant skill/template files and `ai-factory/docs/`; release records: existing changelog/manifests.
- Generated project work and evidence: `ai-factory/runs/`; temporary fixtures: its ignored `tmp/` subdirectory. Add narrowly scoped local ignore rules for the new scratch area as part of Step 1.
- Do not edit this repository's protected `ai-factory/tasks/`, `ai-factory/agents/`, or `ai-factory/make/` entries by hand; change their canonical sources. Do not modify the unrelated `state.sh` work.

There are no server/client components. The changes are local scripts and documentation, with no new runtime dependency. Follow the user's Biome preference for changed JavaScript using the available project tooling; do not add a package dependency solely to format this plan.

## Verification strategy

Each implementation step first reproduces its failure, then fixes it and finishes with the relevant checks green. Do not introduce a standalone red-test step that the current implementer cannot complete. Broader regressions run once at Step 6, except when an intermediate change gives a concrete reason to run them earlier.

The following security scripts now exist and pass; full results are in `ai-factory/runs/0011-verification.md`:

```bash
bash skills/ai-layout/scripts/check-runner-security.sh
bash skills/ai-hooks/fixtures/check-guard-security.sh
bash skills/ai-hooks/fixtures/check-write-boundary.sh
bash skills/ai-layout/scripts/check-review-gate.sh
```

At the final gate, run all checks directly, preserving failure status:

```bash
failed=0
for check in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do
  bash "$check" || failed=1
done
test "$failed" -eq 0
```

Also run `node --check` for changed JavaScript and `bash -n` for changed shell scripts. Before/after prompt transcripts prove changed instructions; string-presence tests do not. Fixture harnesses now default to temporary directories under `ai-factory/runs/tmp/`; the completed regression run used workspace-contained scratch.

## Reviewable delivery groups

1. Command execution: Step 1.
2. Filesystem protection: Steps 2–3.
3. Review enforcement and release verification: Steps 4–6.

Keep these groups independently understandable. Do not publish a security-complete claim until all six steps and the corresponding criteria are satisfied.
