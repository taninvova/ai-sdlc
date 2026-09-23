---
name: t4-plan
description: Turn a spec into an ordered implementation plan with checkboxes
---
Read `ai/tasks/plan.md` in this repo and follow it exactly. Everything the user typed after the
command name is that task's input (its `$ARGUMENTS`).

That task delegates to the `planner` subagent. Codex plugins cannot ship subagents, so read
`ai/agents/planner.md` and follow it yourself, in this session, producing exactly the output
it specifies.

Weigh its findings knowing what this costs: under Claude Code that agent runs in its own
context, which is the whole point of it. A tester that has seen the implementation writes
tests that restate it, and a reviewer that wrote the code is not an independent review.
Here one session does both.
