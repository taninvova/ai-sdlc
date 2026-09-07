# Fleet map — ai-sdlc

The services the `architect` agent reads before it decides where a capability belongs.

This plugin is standalone: it has no dependency on any other repo, and it must not acquire
one. Nothing here is deployed — it is a Claude Code plugin consumed by developer machines
and CI, so "service" means "plugin" and "contract" means "the templates and prompts a
consumer builds on".

Provenance: `(d)` detected from the repo, `(t)` told by the developer, `unverified` neither.
Last refreshed by `/t4:fleet`.

| Service | Repo | Owns | Exposes | Consumes | Owner |
|---|---|---|---|---|---|
| ai-sdlc | `ai/ai-sdlc` (d) — local dir `ai-sdlc` | the `ai/` layout, task prompts, reviewer / tester / architect agents, logging and guard hooks | `skills/ai-layout/templates/` · `agents/*.md` · `hooks/hooks.json` · `/t4:adopt-sdlc` `/t4:explore` `/t4:sync-sdlc` (d) | **nothing** (d) | tanin (d) |

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
  `{{fleet_extra}}` slots with their own rules, docs and skills. An overlay owns the
  `overlay` block of `ai/.sdlc.json`; ai-sdlc never writes it, which is how it stays ignorant
  of who its overlays are.
- **Adopted application repos** — any repo that has run `/t4:adopt-sdlc`, carrying its own copy
  of the layout under `ai/` and an `ai/.sdlc.json` recording which ai-sdlc version it holds.
  Each is the source of truth for its own version; nothing here keeps a copy.

## Boundaries
- **ai-sdlc depends on no repo.** It must never read, name, list or version-pin another repo —
  not in a template, a command, a doc or an agent prompt. A capability that needs knowledge
  of a consumer belongs in that consumer.
- ai-sdlc must not contain framework-specific content. Framework rules reach a project through
  the overlay slots, supplied by whoever installed the overlay.
- No runtime dependency of any kind: no package manager, no lockfile, no submodule, no
  vendored code. Hook scripts use the Node standard library only (d).
- A change to `skills/ai-layout/templates/` is a contract change: it reaches every adopted
  repo on its next `/t4:adopt-sdlc` or `/t4:sync-sdlc`, and needs a CHANGELOG entry naming the
  blast radius.
- Hook scripts must never write to stdout and must no-op in a repo with no `ai/` directory —
  they run in every repo where the plugin is installed, not only adopted ones.
- Drift is pull-only. ai-sdlc never writes into an adopted repo out of band and stores no copy
  of adopter state — see docs/adr/0002.

## Environments
Developer machines (plugin installed from a git marketplace, or `--plugin-dir` locally) and
CI (`make ai` / `make review`, headless, non-interactive). Provider-agnostic: `ai/models.yaml`
is blank by default, so each tool runs whatever model it is configured with, and the same file
carries per-model prices for the cost column of `ai/runs/log.csv`.

## Known gaps
- **Hooks run from the installed plugin, not the working tree.** This repo's log.csv took
  three 12-field rows under the 16-field header because the installed copy is 0.3.0, whose
  session-stop.js appends blind. The 0.7.0 writer moves a mismatched file aside; the older one
  cannot, so a repo that updates its header before its plugin gets mixed rows until the plugin
  is updated and the session restarted (d).
- ~~`.claude-plugin/marketplace.json` pinned ai-sdlc at `0.3.0` while `plugin.json` was
  `0.5.0`~~ — **fixed**; the definition of done now requires both files bumped together,
  since they drifted silently through 0.4.0 and 0.5.0. Nothing yet *checks* that they agree.
- ~~`README.md` installed from `git@gitlab.nsix.io:ai/ai-sdlc.git` while the remote is
  `ai/sdlc.git`~~ — **fixed**; the documented install command works now.
- ~~An adopted repo has no way to learn its layout is behind these templates~~ — **built** in
  0.8.0: `/t4:adopt-sdlc` writes `ai/.sdlc.json` and `/t4:sync-sdlc` reports drift against it
  (docs/adr/0001–0003). Still open: taking an upstream change is manual — there is no
  `/t4:sync-sdlc --update` — and by design nothing here can answer "which repos are behind?".
- ~~Nothing checks that `marketplace.json`'s pin agrees with `plugin.json`~~ — **fixed** in
  0.9.0: `skills/ai-layout/scripts/check-versions.sh` compares every manifest that carries a
  version. It caught a real drift on its first run (docs/adr/0003).
- ~~`specs/0000-scaffold.md` and `hooks/hooks.json` still named "ai-base"~~ — **fixed** in
  0.7.1; the plugin was renamed in 0.2.0 and again in 0.3.0.
- ~~Two writers appended to `ai/runs/log.csv` with different columns~~ — **fixed** in 0.7.0:
  one 16-column schema, a `source` column saying which writer produced the row, and
  `fixtures/check-log-schema.sh` pinning the two declarations together.
