# Using the ai-sdlc plugin

How to install it, what each command is for, and the order to run them in.

The plugin gives you three things: an `ai-factory/` directory in your repo that holds the project's
context and prompts, native slash commands that read its procedures, and eight agents. Everything a command
does is written in a file you can read and change — `ai-factory/tasks/<name>.md`. If a command keeps
needing steering in chat, the prompt is missing a line; fix the prompt, don't repeat yourself.

Three opt-in layers sit on top of the loop and change nothing until a repo enables them in
`ai-factory/contracts/config.json`:
- **artifact contracts** — checked handoffs between steps, with recorded evidence;
- **the completion report** — `/t4:report`, a status for handoff;
- **lifecycle telemetry** — duration, waits, retries, outcomes and attributed tokens.

See *Artifact contracts* in section 4.

---

## Workspace defaults and small changes

Strict adoption creates only `ai-factory/`; root files and existing integrations are preserved.
The installed plugin supplies code, while this workspace owns project instructions, config,
plans, logs, reports and private scratch. See [workspace boundary](workspace-boundary.md).
Use `make -f ai-factory/make/ai.mk ai TASK=quick INPUT="..."` without a root Makefile.
Host pointers are opt-in: `bash ai-factory/make/sync-adapters.sh --adapters=claude,codex` selects
only those hosts. Default sync changes no external files and never overwrites a hand-authored
adapter. Unsupported automatic discovery uses explicit invocation; do not invent host support.

Use `/t4:quick` for a small, understood local change: short acceptance checklist, implementation,
meaningful coverage, affected/final checks, and a labeled self-review. No spec/plan/agent is
required solely because behavior changes. Authorization, public contracts, migrations,
dependencies, service boundaries and material uncertainty use the planned workflow below.
Read only relevant context and preserve existing work; never reset the working tree.

Plans name `red`, `step`, or `final` verification. A red step succeeds on its documented
missing-behavior failure. An implementation step passes its criteria and regression checks;
only recorded future-step failures may remain. Completion requires the full required checks.
Never report global green while planned failures remain, and never weaken assertions.

Headless review defaults to `REVIEW_SCOPE=working-tree` (staged, unstaged, relevant untracked);
select `branch` explicitly for the committed range. `INPUT_FILE` supplies the review diff and
is not replaced by another range. The gate consumes the exact current run. `GATE_ENFORCE=1`
requires a valid approval without blockers; unset/0 is advisory. Invalid enforcement values fail.
Explicit `MODEL` wins, including a blank value for CLI inheritance; with routing enabled a task
mapping comes next; review config falls back from `review:` to the selected tool setting to CLI
inheritance. Configuration is passed as data, not executable shell text; `CMD` names a trusted
executable rather than a shell fragment. See *Choosing a model per task* in section 6.

The Claude Edit/Write/MultiEdit guard is not a shell sandbox. Host permissions govern arbitrary
commands. Codex plugin hooks require host trust; adapters alone do not install them. Inline review is a self-check. Do not
disable host protections or grant broad permissions to make tests pass.

## 1. Install, once per machine

```
/plugin marketplace add git@git.epam.com:volodymyr_tanin/ai-sdlc-plugin.git  <!-- path-scan-ok -->
/plugin install t4@sdlc
```

Working on the plugin itself, from its repo root: `claude --plugin-dir .`.  <!-- path-scan-ok -->

The installed plugin exposes 20 `/t4:*` commands in every repo, including all 14 project
task entry points. No `.claude/commands/` pointers are needed for built-in workflows.
The commands are visible before adoption; a project workflow reports a missing workspace
or task instead of silently scaffolding it. Hooks stay silent outside an adopted repo.

No model configuration is required. The plugin runs whatever model your tool is already
configured with, whatever the provider.

## 2. Set a repo up, once per repo

```
/t4:adopt-sdlc                 # detects your stack and its build/lint/test commands
/t4:fleet                   # fills in ai-factory/docs/fleet.md by asking you
/t4:setup-tracker           # optional — only if you want /t4:spec ABC-12 to work
/t4:setup-knowledge         # optional — declare an external documentation source (MCP)
```

`/t4:adopt-sdlc` copies only `ai-factory/` and writes its manifest. External host pointers are opt-in. It refuses if `ai-factory/` already exists — use `/t4:sync-sdlc` there instead.

Then **fill in the prose it left as TBD**. This is the step people skip, and it is the step
that decides whether any of the rest is worth running:

| File | What it must say | Who reads it |
|---|---|---|
| `ai-factory/AGENTS.md` | what this project is, the real build/lint/test commands | every task |
| `ai-factory/docs/architecture.md` | the module map, data ownership, what is deliberately absent | explore, plan, design |
| `ai-factory/docs/coding-standards.md` | the rules that are not obvious from the code | step, fix, chore, reviewer |
| `ai-factory/docs/dont-touch.md` | paths nothing may edit — enforced by a hook, not a convention | the guard |
| `ai-factory/docs/fleet.md` | your services, what each owns, what crosses a boundary | design, adr |

An agent with a placeholder `architecture.md` produces placeholder-quality work.

