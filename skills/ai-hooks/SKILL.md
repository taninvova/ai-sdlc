---
name: ai-hooks
user-invocable: false
description: Claude Code and Codex hooks that log sessions, edits, test commands and per-session token usage to ai-factory/runs/, and guard dont-touch paths. Use when the run log is empty or wrong, when a session edits a file it should not, or when installing hooks in a repo without the plugin.
---

# ai-hooks

Claude loads `hooks/hooks.json`; Codex loads `hooks/codex.json` through its plugin
manifest. In Codex, review and trust the definitions in `/hooks`; installing a plugin
alone does not enable untrusted hooks. Codex adapters by themselves do not install hooks.
The Codex bridge selects the host explicitly and shares policy, schema and locking code.
Its `apply_patch` parser checks every add, update, delete and rename destination before
allowing the operation, and logs each touched path after execution.

Codex Stop/SubagentStop accounting reads rollout `token_usage_record` entries using
response IDs for de-duplication. Older `event_msg/token_count` rollouts use differences
between cumulative snapshots. Mirrored snapshots are ignored when response records exist.
Cached input is separated from total input; reasoning output is already included in output.
Codex cost stays empty because rollouts do not report a price. Transcript formats are
version-specific; keep `fixtures/check-codex.sh` and a host smoke run with any format change.
Task attribution accepts `/t4:<task>`, `$t4-<task>` and `$t4:t4-<task>`.


The plugin registers these hooks globally (hooks/hooks.json). Every script:
- reads the hook event JSON from stdin (session_id, transcript_path, cwd, tool_name, tool_input);
- exits 0 silently if `ai-factory/` does not exist in cwd, so the plugin is safe to enable everywhere;
- prints NOTHING to stdout. Text printed from SessionStart or UserPromptSubmit
  hooks enters the model's context and breaks the cached prefix. Only
  guard-paths.js writes to stderr, and only when blocking (exit 2).

| Event | Script | Writes |
|---|---|---|
| SessionStart | session-start.js | ai-factory/runs/sessions.jsonl: session_id, ts, user, branch, plan_in_flight |
| UserPromptSubmit | log-task.js | ai-factory/runs/.task.&lt;session_id&gt;: the bare name of the `/t4:` command the prompt carried (`spec`, not `/t4:spec`), for the rows written later; nothing at all when it carried none |
| PreToolUse Edit/Write | guard-paths.js | nothing; exit 2 + stderr reason when the target matches ai-factory/docs/dont-touch.md |
| PreToolUse Bash | log-flush.js | on `git commit` only: moves the rows in ai-factory/runs/log.pending.csv into ai-factory/runs/log.csv and stages it |
| PostToolUse Edit/Write | log-edit.js | ai-factory/runs/edits.jsonl: session_id, ts, file |
| PostToolUse Bash | log-cmd.js | ai-factory/runs/cmds.jsonl when the command ran a test, lint or e2e command (vitest, jest, biome, playwright, pnpm/npm test|lint|e2e|check) |
| Stop | session-stop.js | one line to ai-factory/runs/log.pending.csv, `source=session`: tokens, cache hit rate, cost — the increment since this session's previous row |
| SubagentStop | subagent-stop.js | one line to ai-factory/runs/log.pending.csv, `source=agent`: one row per concluded subagent, summed from that agent's own transcript and carrying its name in the `agent` column |

Tokens spent inside a subagent used to be missing from the log entirely. They are not any more.
A session that delegates gets a row per agent as well as a row per turn — the reviewer, tester,
architect, analyst, and the explorer, specifier, planner and implementer that the four loop steps
delegate to each conclude with their own `source=agent` row, named in the `agent` column and
carrying the `task` the session was running. So the cost of a delegated step is in the log, and it
can be grouped by agent, by task, by session or by model rather than only totalled. The parent
transcript is never opened for an agent row: everything comes from the event payload, the agent's
own transcript and the cwd.

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

