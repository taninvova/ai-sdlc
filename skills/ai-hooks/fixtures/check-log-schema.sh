#!/usr/bin/env bash
# Pins the two ai/runs/log.csv writers to one schema.
# The interactive writer (skills/ai-hooks/scripts/session-stop.js) and the headless writer
# (skills/ai-layout/templates/ai/make/log.js) declare HEADER separately — they run in
# different places and cannot share a module. This asserts they agree, that each row has as
# many fields as the header, and that a pre-schema file is moved aside rather than mixed.
set -euo pipefail
cd "$(dirname "$0")/../../.."   # repo root
HOOK=skills/ai-hooks/scripts/session-stop.js
MAKE=skills/ai-layout/templates/ai/make/log.js
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

h1=$(sed -n 's/^const HEADER = "\(.*\)";$/\1/p' "$HOOK" | head -1)
h2=$(sed -n 's/^const HEADER = "\(.*\)";$/\1/p' "$MAKE" | head -1)
[ -n "$h1" ] && [ -n "$h2" ] || fail "could not read HEADER from both writers"
[ "$h1" = "$h2" ] || fail "writers disagree on the header:
  hook: $h1
  make: $h2"
cols=$(awk -F, '{print NF}' <<<"$h1")

# 1. interactive writer
mkdir -p "$TMP/ai/runs"; cp skills/ai-hooks/fixtures/transcript.jsonl "$TMP/"
printf '{"session_id":"fx","cwd":"%s","transcript_path":"%s/transcript.jsonl","hook_event_name":"Stop"}' "$TMP" "$TMP" \
  | node "$HOOK"
[ "$(head -1 "$TMP/ai/runs/log.csv")" = "$h1" ] || fail "hook wrote the wrong header"
n=$(awk -F, 'NR==2{print NF}' "$TMP/ai/runs/log.csv")
[ "$n" = "$cols" ] || fail "hook row has $n fields, header has $cols"
grep -q ',session,' "$TMP/ai/runs/log.csv" || fail "hook row is not marked source=session"
grep -q ',claude-sonnet-4-5,' "$TMP/ai/runs/log.csv" || fail "hook row lost the model"

# 2. headless writer, appended the way ai.mk does
printf '{"session_id":"hl","num_turns":2,"total_cost_usd":0.01,"usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}' \
  > "$TMP/ai/runs/r-check.json"
node "$MAKE" "$TMP/ai/runs/r-check.json" check claude some-model >> "$TMP/ai/runs/log.csv"
n=$(awk -F, 'END{print NF}' "$TMP/ai/runs/log.csv")
[ "$n" = "$cols" ] || fail "headless row has $n fields, header has $cols"
grep -q ',make,' "$TMP/ai/runs/log.csv" || fail "headless row is not marked source=make"
[ "$(wc -l < "$TMP/ai/runs/log.csv")" -eq 3 ] || fail "expected header + 2 rows"

# 3. a pre-schema file is preserved, not mixed
rm -rf "$TMP/ai/runs"; mkdir -p "$TMP/ai/runs"
printf 'ts,session_id,user,branch,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted\n2026-01-01T00:00:00Z,old,me,main,1,1,1,0,0,0.00,0.1,\n' \
  > "$TMP/ai/runs/log.csv"
printf '{"session_id":"fx","cwd":"%s","transcript_path":"%s/transcript.jsonl","hook_event_name":"Stop"}' "$TMP" "$TMP" \
  | node "$HOOK"
[ "$(head -1 "$TMP/ai/runs/log.csv")" = "$h1" ] || fail "pre-schema file was not migrated"
[ "$(wc -l < "$TMP/ai/runs/log.csv")" -eq 2 ] || fail "migrated file should hold header + the new row only"
grep -q ',old,' "$TMP/ai/runs/log.previous.csv" || fail "old rows were not preserved in log.previous.csv"
if grep -q ',old,' "$TMP/ai/runs/log.csv"; then fail "old rows leaked into the new file"; fi

echo "log schema ok — $cols columns, both writers agree, migration preserves old rows"
