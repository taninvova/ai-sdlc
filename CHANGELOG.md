# Changelog

**Unreleased — plan 0021 assurance presets (no version bump)**

- Add opt-in assurance presets `light`, `standard` and `strict`, managed by the new
  `make/assurance.js`. `show [--json]` is read-only and prints the preset, each effective requirement
  and its source. `set <preset>` previews the change. `set <preset> --apply` enables contracts first
  where the preset needs them, then writes `ai-factory/assurance.json`
  (`{"schema":"t4-assurance","version":1,"preset":…}`). It refuses to overwrite a malformed selection.
  `complete <delivery> [--json]` exits 0 only when completion may be claimed.
  Statuses are `legacy`, `active`, `incomplete` (`U_CONTRACTS_NOT_ENABLED`) and `conflict`
  (`E_GATE_CONFLICT`, `E_GATE_INVALID`).
- **Presets set minimums.** Stronger existing controls are kept and shown as `retained`. `standard` and `strict` require
  contracts, final verification, `blocker` among the blocking severities and independent review, including quick, fix and chore work.
  `allow_attestation` and `code_scope` stay as configured. `light` never removes contracts configuration
  or evidence: in a contracts-enabled repo it keeps final verification and the configured review requirement.
  No preset changes risk routing. The mapping is a reviewable default.
- **Review gate.** `strict` enforces it. `GATE_ENFORCE=0` under `strict` is `E_GATE_CONFLICT`: `gate.js` exits 2,
  and `make ai`/`make review` stop before launching a host. `standard` stays advisory and says that an advisory exit is not approval.
  Without a selection `GATE_ENFORCE` is unchanged. With a preset, `make ai` and `make review` print the
  effective requirements on stderr first.
- **Review provenance.** Review evidence records `independence` and `boundary`. Only
  `make -f ai-factory/make/ai.mk review DELIVERY=<id>` records `independent`.
  - `quick`, `fix` and `chore` run it only from a session the developer invoked. Routed workers, headless task runs,
    the reviewer and an interactive `/t4:check` report the review as unmet with that command, and self-review never satisfies it.
  - Under `standard` and `strict`, a review without independent provenance is `REVIEW_NOT_INDEPENDENT`. This includes
    review evidence recorded before this release, which must be recorded again with `make review`.
- **Completion.** `assurance.js complete` evaluates current evidence and never reads a saved report. Under `strict` it writes
  the fresh completion report, which must be `ready`. Under `standard` a saved report is optional.
- **Reports.** `completion.json` gains an optional `assurance` object and the Markdown an `## Assurance` section,
  only when a preset is selected. `report.v1.json` changes compatibly. Legacy reports are unchanged.
  The report fingerprint includes `assurance.json` when it exists.
- **Procedures.** `quick`, `fix`, `chore`, `run`, `check` and `report`, plus the implementer and reviewer agents,
  consult `assurance.js show` only when a selection exists.
- **Known limitations.**
  - `contracts.recordReview()` accepts `independence: "independent"` from any caller, so provenance is a label, not proof.
  - `continue.js` still requires a saved completion report before returning `complete`, even under `standard`.
  - The paired Claude Code and Codex host runs in `skills/ai-layout/fixtures/assurance/cases.md` were waived.
    Host behavior of the changed procedures is unverified on both hosts, and the prompt changes carry no before/after run.
- Add `check-assurance.sh` (groups `policy`, `runtime`, `procedures`, `docs`). Extend `check-manifest.sh`, `check-workspace.sh`,
  `check-review-gate.sh` and `check-delivery-report.sh`.
- **Template upgrade impact:** this changes the templates of every adopted repository: the task procedures, the agents,
  `make/` helpers and the contracts README and schemas. Adopted repositories receive `make/assurance.js` on their next
  `/t4:adopt-sdlc` or `/t4:sync-sdlc`. Adoption and sync never create a selection, and both preserve an existing selection, a customized
  `contracts/config.json` and evidence. Until a repo selects a preset its behavior is unchanged. A repo that has
  `ai-factory/assurance.json` without the helper stops headless runs and the gate with `/t4:sync-sdlc` guidance.

**Unreleased — `/t4:state` ends its turn (no version bump)**

- `commands/state.md` now says to launch no agent, background task, workflow, command or skill,
  and to end the turn after the table. "Change nothing" alone did not stop a session that had just
  run several `/t4:run` hand-offs from delegating the next step straight after the listing.
  `check-state.sh` pins both sentences. Codex `$t4-state` reads the same file.

**Unreleased — plan 0020 workflow evaluations (no version bump)**

- The opt-in benchmark (`skills/ai-layout/scripts/benchmark-small-tasks.js --real`) now reports five
  outcomes per run: missed requirements, escaped defects, unnecessary questions, completion time and
  cost. Each comes with its evidence or `unknown`.
  - An evaluator rubric outside the model's fixture (`skills/ai-layout/fixtures/workflow-evaluations/rubric.json`,
    pinned by digest) decides requirement outcomes. Escapes are fixture-detected, never production defects.
  - Completion is read from a final `Completion status: completed|blocked|failed` line (prompt protocol 2). Runs
    recorded before it are not comparable. A clean exit alone is not completion, and a timeout is `interrupted`.
- Pairs record their fixture, request, rubric, settings, CLI, runtime and limits. A model, reasoning or provider setting
  is known only when it is pinned in `~/.codex/config.toml`; anything unset makes the pair `unverified`.
  Time and cost are compared only for matched pairs where both runs completed, every requirement is satisfied
  and there are no escaped defects.
- Money stays unknown unless `cost-links.json` links a run to a lifecycle report delivery that holds only that run.
  Lifecycle usage is never added to benchmark tokens. `make cost` is unchanged.
- New offline `--summarize=<run-directory>` regenerates `summary.md` and `report.json` inside the `ai-factory/`
  boundary and never launches a model. It reads optional human judgments (`judgments.json`, `t4-workflow-judgments` v1):
  questions labelled necessary/unnecessary/uncertain with a rationale, review markers and completion rulings.
  Unreviewed question counts are unknown, never 0.
- **Report format change:** the summary is now a workflow-evaluation report. The *Quality passes* column is replaced by
  a *Legacy assertions* count, which is not a quality criterion. The default `--real` selection is still 14 calls.
  `make check` makes no model calls.
- Add `check-workflow-evaluations.sh` with the groups `quality`, `pairing`, `report` and `harness`. The `harness` group
  drives `--real` end to end with a fake `codex` executable. It checks the opt-in refusal, the 14-call default, the
  timeout and concurrency bounds, fixture isolation and report regeneration. No templates or prompts shipped to adopted
  repositories change. The benchmark's own replay prompt adds the completion line, and no real before/after model run was made.

**Unreleased — delivery 0019 (no version bump)**

- Add `/t4:state --delivery <id>` (Codex `$t4-state --delivery <id>`): one contract delivery's
  status — planned or quick — as a read-only `field`/`value` table. It needs artifact contracts
  enabled and one delivery ID (`d-YYYYMMDD-xxxxxx`). `state.sh` passes the ID literally to the new
  `make/delivery-status.js`, which collects and evaluates once in memory through
  `delivery-report.js`. It never generates or saves a report, runs no checks, review or
  continuation, writes nothing and names no next action.
- Rows show evidence-derived progress (`planning`, `implementation`, `verification-unproven`,
  `review-pending`, `ready` or `unknown` — never a claim that work is running), the existing
  readiness, ticks as recorded progress only, criteria grouped as verified, attested, remaining
  and unknown, the latest verification by `finished_at` (ties by path; any unreadable timestamp
  makes it `unknown`), review, blockers, limitations and source paths.
- The default listing, `--done` and `--next` are unchanged. `--delivery` combines with neither and
  refuses a missing, repeated, malformed, unknown or duplicated ID in one line.
- **Template upgrade impact:** adopted repositories need the new `make/delivery-status.js` from
  `/t4:sync-sdlc` (or adoption). Until then `--delivery` answers with `/t4:sync-sdlc` guidance
  and writes nothing; the listing modes keep working. Repos without contracts are unaffected.
- Add `check-delivery-status.sh` (`helper` and `cli` groups) and legacy-listing coverage in
  `check-state.sh`. Live host status:
  [delivery 0019 report](ai-factory/reports/0019-delivery-status.md).

**Unreleased — scaffold spec simplification**

- Simplify `0000-scaffold.md` to four plain-language setup checks. Replace the API feature
  example with a small quick change and describe pending logs accurately.
- **Template upgrade impact:** adopted repositories will see this spec as changed upstream;
  review it through `/t4:sync-sdlc` and preserve local acceptance criteria. Runtime behavior is unchanged.

**Unreleased — delivery 0018 (no version bump)**

- Add interactive `/t4:continue <delivery id>` and `$t4-continue`. It accepts one artifact-contract
  delivery ID for a contracts-enabled planned delivery. A read-only selector (`make/continue.js`)
  reuses contract validation and report evaluation, runs no checks, writes nothing, and returns
  `action`, `question`, `blocked` or `complete` with evidence references and a fingerprint.
- Actions are limited to one existing task per invocation: plan, test red or gaps, run one named
  step, check (working tree), or report. Uncertain gaps-testing or skipped-red status asks first;
  answers (`--answer gaps_tested=yes|no`, `--answer red:S<N>=proceed`) choose between tasks and
  never stand in for evidence. Spec drift stops with downstream work named for manual
  reconciliation; nothing is regenerated, rehashed or deleted.
- The handoff validates the result and allowlisted arguments, rechecks the fingerprint, and
  dispatches exactly once under the destination's own model policy, with no fallback. Continue
  always runs in the invoking session: `routing.tasks.continue` is ignored and flagged by doctor,
  no route agent is generated for it, and a concrete continue `--task-model` is refused.
- Unsupported: headless `TASK=continue` (rejected before launch or run artifacts), spec/plan paths,
  quick deliveries and contracts-disabled repos.
- **Template upgrade impact:** adopted repositories need the new `tasks/continue.md` and
  `make/continue.js`, plus updated models.js, runner.js, sync-adapters.js and AGENTS.md. Inspect
  `/t4:sync-sdlc` drift and preserve local additions. Regenerate routing adapters and restart the host if
  routing is enabled. Direct tasks are unchanged and no adapters are written silently.
- Add `check-continuation.sh` (selector, handoff, integration groups) and transcript scenarios in
  `skills/ai-layout/fixtures/continuation/cases.md`. Live host status:
  [delivery 0018 report](ai-factory/reports/0018-reliable-continuation.md).


- Add interactive `/t4:start` and `$t4-start`: bounded read-only classification, one validated
  session-owned handoff, original request preservation, and independent destination model selection.
  Existing direct commands remain available; headless `TASK=start` rejects before launch or artifacts.
- Concrete start model overrides are rejected because generic workers cannot enforce read-only
  classification. Use a configured native routing adapter or explicit `inherit` instead.
- **Template upgrade impact:** adopted repositories need the new start task and updated models.js,
  runner.js, sync-adapters.js and AGENTS.md. Inspect `/t4:sync-sdlc` drift, preserve local additions,
  and explicitly regenerate configured routing adapters/restart the host when needed. No silent
  adapter writes or release/version bump.
