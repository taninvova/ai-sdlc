# Fleet map — ai-sdlc

The services the `architect` agent reads before it decides where a capability belongs.
Scoped to this project: the `nsix/ai/` GitLab group. Nothing here is deployed — these are
Claude Code plugins consumed by developer machines and CI, so "service" means "plugin" and
"contract" means "the templates and prompts another plugin builds on".

| Service | Repo | Owns | Exposes | Consumes | Owner |
|---|---|---|---|---|---|
| sdlc | ai/ai-sdlc (this repo) | the `ai/` layout, task prompts, reviewer / tester / architect agents, logging and guard hooks | `skills/ai-layout/templates/` · `agents/*.md` · `hooks/hooks.json` · `/sdlc:adopt` `/sdlc:explore` `/sdlc:sync` | nothing | tanin |
| nextjs-scaffold | ai/nextjs-scaffold | the Next.js application scaffold and its overlay docs and skills | its own scaffold command | sdlc's templates and `{{…_extra}}` overlay slots | unverified |
| nestjs-scaffold | ai/nestjs-scaffold | the NestJS application scaffold and its overlay docs and skills | its own scaffold command | sdlc's templates and `{{…_extra}}` overlay slots | unverified |
| adopted app repos | various | their own application code; a copy of the layout under `ai/` | nothing back to sdlc | the templates, via `/sdlc:adopt` and `/sdlc:sync` | per repo |

- **Owns** — the data and the capability this service is the source of truth for.
- **Exposes** — the contracts others may depend on. Anything not listed here is internal and
  may change without notice.
- **Consumes** — the contracts this service depends on, and therefore may not break.

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
- `nextjs-scaffold` and `nestjs-scaffold` rows are `unverified` — written from this repo's
  README and CHANGELOG, not read from those repos. Their owners are unknown.
- No mechanism tells an adopted repo that the templates moved; adopters find out by running
  `/sdlc:sync`. Whether that needs a version check is undecided.
