#!/usr/bin/env bash
# Pins the two ai-factory/runs/log.csv writers to one schema.
# The interactive side (skills/ai-hooks/scripts/session-stop.js writing log.pending.csv, and
# log-flush.js moving those rows into log.csv on `git commit`) shares scripts/_log-schema.js.
# The headless writer (skills/ai-layout/templates/ai-factory/make/log.js) runs inside an adopted repo
# and cannot require it, so it declares HEADER and the guard separately. This asserts the two
# agree, that each row has as many fields as the header, that a pre-schema file is moved aside
# rather than mixed, and that the flush moves rows exactly once and only on a commit.
set -euo pipefail
cd "$(dirname "$0")/../../.."   # repo root
HOOK=skills/ai-hooks/scripts/session-stop.js
SCHEMA=skills/ai-hooks/scripts/_log-schema.js
FLUSH=skills/ai-hooks/scripts/log-flush.js
MAKE=skills/ai-layout/templates/ai-factory/make/log.js
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

h1=$(sed -n 's/^const HEADER = "\(.*\)";$/\1/p' "$SCHEMA" | head -1)
h2=$(sed -n 's/^const HEADER = "\(.*\)";$/\1/p' "$MAKE" | head -1)
[ -n "$h1" ] && [ -n "$h2" ] || fail "could not read HEADER from both writers"
[ "$h1" = "$h2" ] || fail "writers disagree on the header:
  hook: $h1
  make: $h2"
cols=$(awk -F, '{print NF}' <<<"$h1")
# Pinned, not derived: a column added or dropped by accident would otherwise slide through
# every width check below, because they all measure against whatever the header happens to say.
[ "$cols" = 17 ] || fail "the header has $cols columns, expected 17"
[ "$h1" = "ts,session_id,source,user,branch,task,tool,agent,model,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted" ] \
  || fail "the header is not the expected 17 columns:
  $h1"

# 1. interactive writer — into the pending file, never straight into log.csv
mkdir -p "$TMP/ai-factory/runs"; cp skills/ai-hooks/fixtures/transcript.jsonl "$TMP/"
stop() { printf '{"session_id":"fx","cwd":"%s","transcript_path":"%s/transcript.jsonl","hook_event_name":"Stop"}' "$TMP" "$TMP" | node "$HOOK"; }
flush() { printf '{"session_id":"fx","cwd":"%s","tool_name":"Bash","tool_input":{"command":%s}}' "$TMP" "$1" | node "$FLUSH"; }
stop
PEND="$TMP/ai-factory/runs/log.pending.csv"
[ ! -e "$TMP/ai-factory/runs/log.csv" ] || fail "the Stop hook wrote log.csv directly; it must buffer in log.pending.csv"
[ "$(head -1 "$PEND")" = "$h1" ] || fail "hook wrote the wrong header"
n=$(awk -F, 'NR==2{print NF}' "$PEND")
[ "$n" = "$cols" ] || fail "hook row has $n fields, header has $cols"
grep -q ',session,' "$PEND" || fail "hook row is not marked source=session"
grep -q ',claude-sonnet-4-5,' "$PEND" || fail "hook row lost the model"
# `agent` (column 8, right after `tool`) is empty on a session row — the subagent rows carry it
a=$(awk -F, 'NR==2{print $8}' "$PEND")
[ -z "$a" ] || fail "session row should leave agent empty, got '$a'"
[ "$(awk -F, 'NR==1{print $8}' "$PEND")" = agent ] || fail "column 8 of the header is not agent"