Restart the session (or `/reload-plugins`) after a plugin update to load all 20 `/t4:*` commands.

---

## 3. Which command do I want?

```
Is it a bug?                              → /t4:fix
Is it a small chore, no behaviour change? → /t4:chore
Is it a business description — actors,
  rules, permissions, undecided policy?   → /t4:analyse  then /t4:spec
Does it cross a service boundary,
  change a contract, or have no home yet? → /t4:design   then /t4:adr, then /t4:spec
Could it be built more than one way?      → /t4:explore  then /t4:spec
Otherwise                                 → /t4:spec
```

`/t4:explore` is optional for small obvious changes and **mandatory** when the request could
be built more than one way, or touches a queue contract, a schema, or a public API.

`/t4:design` sits above `/t4:explore`: design decides **where** a capability lives and what
it exposes, explore decides **how** to build it in one repo whose home is already settled.

`/t4:analyse` sits before both when the request is still a business description: it settles
**what** is needed — actors, permissions, rules, states, data, undecided policy — as a pack in
`ai-factory/analyses/` that `/t4:spec` reads. A small, well-understood change does not need it.

## 4. The main loop

```
/t4:spec  →  /t4:plan  →  /t4:test red  →  /t4:run ×N  →  /t4:test gaps  →  /t4:check  (→ /t4:report)
```

A worked example — adding CSV export to a reports page:

```
/t4:explore let users export a report as CSV
    → ai-factory/explorations/0003-csv-export.md — 3 options, a recommendation,
      and the /t4:spec line to run next

/t4:spec add CSV export to the reports page
    → ai-factory/specs/0007-csv-export.md — AC1…AC5 as Given/When/Then, plus open questions.
      Answer the open questions before planning. A spec with open questions is not buildable.

/t4:plan ai-factory/specs/0007-csv-export.md
    → ai-factory/plans/0007-csv-export.md — files to touch, then
      - [ ] Step 1 — …  - [ ] Step 2 — …  each naming the tests that prove it

/t4:test red ai-factory/specs/0007-csv-export.md
    → tests for AC1…AC5, written from the spec by an agent that has not seen your
      implementation. They MUST fail, and fail for the right reason.

/t4:run ai-factory/plans/0007-csv-export.md step 1
    → implements step 1 only, verifies the declared phase, ticks the verified checkbox

    …repeat per step, one at a time…

/t4:test gaps ai-factory/specs/0007-csv-export.md
    → covers any AC that ended up with no test

/t4:check
    → the reviewer agent on the selected diff; JSON verdict

/t4:report d-20260930-1a2b3c          (artifact contracts enabled)
    → ai-factory/reports/d-20260930-1a2b3c/completion.md — ready, incomplete, blocked or
      unverified, each reason tied to its evidence, plus a draft MR description
```

Then commit as `ai(<task>): …` and open an MR labelled `ai-assisted`.

### The rules that make it work

- **One named step per `/t4:run`.** It is told not to start the next one. Let it stop.
- **Back after time away? `/t4:state` before `/t4:run`.** It lists the specs and plans still
  outstanding, each outstanding plan with its incomplete steps, so you pick the next step up from
  the artefacts on disk rather than from what you remember of the last session. Read-only — it
  names the work and starts none of it.
  An explicit `**Result — Step N withdrawn; …**` record resolves that numbered step without
  ticking it. `--done` labels plans resolved partly by withdrawal as `closed`, not `complete`;
  blocked or deferred steps without such a record stay pending. This reports recorded work,
  not proof of acceptance criteria. Quoted or fenced examples never withdraw a step.
- **Plan when risk or uncertainty warrants it.** File count alone does not determine the workflow.
- **Steering in chat for 20+ minutes with code changed?** Stop. Write the decision into the
  plan, commit, and continue. Long chat threads lose the decision.
- **Answer a spec's open questions before planning.** They are listed because the model could
  not resolve them, and a plan built on a guess encodes the guess.

### Artifact contracts (opt-in)

Contracts make every handoff in the loop above checkable. Each spec, plan and quick checklist
gets a `.contract.json` beside it, and each check that runs leaves evidence. Nothing moves on
unchecked. They check structure only, never whether a requirement is right.

**Turn them on** once per repo, and commit the result:

```
node ai-factory/make/contracts.js enable
git add ai-factory/contracts/config.json ai-factory/.sdlc.json
```

Then set `code_scope` in `ai-factory/contracts/config.json` to the files that count as code,
and exclude generated test output. `/t4:sync-sdlc` offers the same opt-in.

**Then work exactly as before.** The commands do the bookkeeping:

| Command | Adds, when contracts are on |
|---|---|
| `/t4:spec` | numbered `AC1…` criteria; `contracts.js init spec` records the delivery ID (`d-YYYYMMDD-xxxxxx`) |
| `/t4:plan` | each step names its ACs and ``Verify (red\|step\|final): `command` `` checks; `init plan` rejects uncovered ACs or missing checks |
| `/t4:test … red` | `make verify DELIVERY=<id> STEP=S1 PHASE=red` proves the new tests fail |
| `/t4:run … step N` | `make verify DELIVERY=<id> STEP=SN`; the box is ticked only on passing evidence; the last step adds `PHASE=final` |
| `/t4:check` | reports every artifact that is not valid as a finding; headless `make review DELIVERY=<id>` records review evidence |
| `/t4:quick` | the checklist goes to `ai-factory/quick/<slug>.md` as `QC1…` items, finished by `make verify DELIVERY=<id>` |

