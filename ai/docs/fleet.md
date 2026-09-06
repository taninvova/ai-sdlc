# Fleet map — ai-sdlc

The services the `architect` agent reads before it decides where a capability belongs.

This plugin is standalone: it has no dependency on any other repo, and it must not acquire
one. Nothing here is deployed — it is a Claude Code plugin consumed by developer machines
and CI, so "service" means "plugin" and "contract" means "the templates and prompts a
consumer builds on".

Provenance: `(d)` detected from the repo, `(t)` told by the developer, `unverified` neither.
Last refreshed by `/ai-fleet`.

| Service | Repo | Owns | Exposes | Consumes | Owner |
|---|---|---|---|---|---|
| sdlc | `ai/sdlc` (d) — local dir `ai-sdlc` | the `ai/` layout, task prompts, reviewer / tester / architect agents, logging and guard hooks | `skills/ai-layout/templates/` · `agents/*.md` · `hooks/hooks.json` · `/sdlc:adopt` `/sdlc:explore` `/sdlc:sync` (d) | **nothing** (d) | tanin (d) |

- **Owns** — the data and the capability this service is the source of truth for.
- **Exposes** — the contracts others may depend on. Anything not listed here is internal and
  may change without notice.
- **Consumes** — the contracts this service depends on, and therefore may not break. This
  row is empty by design and must stay empty.

## Consumers
Two kinds of repo depend on this one. Neither is named here, and neither may be read, listed
or version-pinned by anything in this repo — the dependency runs one way only.

- **Overlay plugins** — framework scaffolds that copy this layout and fill the
  `{{overlay_note}}` `{{rules_extra}}` `{{dod_extra}}` `{{dont_touch_extra}}`
  `{{fleet_extra}}` slots with their own rules, docs and skills.
- **Adopted application repos** — any repo that has run `/sdlc:adopt`, carrying its own copy
  of the layout under `ai/`.

## Boundaries
- **sdlc depends on no repo.** It must never read, name, list or version-pin another repo —
  not in a template, a command, a doc or an agent prompt. A capability that needs knowledge
  of a consumer belongs in that consumer.
- sdlc must not contain framework-specific content. Framework rules reach a project through
  the overlay slots, supplied by whoever installed the overlay.
- No runtime dependency of any kind: no package manager, no lockfile, no submodule, no
  vendored code. Hook scripts use the Node standard library only (d).
- A change to `skills/ai-layout/templates/` is a contract change: it reaches every adopted
  repo on its next `/sdlc:adopt` or `/sdlc:sync`, and needs a CHANGELOG entry naming the
  blast radius.
- Hook scripts must never write to stdout and must no-op in a repo with no `ai/` directory —
  they run in every repo where the plugin is installed, not only adopted ones.

## Environments
Developer machines (plugin installed from a git marketplace, or `--plugin-dir` locally) and
CI (`make ai` / `make review`, headless, non-interactive). Provider-agnostic: `ai/models.yaml`
is blank by default, so each tool runs whatever model it is configured with, and the same file
carries per-model prices for the cost column of `ai/runs/log.csv`.

## Known gaps
- ~~`.claude-plugin/marketplace.json` pinned sdlc at `0.3.0` while `plugin.json` was
  `0.5.0`~~ — **fixed**; the definition of done now requires both files bumped together,
  since they drifted silently through 0.4.0 and 0.5.0. Nothing yet *checks* that they agree.
- ~~`README.md` installed from `git@gitlab.nsix.io:ai/ai-sdlc.git` while the remote is
  `ai/sdlc.git`~~ — **fixed**; the documented install command works now.
- An adopted repo has no way to learn its layout is behind these templates, and this repo
  has no way to learn which version any adopter is on. `/sdlc:sync` regenerates `.claude/`
  and `.cursor/` from `ai/` and copies nothing back in; `/sdlc:adopt` refuses when `ai/`
  already exists. Designed in `ai/designs/0001-layout-version-and-drift.md`, not built.
- `skills/ai-layout/templates/specs/0000-scaffold.md` still names "ai-base", the plugin's
  pre-0.2.0 name (d).
- Two writers append to `ai/runs/log.csv` with different columns (d): the session-stop hook
  writes `session_id,user,branch,turns,…` while `ai/make/log.js` writes
  `run_id,task,tool,model,…`. Same file, incompatible rows; only the headless writer records
  the model. Needs one schema.