# 1b. the flush: only a `git commit` moves the rows, exactly once, and stages log.csv
( cd "$TMP" && git init -q && git config user.email t@t && git config user.name t && printf 'ai-factory/runs/*.jsonl\nai-factory/runs/log.pending.csv\n' > .gitignore )
flush '"git status"'
[ -e "$PEND" ] || fail "a command that is not a commit flushed the pending rows"
[ ! -e "$TMP/ai-factory/runs/log.csv" ] || fail "a command that is not a commit created log.csv"
flush '"git commit -m x --dry-run"'
[ -e "$PEND" ] || fail "a dry-run commit flushed the pending rows"
stop
flush '"cd sub && git -C .. commit -m \"ai(fix): x\""'
[ ! -e "$PEND" ] || fail "the pending file survived a commit"
[ "$(head -1 "$TMP/ai-factory/runs/log.csv")" = "$h1" ] || fail "flush wrote the wrong header"
[ "$(wc -l < "$TMP/ai-factory/runs/log.csv")" -eq 3 ] || fail "flush should leave header + 2 rows, got $(wc -l < "$TMP/ai-factory/runs/log.csv")"
[ "$(grep -c ',session,' "$TMP/ai-factory/runs/log.csv")" -eq 2 ] || fail "flush lost or duplicated rows"
( cd "$TMP" && git diff --cached --name-only | grep -qx 'ai-factory/runs/log.csv' ) || fail "flush did not stage log.csv"
flush '"git commit -m again"'
[ "$(wc -l < "$TMP/ai-factory/runs/log.csv")" -eq 3 ] || fail "a second commit with nothing pending changed log.csv"

# 2. headless writer, appended the way ai.mk does
printf '{"session_id":"hl","num_turns":2,"total_cost_usd":0.01,"usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}' \
  > "$TMP/ai-factory/runs/r-check.json"
node "$MAKE" "$TMP/ai-factory/runs/r-check.json" check claude some-model >> "$TMP/ai-factory/runs/log.csv"
n=$(awk -F, 'END{print NF}' "$TMP/ai-factory/runs/log.csv")
[ "$n" = "$cols" ] || fail "headless row has $n fields, header has $cols"
grep -q ',make,' "$TMP/ai-factory/runs/log.csv" || fail "headless row is not marked source=make"
a=$(awk -F, 'END{print $8}' "$TMP/ai-factory/runs/log.csv")
[ -z "$a" ] || fail "headless row should leave agent empty, got '$a'"
grep -q ',check,claude,,some-model,' "$TMP/ai-factory/runs/log.csv" || fail "headless row lost task/tool/agent/model order"
[ "$(wc -l < "$TMP/ai-factory/runs/log.csv")" -eq 4 ] || fail "expected header + 3 rows"

# 3. a pre-schema log.csv is preserved, not mixed, when the flush reaches it
rm -rf "$TMP/ai-factory/runs"; mkdir -p "$TMP/ai-factory/runs"
printf 'ts,session_id,user,branch,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted\n2026-01-01T00:00:00Z,old,me,main,1,1,1,0,0,0.00,0.1,\n' \
  > "$TMP/ai-factory/runs/log.csv"
stop; flush '"git commit -m x"'
[ "$(head -1 "$TMP/ai-factory/runs/log.csv")" = "$h1" ] || fail "pre-schema file was not migrated"
[ "$(wc -l < "$TMP/ai-factory/runs/log.csv")" -eq 2 ] || fail "migrated file should hold header + the new row only"
grep -q ',old,' "$TMP/ai-factory/runs/log.previous.csv" || fail "old rows were not preserved in log.previous.csv"
if grep -q ',old,' "$TMP/ai-factory/runs/log.csv"; then fail "old rows leaked into the new file"; fi

# 4. the guard itself is duplicated, so the two copies must not drift
guard() { awk '/--- shared schema guard/,/--- end shared schema guard ---/' "$1"; }
[ -n "$(guard "$SCHEMA")" ] || fail "no shared schema guard found in $SCHEMA"
diff <(guard "$SCHEMA") <(guard "$MAKE") >/dev/null || fail "the shared schema guard has drifted between the writers:
$(diff <(guard "$SCHEMA") <(guard "$MAKE") | head -20)"
if grep -q 'shared schema guard' "$HOOK"; then fail "$HOOK carries its own copy of the guard; it must require $SCHEMA"; fi

