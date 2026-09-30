# Plan 0011 — Make small tasks faster without weakening verification

**Status:** Done — all 12 steps completed; implementation, regression checks and behavior evidence are recorded.

**Goal:** Make the plugin self sufficient, contain all project work files in `ai-factory/`, and give small changes a short execution path with correct verification and review.

**Security implementation owner:** `ai-factory/plans/done/0012-plugin-security.md`, backed by `ai-factory/specs/0012-plugin-security.md`, now owns SEC1–SEC4 and the overlapping security portions of Steps 3, 4, 9, and 10 below. Their security descriptions remain analysis context, not duplicate implementation tasks. Complete that plan before performance optimization; reuse its launcher, path helpers, fixtures, and gate. This plan retains broader adoption/adapter containment, review diff selection, model-selection precedence, and efficiency changes. Where the earlier gate compatibility wording below differs, spec 0012 takes precedence: enforced mode requires a valid approval with no blockers, with the tightening explicitly documented at release.

**Spec:** `ai-factory/specs/0011-small-task-efficiency.md`

**Requirements source:** The user's request on 2026-09-29 to reassess the updated plugin and create an indexed improvement plan. This is a standalone proposal with acceptance criteria below; it does not implement spec 0010 or claim an existing feature spec covers these changes.

**Baseline:** Repository version 2.0.0, HEAD `0323d30`, plus the working-tree changes present when inspected. This was the planning baseline; checkboxes below now reflect the implementation evidence. Recommended policies are proposals, not descriptions of existing behavior.

**Planning-time recheck:** HEAD advanced to `9b7162b` while this plan was written: the existing Step 4 edits were committed, and plan 0010 Step 5 gained its prompt-to-script hand-off scope. The changed-file set remains confined to that work; none of the workflow/runner findings below was changed. At that planning-time recheck, only this new plan was untracked.


## Execution status — completed 2026-09-29 (America/Toronto)

All 12 steps and security prerequisite plan 0012 are complete in the working tree,
prepared as 2.3.0. All 20 repository check suites pass from an isolated snapshot.
Source JavaScript is formatted with Biome; JavaScript and shell syntax checks pass.
Nothing has been committed or published. See `ai-factory/runs/0011-verification.md`
for the check records, 30 approved model executions and limitations.

- Step 6: the quick enhancement, public-contract escalation and preservation of staged,
  unstaged and untracked user work pass their dedicated candidate controls.
- Step 7: documentation replays omit irrelevant fleet/architecture reads; the dedicated
  unchanged-failure control verifies bounded attempts and a reported blocker.
- Step 8: phased implementation, unexpected-regression refusal and expected-red
  test-authoring controls all pass for the candidate.
- Step 12: adapter, release and adoption checks pass. The enhancement replay reduces
  task procedures from six to one, with functional assertions passing for both variants.
  CLI process count is one for each variant; native UI interactions were not measured.
  Documentation median elapsed time is 82.30s baseline versus 49.13s candidate across
  three pairs, a narrow descriptive observation rather than a general speed guarantee.

All final candidate behavior controls pass. Baseline runtime failures, the dirty-worktree
baseline timeout and baseline workflow failures remain recorded and are excluded from
speed comparisons. Completion does not imply a security sandbox or untested host coverage.

## Workspace requirement added on 2026-09-29

The user requires a self-sufficient plugin and all work files in one directory, `ai-factory/`. This is now a foundational constraint, not a later cleanup. Steps 1–4 establish it; the original eight efficiency steps are now Steps 5–12. At planning time, no implementation step had started; execution is now complete as recorded above.

**Ownership contract:** the installed plugin supplies its program, templates, and registration metadata; `ai-factory/` owns all project-specific SDLC instructions, configuration, analyses, designs, specs, plans, decisions, reports, logs, caches, generated prompt inputs, and plugin-owned temporary files. Application source/tests remain in their normal project locations. Model/CLI installation, credentials, Git metadata, and host-managed transcripts are host facilities, not plugin work files to copy or relocate. Self sufficient means no required sibling repo, overlay plugin, tracker, knowledge service, package download, or developer-specific absolute path. Optional configured integrations remain optional; existing documented Node/Bash/Git/CLI prerequisites must be explicit.

**Entry-file policy:** Strict containment is the default, based on the user's “all work files in one dir ai-factory” instruction and authorization to run this plan. ADR 0009 records the decision. Existing host entry files are preserved; new external adapters require a separate explicit request. Core runner/status/report operations do not depend on generated root files. Native discovery is described only where the installed host actually supports it.

