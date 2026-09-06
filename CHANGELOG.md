# Changelog

## 0.4.0 — 2026-09-06
- New `tester` agent and `/ai-test` task: writes acceptance tests from the spec's ACs,
  reading the implementation's public surface only and never the diff, so tests are not
  shaped by the code they check. Modes `red` (before `/ai-step`, ACs must fail first) and
  `gaps` (after, close uncovered ACs). Writes test files only; never production code.
- Loop is now `/ai-explore → /ai-spec → /ai-plan → /ai-test red → /ai-step → /ai-test gaps → /ai-check`.
- `sync-adapters.sh`: `shopt -s nullglob` — a repo with no `ai/skills/*/` subdirectory
  previously created a directory literally named `.claude/skills/*`. Agent symlinks now
  loop over `ai/agents/*.md` instead of hardcoding the reviewer, so a new agent needs no
  script change. **Adopted repos should run `/sdlc:sync`.**
- Definition-of-done item 2 now names `/ai-test` as the source of AC tests.
- ai-sdlc adopts its own `ai/` layout, symlinked to `skills/ai-layout/templates/`.

## 0.3.0 — 2026-09-06
- Plugin renamed `sdlc` (repo stays ai-sdlc). Commands: `/sdlc:adopt` (was init), `/sdlc:explore` (was investigate), `/sdlc:sync`.
- Project commands now prefixed `ai-`: `/ai-explore /ai-spec /ai-plan /ai-step /ai-fix /ai-chore /ai-check` (tasks renamed explore, step, fix, check; `/review` collided with a Claude Code built-in). `ai/investigations/` → `ai/explorations/`.

## 0.2.0 — 2026-09-06
- Renamed from ai-base and split: Next.js pieces moved to the nextjs-scaffold plugin; NestJS lives in nestjs-scaffold.
- New `/ai-explore` command + task: 2–4 implementation options with trade-offs before a spec; output in `ai/explorations/`.
- New `/sdlc:adopt` command: add the ai/ layout to an existing repo without a framework scaffold.
- `/ai-sync` renamed `/sdlc:sync`; guards against repos without `ai/`.
- Generic templates are framework-neutral with `{{…_extra}}` slots overlays fill.

## 0.1.2 / 0.1.1 / 0.1.0 — 2026-09-05 (as ai-base)
- Initial layout, hooks, reviewer; skills hidden from the slash menu; sync guard.
