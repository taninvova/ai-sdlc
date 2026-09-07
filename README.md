# ai-sdlc — t4 AI SDLC core plugin (repo: ai-sdlc)

The operating-model half of AI-native delivery, as a Claude Code plugin. Standalone: it depends on no other repo and adds no runtime dependency. Framework-neutral — overlay plugins build on it by filling the `{{…_extra}}` slots in its templates.

**[docs/workflow.md](docs/workflow.md) — how to install it, what each command is for, and the order to run them in.**

## Commands
- `/ai-sdlc:adopt` — add the `ai/` layout to an existing repo (any stack)
- `/ai-sdlc:explore <request>` — before a spec: read the code, present 2–4 implementation options with effort, risk, reversibility, a recommendation and the `/ai-spec` line to run next; writes `ai/explorations/NNNN-slug.md`
- `/ai-sdlc:sync` — regenerate `.claude/` and `.cursor/` adapters from `ai/`

Works with Claude Code and Codex: `ai/make/sync-adapters.sh` generates `.claude/`, `.cursor/` and `.codex/` from one source. See [docs/workflow.md](docs/workflow.md#8-using-it-from-codex) for what differs under Codex.

Project-level slash commands (generated into each repo from `ai/tasks/`): `/ai-fleet /ai-design /ai-adr /ai-explore /ai-spec /ai-plan /ai-test /ai-step /ai-fix /ai-chore /ai-check`.

## Skills (model-invoked, hidden from the menu)
- `ai-layout` — the `ai/` directory and its templates; where an AI-related file belongs
- `ai-hooks` — session / edit / test-command / usage logging to `ai/runs/`, and the dont-touch guard

## Agents
- `reviewer` — independent, read-only review of the branch diff; JSON verdict
- `tester` — writes acceptance tests from the spec's ACs, blind to the implementation; test files only
- `architect` — decides where a capability belongs across the services in `ai/docs/fleet.md`; writes design docs and ADRs

## Hooks
Registered plugin-wide; no-op in repos without `ai/`; never print to stdout (cache-neutral).

## Install
```
/plugin marketplace add git@gitlab.nsix.io:ai/sdlc.git
/plugin install ai-sdlc@t4
```
Local: `claude --plugin-dir ~/code/nsix/ai/ai-sdlc`

## The loop each repo follows
Full walkthrough with a worked example: [docs/workflow.md](docs/workflow.md).

`/ai-design` first when the capability spans services or changes a contract between them — `/ai-fleet` fills the service map it reads, `/ai-adr` records the decision. Otherwise start at `/ai-explore`.

`/ai-explore` (options) → `/ai-spec` (Given/When/Then) → `/ai-plan` (checklist) → `/ai-test red` (ACs fail first) → `/ai-step` one step at a time → `/ai-test gaps` → `/ai-check` → commit `ai(<task>): …` → MR labelled `ai-assisted`.

## Conventions
Prompt, skill and hook changes go through MR with a before/after run. Tag releases; scaffolds record the tag they used in `ai/AGENTS.md`.
