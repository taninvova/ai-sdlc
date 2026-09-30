# ai-sdlc — t4 AI SDLC core plugin (repo: ai-sdlc)

The operating-model half of AI-native delivery, as a Claude Code plugin. Standalone: it depends on no other repo and adds no runtime dependency. Framework-neutral — overlay plugins build on it by filling the `{{…_extra}}` slots in its templates.

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
- `/t4:state` — list the specs and plans still outstanding here, each outstanding plan shown with its incomplete steps. Read-only; it lists the work and never starts any
- `/t4:setup-tracker` — point this repo at a tracker so `/t4:spec ABC-12` works, and prove it by resolving a key. Optional; skip it and nothing changes
- `/t4:sync-sdlc` — inspect workspace drift; generate selected host pointers only when explicitly requested

`/t4:migrate-layout`, which moved a repo adopted before 1.0.0 onto `ai-factory/`, was **removed in 2.1.0**. A repo that never ran it runs it from an ai-sdlc checkout at 2.0.0 or earlier; its hooks keep working until then, because the fallback to the old directory name stays until 3.0.0.

Claude Code and Codex use the same canonical task files. Strict mode creates no external
project adapters. On an explicit request, `bash ai-factory/make/sync-adapters.sh --adapters=claude,codex`
generates only those hosts' pointers. Native discovery depends on the host; headless invocation
works without those adapters. See [workflow](ai-factory/docs/workflow.md).

`/t4:spec` also accepts a tracker ticket key — `/t4:spec ABC-12` — in a repo that has
committed `ai-factory/jira.yaml`. Off by default: without that file nothing changes, whatever you type.

A repo can also declare a read-only knowledge source — an MCP server the developer's tool has
attached, or a knowledge base — in `ai-factory/knowledge_base.md`. The explorer, specifier, planner,
analyst, architect and reviewer agents then read it and cite what they used as external and
unverified; an unreachable source is one report line, never a halt. `ai-factory/docs/knowledge.md` is the
only file that knows how; a repo that declares nothing sees nothing.

Project-level slash commands (generated into each repo from `ai-factory/tasks/`): `/t4:fleet /t4:design /t4:adr /t4:analyse /t4:explore /t4:spec /t4:plan /t4:test /t4:run /t4:fix /t4:chore /t4:quick /t4:check`.

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

## Install
```
/plugin marketplace add git@gitlab.nsix.io:ai/sdlc.git
/plugin install t4@sdlc
```
Local: `claude --plugin-dir ~/code/nsix/ai/sdlc`

## The loop each repo follows
Full walkthrough with a worked example: [ai-factory/docs/workflow.md](ai-factory/docs/workflow.md).

`/t4:design` first when the capability spans services or changes a contract between them — `/t4:fleet` fills the service map it reads, `/t4:adr` records the decision. For an understood local enhancement, use `/t4:quick`; otherwise start at `/t4:explore`.

`/t4:analyse` when the request is still a business description — several actors, rules, permissions, a lifecycle, policy nobody has decided — and needs a requirements pack before a spec can be written without guessing. `/t4:spec` reads the pack.

`/t4:explore` (options) → `/t4:spec` (Given/When/Then) → `/t4:plan` (checklist) → `/t4:test red` (ACs fail first) → `/t4:run` one step at a time → `/t4:test gaps` → `/t4:check` → commit `ai(<task>): …` → MR labelled `ai-assisted`.

## Conventions
Prompt, skill and hook changes go through MR with a before/after run. Tag releases; scaffolds record the tag they used in `ai-factory/AGENTS.md`.