This does not require moving distributable plugin source directories (`agents/`, `commands/`, `hooks/`, `skills/`, `.claude-plugin/`) into the workspace. It also does not promise that the `ai-factory/` directory alone replaces an installed plugin and its host runtime. A portable, uninstall-the-plugin runtime would be a separate, stronger requirement.

## Planning-time reassessment after the new fixes

| ID | Finding | Evidence and disposition |
|---|---|---|
| F01 | Small behavior changes still have no explicit short route. | `skills/ai-layout/templates/ai-factory/AGENTS.md` prescribes the full loop; `tasks/chore.md` covers maintenance and `tasks/fix.md` covers bugs. Keep both existing commands; add a clearly bounded route for small enhancements. |
| F02 | Verification is not phase-aware. | `agents/tester.md` writes red tests for the plan's criteria; `agents/implementer.md` and `tasks/run.md` require green tests for every step. A test-only red step or an early implementation step can conflict with that requirement. This is a prompt contradiction, not a measured runtime failure. |
| F03 | Required context and repeated checks are too broad. | The template's “Read before working” includes architecture and fleet for every task. Chore, fix, and each implementation step request lint, typecheck, and tests without defining scope. |
| F04 | Pre-commit review can miss the actual change. | `tasks/check.md` reviews merge-base through HEAD, and `agents/reviewer.md` says to use it before committing. Staged, unstaged, and untracked work is absent from that range. `make review` likewise supplies a committed branch diff. |
| F05 | The advertised review model setting is unused by the headless runner. | `models.yaml` has `review:`, but `make/ai.mk` selects only the key named by `TOOL`; `make review` invokes `TASK=check` without selecting `review:`. All interactive agents also inherit the session model, which is a valid default, not itself a bug. |
| F06 | The release gate fix is useful, with one residual false positive. | Commit `b9410ad` correctly binds migration assertions to the 2.0.0 entry rather than the newest release. Its commit notes acknowledge that `hooks[^.]*(accept|keep)[^.]*(guard|log)` can match unrelated accounting prose; the self-tests use a purpose-built record rather than removing the intended sentence from the actual release text. |
| F07 | Timing evidence is still missing. | The current 17-column log measures tokens/turns, not task durations. Earlier local microbenchmarks suggested small no-op hook costs, but they are not end-to-end measurements and were not rerun for this reassessment. Do not infer a speedup from token counts alone. |
| F08 | Setup creates more than the declared workspace directory. | `commands/adopt-sdlc.md` copies the entire template root; `make/sync-adapters.sh` unconditionally generates all three tool directories. ADR 0008 says only three root entry files remain, which is not the full current footprint. Make adapters optional and document the real boundary. |
| F09 | Adopted agent instructions are incomplete. | `templates/ai-factory/agents/*.md` say “Follow the ai-sdlc … instructions exactly” plus a summary, without embedding or resolving the full canonical agent. For example, the reviewer template is 445 bytes versus 2,343 bytes for `agents/reviewer.md`. Codex adapters point to the local summary, so the required full procedure is not explicitly supplied by that route. Resolve full instructions deterministically; do not depend on model memory or assumed prompt inheritance. |
| F10 | Temporary work and Git policy escape the directory. | `make/ai.mk` uses bare `mktemp` for prompt input. Adoption appends workspace ignore/attribute rules at the repo root. Put plugin-owned scratch under `ai-factory/runs/tmp/`, and scope workspace Git rules with `ai-factory/.gitignore` and `.gitattributes`. Host-created transcript storage is outside this contract. |
| F11 | Generic setup assumes an application stack and can collide with existing files. | The root Makefile template hardcodes `pnpm lint`, `pnpm test`, and `pnpm e2e`. Adoption says to copy all templates to the repo root before saying to create root instruction files only if absent. The copy operation's collision behavior is unspecified. Use an explicit non-overwriting file plan, detected commands, and an internal runner entry point; do not replace an application's Makefile. |


Changes already present, which this plan must not redo:

- Release validation now permits an ordinary newer release while preserving the historical migration assertions. `bash skills/ai-layout/scripts/check-release-docs.sh` passed during this reassessment.
- The new `state.sh` provides a deterministic, read-only default listing. `bash skills/ai-layout/scripts/check-state.sh` passed all nine reported sections, including the working-tree test additions.
- Plan 0010 steps 1–4 are ticked in the inspected worktree; flag support and release work remain with that plan. Do not duplicate or modify those steps here.
- Usage attribution, per-agent rows, incremental accounting, and `make cost` already exist. Missing duration measurement does not mean those features are absent.