- Add dispatch, entry, headless and adoption regression coverage. Live acceptance status and
  verification evidence: [delivery 0017 report](ai-factory/reports/0017-start-entry-command.md).

## 2.8.0 — 2026-09-30

Opt-in per-task model routing (spec 0016). `ai-factory/models.yaml` can name a model for each task
and tool. When enabled, the model is enforced before the task's work starts, for headless runs
and for interactive `/t4:<task>` and `$t4-<task>`. **With routing absent or `enabled: false`,
model selection is unchanged.**

- **Configuration.** Add `routing: { enabled, tasks.<task>.<claude|codex> }` in the existing
  file, written as the documented two-space block. The template ships it disabled.
  - Task names are the files in `ai-factory/tasks/`, custom ones included. Map `check`; `make review`
    runs it, and `review` under `tasks:` is rejected.
  - Aliases are passed verbatim and select a model, not a provider.
  - `pricing` is unchanged.
- **Resolution, first match wins:**
  1. explicit `MODEL=<id>` or `--task-model=<id>`;
  2. explicit `MODEL=` or `--task-model=inherit`;
  3. the task mapping;
  4. `review:` for check;
  5. the tool entry;
  6. the CLI's own configuration.

  A missing or blank mapping falls back, and says so.
- **Strict parsing.** A new shared module, `make/models.js`, is the only parser. Tabs, flow
  syntax, duplicates, unknown keys and non-literal booleans (`enabled: ture`) fail with their line
  number before anything launches, even while routing is disabled. Nothing retries on another model.
- **Headless.**
  - Every run prints `model: <task> / <tool>: <model> (<source>)` to stderr.
  - It writes a `<run>.json.model.json` sidecar (`t4.model-selection.v1`), keeping the requested
    model apart from any model identity the CLI output reported.
  - With routing on, a Claude run refuses to start while `CLAUDE_CODE_SUBAGENT_MODEL` would
    override its subagents.
  - `log.csv` and `make cost` are unchanged.
- **Interactive.**
  - Every task command and skill first runs `node ai-factory/make/models.js dispatch`, which prints
    one directive: `legacy`, `inherit`, `route` or `blocked`.
  - A routed task runs in a generated worker agent pinned to its model:
    `.claude/agents/t4-route-<task>-<hash>.md` or `.codex/agents/t4-route-<task>-<hash>.toml`.
  - The chat only relays questions and results. It never does the task itself, and never falls
    back to its own model.
  - Worker agents are written by `sync-adapters.sh --adapters=routing` (also by the claude and
    codex selections). Their names are content-addressed, so a session holding an outdated agent
    stops with a restart instruction instead of using the old model.
  - Dispatches and outcomes go to `ai-factory/runs/routing.jsonl` (`t4.model-dispatch.v1`).
- **Doctor** reports invalid routing, mappings with no task file, missing or stale worker agents,
  and `CLAUDE_CODE_SUBAGENT_MODEL`. It makes no network calls.
- **Checks.**
  - New: `check-interactive-model-routing.sh`, 12 cases.
  - Extended:
    - `check-model-selection.sh`: the precedence matrix and 28 invalid configurations;
    - `check-runner-security.sh`: routed argv through Make, sidecars, and one launch on failure;
    - `check-review-scope.sh`: `make review` and `make ai TASK=check` agree.
- **Not verified on live hosts.** No live Claude Code or Codex session has run a routed task with
  gateway aliases. Arbitrary aliases in agent files, reload timing and the model a worker actually
  used are unverified on both hosts. See the host matrix in `ai-factory/docs/workflow.md` §8 and
  plan 0016, Step 7.
- **Template change for adopted repos:**
  - New file: `make/models.js`.
  - Changed: `make/runner.js` and `make/sync-adapters.js`, which gains the `routing` selector and
    puts the routing step in project pointers. Custom-task Claude pointers now name the task file
    instead of `@`-importing it.
  - `models.yaml` gains the disabled `routing:` block and the precedence notes.
  - `docs/workspace-boundary.md` notes the local selection records.

## 2.7.0 — 2026-09-30

Opt-in lifecycle telemetry (spec 0015). It records delivery-level duration, waits, retries,
outcomes and attribution coverage beside the existing accounting. **`log.csv` and `make cost` are
unchanged**, whether telemetry is enabled or disabled.

- **Enabling it.** Set `"lifecycle": {"enabled": true, "retention_days": 90}` in
  `ai-factory/contracts/config.json`. Without it, nothing is recorded.
- **Recording.**
  - Events are local, one immutable file each, under the gitignored `ai-factory/runs/lifecycle/`.
  - Each run, attempt and wait gets its own ID, with explicit parent runs for delegated work.
  - Replayed hooks are idempotent: the same event lands under the same file name.
  - Events hold IDs, timings, outcomes and token counts only.
- **Instrumentation.**
  - The headless runner records its own runs (`DELIVERY`, `STEP`) and passes `T4_LIFECYCLE_RUN`
    to the CLI child.
  - Stop and SubagentStop link the usage they counted.
  - The Bash hook binds a session to a run when it sees `lifecycle.js start`.
  - The spec, plan, test, run, check and quick procedures bracket their work with
    `lifecycle.js start`/`end` and `wait-start`/`wait-end`.
- **Reporting.** `make lifecycle [DELIVERY=] [JSON=1]` covers:
  - elapsed time as an interval union, and waiting as a union of recorded waits;
  - active time, and agent effort, which is labelled and may exceed elapsed;
  - retries (resumptions and reruns are counted separately) and outcomes;
  - tokens, each unique source record counted once;
  - cost as a known subtotal plus the unpriced remainder, with provenance.

  Open runs, open waits, invalid clocks and missing prices show as unknown or partial, never
  zero. Ambiguous or unbound usage is reported as unattributed.
- **Export and retention.** `make lifecycle-export DELIVERY=<id>` writes the telemetry v1 export,
  and `make delivery-report` reads live lifecycle numbers when enabled. `lifecycle.js prune` keeps
  deliveries with saved reports and records what it removed.
- **Docs.** The workflow guide, README and FACTORY.md describe the three opt-in layers together:
  artifact contracts, the completion report and lifecycle telemetry. That includes the main-loop
  diagram, the CI gating commands, what the hooks record and what is gitignored, troubleshooting
  rows, and the short version.
- **Checks.** New `skills/ai-layout/scripts/check-lifecycle.sh`, 13 cases. All existing accounting
  checks pass unchanged.
- **Template change for adopted repos:**
  - New files: `ai-factory/make/lifecycle.js`, `lifecycle-events.js` and
    `contracts/schema/lifecycle-event.v1.json`.
  - `make/runner.js` and `make/delivery-report.js` are extended.
  - `make/ai.mk` gains `lifecycle` and `lifecycle-export`.
  - `.gitignore` gains `/runs/lifecycle/` and `/runs/telemetry/`.
  - Six task procedures gain one lifecycle paragraph, which only applies when lifecycle is enabled.
  - `AGENTS.md` ends its workflow line with `(→ /t4:report with contracts)`.
  - `docs/definition-of-done.md` gains item 8, the completion report before handoff where contracts
    are enabled, and loses a stray duplicated line under item 2.
  - `docs/workspace-boundary.md` names where reports, lifecycle events and telemetry exports live.

  Take these via `/t4:sync-sdlc`. The plugin hooks update with the plugin. **Not verified on real
  hosts:** interactive Claude and Codex sessions were not exercised live, and Codex session binding
  depends on a PostToolUse payload field that has not been confirmed.

## 2.6.0 — 2026-09-30

Delivery completion report (spec 0014): one local, reproducible answer to "what was asked,
what changed, what actually ran, what review found and what is still open", for finished and
unfinished work alike. It builds on the 2.5.0 artifact contracts and only reads.

- **New `/t4:report <delivery id>`** (Codex `t4-report`) and
  `make -f ai-factory/make/ai.mk delivery-report DELIVERY=<id>`. Both write
  `ai-factory/reports/<id>/completion.md` and `completion.json`, rendered from one model with
  schema `t4-delivery-report` v1.
- **Status** is `ready`, `incomplete`, `blocked` or `unverified`, with every contributing reason
  and its evidence reference.
  - A failed required check or a blocking review finding blocks.
  - Missing, stale or interrupted evidence leaves the delivery unverified.
  - Unfinished work is incomplete.
  - `ready` means ready for handoff, not merged.
- **Criteria.** The report has one row per AC or QC, uncovered ones included. A criterion is
  mapped only to the steps its plan sidecar names, never by wording. Quick deliveries use their
  checklist, and no spec is generated for them.
- **Read-only.** The report runs no check, edits no source artifact and publishes nothing; its
  MR description is a draft.
  - Collection is fingerprinted and retried, and aborts rather than mix two states of the evidence.
  - Writes are atomic, and a failed write keeps the previous report.
  - Logs are referenced by path and hash, never inlined.
  - Unsafe IDs and symlinked destinations are refused.
- **Completion policy.** An optional `completion` block in `ai-factory/contracts/config.json`
  sets `require_review`, `require_review_quick`, `blocking_severities` and `allow_attestation`.
- **Attestation.** New `contracts.js attest` records who, when, why and against which content.
  An attestation is always shown, counts only when policy allows it, never overrides a failed
  check, and goes stale when the spec changes.
- **Review evidence** now keeps a summary of the findings: severity, file, line and issue,
  truncated.
- **Telemetry** is optional. The report reads `ai-factory/runs/telemetry/<id>.json` (provisional
  schema `t4-delivery-telemetry` v1) if one exists. Nothing produces that file yet, so the section
  says `unavailable`. Unknown values are never shown as zero, and telemetry never affects status.
- New check: `skills/ai-layout/scripts/check-delivery-report.sh`, with 20 cases.
- **Template change for adopted repos:**
  - New files: `ai-factory/make/delivery-report.js` and `ai-factory/tasks/report.md`.
  - New schemas: `contracts/schema/{report,attestation,telemetry}.v1.json`.
  - `make/ai.mk` gains `delivery-report`.
  - `make/contracts.js` gains `attest`, attestation evidence, the completion policy and findings in
    review evidence; `make/runner.js` passes those findings.
  - `make/sync-adapters.js` lists `report` as a native command.
  - `tasks/check.md` and `tasks/quick.md` mention `/t4:report`.
  - `AGENTS.md` lists `/t4:report`.

  Take these via `/t4:sync-sdlc`. Repos without contracts are unaffected; `/t4:report` needs a
  delivery ID from an enabled repo.

## 2.5.0 — 2026-09-30

Opt-in validated artifact contracts (spec 0013): deterministic, read-only checks between
workflow steps, so a malformed, incomplete or stale spec, plan, checklist or verification result
is never silently used as the next step's input. Nothing changes for a repo that does not opt in.

- New `ai-factory/make/contracts.js`, which uses Node built-ins only. It adds `validate`,
  `init spec|plan|quick`, `record`, `snapshot`, `enable` and `migrate`, plus the
  `make contracts` and `make verify` targets.