# 5. a short row under a header that MATCHES is the case a header check cannot see.
# This is what an older hook still installed elsewhere appends.
rm -rf "$TMP/ai-factory/runs"; mkdir -p "$TMP/ai-factory/runs"
{ echo "$h1"
  echo '2026-01-01T00:00:00Z,keep,session,me,main,,claude,,m,1,1,1,0,0,0.00,0.1,'
  echo '2026-01-02T00:00:00Z,short,me,main,1,1,1,0,0,0.00,0.1,'
} > "$TMP/ai-factory/runs/log.csv"
stop; flush '"git commit -m x"'
grep -q ',short,' "$TMP/ai-factory/runs/log.previous.csv" || fail "the short row was not moved aside"
if grep -q ',short,' "$TMP/ai-factory/runs/log.csv"; then fail "the short row survived in log.csv"; fi
grep -q ',keep,' "$TMP/ai-factory/runs/log.csv" || fail "a conforming row was moved aside with the short one"
[ "$(head -1 "$TMP/ai-factory/runs/log.csv")" = "$h1" ] || fail "header lost while moving a short row"
while read -r line; do
  n=$(awk -F, '{print NF}' <<<"$line")
  [ "$n" = "$cols" ] || fail "row left in log.csv has $n fields, header has $cols"
done < <(tail -n +2 "$TMP/ai-factory/runs/log.csv")

# 6. a quoted comma is one field, not two — a naive split would quarantine a valid row
rm -rf "$TMP/ai-factory/runs"; mkdir -p "$TMP/ai-factory/runs"
{ echo "$h1"
  echo '2026-01-01T00:00:00Z,q,session,"Doe, Jane",main,,claude,,m,1,1,1,0,0,0.00,0.1,'
} > "$TMP/ai-factory/runs/log.csv"
stop; flush '"git commit -m x"'
grep -q 'Doe, Jane' "$TMP/ai-factory/runs/log.csv" || fail "a row with a quoted comma was wrongly moved aside"
[ ! -f "$TMP/ai-factory/runs/log.previous.csv" ] || fail "nothing should have been quarantined"

# 7. the headless writer guards the same way
rm -rf "$TMP/ai-factory/runs"; mkdir -p "$TMP/ai-factory/runs"
{ echo "$h1"; echo '2026-01-02T00:00:00Z,short,me,main,1,1,1,0,0,0.00,0.1,'; } > "$TMP/ai-factory/runs/log.csv"
printf '{"session_id":"hl","num_turns":2,"total_cost_usd":0.01,"usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}' \
  > "$TMP/ai-factory/runs/r-check.json"
node "$MAKE" "$TMP/ai-factory/runs/r-check.json" check claude some-model >> "$TMP/ai-factory/runs/log.csv"
grep -q ',short,' "$TMP/ai-factory/runs/log.previous.csv" || fail "headless writer did not move the short row aside"
if grep -q ',short,' "$TMP/ai-factory/runs/log.csv"; then fail "headless writer left the short row in log.csv"; fi