(`make` here is `make -f ai-factory/make/ai.mk`.)

**Where a delivery stands:**

```
make -f ai-factory/make/ai.mk contracts                                   # everything
make -f ai-factory/make/ai.mk contracts DELIVERY=<id>                     # one delivery
make -f ai-factory/make/ai.mk contracts DELIVERY=<id> REQUIRE=final,review   # before merging
```

Every artifact is reported as `valid`, `invalid`, `stale` or `legacy_unverified`. A line that
is not valid names a code and says what to do. The usual causes:
- a spec edited after planning (`S_SPEC_CHANGED`): check the plan, then `init plan` again;
- code edited after verification or review (`S_CODE_CHANGED`): run the same `make verify` or
  `make review` again;
- a ticked box without evidence (`E_EVIDENCE_NOT_RUN`): record the step's verification.

Never edit a sidecar or an evidence file by hand.

**The completion report.** `/t4:report <id>`, or `make -f ai-factory/make/ai.mk delivery-report
DELIVERY=<id>`, writes `ai-factory/reports/<id>/completion.md` and `.json`. It contains:
- the status (`ready`, `incomplete`, `blocked` or `unverified`) with every reason and its evidence;
- one row per criterion;
- the changed files and the checks that actually ran;
- the review findings and the open follow-up;
- telemetry, which shows as unavailable until a per-delivery export exists;
- a draft MR description.

It only reads: it runs no check and publishes nothing. `ready` means ready for handoff. The
`completion` policy in `ai-factory/contracts/config.json` decides whether review is required,
which finding severities block, and whether human attestations (`contracts.js attest`) may count.

**Lifecycle telemetry (opt-in).** `"lifecycle": {"enabled": true}` in
`ai-factory/contracts/config.json` enables a separate, local event stream under the gitignored
`ai-factory/runs/lifecycle/`. `log.csv` and `make cost` are unchanged.
- **Headless runs** record themselves.
- **Interactive tasks** bracket their work with `node ai-factory/make/lifecycle.js start` / `end` and,
  while waiting on you, `wait-start` / `wait-end`.
- **Reading it.** `make -f ai-factory/make/ai.mk lifecycle [DELIVERY=<id>] [JSON=1]` reports elapsed,
  waiting and active time, agent effort, retries, outcomes, tokens and priced/unpriced cost per
  delivery, plus unattributed activity. Anything not measured shows as unknown, never zero.
- **In the completion report.** `/t4:report` includes these numbers when lifecycle is enabled.

**Repos with existing specs and plans.** `node ai-factory/make/contracts.js migrate` shows the
drafts it would create; `--write` creates them. Drafts stay unverified until you review them
and rerun `init`. Migration never edits Markdown or invents IDs.

The full walkthrough, the diagnostic table and the file formats are in
`ai-factory/contracts/README.md` in any adopted repo.

## 5. Every command

### Plugin-level — available in any repo

| Command | Use it when | Writes |
|---|---|---|
| `/t4:adopt-sdlc` | adding the layout to an existing repo | the whole `ai-factory/` layout + `ai-factory/.sdlc.json` |
| `/t4:state` | coming back to a repo and asking what is left, before picking a step up | nothing — terminal output only |
| `/t4:sync-sdlc` | after pulling a new plugin version, or when `/t4:*` are missing | reports drift; generates selected host pointers only on explicit request |

#### Taking the 1.0.0 rename

1.0.0 renamed the layout: `ai/` became `ai-factory/`, and `specs/` and `docs/adr/` moved inside it.  <!-- path-scan-ok -->
`/t4:migrate-layout` made that move, and **2.1.0 removed it** — a one-shot migration, kept for as
long as it was a command anyone here still needed. A repo that has not run it still can: check out
ai-sdlc at 2.0.0 or earlier, point your tool at that copy, and run the command from there.
Then commit what it leaves in **two** commits, in the order it prints — the moves first, the path
rewrite second. Git pairs a rename by similarity, so in one commit a file whose path lines are most
of its content loses its history; two commits make that independent of how big the file is.

Until you run it the hooks still work: they accept the old directory name until 3.0.0, so the
dont-touch guard and the run log keep going. The prompts do not — they name `ai-factory/` only, so
`/t4:spec` and the rest will look in a directory that is not there yet. `/t4:doctor` says which of
the three states a repo is in, and `/t4:sync-sdlc` stops and points here rather than syncing.

### Project tasks — native commands backed by repo procedures

