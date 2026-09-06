# sdlc — n6 AI SDLC core plugin (repo: ai-sdlc)

The operating-model half of AI-native delivery, as a Claude Code plugin. Framework-neutral; the scaffold plugins (**nextjs-scaffold**, **nestjs-scaffold**) build on it.

## Commands
- `/sdlc:adopt` — add the `ai/` layout to an existing repo (any stack)
- `/sdlc:explore <request>` — before a spec: read the code, present 2–4 implementation options with effort, risk, reversibility, a recommendation and the `/ai-spec` line to run next; writes `ai/explorations/NNNN-slug.md`
- `/sdlc:sync` — regenerate `.claude/` and `.cursor/` adapters from `ai/`

Project-level slash commands (generated into each repo from `ai/tasks/`): `/ai-explore /ai-spec /ai-plan /ai-step /ai-fix /ai-chore /ai-check`.

## Skills (model-invoked, hidden from the menu)
- `ai-layout` — the `ai/` directory and its templates; where an AI-related file belongs
- `ai-hooks` — session / edit / test-command / usage logging to `ai/runs/`, and the dont-touch guard

## Agent
- `reviewer` — independent, read-only review of the branch diff; JSON verdict

## Hooks
Registered plugin-wide; no-op in repos without `ai/`; never print to stdout (cache-neutral).

## Install
```
/plugin marketplace add git@gitlab.nsix.io:infra/ai-sdlc.git
/plugin install sdlc@n6
```
Local: `claude --plugin-dir ~/code/nsix/infra/ai-sdlc`

## The loop each repo follows
`/ai-explore` (options) → `/ai-spec` (Given/When/Then) → `/ai-plan` (checklist) → `/ai-step` one step at a time → `/ai-check` → commit `ai(<task>): …` → MR labelled `ai-assisted`.

## Conventions
Prompt, skill and hook changes go through MR with a before/after run. Tag releases; scaffolds record the tag they used in `ai/AGENTS.md`.
