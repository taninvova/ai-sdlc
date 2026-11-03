# ASD-005 — Opt-in quality gate (Biome and Fallow)
Created: 2026-10-31T20:47:12.412Z

## Request
The request is the developer's "FC AI Factory — Quality Gate Integration Plan". It asks for an
opt-in quality gate on application code. Adoption and sync offer it, and in JS/TS repos it uses
Biome and Fallow. Deterministic tool runs, not the LLM, decide `passed`/`warned`/`failed`/`error`/`skipped`.
The result is recorded as evidence bound to a snapshot, and that evidence goes stale when the
code, the policy, the base or a tool version changes. The gate runs after each `/fc:run` step,
before `/fc:loop` ticks a step, in interactive `/fc:review` / `$fc-review`, and in headless
`make review`. A failed required check blocks the combined readiness even when the AI reviewer
approves. A new `quality-gate` agent explains findings but approves nothing and edits nothing.
Interactive runs prompt for the next action after every step. `ai-factory/` is never scanned,
formatted or reported. The request lists its file names (`quality.json`, `make/quality.js`,
`quality-scope.js`, `quality-policy.js`, `scripts/quality-setup.js`, `agents/quality-gate.md`)
as targets, not as existing code. It also asks for consent-gated edits to root `package.json`,
lockfiles, `biome.json`, `.fallowrc.json` and `.gitignore`.

## What exists today
- **Boundary.** `commands/adopt-sdlc.md` and `scripts/adopt.js` copy only `ai-factory/`. ADR 0009 and
  `docs/workspace-boundary.md` forbid adoption and ordinary sync from creating root files ("strict
  containment"). `architecture.md` says the base "never names, reads or version-pins" an overlay
  and carries "no stack-specific rules". ADR 0004 rule 1 says the plugin ships no package manager or
  lockfile. Coding standards say the plugin "adds no npm package". `adopt.js` `detect()` already reads
  `package.json` (`packageManager`, scripts `build|lint|typecheck|test|e2e`) and writes only text.
  The only optional step that adopt offers today is the knowledge seam (step 5), which defaults to skip.
- **Evidence already does most of the gate's work** (`make/contracts.js`, spec 0013, opt-in through
  `contracts/config.json`). Plan steps declare ``Verify (red|step|final): `cmd` ``. A command runs as a
  plain argv with no shell; metacharacters are refused at line 317. `contracts.js record` (`make verify`)
  writes evidence holding the `snapshot_sha256` of the tracked, modified and untracked files.
  `ai-factory/` is already excluded from that snapshot (line 541). The record also carries the
  statuses `passed`/`failed`/`unavailable` ("unavailable is never a pass") and the diagnostics
  `E_EVIDENCE_UNSTABLE` and stale-on-change. Review evidence is recorded the same way (`runner.js reviewEvidence`).
- **Loop barrier exists.** `make/loop.js finish` ticks a worktree step only after `make verify` for
  that step exits 0 (`verifyStep`, about line 1103). For main-tree steps, the implementer ticks the
  step as `/fc:run` does. Defaults: `max_parallel: 3`, with no per-step prompt, because spec 0022
  runs every unticked step and then one review.
- **Review.** `runner.js reviewInput()` builds the `working-tree` (staged, unstaged and untracked),
  `branch` (merge-base with main/develop) and `supplied` diffs. It excludes only the loop worktrees,
  not `ai-factory/`. `gate.js parseVerdict` plus `GATE_ENFORCE` / assurance `gate: enforced` decide
  approval. `check-review-gate.sh` and `check-review-scope.sh` cover this.
- **Policy.** `make/assurance.js` (spec 0021) gives `light|standard|strict` presets as minimums. It
  previews with `set` and writes only with `--apply`, which is the same consent pattern the request wants.
  `assurance.js complete` and `delivery-report.js` decide readiness. `make/lifecycle-events.js` records telemetry.
- **Not present:** any Biome or Fallow config or reference in the plugin, a quality policy, a
  quality agent, and any per-step interactive prompt. **Still unverified:** Biome 2 `!!`
  force-ignore and `fallow viz --out --no-open`.

