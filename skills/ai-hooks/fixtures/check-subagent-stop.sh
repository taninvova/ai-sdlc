#!/usr/bin/env bash
# Pins scripts/subagent-stop.js — the row written when a subagent concludes.
#
# What this has to prove that no other fixture can. The hook is the only writer of a `source=agent`
# row, and the only place the `agent` column is ever non-empty, so the whole of per-agent
# attribution rests here. Three of its behaviours are silent when they break:
#   the parent transcript must never be opened — a payload whose `transcript_path` points nowhere
#     is the normal case for a background agent, and reading it "just for the model" would drop the
#     row entirely rather than fail loudly;
#   a resumed agent fires the event twice, and a second row would double that agent's tokens;
#   context inheritance re-logs a prefix of a parent agent's records into each fork child, so the
#   two rows must sum to the UNION of the two transcripts, not to their concatenation.
#
# Every sum below is computed here, by an inline node, over the transcript files — never by calling
# the module the hook itself uses. The test measures the writer instead of agreeing with it.
#
# The payloads are the shipped subagent-stop.json with fields overridden, so a field renamed
# upstream and re-captured into that file surfaces as a failure here rather than as a fixture
# nobody reads.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/../../.."   # repo root
HOOK=$PWD/skills/ai-hooks/scripts/subagent-stop.js
STOP=$PWD/skills/ai-hooks/scripts/session-stop.js
JSON=$PWD/skills/ai-hooks/fixtures/subagent-stop.json
PARENT=$PWD/skills/ai-hooks/fixtures/agent-transcript.jsonl
CHILD=$PWD/skills/ai-hooks/fixtures/agent-child-transcript.jsonl
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
eq() { [ "$2" = "$3" ] || fail "$1: got '$2', want '$3'"; }

# payload <k=v>… — the captured payload with fields set; `-k` drops one. "true"/"false" go through
# as booleans so stop_hook_active can be set for real.
payload() {
  node -e '
    const fs = require("fs");
    const ev = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    for (const a of process.argv.slice(2)) {
      if (a.startsWith("-")) { delete ev[a.slice(1)]; continue; }
      const i = a.indexOf("="); const k = a.slice(0, i); const v = a.slice(i + 1);
      ev[k] = v === "true" ? true : v === "false" ? false : v;
    }
    process.stdout.write(JSON.stringify(ev));' "$JSON" "$@"
}

# run <payload> — the hook must exit 0 and print nothing, whatever it decides to write.
run() {
  local rc
  printf '%s' "$1" | node "$HOOK" >"$TMP/o" 2>"$TMP/e" && rc=0 || rc=$?
  [ "$rc" = 0 ] || fail "the hook exited $rc: $(cat "$TMP/e")"
  [ -s "$TMP/o" ] && fail "the hook wrote to stdout: $(cat "$TMP/o")"
  [ -s "$TMP/e" ] && fail "the hook wrote to stderr: $(cat "$TMP/e")"
  return 0
}