`source` says which event wrote the row: `session` (the Stop hook, one per turn), `agent` (the
SubagentStop hook, one per concluded subagent) or `make` (ai-factory/make/log.js, headless). All
three write these 17 columns; each blanks what it cannot know — a headless run has no separate turn
accounting beyond `num_turns`, and only an `agent` row names an `agent`, the other two write it
empty. `task` is the bare name of the last `/t4:` command the session submitted, and it is the
*session's* task on an agent row too, so a specifier spawned under `/t4:run` is `run,specifier`
rather than a fixed agent-to-task map; a prompt carrying two `/t4:` commands is attributed to the
first match, and a prompt carrying none leaves the last task standing rather than clearing it.
`accepted` is filled by the developer at commit time (y/n/partial). `user` is $GITLAB_USER or
`git config user.name`.

The plugin-side scripts (session-stop.js, log-flush.js) share `scripts/_log-schema.js`, and the
token accounting — the transcript sum, the per-session claim ledger and the models.yaml price
resolution — sits in `scripts/_usage.js`, pinned by `fixtures/check-usage.sh`. The
headless writer runs inside an adopted repo and cannot require it, so it declares the header
and the schema guard separately. `fixtures/check-log-schema.sh` asserts the two copies have not
drifted, that every row matches the header width, that both kinds of migration preserve old
rows, and that the flush moves rows exactly once and only on a commit. Run it after touching
any of the three.

The reader on the other side of that schema,
`skills/ai-layout/templates/ai-factory/make/cost.js`, carries a **third** copy of the same
`records()`/`width()` pair, because a template copied into an adopted repo cannot require anything
from the plugin. `fixtures/check-log-schema.sh` pins all three against each other, and
`skills/ai-layout/scripts/check-cost.sh` holds the reader itself against the fixture logs in
`fixtures/cost/`, whose totals are known by construction. Run both after touching the schema.

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

## Every row is an increment, and a usage record is counted once
A row is the delta since that session's previous row, not a re-sum of the transcript, so the rows
of one `session_id` **add up** to what the session spent instead of each restating a running total.
The bookkeeping is one file per session beside the run log, `ai-factory/runs/.counted.<session_id>`
(gitignored, append-only), holding `u:<message uuid>` for a usage record already counted and
`a:<agent id>` for a subagent already reported.

- **The `uuid` rule.** A usage record belongs to one agent and is counted once however many
  transcripts carry a copy of it. It has to be: context inheritance re-logs a prefix of the
  parent's records into each forked child, so a per-transcript sum counts those tokens once per
  transcript that carries them. A record with **no `uuid`** cannot be claimed and is therefore
  counted every time — an over-count on a transcript format that omits the key, never a silent
  loss of the tokens.
- **One row per agent.** A resumed subagent fires SubagentStop again and the `a:` claim makes the
  second event a no-op. The id is claimed *before* the transcript is summed, so two subagents
  concluding at once cannot lose each other's claims to a read-modify-write. The cost of that
  order: a first event whose agent transcript is missing or unparseable still burns the id, writes
  no row, and a later well-formed event for the same agent writes none either.
- Claims are durable before the row is, for the same reason, so a swallowed append failure leaves
  records claimed with no row carrying them, and later increments do not re-report them.

Rows written before 2.0.0 are cumulative rather than increments, and they are not reinterpreted:
the 17-column header moves every one of them to `ai-factory/runs/log.previous.csv` — the first
bullet above — which is where rows written under the old semantics belong.

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

## gitignore lines inside ai-factory/.gitignore
/runs/*.json
/runs/*.jsonl
/runs/log.pending.csv
/runs/.counted.*
/runs/.task.*
/runs/report.html
/runs/tmp/

## gitattributes line inside ai-factory/.gitattributes
runs/log.csv merge=union

Keep these rules workspace-local. Preserve existing root Git files; do not add host personal
settings to project policy. Hooks use host events and permissions; the Edit/Write/MultiEdit
guard does not intercept arbitrary shell writes, and these Claude hooks are not installed by
the Codex task adapter. A missing hook is not enforced protection. Never disable the host's
sandbox or grant broad permissions to compensate.

## Fortnightly read
hit_rate < 0.70 → something dynamic sits in the prefix (AGENTS.md edited mid-session, a hook printing, a restart).
Sessions with edits but no cmds → tests were not run; tighten the task prompt.
Files in edits.jsonl not in the commit → what the model changed that you dropped; check why.

## Without the plugin
Copy scripts/ (including `_common.js`, `_safe-files.js`, `_log-schema.js` and `_usage.js`) to ai-factory/make/hooks/ and register the
same hooks in .claude/settings.json with `node ai-factory/make/hooks/<script>.js` as the command.
