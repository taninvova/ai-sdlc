#!/usr/bin/env bash
# Regenerates tool adapters from ai/. Never edit .claude/ or .cursor/ by hand.
set -euo pipefail
shopt -s nullglob
if ! ls ai/tasks/*.md >/dev/null 2>&1; then
  echo "sync-adapters: no ai/tasks/*.md found — this repo has no ai/ layout; nothing to sync." >&2
  exit 1
fi
mkdir -p .claude/commands/t4 .claude/skills .claude/agents .cursor/rules .codex/skills
rm -f .claude/commands/ai-*.md .claude/commands/t4/*.md
for t in ai/tasks/*.md; do
  n=$(basename "$t" .md)
  d=$(sed -n 's/^description: *//p' "$t" | head -1)
  # argument-hint rides along so the command menu shows what the task expects. A task with no
  # hint takes no input; emitting an empty one would advertise an argument that does not exist.
  h=$(sed -n 's/^argument-hint: *//p' "$t" | head -1)
  {
    printf -- '---\ndescription: %s\n' "$d"
    [ -n "$h" ] && printf -- 'argument-hint: %s\n' "$h"
    printf -- '---\n@../../../%s\n' "$t"
  } > ".claude/commands/t4/$n.md"
done
# Codex reads .codex/skills/<name>/SKILL.md and treats each as a slash command. The skill
# points at the task file rather than copying it — a copy would fork from ai/tasks/ the first
# time anyone edits one.
rm -rf .codex/skills/ai-* .codex/skills/t4-*
for t in ai/tasks/*.md; do
  n=$(basename "$t" .md)
  d=$(sed -n 's/^description: *//p' "$t" | head -1)
  mkdir -p ".codex/skills/t4-$n"
  {
    printf -- '---\nname: t4-%s\ndescription: %s\n---\n' "$n" "$d"
    printf 'Read `%s` in this repo and follow it exactly. Everything the user typed after the\n' "$t"
    printf "command name is that task's input (its \`\$ARGUMENTS\`).\n"
    a=$(sed -n 's/.*Delegate to the `\([a-z]*\)` subagent.*/\1/p' "$t" | head -1)
    if [ -n "$a" ]; then
      printf '\nThat task delegates to the `%s` subagent. Codex plugins cannot ship subagents, so read\n' "$a"
      printf '`ai/agents/%s.md` and follow it yourself, in this session, producing exactly the output\n' "$a"
      printf 'it specifies.\n'
      printf '\nWeigh its findings knowing what this costs: under Claude Code that agent runs in its own\n'
      printf 'context, which is the whole point of it. A tester that has seen the implementation writes\n'
      printf 'tests that restate it, and a reviewer that wrote the code is not an independent review.\n'
      printf 'Here one session does both.\n'
    fi
  } > ".codex/skills/t4-$n/SKILL.md"
done

for s in ai/skills/*/; do
  n=$(basename "$s"); mkdir -p ".claude/skills/$n"
  ln -sfn "../../../ai/skills/$n/SKILL.md" ".claude/skills/$n/SKILL.md"
done
for a in ai/agents/*.md; do
  ln -sfn "../../$a" ".claude/agents/$(basename "$a")"
done
cat > .cursor/rules/ai.mdc <<'MDC'
---
description: Project AI instructions
alwaysApply: true
---
Read ai/AGENTS.md first and follow it. Task procedures are in ai/tasks/.
MDC
echo "adapters regenerated from ai/ (.claude, .cursor, .codex)"
