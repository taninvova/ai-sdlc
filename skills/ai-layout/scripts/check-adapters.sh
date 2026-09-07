#!/usr/bin/env bash
# Asserts sync-adapters.sh generates all three adapter sets from ai/, that Codex skills carry
# the inline-agent note exactly where a task delegates, and that a second run changes nothing.
set -euo pipefail
cd "$(dirname "$0")/../../.."
fail() { echo "FAIL: $*" >&2; exit 1; }

bash ai/make/sync-adapters.sh > /dev/null
before=$(find .claude .cursor .codex -type f -o -type l | sort | xargs shasum | shasum)
bash ai/make/sync-adapters.sh > /dev/null
[ "$before" = "$(find .claude .cursor .codex -type f -o -type l | sort | xargs shasum | shasum)" ] \
  || fail "sync-adapters is not idempotent"

tasks=$(ls ai/tasks/*.md | wc -l | tr -d ' ')
cmds=$(ls .claude/commands/ai-*.md 2>/dev/null | wc -l | tr -d ' ')
skills=$(ls -d .codex/skills/ai-*/ 2>/dev/null | wc -l | tr -d ' ')
[ "$tasks" = "$cmds" ]   || fail "$tasks tasks but $cmds claude commands"
[ "$tasks" = "$skills" ] || fail "$tasks tasks but $skills codex skills"

for t in ai/tasks/*.md; do
  n=$(basename "$t" .md); s=".codex/skills/ai-$n/SKILL.md"
  [ -f "$s" ] || fail "missing $s"
  grep -q "^name: ai-$n$" "$s" || fail "$s has the wrong name in its frontmatter"
  grep -q "ai/tasks/$n.md" "$s" || fail "$s does not point at its task file"
  # A task that delegates must carry the note; one that does not must not.
  if grep -q 'Delegate to the `[a-z]*` subagent' "$t"; then
    a=$(sed -n 's/.*Delegate to the `\([a-z]*\)` subagent.*/\1/p' "$t" | head -1)
    grep -q "cannot ship subagents" "$s" || fail "$s is missing the inline-agent note"
    grep -q "ai/agents/$a.md" "$s"       || fail "$s does not name ai/agents/$a.md"
  else
    grep -q "cannot ship subagents" "$s" && fail "$s has an inline-agent note but $t delegates to nothing"
  fi
done

# The codex skill must not copy the prompt text — that would fork from ai/tasks/.
body=$(sed -n '/^---$/,/^---$/!p' .codex/skills/ai-spec/SKILL.md | wc -l | tr -d ' ')
[ "$body" -lt 15 ] || fail "codex skills look like copies of the task, not pointers ($body lines)"

echo "adapters ok — $tasks tasks → claude commands + codex skills, idempotent, agent notes correct"
