---
name: t4-analyse
description: Turn a feature description into a business-analysis pack — objectives, scope, actors and permissions, use cases, requirements, rules, data, stories with acceptance criteria, test scenarios — facts, assumptions and open questions kept apart; before any spec
---
Read `ai-factory/tasks/analyse.md` in this repo and follow it exactly. Everything the user typed after the
command name is that task's input (its `$ARGUMENTS`).

That task delegates to the `analyst` subagent. Codex plugins cannot ship subagents, so read
`ai-factory/agents/analyst.md` and follow it yourself, in this session, producing exactly the output
it specifies.

Weigh its findings knowing what this costs: under Claude Code that agent runs in its own
context, which is the whole point of it. A tester that has seen the implementation writes
tests that restate it, and a reviewer that wrote the code is not an independent review;
a step agent that shares the session sees the chat it was meant to start without.
Here one session does both.
