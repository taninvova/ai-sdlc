#!/usr/bin/env bash
# Regenerates tool adapters from ai/. Never edit .claude/ or .cursor/ by hand.
set -euo pipefail
shopt -s nullglob
if ! ls ai/tasks/*.md >/dev/null 2>&1; then
  echo "sync-adapters: no ai/tasks/*.md found — this repo has no ai/ layout; nothing to sync." >&2
  exit 1
fi
mkdir -p .claude/commands .claude/skills .claude/agents .cursor/rules
rm -f .claude/commands/ai-*.md
for t in ai/tasks/*.md; do
  n=$(basename "$t" .md)
  d=$(sed -n 's/^description: *//p' "$t" | head -1)
  printf -- '---\ndescription: %s\n---\n@../../%s\n' "$d" "$t" > ".claude/commands/ai-$n.md"
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
echo "adapters regenerated from ai/"
