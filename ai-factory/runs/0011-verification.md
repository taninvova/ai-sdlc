# Plan 0011 implementation evidence

Completed 2026-09-29 (America/Toronto); final regression record timestamp: 2026-09-30T00:31:26.775350+00:00. Working-tree release: 2.3.0. No commit, push or publication performed.

## Delivered

- Strict adoption creates only ai-factory/ and preserves root files; external adapters are explicit opt-ins with collision and ownership checks.
- Complete adopted agent procedures, stack-neutral command detection, local Git rules and a root-Makefile-independent runner.
- Quick route, proportional context, phase-aware verification, exact review scope and model precedence.
- Safe argv launcher, canonical edit guard, shared safe writers/accounting lock, schema-valid review approval bound to the exact output.
- Focused historical release-assertion fix and consistent adoption/host-boundary documentation.

## Deterministic validation

All 20 repository check suites pass in a disposable snapshot. Platform: macOS-26.6.2-arm64-arm-64bit-Mach-O. Synthetic security cases use harmless sentinels and fake CLIs; they do not measure model quality.

JavaScript syntax: 23 modified/new source files pass. Shell syntax: 21 files pass. Biome 2.5.14 formatter validation passes for all 23 JavaScript source files. git diff --check passes. Canonical agent payload generation matches.

| Check | Result |
|---|---|
| `skills/ai-layout/scripts/check-adapters.sh` | PASS |
| `skills/ai-layout/scripts/check-cost.sh` | PASS |
| `skills/ai-layout/scripts/check-doctor.sh` | PASS |
| `skills/ai-layout/scripts/check-entrypoints.sh` | PASS |
| `skills/ai-layout/scripts/check-manifest.sh` | PASS |
| `skills/ai-layout/scripts/check-model-selection.sh` | PASS |
| `skills/ai-layout/scripts/check-paths.sh` | PASS |
| `skills/ai-layout/scripts/check-release-docs.sh` | PASS |
| `skills/ai-layout/scripts/check-review-gate.sh` | PASS |
| `skills/ai-layout/scripts/check-review-scope.sh` | PASS |
| `skills/ai-layout/scripts/check-runner-security.sh` | PASS |
| `skills/ai-layout/scripts/check-state.sh` | PASS |
| `skills/ai-layout/scripts/check-versions.sh` | PASS |
| `skills/ai-layout/scripts/check-workspace.sh` | PASS |
| `skills/ai-hooks/fixtures/check-detect.sh` | PASS |
| `skills/ai-hooks/fixtures/check-guard-security.sh` | PASS |
| `skills/ai-hooks/fixtures/check-log-schema.sh` | PASS |
| `skills/ai-hooks/fixtures/check-subagent-stop.sh` | PASS |
| `skills/ai-hooks/fixtures/check-usage.sh` | PASS |
| `skills/ai-hooks/fixtures/check-write-boundary.sh` | PASS |

Exact outputs and platform metadata: [check records](plan-0011-verification/checks.json). The final full suite ran after the shared lock, manifest-symlink and adapter-hardlink fixes. Adapter and workspace checks were then rerun after correcting the reviewer discovery description to match the working-tree default. Run this suite only in a disposable snapshot: the adapter fixture intentionally generates host pointers.

```bash
for check in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do
  bash "$check" || exit 1
done
```

Security coverage includes 36 guard cases, 62 writer-boundary cases and 26 workspace cases, symlink/hardlink refusal, unsafe IDs, nested cwd, absent/bad policy, literal configuration payloads, interrupted/concurrent runners, shared hook/runner locking, exact sidecars, malformed verdicts and existing accounting compatibility. Plan 0012 records the four original synthetic reproductions; the current regression fixtures establish that those inputs now fail safely.

## Real model runs

The user explicitly approved 14 initial calls, six replacements and ten final controls: 30 real executions total. The initial 20 calls finished with exit 0 and no timeout; the final dirty-worktree baseline timed out at 150 seconds. Not all executions passed their quality assertions. Functional assertions remain distinct from CLI exit status. Runtime: codex-cli 0.155.1, gpt-6-astra/high, configured headroom provider, Node v22.21.1. Two concurrent jobs; cache state and inherited user context were uncontrolled. Human waiting and internal phase timing are unavailable.

Initial records: [small-task-benchmark-2026-09-29T17-25-02-260Z/summary.md](small-task-benchmark-2026-09-29T17-25-02-260Z/summary.md). Exact prompts, snapshots, events, available token fields, final responses and diffs are retained alongside the summary.

| Documentation replay | Runs | Median | Range | Tool calls |
|---|---:|---:|---:|---|
| baseline | 3 | 82.30s | 79.64–95.34s | 29, 15, 16 |
| candidate | 3 | 49.13s | 41.83–63.93s | 13, 10, 11 |

Both variants corrected the exact requested text and preserved application code. Baseline documentation runs read fleet/architecture documents; candidate runs omitted those irrelevant reads. This is narrow descriptive evidence from three synthetic pairs, not a general latency guarantee or a cache-controlled causal estimate.

The initial bug pair passed functional and reverted-code regression assertions in both variants. Some delegated enhancement, phased-work and review runs failed at the CLI subagent boundary (`no thread id`). Those are preserved as runtime failures and excluded from speed comparisons.

