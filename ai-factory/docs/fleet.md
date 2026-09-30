# Fleet map — ai-sdlc

The services the `architect` agent reads before it decides where a capability belongs.

This plugin is standalone: it has no dependency on any other repo and no runtime dependency,
and it must not acquire either. Two optional task paths reach services a repo configures — a
tracker (ai-factory/adr/0004) and a read-only knowledge source (ai-factory/adr/0007) — each behind one
seam document and each inert where the repo declares nothing. Nothing here is deployed — it is a Claude Code plugin consumed by developer machines
and CI, so "service" means "plugin" and "contract" means "the templates and prompts a
consumer builds on".

Three names are in play and none of them match, which is the first thing to get straight:
the **repo** is `ai-sdlc` (GitLab `ai-factory/sdlc`), the **plugin** is `t4` — which is why every
command is `/t4:…` — and the **marketplace** is `sdlc`. The install handle is therefore
`t4@sdlc` (d).

Provenance: `(d)` detected from the repo, `(t)` told by the developer, `unverified` neither.
Last refreshed by `/t4:fleet`.

| Service | Repo | Owns | Exposes | Consumes | Owner |
|---|---|---|---|---|---|
| ai-sdlc (plugin `t4`) | `ai-factory/sdlc` (d) — local dir `ai-sdlc` | the `ai-factory/` layout, task prompts, eight agents (reviewer, tester, architect, analyst, explorer, specifier, planner, implementer), logging and guard hooks | `skills/ai-layout/templates/` · `agents/*.md` · `hooks/hooks.json` · `/t4:adopt-sdlc` `/t4:sync-sdlc` (d) | **nothing** (d) | tanin (d) |

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
  `overlay` block of `ai-factory/.sdlc.json`; ai-sdlc never writes it, which is how it stays ignorant
  of who its overlays are.
- **Adopted application repos** — any repo that has run `/t4:adopt-sdlc`, carrying its own copy
  of the layout under `ai-factory/` and an `ai-factory/.sdlc.json` recording which ai-sdlc version it holds.
  Each is the source of truth for its own version; nothing here keeps a copy.

## Boundaries
- **ai-sdlc depends on no repo.** It must never read, name, list or version-pin another repo —
  not in a template, a command, a doc or an agent prompt. A capability that needs knowledge
  of a consumer belongs in that consumer.
- **Two optional service dependencies, and no other.** A task may call an external tracker in a
  repo that has committed `ai-factory/jira.yaml`, and an agent may read an external knowledge source in
  a repo that has committed `ai-factory/knowledge_base.md`. Every task works without either; a repo
  that configures neither sees no new prompt, no new question and no new failure mode. The
  tracker is named only in `ai-factory/docs/tracker.md` and the knowledge source only in
  `ai-factory/docs/knowledge.md`, never in a task prompt (ai-factory/adr/0004, 0007). The tracker stops when
  its input cannot be resolved; the knowledge seam proceeds and reports when its source cannot
  be reached.
- ai-sdlc must not contain framework-specific content. Framework rules reach a project through
  the overlay slots, supplied by whoever installed the overlay.
- No runtime dependency of any kind: no package manager, no lockfile, no submodule, no
  vendored code. Hook scripts use the Node standard library only (d).
- A change to `skills/ai-layout/templates/` is a contract change: it reaches every adopted
  repo on its next `/t4:adopt-sdlc` or `/t4:sync-sdlc`, and needs a CHANGELOG entry naming the
  blast radius.
- Hook scripts must never write to stdout and must no-op in a repo with no `ai-factory/` directory —
  they run in every repo where the plugin is installed, not only adopted ones.
- Drift is pull-only. ai-sdlc never writes into an adopted repo out of band and stores no copy
  of adopter state — see ai-factory/adr/0002.

## Environments
Developer machines (plugin installed from a git marketplace, or `--plugin-dir` locally) and
CI (`make ai` / `make review`, headless, non-interactive). Provider-agnostic: `ai-factory/models.yaml`
is blank by default, so each tool runs whatever model it is configured with, and the same file
carries per-model prices for the cost column of `ai-factory/runs/log.csv`.

## Known gaps
- **Hooks run from the installed plugin, not the working tree** (d) — still true, and still
  the reason a session can behave unlike the code in front of you. What it used to cost is
  fixed: an older writer appending 12-field rows under the 16-field header went unnoticed
  because only the header was checked, so this repo's log took several such rows. Since 0.10.0
  both writers measure every row and quarantine the ones that do not fit, which catches a
  stale hook rather than trusting it. Editing the installed copy is still not a fix — updating
  the plugin and restarting the session is.
- ~~A repo adopted before 0.5.0 kept its bare `.claude/commands/spec.md` through every sync and
  answered both `/spec` and `/t4:spec`~~ — **fixed** in 0.16.0: cleanup identifies generated
  commands by the `ai-factory/tasks/` include they carry rather than by a name glob, so older
  generations go and hand-written commands stay. Found in a repo scaffolded at ai-base 0.1.2.
- ~~`.claude-plugin/marketplace.json` pinned ai-sdlc at `0.3.0` while `plugin.json` was
  `0.5.0`~~ — **fixed**; the definition of done now requires both files bumped together,
  since they drifted silently through 0.4.0 and 0.5.0. Nothing yet *checks* that they agree.
- ~~`README.md` installed from a URL that did not match the
  remote~~ — **fixed**; the documented install command works now.
- ~~An adopted repo has no way to learn its layout is behind these templates~~ — **built** in
  0.8.0: `/t4:adopt-sdlc` writes `ai-factory/.sdlc.json` and `/t4:sync-sdlc` reports drift against it
  (ai-factory/adr/0001–0003). Still open: taking an upstream change is manual — there is no
  `/t4:sync-sdlc --update` — and by design nothing here can answer "which repos are behind?".
- ~~Nothing checks that `marketplace.json`'s pin agrees with `plugin.json`~~ — **fixed** in
  0.9.0: `skills/ai-layout/scripts/check-versions.sh` compares every manifest that carries a
  version. It caught a real drift on its first run (ai-factory/adr/0003).
- ~~`ai-factory/specs/0000-scaffold.md` and `hooks/hooks.json` still named "ai-base"~~ — **fixed** in
  0.7.1. The plugin has since been renamed twice more — `ai-sdlc` in 0.12.0, `t4` in 0.13.0 —
  and the marketplace twice, `t4` in 0.11.0 and `sdlc` in 0.15.0. Naming is the most
  frequently churned thing in this repo; anything quoting a name dates quickly.
- ~~Two writers appended to `ai-factory/runs/log.csv` with different columns~~ — **fixed** in 0.7.0:
  one 16-column schema, a `source` column saying which writer produced the row, and
  `fixtures/check-log-schema.sh` pinning the two declarations together.