### Fallow research (2026-10-31)
The developer supplied this research from fallow.tools and the GitHub repos fallow-rs/fallow and
fallow-rs/fallow-skills. It is *external and not checked against this repo*.
- **CLI.** MIT. A Rust binary built on Oxc, published as npm `fallow`. It is also available as cargo
  `fallow-cli`, a GitHub Action, a GitLab CI template, an MCP server and an LSP. It covers the JS/TS
  family and has 100+ framework entry-point plugins. Config lives in `.fallowrc.json` (`ignorePatterns`),
  with inline `fallow-ignore-*` comments and baselines. `fallow recommend` proposes a config without writing it.
- **`audit`, verified at v3.38.1 (schema_version 13).** `--base <REF>` defaults to the merge-base with
  upstream or origin/main. `--diff-file <PATH|->` keeps only findings on added lines.
  `--gate new-only` (the default) or `all`. `--worsened warn|error|off` (default `warn`; it does nothing
  under `all`). `--format` includes `json`, `sarif` and `gitlab-codequality`. The JSON `verdict` is
  `pass|warn|fail`. Exit codes: 0 for pass or warn, 1 for fail, 2 for a runtime error, which comes
  with `{"error":true,…}`. The docs recommend gating on the verdict or the exit code, not on finding counts.
  Without `--diff-file`, changed files come from `git diff <base>...HEAD`, which misses uncommitted
  and untracked work. That confirms the request's §6.1 need to synthesise the diff.
- **fallow-skills agent plugin (Claude Code and Codex).** A separate plugin. Its skills are `fallow`
  (audit), `fallow-review` (branch/PR review), `fallow-setup` (installs and configures Fallow and adds a
  CI gate, editing root and CI files at the agent's judgement), `fallow-cloud-setup` (uploads inventory
  and source maps to the paid Fallow Cloud) and `fallow-codex-onboarding`. It does not bundle or pin
  the binary. It is LLM-driven, so it is not deterministic.

## Options
**A. The plan as written, in base, as one delivery.** Adds the installer (`scripts/quality-setup.js`),
`quality.json`, `quality.js` with its scope and policy modules, the `quality-gate` agent, a loop state
machine with per-step prompts and serialised acceptance, the review gate, report changes and the Codex
mirrors. *Effort XL*: cross-cutting, and it needs ADRs that amend 0009 (root writes) and the
architecture's no-stack rule. *Risks*: it names and pins two third-party tools in every adopter's
templates. It also ships a second evidence format beside contracts evidence, and per-step prompts
break `/fc:loop`'s unattended design. It is hard to reverse once released.
*Later*: every other stack needs its own hard-wiring.

**B. Generic project quality checks in base, built on contracts evidence and phased.** The project
declares named checks as argv in one opt-in file. That file could be `ai-factory/quality.json`, or a
`quality` block in `contracts/config.json` beside `code_scope`. Each check carries `required`, a timeout
and the triggers it runs on. `contracts.js` records each run as evidence (phase `quality`), so the
existing snapshot, the `ai-factory/` exclusion, staleness and `unavailable`-is-not-a-pass rules apply.
A new `--diff-file` input reuses `reviewInput()`'s diff synthesis, with `ai-factory/` added to its exclusions.
`loop.js verifyStep` and `/fc:run`'s tick rule require that evidence. `runner.js review` records it
before the reviewer runs and passes its summary in. `gate.js` and `assurance.js complete` refuse
readiness while a required check is failed, errored or stale. Biome and Fallow ship as a
*documented preset* (the argv lines and the exclusion snippets), and the developer edits the root files.
The Fallow preset calls the pinned, project-local `node_modules/.bin/fallow audit` directly, as argv.
It maps exit 0 to `passed` when the verdict is `pass` and to `warned` when it is `warn`, exit 1 to
`failed`, and exit 2 or unreadable JSON to `error`. `--format gitlab-codequality` is a useful extra
output for the GitLab host (opinion).
*Effort*: the whole is XL (cross-cutting, plus an ADR on gate composition). It ships as L slices:
(B1) declare and record checks; (B2) the run/loop barrier; (B3) the review gate and report. The
explain-only agent (B4) is deferred or dropped in favour of the fallow-skills plugin; see the Recommendation.
*Risks*: tying quality to contracts opt-in, and whether `--diff-file` accepts the diff that
reviewInput builds. That diff has `## …` section headers between the staged, unstaged and untracked
diffs, so it may need a plain unified diff instead. *Later*: any stack gets
quality gates for free, and an installer can still come afterwards.