- **Sidecars and states.** JSON sidecars beside the Markdown carry a stable `delivery_id`, the
  content digests, the AC and step IDs, and the verification argv. The validator reports each
  artifact as `valid`, `invalid`, `stale` or `legacy_unverified`, with stable JSON diagnostics
  (`--json` / `JSON=1`). Missing or unsupported metadata is never valid.
- **Freshness** is decided by content: SHA-256 of the Markdown (checkbox marks normalized) and of
  a Git-listed code snapshot that never includes `ai-factory/`.
  - Editing a spec makes its plan and evidence stale.
  - Editing in-scope code makes final, quick and review evidence stale.
  - A ticked step without passing evidence is `not_run`.
- **Evidence** is recorded only by running the declared commands without a shell, as `passed`,
  `failed`, `not_run` or `unavailable`. Red runs expect failure and never count as final
  verification. `make review DELIVERY=<id>` records review evidence bound to the exact gated
  output.
- **Read-only validation.** Validation writes nothing and reads through the `safe-files.js`
  boundary. Path escapes and symlinks are rejected, and a path mentioned in artifact prose is
  never opened.
- **Legacy artifacts.** `contracts.js migrate` is a dry run by default. `--write` drafts sidecars
  for legacy specs and plans. It never edits Markdown and never invents IDs or evidence, and its
  drafts stay `legacy_unverified` until reviewed. Running it twice changes nothing.
- `/t4:doctor` reports whether contracts are enabled and the overall contract state.
  `/t4:sync-sdlc` offers the opt-in and the migration dry run.
- New check: `skills/ai-layout/scripts/check-contracts.sh`, 37 cases in disposable repositories.
- **Template change for adopted repos:**
  - New files: `ai-factory/make/contracts.js` and `ai-factory/contracts/` (README and v1 schemas).
  - `make/ai.mk` gains `contracts` and `verify`; `make/runner.js` records review evidence when
    `DELIVERY` is set.
  - `.gitignore` gains `/runs/evidence/`, and `docs/workspace-boundary.md` names the evidence
    locations.
  - The specifier, planner, tester, implementer and reviewer agents and the quick task gain a
    contracts section that applies only when `ai-factory/contracts/config.json` exists.

  Take these via `/t4:sync-sdlc`, then opt in with `node ai-factory/make/contracts.js enable`.
  Opting out means deleting `config.json`; sidecars and evidence stay in place and are never
  reinterpreted as verified.

## 2.4.0 — 2026-09-30

An optional external documentation source, offered at adoption and addable later. The repo's own
`ai-factory/docs/` stays the primary knowledge base; nothing changes for a repo that skips it.

- New `/t4:setup-knowledge` (and Codex `t4-setup-knowledge`): interactive, modelled on
  `/t4:setup-tracker`. It picks a source the session already lists, asks what it is for, writes
  one row to the knowledge declaration after confirming, asks whether to commit or ignore it, and
  proves it with one read-only call. It never writes tool configuration or credentials.
- `/t4:adopt-sdlc` asks once, in an interactive session only, whether to declare an external
  documentation source; the default is skip. Skipping, or a headless run, writes nothing and the
  report names `/t4:setup-knowledge` for later.
- `/t4:doctor` points an unconfigured repo at `/t4:setup-knowledge`, as information, not a finding.
- **Template change for adopted repos:** `ai-factory/docs/knowledge.md` gains *Setting up a source*,
  and `ai-factory/make/sync-adapters.js` lists `setup-knowledge` as a native command. Take both
  via `/t4:sync-sdlc`; until then `/t4:setup-knowledge` still works from the older `knowledge.md`.

## 2.3.3 — 2026-09-30

Maintenance release; no workspace-layout, log-schema or prompt change for adopted repos.

- `check-adapters.sh` no longer fails on a clean checkout. Since 2.3.2 every task is a native
  plugin command, so the adapter sync writes no `.claude/` pointer and the directory does not
  exist; the idempotence hash now covers only the adapter directories that are present.
- A root `Makefile` adds `make check`, which runs every `check-*.sh` in the plugin and stops at the
  first failure. It is plugin-only; the adopter `ai.mk` template is unchanged.
- The Claude manifest names the repository, as the Codex one already did; the Codex manifest no
  longer declares an MIT license that contradicted `LICENSE` (internal use).
- The local-development command is `claude --plugin-dir .` from the repo root, which works
  wherever the checkout lives.
- `.gitignore` drops the `.serena/` entry left over from Serena's removal.


## 2.3.2 — 2026-09-29

Fix Claude command discovery: 2.3.1 shipped six native slash commands, while its other
workflow prompts were available only through repo-local pointers. The plugin now ships
all 18 commands, including all 13 project task entry points. Thin wrappers read the repo's
`ai-factory/tasks/<name>.md`, preserve customizations and user arguments, and report missing
workspaces or tasks without creating adapters or silently adopting a repo.

**Adapter template change for adopted repos:** take the updated
`ai-factory/make/sync-adapters.js` explicitly before requesting Claude adapter sync.
The sync removes old generated pointers for built-in commands, preserves hand-authored
files, and still creates pointers for project-specific tasks. Repos retaining an older
adapter generator may recreate duplicate entries; update the template before syncing.
No workspace-layout or log-schema change is required. Codex skills remain available.

Update/reinstall the plugin and restart Claude Code (or reload plugins) to load the native
commands. A real Claude Code 2.1.277 SDK initialization in an empty directory confirmed
six t4 commands from installed 2.3.1 and 18 from the updated checkout, without repo-local
pointers or a model turn. Regression coverage checks both native host surfaces, stale
pointer cleanup, custom task preservation, and command metadata/procedure references.


## 2.3.1 — 2026-09-29

Compatibility fixes for Claude Code and Codex, plus accurate reporting of withdrawn work.

- Codex ships native skills for all t4 workflows and setup commands. Its hook adapter
  handles `apply_patch` targets and rename destinations, task labels, and rollout usage
  with response de-duplication and separate cached input. Codex costs remain unknown;
  Claude hooks retain their event and transcript formats. Delegation uses native agents
  when available and labels inline reviews as self-checks.
- Claude adapter sync removes duplicate `/t4:quick` pointers and duplicate registrations
  for the plugin's eight agents. Project-specific agents still receive pointers, and
  native agents read the project's complete procedure and additions. `/t4:doctor`
  identifies duplicate command pointers separately from missing or stale adapters.
- `/t4:state` recognizes explicit numbered withdrawal results without editing archived
  checkboxes. Withdrawn steps are omitted from pending work and `--next`; `--done`
  distinguishes closed plans/specs from fully complete ones. Pending and unknown work
  still takes precedence; quoted and fenced examples do not resolve steps.

### Adoption and validation

This release changes shipped agent procedures and the adapter-generation template.
Existing adopted repos must take those template updates explicitly, preserving project
additions, before regenerating selected adapters. Claude sync removes previously generated
agent and command duplicates; hand-authored adapters remain protected. The workspace layout
and 17-column log schema are unchanged.

Update the installed plugin and restart the host session. Codex's bundled skills require no
project adapters; review and trust the updated hook definitions in `/hooks` before relying
on automatic logging or edit protection. Adapter generation remains opt-in.

All 22 regression scripts passed, including existing Claude fixtures and new Codex coverage.
Biome checks and native Codex skill/hook discovery passed. A full autonomous model-driven
run of both hosts was not performed; see `ai-factory/docs/workflow.md` for validation limits.

## 2.3.0 — 2026-09-29

Security fixes and a shorter route for small changes. Performance measurements and
remaining validation limits are recorded in `ai-factory/docs/small-task-benchmark.md`;
this release does not promise a particular model latency improvement.

### Workspace and workflow

- New adoption creates only `ai-factory/`, detects declared commands without running
  them, and preserves existing root files. Complete agent procedures are delivered
  locally. Node, Bash, Git and a configured AI CLI remain prerequisites; no new package
  or optional integration is required.
- Adapter generation is now opt-in per host. Default `/t4:sync-sdlc` reports drift and
  preserves existing integration files. Explicit generation refuses user-file collisions.
  Manifest writes reject redirected destinations; adapter writes reject shared hard links.
  Use `make -f ai-factory/make/ai.mk` without a root Makefile. Scratch and Git rules live
  inside the workspace. Existing external files are not automatically moved or removed.
- `/t4:quick` handles understood local enhancements with an acceptance checklist,
  regression evidence and labeled self-review. Uncertainty or sensitive boundaries use
  the planned workflow. Planned verification distinguishes expected red, step, and final
  checks; a future-step failure can remain only when its recorded identity and cause match.
- Headless review defaults to staged, unstaged and nonignored untracked changes;
  committed branch and supplied-input scopes remain explicit. Review model selection
  honors explicit `MODEL`, then `review:`, tool default, and CLI inheritance. Explicit
  blank `MODEL=` means inheritance. Interactive agents retain their session model.

### Security and compatibility changes

- The launcher treats Make/config values as data and invokes executables with argument
  arrays. `CMD` now selects one executable name or path; shell-fragment overrides are
  rejected. Per-run private scratch and exact review-output identities prevent overlap.
- The edit guard resolves the repository from nested directories and checks canonical
  targets. Missing or malformed policy in an adopted repository fails closed. Intentional
  empty policy requires `<!-- t4:allow-empty-policy -->`. No-layout repositories remain
  a deliberate no-op; the historical old-layout hook fallback remains until 3.0.0.
- Hook and runner writers reject symlinked or shared mutable destinations and unsafe
  event identifiers. Existing projects using redirected run directories must move them
  into a real local workspace before these writers can resume.
- `GATE_ENFORCE=1` now requires a schema-valid `approve` with no blockers. Unknown
  verdicts, malformed output, missing output and `request_changes` fail. Unset/`0` is
  advisory; invalid enforcement settings fail. Output and Codex sidecars bind to one run.
- These checks provide defense in depth. The host sandbox still governs arbitrary shell
  execution and concurrent hostile filesystem races; the edit hook is not a sandbox.

### Adoption and validation

Update the installed plugin and restart its host session to load hooks and native commands.
Run `/t4:sync-sdlc` to inspect drift, then take template changes as a separate reviewed edit,
preserving project additions. Existing adopted runners do not update automatically. Include
`runner.js`, `safe-files.js`, `gate.js`, `log.js`, the Make entry point, complete agents,
workflow prompts, and local Git rules when taking this release. Generate external adapters
only when requested for the selected host. No package is published by this working-tree edit.

Regression coverage adds literal configuration payloads, canonical path checks, unsafe
writer destinations, concurrent accounting, exact review binding, diff scope/model
selection, isolated adoption, optional adapters and actual-text release assertions.


## 2.2.0 — 2026-09-29

`/t4:state` lists what is still outstanding in a repo — every spec and plan that is not finished,
each outstanding plan shown with its own incomplete steps — and changes nothing while doing it.
It is what to run when you come back to a repo and need to know where the loop was left, before
`/t4:run` picks anything up. Nothing else in this release changes, and nothing an adopted repo
holds is touched by it.

