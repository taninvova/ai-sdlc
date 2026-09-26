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
TRANSCRIPT=$PWD/skills/ai-hooks/fixtures/transcript.jsonl
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

echo "detect ok — ai-factory/ preferred, ai/ still guarded and logged, neither is a silent no-op"
