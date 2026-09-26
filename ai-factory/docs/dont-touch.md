# Do not edit — enforced by the guard-paths hook

Lines starting with "- `" are rules; the backticked prefix is matched against the target path.

- `node_modules/`
- `.env`
- `.claude/`
- `.cursor/`
- `.codex/`
- `ai-factory/runs/`
- `ai-factory/tasks/`
- `ai-factory/agents/`
- `ai-factory/make/`
- `LICENSE`

`ai-factory/tasks/`, `ai-factory/agents/` and `ai-factory/make/` are symlinks into the templates — edit the target
under `skills/ai-layout/templates/` (or `agents/`) instead. To change adapters, edit `ai-factory/`
and run /t4:sync-sdlc.