| Command | Use it when | Writes | Never does |
|---|---|---|---|
| `/t4:fleet` | once per repo, then when a service or contract changes | `ai-factory/docs/fleet.md` | ask anything in CI — it fills what it can and marks the rest TBD |
| `/t4:design <capability>` | the capability spans services or changes a contract | `ai-factory/designs/NNNN-*.md` | write specs, plans or code |
| `/t4:design review <plan>` | a plan crosses a boundary or adds a dependency | nothing — JSON verdict | review correctness or style; that is `/t4:check` |
| `/t4:adr <decision>` | any decision that outlives the change, **every new dependency** | `ai-factory/adr/NNNN-*.md` | reopen a decision an accepted ADR settled |
| `/t4:analyse <feature description>` | the request is a business description — actors, rules, permissions, a lifecycle, undecided policy | `ai-factory/analyses/NNNN-*.md` | write specs, plans or code; invent policy, estimates or approvals; create anything outside the repo |
| `/t4:explore <request>` | the request could be built more than one way | `ai-factory/explorations/NNNN-*.md` | change code |
| `/t4:spec <feature>` | you know what to build, not yet how | `ai-factory/specs/NNNN-*.md` | write the plan or the code |
| `/t4:plan <spec>` | the spec's open questions are answered | `ai-factory/plans/NNNN-*.md` | change code |
| `/t4:test red <spec>` | before implementing | test files | touch production code — if a test needs a change there, it stops and says so |
| `/t4:run <plan> step N` | implementing, one step at a time | code + tests | start step N+1 |
| `/t4:test gaps <spec>` | after the steps are done | test files | weaken an assertion to reach green |
| `/t4:fix <bug>` | something is broken | a failing test first, then the fix | refactor anything unrelated |
| `/t4:quick <change>` | a small understood local change | code, meaningful tests, checklist report | change public contracts or silently widen scope |
| `/t4:chore <change>` | small maintenance, no behaviour change | code + tests | change behaviour beyond the request |
| `/t4:check` | before committing | nothing — JSON verdict | fix anything it finds |
| `/t4:report <delivery id>` | after review, or any time you need to know where a delivery stands (contracts enabled) | `ai-factory/reports/<id>/completion.{md,json}` | run checks, edit artifacts or publish anything — its MR text is a draft |

### The agents

Eight subagents do the work the commands delegate. Each is deliberately narrow. Four run the
loop steps, so that each step starts from its artefacts and not from the chat that produced
them; the session keeps what only a session can do — refuse an empty argument, ask a question,
resolve a tracker key, relay the report:

- **`explorer`** — `/t4:explore`: reads the code the request touches, writes two to four
  options with a comparison and one recommendation to `ai-factory/explorations/`. Never code.
- **`specifier`** — `/t4:spec`: builds on the exploration's chosen option and the analysis if
  either exists, writes Given/When/Then criteria to `ai-factory/specs/`; anything implicit is an open
  question, never a criterion. Never the plan or code.
- **`planner`** — `/t4:plan`: turns one spec into steps sized for one `/t4:run`, each naming
  the tests that prove it, in `ai-factory/plans/`. Never code.
- **`implementer`** — `/t4:run`: implements exactly one step, runs lint, typecheck and tests,
  ticks the box only when green. Red, or a test it cannot find: stops and explains. Never the
  next step, never a knowledge source, and the dont-touch guard blocks it like anyone else.

Four stand outside the loop's steps:


- **`reviewer`** — reads the selected diff against the spec, plan and standards. Read-only,
  JSON verdict. Checks correctness, scope, tests, spec drift, boundaries, security,
  operability. Does not comment on formatting; the linter owns that.
- **`tester`** — writes acceptance tests from the spec's ACs. Reads the implementation's
  *public surface only* and never the diff, because a test derived from an implementation
  restates it instead of checking it. Writes test files only.
- **`architect`** — decides where a capability belongs, writes designs and ADRs. Treats an
  accepted ADR as binding. Proposes changes to context docs rather than making them.
- **`analyst`** — turns a feature description into a requirements pack: objectives, scope,
  permission matrix, use cases and lifecycles, functional and non-functional requirements,
  business rules, data dictionary, integrations, stories with Given/When/Then ACs, test
  scenarios and traceability. Labels every statement a supplied fact, assumption, proposal
  or open question and never lets one become another. Invents no policy, estimate, approval
  or existing architecture. Writes `ai-factory/analyses/` only.

Their project copies live in `ai-factory/agents/` — add project-specific checks there, not to the
plugin.

### External knowledge, read-only

Declare a source in `ai-factory/knowledge_base.md` — one table with `name`, `kind` and `use` — and the
explorer, specifier, planner, analyst, architect and reviewer agents read it. Every fact
they take from it is labelled with the source's name and *external, unverified*, ranks below the
code and an accepted ADR, and a disagreement becomes an open question. Nothing is ever written
back. A source that cannot be reached — Codex, headless, not attached — is one line in the
report; the loop never halts on it, unlike a ticket the tracker cannot resolve, because a ticket
is input and knowledge is enrichment. `ai-factory/docs/knowledge.md` holds every detail; a repo that
declares nothing sees no change at all. `/t4:adopt-sdlc` offers to declare one (default: skip);
`/t4:setup-knowledge` declares one at any later time. `/t4:doctor` says whether a repo is configured.

