#!/usr/bin/env bash
# Regenerates tool adapters from ai-factory/. Never edit .claude/ or .cursor/ by hand.
set -euo pipefail
shopt -s nullglob
if ! ls ai-factory/tasks/*.md >/dev/null 2>&1; then
  echo "sync-adapters: no ai-factory/tasks/*.md found — this repo has no ai-factory/ layout; nothing to sync." >&2
  exit 1
fi
mkdir -p .claude/commands/t4 .claude/skills .claude/agents .cursor/rules .codex/skills
# Remove the commands this generator produced, in whatever naming it used at the time: bare
# <task>.md before 0.5.0, ai-<task>.md through 0.12.0, t4/<task>.md now. Matching on the
# include rather than on the name is what makes that safe — a hand-written command that
# happens to be called spec.md does not point into the layout's tasks/, so it survives. Name globs
# cannot tell the two apart, which is how a repo ends up answering both /spec and /t4:spec.
# Both directory names are matched, because in a repo migrating from 0.27.1 the adapters this
# generator wrote last time point at the old tasks/ directory, and an unmatched one would be
# left behind as an orphan exactly when the cleanup is needed most. path-scan-ok
for f in .claude/commands/*.md .claude/commands/t4/*.md; do
  [ -f "$f" ] || continue
  grep -qE '^@(\.\./)+(ai-factory|ai)/tasks/[a-z0-9-]+\.md$' "$f" && rm -f "$f"
done
for t in ai-factory/tasks/*.md; do
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
# points at the task file rather than copying it — a copy would fork from ai-factory/tasks/ the first
# time anyone edits one.
# Same for Codex: the skill points at ai-factory/tasks/<name>.md, so that is what identifies it as
# ours regardless of the ai- or t4- prefix it was generated under.
for d in .codex/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  grep -qE '(ai-factory|ai)/tasks/[a-z0-9-]+\.md' "$d/SKILL.md" && rm -rf "$d"
done
for t in ai-factory/tasks/*.md; do
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
      printf '`ai-factory/agents/%s.md` and follow it yourself, in this session, producing exactly the output\n' "$a"
      printf 'it specifies.\n'
      printf '\nWeigh its findings knowing what this costs: under Claude Code that agent runs in its own\n'
      printf 'context, which is the whole point of it. A tester that has seen the implementation writes\n'
      printf 'tests that restate it, and a reviewer that wrote the code is not an independent review;\n'
      printf 'a step agent that shares the session sees the chat it was meant to start without.\n'
      printf 'Here one session does both.\n'
    fi
  } > ".codex/skills/t4-$n/SKILL.md"
done

for s in ai-factory/skills/*/; do
  n=$(basename "$s"); mkdir -p ".claude/skills/$n"
  ln -sfn "../../../ai-factory/skills/$n/SKILL.md" ".claude/skills/$n/SKILL.md"
done
for a in ai-factory/agents/*.md; do
  ln -sfn "../../$a" ".claude/agents/$(basename "$a")"
done
cat > .cursor/rules/ai.mdc <<'MDC'
---
description: Project AI instructions
alwaysApply: true
---
Read ai-factory/AGENTS.md first and follow it. Task procedures are in ai-factory/tasks/.
MDC
echo "adapters regenerated from ai-factory/ (.claude, .cursor, .codex)"
