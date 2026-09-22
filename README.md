# ai-sdlc — t4 AI SDLC core plugin (repo: ai-sdlc)

The operating-model half of AI-native delivery, as a Claude Code plugin. Standalone: it depends on no other repo and adds no runtime dependency. Framework-neutral — overlay plugins build on it by filling the `{{…_extra}}` slots in its templates.

**[docs/workflow.md](docs/workflow.md) — how to install it, what each command is for, and the order to run them in.**

## Commands
- `/t4:adopt-sdlc` — add the `ai/` layout to an existing repo (any stack)
- `/t4:doctor` — report what is wrong with this repo's setup and the command that fixes each thing. Read-only; run it first
- `/t4:setup-tracker` — point this repo at a tracker so `/t4:spec ABC-12` works, and prove it by resolving a key. Optional; skip it and nothing changes
- `/t4:sync-sdlc` — regenerate `.claude/` and `.cursor/` adapters from `ai/`

Works with Claude Code and Codex: `ai/make/sync-adapters.sh` generates `.claude/`, `.cursor/` and `.codex/` from one source. See [docs/workflow.md](docs/workflow.md#8-using-it-from-codex) for what differs under Codex.

`/t4:spec` also accepts a tracker ticket key — `/t4:spec ABC-12` — in a repo that has
committed `ai/jira.yaml`. Off by default: without that file nothing changes, whatever you type.

Project-level slash commands (generated into each repo from `ai/tasks/`): `/t4:fleet /t4:design /t4:adr /t4:analyse /t4:explore /t4:spec /t4:plan /t4:test /t4:run /t4:fix /t4:chore /t4:check`.

## Skills (model-invoked, hidden from the menu)
- `ai-layout` — the `ai/` directory and its templates; where an AI-related file belongs
- `ai-hooks` — session / edit / test-command / usage logging to `ai/runs/`, and the dont-touch guard

## Agents
- `reviewer` — independent, read-only review of the branch diff; JSON verdict
- `tester` — writes acceptance tests from the spec's ACs, blind to the implementation; test files only
- `architect` — decides where a capability belongs across the services in `ai/docs/fleet.md`; writes design docs and ADRs
- `analyst` — turns a feature description into a requirements pack in `ai/analyses/`, with supplied facts kept apart from assumptions, proposals and open questions; never specs, plans or code

## Hooks
Registered plugin-wide; no-op in repos without `ai/`; never print to stdout (cache-neutral).

## Install
```
/plugin marketplace add git@gitlab.nsix.io:ai/sdlc.git
/plugin install t4@sdlc
```
Local: `claude --plugin-dir ~/code/nsix/ai/ai-sdlc`

## The loop each repo follows
Full walkthrough with a worked example: [docs/workflow.md](docs/workflow.md).

`/t4:design` first when the capability spans services or changes a contract between them — `/t4:fleet` fills the service map it reads, `/t4:adr` records the decision. Otherwise start at `/t4:explore`.

`/t4:analyse` when the request is still a business description — several actors, rules, permissions, a lifecycle, policy nobody has decided — and needs a requirements pack before a spec can be written without guessing. `/t4:spec` reads the pack.

`/t4:explore` (options) → `/t4:spec` (Given/When/Then) → `/t4:plan` (checklist) → `/t4:test red` (ACs fail first) → `/t4:run` one step at a time → `/t4:test gaps` → `/t4:check` → commit `ai(<task>): …` → MR labelled `ai-assisted`.

## Conventions
Prompt, skill and hook changes go through MR with a before/after run. Tag releases; scaffolds record the tag they used in `ai/AGENTS.md`.
