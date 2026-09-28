---
name: ai-hooks
user-invocable: false
description: Claude Code hooks that log sessions, edits, test commands and per-session token usage to ai-factory/runs/, and guard dont-touch paths. Use when the run log is empty or wrong, when a session edits a file it should not, or when installing hooks in a repo without the plugin.
---

# ai-hooks

The plugin registers these hooks globally (hooks/hooks.json). Every script:
- reads the hook event JSON from stdin (session_id, transcript_path, cwd, tool_name, tool_input);
- exits 0 silently if `ai-factory/` does not exist in cwd, so the plugin is safe to enable everywhere;
- prints NOTHING to stdout. Text printed from SessionStart or UserPromptSubmit
  hooks enters the model's context and breaks the cached prefix. Only
  guard-paths.js writes to stderr, and only when blocking (exit 2).

| Event | Script | Writes |
|---|---|---|
| SessionStart | session-start.js | ai-factory/runs/sessions.jsonl: session_id, ts, user, branch, plan_in_flight |
| PreToolUse Edit/Write | guard-paths.js | nothing; exit 2 + stderr reason when the target matches ai-factory/docs/dont-touch.md |
| PreToolUse Bash | log-flush.js | on `git commit` only: moves the rows in ai-factory/runs/log.pending.csv into ai-factory/runs/log.csv and stages it |
| PostToolUse Edit/Write | log-edit.js | ai-factory/runs/edits.jsonl: session_id, ts, file |
| PostToolUse Bash | log-cmd.js | ai-factory/runs/cmds.jsonl when the command ran a test, lint or e2e command (vitest, jest, biome, playwright, pnpm/npm test|lint|e2e|check) |
| Stop | session-stop.js | one line to ai-factory/runs/log.pending.csv with tokens, cache hit rate, cost |

The row counts the session's own transcript. Tokens spent inside a subagent — the reviewer,
tester, architect, analyst, or the explorer, specifier, planner and implementer that the four
loop steps delegate to — are not in the main transcript and so not in the row: a session that
delegated a step under-counts by that step's cost. The hook does not read subagent transcripts
today; recovering them is a separate change.

## Why the session row is buffered
A Stop fires after every turn. Written straight into the tracked log.csv, the file was dirty for
the whole session, `git checkout` refused to switch branches, and every branch grew its own tail
of rows that conflicted on merge. So session-stop.js appends to `ai-factory/runs/log.pending.csv`
(gitignored), and log-flush.js moves those rows into log.csv when the session runs `git commit`,
staging the file so the rows land in the commit that produced the work. A commit made from a
terminal skips the hook; `make log-flush` does the same move by hand, and unflushed rows just
wait for the next commit. `ai-factory/runs/log.csv merge=union` in .gitattributes keeps two branches'
rows from conflicting when they merge — the file is append-only, so union is the right merge.

## log.csv — one schema, two writers
ts,session_id,source,user,branch,task,tool,agent,model,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted

`source` is `session` (this Stop hook) or `make` (ai-factory/make/log.js, headless). Both write
these 17 columns; each blanks what it cannot know — an interactive session has no `task`,
a headless run has no separate turn accounting beyond `num_turns`, and neither names an
`agent` — both write it empty. `accepted` is filled by
the developer at commit time (y/n/partial). `user` is $GITLAB_USER or `git config user.name`.

The plugin-side scripts (session-stop.js, log-flush.js) share `scripts/_log-schema.js`, and the
token accounting — the transcript sum, the per-session claim ledger and the models.yaml price
resolution — sits in `scripts/_usage.js`, pinned by `fixtures/check-usage.sh`. The
headless writer runs inside an adopted repo and cannot require it, so it declares the header
and the schema guard separately. `fixtures/check-log-schema.sh` asserts the two copies have not
drifted, that every row matches the header width, that both kinds of migration preserve old
rows, and that the flush moves rows exactly once and only on a commit. Run it after touching
any of the three.

Two things can be wrong with a log.csv (or a pending file), and both are repaired on the next
write — for log.csv that is the flush or a headless run:

- **The header is not the above.** The file predates this schema; its rows came from two
  writers with different column meanings. All of them move to `ai-factory/runs/log.previous.csv`
  and a clean file is started.
- **The header matches but a row is not 17 fields.** A writer still on an older schema
  appended into a current file — an older hook installed elsewhere, say. A header check
  cannot see this, which is how 12-field rows once sat under a 16-field header for a whole
  session. Only the offending rows move, under a dated comment naming why.

Rows are never reinterpreted into the new columns: width alone cannot say which writer
produced a row, and guessing is what caused the original mixed-schema bug. Field counting
is quote-aware, so a value containing a comma or a newline is one field, not several.

## Pricing
session-stop.js prices a run with the model the transcript says actually ran, so any
provider costs correctly. It reads ai-factory/models.yaml if present:
```yaml
pricing:            # USD per million tokens
  default: { input: 3, output: 15, cache_read: 0.3, cache_write: 3.75 }
  claude-haiku-4-5: { input: 1, output: 5, cache_read: 0.1, cache_write: 1.25 }
```
Match order: the exact model id, then the longest listed id the model starts with (so
`claude-haiku-4-5` covers `claude-haiku-4-5-20251001`), then `default`. With no match it
uses the built-in figures above and marks the row `~` in cost — an estimate, not a price.

## dont-touch.md format the guard reads
Lines beginning with "- `" — the backticked path prefix is the rule:
- `prisma/migrations/`
- `.env`
- `pnpm-lock.yaml` (or package-lock.json)

## gitignore lines for every repo
ai-factory/runs/*.json
ai-factory/runs/*.jsonl
ai-factory/runs/log.pending.csv
ai-factory/runs/.counted.*
ai-factory/runs/.task.*
.claude/settings.local.json
CLAUDE.local.md

## gitattributes line for every repo
ai-factory/runs/log.csv merge=union

## Fortnightly read
hit_rate < 0.70 → something dynamic sits in the prefix (AGENTS.md edited mid-session, a hook printing, a restart).
Sessions with edits but no cmds → tests were not run; tighten the task prompt.
Files in edits.jsonl not in the commit → what the model changed that you dropped; check why.

## Without the plugin
Copy scripts/ (including `_common.js`, `_log-schema.js` and `_usage.js`) to ai-factory/make/hooks/ and register the
same hooks in .claude/settings.json with `node ai-factory/make/hooks/<script>.js` as the command.
