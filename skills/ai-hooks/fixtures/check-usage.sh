#!/usr/bin/env bash
# Pins scripts/_usage.js — the transcript sum, the claim ledger and the price resolution that the
# two row writers share.
#
# Why it gets a fixture of its own. The module is reached only through a hook, and the half of it
# that matters most is invisible from either hook until the rows they write change meaning: the
# `uuid` de-duplication is what stops a record copied into a subagent transcript being counted
# twice, and a bug in it reads as "the numbers look a bit high" rather than as a failure. Pricing
# is asserted here for the same reason — it moved out of the Stop hook unchanged, and "unchanged"
# is a claim, not a fact, until the four resolution paths are exercised.
#
# Everything is built in a scratch directory: no fixture file is shipped for it, because the
# transcripts each case needs differ by one field.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."   # repo root
U=$PWD/skills/ai-hooks/scripts/_usage.js
STOP=$PWD/skills/ai-hooks/scripts/session-stop.js
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# run <js> — evaluates <js> with `U` bound to the module. Whatever it prints comes back.
run() { node -e "const U = require('$U'); $1"; }
# eq <what> <got> <want>
eq() { [ "$2" = "$3" ] || fail "$1: got '$2', want '$3'"; }

# --- 1. price(): exact id, then the LONGEST id it starts with, then default, then no file ------
AI=$TMP/priced; mkdir -p "$AI"
cat > "$AI/models.yaml" <<'YAML'
pricing:
  default: { input: 3, output: 15, cache_read: 0.3, cache_write: 3.75 }
  gw-fast: { input: 1, output: 5, cache_read: 0.1, cache_write: 1.25 }
  gw-fast-v2: { input: 2, output: 6, cache_read: 0.2, cache_write: 2.5 }
# gw-commented: { input: 99, output: 99, cache_read: 99, cache_write: 99 }
YAML
p() { run "const p = U.price('$AI', $1); console.log(p.rate.input + '|' + p.approx);"; }
eq "exact id wins"              "$(p "'gw-fast-v2'")"      "2|"
eq "the longest prefix wins"    "$(p "'gw-fast-v2-2026'")" "2|"
eq "a shorter prefix still hits" "$(p "'gw-fast-9'")"      "1|"
eq "unlisted model falls to default" "$(p "'no-such-model'")" "3|"
eq "a commented block is not a price" "$(p "'gw-commented'")" "3|"
# No models.yaml at all: the built-in figures, and the "~" that marks the cost an estimate.
eq "no models.yaml estimates" "$(run "const p = U.price('$TMP/absent', 'x'); console.log(p.rate.input + '|' + p.approx);")" "3|~"
eq "an absent model id does not throw" "$(run "const p = U.price('$AI', undefined); console.log(p.rate.input + '|' + p.approx);")" "3|"

# --- 2. claims(): created on the first claim, never rewritten, visible to the next process -----
AI=$TMP/repo/ai-factory; mkdir -p "$AI/runs"
LEDGER=$AI/runs/.counted.s1
run "U.claims('$AI', 's1').has('u:A');"
[ ! -e "$LEDGER" ] || fail "the ledger was created by a read; it must appear only once there is something to claim"
eq "a first claim is taken"   "$(run "console.log(U.claims('$AI', 's1').add('u:A'));")" "true"
[ -f "$LEDGER" ] || fail "the first claim did not create $LEDGER"
eq "the ledger holds the claim" "$(cat "$LEDGER")" "u:A"
eq "a claim from a later process is seen" "$(run "console.log(U.claims('$AI', 's1').has('u:A'));")" "true"
eq "re-claiming reports false"  "$(run "console.log(U.claims('$AI', 's1').add('u:A'));")" "false"
eq "re-claiming appends nothing" "$(wc -l < "$LEDGER" | tr -d ' ')" "1"
eq "a different session has its own ledger" "$(run "console.log(U.claims('$AI', 's2').has('u:A'));")" "false"

# --- 3. sumTranscript(): the sum, and the uuid rule ---------------------------------------------
rec() { printf '{"uuid":"%s","type":"assistant","message":{"model":"%s","usage":{"input_tokens":%s,"output_tokens":%s,"cache_read_input_tokens":%s,"cache_creation_input_tokens":%s}}}\n' "$@"; }
{ rec A m-one 100 10 1000 5
  echo '{"uuid":"X","type":"user","message":{"content":"no usage here"}}'
  echo 'not json at all'
  rec B m-one 200 20 2000 0
  rec C m-two 300 30 3000 0
} > "$TMP/parent.jsonl"
sum() { run "const t = U.sumTranscript('$1'$2); console.log([t.turns,t.inp,t.out,t.cr,t.cw,t.model].join('|'));"; }

