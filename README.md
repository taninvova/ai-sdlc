# ai-sdlc — T4 AI SDLC core plugin (repo: ai-sdlc)

The operating-model half of AI-native delivery, as a Claude Code and Codex plugin. Standalone: it depends on no other repo and adds no runtime dependency. Framework-neutral — overlay plugins build on it by filling the `{{…_extra}}` slots in its templates.

**[ai-factory/docs/workflow.md](ai-factory/docs/workflow.md) — how to install it, what each command is for, and the order to run them in.**

## Workspace and runtime

All plugin-owned project work lives in `ai-factory/`, including local Git rules and scratch
under `ai-factory/runs/tmp/`. Adoption preserves existing root and host files. It delivers full
agent procedures and detects verification commands without assuming a JavaScript stack.
Node, Bash, Git and a configured AI CLI are host prerequisites; no npm package or external
integration is required. Use `make -f ai-factory/make/ai.mk ai TASK=quick INPUT="..."` without a root Makefile.
The file-edit guard is defense in depth; arbitrary shell commands remain governed by the host sandbox.

## Commands
- `/t4:start <request>` — choose an existing workflow, explain the choice, and hand off once (Codex: `$t4-start`)
- `/t4:continue <delivery id>` — resume a contracts-enabled planned delivery: explain its next evidence-backed action and run that one task (Codex: `$t4-continue`)
- `/t4:quick` — complete a small, well-understood change with focused checks and a labeled self-review
- `/t4:adopt-sdlc` — add the `ai-factory/` layout to an existing repo (any stack)
- `/t4:doctor` — report what is wrong with this repo's setup and the command that fixes each thing. Read-only; run it first
- `/t4:state` — list the specs and plans still outstanding here, each outstanding plan shown with its incomplete steps. `--done` lists only finished items; `--next` names the one to pick up, by git commit date; `--delivery <id>` shows one contract delivery's evidence-derived status instead (see [Delivery status](#delivery-status)). Read-only; it lists the work and never starts any
- `/t4:setup-tracker` — point this repo at a tracker so `/t4:spec ABC-12` works, and prove it by resolving a key. Optional; skip it and nothing changes
- `/t4:setup-knowledge` — declare an external documentation source (an MCP server already attached to your session) for the agents to consult, and prove it answers. Optional; `/t4:adopt-sdlc` offers it once, and the repo's own `ai-factory/docs/` stays the primary knowledge base
- `/t4:sync-sdlc` — inspect workspace drift; generate selected host pointers only when explicitly requested

`/t4:migrate-layout`, which moved a repo adopted before 1.0.0 onto `ai-factory/`, was **removed in 2.1.0**. A repo that never ran it runs it from an ai-sdlc checkout at 2.0.0 or earlier; its hooks keep working until then, because the fallback to the old directory name stays until 3.0.0.

Claude Code and Codex use the same canonical task files. The plugin ships all 22 Claude
slash commands and the matching Codex workflow skills; strict mode needs no project
pointers for built-in tasks. Explicit `--adapters=claude` sync removes old generated
pointers for native commands and creates pointers only for project-specific tasks.
Other host adapters remain opt-in. See [workflow](ai-factory/docs/workflow.md).

`/t4:spec` also accepts a tracker ticket key — `/t4:spec ABC-12` — in a repo that has
committed `ai-factory/jira.yaml`. Off by default: without that file nothing changes, whatever you type.

A repo can also declare a read-only knowledge source — an MCP server the developer's tool has
attached, or a knowledge base — in `ai-factory/knowledge_base.md`. The explorer, specifier, planner,
analyst, architect and reviewer agents then read it and cite what they used as external and
unverified; an unreachable source is one report line, never a halt. `ai-factory/docs/knowledge.md` is the
only file that knows how; a repo that declares nothing sees nothing.

Native project-workflow commands: `/t4:fleet /t4:design /t4:adr /t4:analyse /t4:explore /t4:spec /t4:plan /t4:test /t4:run /t4:fix /t4:chore /t4:check /t4:report`, plus `/t4:quick` listed above. Each loads the matching `ai-factory/tasks/<name>.md` from the user's repo, preserving project customizations. The commands are discoverable immediately after plugin installation; executing a project task requires an adopted workspace.

### Start with a request