### New — `/t4:state`

- **`/t4:state`** (`commands/state.md`) lists every outstanding spec and plan by
  repository-relative path, and under each outstanding plan its incomplete steps, each with the
  step identifier and its one-line description. A finished item is not listed. Where a plan file
  sits decides nothing — its checkboxes do: a plan filed under `ai-factory/plans/done/` with one
  step still open is outstanding, and `- [~]` counts as incomplete exactly as `- [ ]` does.
- **`/t4:state --done`** replaces that listing with its mirror image: only the items whose every
  step is complete, with the same columns in the same order and the same shape.
- **`/t4:state --next`** names the single item to pick up — the most recently modified artefact,
  measured by its **git commit date** (`git log -1 --format=%ct`) and not by filesystem mtime, so
  two people sitting on the same commit get the same answer out of the same tree. An mtime does not
  survive a clone; a commit date is identical in every clone. An uncommitted or untracked artefact
  sorts newest, ties break on the artefact's number then its path then its step, and one reason
  line says which rule chose the winner.
- **`--done --next`, in either order, refuses**: one line saying the two do not combine and what
  each does on its own, no table rows, and **exit 0**. A flag the command does not take is named
  back the same way, with the two it does. A refused result is an answer, not a crash.
- **`skills/ai-layout/scripts/state.sh`** carries the whole decision — the scan, the completeness
  rule and the rows. The prompt renders what the script emits and re-infers nothing, so the same
  tree answers the same way twice running and in a headless run. The script always exits 0, reads
  nothing outside the repo root it is handed, and reports an artefact it cannot read or cannot
  parse as `unknown` with the reason, never as complete.

### Read-only, and checked rather than promised

Neither the command nor the script creates, edits, moves or deletes anything. It never ticks a
checkbox, never moves a plan between `ai-factory/plans/` and `done/`, and never starts a step —
`--next` names the item to pick up and does not pick it up. `skills/ai-layout/scripts/check-state.sh`
pins that with a filesystem snapshot and a content snapshot taken either side of a run, and pins
that two consecutive runs over one tree are byte-identical.

`--next` is the one part that calls `git`, and in a directory that is not itself a repository `git`
walks **up** to an ancestor one. Every `git log` is therefore gated on the repo root being the git
toplevel, so a run can never answer out of a repository it was never given. Where that gate fails
no artefact has a commit date, the tiebreak alone decides, and the reason line says that no commit
dates were available.

`check-state.sh` is already counted in 2.1.0's thirteen check scripts — it landed before that
release went out. This release adds none and removes none.

### Blast radius: nothing moves in an adopted repo

**No template file moved.** `/t4:state` is a plugin command, not a project task, so nothing under
`skills/ai-layout/templates/` changed: no adopted repo's `ai-factory/.sdlc.json` gains, loses or
rehashes an entry, and `/t4:sync-sdlc` reports no drift from this release. Verified rather than
assumed — the feature's whole diff touches `commands/`, `skills/ai-layout/scripts/`, `README.md`
and `ai-factory/docs/workflow.md`, and no template path at all; a manifest generated over the
templates names neither `commands/state.md` nor `skills/ai-layout/scripts/state.sh`, because
`manifest.js` hashes only `skills/ai-layout/templates/`; and `check-manifest.sh` passes with both
files present. The one thing a synced repo does see change is the version in its manifest header,
as it does on every release.

### What this ships, and what it does not

- **The documented half of the feature's acceptance criterion is done.** The command ships in
  `commands/`, `README.md` and `ai-factory/docs/workflow.md` name it, and this entry and the three
  manifests record the change.
- **The adapter and manifest half is not done, and is not reachable without a breaking change.**
  `ai-factory/make/sync-adapters.sh` generates the `.claude/`, `.cursor/` and `.codex/` adapters
  from `ai-factory/tasks/`, `ai-factory/skills/` and `ai-factory/agents/` — it never reads
  `commands/` — and `manifest.js` hashes only the templates. A plugin command is structurally
  invisible to both, and every plugin command already shipped is equally invisible: `.claude/commands/t4/`
  holds the twelve task commands and no `/t4:doctor`, `/t4:adopt-sdlc`, `/t4:sync-sdlc` or
  `/t4:setup-tracker` either. Making one visible means changing the generator or the manifest
  format, which is a template change and breaking for every adopted repo. **So do not read this
  entry as saying `/t4:state` is registered in the adapters or listed in `ai-factory/.sdlc.json`.
  It is not, any more than `/t4:doctor` is.**
- **Five questions about `/t4:state` are still open, and shipping it closes none of them.** Which
  of the six emitted fields become table columns, in what order, and whether a spec row and a
  plan-step row share one column set. How a spec is paired to its plan — the rule in use is derived
  from the spec rather than confirmed by anyone. The adapter-and-manifest clause above. Whether a
  step that is blocked, withdrawn or recorded not-run should be distinguishable from one simply not
  started — today all four read as outstanding, which is the conservative answer, not a decided one.
  And whether `ai-factory/specs/0000-scaffold.md`, which ships in the templates with no plan and
  never will have one, should head the listing in every adopted repo for ever — today it does. Each
  has a fixture in `check-state.sh`, so answering one changes one rule and one fixture.

## 2.1.0 — 2026-09-29

`/t4:migrate-layout` is removed, on the schedule 1.0.0 set and 2.0.0 revised. Nothing else about
the rename changes: the hooks' fallback to the pre-1.0.0 directory name stays until 3.0.0, so a
repo that never migrated keeps its dont-touch guard and its run log exactly as it had them.

### Still on the pre-1.0.0 layout?

Run the migration from an older checkout, which is what made removing it a minor release rather
than a major one. Check ai-sdlc out at 2.0.0 or earlier, point your tool at that copy
(`claude --plugin-dir <that checkout>`), and run `/t4:migrate-layout` there; it is unchanged, and
the two-commit order it prints still applies. Nothing is disarmed while you wait — an unmigrated
repo's hooks go on reading the old directory name until 3.0.0, and a slash command that is not
installed fails in front of the person who can fix it.

`/t4:doctor`, `/t4:sync-sdlc` and `manifest.js check` still detect an unmigrated repo and stop
rather than guess. Each now names the checkout the command lives in, instead of a command this
release no longer ships.

### Removed

- `/t4:migrate-layout` (`commands/migrate-layout.md`).
- `skills/ai-layout/scripts/migrate-layout.sh` and `rewrite-paths.js` — the move and the path
  rewriter. They go with the command: nothing here reaches them without it, and ADR 0008 already
  names an older checkout as where a repo that still needs them gets them.
- `skills/ai-layout/scripts/check-migrate.sh` — the check that pinned those two against synthetic
  pre-1.0.0 repos. Its subject left the repo, so it did too: **thirteen** check scripts now, nine
  under `skills/ai-layout/scripts/` and four under `skills/ai-hooks/fixtures/`.

### Still deprecated

- The hooks' fallback to the old directory name — **kept until 3.0.0**, unchanged by this release.
  Removing it disarms the dont-touch guard and stops the run log in any repo that never migrated,
  and does so silently. See `ai-factory/adr/0008`.

## 2.0.0 — 2026-09-27

**Breaking for every adopted repo. Your existing `ai-factory/runs/log.csv` rows move to
`log.previous.csv` on the next write.**

The run log gained a seventeenth column, `agent`, and the header therefore changed. The guard that
has always protected this file does what it is for: on the first write after you take this update —
a flush from a session, or a headless `make log` run — every row under the old header moves to
`ai-factory/runs/log.previous.csv` under a dated comment saying why, and a clean `log.csv` is
started. Nothing is deleted and nothing is reinterpreted.

### What that means for a log you have been keeping

Your history is intact, in a second file, and it does not append to the new one. If you read
`log.csv` from a script, a dashboard or a spreadsheet, it now has 17 columns and, from the next
write on, no rows older than this release — read `log.previous.csv` alongside it for anything
before. Those old rows are also **cumulative**: each was a re-sum of the session's transcript so
far, so adding them up double-counts. The new rows are increments and do add up. That difference is
the reason the two files stay apart instead of being merged.

`make log-flush` refuses while `log.pending.csv` and `log.csv` carry different headers — exactly the
state right after this upgrade. Let a session flush first, so the hook migrates the file, and then
`make log-flush` works as before. Restart your sessions after updating the plugin: hooks load from
the installed copy, so an older one keeps writing 16-field rows, and the guard quarantines them.

### New — where the money went

- **One row per concluded subagent**, on `SubagentStop`, summed from that agent's own transcript.
  `source=agent`, the agent's name in the new `agent` column. Tokens spent inside the reviewer, the
  tester, or the explorer / specifier / planner / implementer that `/t4:explore`, `/t4:spec`,
  `/t4:plan` and `/t4:run` delegate to are no longer missing from the log.
- **`task`**, filled on `UserPromptSubmit` from the `/t4:` command you typed — the session's task,
  carried onto its agents' rows too, so a specifier under `/t4:run` is `run,specifier`.
- **Rows are increments**, not running totals: the rows of one session add up to what it spent.
- **A usage record is counted once**, keyed on its message uuid, however many transcripts carry a
  copy of it — context inheritance re-logs a prefix of the parent's records into every forked child,
  and summing per transcript counted those tokens once per copy. A record whose transcript format
  omits the key is counted every time instead: an over-count, never a silent loss.
- `source` is now `session`, `agent` or `make`. Group by any of the four new dimensions.

### New — `make cost`, which reads all of that back

Shipped in this entry rather than a version of its own: it reads the schema this release introduces
and is unusable without the rotation above, so the two are one change. The header break is what makes
its totals trustworthy — the cumulative rows it must not sum are quarantined in `log.previous.csv`,
which it never opens.

- **`make cost`** prints token spend by **task**, **agent**, **branch** and **day**, then a total.
  Four tables inside 80 columns; the cache hit rate per group is recomputed from the summed tokens,
  never averaged over rows, because the mean of per-row ratios weights a ten-token row like a
  ten-million-token one.
- **`make cost JSON=1`** and **`make cost TSV=1`** print the same numbers as a machine-readable
  document — one document on stdout and nothing else. Those two variables are the whole flag surface;
  there are no filters in this version.
- **Tokens and turns, never money.** `cost_usd` is not read at all. Summing it across layouts would be
  summing prices set in ten separate `models.yaml` files; anything that wants a dollar figure prices
  the token counts itself, with one price list, so its totals compare.
- **The export is a contract.** It carries a schema version — a plain integer, starting at `1`.
  Adding a field does not change it, so a consumer must ignore fields it does not recognise; renaming
  a field, removing one, or changing what one means does change it, and is breaking for a collector
  this repo cannot see.
- **Unattributed spend is named, not folded away.** Rows with no `task` or no `agent` — every row
  written before this release — appear under `(unattributed)` with their count visible. A row whose
  width does not match the header, or whose quotes never close, reaches no total and is counted
  separately: a torn record and a wrong-width one are different faults.
- **A missing, empty or damaged log says which it is.** A header that cannot be parsed swallows the
  file into one record, so it counts zero rows exactly as an empty log does; the message distinguishes
  them rather than reporting a damaged log as "nothing recorded yet".
