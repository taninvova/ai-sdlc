# Spec 0012 — Secure plugin execution and workspace writes

**Summary:** Fix the four security defects reproduced during the 2026-09-29 review: shell interpretation of model configuration, bypassable path protection, symlink-directed hook writes, and acceptance of invalid enforced review verdicts.

**Source:** The user's security review and request for a remediation plan. This spec defines the proposed implementation contract; it does not claim any fix is already shipped.

## Scope and trust boundary

- Use Node's standard library and existing Bash/Git/CLI prerequisites. No new package, service, overlay, sibling repository, or developer-specific path is required.
- All plugin-owned project scratch, generated inputs, logs, and evidence belong under `ai-factory/`. Authorized application code and test changes remain in their normal directories. Installed plugin source and host-owned credentials/transcripts are separate facilities.
- Treat configuration values, selected task names, hook fields, repository paths, and model output as data requiring validation. Repository instructions are not permission to escape the host's sandbox.
- Installed plugin code, the selected executable, and intentionally executed application/test scripts must still be trusted. This work cannot make a hostile Makefile safe to execute or replace an OS/host sandbox.
- The path guard covers registered file-edit tools. Arbitrary shell writes require host enforcement; no regex-based shell firewall or unsupported cross-runtime hook guarantee is in scope.

## Acceptance criteria

| ID | Given / When / Then |
|---|---|
| AC1 | Given a model setting containing dollar substitution, backticks, quotes, spaces, or shell metacharacters, when either supported headless CLI is invoked, then the value is passed as one literal argument or rejected before launch; it never executes a second command. |
| AC2 | Given a task/tool selection, executable override, or input-file argument, when the runner prepares execution, then it validates the selection and passes values through argument arrays/data channels, without evaluating shell fragments or constructing traversable task paths. Missing required inputs fail before invoking the model. |
| AC3 | Given an adopted Git repository or worktree and a protected edit, when the hook runs from the repository root or a nested directory, then the same policy applies. A symlink alias cannot make a protected destination writable. Discovery never crosses the current repository/worktree boundary into another project. |
| AC4 | Given an adopted repository with missing, unreadable, or malformed protection rules, when a guarded mutation is requested, then it is blocked with a useful stderr diagnostic. An explicitly valid empty policy is distinguishable from a broken policy. A genuinely unadopted repository remains a no-op. |
| AC5 | Given a hook/runner output path with traversal, unsafe event-derived names, or symlinked workspace/output ancestors, when it attempts a write, then it refuses the unsafe destination without modifying the external sentinel. Normal supported paths still work. |
| AC6 | Given two simultaneous runs, CLI failure, or interruption, when scratch files are created and cleaned up, then each run uses its own private directory under `ai-factory/runs/tmp/`; cleanup affects only that run. Interrupted runs cannot be reported as successful. |
| AC7 | Given an enforced review, when output is absent, unparseable, schema-invalid, has an unknown verdict/severity, requests changes, or contains a blocker, then the gate returns nonzero. Only a valid `approve` verdict with no blockers passes. Advisory behavior is clearly labeled and never calls invalid output an approval. |
| AC8 | Given concurrent reviews or older saved runs, when a review is gated, then only the exact output produced by that invocation is used; selecting the latest filename or accepting a mismatched sidecar cannot substitute another review. |
| AC9 | Given a runtime lacking the required hook or filesystem enforcement, when setup/diagnostics describe protection, then they state the limitation accurately. No command silently disables the host sandbox, bypasses approval controls, or installs broad permissions to make work succeed. |
| AC10 | Given a fresh isolated fixture with the documented prerequisites, when core runner/hook/gate checks execute, then no external integration, package download, or sibling repository is accessed. Filesystem snapshots and sentinel checks confirm the promised write boundary. |

## Defined behavior and compatibility

- Enforced review means `GATE_ENFORCE=1`; unset or `0` selects advisory mode. Reject other values with a configuration error. Requiring approval in enforced mode is an intentional tightening of the existing blocker-only gate and must appear in release notes.
- Verdicts are `approve` or `request_changes`. Findings are an array of objects with known severity (`blocker`, `major`, `minor`), string file/issue/suggestion fields, and a nonnegative integer line. Summary is a string. Missing required fields are invalid; harmless unknown fields may be ignored for forward compatibility.
- Guard-policy parsing preserves the current documented prefix rules. Add an explicit empty-policy marker, proposed as `<!-- t4:allow-empty-policy -->`, rather than silently interpreting malformed rules as no restrictions. Explain invalid rules without exposing sensitive file contents.
- Reject symlinked mutable workspace/output directories by default. For guarded application paths, resolve existing ancestors so an alias cannot hide a protected target, including targets not created yet. Preserve safe existing source symlinks only when their resolved destination is allowed by policy and the host boundary.
- No-follow flags on a leaf file do not protect its ancestors. Describe supported platform behavior and residual concurrent-mutation assumptions; retain the host sandbox as the boundary against a hostile local process racing path checks.
- Retain documented transitional layout compatibility until its scheduled removal. Do not use this security change to remove unrelated compatibility paths.
- Preserve model inheritance, normal aliases, explicit executable selection, user input fidelity, usage accounting, and existing local files. Shell-fragment executable overrides become unsupported; explain how to select a trusted executable instead.

## Out of scope

Performance routing, automatic model downgrades, moving application files, a custom shell sandbox, arbitrary Makefile safety, host transcript relocation, automatic external integration changes, and the strict-versus-pointer adapter decision in plan 0011.

## Open questions

None blocks the security implementation. Release numbering must be resolved from the release branch at packaging time; plan 0010 currently reserves 2.2.0 after its 2.1.0 prerequisite. Host/platform enforcement claims must be backed by actual verification, with unsupported cases reported explicitly.