# union <transcript>… — "turns inp out cr cw" over the given transcripts with each message `uuid`
# counted once. Independent of _usage.js on purpose.
union() {
  node -e '
    const fs = require("fs"); const t = [0, 0, 0, 0, 0]; const seen = new Set();
    for (const f of process.argv.slice(1)) {
      for (const l of fs.readFileSync(f, "utf8").split("\n")) {
        if (!l.trim()) continue;
        let r; try { r = JSON.parse(l); } catch { continue; }
        const u = r.message?.usage; if (!u) continue;
        if (r.uuid) { if (seen.has(r.uuid)) continue; seen.add(r.uuid); }
        t[0]++; t[1] += u.input_tokens; t[2] += u.output_tokens;
        t[3] += u.cache_read_input_tokens; t[4] += u.cache_creation_input_tokens;
      }
    }
    process.stdout.write(t.join(" "));' "$@"
}
# usd <inp> <out> <cr> <cw> <r_in> <r_out> <r_read> <r_write>
usd() { node -e 'const a = process.argv.slice(1).map(Number);
  process.stdout.write(((a[0]*a[4] + a[1]*a[5] + a[2]*a[6] + a[3]*a[7]) / 1e6).toFixed(4));' "$@"; }
# rate <inp> <cr> <cw> — the hit_rate the row should carry.
rate() { node -e 'const a = process.argv.slice(1).map(Number);
  process.stdout.write((a[1] / (a[0] + a[1] + a[2] || 1)).toFixed(2));' "$@"; }

# repo <name> [priced] — a scratch repo carrying the layout; with "priced", a models.yaml whose
# `default` is deliberately WRONG, so an exact-id hit is the only way to the right cost.
repo() {
  local root=$TMP/$1; mkdir -p "$root/ai-factory/runs"
  if [ "${2:-}" = priced ]; then
    cat > "$root/ai-factory/models.yaml" <<'YAML'
pricing:
  default: { input: 99, output: 99, cache_read: 99, cache_write: 99 }
  claude-sonnet-4-5: { input: 3, output: 15, cache_read: 0.3, cache_write: 3.75 }
YAML
  fi
  echo "$root"
}
row() { awk -F, -v n="$2" 'NR==n' "$1/ai-factory/runs/log.pending.csv"; }
f() { awk -F, -v n="$2" -v c="$3" 'NR==n{print $c}' "$1/ai-factory/runs/log.pending.csv"; }
toks() { awk -F, -v n="$2" 'NR==n{print $10, $11, $12, $13, $14}' "$1/ai-factory/runs/log.pending.csv"; }
rows() { [ -f "$1/ai-factory/runs/log.pending.csv" ] && echo $(( $(wc -l < "$1/ai-factory/runs/log.pending.csv") - 1 )) || echo 0; }

PSUM=$(union "$PARENT")   # 3 turns over the parent agent's own transcript

# --- 0. the captured payload carries the fields the hook reads --------------------------------
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$JSON" \
  || fail "$JSON is not valid JSON"
for k in session_id agent_id agent_type agent_transcript_path hook_event_name; do
  node -e 'const ev = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    if (ev[process.argv[2]] === undefined) process.exit(1);' "$JSON" "$k" \
    || fail "$JSON has no \"$k\" — the captured payload no longer carries a field the hook reads"
done
eq "the captured payload's event" \
  "$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).hook_event_name)' "$JSON")" \
  "SubagentStop"

# --- 1. exactly one row, with the right source, agent, tool, model and tokens (AC2, AC3) ------
R=$(repo priced priced)
run "$(payload "cwd=$R" "agent_transcript_path=$PARENT" session_id=s1 agent_id=a1 agent_type=implementer)"
P=$R/ai-factory/runs/log.pending.csv
[ -f "$P" ] || fail "no row written to log.pending.csv"
[ ! -e "$R/ai-factory/runs/log.csv" ] || fail "the hook wrote log.csv directly; it must buffer in log.pending.csv"
eq "one row per concluded agent" "$(rows "$R")" "1"
eq "source"      "$(f "$R" 2 3)" "agent"
eq "session_id"  "$(f "$R" 2 2)" "s1"
eq "task is empty with no task file" "$(f "$R" 2 6)" ""
eq "tool stays claude alone, unsplit" "$(f "$R" 2 7)" "claude"
eq "agent is the payload's agent_type verbatim" "$(f "$R" 2 8)" "implementer"
eq "model is the one that transcript names" "$(f "$R" 2 9)" "claude-sonnet-4-5"
eq "accepted stays empty" "$(f "$R" 2 17)" ""
eq "the tokens are that transcript's, summed here" "$(toks "$R" 2)" "$PSUM"
eq "the row is as wide as the header" "$(awk -F, 'NR==2{print NF}' "$P")" "$(awk -F, 'NR==1{print NF}' "$P")"
eq "hit_rate" "$(f "$R" 2 15)" "$(rate 1900 15000 150)"
# AC4, priced half: the exact model id wins over a default that would cost 99/99/99/99, and the
# cost carries no "~".
eq "cost_usd is priced by the exact model id" "$(f "$R" 2 16)" "$(usd 1900 400 15000 150 3 15 0.3 3.75)"

# --- 2. no models.yaml: the built-in figures, and the "~" that marks the number an estimate ----
R=$(repo unpriced)
run "$(payload "cwd=$R" "agent_transcript_path=$PARENT" session_id=s2 agent_id=a2)"
eq "cost_usd is marked approximate" "$(f "$R" 2 16)" "~$(usd 1900 400 15000 150 3 15 0.3 3.75)"

# --- 3. user and branch are derived exactly as session-stop.js derives them (AC2) --------------
# Asserted by comparison rather than by value: the two hooks must agree, whatever `git config` in
# the scratch directory happens to say.
R=$(repo derived)
printf '{"session_id":"cmp-session","cwd":"%s","transcript_path":"%s","hook_event_name":"Stop"}' "$R" "$PARENT" \
  | node "$STOP" >"$TMP/o" 2>"$TMP/e" || fail "the Stop hook exited non-zero: $(cat "$TMP/e")"
run "$(payload "cwd=$R" "agent_transcript_path=$PARENT" session_id=cmp-agent agent_id=a3)"
eq "the session row and the agent row are the two rows" "$(rows "$R")" "2"
eq "user"   "$(f "$R" 3 4)" "$(f "$R" 2 4)"
eq "branch" "$(f "$R" 3 5)" "$(f "$R" 2 5)"

# --- 4. an absent parent transcript costs the row nothing (AC5) --------------------------------
# Two identical repos, identical payloads but for the parent `transcript_path`: one readable, one
# pointing nowhere. Every field but the timestamp must match, which is stronger than checking that
# a row exists — a field quietly taken from the parent transcript would differ.
A=$(repo parent-ok);   run "$(payload "cwd=$A" "agent_transcript_path=$PARENT" "transcript_path=$PARENT" session_id=s4 agent_id=a4)"
B=$(repo parent-gone); run "$(payload "cwd=$B" "agent_transcript_path=$PARENT" "transcript_path=$TMP/no-such-transcript.jsonl" session_id=s4 agent_id=a4)"
eq "a payload with an unreadable parent transcript still writes a row" "$(rows "$B")" "1"
eq "the row does not depend on the parent transcript" \
  "$(row "$B" 2 | cut -d, -f2-)" "$(row "$A" 2 | cut -d, -f2-)"
C=$(repo parent-absent); run "$(payload "cwd=$C" "agent_transcript_path=$PARENT" -transcript_path session_id=s4 agent_id=a4)"
eq "so does a payload carrying no parent transcript at all" \
  "$(row "$C" 2 | cut -d, -f2-)" "$(row "$A" 2 | cut -d, -f2-)"

# --- 5. a resumed agent: the second event writes no second row (AC6) ---------------------------
R=$(repo resumed)
run "$(payload "cwd=$R" "agent_transcript_path=$PARENT" session_id=s5 agent_id=a5)"
eq "the first event writes the row" "$(rows "$R")" "1"
grep -qxF 'a:a5' "$R/ai-factory/runs/.counted.s5" || fail "the agent id was not claimed, so a resumed agent would be counted twice"
run "$(payload "cwd=$R" "agent_transcript_path=$PARENT" session_id=s5 agent_id=a5 stop_hook_active=true)"
eq "a resumed agent adds no second row" "$(rows "$R")" "1"
eq "and its tokens are still counted once" "$(toks "$R" 2)" "$PSUM"

# --- 6. the four cases that write nothing, all silent and all exit 0 (AC7) ---------------------
printf 'not json at all\n{oops\n' > "$TMP/garbage.jsonl"
printf '{"type":"user","uuid":"n-1","message":{"role":"user","content":"no usage anywhere"}}\n' > "$TMP/nousage.jsonl"
i=0
for case in "-agent_transcript_path" "agent_transcript_path=$TMP/absent.jsonl" \
            "agent_transcript_path=$TMP/garbage.jsonl" "agent_transcript_path=$TMP/nousage.jsonl"; do
  i=$((i + 1)); R=$(repo "norow-$i")
  run "$(payload "cwd=$R" "$case" session_id=s6 agent_id="a6-$i")"
  if [ -e "$R/ai-factory/runs/log.pending.csv" ]; then fail "no-row case $i ($case) wrote a row"; fi
  if [ -e "$R/ai-factory/runs/log.csv" ]; then fail "no-row case $i ($case) wrote log.csv"; fi
done

# --- 7. the inherited prefix is counted once (AC16) --------------------------------------------
# The child re-logs two of the parent's records verbatim — same UUIDs, same tokens. Parent first,
# then the child: the child's row must carry only its own work, and the two rows must sum to the
# union of the two files. Both assertions fail if the shared ledger is bypassed, because the child
# would then re-report the inherited pair.
R=$(repo inherited priced)
run "$(payload "cwd=$R" "agent_transcript_path=$PARENT" session_id=s7 agent_id=parent agent_type=implementer)"
run "$(payload "cwd=$R" "agent_transcript_path=$CHILD"  session_id=s7 agent_id=child  agent_type=explorer)"
eq "one row per agent" "$(rows "$R")" "2"
eq "the parent's row is its own transcript" "$(toks "$R" 2)" "$PSUM"
eq "the parent kept its name"  "$(f "$R" 2 8)" "implementer"
eq "the child kept its name"   "$(f "$R" 3 8)" "explorer"
eq "the child's model is its own, not the inherited one" "$(f "$R" 3 9)" "claude-haiku-4-5"
# The child's own work only: 2 records, not the 4 its file holds.
eq "the child's row excludes the inherited prefix" "$(toks "$R" 3)" "2 120 30 300 5"
summed=$(awk -F, 'NR>1{for (i = 10; i <= 14; i++) s[i] += $i} END{print s[10], s[11], s[12], s[13], s[14]}' \
  "$R/ai-factory/runs/log.pending.csv")
eq "the two rows sum to the union of the two transcripts" "$summed" "$(union "$PARENT" "$CHILD")"
eq "a shared uuid is claimed once" "$(grep -c '^u:ag-0003$' "$R/ai-factory/runs/.counted.s7")" "1"

echo "subagent-stop ok — one row per concluded agent from its own transcript, priced and estimated, the parent transcript is never read, a resumed agent is counted once, four cases write nothing silently, and an inherited prefix is counted once"