- **Read-only.** Neither mode creates, modifies, moves or deletes anything under `ai-factory/runs/`.
- Caveats, stated because the report would otherwise imply otherwise: **Cursor is not measured** and
  cannot be, so where Cursor is in use this is not a complete picture of spend; `accepted` is
  hand-filled, so its coverage line appears only once some row carries a value; and per-**agent** and
  per-**task** figures are meaningful only for rows written by this release's collection change.

### Still on the pre-1.0.0 layout?

**Run `/t4:migrate-layout` once, in each repo** — this release does not change that, and does not
remove the safety net either. The hooks still accept the old directory name as well as the new one,
so an unmigrated repo keeps its dont-touch guard and its run log, and the two new events behave
exactly as they do in a migrated repo. The prompts are not so forgiving: they name `ai-factory/`
only. **Grep your own CI, pipeline config and tooling** for the old directory name — the plugin
cannot see those paths and does not touch them. `/t4:doctor` says which state a repo is in.

### Deprecated

- `/t4:migrate-layout` — **removed in 2.1.0** (was 1.1.0, which this release skips past). A
  one-shot migration; its absence is a missing command, which is loud, and the script can still be
  run from an older checkout.
- The hooks' fallback to the old directory name — **kept until 3.0.0** (was 2.0.0, which is this
  release, and it keeps the fallback). Removing it disarms the dont-touch guard and stops the run
  log in any repo that never migrated, and does so silently. That is not a change to make in a
  release doing something else. See `ai-factory/adr/0008`.

### Also

- New hook scripts `subagent-stop.js` and `log-task.js`; `SubagentStop` and `UserPromptSubmit`
  registered in `hooks/hooks.json`. Both no-op outside a repo with the layout, and neither prints.
- `_usage.js` — the transcript sum, the per-session claim ledger and the price resolution, shared by
  the session and agent rows and pinned by `fixtures/check-usage.sh`.
- `ai-factory/runs/.counted.*` and `.task.*` — two gitignored state files beside the log. Add both
  lines to your `.gitignore`; `/t4:sync-sdlc` and `make clean-runs` know about them.

## 1.0.0 — 2026-09-25

**Breaking for every adopted repo. Run `/t4:migrate-layout` once, in each repo.**

The layout directory is now `ai-factory/`, and the two directories the loop kept outside it have
moved in:

| was | is |
|---|---|
| `ai/` | `ai-factory/` |
| `specs/` | `ai-factory/specs/` |
| `docs/adr/` | `ai-factory/adr/` |
| `docs/workflow.md` | `ai-factory/docs/workflow.md` |

An adopted repo now gains exactly one directory. `AGENTS.md`, `CLAUDE.md` and `Makefile` stay at
the root, because the tools look for them there. Decided in `ai-factory/adr/0008`.

### What to do

1. Update the plugin.
2. In each adopted repo, with a clean tree: `/t4:migrate-layout`.
3. Commit what it leaves as **two** commits, in the order it prints — the moves, then the path
   rewrite. The command stages the moves and leaves the rewrite unstaged so the right order is the
   easy one. *(Corrected after this release merged: the original wording said one commit always
   severs `git log --follow`. It depends on similarity — a file whose path lines are most of its
   content loses its history, an ordinary-length file survives. Two commits make the outcome
   independent of file size. See ai-factory/adr/0008.)*
4. **Grep your own CI, pipeline config and tooling for `ai/`.** The plugin cannot see those paths
   and does not touch them.

The migration refuses rather than guess: no layout at all, both layouts present, the same file
under both, or uncommitted changes to tracked files — an untracked file is named, not refused.
It commits nothing, and it rewrites path strings only — no new
prompt text arrives with it. Taking upstream prompt changes is still `/t4:sync-sdlc`, separately.

### Nothing breaks while you wait

The hooks accept the old directory name as well as the new one, so a repo that has updated the
plugin but not yet migrated keeps its dont-touch guard and its run log. A rename that silently
disarmed the guard would be the worst outcome here, because nothing would look wrong. The prompts
are not so forgiving — they name `ai-factory/` only, so the tasks will look in a directory that is
not there until the migration runs. `/t4:doctor` reports which of the three states a repo is in, and
`/t4:sync-sdlc` stops with the migration instruction instead of a drift report it cannot compute.

### Deprecated

- `/t4:migrate-layout` — **removed in 1.1.0.** A one-shot migration; its absence is a missing
  command, which is loud, and the script can still be run from an older checkout.
- The hooks' fallback to the old directory name — **kept until 2.0.0.** Removing it disarms the
  dont-touch guard and stops the run log in any repo that never migrated, and does so silently.
  That is not a minor-release change.

### Also

- New `/t4:migrate-layout` command, with `skills/ai-layout/scripts/migrate-layout.sh` and
  `rewrite-paths.js` behind it.
- New `check-paths.sh`: no prompt, agent, skill, command or context doc may name a pre-1.0.0 path.
  Records — specs, plans, designs, analyses, ADRs, this file — are exempt and keep the paths that
  were true when they were written.
- New `check-migrate.sh`: the migration against synthetic repos, including every refusal, the
  path-only guarantee and the history check.
- `check-doctor.sh` goes from 9 cases to 12: unmigrated, half migrated, migrated.
- `manifest.js` no longer tells an unmigrated repo it "was adopted before manifests existed" and
  then sends it to two commands that cannot help. It says what to run.

## 0.27.1 — 2026-09-22
- Review follow-ups for 0.26.0 and 0.27.0, no behaviour change.
- `ai/docs/knowledge.md`: the "Not defined here yet" section no longer says the implementer's
  position waits for a spec — the executor paragraph above it settled it in 0.27.0, and the two
  sentences contradicted each other.
- `tester` and `reviewer` prompts: in an unconfigured repo, say nothing about a knowledge source —
  not even that none was used. The reviewer's summary had been ending with exactly that leak.
- `check-adapters.sh`: `shopt -s nullglob` per the shell standard, and a check that this repo's
  real-file copy of the seam document is byte-identical to the template.
- Codex inline note and workflow §8 now say what the four step agents lose when inlined: the
  step sees the chat it was meant to start without.
- Plans 0004 and 0005 and spec 0004: AC7 recorded as partially proved headless; result blocks for
  0004 steps 3 and 4; the 0005 file table names `fleet.md` and `adopt-sdlc.md`; the doctor line is
  stated to be the prompt's. 0.27.0's adopter note said eight files; it is nine.
- Adopted repos: `ai/docs/knowledge.md` changes one paragraph; the Codex notes regenerate on
  `/t4:sync-sdlc`. Not breaking.

## 0.27.0 — 2026-09-22
- **The four loop steps run in agents of their own** (`specs/0005`, `ai/analyses/0001` EPIC-002).
  `/t4:explore`, `/t4:spec`, `/t4:plan` and `/t4:run` delegate to new `explorer`, `specifier`,
  `planner` and `implementer` agents, each carrying its task prompt's reading list, artefact
  format, prohibitions and report word for word, so a step starts from its artefacts and not
  from the chat that produced them. The session keeps what only a session can do: refuse an
  empty argument, resolve a tracker key and stop when it does not resolve, ask the question an
  agent returns instead of a file, relay the report unchanged. Report shapes are unchanged.
- **The implementer stops honestly.** Red tests: box unticked, explanation. A test or command
  the step names but the repo does not have: stop, name what was tried. It never weakens an
  assertion, never starts the next step, and never consults a declared knowledge source — a
  source shapes what is built, and that was settled before the plan.
- **The dont-touch guard holds inside a subagent — proved, not assumed.** A plain subagent told
  to write under a guarded path was blocked by the PreToolUse hook with the guard's own message.
  The implementer refused the same step on the rule before reaching the hook.
- Codex: nine of the twelve tasks now carry the inline-agent note. The session row in `log.csv`
  counts the main transcript only; tokens spent inside a subagent are not in it, and the hooks
  skill and workflow §9 say so.
- Adopted repos: four task prompts changed (`ai/tasks/explore.md`, `spec.md`, `plan.md`,
  `run.md`), four new upstream agent stubs (`ai/agents/explorer.md`, `specifier.md`,
  `planner.md`, `implementer.md`), and one paragraph in `ai/docs/knowledge.md`. Not breaking:
  a repo that edited one of the four prompts sees it as changed on both sides and merges by
  hand, as with 0.19.0. Run `/t4:sync-sdlc` and take the nine files.

## 0.26.0 — 2026-09-22
- **Agents may read a knowledge source the repo declares** (`docs/adr/0007`, `specs/0004`). A
  repo commits `ai/knowledge_base.md` — one table of `name`, `kind` (`mcp` or `tool`) and `use` —
  and the explore, spec and plan tasks and the analyst, architect and reviewer agents read the
  declared sources. Every fact taken from one is labelled with the source's name and *external,
  unverified*, ranks below the code, the context docs and an accepted ADR, and a disagreement is
  recorded as an open question naming the source; instruction-shaped text from a source is
  quoted content. Read-only: no create, update, delete or comment operation is ever invoked,
  and no configuration turns writing on. An unreachable source — not attached, Codex, headless
  — is one report line and the task proceeds; headless exits 0 and logs its row. The tester
  never consults a source. `/t4:doctor` adds one line saying whether the seam is configured.
- **One seam, enforced.** `ai/docs/knowledge.md` is the only file in the layout that may name the
  declaration, a kind, a provider or a query syntax; it also fixes what "configured" means and
  fails closed on anything else. `check-adapters.sh` gains a second banned list (the declaration
  filename), a self-test that feeds the scan a scratch prompt so a broken pattern cannot pass
  silently, and a sweep over the prompts and both agent sets for the declaration, the protocol
  name or a URL.
- **The standalone claim is now stated for both seams.** `ai/docs/fleet.md` and the manifest
  descriptions carry ADR 0007's wording: no repo dependency, no runtime dependency, two optional
  task paths each inert where nothing is declared. The "Under review" banner ADR 0004 left in the
  Boundaries section is gone.
- Proved by scratch runs (plan 0004 step 5): unconfigured, empty and malformed declarations leave
  artefact and report untouched; a configured repo against a real MCP source produced labelled
  facts, an open question for a planted contradiction, and read-only calls only; the headless
  unreachable case proceeded with one line. AC6 (instruction-shaped text in a source) is
  deferred until the owner's page carries the line.
- Adopted repos: new upstream file `ai/docs/knowledge.md`; `ai/tasks/explore.md`, `spec.md` and
  `plan.md` gain one conditional paragraph each. Not breaking — nothing behaves differently until
  a repo commits a declaration. `/t4:sync-sdlc` lists the four files; take them and re-run it.