## Planning-time security reassessment — confirmed with synthetic fixtures

**Conclusion:** this plugin is workflow automation, not a security sandbox. Its guard and review gate at the planning baseline were insufficient as security boundaries; plan 0012 resolves the reproduced defects. Fix the findings below before claiming secure containment; a single directory name does not enforce containment.

| ID | Priority | Confirmed behavior | Exposure and remediation |
|---|---|---|---|
| SEC1 | P1 | A model value containing shell command substitution created a harmless marker when the real `ai.mk` ran against a fake CLI. | An attacker-controlled `models.yaml` can execute shell commands with the runner's existing permissions. Do not interpolate configuration into shell program text; pass model values through a data channel into a quoted variable or an argument array. Inspect TASK, TOOL, INPUT_FILE, and other interpolated fields as part of the same boundary. Covered by Step 10, now a security prerequisite. |
| SEC2 | P1 | The guard blocked a directly protected path with exit 2, but returned 0 for a symlink alias, a nested cwd, and a missing rules file. | Protection can silently disappear or be bypassed. Resolve the repository root and canonical target/parent paths, diagnose missing or malformed policy in adopted repos, and fail closed for protected mutations. No-layout repos must remain a deliberate no-op. Hook registration only guards Edit/Write/MultiEdit; arbitrary Bash writes are outside it. Do not claim a complete shell sandbox or attempt to build one with command-string matching. Host permissions must constrain arbitrary execution. Covered by Steps 3–4. |
| SEC3 | P1 | A normal task-log event wrote outside the fixture's `ai-factory/` after its runs directory was symlinked elsewhere. | Repository-controlled symlinks can redirect hook writes within the host process's filesystem permissions. Validate workspace and output ancestors, constrain event-derived filenames, and use suitable no-follow/atomic file operations rather than a lexical prefix check alone. Include race assumptions and platform limits explicitly. Covered by Steps 3–4. |
| SEC4 | P2 | `gate.js` exited 0 for `verdict: invalid-verdict` with `GATE_ENFORCE=1`. | Parseable output is not a valid verdict. Validate the verdict/findings schema and reject invalid or missing results in enforced mode. Keep the existing blocker-only versus advisory policy explicit rather than silently inventing an approval requirement. Covered by Step 9. |

Tests used synthetic files, a fake model CLI, and harmless markers; no real credentials, network calls, or model requests were used. Fixtures were created under `ai-factory/` and removed afterward. The existing runner exercised its current temporary-file behavior. SEC1 was proved for the Claude argument branch; the analogous Codex interpolation was inspected, not separately executed. SEC2's Bash gap follows from hook registration; it was not tested by modifying a real protected file. These results establish local defects, not evidence of an actual compromise or a complete penetration test.

## Proposed acceptance criteria

| ID | Observable outcome |
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



## Indexed implementation steps

- [x] **Step 1 — Define and record the workspace contract.** Priority P1; covers F08–F11, AC10–AC13. Record a focused ADR under `ai-factory/adr/` defining plugin package versus mutable project workspace, the entry-file policy once answered, and the exact allowed-write set. Clarify ADR 0008 with a new decision rather than silently rewriting the accepted record. Inventory adoption, sync, hooks, runner, tracker setup, and reporting paths. Update the relevant template/repository instructions and architecture docs together. No application source paths move. **Proof:** every current write destination is classified; unknown destinations are reported, not granted a blanket exception; the entry-file choice is explicit before implementation of external pointers.

- [x] **Step 2 — Make adopted instructions complete and stack-neutral.** Priority P1; depends on Step 1; covers F09, F11, AC11, AC12. Adopt full agent procedures under `ai-factory/agents/` with a distinct project-additions section, generated from canonical plugin instructions rather than maintaining two independently edited copies. Adapt manifest/drift tracking to account for the actual delivered content and preserve local additions on update. Give the local runner an internal entry point, usable without a root Makefile; recursive review invocations must preserve that entry point. Remove hardcoded pnpm commands from the generic scaffold and use detected or explicitly configured project commands. Define behavior for unavailable checks without claiming success. **Proof:** isolated Node, Python, and non-application fixtures receive no inappropriate stack commands; local agent instructions include the full procedures; a fake CLI proves headless invocation and recursive review work with no root Makefile. Native hooks remain plugin-owned and runtime capability differences remain explicit.