# No ledger: every usage record counts, non-usage and unparseable lines are skipped, and the
# model is the last one the transcript names.
eq "plain sum" "$(sum "$TMP/parent.jsonl" "")" "3|600|60|6000|5|m-two"
eq "a missing transcript sums to nothing" "$(sum "$TMP/absent.jsonl" "")" "0|0|0|0|0|"

# With a ledger the first pass counts everything and claims each uuid; the second counts nothing.
LED="$AI/runs/.counted.s3"
eq "first pass over a transcript"  "$(sum "$TMP/parent.jsonl" ", U.claims('$AI', 's3')")" "3|600|60|6000|5|m-two"
eq "every uuid was claimed" "$(sort "$LED" | tr '\n' ' ')" "u:A u:B u:C "
eq "second pass counts nothing"    "$(sum "$TMP/parent.jsonl" ", U.claims('$AI', 's3')")" "0|0|0|0|0|"

# A child re-logging an inherited prefix: only what is new to the session is counted, and the two
# sums add up to the union of the two transcripts rather than to their concatenation.
{ rec B m-one 200 20 2000 0
  rec C m-two 300 30 3000 0
  rec D m-two 400 40 4000 0
} > "$TMP/child.jsonl"
eq "the inherited prefix is counted once" "$(sum "$TMP/child.jsonl" ", U.claims('$AI', 's3')")" "1|400|40|4000|0|m-two"

# A transcript with no uuid cannot be de-duplicated, so it is counted every time and claims
# nothing — the deliberate over-count, rather than silently dropping the tokens.
{ echo '{"type":"assistant","message":{"model":"m-one","usage":{"input_tokens":7,"output_tokens":1,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
  echo '{"type":"assistant","message":{"model":"m-one","usage":{"input_tokens":3,"output_tokens":1,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
} > "$TMP/nouuid.jsonl"
eq "no uuid, first pass"  "$(sum "$TMP/nouuid.jsonl" ", U.claims('$AI', 's4')")" "2|10|2|0|0|m-one"
eq "no uuid, second pass" "$(sum "$TMP/nouuid.jsonl" ", U.claims('$AI', 's4')")" "2|10|2|0|0|m-one"
[ ! -e "$AI/runs/.counted.s4" ] || fail "a transcript with no uuid left a ledger behind; there was nothing to claim"

# --- 4. the Stop hook still writes the snapshot it always has, and records its claims ----------
# This step moves session-stop.js onto the module without changing the row: the claims are taken
# so the agent rows can exclude them, but they are not yet enforced against the session's own sum.
R=$TMP/stopped; mkdir -p "$R/ai-factory"
cp "$TMP/parent.jsonl" "$R/t.jsonl"
stop() {
  printf '{"session_id":"fx-usage","cwd":"%s","transcript_path":"%s/t.jsonl","hook_event_name":"Stop"}' "$R" "$R" \
    | node "$STOP" >"$TMP/o" 2>"$TMP/e" || fail "the Stop hook exited non-zero: $(cat "$TMP/e")"
  [ -s "$TMP/o" ] && fail "the Stop hook wrote to stdout: $(cat "$TMP/o")"
  [ -s "$TMP/e" ] && fail "the Stop hook wrote to stderr: $(cat "$TMP/e")"
  return 0
}
stop; stop
PEND=$R/ai-factory/runs/log.pending.csv
cols() { awk -F, -v n="$1" 'NR==n{print $10"|"$11"|"$12"|"$13"|"$14}' "$PEND"; }
eq "the first row is the whole transcript" "$(cols 2)" "3|600|60|6000|5"
eq "the second row is still the whole transcript" "$(cols 3)" "3|600|60|6000|5"
[ -f "$R/ai-factory/runs/.counted.fx-usage" ] || fail "the Stop hook took no claims"
eq "the ledger holds one line per record" "$(wc -l < "$R/ai-factory/runs/.counted.fx-usage" | tr -d ' ')" "3"

echo "usage ok — price resolves exact/prefix/default/estimate, the ledger is lazy and append-only, a shared uuid is counted once, and the Stop row is unchanged"
