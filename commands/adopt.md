---
description: Add the ai/ layout (AGENTS.md, docs, tasks, reviewer, tester and architect agents, hooks log, adapters) to an existing repo without a framework scaffold
argument-hint: [--owner <name>]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---
Add the generic ai-sdlc layout to the current repo. Use the `ai-layout` and `ai-hooks`
skills. Do NOT scaffold an application — that is an overlay plugin's job; an overlay calls
this same layout and fills the `{{…_extra}}` slots with its own rules, docs and skills.

1. If `ai/` already exists, stop and suggest /sdlc:sync instead.
2. Detect the stack from the repo (package.json, go.mod, pyproject, etc.) and the
   commands that build, lint, typecheck and test it. Fill `{{stack}}` and `{{commands}}`.
3. Copy `${CLAUDE_PLUGIN_ROOT}/skills/ai-layout/templates/` to the repo root; substitute
   `{{app}}` (repo dir name), `{{stack}}`, `{{commands}}`, `{{owner}}` (git user.name or
   --owner), `{{backup}}` = TBD, `{{date}}`, `{{plugin_version}}`; remove every remaining
   `{{…_extra}}` / `{{overlay_note}}` placeholder line.
4. Write root `AGENTS.md` ("See ai/AGENTS.md") and `CLAUDE.md` ("@ai/AGENTS.md") if absent.
5. Append the gitignore lines from the ai-hooks skill. Create `ai/runs/log.csv` header.
6. Run `bash ai/make/sync-adapters.sh`.
7. Report the files created and ask the developer to fill the prose in
   ai/docs/architecture.md before the first /spec.
