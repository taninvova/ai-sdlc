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
cmds=$(ls .claude/commands/t4/*.md 2>/dev/null | wc -l | tr -d ' ')
skills=$(ls -d .codex/skills/t4-*/ 2>/dev/null | wc -l | tr -d ' ')
[ "$tasks" = "$cmds" ]   || fail "$tasks tasks but $cmds claude commands"
[ "$tasks" = "$skills" ] || fail "$tasks tasks but $skills codex skills"

for t in ai/tasks/*.md; do
  n=$(basename "$t" .md); s=".codex/skills/t4-$n/SKILL.md"
  [ -f "$s" ] || fail "missing $s"
  grep -q "^name: t4-$n$" "$s" || fail "$s has the wrong name in its frontmatter"
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

for t in ai/tasks/*.md; do
  n=$(basename "$t" .md); c=".claude/commands/t4/$n.md"
  [ -f "$c" ] || fail "missing $c"
  inc=$(sed -n 's/^@//p' "$c" | head -1)
  [ -n "$inc" ] || fail "$c has no @include"
  target=$(cd "$(dirname "$c")" && cd "$(dirname "$inc")" 2>/dev/null && pwd)/$(basename "$inc")
  [ -f "$target" ] || fail "$c includes $inc, which does not resolve to a file"
  [ "$target" = "$PWD/$t" ] || fail "$c resolves to $target, expected $PWD/$t"
done

# A task's argument-hint must reach the generated command, or the menu advertises no input
# and the user discovers the requirement only by running it. A task without a hint must not
# gain an empty one.
for t in ai/tasks/*.md; do
  n=$(basename "$t" .md); c=".claude/commands/t4/$n.md"
  h=$(sed -n 's/^argument-hint: *//p' "$t" | head -1)
  g=$(sed -n 's/^argument-hint: *//p' "$c" | head -1)
  [ "$h" = "$g" ] || fail "$n: task hint '$h' but command hint '$g'"
done

# A task that takes input must say what to do when it gets none, or an empty invocation
# leaves a dangling label and the task guesses. Hint present => prompt present.
for t in ai/tasks/*.md; do
  n=$(basename "$t" .md)
  h=$(sed -n 's/^argument-hint: *//p' "$t" | head -1)
  case "$h" in
    "" ) continue ;;                       # takes no input
    \[*\] ) continue ;;                     # optional input, marked by brackets
  esac
  grep -q "If nothing follows the command name" "$t" \
    || fail "$n requires input ($h) but never says what to do when it gets none"
done

# A repo adopted under an older naming keeps its old command files unless sync removes them,
# and then answers both /spec and /t4:spec. Reproduce that: a pre-0.5.0 bare command, a
# 0.5.0-era ai- command, a stale codex skill — and a hand-written command that must survive,
# because the only thing separating it from ours is the include, not the name.
printf -- '---\ndescription: stale\n---\n@../../ai/tasks/spec.md\n' > .claude/commands/spec.md
printf -- '---\ndescription: stale\n---\n@../../ai/tasks/plan.md\n' > .claude/commands/ai-plan.md
mkdir -p .codex/skills/ai-spec && printf -- '---\nname: ai-spec\n---\nRead `ai/tasks/spec.md`\n' > .codex/skills/ai-spec/SKILL.md
printf -- '---\ndescription: mine\n---\nMy own prompt, nothing to do with ai/tasks.\n' > .claude/commands/spec-of-mine.md
bash ai/make/sync-adapters.sh > /dev/null
[ ! -f .claude/commands/spec.md ]        || fail "sync left the pre-0.5.0 bare command in place"
[ ! -f .claude/commands/ai-plan.md ]     || fail "sync left the 0.5.0-era ai- command in place"
[ ! -d .codex/skills/ai-spec ]           || fail "sync left a stale codex skill in place"
[ -f .claude/commands/spec-of-mine.md ]  || fail "sync deleted a hand-written command"
rm -f .claude/commands/spec-of-mine.md

# The codex skill must not copy the prompt text — that would fork from ai/tasks/.
body=$(sed -n '/^---$/,/^---$/!p' .codex/skills/t4-spec/SKILL.md | wc -l | tr -d ' ')
[ "$body" -lt 15 ] || fail "codex skills look like copies of the task, not pointers ($body lines)"

echo "adapters ok — $tasks tasks → claude commands + codex skills, idempotent, agent notes correct"
