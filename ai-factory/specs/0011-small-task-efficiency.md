# Spec 0011 — Self-contained workspace and proportional task execution

**Summary:** Implement the user-approved goals in plan 0011: keep plugin-owned project work in ai-factory/, deliver complete procedures, and scale workflow effort to the change.

**Security dependency:** Spec/plan 0012 owns security fixes. Reuse those mechanisms; this spec does not duplicate or relax them.

## Workspace policy

Strict containment is the default, following the user's request. Preserve existing external
entry files; create optional host adapters only on a separate explicit request. ADR 0009
records ownership, supported exceptions and the allowed-write inventory. Installed plugin
source and host prerequisites remain separate from project work. All scratch and evidence
belongs under ai-factory/runs/. Application source and tests remain in their normal locations.

## Acceptance criteria

| ID | Required outcome |
|---|---|
| AC1 | A local, well-understood enhancement can be completed in one task invocation, with a short acceptance checklist, appropriate verification, and a final report; it requires no separate spec, plan, or agent merely because it changes behavior. |
| AC2 | Uncertain requirements or changes to authorization, public contracts, persistence/migrations, dependencies, or service boundaries use the existing deliberate workflow. File count is a hint, never the sole risk classifier. Explicit user selection of a workflow takes precedence. |
| AC3 | A small local task reads the applicable rules and affected code without automatically reading fleet, unrelated plans, or external knowledge. Required safety and project constraints remain applicable. |
| AC4 | Red test-authoring steps can complete on the documented expected failure. Implementation steps prove their own criteria and relevant regressions. Full completion requires the final required checks to pass; future-step failures cannot conceal new regressions. |
| AC5 | Review reports exactly what was reviewed. A default pre-commit review includes staged and unstaged changes plus relevant non-ignored untracked files. Branch review and supplied-diff review remain explicit alternatives. |
| AC6 | For headless review/check tasks, an explicit command-line model override wins, then a nonblank `review:` setting, then the tool setting, then CLI inheritance. Other tasks retain tool defaults. Values are treated as data, never evaluated as shell code. |
| AC7 | New-release validation stays independent of the historical migration record. Removing the intended compatibility statement from the actual historical text fails even when unrelated “hooks/guard/log” sentences remain. Equivalent wrapping does not cause a failure. |
| AC8 | Matched before/after runs record elapsed time, invocations, tool calls, verification runs, outcome, and available token counts. Claims distinguish measured improvements from hypotheses and disclose runtime/model/cache conditions. |
| AC9 | The selected runtime exposes the new route through its supported entry mechanism; where adapters are allowed, a second sync is unchanged. Adoption remains pull-only. Existing local work is preserved; no workflow instruction requests a destructive reset. |
| AC10 | All plugin-owned project work files, including scratch and reports, resolve inside the real `ai-factory/` directory. No required sibling repository, overlay, integration, personal absolute path, or new package installation is introduced. Authorized application changes are outside this SDLC artifact boundary. |
| AC11 | An adopted workspace contains complete executable task/agent instructions with explicit local references. An isolated fixture with the installed plugin and standard prerequisites, no sibling repositories, and integrations absent can run the core workflows without fetching missing instructions. |
| AC12 | Adoption preserves pre-existing root files and tool configuration. Core runner/status/report operations work with no generated root Makefile or tool adapters. Any external pointers require the selected entry-file policy and contain no unique work content. |
| AC13 | A path-ownership fixture proves allowed writes, including failure and cleanup paths. Workspace ignore/attribute rules cover local caches and append-only logs without root-file edits. Existing files outside the boundary are migrated or removed only when ownership is proven and their contents are preserved. |
| AC14 | Configuration values cannot execute shell syntax. Path and hook fixtures cover symlink escape, nested cwd, missing/malformed policy, generated filenames, and no-layout behavior; documented enforcement scope accurately identifies the host sandbox as the boundary for arbitrary shell execution. |
| AC15 | In enforced mode, invalid verdicts and malformed findings fail the review gate. Valid blocker/advisory behavior remains compatible and explicitly documented. |

## Scope

Workspace adoption, complete agent payloads, explicit optional adapters, relevant context
loading, the quick task route, phase-aware verification, correct review scope, review model
selection, release documentation checks, and reproducible measurement. No new dependency,
service, automatic model downgrade, destructive workspace reset, or required integration.

## Verification

Use real filesystem/Git/fake-CLI fixtures for mechanical behavior. Record actual model runs
for prompt behavior and end-to-end timing; never present fake CLI timing as model latency.
The final report distinguishes implementation, mechanical validation and unverified claims.

## Open questions

None blocks implementation. No automatic speedup claim is authorized without measurements.
The security gate uses spec 0012's stricter enforced-approval policy where earlier plan text
described blocker-only compatibility.