Replacement records: [small-task-benchmark-2026-09-29T17-34-13-577Z/summary.md](small-task-benchmark-2026-09-29T17-34-13-577Z/summary.md). The replacements explicitly use documented Codex inline-agent mode, which executes the named procedure in the same session. It is not independent review.

| Inline replacement | Baseline | Candidate | Interpretation |
|---|---|---|---|
| enhancement | PASS | PASS | Both implement the behavior and add tests that fail when the implementation is reverted. Baseline follows the six-stage workflow; candidate uses quick. |
| two-step | FAIL | PASS | Baseline implements Step 1 but leaves it unticked under its all-green rule. Candidate passes and ticks Step 1 while preserving the known failing Step 2. |
| review | FAIL | PASS | Baseline default branch scope misses local defects. Candidate reports staged, unstaged and untracked defects and preserves the files/index. |

Single replacement pairs establish only these functional observations. They do not establish a reliable speedup. Some model reports note Biome is unavailable inside the dependency-free fixtures; their make lint/typecheck targets are syntax checks only. Formatter validation of the actual plugin source was performed separately with the available Biome binary. The enhancement replay follows six baseline task procedures (`spec`, `plan`, `test`, `run`, `test`, `check`) versus one candidate procedure (`quick`); both pass functional assertions. The baseline response confirms all six workflow stages. [Invocation evidence](plan-0011-verification/workflow-invocations.json) records task-procedure count 6 → 1 and CLI process count 1 → 1. Native UI interactions were not measured.

## Final behavior controls

The ten explicitly approved inline calls completed under
[small-task-benchmark-2026-09-30T00-26-38-593Z/summary.md](small-task-benchmark-2026-09-30T00-26-38-593Z/summary.md).
Exact per-assertion outcomes are in that directory's `records.json`, alongside prompts,
responses, raw events and diffs. All five candidate controls pass.

| Control | Baseline | Candidate | Observed candidate behavior |
|---|---|---|---|
| Public-contract escalation | PASS | PASS | Leaves production unchanged and reports the unresolved authorization/public-contract decision. |
| Dirty implementation worktree | TIMEOUT / FAIL | PASS | Implements and tests the enhancement while preserving staged, unstaged and untracked user notes. |
| Repeated unchanged failure | PASS | PASS | Bounds attempts, preserves the correction and immutable checker, and reports the infrastructure blocker. |
| Unexpected regression | PASS | PASS | Leaves the step unticked, preserves the failing assertion and reports the failure outside the recorded baseline. |
| Expected-red test step | FAIL | PASS | Writes a meaningful regression, records the expected failure and completes only the red step; production and the later implementation step remain unchanged. |

The dirty baseline preserved the user's notes but did not finish the enhancement within
150 seconds, after 93 tool calls. It is not a comparable speed result. The red baseline
wrote a valid regression but left its step unticked under the old all-green rule. The
harness also supplies the missing implementation temporarily and verifies that the new
red test passes, then restores production, so an arbitrary failing test cannot qualify.
These single control pairs establish behavior only, not reliable latency differences.

## Final self-review

Local integration self-review reproduced two additional unsafe writes: manifest creation
followed a symlinked `.sdlc.json`, and optional Claude adapter generation followed a hard
link into an external file. Each old implementation returned success where the new
regression required refusal. Manifest writes now validate the boundary before reading the
prior manifest and use the shared safe writer; adapter preflight rejects nonregular or
multiply linked targets. Both external-sentinel regressions pass, bringing the workspace
suite to 26 cases. The final 20-suite run passes after these fixes.

Reviewer discovery metadata now matches the working-tree default and canonical agent
materialization passes. This is a self-review with resolved findings and no remaining
identified blocker in the reviewed integration changes, not a fresh independent
whole-diff review.

## Completion and boundaries

Plan 0011 is Done with all 12 steps checked. Dedicated behavioral proof for Steps 6, 7
and 8 is complete. Step 12 records the measured task-procedure reduction and explicitly
distinguishes it from CLI and native UI counts. The following platform and methodology
limits remain:

- Live Claude hook integration and adversarial host sandbox behavior were not exercised. Direct hook fixtures and host registration inspection establish only the documented edit-hook coverage. Codex adapters do not register Claude hooks.
- Static unsafe write destinations are rejected. A concurrent hostile process swapping an ancestor still requires host sandbox enforcement; directory naming is not a sandbox.
- Accounting is serialized in supported normal/concurrent cases. Crash or disk exhaustion between usage claim and row append is not a transaction and may need manual reconciliation.
- macOS/Node/Bash coverage only; Linux and Windows host integration are unverified.
- Prior independent workspace review found metadata, preflight/ownership and instruction contradictions; those were corrected and covered by the relevant fixtures. Subsequent integration changes received local review and regression checks, not a claimed fresh independent whole-diff review.

## Adoption

Update the installed plugin and restart the host session. Inspect drift with /t4:sync-sdlc, then take the changed templates as a separate reviewed edit preserving project additions. Existing local runners are not updated automatically. Explicitly request only the host adapters wanted. The CHANGELOG describes the stricter approval gate, executable-only CMD override and refusal of redirected run directories.
