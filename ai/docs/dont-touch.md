# Do not edit — enforced by the guard-paths hook

Lines starting with "- `" are rules; the backticked prefix is matched against the target path.

- `node_modules/`
- `.env`
- `.claude/`
- `.cursor/`
- `.codex/`
- `ai/runs/`
- `ai/tasks/`
- `ai/agents/`
- `ai/make/`
- `LICENSE`

`ai/tasks/`, `ai/agents/` and `ai/make/` are symlinks into the templates — edit the target
under `skills/ai-layout/templates/` (or `agents/`) instead. To change adapters, edit `ai/`
and run /ai-sdlc:sync.
