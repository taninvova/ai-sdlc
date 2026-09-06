# Changelog

## 0.5.0 — 2026-09-06
- New `architect` agent: decides where a capability belongs across services, what contract
  it exposes and who owns the data. Writes design docs and ADRs only — never source, specs
  or plans; changes to other context docs are proposed as replacement text, not applied.
- New `/ai-design`: the capability's home, its contracts and its data ownership, before any
  spec. Output in `ai/designs/`, ending with the `/ai-adr` and `/ai-spec` lines to run.
  `/ai-design review <plan>` checks a plan for architectural fit and emits the same JSON
  shape the reviewer does, so `ai/make/gate.js` reads it unchanged.
  Use it only when a capability spans services or changes a contract between them —
  `/ai-explore` still decides how to build a feature inside one repo.
- New `/ai-adr`: writes `docs/adr/NNNN-slug.md`. Three documents already required an ADR for
  every new dependency and nothing in the loop produced one; now something does.
- New `ai/docs/fleet.md` — the service map the architect reads — and **`/ai-fleet`, which
  fills it in**: it detects what it can from the repo (remotes, manifests, compose and k8s
  files, routes, queue names, CODEOWNERS) and asks you for the rest, offering what it
  detected as the default. It refreshes rather than overwrites, and asks nothing in a
  non-interactive `make ai` run. The map ships scoped to the project with this repo as its
  only row.
- Definition of done gains item 7: a change crossing a service boundary or changing a
  contract has a design doc, an ADR, and an up-to-date fleet map.
- New overlay slot `{{fleet_extra}}`.
- **Adopted repos: run `/sdlc:sync` for the three new commands, then `/ai-fleet` once** —
  until it runs, `ai/docs/fleet.md` is the unfilled default and `/ai-design` will say so.

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
