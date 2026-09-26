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
  echo '2026-01-01T00:00:00Z,keep,session,me,main,,claude,m,1,1,1,0,0,0.00,0.1,'
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
  echo '2026-01-01T00:00:00Z,q,session,"Doe, Jane",main,,claude,m,1,1,1,0,0,0.00,0.1,'
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

echo "log schema ok — $cols columns, both writers agree, per-row width enforced, migration preserves old rows, flush moves rows once on commit"