## 0.25.0 — 2026-09-22
- **New `analyst` agent and `/t4:analyse` task.** A request that is still a business
  description — several actors, permissions, business rules, a lifecycle, integrations, policy
  nobody has decided — had nowhere to go: `/t4:spec` needs a buildable feature and
  `/t4:explore` needs a settled home. `/t4:analyse <description>` delegates to the `analyst`,
  which writes `ai/analyses/NNNN-*.md`: objectives with success measures, scope and boundary,
  permission matrix, use cases and state transitions, functional and non-functional
  requirements, business rules and decision tables, data dictionary, integrations, stories with
  Given/When/Then ACs, test scenarios (`Not run`), a traceability matrix, and separate registers
  for assumptions, proposals, open questions, risks and source conflicts. Every statement
  carries one label — supplied fact, confirmed decision, assumption, proposal, open question —
  and none is promoted to another by repetition. It invents no policy, estimate, approval or
  existing architecture; current behaviour comes from the code's public surface, cited as a
  source. Modes: `document` (default), `lean`, `questions`, `review`, `update` (change control
  with ids preserved), `explain`.
- `/t4:spec` reads `ai/analyses/` when a pack exists for the feature: ACs come from its
  requirements and stories, its open questions carry over, and an assumption or proposal never
  becomes a criterion.
- Adopted repos: new upstream files `ai/agents/analyst.md`, `ai/tasks/analyse.md` and
  `ai/analyses/.gitkeep`; `ai/tasks/spec.md` changed (one paragraph). Not breaking — nothing
  that exists behaves differently until the new task is run. `/t4:sync-sdlc` lists them; take
  them and run it again to get `/t4:analyse`.

## 0.24.0 — 2026-09-17
- **`ai/runs/log.csv` no longer blocks `git checkout`.** The Stop hook wrote one row into the
  tracked file after every turn, so it was dirty for the whole session, every branch switch was
  refused ("Your local changes … would be overwritten by checkout"), and two branches' rows
  conflicted on merge. `session-stop.js` now appends to `ai/runs/log.pending.csv` (gitignored);
  a new PreToolUse Bash hook, `log-flush.js`, moves those rows into `log.csv` and stages it when
  the session runs `git commit` — and only then; a dry run or any other command leaves them.
  The log changes inside the commit that produced the work, which is where the `accepted`
  column was always meant to be filled.
- `make log-flush` does the same move for a commit made from a terminal; rows never flushed
  simply wait for the next commit.
- The schema guard moved out of `session-stop.js` into `scripts/_log-schema.js`, required by
  both plugin-side scripts. The headless writer keeps its byte-identical copy;
  `check-log-schema.sh` now diffs against the module, asserts the Stop hook carries no copy of
  its own, and gains the flush cases: not on `git status`, not on `--dry-run`, once per commit,
  staged, and a pre-schema `log.csv` migrated when the flush reaches it.
- Adopted repos: add `ai/runs/log.pending.csv` to `.gitignore` and `ai/runs/log.csv merge=union`
  to `.gitattributes` (both listed in the ai-hooks skill; `/t4:adopt-sdlc` step 5 writes them
  for a new repo). Until the plugin is updated and the session restarted, the old hook keeps
  writing straight into `log.csv`.

## 0.23.0 — 2026-09-07
- **The plugin's own repo is recognised again once the plugin is installed.** `isPluginItself`
  compared repo-root to plugin-root, which is only equal while the plugin runs from its working
  tree. Installed, plugin-root is the cache, the paths differ, and the source repo looked like
  an ordinary adopter. Both `manifest.js` and `/t4:doctor` now test identity — a repo carrying
  this plugin's own name in its own `plugin.json` **is** this plugin — and keep the path
  comparison as the fast case.
- **What that cost, found by running `/t4:doctor` for the first time from a real install:** it
  reported "no `ai/.sdlc.json` — start a baseline" in the plugin's own repo, and following that
  advice wrote a manifest into it. `check-manifest.sh` asserts that never happens; the invariant
  was intact and the test could not see the case, because it passed the same path for both
  arguments.
- Both tests now cover the installed shape: `check-manifest.sh` runs `write` with the plugin
  copied elsewhere, and `check-doctor.sh` gains a ninth case for the same. Each verified by
  reverting its fix and watching the suite fail.
- `check-manifest.sh` cleans up in its trap rather than inline. A failing assertion exits before
  any cleanup after it, so the test that provoked a manifest into this repo was leaving it there
  — a test that fails dirty makes the next run's result meaningless.

## 0.22.0 — 2026-09-07
- **`/t4:doctor` now says when your install is behind.** It compared a repo against whichever
  plugin it was handed and never looked at whether that plugin was current, so a repo could be
  perfectly in step with an install several releases old and report entirely green. That is the
  exact invisible state the command exists for, and it was blind to it. `specs/0002` AC13.
- **It compares against the marketplace copy already on disk, not the remote**, and says so in
  the message. "Behind what you have fetched" is a smaller claim than "behind the world", it
  needs no network, and conflating the two would make the command lie on a stale clone.
  `specs/0002` AC14.
- Version comparison is numeric per component, not lexical. The fixture uses 0.9.0 against
  0.10.0 for that reason: a string comparison calls 0.9.0 the newer, and would have reported a
  behind install as current. Verified by replacing the comparison with `<` and watching the
  fixture fail.
- `check-doctor.sh` is now eight cases, adding update-available, up-to-date, and no-marketplace.
- `specs/0001` AC4 and AC5 said the session "asks how to proceed" when a key does not resolve.
  Impossible on the path AC4 itself names — `make ai` runs with no session behind it — so both
  now say report and write nothing, asking only where there is someone to ask. Wording only;
  the behaviour has been report-and-stop since 0.19.0.

## 0.21.0 — 2026-09-07
- **`/t4:setup-tracker`** — points a repo at a tracker and proves it, so turning `specs/0001`
  on no longer means knowing a filename, a key and its exact shape from reading a design
  document. Detects the reachable site, shows it, asks before writing, writes `base_url` and
  nothing else, then resolves one key to demonstrate the result works. Implements
  `specs/0003-tracker-setup.md`.
- **It refuses before it reads or writes.** No `ai/docs/tracker.md` means the layout predates
  tracker support, and it will not create that file — it is a template, and a local copy would
  fork from the one that ships. A non-interactive run stops rather than proceeding on assumed
  answers: a config written from guesses is worse than none, because the repo then looks
  configured.
- **It will not silently replace an existing `ai/jira.yaml`.** That file is hand-owned and
  deliberately outside `dont-touch.md`, so a second confirmation is required and the current
  contents are shown first.
- **Committing it is a choice, and the cost of not committing is stated when you make it.**
  Choosing `.gitignore` leaves the repo configured for one developer: a teammate who clones it
  gets the unconfigured behaviour, so `/t4:spec ABC-12` means different things to different
  people on one team. That is allowed; being surprised by it is not.
- **Writing the file is not evidence it works.** With a key it resolves one and reports what
  came back; with none it says the configuration is unverified and names what would verify it.
- **Nothing is written to the tracker** — checked against a real ticket rather than asserted:
  comments, status, resolution, labels and the `updated` timestamp all unchanged after the
  work, the timestamp being the one Jira moves on any field write.
- **Not yet proved:** the unreachable-tracker path (`specs/0003` AC4). Every other criterion
  ran. That one needs a session where the connector is unavailable, and manufacturing it costs
  a re-authorisation, so it waits for a session already in that state.

## 0.20.0 — 2026-09-07
- **`/t4:doctor`** — one read-only command that reports what is wrong with a repo's setup and
  the command that fixes each thing. Layout, adapters against tasks, the version the repo
  records against the one the session loaded, drift, where the plugin is installed, and whether
  older cached copies are still around. Implements `specs/0002-t4-doctor.md`.
- **It never fixes anything, and that is the point.** Every remedy is a command you run. Being
  read-only is what makes it safe as the *first* thing you try, before you know what is wrong —
  and it always exits 0, so it stays usable in CI. A doctor that fails the build when it finds
  something is a doctor nobody runs.
- **It reports the two things that are hardest to work out by hand:** a plugin installed for a
  different project than the one you are in, and older cached copies that a session which has
  not restarted may still be running. Both took several rounds of manual digging to identify
  while building the tracker work; both are now one line each.
- **The one thing it cannot report is in `docs/workflow.md` instead.** If `/t4:doctor` does not
  exist in a repo, the plugin is not enabled there — and no command can say so, because in that
  repo none of them are there to run. Its absence is the diagnosis.
- Names are read from the plugin's own manifest rather than hardcoded, because this plugin and
  its marketplace have each been renamed more than once; a check pinned to a literal handle
  would have been wrong three renames ago.
- `check-doctor.sh` covers five cases — no layout, no manifest, behind the templates, healthy,
  and no config directory at all — each verified by breaking the doctor rather than by passing.
- **Known gap, recorded in `ai/plans/0002`:** the doctor compares a repo against the plugin it
  was handed and never says a newer release exists. A repo pinned to an older install therefore
  reports green while a newer version sits published. Closing it needs a new acceptance
  criterion, not a quiet addition.

## 0.19.0 — 2026-09-07
- **`/t4:spec` can draft from a tracker ticket.** In a repo that has committed `ai/jira.yaml`,
  `/t4:spec ABC-12` resolves the key and specs the ticket, recording it as a vendor-neutral
  `Ticket: ABC-12` line under the title so later work can find its way back. Implements
  `specs/0001-spec-accepts-a-ticket-key.md`; decided in `docs/adr/0004`, `0005` and `0006`.
- **Off unless you turn it on, and the gate is configuration — never the shape of what you
  typed.** A repo with no `ai/jira.yaml` behaves exactly as it did before: `/t4:spec UTF-8`
  specs UTF-8. That matters because `UTF-8`, `ISO-8601` and `RFC-7231` all match a ticket-key
  pattern end to end, so keying off the argument would have made a repo with no tracker stop
  and ask about a ticket that cannot exist.
- **A repo without a tracker cannot tell this shipped — including from what the session says.**
  The first real run failed exactly there: the artefact was right, but the report announced
  that `ai/jira.yaml` was missing, which told a repo that had configured nothing that a
  mechanism existed. A report is output. `argument-hint` is unchanged for the same reason: the
  command menu is output too.
- **Criteria come from the ticket's description and nothing else**, and what the description
  leaves implicit becomes an Open question rather than an invented Given/When/Then. Proved
  against a real ticket whose entire description was one sentence: one criterion, nine open
  questions. Eight plausible criteria would have looked more useful and been a fabrication.
- **New template: `ai/docs/tracker.md`** — the one file allowed to name a vendor, a connector,
  a URL or a config filename. `check-adapters.sh` now fails if any of those reach a task prompt
  or a generated command.
- **`ai/jira.yaml` is deliberately not in `dont-touch.md`.** Everything on that list is
  generated or secret; this is hand-written config a developer must author, and the guard
  blocks edits outright — listing it would stop a session creating the file that turns the
  feature on.
- **Nothing writes to a tracker.** `docs/adr/0006` allows comments and gates transitions behind
  a seam arm that does not exist yet; neither is built. Setup and resolution read only.
- **Blast radius: every adopted repo**, on its next sync, receives `ai/docs/tracker.md` and
  gains nothing else until it writes `ai/jira.yaml`. Outside Claude Code — Codex, and headless
  `make ai` — a key cannot be resolved at all until `ai/make/jira.sh` exists, and the task
  stops and says so rather than guessing.

