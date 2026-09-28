#!/usr/bin/env bash
# Pins which directory the hooks treat as the layout, and that they keep working in a repo that
# has taken the 1.0.0 update without running /t4:migrate-layout yet.
#
# The rename of `ai/` to `ai-factory/` has one failure mode worth a fixture: detection follows the
# new name, an unmigrated repo matches neither, and every hook no-ops. Nothing would appear to be
# wrong — no error, no log row, and no dont-touch guard. So both names are accepted, newest first,
# and this asserts all four cases: new only, old only, both (new wins), neither (no-op).
#
# Preference is proved by content, not by inspection: when both directories exist each carries a
# DIFFERENT rule, so which rule fires says which file was read.
set -euo pipefail
cd "$(dirname "$0")/../../.."   # repo root
GUARD=skills/ai-hooks/scripts/guard-paths.js
STOP=skills/ai-hooks/scripts/session-stop.js
SUB=skills/ai-hooks/scripts/subagent-stop.js
TRANSCRIPT=$PWD/skills/ai-hooks/fixtures/transcript.jsonl
AGENT_TRANSCRIPT=$PWD/skills/ai-hooks/fixtures/agent-transcript.jsonl
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# A repo whose layout directory is $1, carrying one dont-touch rule $2.
mkrepo() {
  local root=$TMP/$3 dir=$1 rule=$2
  mkdir -p "$root/$dir/docs"
  printf '# Do not edit\n\n- `%s`\n' "$rule" > "$root/$dir/docs/dont-touch.md"
  echo "$root"
}

# Run guard-paths.js for a write to $2 in repo $1. Echoes "<exit>|<stdout>|<stderr>".
probe() {
  local root=$1 target=$2 out err rc
  out=$TMP/out.$$; err=$TMP/err.$$
  printf '{"cwd":"%s","tool_input":{"file_path":"%s"}}' "$root" "$target" \
    | node "$PWD/$GUARD" >"$out" 2>"$err" && rc=0 || rc=$?
  printf '%s|%s|%s' "$rc" "$(cat "$out")" "$(cat "$err")"
}

# --- 1. new name only: the guard fires and names ai-factory/ ---
R=$(mkrepo ai-factory "secrets/" new-only)
IFS='|' read -r rc out err <<<"$(probe "$R" "secrets/token.txt")"
[ "$rc" = 2 ] || fail "ai-factory/ only: expected exit 2, got $rc"
[ -z "$out" ] || fail "ai-factory/ only: wrote to stdout: $out"
case $err in *"Blocked by ai-factory/docs/dont-touch.md"*) ;; *) fail "ai-factory/ only: message does not name ai-factory/: $err";; esac

# --- 2. old name only: an unmigrated repo keeps its guard, and the message names ai/ ---
R=$(mkrepo ai "secrets/" old-only)
IFS='|' read -r rc out err <<<"$(probe "$R" "secrets/token.txt")"
[ "$rc" = 2 ] || fail "ai/ only: expected exit 2, got $rc — an unmigrated repo has lost its guard"
[ -z "$out" ] || fail "ai/ only: wrote to stdout: $out"
case $err in *"Blocked by ai/docs/dont-touch.md"*) ;; *) fail "ai/ only: message does not name ai/: $err";; esac

# --- 3. both: ai-factory/ wins, proved by which rule fires ---
R=$TMP/both; mkdir -p "$R/ai-factory/docs" "$R/ai/docs"
printf -- '- `alpha/`\n' > "$R/ai-factory/docs/dont-touch.md"
printf -- '- `beta/`\n'  > "$R/ai/docs/dont-touch.md"
IFS='|' read -r rc out err <<<"$(probe "$R" "alpha/x.txt")"
[ "$rc" = 2 ] || fail "both: ai-factory/'s rule did not fire (exit $rc) — the old directory won"
IFS='|' read -r rc out err <<<"$(probe "$R" "beta/x.txt")"
[ "$rc" = 0 ] || fail "both: ai/'s rule fired (exit $rc) — the old directory was read as well"

