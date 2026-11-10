#!/usr/bin/env bash
# The ponytail hook loads ai-factory/docs/ponytail.md and nothing else.
set -euo pipefail
cd "$(dirname "$0")/../../.."
HOOK=skills/ai-hooks/scripts/ponytail.js
FILE=ai-factory/docs/ponytail.md
TEMPLATE=skills/ai-layout/templates/ai-factory/docs/ponytail.md
fail() { echo "FAIL: $*" >&2; exit 1; }
node --check "$HOOK"
cmp -s "$FILE" "$TEMPLATE" || fail "ponytail.md differs from the template copy"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

run() { # <cwd> [extra json fields]
  local cwd="$1" extra="${2:-}"
  printf '{"cwd":"%s","hook_event_name":"SessionStart"%s}' "$cwd" "$extra" \
    | node "$HOOK" >"$TMP/o" 2>"$TMP/e"
}

# No layout: silent, and it creates nothing.
mkdir -p "$TMP/none"
git init -q "$TMP/none"
run "$TMP/none"
[ ! -s "$TMP/o" ] || fail "no layout wrote to stdout: $(cat "$TMP/o")"
[ ! -s "$TMP/e" ] || fail "no layout wrote to stderr: $(cat "$TMP/e")"
[ "$(ls -A "$TMP/none")" = .git ] || fail "no layout created $(ls -A "$TMP/none")"

# Layout without its own copy still loads the file shipped in the plugin.
mkdir -p "$TMP/bare/ai-factory"
git init -q "$TMP/bare"
run "$TMP/bare"
grep -q "The smallest complete change" "$TMP/o" || fail "the shipped file was not the fallback"

# The workspace copy wins over the shipped file. The license comment stays out of the model context.
mkdir -p "$TMP/repo/ai-factory/docs"
git init -q "$TMP/repo"
cp "$FILE" "$TMP/repo/ai-factory/docs/ponytail.md"
run "$TMP/repo"
grep -q "The smallest complete change" "$TMP/o" || fail "the skill body was not loaded"
printf '\nWORKSPACE COPY WINS\n' >> "$TMP/repo/ai-factory/docs/ponytail.md"
run "$TMP/repo"
grep -q "WORKSPACE COPY WINS" "$TMP/o" || fail "the workspace copy lost to the shipped file"
grep -q "PONYTAIL MODE ACTIVE — level: full" "$TMP/o" || fail "the active line is missing"
grep -q "that check stays" "$TMP/o" || fail "the required-check fence is missing"
grep -q "Permission is hereby granted" "$TMP/o" && fail "the license was injected" || true
[ ! -s "$TMP/e" ] || fail "a load wrote to stderr: $(cat "$TMP/e")"

# Codex and a subagent get the hook JSON, not raw text.
run "$TMP/repo" ',"host":"codex"'
node -e '
const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const text = o.hookSpecificOutput && o.hookSpecificOutput.additionalContext;
if (!text || !text.includes("The smallest complete change")) process.exit(1);
if (o.hookSpecificOutput.hookEventName !== "SessionStart") process.exit(2);
' "$TMP/o" || fail "codex output was not hook JSON"

printf '{"cwd":"%s","hook_event_name":"SubagentStart"}' "$TMP/repo" | node "$HOOK" >"$TMP/o"
node -e '
const o = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
if (o.hookSpecificOutput.hookEventName !== "SubagentStart") process.exit(1);
if (!o.hookSpecificOutput.additionalContext.includes("level: full")) process.exit(2);
' "$TMP/o" || fail "SubagentStart output was not hook JSON"

# The pre-1.0.0 layout name still loads. path-scan-ok
mkdir -p "$TMP/old/ai/docs" # path-scan-ok
git init -q "$TMP/old"
cp "$FILE" "$TMP/old/ai/docs/ponytail.md" # path-scan-ok
run "$TMP/old"
grep -q "The smallest complete change" "$TMP/o" || fail "the old layout was ignored" # path-scan-ok

echo "ponytail ok — the hook loads docs/ponytail.md and stays silent without it"