- [x] **Step 3 — Contain scratch, Git rules, and adapter generation.** Priority P1; depends on Steps 1–2; covers F08, F10, F11, AC10, AC12, AC13. Replace bulk root copying with a collision-safe adoption manifest. Put private temporary prompt/diff files in a unique per-run directory under `ai-factory/runs/tmp/`, with cleanup traps for success, failure, and interruption; retain intentional reports under `ai-factory/runs/`. Add local `.gitignore` and `.gitattributes` files with directory-relative patterns, and update tracker setup to use local ignores. Make adapters opt-in per selected tool under the agreed entry-file policy; keep behavioral instructions canonical inside `ai-factory/`. Ensure hooks and helpers reject accidental path escape through generated names or symlinked output directories. Migration must preserve hand-authored root files and remove only positively identified obsolete generated entries. **Proof:** before/after filesystem snapshots for adoption/sync/run/report/failure show only allowed writes, concurrent fake runs do not share scratch paths, `git check-ignore` and `git check-attr` confirm nested rules, and a pre-existing root Makefile is byte-identical afterward.

- [x] **Step 4 — Prove isolation before optimizing the workflow.** Priority P1; depends on Steps 2–3; covers AC10–AC13. Add a focused ownership/isolation fixture under `skills/ai-layout/scripts/`, with its generated repositories and outputs under ignored `ai-factory/runs/tmp/`. Exercise only the installed plugin plus the copied workspace and documented prerequisites, with external integrations unconfigured and sibling repos unavailable. Verify local instruction resolution, runner, status, report, sync policy, and hook behavior in the runtimes that support those hooks. Do not claim Codex supports Claude hooks. Update existing fixture harnesses so their own generated work also follows the directory policy. Keep runtime behavior checks separate from before/after prompt transcripts. **Proof:** containment assertions pass for normal/error/interrupted paths; scratch cleanup leaves retained evidence only under `ai-factory/runs/`; no command repairs itself by looking up a developer checkout. Full-suite validation is still consolidated in Step 12.

- [x] **Step 5 — Capture a small representative baseline.** Priority P1; depends on Steps 4, 9, and 10; covers F07 and AC8. Security fixes precede benchmark-driven optimization. Add `ai-factory/docs/small-task-benchmark.md` with reproducible scenarios: a documentation-only correction, a one-function bug, a small enhancement, a two-step feature with expected red tests, and a pre-commit review containing staged/unstaged/untracked changes. Use disposable fixture repos under ignored `ai-factory/runs/tmp/` and the same model, runtime, inputs, and verification commands before and after. Record total elapsed time and human waiting separately where available; mark unavailable phase timings explicitly. Record at least three comparable runs for scenarios used to claim a speedup, reporting median and range. Do not change the usage CSV schema or introduce permanent hook telemetry just to establish this baseline. **Proof:** recorded runs and their outputs; no wall-clock assertion in CI. Save benchmark records and exported evidence under `ai-factory/runs/` through the allowed recording workflow; host transcript links may supplement, but must not be the sole copy of required work records.

- [x] **Step 6 — Add a bounded small-change route.** Priority P1; depends on Step 5; covers F01, AC1, AC2, AC9. Proposed command: `/t4:quick <change>`, implemented as `skills/ai-layout/templates/ai-factory/tasks/quick.md`, so supported host registration can expose it under the selected entry-file policy. If strict containment is chosen, provide a supported installed-plugin entry point or explicit invocation rather than generating forbidden project adapters. Keep `/t4:chore` limited to maintenance and `/t4:fix` focused on bugs. Update template and repository `AGENTS.md`, template definition of done, and workflow routing together: a quick task records a short acceptance checklist in its report, implements the requested change, runs relevant verification, and performs a self-review in the same session. Behavior changes still need meaningful regression evidence. Escalate when the named risks emerge, preserving work and explaining the unresolved decision; do not demand extra paperwork solely for crossing a file-count threshold. Remove “Reset the working tree between steps” from the template and replace it with inspecting and preserving existing changes. **Proof:** before/after prompt runs for a safe enhancement, a public-contract change, and a dirty worktree; adapter mechanics are verified in Step 12, not by assertions pretending to prove model behavior.

