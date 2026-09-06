---
description: Explore a feature request against this codebase — 2–4 implementation approaches with trade-offs and a recommendation, before any spec
argument-hint: <feature request in one sentence>
allowed-tools: Read, Grep, Glob, Bash, Write
---
Run the `explore` task: if `ai/tasks/explore.md` exists in this repo use it;
otherwise use `${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/templates/ai/tasks/explore.md`
(and tell the developer to run /sdlc:sync so the repo gets its own copy).
Do not change any code. Output goes to `ai/explorations/<NNNN>-<slug>.md`
(create the directory if missing). End with the recommended option in one sentence
and the exact `/ai-spec …` line to run next.

Feature request: $ARGUMENTS