**C. B's seam in base, with Biome/Fallow, the installer and the agent in an overlay plugin.** Base ships
only B1–B3. A separate JS/TS overlay contributes the preset, an explicit `setup-quality` command that
previews and then applies `package.json`, lockfile and config merges, and the agent (or a pointer to fallow-skills), through new
`{{quality_extra}}`-style slots. *Effort*: XL in total across two repos. The overlay is L by itself, a
new pattern with several unknowns: package-manager installs and the merge or rollback of JSON or JSONC
configs. *Risks*: the overlay has to stay version-locked to base slots. *Later*: this is the cleanest fit
with "base never names an overlay". The overlay repo does not exist here, so nothing here can verify it.

**D. Convention only.** Make no new machinery. The planner and `adopt.js` recommend a `quality` package
script, and plans add ``Verify (step): `npm run quality` ``, which is already gated by `make verify` and
loop ticks. Docs give the Biome and Fallow snippets. *Effort M*: docs and a planner prompt, about two to
five files, plus a run transcript. *Risks*: nothing enforces quality in `make review` or in contracts-disabled
repos, and nothing guarantees the `ai-factory/` exclusion inside the tools. Easy to reverse, and it does not
block B later.

## Comparison
| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A | XL | High | Low | No: names and pins tools in base, writes root files at adoption | No |
| B | XL total, L per slice | Medium | Medium to high (opt-in, absent means legacy) | Yes, extends contracts and assurance | **Yes** |
| C | XL across two repos | Medium | High for the overlay | Yes, best on stack neutrality | Follow-on to B |
| D | M | Low, but weak guarantees | High | Yes | Stop-gap only |