## 0.18.0 — 2026-09-07
- **`make ai` never ran a task under `claude`.** `ai.mk` passed the prompt as an argument —
  `claude -p "$(cat $PF)"` — and every task file opens with YAML frontmatter, so the CLI read
  `---` as an option and exited before starting. The prompt now goes in on stdin, which is
  what the Codex branch has always done. Found by running the acceptance criteria of
  `specs/0001` for real; reproduced with `chore`, so it was never specific to one task.
- **And it reported that failure as success.** The recipe ran on regardless: it printed
  `run saved`, appended a row to `ai/runs/log.csv` for a run that never happened, and exited
  0. CI would have gone green on an empty file. `make ai` now exits non-zero when the tool
  fails or writes nothing, says how many bytes it got, and logs no row — a failed run is not
  a run. `make review` inherits this, since it chains on `&&`.
- **Blast radius: every adopted repo, but not automatically.** `ai/make/ai.mk` is a template,
  and `/t4:sync-sdlc` regenerates adapters without touching `ai/`, so a repo keeps its broken
  copy until it takes the drift the sync reports. Any repo relying on `make ai` or
  `make review` in CI should take this one.

## 0.17.0 — 2026-09-07
- **`/t4:step` is now `/t4:run`.** `ai/tasks/step.md` becomes `ai/tasks/run.md`; the task
  itself is unchanged. Breaking for anyone with the old command in a script or a habit.
- The word "step" stays everywhere it means a step *within* a plan, which is most places:
  the description is still "Implement one step of a plan", the argument hint is still
  `<plan path> <step>`, and `/t4:plan` still writes `- [ ] Step N — …`. Only the command
  moved. Two sentences were reworded to avoid "`/t4:run` run".
- Past CHANGELOG entries keep saying `/t4:step`, unlike the org and plugin renames where
  the records were rewritten. Rewriting here would turn "tasks renamed explore, step, fix,
  check" in the 0.5.0 entry into a claim about a rename that happened today, and "step" is
  an ordinary word in those sentences rather than a name being retired.
- The stale `step` adapters were removed by the sync fix shipped in 0.16.0 — first real
  exercise of it.

## 0.16.0 — 2026-09-07
- **Sync removes the commands it generated under older naming.** Cleanup matched
  `ai-<task>.md` and `t4/<task>.md` only, so a repo adopted before 0.5.0 kept its bare
  `.claude/commands/spec.md` through every sync and answered both `/spec` and `/t4:spec` —
  the same task twice, under two names, one of them pointing at a task file that may no
  longer exist. Found in a repo scaffolded at ai-base 0.1.2.
- **Ours is identified by the include, not by the name.** A generated command carries
  `@../../ai/tasks/<name>.md`; a hand-written one does not. Matching on that is what makes
  deleting safe — a name glob wide enough to catch `spec.md` would also delete a command
  someone wrote themselves and called `spec.md`. Codex skills are matched the same way, by
  the `ai/tasks/` path in the skill body.
- Pinned by a test that reproduces the case: a pre-0.5.0 bare command, a 0.5.0-era `ai-`
  command and a stale codex skill must all go, and a hand-written `spec-of-mine.md` must
  survive. Verified by restoring the old glob, which fails it.

## 0.15.0 — 2026-09-07
- **The marketplace is `sdlc`; the handle is `t4@sdlc`.** A handle reads
  `<plugin>@<marketplace>`, so this renames the marketplace only. The plugin stays `t4` —
  its name is what makes the commands `/t4:`, and renaming it would take them with it.
  0.13.0 had both called `t4`, which worked but read as a stutter and hid which half meant
  what.
- The marketplace now matches the git project it is served from, `ai/sdlc.git`, so the name
  in the manifest and the name in the URL finally agree.
- Unchanged: the org is still `t4 platform`, the plugin is still `t4`, the repo is still
  `ai-sdlc`, and the `/plugin marketplace add` line is the same
  as before. Only the handle's right-hand side moved.
- The 0.13.0 entry's claim that "plugin and marketplace share a name" was left in place as a
  sentence but is no longer true, so it is removed there rather than left to mislead.

## 0.14.0 — 2026-09-07
- **A task that needs input now asks for it.** Every task ended with a label — `Feature:
  $ARGUMENTS`, `Bug: $ARGUMENTS` — and an empty invocation left a dangling colon, which a
  session fills in by guessing: a feature inferred from the branch name, a bug it went
  looking for, the newest spec assumed to be the one you meant. The nine tasks that require
  input now say what to do when they get none, and say it specifically — `/t4:plan` lists the
  paths in `specs/` rather than assuming the newest, `/t4:step` names the unticked steps
  rather than starting one.
- **`/t4:check` and `/t4:fleet` deliberately do not ask.** Both work with no argument by
  design — check reviews the branch diff, fleet maps the whole repo — so a prompt would be an
  obstacle rather than a safeguard. Their input is marked optional with brackets instead.
- **`argument-hint` reaches the command menu.** Each task declares one and
  `sync-adapters.sh` copies it into the generated command, so the expected input is visible
  before running rather than discovered by running. A task with no hint gets no empty one.
- Two assertions pin this, both verified by breaking them: a task whose hint says it takes
  input must carry the prompt, and the generated command's hint must match its task's. The
  first catches a task that gains an argument without gaining the question; the second
  catches a generator that quietly stops propagating.
- Codex needs no separate handling — its skills point at `ai/tasks/<name>.md` rather than
  copying it, so the prompt arrives with the task.

## 0.13.0 — 2026-09-07
- **Every command lives under `/t4:`.** The eleven project tasks become `/t4:spec`,
  `/t4:plan`, `/t4:step` and so on; the plugin's two become `/t4:adopt-sdlc` and
  `/t4:sync-sdlc`. Reinstall with `/plugin install t4@sdlc`.
- **The plugin is named `t4`.** That is not cosmetic: a plugin's command namespace *is* its
  name, so `/t4:adopt-sdlc` is only reachable by renaming the plugin. The repo stays
  `ai-sdlc`.
- **The project commands are namespaced by directory, not by prefix.** `sync-adapters.sh`
  now writes `.claude/commands/t4/<task>.md` instead of `.claude/commands/ai-<task>.md`,
  because a subdirectory under `.claude/commands/` is what Claude Code reads as a namespace.
  That puts the generated file one level deeper, so its `@` include needed another `../` —
  a wrong depth still generates a perfectly valid-looking command that silently includes
  nothing, so `check-adapters.sh` now resolves every include and asserts it lands on the task
  file. Verified by reverting the depth: it fails.
- **Codex skills read `t4-<task>`, not `t4:<task>`.** Codex skill names are invoked as
  `/name` and take no colon, so the two tools differ here by necessity: `/t4:spec` under
  Claude Code, `/t4-spec` under Codex.
- **`/t4:explore` is now project-only.** The plugin shipped its own `explore` for repos with
  no `ai/` layout, and under one namespace it collided head-on with the task of the same
  name. The plugin copy is removed and the project one keeps the plain verb, so exploring a
  repo now requires adopting the layout first — the one capability this release drops.
  `README.md` and `docs/workflow.md` no longer offer it.

## 0.12.0 — 2026-09-07
- **The plugin is `ai-sdlc` again, not `sdlc`.** Breaking twice over: the handle is now
  `ai-sdlc@t4`, and every command moves namespace — `/sdlc:adopt` `/sdlc:explore` `/sdlc:sync`
  become `/t4:adopt-sdlc` `/t4:explore` `/t4:sync-sdlc`. Reinstall with
  `/plugin install ai-sdlc@t4`. This undoes the rename made in 0.5.0; plugin and repo name
  now agree again.
- The eleven project commands are untouched — they are generated from `ai/tasks/` into each
  repo and were already `/ai-*`, never namespaced by the plugin.
- **`ai/.sdlc.json` keeps its name.** The drift manifest is plumbing, not the handle, and
  every adopted repo already has one; renaming it would make `manifest.js` miss the file and
  report a fresh repo, silently losing each repo's drift baseline. The prose around it now
  says ai-sdlc while the filename does not — a deliberate seam, not an oversight.
- The git remote is unchanged. The GitLab project keeps
  the short name; only the plugin was renamed.
- Records were rewritten rather than left standing, matching the choice made for the org
  rename in 0.11.0. Two entries now assert things that were never true, and are left that
  way knowingly: 0.5.0 reads "Plugin renamed `ai-sdlc`" when it was in fact renamed *from*
  that to `sdlc`, and 0.11.0 offers `ai-sdlc@n6` and `ai-sdlc@t4`, handles that did not
  exist at the time it describes. History here records the current naming, not the naming
  in force on the day.

## 0.11.0 — 2026-09-07
- **The marketplace is now `t4`, not `n6`.** Breaking for anyone who installed by handle:
  `ai-sdlc@n6` no longer resolves. Re-point with `/plugin marketplace remove n6`, then
  `/plugin marketplace add <repo URL>` and `/plugin install ai-sdlc@t4`.
  The git remote is unchanged — only the marketplace handle and the org name moved.
- The rename is total: manifests, install instructions, the owner and author fields, the
  LICENSE holder, and the earlier changelog entry that named the old org. Outside this entry
  the old name survives nowhere, which is what a straight org rename calls for. Two things
  that follow from it and are easy to miss: rewriting the earlier entry edits a record of
  what was true at the time rather than noting a change on top of it, and this entry has to
  keep naming the old handle, because migration instructions are useless without it.

## 0.10.0 — 2026-09-07
- **The log guard measures every row, not just the header.** 0.7.0 moved a log.csv aside when
  its header was not the current one, which catches a file that predates the schema but not a
  writer that appends into a current one. An older hook still installed elsewhere kept writing
  12-field rows under the 16-field header for an entire session, and nothing noticed: the
  header it was checked against still matched. Both writers now check each row's width and move
  only the rows that fail, under a dated comment saying why. Rows are still never reinterpreted
  into the new columns — width cannot say which writer produced a row, and guessing is what
  caused the mixed-schema bug in the first place.
- **Field counting is quote-aware.** `csv()` quotes any value holding a comma or a newline, so
  counting commas would have quarantined a valid row whose `user` is `"Doe, Jane"`, and torn a
  row with an embedded newline into two malformed halves. Records are split on quote state and
  an unclosed quote is treated as unmeasurable rather than counted as some width.
- The guard is duplicated in both writers for the same reason `HEADER` is — they run from
  different places and cannot share a module — so `fixtures/check-log-schema.sh` now diffs the
  two copies and fails on drift. Three new cases cover a short row under a matching header, a
  quoted comma surviving, and the headless writer guarding the same way. Each was verified to
  fail with the guard removed, the quote handling removed, and the copies drifted — not just
  to pass today.

## 0.9.0 — 2026-09-06
- **Codex support.** `sync-adapters.sh` now generates `.codex/skills/` beside `.claude/` and
  `.cursor/`, so the same eleven tasks are slash commands in Codex. Verified against Codex
  0.153.4: `.codex/skills/` is picked up with no configuration. The skills point at
  `ai/tasks/<name>.md` rather than copying it, so there is still one source of truth.
