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
- `/t4:quick` — complete a small, well-understood change with focused checks and a labeled self-review
- `/t4:adopt-sdlc` — add the `ai-factory/` layout to an existing repo (any stack)
- `/t4:doctor` — report what is wrong with this repo's setup and the command that fixes each thing. Read-only; run it first
- `/t4:state` — list the specs and plans still outstanding here, each outstanding plan shown with its incomplete steps. `--done` lists only finished items; `--next` names the one to pick up, by git commit date. Read-only; it lists the work and never starts any
- `/t4:setup-tracker` — point this repo at a tracker so `/t4:spec ABC-12` works, and prove it by resolving a key. Optional; skip it and nothing changes
- `/t4:setup-knowledge` — declare an external documentation source (an MCP server already attached to your session) for the agents to consult, and prove it answers. Optional; `/t4:adopt-sdlc` offers it once, and the repo's own `ai-factory/docs/` stays the primary knowledge base
- `/t4:sync-sdlc` — inspect workspace drift; generate selected host pointers only when explicitly requested

`/t4:migrate-layout`, which moved a repo adopted before 1.0.0 onto `ai-factory/`, was **removed in 2.1.0**. A repo that never ran it runs it from an ai-sdlc checkout at 2.0.0 or earlier; its hooks keep working until then, because the fallback to the old directory name stays until 3.0.0.

Claude Code and Codex use the same canonical task files. The plugin ships all 20 Claude
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
- `review` — the reviewer, headless. By default it reads staged, unstaged and nonignored untracked changes; `REVIEW_SCOPE=branch` reviews the committed branch instead. The gate is advisory unless `GATE_ENFORCE=1`. It then passes only a valid `approve` with no blockers.
- `contracts` — opt-in artifact contracts: validate the spec → plan → evidence chain read-only (`DELIVERY=…`, `REQUIRE=final,review`, `JSON=1`). `verify DELIVERY=… STEP=S<N> PHASE=red|step|final` runs the declared checks without a shell and records the outcome as evidence. Enable with `node ai-factory/make/contracts.js enable`. The step-by-step guide is *Artifact contracts* in `ai-factory/docs/workflow.md`; the full walkthrough and diagnostic table are in the adopted repo's `ai-factory/contracts/README.md`.
- `delivery-report DELIVERY=<id>` — the completion report behind `/t4:report`: `ai-factory/reports/<id>/completion.md` and `.json`, with status `ready`, `incomplete`, `blocked` or `unverified` and every reason tied to its evidence. It only reads; it runs no check and publishes nothing, and its MR description is a draft. Exits 0 only when ready.
- `lifecycle [DELIVERY=<id>] [JSON=1]` — opt-in lifecycle telemetry (`"lifecycle": {"enabled": true}` in `ai-factory/contracts/config.json`). It reports elapsed, waiting and active time, agent effort, retries, outcomes, attributed tokens and priced/unpriced cost per delivery, plus unattributed activity. Missing measurements show as unknown, never zero. `lifecycle-export DELIVERY=<id>` writes the per-delivery export that `/t4:report` reads. `log.csv` and `cost` are unchanged.
- `cost` — token spend from the run log, grouped by task, agent, branch and day. `JSON=1` or `TSV=1` prints the same numbers for other tools.
- `log-flush` — move pending log rows into `log.csv` when you committed from a terminal. `clean-runs` — delete headless run outputs and markers older than 30 days.

Models: an explicit `MODEL=…` wins. Otherwise `ai-factory/models.yaml` applies (with opt-in `routing:`, the task's own entry first; then `review:` for reviews, then the tool's entry), and a blank entry inherits the CLI's own configuration, so any provider or gateway works. Enabled routing also covers interactive tasks: each `/t4:<task>` and `$t4-<task>` dispatches to a generated worker agent pinned to the task's model (`sync-adapters.sh --adapters=routing`, then restart), and stops rather than run on the chat's model when it cannot. Every headless run prints its selection and records it next to its output. The same file holds per-model prices for the run log. Configuration values are passed as data, never as shell, and `CMD` must name a single executable.

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

Opt-in layers, all off until a repo enables them in `ai-factory/contracts/config.json`:
- **Artifact contracts** — checked handoffs and recorded evidence. Enable with `node ai-factory/make/contracts.js enable`.
- **The completion report** — `/t4:report`, for handoff.
- **Lifecycle telemetry** — duration, waits, retries, outcomes and attributed tokens. Enable with `"lifecycle": {"enabled": true}`.

## Conventions
Prompt, skill and hook changes go through MR with a before/after run. Tag releases; scaffolds record the tag they used in `ai-factory/AGENTS.md`.

Before an MR, run `make check` at the repo root. It runs every regression script under `skills/ai-layout/scripts/` and `skills/ai-hooks/fixtures/` and stops at the first failure.
