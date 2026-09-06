---
description: Investigate a feature request against this codebase and present 2–4 implementation options with trade-offs and a recommendation
argument-hint: <feature request in one sentence>
allowed-tools: Read, Grep, Glob, Bash, Write
---
Run the `investigate` task: if `ai/tasks/investigate.md` exists in this repo use it;
otherwise use `${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/templates/ai/tasks/investigate.md`
(and tell the developer to run /sync so the repo gets its own copy).
Do not change any code. Output goes to `ai/investigations/<NNNN>-<slug>.md`
(create the directory if missing). End with the recommended option in one sentence
and the exact `/spec …` line to run next.

Feature request: $ARGUMENTS