# 8. deltas at write (AC14): a row carries the increment since that session's previous row.
# The claim ledger `.counted.<session_id>` is what remembers which usage records are already
# accounted for, so this needs a transcript whose records carry `uuid` — transcript.jsonl has none
# on purpose, and keeps the un-deduplicated path covered.
rm -rf "$TMP/ai-factory/runs"; mkdir -p "$TMP/ai-factory/runs"
cp skills/ai-hooks/fixtures/transcript-uuid.jsonl "$TMP/uuid.jsonl"
stopd() { printf '{"session_id":"dl","cwd":"%s","transcript_path":"%s/uuid.jsonl","hook_event_name":"Stop"}' "$TMP" "$TMP" | node "$HOOK"; }
# Independent of the hook: sums the transcript here, so the assertion measures the writer rather
# than agreeing with it. Prints "turns inp out cr cw".
total() { node -e '
  const fs = require("fs"); const t = [0,0,0,0,0];
  for (const l of fs.readFileSync(process.argv[1], "utf8").split("\n")) {
    if (!l.trim()) continue; const u = JSON.parse(l).message?.usage; if (!u) continue;
    t[0]++; t[1] += u.input_tokens; t[2] += u.output_tokens;
    t[3] += u.cache_read_input_tokens; t[4] += u.cache_creation_input_tokens;
  }
  process.stdout.write(t.join(" "));' "$1"; }

stopd
first=$(awk -F, 'NR==2{print $10, $11, $12, $13, $14}' "$PEND")
# AC14's last clause: the first row of a session claims nothing beforehand, so its increment is
# the whole transcript so far.
[ "$first" = "$(total "$TMP/uuid.jsonl")" ] \
  || fail "the first row of a session should carry the whole transcript, got '$first' for '$(total "$TMP/uuid.jsonl")'"
[ -f "$TMP/ai-factory/runs/.counted.dl" ] || fail "no claim ledger written for session dl"

cat >> "$TMP/uuid.jsonl" <<'EOF'
{"type":"assistant","uuid":"u-0004","message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":700,"output_tokens":90,"cache_read_input_tokens":7000,"cache_creation_input_tokens":50}}}
{"type":"assistant","uuid":"u-0005","message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":300,"output_tokens":60,"cache_read_input_tokens":8000,"cache_creation_input_tokens":0}}}
EOF
stopd
[ "$(wc -l < "$PEND")" -eq 3 ] || fail "expected header + 2 session rows, got $(wc -l < "$PEND")"
second=$(awk -F, 'NR==3{print $10, $11, $12, $13, $14}' "$PEND")
# Only the two appended records, not a re-sum: turns, input, output, cache_read, cache_write.
[ "$second" = "2 1000 150 15000 50" ] \
  || fail "the second row should carry only the new records (2 1000 150 15000 50), got '$second'"
summed=$(awk -F, 'NR>1{for(i=10;i<=14;i++) s[i]+=$i} END{print s[10], s[11], s[12], s[13], s[14]}' "$PEND")
[ "$summed" = "$(total "$TMP/uuid.jsonl")" ] \
  || fail "the rows of one session must sum to the transcript total: rows '$summed', transcript '$(total "$TMP/uuid.jsonl")'"
# And a Stop that adds nothing adds no row: every record is already claimed.
stopd
[ "$(wc -l < "$PEND")" -eq 3 ] || fail "a Stop with nothing new to count wrote a row"

# 9. the `task` column on a session row (AC10, AC11): filled from `.task.<session_id>`, empty
# without one. The column session-stop.js wrote empty for every interactive session until now, so
# a regression here is invisible — the row is still valid and still the right width.
rm -rf "$TMP/ai-factory/runs"; mkdir -p "$TMP/ai-factory/runs"
stop
t=$(awk -F, 'NR==2{print $6}' "$PEND")
[ -z "$t" ] || fail "with no task file the task column must stay empty, got '$t'"
[ "$(awk -F, 'NR==1{print $6}' "$PEND")" = task ] || fail "column 6 of the header is not task"

rm -rf "$TMP/ai-factory/runs"; mkdir -p "$TMP/ai-factory/runs"
printf 'plan\n' > "$TMP/ai-factory/runs/.task.fx"
stop
t=$(awk -F, 'NR==2{print $6}' "$PEND")
[ "$t" = plan ] || fail "the session row should carry the task file's name (plan), got '$t'"
n=$(awk -F, 'NR==2{print NF}' "$PEND")
[ "$n" = "$cols" ] || fail "the row carrying a task has $n fields, header has $cols"
# Keyed by session_id: a file belonging to another session must not fill this one's column.
rm -rf "$TMP/ai-factory/runs"; mkdir -p "$TMP/ai-factory/runs"
printf 'spec\n' > "$TMP/ai-factory/runs/.task.someone-else"
stop
t=$(awk -F, 'NR==2{print $6}' "$PEND")
[ -z "$t" ] || fail "another session's task file filled this session's task column with '$t'"

echo "log schema ok — $cols columns, both writers agree, per-row width enforced, migration preserves old rows, flush moves rows once on commit, session rows are increments and carry the session's task"