---

## 6. Headless, for CI

```
make -f ai-factory/make/ai.mk ai TASK=chore INPUT="bump the node version"
make -f ai-factory/make/ai.mk ai TASK=check INPUT_FILE=some.diff
make -f ai-factory/make/ai.mk review # staged, unstaged and nonignored untracked changes
```

Set `REVIEW_SCOPE=branch` for committed branch review. Supplied input wins over automatic
selection. The run records the reviewed scope and paths; the gate consumes that exact output.
`GATE_ENFORCE=1` requires a valid `approve` result with no blockers. Missing or malformed
results, `request_changes`, and invalid enforcement values fail. Unset or `0` is advisory.
Explicit `MODEL` wins; `MODEL=` requests CLI inheritance. Otherwise check/review uses
`review:`, the tool default, then CLI inheritance. `CMD` selects a single executable,
not a shell fragment. Neither a root Makefile nor project adapters are required.

With artifact contracts enabled, CI can gate on the handoff chain as well:

```
make -f ai-factory/make/ai.mk contracts JSON=1                         # nonzero on anything not valid
make -f ai-factory/make/ai.mk contracts DELIVERY=<id> REQUIRE=final,review
make -f ai-factory/make/ai.mk delivery-report DELIVERY=<id>            # exit 0 only when ready
make -f ai-factory/make/ai.mk review DELIVERY=<id>                     # also records review evidence
```

Keep `ai-factory/reports/<id>/completion.md` as a job artifact. With lifecycle telemetry enabled,
headless runs record themselves (`DELIVERY=` and `STEP=` name what they belong to), and
`make -f ai-factory/make/ai.mk lifecycle JSON=1` prints the per-delivery summary. Telemetry never
changes a job's exit status.

### Choosing a model per task (opt-in)

`ai-factory/models.yaml` can name a model per task and tool. Routing is off until you enable it,
and the same mapping then applies to headless runs and interactive tasks:

```yaml
routing:
  enabled: true
  tasks:
    plan:
      claude: gateway/planning-claude
      codex: gateway/planning-codex
    test:
      claude: gateway/testing-claude
      codex: gateway/testing-codex
```

Task names are the files in `ai-factory/tasks/`, custom ones included. `make review` runs the
`check` task, so map `check`; `review` is rejected under `tasks:`. Aliases are passed verbatim and
select a model, not a provider — endpoints, keys and gateways stay in each tool's own configuration.

The model is resolved once per task, first match wins:

| # | Source | Headless | Interactive |
|---|---|---|---|
| 1 | explicit | `MODEL=<id>` | `/t4:plan --task-model=<id> -- <input>` |
| 2 | explicit inherit | `MODEL=` on the command line | `--task-model=inherit` |
| 3 | task default | `routing.tasks.<task>.<tool>`, when enabled and not blank | same |
| 4 | review default | `review:`, for `check` only | same |
| 5 | tool default | `claude:` or `codex:` | same |
| 6 | CLI default | no model argument; the tool's own configuration | the session's model |

A missing or blank entry falls back and says so. Setting `enabled: false`, or removing the section,
restores the old behavior exactly, and keeps the mappings for later. The file is parsed strictly:
a typo such as `enabled: ture`, a duplicate key, flow syntax or bad indentation stops the task
with the line number before anything launches, and never selects another model. A rejected alias,
a failed login or a refused request is returned as the failure; nothing retries on a different model.

**Headless.** Every run prints its selection to stderr — `model: plan / codex: gateway/planning-codex
(task default)` — and writes `ai-factory/runs/<run>.json.model.json` (schema
`t4.model-selection.v1`): task, tool, requested model, source, routing state, configuration digest,
outcome, and any model identity the CLI output reported, kept separate. This is the *requested*
model; a gateway alias can still resolve to something else behind the provider. `log.csv` is unchanged.

**Interactive.** A routed task runs in a worker agent pinned to the selected model; the chat
itself keeps its own model and only relays questions and results. Each `/t4:<task>` command and
`$t4-<task>` skill first runs `node ai-factory/make/models.js dispatch`, which prints one directive:

| Directive | What the session does |
|---|---|
| `legacy` | routing is off: the task runs exactly as before |
| `inherit` | routing is on, but no model is configured for this task: it runs on the session's model |
| `route` | launch the named worker; do not read or do the task in the chat |
| `blocked` | stop and report; no task work, and never on another model |

The workers are generated agent files, one per task, written only by an explicit sync:

```
bash ai-factory/make/sync-adapters.sh --adapters=routing   # or /t4:sync-sdlc --adapters=routing
```

Then restart the session: both hosts load agent files when a session starts. Each agent's name
carries a hash of its content, so editing a mapping produces a new agent name. A session that
still holds the old agent cannot reach the new one; its routed task stops with a restart
instruction instead of running on the old model. A worker already running keeps its model.
Until the sync runs, a routed task stops with the sync command.