- **Agents are inlined under Codex, and say so.** Codex plugin manifests support only
  `skills` and `mcpServers` — no subagents — so the four agent-backed tasks (`check`, `test`,
  `design`, `adr`) tell the session to follow `ai/agents/<name>.md` itself. The generated
  skill states the cost plainly: a tester that has seen the implementation writes tests that
  restate it, and a reviewer that wrote the code is not an independent review.
- **`make ai TOOL=codex`.** `ai.mk` builds the invocation per tool — `codex exec --json` with
  the prompt on stdin and the final message via `-o`, versus `claude -p --output-format json`.
  `log.js` sniffs which shape it was given; `gate.js` reads Codex's `-o` file. Both parsers
  were written from real captured output, not from assumption.
- Codex reports **no cost**, so `cost_usd` stays empty for its rows rather than being guessed,
  and its `input_tokens` include cached tokens (the OpenAI convention), which `log.js`
  subtracts back out so the column means the same thing in every row.
- `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` ship for Codex-native
  discovery. Codex also reads the `.claude-plugin/` manifests — confirmed by test — so these
  are belt-and-braces rather than required.
- **`skills/ai-layout/scripts/check-versions.sh`** asserts every manifest carrying a version
  agrees. It caught a real drift on its first run. Definition of done item 3 now points at it
  instead of asking a human to remember.
- `skills/ai-layout/scripts/check-adapters.sh` asserts all three adapter sets are generated,
  that the inline-agent note appears exactly where a task delegates and nowhere else, and that
  a second sync changes nothing. Verified to fail when the generator drifts either way.
- `.codex/` is in the template `dont-touch.md` — it is generated, like `.claude/` and `.cursor/`.
- **Not supported under Codex:** hooks. No session or edit log, no cost row, and **no
  dont-touch guard** — `docs/workflow.md` says so in those words.

## 0.8.0 — 2026-09-06
- **Layout drift detection.** `/t4:adopt-sdlc` now writes `ai/.sdlc.json` recording which ai-sdlc
  version a repo received and a hash per file; `/t4:sync-sdlc` compares it against the installed
  templates and reports six states — upstream changed (safe to take), both changed (merge by
  hand), locally modified, new upstream, removed upstream, missing locally — plus a version
  comparison. Before this an adopted repo had no way to learn it was behind, and `/t4:sync-sdlc`
  regenerated adapters without comparing anything. Implements
  `ai/designs/0001-layout-version-and-drift.md`; decisions in `docs/adr/0001`-`0003`.
- **Two hashes per file, not one.** The design sketched a single hash, which cannot work:
  adopt substitutes `{{app}}`, `{{stack}}` and friends, so a repo file never equals its
  template and every substituted file would report as modified forever. The manifest records
  `received` (what landed in the repo) and `template` (what it came from).
- `/t4:sync-sdlc` still changes nothing under `ai/` — it reports, and taking an upstream change
  stays a separate reviewable edit. A repo with no manifest is told how to start a baseline
  rather than treated as an error, and a manifest with a newer `schema` stops the check
  instead of being misread.
- `ai/.sdlc.json` is listed in the template `ai/docs/dont-touch.md`, so `guard-paths.js`
  blocks hand edits — a manifest edited by hand makes the check lie.
- `skills/ai-layout/scripts/check-manifest.sh` covers all six drift states, version drift,
  the migration path, the schema guard, that `check` never mutates the repo, and that the
  plugin's own repo never gets a manifest.

## 0.7.1 — 2026-09-06
- Drop the last two uses of "ai-base", the name this plugin left behind in 0.2.0:
  `skills/ai-layout/templates/specs/0000-scaffold.md`, which every adopted repo receives as
  its first spec, and the `hooks/hooks.json` description. Both now say `ai-sdlc`, matching
  the templates.

## 0.7.0 — 2026-09-06
- **`ai/runs/log.csv` has one schema.** Two writers were appending rows with different
  column meanings to the same file: the Stop hook wrote
  `ts,session_id,user,branch,turns,…` while `ai/make/log.js` wrote
  `ts,run_id,task,tool,model,…`. Any reader of a repo that used both got nonsense, and only
  headless runs recorded the model. Both now write the same 16 columns —
  `ts,session_id,source,user,branch,task,tool,model,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted`
  — with `source` naming the writer (`session` or `make`) and each blanking what it cannot
  know. Fields are CSV-quoted, so a branch or model containing a comma no longer shifts
  every later column.
- **Migration is automatic and lossless.** A log.csv with any other header has its rows
  moved to `ai/runs/log.previous.csv` on the next write, and a clean file started. Old rows
  are not reinterpreted — they came from two writers and cannot be told apart safely.
- **`skills/ai-hooks/fixtures/check-log-schema.sh`** pins the two declarations together: the
  writers must agree, every row must match the header width, and migration must preserve the
  old rows. Verified to fail when the headers are made to drift.

## 0.6.0 — 2026-09-06
- **Any model, any provider.** `ai/models.yaml` now ships blank, meaning "whatever the tool
  is already configured with", and `make ai` passes no `--model` at all unless a value is
  set — so a pinned alias is never required and no endpoint is assumed. Commented examples
  cover a plain model id and a gateway alias. `CMD ?= claude` makes the binary overridable.
- **Costs are priced by the model that actually ran.** The session-stop hook reads the model
  from the transcript and matches `pricing:` by exact id, then by longest id prefix (so
  `claude-haiku-4-5` covers `claude-haiku-4-5-20251001`), then `default`. Previously every
  run was costed at one hardcoded Anthropic rate. No match still writes `~` for an estimate.
- **`make ai` was broken and never invoked a model at all** — pre-existing, since before the
  0.5.x work. The recipe embedded a blank line and two unindented lines inside the prompt
  string, and a makefile recipe ends at the first line without a leading tab, so everything
  from `claude -p` onward was parsed as makefile text rather than run. `make review`
  inherited the failure. The prompt is now assembled into a temp file on tab-indented
  continuation lines.
- **`make review` corrupted diffs containing `$`.** The diff was routed through a make
  variable, which re-expands `$`; it now goes to a file passed as `INPUT_FILE`, byte for
  byte. `INPUT_FILE=<path>` works for any task.
- No t4-specific configuration remains in the templates: the AGENTS.md setup section names
  no provider, and `ai/docs/architecture.md` no longer claims a LiteLLM proxy resolves aliases.

## 0.5.1 — 2026-09-06
- **Standalone.** The plugin names, reads and version-pins no other repo. There was never a
  functional dependency — no package manager, lockfile, submodule or out-of-repo path, and
  the hooks use the Node standard library only — but eight documents named the framework
  scaffold repos and pinned their versions, most of it written into `ai/docs/fleet.md` by
  the first `/t4:fleet` run reading sibling checkouts off disk. Consumers are now described
  generically: overlay plugins and adopted repos, named nowhere.
- `ai/docs/fleet.md` is scoped to this repo alone, its **Consumes** column deliberately
  empty, with the one-way dependency written into Boundaries so `/t4:design review` enforces
  it on future plans.

## 0.5.0 — 2026-09-06
- New `architect` agent: decides where a capability belongs across services, what contract
  it exposes and who owns the data. Writes design docs and ADRs only — never source, specs
  or plans; changes to other context docs are proposed as replacement text, not applied.
- New `/t4:design`: the capability's home, its contracts and its data ownership, before any
  spec. Output in `ai/designs/`, ending with the `/t4:adr` and `/t4:spec` lines to run.
  `/t4:design review <plan>` checks a plan for architectural fit and emits the same JSON
  shape the reviewer does, so `ai/make/gate.js` reads it unchanged.
  Use it only when a capability spans services or changes a contract between them —
  `/t4:explore` still decides how to build a feature inside one repo.
- New `/t4:adr`: writes `docs/adr/NNNN-slug.md`. Three documents already required an ADR for
  every new dependency and nothing in the loop produced one; now something does.
- New `ai/docs/fleet.md` — the service map the architect reads — and **`/t4:fleet`, which
  fills it in**: it detects what it can from the repo (remotes, manifests, compose and k8s
  files, routes, queue names, CODEOWNERS) and asks you for the rest, offering what it
  detected as the default. It refreshes rather than overwrites, and asks nothing in a
  non-interactive `make ai` run. The map ships scoped to the project with this repo as its
  only row.
- Definition of done gains item 7: a change crossing a service boundary or changing a
  contract has a design doc, an ADR, and an up-to-date fleet map.
- New overlay slot `{{fleet_extra}}`.
- **Adopted repos: run `/t4:sync-sdlc` for the three new commands, then `/t4:fleet` once** —
  until it runs, `ai/docs/fleet.md` is the unfilled default and `/t4:design` will say so.

## 0.4.0 — 2026-09-06
- New `tester` agent and `/t4:test` task: writes acceptance tests from the spec's ACs,
  reading the implementation's public surface only and never the diff, so tests are not
  shaped by the code they check. Modes `red` (before `/t4:step`, ACs must fail first) and
  `gaps` (after, close uncovered ACs). Writes test files only; never production code.
- Loop is now `/t4:explore → /t4:spec → /t4:plan → /t4:test red → /t4:step → /t4:test gaps → /t4:check`.
- `sync-adapters.sh`: `shopt -s nullglob` — a repo with no `ai/skills/*/` subdirectory
  previously created a directory literally named `.claude/skills/*`. Agent symlinks now
  loop over `ai/agents/*.md` instead of hardcoding the reviewer, so a new agent needs no
  script change. **Adopted repos should run `/t4:sync-sdlc`.**
- Definition-of-done item 2 now names `/t4:test` as the source of AC tests.
- ai-sdlc adopts its own `ai/` layout, symlinked to `skills/ai-layout/templates/`.

## 0.3.0 — 2026-09-06
- Plugin renamed `ai-sdlc` (repo stays ai-sdlc). Commands: `/t4:adopt-sdlc` (was init), `/t4:explore` (was investigate), `/t4:sync-sdlc`.
- Project commands now prefixed `ai-`: `/t4:explore /t4:spec /t4:plan /t4:step /t4:fix /t4:chore /t4:check` (tasks renamed explore, step, fix, check; `/review` collided with a Claude Code built-in). `ai/investigations/` → `ai/explorations/`.

## 0.2.0 — 2026-09-06
- Renamed from ai-base and split: Next.js pieces moved to the nextjs-scaffold plugin; NestJS lives in nestjs-scaffold.
- New `/t4:explore` command + task: 2–4 implementation options with trade-offs before a spec; output in `ai/explorations/`.
- New `/t4:adopt-sdlc` command: add the ai/ layout to an existing repo without a framework scaffold.
- `/ai-sync` renamed `/t4:sync-sdlc`; guards against repos without `ai/`.
- Generic templates are framework-neutral with `{{…_extra}}` slots overlays fill.

## 0.1.2 / 0.1.1 / 0.1.0 — 2026-09-05 (as ai-base)
- Initial layout, hooks, reviewer; skills hidden from the slash menu; sync guard.