## Recommendation
**B, delivered as slices B1→B3.** This is an opinion. Most of the request already
exists as contracts evidence: snapshot binding, the `ai-factory/` exclusion, staleness, fail-closed
when a tool is unavailable, the loop's pre-tick verify, and recorded review evidence. Extending
that keeps one evidence authority, as §4 of the request asks ("do not create a second approval
authority"). A generic check list keeps the base stack-neutral. Biome and Fallow become one preset,
and the root-file installer either goes to an overlay (C) or gets its own ADR later. I would change
my mind in two cases: the developer requires quality gates in contracts-disabled repos (that pushes
toward a standalone evidence file), or the plugin's owner decides that this base should ship JS/TS
tooling (that is A, behind an ADR).
The following points on Fallow are this session's recommendation and are opinion:
- fc does not depend on the fallow-skills plugin, because an LLM-driven skill cannot be the gate.
- The docs recommend fallow-skills as an optional analyst that a developer installs for JS/TS repos
  using the preset. That replaces building fc's own `quality-gate` agent (B4).
- fc flows never invoke `fallow-setup`, which writes root and CI files without fc's consent step and
  conflicts with ADR 0009.
- fc flows never invoke `fallow-cloud-setup`, because data leaves the machine.

### Effort and risk
Effort for B is **XL** overall: size XL (cross-cutting across run, loop, review, gate, assurance
and report, with an ADR) and uncertainty L (Biome `!!` and `fallow viz` are unverified, the `--diff-file` input format is untested, and per-step
prompts are new). The first slice, B1, is L. After the Decision below, B2 is **XL**. It now
carries the per-step panel, an interactive serial loop mode and bounded fix cycles in both
`/fc:run` and `/fc:loop` on Claude and Codex, which makes its size cross-cutting. It also needs an
amendment to ADR ETT683, whose loop halts only on failure, conflict or timeout. Its uncertainty is
L, because a prompt inside the loop is a new pattern. B3 stays L.
- Uncertain requirements: **present**. Per-step prompting conflicts with spec 0022's unattended
  loop, and Biome `!!` and `fallow viz` are unverified (Fallow `audit` is verified at 3.38.1 only).
- Authorization: **absent**. No user, role or permission model is touched; actor authority is
  covered by the gate semantics below.
- Public contracts: **present**. A new evidence phase and policy schema, new `gate.js` / `assurance.js
  complete` semantics, and a new `ai.mk` target, all of which are template changes for every adopter.
- Migrations: **absent**. The configuration is opt-in, a missing config means legacy behaviour, and no
  existing evidence is rewritten.
- Dependencies: **present**. The Biome and Fallow preset relies on two third-party CLIs, though base itself adds none.
- Service ownership: **present**. ADR 0009 forbids root-file writes at adoption and sync, and it is
  open whether the base or an overlay owns tool setup.

Present triggers: uncertain requirements, public contracts, dependencies and service ownership.
Run `/fc:risk` once the spec exists.

## Open questions
1. Must quality gates work in repos without artifact contracts? *Session's proposed default, not confirmed by the developer:* no, contracts-enabled repos only.
2. *Answered by the Decision:* the panel follows every step of `/fc:run` and of interactive `/fc:loop`, and an interactive, quality-enabled loop runs one step at a time.
3. Should the root-file installer exist in base at all (amend ADR 0009), in an overlay (C), or not at all (documented manual setup)? *Session's proposed default, not confirmed by the developer:* no installer. The preset is set up by hand, and an overlay may add one later.
4. Policy home: a standalone `ai-factory/quality.json`, a block in `contracts/config.json`, or an assurance preset key? *Session's proposed default, not confirmed by the developer:* `ai-factory/quality.json`.
5. Verify `fallow viz` and the Biome `!!` force-ignore against the pinned versions. The Fallow `audit` flags, `verdict` and exit codes were verified at 3.38.1, so re-check them at whichever version the preset pins.
6. Should the `working-tree` review diff that `runner.js` builds also exclude `ai-factory/` for everyone, or only for quality input? *Session's proposed default, not confirmed by the developer:* quality input only, so today's review diff is unchanged.
7. Ordering and version: ASD-003 (5.0.1) and ASD-004 (5.1.0, which rebases generators and `models.js`) come first. Does B1 release as 5.2.0, or as a major because it is template-breaking? *Session's proposed default, not confirmed by the developer:* B1 releases as 5.2.0, after ASD-004.
8. *New, from the Decision:* B2 has to amend ADR ETT683 and spec 0022. Should that be a new ADR, or an amendment recorded in ETT683?

## Decision (2026-10-31)
The developer chose **option B**: project-declared checks recorded as contracts evidence, delivered
as slices B1→B3. B4 is dropped in favour of the optional fallow-skills plugin. The developer also
took **the per-step panel from option A**, which B2 delivers:
- **Panel.** It appears after each `/fc:run` step and each `/fc:loop` step, but only when quality
  checks are configured. It shows ✓/✗ for the step's tests and for each quality check, then asks
  for the next action.
- **Choices, exactly as in the request's §3.3.**
  - On pass: Continue to next step, View report, Pause.
  - On fail or error: Show findings, Ask Implementer to fix, Re-run checks, Pause.
  - Ask Implementer to fix needs the developer's approval and is bounded by `maxFixAttempts`
    (default 3). Every fix invalidates earlier evidence, and the checks then re-run from scratch.
  - There is no choice that overrides a failure or accepts a failed step.
- **Interactive `/fc:loop` with quality on.** It runs one step at a time (effective parallelism 1):
  step, then panel, then choice, then the next step. No parallel decisions are queued.
- **Headless (`make ai TASK=loop`, CI).** No prompts. It continues on pass or warn, and it stops on
  fail or error with the blocked state recorded.
- **Repos without quality configuration** keep today's behaviour exactly, with no panel and no new line.

This deliberately reverses spec 0022's unattended loop and ADR ETT683's halt rule ("halting only on
a failure, conflict or timeout"), but only for interactive, quality-enabled runs. The pause adds
halts and grants no new exception: there are no extra commits and no reduced checks. B2 still has
to record it (see open question 8).
Two points are opinion. The serial-loop choice belongs in `loop.js`, as an action such as "await
choice" in the state, while `tasks/loop.md` only renders the panel, which keeps spec 0022's split.
The loop's worktrees live under `ai-factory/runs/tmp/worktrees/`, so excluding `ai-factory/` also
satisfies ETT683's rule that lint tools skip them.

## Next
`/fc:spec ai-factory/explorations/ASD-005-quality-gate.md option B as decided on 2026-10-31, slice B1: project-declared quality checks in ai-factory/quality.json recorded as contracts evidence (contracts-enabled repos only, no installer, release 5.2.0); B2 (per-step panel and serial interactive loop) and B3 (review gate and report) follow as separate specs`