`--task-model=<id>` sends one task to another model without a generated agent. It is limited to
letters, digits and `. _ : / @ + -`. Claude Code accepts only its own model aliases for a single
call, such as `opus` or `haiku`. To route an arbitrary gateway alias on Claude, map it and sync.
Codex offers only the models its spawn tool lists. Changing the chat's own model does not override
a mapping. Dispatches are recorded in `ai-factory/runs/routing.jsonl` (schema `t4.model-dispatch.v1`),
with the worker ID and the outcome added when the task ends. `/t4:doctor` reports invalid
configuration, mappings with no task file, missing or stale agents, and `CLAUDE_CODE_SUBAGENT_MODEL`.

## 7. Staying current

`/t4:sync-sdlc` reports how `ai-factory/` compares to the installed templates. It generates
external adapters only when explicitly requested:

| It says | What to do |
|---|---|
| **upstream changed** | your copy is untouched — safe to take the new version |
| **both changed** | you edited it and so did upstream — merge by hand |
| **locally modified** | yours; upstream has not moved. Nothing to do |
| **new upstream** | a file added since you adopted; copy it in if you want it |

It reports only. Taking a change is a separate, reviewable edit — deliberately, so an upstream
template can never silently overwrite something you rely on.

A repo adopted before `ai-factory/.sdlc.json` existed is told how to start a baseline. Never edit that
file by hand; a hook blocks it, because a manifest edited by hand makes the check lie.

## 8. Using Claude Code and Codex

Both hosts use the same `ai-factory/tasks/` and complete agent procedures. The Codex
package includes native skills for every workflow and plugin command, including adoption,
sync, doctor and state. Project adapters are optional; installing the plugin does not
require generating files into `.codex/`.

| Capability | Claude Code | Codex |
|---|---|---|
| Interactive tasks | `/t4:<task>` through native plugin commands | `$t4-<task>` through bundled plugin skills |
| Setup | `/t4:adopt-sdlc` | `$t4-adopt-sdlc` |
| Headless | `make -f ai-factory/make/ai.mk ai TOOL=claude` | `make -f ai-factory/make/ai.mk ai TOOL=codex` |
| Lifecycle hooks | `hooks/hooks.json` | `hooks/codex.json`; review and trust in `/hooks` |
| Protected edits | Edit, Write, MultiEdit paths | Every apply_patch path, including rename destinations |
| Agent procedure | Registered Claude agent | Native delegation when available; otherwise labeled inline self-check |
| Usage | Claude transcript records | Codex response records or older cumulative snapshots |
| Completion report | `/t4:report <delivery id>` | `$t4-report <delivery id>`; both run `make … delivery-report` |
| Lifecycle session binding | Bash PostToolUse output shows `lifecycle.js start` | Unconfirmed: depends on the hook payload carrying command output; otherwise usage stays unattributed |
| Per-task model routing | `.claude/agents/t4-route-<task>-<hash>.md` with `model:`, launched by the Agent tool without a per-call model | `.codex/agents/t4-route-<task>-<hash>.toml` with `model`, spawned by `agent_type` with `fork_turns` `none` |
| Routing override | Agent tool `model`, Claude aliases only | `spawn_agent` `model`, the models the host lists |
| Routing blockers | `CLAUDE_CODE_SUBAGENT_MODEL` overrides every subagent; agent files load at session start | Agent files load at session start; a full-history fork inherits the parent agent type |

Routing adapter evidence (2026-09-30, Claude Code 2.1.285, Codex CLI 0.153.2):
- **Claude Code — documented.** Subagent `model:` frontmatter takes aliases, full model IDs or
  `inherit`. `CLAUDE_CODE_SUBAGENT_MODEL` overrides it.
- **Claude Code — observed in the host.** The Agent tool's per-call `model` is an alias enum.
- **Codex — read from the 0.153.2 binary.** It discovers `.codex/agents`, and an agent file must
  define a non-empty `name`, `description` and `developer_instructions`. `spawn_agent` lists
  "available model overrides", and a full-history fork inherits the parent's agent type.
- **Not verified on either host.** Arbitrary gateway aliases in an agent file's model field, and
  the model a worker actually used. No live routed session ran on either host. Treat interactive
  routing on a host as unverified until a smoke run there has used your gateway aliases:
  planning, then testing, in one session.


For Codex CLI, add this checkout as a marketplace with
`codex plugin marketplace add /absolute/path/to/checkout`, then run
`codex plugin add t4@sdlc`. In the desktop app, install t4 from the configured sdlc
marketplace. Start a new session after installing or updating the plugin. Review changed
hook definitions in `/hooks` before relying on automatic logging or edit guards.

Subagent availability and foreground/background behavior depend on the host version.
An inline review is a self-check, never an independent review. Both hosts preserve the
host sandbox: arbitrary shell writes are outside the edit guard's coverage. Hosts that
cannot execute local plugin hooks can still use the skills and headless runner, but do
not provide automatic interactive logging or hook enforcement.

Codex usage excludes cached input from the `input_tokens` column so its meaning matches
Claude rows. `output_tokens` already includes reasoning output. Codex `cost_usd` stays
empty instead of using Claude prices. Its rollout format is version-specific; fixtures
cover response records and legacy cumulative snapshots. Repeated Stops and inherited
response IDs are counted once within a session's claim ledger.

