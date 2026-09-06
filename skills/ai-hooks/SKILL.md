---
name: ai-hooks
user-invocable: false
description: Claude Code hooks that log sessions, edits, test commands and per-session token usage to ai/runs/, and guard dont-touch paths. Use when the run log is empty or wrong, when a session edits a file it should not, or when installing hooks in a repo without the plugin.
---

# ai-hooks

The plugin registers these hooks globally (hooks/hooks.json). Every script:
- reads the hook event JSON from stdin (session_id, transcript_path, cwd, tool_name, tool_input);
- exits 0 silently if `ai/` does not exist in cwd, so the plugin is safe to enable everywhere;
- prints NOTHING to stdout. Text printed from SessionStart or UserPromptSubmit
  hooks enters the model's context and breaks the cached prefix. Only
  guard-paths.js writes to stderr, and only when blocking (exit 2).

| Event | Script | Writes |
|---|---|---|
| SessionStart | session-start.js | ai/runs/sessions.jsonl: session_id, ts, user, branch, plan_in_flight |
| PreToolUse Edit/Write | guard-paths.js | nothing; exit 2 + stderr reason when the target matches ai/docs/dont-touch.md |
| PostToolUse Edit/Write | log-edit.js | ai/runs/edits.jsonl: session_id, ts, file |
| PostToolUse Bash | log-cmd.js | ai/runs/cmds.jsonl when the command ran a test, lint or e2e command (vitest, jest, biome, playwright, pnpm/npm test|lint|e2e|check) |
| Stop | session-stop.js | one line to ai/runs/log.csv with tokens, cache hit rate, cost |

## log.csv header (create in every repo)
ts,session_id,user,branch,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted

`accepted` is filled by the developer at commit time (y/n/partial). `user` is
$GITLAB_USER or `git config user.name`.

## Pricing
session-stop.js reads prices from ai/models.yaml if present:
```yaml
pricing:            # USD per million tokens
  default: { input: 3, output: 15, cache_read: 0.3, cache_write: 3.75 }
```
Otherwise it uses the default above and marks the row with `~` in cost.

## dont-touch.md format the guard reads
Lines beginning with "- `" — the backticked path prefix is the rule:
- `prisma/migrations/`
- `.env`
- `pnpm-lock.yaml` (or package-lock.json)

## gitignore lines for every repo
ai/runs/*.json
ai/runs/*.jsonl
.claude/settings.local.json
CLAUDE.local.md

## Fortnightly read
hit_rate < 0.70 → something dynamic sits in the prefix (AGENTS.md edited mid-session, a hook printing, a restart).
Sessions with edits but no cmds → tests were not run; tighten the task prompt.
Files in edits.jsonl not in the commit → what the model changed that you dropped; check why.

## Without the plugin
Copy scripts/ to ai/make/hooks/ and register the same hooks in .claude/settings.json
with `node ai/make/hooks/<script>.js` as the command.
