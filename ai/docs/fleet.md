# Fleet map — ai-sdlc

The services the `architect` agent reads before it decides where a capability belongs.
Scoped to the `nsix/ai/` GitLab group. Nothing here is deployed — these are Claude Code
plugins consumed by developer machines and CI, so "service" means "plugin" and "contract"
means "the templates and prompts another plugin builds on".

Provenance: `(d)` detected from the repos, `(t)` told by the developer, `unverified` neither.
Last refreshed by `/ai-fleet`.

| Service | Repo | Owns | Exposes | Consumes | Owner |
|---|---|---|---|---|---|
| sdlc | `ai/sdlc` (d) — local dir `ai-sdlc` | the `ai/` layout, task prompts, reviewer / tester / architect agents, logging and guard hooks | `skills/ai-layout/templates/` · `agents/*.md` · `hooks/hooks.json` · `/sdlc:adopt` `/sdlc:explore` `/sdlc:sync` (d) | nothing (d) | tanin (d) |
| nextjs | `ai/nextjs-base` (d) | the Next.js App Router scaffold: Biome, Vitest, Playwright+axe, Zod, Prisma, plus a Next.js overlay — design contract, component and e2e tasks, UI-aware reviewer | `/new` (d) | sdlc's templates and the `{{…_extra}}` overlay slots (d) | unverified |
| nestjs | `ai/nestjs-base` (d) | the NestJS service scaffold matching the existing n6 services: health, x-secret auth, RMQ, Biome, Jest+SWC, Husky, Dockerfile, GitLab CI; `ai/docs/service.md` | `/new` · `/nestjs:facts` (d) | sdlc's templates and the `{{…_extra}}` overlay slots (d) | unverified |
| adopted app repos | various | their own application code; a copy of the layout under `ai/` | nothing back to sdlc | the templates, via `/sdlc:adopt` and `/sdlc:sync` (d) | per repo |

- **Owns** — the data and the capability this service is the source of truth for.
- **Exposes** — the contracts others may depend on. Anything not listed here is internal and
  may change without notice.
- **Consumes** — the contracts this service depends on, and therefore may not break.

Both scaffolds are at plugin version 0.3.0 (d). Their plugin names are `nextjs` and `nestjs`
— the repo names carry the `-base` suffix, the plugin names do not (d). Earlier docs called
them `nextjs-scaffold` / `nestjs-scaffold`; that naming is stale (t).

## Boundaries
- sdlc must not contain framework-specific content. Next.js and NestJS rules live in the
  scaffolds and arrive through the `{{overlay_note}}` `{{rules_extra}}` `{{dod_extra}}`
  `{{dont_touch_extra}}` `{{fleet_extra}}` slots.
- The scaffolds depend on sdlc; sdlc must never depend on a scaffold, read one, or name one
  in a template.
- A change to `skills/ai-layout/templates/` is a contract change: it reaches every adopted
  repo on its next `/sdlc:adopt` or `/sdlc:sync`. It needs a CHANGELOG entry naming the
  blast radius, and the scaffolds record the tag they built on in their `ai/AGENTS.md`.
- Hook scripts must never write to stdout and must no-op in a repo with no `ai/` directory —
  they run in every repo where the plugin is installed, not only adopted ones.

## Environments
Developer machines (plugin installed from the `n6` marketplace, or `--plugin-dir` locally)
and CI (`make ai` / `make review`, headless, non-interactive). Model aliases resolve through
the LiteLLM proxy at llm.nsix.io; `ai/models.yaml` holds the mapping.

## Known gaps
- ~~`.claude-plugin/marketplace.json` pinned sdlc at `0.3.0` while `plugin.json` was
  `0.5.0`~~ — **fixed**; the definition of done now requires both files bumped together,
  since they drifted silently through 0.4.0 and 0.5.0. Nothing yet *checks* that they agree.
- ~~`README.md` installed from `git@gitlab.nsix.io:ai/ai-sdlc.git` while the remote is
  `ai/sdlc.git`~~ — **fixed**; the documented install command works now.
- The n6 runtime estate — the existing services and the LavinMQ, Valkey, Postgres/MongoDB
  and Unleash they share — is deliberately out of scope here. Add rows only when a design
  actually needs them (t).
- Neither scaffold carries an `ai/` layout of its own (d), so neither can run this loop on
  itself the way sdlc now does.
- Owners of `ai/nextjs-base` and `ai/nestjs-base` are unknown.
- Nothing tells an adopted repo that the templates moved; adopters find out by running
  `/sdlc:sync`. Whether that needs a version check is undecided.
