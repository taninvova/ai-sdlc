# Changelog

## 0.9.0 — 2026-09-06
- **Codex support.** `sync-adapters.sh` now generates `.codex/skills/` beside `.claude/` and
  `.cursor/`, so the same eleven tasks are slash commands in Codex. Verified against Codex
  0.153.4: `.codex/skills/` is picked up with no configuration. The skills point at
  `ai/tasks/<name>.md` rather than copying it, so there is still one source of truth.
- **Agents are inlined under Codex, and say so.** Codex plugin manifests support only
  `skills` and `mcpServers` — no subagents — so the four agent-backed tasks (`check`, `test`,
  `design`, `adr`) tell the session to follow `ai/agents/<name>.md` itself. The generated
  skill states the cost plainly: a tester that has seen the implementation writes tests that
  restate it, and a reviewer that wrote the code is not an independent review.
- **`make ai TOOL=codex`.** `ai.mk` builds the invocation per tool — `codex exec --json` with
  the prompt on stdin and the final message via `-o`, versus `claude -p --output-format json`.
  `log.js` sniffs which shape it was given; `gate.js` reads Codex's `-o` file. Both parsers
  were written from real captured output, not from assumption.
- Codex reports **no cost**, so `cost_usd` stays empty for its rows rather than being guessed,
  and its `input_tokens` include cached tokens (the OpenAI convention), which `log.js`
  subtracts back out so the column means the same thing in every row.
- `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` ship for Codex-native
  discovery. Codex also reads the `.claude-plugin/` manifests — confirmed by test — so these
  are belt-and-braces rather than required.
- **`skills/ai-layout/scripts/check-versions.sh`** asserts every manifest carrying a version
  agrees. It caught a real drift on its first run. Definition of done item 3 now points at it
  instead of asking a human to remember.
- `skills/ai-layout/scripts/check-adapters.sh` asserts all three adapter sets are generated,
  that the inline-agent note appears exactly where a task delegates and nowhere else, and that
  a second sync changes nothing. Verified to fail when the generator drifts either way.
- `.codex/` is in the template `dont-touch.md` — it is generated, like `.claude/` and `.cursor/`.
- **Not supported under Codex:** hooks. No session or edit log, no cost row, and **no
  dont-touch guard** — `docs/workflow.md` says so in those words.

## 0.8.0 — 2026-09-06
- **Layout drift detection.** `/sdlc:adopt` now writes `ai/.sdlc.json` recording which sdlc
  version a repo received and a hash per file; `/sdlc:sync` compares it against the installed
  templates and reports six states — upstream changed (safe to take), both changed (merge by
  hand), locally modified, new upstream, removed upstream, missing locally — plus a version
  comparison. Before this an adopted repo had no way to learn it was behind, and `/sdlc:sync`
  regenerated adapters without comparing anything. Implements
  `ai/designs/0001-layout-version-and-drift.md`; decisions in `docs/adr/0001`-`0003`.
- **Two hashes per file, not one.** The design sketched a single hash, which cannot work:
  adopt substitutes `{{app}}`, `{{stack}}` and friends, so a repo file never equals its
  template and every substituted file would report as modified forever. The manifest records
  `received` (what landed in the repo) and `template` (what it came from).
- `/sdlc:sync` still changes nothing under `ai/` — it reports, and taking an upstream change
  stays a separate reviewable edit. A repo with no manifest is told how to start a baseline
  rather than treated as an error, and a manifest with a newer `schema` stops the check
  instead of being misread.
- `ai/.sdlc.json` is listed in the template `ai/docs/dont-touch.md`, so `guard-paths.js`
  blocks hand edits — a manifest edited by hand makes the check lie.
- `skills/ai-layout/scripts/check-manifest.sh` covers all six drift states, version drift,
  the migration path, the schema guard, that `check` never mutates the repo, and that the
  plugin's own repo never gets a manifest.

## 0.7.1 — 2026-09-06
- Drop the last two uses of "ai-base", the name this plugin left behind in 0.2.0:
  `skills/ai-layout/templates/specs/0000-scaffold.md`, which every adopted repo receives as
  its first spec, and the `hooks/hooks.json` description. Both now say `ai-sdlc`, matching
  the templates.

## 0.7.0 — 2026-09-06
- **`ai/runs/log.csv` has one schema.** Two writers were appending rows with different
  column meanings to the same file: the Stop hook wrote
  `ts,session_id,user,branch,turns,…` while `ai/make/log.js` wrote
  `ts,run_id,task,tool,model,…`. Any reader of a repo that used both got nonsense, and only
  headless runs recorded the model. Both now write the same 16 columns —
  `ts,session_id,source,user,branch,task,tool,model,turns,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,hit_rate,cost_usd,accepted`
  — with `source` naming the writer (`session` or `make`) and each blanking what it cannot
  know. Fields are CSV-quoted, so a branch or model containing a comma no longer shifts
  every later column.
- **Migration is automatic and lossless.** A log.csv with any other header has its rows
  moved to `ai/runs/log.previous.csv` on the next write, and a clean file started. Old rows
  are not reinterpreted — they came from two writers and cannot be told apart safely.
- **`skills/ai-hooks/fixtures/check-log-schema.sh`** pins the two declarations together: the
  writers must agree, every row must match the header width, and migration must preserve the
  old rows. Verified to fail when the headers are made to drift.

## 0.6.0 — 2026-09-06
- **Any model, any provider.** `ai/models.yaml` now ships blank, meaning "whatever the tool
  is already configured with", and `make ai` passes no `--model` at all unless a value is
  set — so a pinned alias is never required and no endpoint is assumed. Commented examples
  cover a plain model id and a gateway alias. `CMD ?= claude` makes the binary overridable.
- **Costs are priced by the model that actually ran.** The session-stop hook reads the model
  from the transcript and matches `pricing:` by exact id, then by longest id prefix (so
  `claude-haiku-4-5` covers `claude-haiku-4-5-20251001`), then `default`. Previously every
  run was costed at one hardcoded Anthropic rate. No match still writes `~` for an estimate.
- **`make ai` was broken and never invoked a model at all** — pre-existing, since before the
  0.5.x work. The recipe embedded a blank line and two unindented lines inside the prompt
  string, and a makefile recipe ends at the first line without a leading tab, so everything
  from `claude -p` onward was parsed as makefile text rather than run. `make review`
  inherited the failure. The prompt is now assembled into a temp file on tab-indented
  continuation lines.
- **`make review` corrupted diffs containing `$`.** The diff was routed through a make
  variable, which re-expands `$`; it now goes to a file passed as `INPUT_FILE`, byte for
  byte. `INPUT_FILE=<path>` works for any task.
- No n6-specific configuration remains in the templates: the AGENTS.md setup section names
  no provider, and `ai/docs/architecture.md` no longer claims a LiteLLM proxy resolves aliases.

## 0.5.1 — 2026-09-06
- **Standalone.** The plugin names, reads and version-pins no other repo. There was never a
  functional dependency — no package manager, lockfile, submodule or out-of-repo path, and
  the hooks use the Node standard library only — but eight documents named the framework
  scaffold repos and pinned their versions, most of it written into `ai/docs/fleet.md` by
  the first `/ai-fleet` run reading sibling checkouts off disk. Consumers are now described
  generically: overlay plugins and adopted repos, named nowhere.
- `ai/docs/fleet.md` is scoped to this repo alone, its **Consumes** column deliberately
  empty, with the one-way dependency written into Boundaries so `/ai-design review` enforces
  it on future plans.

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