# --- 4. neither: no-op, silent, exit 0 ---
R=$TMP/neither; mkdir -p "$R"
IFS='|' read -r rc out err <<<"$(probe "$R" "secrets/token.txt")"
[ "$rc" = 0 ] || fail "no layout: expected exit 0, got $rc"
[ -z "$out$err" ] || fail "no layout: hook was not silent: $out$err"

# --- 5. the Stop hook logs under whichever name the repo carries ---
for dir in ai-factory ai; do
  R=$TMP/stop-$dir; mkdir -p "$R/$dir"
  printf '{"session_id":"fixture-detect","cwd":"%s","transcript_path":"%s","hook_event_name":"Stop"}' \
    "$R" "$TRANSCRIPT" | node "$PWD/$STOP" >"$TMP/o" 2>"$TMP/e" || fail "$dir: Stop hook exited non-zero: $(cat "$TMP/e")"
  [ -s "$TMP/o" ] && fail "$dir: Stop hook wrote to stdout: $(cat "$TMP/o")"
  [ -f "$R/$dir/runs/log.pending.csv" ] || fail "$dir: no row written to $dir/runs/log.pending.csv"
  rows=$(( $(wc -l < "$R/$dir/runs/log.pending.csv") - 1 ))
  [ "$rows" -ge 1 ] || fail "$dir: log.pending.csv has a header but no row"
done

# --- 6. the SubagentStop hook, across the same four cases ---
# The agent rows are the only place the `agent` column is ever filled, so an unmigrated repo that
# stopped writing them would lose per-agent attribution with nothing to show for it.
subagent() {   # subagent <repo> <agent_id>
  printf '{"session_id":"fixture-detect-sub","cwd":"%s","agent_id":"%s","agent_type":"implementer","agent_transcript_path":"%s","hook_event_name":"SubagentStop"}' \
    "$1" "$2" "$AGENT_TRANSCRIPT" | node "$PWD/$SUB" >"$TMP/o" 2>"$TMP/e" \
    || fail "SubagentStop hook exited non-zero in $1: $(cat "$TMP/e")"
  [ -s "$TMP/o" ] && fail "SubagentStop hook wrote to stdout: $(cat "$TMP/o")"
  [ -s "$TMP/e" ] && fail "SubagentStop hook wrote to stderr: $(cat "$TMP/e")"
  return 0
}
for dir in ai-factory ai; do
  R=$TMP/sub-$dir; mkdir -p "$R/$dir"
  subagent "$R" "agent-$dir"
  PEND=$R/$dir/runs/log.pending.csv
  [ -f "$PEND" ] || fail "$dir: no agent row written to $dir/runs/log.pending.csv"
  grep -q ',agent,' "$PEND" || fail "$dir: the row is not marked source=agent"
  [ "$(awk -F, 'NR==2{print $8}' "$PEND")" = implementer ] \
    || fail "$dir: the row lost the agent name: $(awk -F, 'NR==2{print $8}' "$PEND")"
done
# both: the row goes under ai-factory/ only, the same preference the guard shows
R=$TMP/sub-both; mkdir -p "$R/ai-factory" "$R/ai"
subagent "$R" agent-both
[ -f "$R/ai-factory/runs/log.pending.csv" ] || fail "both: no row under ai-factory/"
if [ -e "$R/ai/runs" ]; then fail "both: the old directory was written as well"; fi
# neither: no row, no directory, no output
R=$TMP/sub-neither; mkdir -p "$R"
subagent "$R" agent-none
[ -z "$(ls -A "$R")" ] || fail "no layout: the SubagentStop hook created $(ls -A "$R")"

echo "detect ok — ai-factory/ preferred, ai/ still guarded and logged for both Stop and SubagentStop, neither is a silent no-op"
