#!/usr/bin/env bash
# Regenerates tool adapters from ai/. Never edit .claude/ or .cursor/ by hand.
set -euo pipefail
if ! ls ai/tasks/*.md >/dev/null 2>&1; then
  echo "sync-adapters: no ai/tasks/*.md found — this repo has no ai/ layout; nothing to sync." >&2
  exit 1
fi
mkdir -p .claude/commands .claude/skills .claude/agents .cursor/rules
rm -f .claude/commands/*.md
for t in ai/tasks/*.md; do
  n=$(basename "$t" .md)
  d=$(sed -n 's/^description: *//p' "$t" | head -1)
  printf -- '---\ndescription: %s\n---\n@../../%s\n' "$d" "$t" > ".claude/commands/$n.md"
done
# /feature is the friendlier name for new-feature
[ -f .claude/commands/new-feature.md ] && cp .claude/commands/new-feature.md .claude/commands/feature.md
for s in ai/skills/*/; do
  n=$(basename "$s"); mkdir -p ".claude/skills/$n"
  ln -sfn "../../../ai/skills/$n/SKILL.md" ".claude/skills/$n/SKILL.md"
done
ln -sfn ../../ai/agents/reviewer.md .claude/agents/reviewer.md
cat > .cursor/rules/ai.mdc <<'MDC'
---
description: Project AI instructions
alwaysApply: true
---
Read ai/AGENTS.md first and follow it. Task procedures are in ai/tasks/.
MDC
echo "adapters regenerated from ai/"
