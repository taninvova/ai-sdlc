# 0000 — Scaffold

Summary: the project starts with the AI SDLC layout from ai-base {{plugin_version}}.

## Acceptance criteria
- AC1 Given a fresh clone, When a developer runs the check command from ai/AGENTS.md, Then lint, typecheck and tests pass.
- AC2 Given a fresh Claude Code session, When the developer runs `/chore add a /healthz route`, Then the session reads ai/AGENTS.md, runs lint and tests, and produces a reviewable diff.
- AC3 Given any session, When the model attempts to edit a path in ai/docs/dont-touch.md, Then the edit is blocked.
- AC4 Given a completed session, When it ends, Then one line is appended to ai/runs/log.csv.

## Out of scope
Features. This spec covers only the delivery machinery.