Use `/t4:start Change the setup heading to Installation` or `$t4-start` with the same request.
Start classifies into `quick`, `fix`, `chore`, `analyse`, `design`, `explore` or `spec` and hands
original request text to that project procedure. It considers uncertainty and risk before size;
a one-line authorization or public-contract change still needs the normal workflow. Existing
artifacts can settle prerequisites. Start does not resume a delivery or chain its remaining phases.
All direct commands remain available.

Start is interactive-only: headless `TASK=start` stops before launching a CLI or creating run
artifacts. CI must name a destination task. Empty input asks for the change and expected result;
missing workspace or task reports adoption/drift guidance without silently generating adapters.

With model routing enabled, a configured start worker only classifies with read-only permissions.
The session validates its result and independently dispatches the destination with that task's
model policy. A start model never becomes the destination override. Concrete
`--task-model=<id>` start overrides are rejected because generic override workers cannot enforce
the read-only profile; configure `routing.tasks.start.<host>`, explicitly sync routing adapters
and restart, or use `--task-model=inherit` for session classification. Direct task overrides keep
their existing behavior. Input options are parsed once; retained flags and quoted/multiline text
are task data. Clarification answers accompany the unchanged request as separate context.

### Continue a delivery

Use `/t4:continue d-20261005-1a2b3c` or `$t4-continue d-20261005-1a2b3c` to pick an interrupted
delivery back up. The input is one artifact-contract delivery ID (`d-YYYYMMDD-xxxxxx`, from the
spec's `.contract.json`) for a planned delivery in a repo with contracts enabled. Spec or plan
paths, quick deliveries, unknown IDs and contracts-disabled repos are unsupported and stop with
the reason; empty input asks for the ID. A missing workspace or helper reports adoption or
template-drift guidance and creates no adapters.

`node ai-factory/make/continue.js <id>` inspects read-only: it reuses contract validation and the
completion-report evaluation, runs no verification and writes nothing. It returns one bounded
result — `action`, `question`, `blocked` or `complete` — with a reason, evidence references and an
input fingerprint. The earliest unsatisfied prerequisite wins. Ticks, lifecycle events and refreshed
sidecars are not treated as passed verification. The possible actions, with the destination input
each receives:

| Delivery state | Task | Destination input |
|---|---|---|
| spec with no plan | plan | `<spec>` |
| first unfinished step declares red and has no red evidence | test | `<spec> <plan> red S<N>` |
| first unfinished step (also when interrupted or part-done) | run | `<plan> S<N>` |
| all steps done, gaps testing answered not run | test | `<spec> <plan> gaps` |
| gaps testing answered run and a required review is missing, or the recorded review is stale | check | `working-tree <spec> <plan>` |
| evidence ready, no matching completion report | report | `<delivery>` |

Evidence cannot show whether `/t4:test gaps` ran, or whether a started step's declared red run was
skipped on purpose, so continue asks. It passes the answer back as `--answer gaps_tested=yes|no` or
`--answer red:S<N>=proceed`, kept apart from the original input. An answer only chooses between
tasks. It never creates evidence or turns a failure into a pass.

An unfinished step that was interrupted or failed its last run resumes as the same `run` step, and
its changes and evidence are kept. A failed check on finished work returns `blocked` with the
diagnostics, and so do missing, stale or malformed evidence and evaluation gaps that no task can fix. A spec edited after
downstream work (`S_SPEC_CHANGED`) also stops. Continue then names the plan, acceptance tests,
implementation and its verification, and review as possibly affected. The hashes show drift but
not which criteria changed. You reconcile the spec and downstream work yourself, then run continue
again. It never regenerates a plan, rewrites hashes or deletes evidence. `complete` means the report
evaluation is ready and a matching completion report exists. It does not mean merged, deployed or
published.

For an `action`, the session pipes the result to `continue.js handoff`, which validates it, rechecks the
fingerprint and dispatches exactly one destination under that task's own model policy. Changed
inputs, rejection, an unavailable worker, failure or cancellation stop without fallback, and success
stops at the destination's normal boundary. Continue always runs in the invoking session. It takes no
`--task-model` override and ignores any `routing.tasks.continue` mapping, which `/t4:doctor` flags.
Map the destination tasks instead. Headless `TASK=continue` is unsupported. It stops before
launching a CLI or creating run artifacts, so CI names the destination task directly.

### Delivery status

In a repo with artifact contracts enabled, `/t4:state --delivery d-20261006-1a2b3c` (Codex
`$t4-state --delivery d-20261006-1a2b3c`) shows one planned or quick delivery as a two-column
`field`/`value` table. The ID is one contract delivery ID (`d-YYYYMMDD-xxxxxx`, from the
`.contract.json`; `make -f ai-factory/make/ai.mk contracts` lists them). The default listing,
`--done` and `--next` are unchanged, and `--delivery` combines with neither of them.

`state.sh` passes the ID as one literal argument to the workspace's adopted
`ai-factory/make/delivery-status.js`, which collects and evaluates the delivery once in memory
with the same collector and readiness rules as `/t4:report`. Its rows: `delivery`, `kind`,
`progress`, `readiness` (`ready`, `incomplete`, `unverified` or `blocked`), `steps` or `checks`
(ticks, recorded progress only), the criterion groups `verified`, `attested`, `remaining` and
`unknown`, `latest verification`, `review`, `blockers`, `limitations`, and one `source` row per
artifact with its path. `progress` is one of `planning`, `implementation`,
`verification-unproven`, `review-pending`, `ready` or `unknown`. It is derived from artifacts and
evidence, not a claim that an agent is running, and the view names no next action. Attested
criteria stay apart from verified ones. Missing, stale or malformed evidence leaves criteria
`unknown` and is named under `limitations`. A ticked step never proves a criterion.
The `(contracts: …)` note on the `readiness` row is the raw `contracts.js validate` result. That
check ignores completion policy, so it can read `invalid` beside `ready` when a step that could
not run is covered by an allowed attestation (shown as `ATTESTED` under `limitations`).

The latest verification is the non-review record with the latest valid `finished_at`, ties broken
by ascending evidence path. If any record's timestamp is missing or invalid, or an evidence file
cannot be read, the chronology is `unknown`; file times, run logs and the current time are never
used. A missing ID, a malformed ID or path, an unknown ID, a duplicate delivery identity, or
contracts not enabled or unreadable, is refused in one line. A workspace without the helper is told to run
`/t4:sync-sdlc`. Nothing is written, and no tests, review, report or continuation are started.
Worked examples: [workflow, *Delivery status*](ai-factory/docs/workflow.md#delivery-status).

## Skills (model-invoked, hidden from the menu)
- `ai-layout` — the `ai-factory/` directory and its templates; where an AI-related file belongs
- `ai-hooks` — session / edit / test-command / usage logging to `ai-factory/runs/`, and the dont-touch guard

## Agents
- `reviewer` — independent, read-only review of the selected diff; JSON verdict
- `tester` — writes acceptance tests from the spec's ACs, blind to the implementation; test files only
- `architect` — decides where a capability belongs across the services in `ai-factory/docs/fleet.md`; writes design docs and ADRs
- `analyst` — turns a feature description into a requirements pack in `ai-factory/analyses/`, with supplied facts kept apart from assumptions, proposals and open questions; never specs, plans or code
- `explorer`, `specifier`, `planner`, `implementer` — the four loop steps, `/t4:explore` `/t4:spec` `/t4:plan` `/t4:run`, each run in its own agent from its artefacts alone; the session keeps the questions and the report

## Hooks
Registered plugin-wide; no-op in repos without `ai-factory/`; never print to stdout (cache-neutral).
Claude Code uses `hooks/hooks.json`. Codex uses `hooks/codex.json`, once you have reviewed and trusted it in `/hooks`.

- **Dont-touch guard** — blocks edits to the paths in `ai-factory/docs/dont-touch.md`. It checks the real target, including Codex patch targets, rename destinations, symlinks and nested directories. If an adopted repo's policy is missing or malformed, the guard blocks edits instead of allowing them.
- **Run log** — one row per turn and one per concluded subagent, 17 columns. Rows collect in `log.pending.csv` and move into the committed `ai-factory/runs/log.csv` when you `git commit`. The `task` column holds the `/t4:` command, and the `agent` column says which agent spent the tokens. Rows are increments, and a usage record copied into several transcripts is counted once.
- **Session, edit and command logs** — `sessions.jsonl`, `edits.jsonl` (every edited file) and `cmds.jsonl` (test, lint and e2e commands), all local and gitignored.

## Headless runs, review gate and cost
All targets run as `make -f ai-factory/make/ai.mk <target>`; adopted repos need no root Makefile.

- `ai TASK=<task> INPUT="…"` — run any task without an interactive session. `TOOL=claude|codex` picks the CLI.
- `review` — the reviewer, headless. By default it reads staged, unstaged and nonignored untracked changes; `REVIEW_SCOPE=branch` reviews the committed branch instead. The gate is advisory unless `GATE_ENFORCE=1` or the `strict` assurance preset. It then passes only a valid `approve` with no blockers.
- `contracts` — opt-in artifact contracts: validate the spec → plan → evidence chain read-only (`DELIVERY=…`, `REQUIRE=final,review`, `JSON=1`). `verify DELIVERY=… STEP=S<N> PHASE=red|step|final` runs the declared checks without a shell and records the outcome as evidence. Enable with `node ai-factory/make/contracts.js enable`. The step-by-step guide is *Artifact contracts* in `ai-factory/docs/workflow.md`; the full walkthrough and diagnostic table are in the adopted repo's `ai-factory/contracts/README.md`.
- `delivery-report DELIVERY=<id>` — the completion report behind `/t4:report`: `ai-factory/reports/<id>/completion.md` and `.json`, with status `ready`, `incomplete`, `blocked` or `unverified` and every reason tied to its evidence. It only reads; it runs no check and publishes nothing, and its MR description is a draft. Exits 0 only when ready.
- `lifecycle [DELIVERY=<id>] [JSON=1]` — opt-in lifecycle telemetry (`"lifecycle": {"enabled": true}` in `ai-factory/contracts/config.json`). It reports elapsed, waiting and active time, agent effort, retries, outcomes, attributed tokens and priced/unpriced cost per delivery, plus unattributed activity. Missing measurements show as unknown, never zero. `lifecycle-export DELIVERY=<id>` writes the per-delivery export that `/t4:report` reads. `log.csv` and `cost` are unchanged.
- `cost` — token spend from the run log, grouped by task, agent, branch and day. `JSON=1` or `TSV=1` prints the same numbers for other tools.
- `log-flush` — move pending log rows into `log.csv` when you committed from a terminal. `clean-runs` — delete headless run outputs and markers older than 30 days.

Models: an explicit `MODEL=…` wins. Otherwise `ai-factory/models.yaml` applies (with opt-in `routing:`, the task's own entry first; then `review:` for reviews, then the tool's entry), and a blank entry inherits the CLI's own configuration, so any provider or gateway works. Enabled routing also covers interactive tasks: each `/t4:<task>` and `$t4-<task>` dispatches to a generated worker agent pinned to the task's model (`sync-adapters.sh --adapters=routing`, then restart), and stops rather than run on the chat's model when it cannot. Every headless run prints its selection and records it next to its output. The same file holds per-model prices for the run log. Configuration values are passed as data, never as shell, and `CMD` must name a single executable.

## Assurance presets (opt-in)
One setting chooses the checks every delivery needs: `light`, `standard` or `strict`. Without a
selection, nothing changes. The full reference is section 10 of the adopted repo's
`ai-factory/contracts/README.md`.

```
node ai-factory/make/assurance.js show                     # read-only: preset, effective requirements, their sources
node ai-factory/make/assurance.js set standard             # preview only; writes nothing
node ai-factory/make/assurance.js set standard --apply     # enables contracts if needed, then writes ai-factory/assurance.json
node ai-factory/make/assurance.js complete <delivery id>   # exit 0 only when completion may be claimed
```

| | `light` | `standard` | `strict` |
|---|---|---|---|
| Contracts and final verification | not required | required | required |
| Review | labelled self-review | independent, quick, fix and chore included | independent, quick, fix and chore included |
| Review gate | advisory | advisory | enforced |
| Completion | normal task summary | current evidence `ready`; saved report optional | freshly generated report `ready` |

These are reviewable defaults, not settled policy.
- **Minimums.** A preset sets minimums. A stronger existing control (contracts already on, a stricter completion policy,
  `GATE_ENFORCE=1`) is kept and shown as `retained`. `allow_attestation` and `code_scope` stay as configured.
- **`light` removes nothing.** It never deletes contracts configuration or evidence. In a contracts-enabled repo it keeps
  final verification and the configured review requirement, and it never makes a risky request eligible for `/t4:quick`.
- **Advisory is not approval.** Under `standard`, `make review` may exit 0 on a rejection, but completion stays
  non-ready until an approving independent review is recorded.
- **`strict` enforces.** The gate is enforced, and `GATE_ENFORCE=0` is a configuration conflict (`E_GATE_CONFLICT`) that
  stops `make ai` and `make review` before any host launches.
- **Independent review.** Only `make -f ai-factory/make/ai.mk review DELIVERY=<id>` records an `independent` review, run
  headless or from a session you invoked. Routed workers, headless task runs, the reviewer and an interactive
  `/t4:check` report the review as unmet with that command. Review evidence recorded before provenance existed must
  be recorded again.
- **Completion.** `complete` evaluates current evidence and never trusts a saved report. Under `strict` it writes the
  fresh report itself.
- **Selection.** Adoption and `/t4:sync-sdlc` ship `make/assurance.js` but never create, change or remove
  `ai-factory/assurance.json`.

Known limitations:
- Review provenance is a label, not proof: `contracts.recordReview()` accepts `independent` from any caller.
- `/t4:continue` still asks for a saved report before it says `complete`, even under `standard`.
- The changed task procedures have not been exercised in real Claude Code or Codex runs.

## Workflow evaluations (opt-in benchmark)
`skills/ai-layout/scripts/benchmark-small-tasks.js` compares a baseline revision of the task
templates with the current ones on small synthetic fixtures. It is for plugin maintainers. It is never part
of `make check` or adoption. Protocol and earlier results: [small-task benchmark](ai-factory/docs/small-task-benchmark.md).

- **Explicit opt-in.** Without `--real` it refuses and launches nothing. `--real` calls the
  configured Codex CLI and uses model quota. The default selection (five scenarios, three docs repetitions) is 14 calls.
  `--scenarios=a,b` narrows it. `--inline-agents` replays agent procedures in the same session (the Codex inline-agent mode) and labels the report accordingly.
- **Baseline.** `BENCHMARK_BASELINE=<rev>` (default `HEAD`) is resolved to a commit and recorded. With
  `HEAD`, both sides are the same committed workflow: that is a harness smoke run, not evidence of an improvement.
  To compare, name the intended earlier revision.
- **Bounds.** `BENCHMARK_TIMEOUT_MS` (default 150000, at least 1000) stops each run's process
  group. `BENCHMARK_JOBS` (1–4, default 2) caps concurrent runs. Pairs alternate order. Each run gets its
  own Git fixture under `ai-factory/runs/tmp/`. The evaluator rubric
  (`skills/ai-layout/fixtures/workflow-evaluations/rubric.json`) stays outside the fixture and is pinned by digest.
- **One compact smoke run** (two model calls):
  `BENCHMARK_BASELINE=HEAD BENCHMARK_TIMEOUT_MS=150000 BENCHMARK_JOBS=1 node skills/ai-layout/scripts/benchmark-small-tasks.js --real --inline-agents --scenarios=bug`
- **Offline re-summarization.** `node skills/ai-layout/scripts/benchmark-small-tasks.js --summarize=ai-factory/runs/small-task-benchmark-<stamp>`
  rewrites only `summary.md` and `report.json` in that directory, from `records.json` and the optional files
  beside it. It takes no other argument and never launches a model. Rerun it after every edit.

The report gives five metrics per run: missed requirements, escaped defects, unnecessary questions, completion time
and cost. Each metric has its evidence or an explicit `unknown`.
- Requirements are `satisfied`, `unmet` or `unassessed`, decided by harness checks run on the final code after the model exits.
  An escaped defect is a fixture-detected failure after a reported completion, not a production defect.
- Completion comes from the single final line `Completion status: completed|blocked|failed` (prompt protocol 2).
  Runs recorded before that protocol are not comparable. A clean exit alone is not completion, and a timeout is `interrupted`.
- Time and cost are compared only for matched pairs where both runs completed, every requirement is satisfied and there
  are no escaped defects.
  A model, reasoning or provider setting counts as known only when it is pinned in `~/.codex/config.toml`. Anything
  unset makes the pair `unverified`, with no time comparison.
- Tokens are shown as observed. Money is unknown unless `cost-links.json` beside `records.json` links a run to the saved
  output of `make -f ai-factory/make/ai.mk lifecycle DELIVERY=<id> JSON=1`:
  `{"schema": "t4-benchmark-cost-links", "version": 1, "lifecycleReport": "<path from the run directory>", "links": [{"run": "<benchmark run>", "lifecycleRun": "<run_id>", "session": "<session>"}]}`.
  A link is trusted only when that delivery holds that single run. Linked usage is shown beside the benchmark tokens, never added to them.
- The *Legacy assertions* column is not a quality criterion. There is no overall score, threshold or statistical claim.
  Prompt replay, cache, scheduling and human waiting are labelled limits.

Questions and unclear completions are judged by a person in `judgments.json` beside `records.json`. A run without a
complete review has an unknown question count, never 0:

```json
{"schema": "t4-workflow-judgments", "version": 1,
 "reviews": [{"run": "escalation-1-candidate", "transcript": "escalation-1-candidate/final.txt", "reviewer": "maintainer", "complete": true}],
 "questions": [{"run": "escalation-1-candidate", "transcript": "escalation-1-candidate/final.txt#L1",
   "question": "Which admin resources may unauthenticated visitors modify?", "label": "necessary",
   "reviewer": "maintainer", "rationale": "The permission policy is undecided; only its owner can settle it."}],
 "completion": [{"run": "docs-1-baseline", "status": "completed", "reviewer": "maintainer", "rationale": "The final message reports the fix done; it only lacks the status line."}]}
```
Labels are `necessary`, `unnecessary` or `uncertain`. Re-asking the explicit spelling fix in `docs` is unnecessary.
A `completion` ruling settles only a run whose claim is still pending. An unknown run ID, an invalid field, a
transcript outside that run or a `#L<n>`/`#L<n>-L<m>` anchor past its last line is refused, and nothing is written. Offline checks: `bash skills/ai-layout/scripts/check-workflow-evaluations.sh [quality|pairing|report|harness]`.
The `harness` group drives `--real` through a fake `codex` executable, with no model calls.

## Install

Claude Code uses `/t4:<task>`. Codex uses the bundled `$t4-<task>` skills, including
`$t4-adopt-sdlc`, `$t4-doctor` and `$t4-state`; no project adapters are required for
native Codex discovery. Both hosts use the same project procedures. Codex plugin hooks
support patch protection and session/agent accounting after review and trust in `/hooks`.

For Codex CLI: `codex plugin marketplace add /absolute/path/to/checkout`, then
`codex plugin add t4@sdlc`. Restart the session after installation. See the
[host support table](ai-factory/docs/workflow.md#8-using-claude-code-and-codex).

Claude Code installation:

```
/plugin marketplace add git@git.epam.com:volodymyr_tanin/ai-sdlc-plugin.git
/plugin install t4@sdlc
```
Local, from the repo root: `claude --plugin-dir .`

## The loop each repo follows
Full walkthrough with a worked example: [ai-factory/docs/workflow.md](ai-factory/docs/workflow.md).

`/t4:design` first when the capability spans services or changes a contract between them — `/t4:fleet` fills the service map it reads, `/t4:adr` records the decision. For an understood local enhancement, use `/t4:quick`; otherwise start at `/t4:explore`.

`/t4:analyse` when the request is still a business description — several actors, rules, permissions, a lifecycle, policy nobody has decided — and needs a requirements pack before a spec can be written without guessing. `/t4:spec` reads the pack.

`/t4:explore` (options) → `/t4:spec` (Given/When/Then) → `/t4:plan` (checklist) → `/t4:test red` (ACs fail first) → `/t4:run` one step at a time → `/t4:test gaps` → `/t4:check` → `/t4:report` (with artifact contracts) → commit `ai(<task>): …` → MR labelled `ai-assisted`.

Opt-in layers, all off until a repo enables them (the first three in `ai-factory/contracts/config.json`):
- **Artifact contracts** — checked handoffs and recorded evidence. Enable with `node ai-factory/make/contracts.js enable`.
- **The completion report** — `/t4:report`, for handoff.
- **Lifecycle telemetry** — duration, waits, retries, outcomes and attributed tokens. Enable with `"lifecycle": {"enabled": true}`.
- **Assurance presets** — one `light`/`standard`/`strict` choice over the layers above, stored in `ai-factory/assurance.json`. Select with `node ai-factory/make/assurance.js set <preset> --apply` (see [Assurance presets](#assurance-presets-opt-in)).

## Conventions
Prompt, skill and hook changes go through MR with a before/after run. Tag releases; scaffolds record the tag they used in `ai-factory/AGENTS.md`.

Before an MR, run `make check` at the repo root. It runs every regression script under `skills/ai-layout/scripts/` and `skills/ai-hooks/fixtures/` and stops at the first failure.