Validation (2026-09-29): all 22 regression scripts passed in an isolated checkout,
including the existing Claude hooks and the new Codex event/rollout fixtures. Before the
fix, safe Codex patches were blocked, edit/task/usage rows were absent, and native workflow
skills were missing. Codex CLI 0.159.0 installed the package into a temporary profile;
its real `skills/list` and `hooks/list` APIs discovered all 20 bundled skills and eight
hook handlers with no errors. Hooks remained untrusted in that profile, as expected.
This loader check did not execute an autonomous model turn or prove hook delivery in every
Codex surface; host trust and local command-hook support remain deployment requirements.

Claude discovery correction (2.3.2): the installed 2.3.1 package exposed only six native
commands; the remaining task files required project pointers. A fresh Claude Code 2.1.277
SDK initialization in an empty directory discovered six t4 commands from that installed
package and all 18 from the updated checkout. No project adapters or model turns were used.
This validates command registration, not every task's model-driven behavior. Explicit
Claude adapter sync removes generated duplicates and retains pointers for custom tasks.

Official host contracts: [plugins](https://developers.openai.com/plugins/build/plugins),
[hooks](https://developers.openai.com/codex/hooks), and
[subagents](https://developers.openai.com/codex/agent-configuration/subagents).

## 9. What the hooks record

Silently, into `ai-factory/runs/` — nothing prints to your terminal:

- `log.csv` — one row per session: tokens, cache hit rate, cost, model, branch. The row is
  buffered in `log.pending.csv` (gitignored) and moved into `log.csv` when the session runs
  `git commit`, so the tracked file changes only inside the commit that produced the work and
  never blocks a `git checkout`. Committing from a terminal instead? `make log-flush`. Fill the
  `accepted` column (y/n/partial) at commit time; it is the only honest measure of whether
  this is working. Each row is the **increment** since that session's previous row, so the rows of
  one session add up to what it spent rather than each restating a running total.
- Tokens spent inside a subagent are in the log too, as their own rows. Every agent that
  concludes — the reviewer and tester, and the explorer, specifier, planner and implementer that
  `/t4:explore`, `/t4:spec`, `/t4:plan` and `/t4:run` delegate to — adds a row summed from its own
  transcript. The `source` column says which kind you are looking at: `session` for a turn, `agent`
  for a concluded subagent, `make` for a headless CI run. An `agent` row names the agent in the
  `agent` column and carries the `/t4:` command the session was running in `task`, so you can ask
  where the money went by agent, by task, by branch or by model — not just how much the repo spent.
  A record is counted once however many transcripts carry a copy of it, keyed on its message uuid;
  a record whose transcript format omits that key is counted every time instead, which over-counts
  rather than losing the tokens quietly.
- Because the header changed in 2.0.0 (17 columns — `agent` is new), the first write after you take
  that update moves your existing rows to `log.previous.csv` and starts a clean file. Those rows
  were cumulative, not increments, and nothing reinterprets them. `make log-flush` refuses while
  `log.pending.csv` and `log.csv` have different headers, which is exactly the state right after the
  upgrade — let a session flush first, so the hook migrates the file, then flush by hand as usual.
- `sessions.jsonl`, `edits.jsonl`, `cmds.jsonl` — what ran, what was edited, which test and
  lint commands were used.
- The guard blocks any edit to a path in `ai-factory/docs/dont-touch.md` and says which rule matched.
- With lifecycle telemetry enabled, Stop and SubagentStop also write one `usage_linked` event per
  row into `ai-factory/runs/lifecycle/events/`, and the Bash hook binds the session to a run when
  it sees `lifecycle.js start`. The rows themselves are identical either way. A lifecycle failure
  is one stderr line, never a lost row.

`ai-factory/runs/*.json`, `*.jsonl`, `log.pending.csv`, `runs/tmp/`, `runs/evidence/` (command logs),
`runs/lifecycle/` and `runs/telemetry/` are gitignored. `log.csv` is committed, with
`merge=union` in `.gitattributes` so two branches' rows never conflict. Contract sidecars,
`ai-factory/evidence/` and `ai-factory/reports/` are committed when you use them.

Hooks run from the **installed** plugin, not from a working copy. After updating the plugin,
restart the session — until you do, an older hook keeps writing the older row shape, and a
`log.csv` already migrated to a newer header will collect rows that do not match it. If that
happens, move the mismatched rows to `ai-factory/runs/log.previous.csv`; that is what the current
writer does automatically.

### `make cost` — where the tokens went

`make cost` reads `ai-factory/runs/log.csv` and prints token spend grouped by **task**, **agent**,
**branch** and **day**, then a total. `make cost JSON=1` and `make cost TSV=1` print the same numbers
as a machine-readable document instead. All three are read-only over the log and write nothing.

**It reports tokens and turns, never money.** Decided 2026-09-27: `cost_usd` is not read at all.
Nine of the ten logs in this workspace sit in layouts that may run different models, the column is
already `~`-marked or empty per row, and a rolled-up dollar figure would be summing prices set in ten
separate `models.yaml` files. Anything that wants money prices the token counts itself, with one
price list, so its totals are comparable by construction.

What it **can** answer: which task, agent, branch or day the tokens went to; how many runs and turns
each took; the cache hit rate per group, recomputed from the summed tokens rather than averaged over
rows. Per-agent and per-task numbers are meaningful only for rows written by the 2.0.0 collection
change — older rows carry no `agent` column and an empty `task`, and appear under `(unattributed)`.

What the log **cannot** see, at any effort, and which `make cost` therefore never shows:
per-plan-step cost inside `/t4:run`, wall-clock duration, tool-call counts, lines changed, and
**anything from Cursor**, which has no local export of any kind. If Cursor is in use here, this is
not a complete picture of spend and cannot be made into one.

Two lines appear only when they mean something. The `accepted` column is hand-filled and usually
empty, so a coverage line is printed only once some row carries a value rather than reading
"0 of N" forever. And a total drawn from more than one `tool` carries a footnote naming them: Codex
inlines the agent into the session, so one session is both the task and the agent, while Claude
spreads across named agents — without the note, the by-agent table invites comparing a part with a
whole.

### The export is a contract

The JSON and TSV forms are read by collectors outside this repo, which no fixture here can reach. So
they carry a **schema version**, and it is a plain integer starting at `1`:

- **Adding** a field does **not** change the version. A consumer reading version 1 keeps working when
  a field it never reads appears, so consumers must ignore fields they do not recognise.
- **Renaming** a field, **removing** one, or changing what an existing one means **does** change it.
  Any of those is a breaking change for a consumer this repo cannot see.

`skills/ai-layout/scripts/check-cost.sh` asserts the exact field-name set and fails on a rename, a
removal *and* an addition. The asymmetry is deliberate: the check guards against accidental drift,
while the version communicates breakage. An addition means editing that expected list by hand, which
is the point.

## 10. When something is wrong

**Run `/t4:doctor` first.** It reports the layout, the adapters, the version this repo records
against the one the session loaded, drift, where the plugin is installed and whether older
cached copies are still around — each with the command that fixes it. It changes nothing, so
there is no reason not to run it before guessing.

**If `/t4:doctor` itself does not exist, that is the diagnosis.** The plugin is not enabled in
this repo, and no command can tell you so — in a repo without it, none of them are there to
run. Install it at user scope, or enable it here:

```
/plugin install t4@sdlc
```

Then restart the session: commands and hooks are loaded at startup, so a plugin installed
mid-session is not yet running.

| Symptom | Cause |
|---|---|
| No `/t4:*` commands | Verify the installed plugin and host discovery support. Strict mode can use explicit task paths; request the specific host adapter only if wanted. |
| t4 skills missing in Codex | Install/update the Codex plugin and start a new session; use `$t4-<task>`. The local runner remains available. |
| A command behaves oddly | read `ai-factory/tasks/<name>.md`; that text *is* the behaviour. Fix it there via MR |
| An edit was blocked | it matched `ai-factory/docs/dont-touch.md`. Edit the source, not the generated copy |
| `.claude/` looks wrong | never edit it — it is generated. Change `ai-factory/` and run `/t4:sync-sdlc` |
| The reviewer is too lenient | add project checks to `ai-factory/agents/reviewer.md` |
| Tests pass but prove nothing | `/t4:test gaps` — it flags ACs whose tests would still pass if the behaviour were reverted |
| `make contracts` reports `stale` | Something upstream changed after it was checked. Rerun the `init` or `make verify` named in the hint; never edit a sidecar or evidence file by hand |
| `/t4:report` says `unverified` but the work is done | Required evidence is missing or stale. The reasons table names each file and the command that records it |
| `make lifecycle` shows `unknown` | A run or wait was never ended, a clock went backwards, or no run was bound to the session. Unknown is deliberate; end the run with `lifecycle.js end` |
| A task says `directive: blocked` | Routing cannot honor the selected model: fix the named `models.yaml` line, run `bash ai-factory/make/sync-adapters.sh --adapters=routing`, unset `CLAUDE_CODE_SUBAGENT_MODEL`, or restart the session, as the message says. Nothing ran on another model |
| "Unknown agent type t4-route-…" | The session started before that agent file existed or changed. Restart it; the task did not run |

## 11. The short version

```
once:      /t4:adopt-sdlc  →  /t4:fleet  →  fill in ai-factory/docs/*
per change: /t4:design? → /t4:analyse? → /t4:explore? → /t4:spec → /t4:plan
            → /t4:test red → /t4:run ×N → /t4:test gaps → /t4:check
            → /t4:report (with contracts)  →  commit ai(<task>): …  →  MR labelled ai-assisted
per dependency or lasting decision: /t4:adr
opt-in:    node ai-factory/make/contracts.js enable  ·  "lifecycle": {"enabled": true} in contracts/config.json
           routing.enabled: true in ai-factory/models.yaml → sync-adapters.sh --adapters=routing → restart
```