- [x] **Step 7 — Make reading and investigation proportional.** Priority P1; depends on Step 6; covers F03, AC3. Update the template's reading rules, the repository's own instructions, and affected task/agent prompts so they agree: load applicable constraints first; architecture when placement is uncertain; fleet for cross-service work; named specs/plans when the selected workflow requires them. Avoid rereading unchanged content already available in the current context. Preserve the existing knowledge-source eligibility rules. For quick/chore/fix, require a new hypothesis or new evidence before repeating a failed check; after two attempts with the same failure and no new evidence, report the blocker with work preserved rather than retrying indefinitely. This does not impose a time limit on useful investigation. Keep reports to changes, verification, and unresolved concerns, without repeated plan narration. **Proof:** run transcripts show fewer irrelevant reads and no unchanged failure loop; a relevant project restriction is still observed.

- [x] **Step 8 — Separate red, step, and final verification.** Priority P1; depends on Step 7; covers F02, F03, AC4. Update `agents/planner.md`, `agents/tester.md`, `agents/implementer.md`, `tasks/plan.md`, `tasks/test.md`, `tasks/run.md`, `tasks/fix.md`, `tasks/chore.md`, and both definitions of done consistently. Plans name the verification phase and exact commands per step. Prefer red tests scoped to the next implementation step. When future-step tests already exist, record their test identities and expected failures before implementation; a failure outside that baseline remains a regression. Never skip tests, loosen assertions, or claim the whole suite is green. Pure docs changes use applicable checks without inventing runtime tests; JavaScript changes use Biome where configured, plus relevant fixtures. Run the complete required checks once at feature completion, and repeat affected checks after subsequent edits. **Proof:** a two-step feature completes Step 5 without implementing Step 6, an unexpected failure blocks it, a red test-authoring step is reportable as complete, and final completion fails while any required behavior remains red.

- [x] **Step 9 — Review the intended diff once.** Priority P1; depends on Step 4; independent of Steps 6–8; covers F04, AC5. Update `tasks/check.md`, `agents/reviewer.md`, and `make/ai.mk` to define working-tree, branch, and supplied-input scopes. Default interactive pre-commit review to local changes; retain an explicit committed-branch scope for CI. Include relevant non-ignored untracked content without staging it or reading ignored secrets. Report paths and scope, explain an empty selection, and honor supplied input rather than recomputing another range. For a small change without a spec/plan, review against the request and acceptance checklist. Preserve independent review when requested; label an inline self-review accurately. Add `skills/ai-layout/scripts/check-review-scope.sh` using disposable Git repos and a fake CLI, without contacting a model. **Proof:** staged, unstaged, untracked, committed-only, mixed, supplied-diff, and empty cases select the intended content, and a snapshot confirms index and worktree are unchanged. Pair mechanics fixtures with a prompt transcript proving the reviewer uses that selection. Fix SEC4 in `make/gate.js`: validate the result schema before enforcing it, and test invalid verdicts, malformed findings, missing results, and the documented valid blocker/advisory cases. This step also covers AC15.

- [x] **Step 10 — Honor the existing headless review model setting.** Priority P1; depends on Step 4; independent of workflow changes; covers F05, SEC1, AC6, AC14. Fix shell interpolation before treating model selection as a convenience feature. Change `skills/ai-layout/templates/ai-factory/make/ai.mk`, clarify `models.yaml` comments, and add `skills/ai-layout/scripts/check-model-selection.sh`. Implement the precedence in AC6 for both `make review` and `make ai TASK=check`; preserve a command-line `MODEL=...` override and blank-value inheritance. Keep interactive agents on `model: inherit`; automatic cheap-model routing is deferred until there is evidence it preserves quality. **Proof:** fake Claude/Codex executables record arguments for each precedence case, blanks, and a gateway alias; no network or paid model call is needed. Quoting fixtures confirm model values cannot execute shell substitutions, including the reproduced SEC1 payload; inspect other interpolated settings for the same flaw.

- [x] **Step 11 — Close the release assertion's remaining false positive.** Priority P2; depends on Step 4; otherwise independent; covers F06, AC7. Extend `skills/ai-layout/scripts/check-release-docs.sh` with a mutation of the actual historical entry in a disposable copy: remove its intended old-layout compatibility statement while retaining the unrelated accounting sentences. Make that fail for the correct reason. Tighten the assertion to require the compatibility meaning in the relevant passage, while allowing line wrapping. Preserve the new version-bound lookup and its existing missing-entry/newer-release fixtures. **Proof:** the actual-text mutation fails, the original and wrapped text pass, and a nonbreaking newer release still passes. Keep this a focused validation fix; do not rewrite the changelog to satisfy a loose regex.

- [x] **Step 12 — Verify adapters, compare results, and document adoption.** Priority P1 completion gate; depends on Steps 1–11; covers AC1–AC15. Update command lists, README/workflow, adapter fixtures that assume twelve tasks, and adoption guidance for the quick route. Run the selected adapter mode twice in a disposable checkout under `ai-factory/runs/tmp/` containing the implementation and verify identical outputs; never hand-edit generated `.claude/`, `.cursor/`, `.codex/`, or the repository's symlinked task paths. Repeat Step 5's scenarios with matched conditions and publish measured differences and remaining limits. Run the complete required check suite once here. Resolve the release number against the branch state at that time, coordinating with plan 0010 and the already-announced 2.1.0 removal; do not invent or reserve a conflicting version in this plan. Update the canonical manifests and changelog together, describing template impact and pull-only adoption. **Proof:** mechanical checks pass, prompt transcripts demonstrate the intended behavior, simple-task invocation count is reduced, and no measured quality regression is left unexplained. If latency does not improve, report that result instead of claiming success.

## Files and boundaries

- The workspace contract and entry-file decision above govern every step, including benchmarks and fixture-generated files. Plugin implementation files are distributable source, not project work artifacts.

- Canonical task/template edits belong under `skills/ai-layout/templates/`; agent edits belong under `agents/`. The `ai-factory/tasks/`, `ai-factory/agents/`, and `ai-factory/make/` paths are symlinked/protected here.
- Repository policy updates belong in `ai-factory/AGENTS.md` and `ai-factory/docs/`; proposed mechanics fixtures belong in `skills/ai-layout/scripts/`.
- This work has no server/client component split: it changes prompts, adapter generation, and a local headless runner. No application UI, service, or new dependency is required.
- Preserve the existing edits to README, workflow docs, plan 0010, and `check-state.sh`; merge future edits against their current contents, not the baseline snapshot.
- A missing spec does not block authoring this user-requested improvement plan. If implementation will be driven through `/t4:run`, use the matching spec 0011; never point it at spec 0010.

## Verification commands for implementation

Run only affected checks during individual steps. Run these commands from a disposable checkout under ignored `ai-factory/runs/tmp/` containing the current implementation for the final gate, since several existing checks regenerate adapters in place:

```bash
bash skills/ai-layout/scripts/check-review-scope.sh
bash skills/ai-layout/scripts/check-model-selection.sh
bash skills/ai-layout/scripts/check-release-docs.sh
bash skills/ai-layout/scripts/check-state.sh
bash skills/ai-layout/scripts/check-adapters.sh
bash skills/ai-layout/scripts/check-versions.sh
bash skills/ai-layout/scripts/check-manifest.sh

# At the final gate, use this loop instead of individually repeating the checks above.
failed=0
for check in skills/ai-layout/scripts/check-*.sh skills/ai-hooks/fixtures/check-*.sh; do
  bash "$check" || failed=1
done
test "$failed" -eq 0
```

The review-scope, model-selection, and isolation fixture scripts are implemented and pass; exact results are recorded in the verification report. For any edited JavaScript or shell file, also run `node --check <file>` or `bash -n <file>` respectively; follow the user's Biome preference for JavaScript formatting/checks without adding a dependency solely for this Markdown plan. Prompt quality is proved by recorded runs, not string-presence assertions.

## Deferred until evidence justifies the cost

- Incremental transcript parsing, cached ledger reads, and hook-process consolidation: possible optimizations for large sessions, but no demonstrated dominant latency here.
- A new duration column or always-on timing hooks: design a separate compatible measurement contract if the small benchmark proves ongoing telemetry is needed.
- Automatic model downgrades or extra parallel agents for simple tasks: evaluate only after removing unnecessary phases and measuring quality.
- Completion of `/t4:state` flags: belongs to plan 0010.

## Historical checks performed while drafting this plan

Read-only inspection of current prompts, agents, adapters, runner, hook accounting, recent commits, and the existing working-tree diff. Both `check-release-docs.sh` and `check-state.sh` passed. No full suite, model benchmark, or implementation change was performed during that drafting stage. Completed implementation validation is recorded in the execution status and verification report above.

The later security reassessment confirmed SEC1–SEC4 with disposable synthetic fixtures; no production code was changed.

The containment reassessment also inspected adoption, template agents, package boundaries, scratch paths, and Git policy. No files were moved and no adapters or hooks were changed. The default entry-file choice is now strict containment; optional external pointers require a separate explicit request.
