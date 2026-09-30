# 0006 — The layout directory is ai-factory/, and every loop artefact lives in it

Summary: the layout directory ai-sdlc ships is renamed `ai/` → `ai-factory/`, and the working
files and folders still kept outside it move in — `specs/` → `ai-factory/specs/`, `docs/adr/` →
`ai-factory/adr/`, `docs/workflow.md` → `ai-factory/docs/workflow.md` — leaving no top-level
`ai/`, `specs/` or `docs/` at all. An adopted repo then carries exactly one directory for the
operating model, `ai-factory/`, plus the three root entry points tools must find at the root:
`AGENTS.md`, `CLAUDE.md`, `Makefile`.

This renames the thing every part of the plugin names. Detection (`_common.js` joins `cwd` with
`"ai"`), the manifest path, the dont-touch rules, the gitignore and gitattributes lines, the
Makefile include, `CLAUDE.md`'s single `@` import, `sync-adapters.sh`, the doctor, all twelve
task prompts, all eight agents and every check script name `ai/` today. So it ships with a
migration the developer runs in their own repo on taking the update: it moves the directories
with history, rewrites the references, regenerates the adapters and refreshes the manifest.
ADR 0002 still holds — ai-sdlc keeps no registry and never reaches into a repo; the migration
runs only because someone ran it there.

Decided, and not reopened below: the directory is named `ai-factory/`; the workflow doc lands at
`ai-factory/docs/workflow.md`; the fallback to the old paths is granted to the hooks and withheld
from the prompts; the migration refuses to run with tracked changes in flight; `/t4:doctor` reports a
half-migrated repo; this ships as **1.0.0**; and both the migration command and the hook fallback
are transitional: the command goes in 1.1.0, the fallback in 2.0.0.

AC6 pins the hook half. The hooks must accept `ai/` as well as `ai-factory/`, because a repo
that has taken the plugin update and not yet migrated would otherwise lose its dont-touch guard
and its run log silently — the worst possible failure mode for a rename, since nothing would
appear to be wrong. The prompts get no such fallback: a prompt that reads a path the repo no
longer has fails in front of the developer who can fix it, which costs a visible error in that
same window and buys one live path per prompt and an absolute scan (AC5). The asymmetry is the
decision, not an oversight — a silent loss of a guard is not comparable to a loud missing file.

## User story
As a developer working across repos that carry the ai-sdlc layout, I want that layout in one
directory named for what it is — `ai-factory/` — holding every file the loop reads and writes,
and one command that moves an existing repo there when I take the plugin update, so that the
operating model is one reviewable, greppable, explainable directory instead of a bare `ai/`
plus two top-level strays, and so that updating does not mean hand-moving directories and
hand-editing prompts in every repo that adopted.

## Acceptance criteria

### The new layout

- **AC1** Given the release, When `skills/ai-layout/templates/` is listed, Then it holds no
  `ai/`, `specs/` or `docs/` directory; `templates/ai-factory/` holds everything
  `templates/ai/` held — `AGENTS.md`, `models.yaml`, `docs/`, `tasks/`, `agents/`, `make/`,
  `plans/done/`, `runs/log.csv`, `designs/`, `analyses/`, `explorations/` — plus
  `ai-factory/specs/0000-scaffold.md` and `ai-factory/adr/0000-template.md`; and the only paths
  the templates place outside `ai-factory/` are `AGENTS.md`, `CLAUDE.md` and `Makefile`.
- **AC2** Given the release, When the root entry points are read, Then `templates/AGENTS.md` is
  `See ai-factory/AGENTS.md`, `templates/CLAUDE.md` is `@ai-factory/AGENTS.md`,
  `templates/Makefile` includes `ai-factory/make/ai.mk`, and the gitignore and gitattributes
  lines `skills/ai-hooks/SKILL.md` prescribes name `ai-factory/runs/*.json`,
  `ai-factory/runs/*.jsonl`, `ai-factory/runs/log.pending.csv` and
  `ai-factory/runs/log.csv merge=union`.
- **AC3** Given a scratch repo with no layout, When `/t4:adopt-sdlc` is run in it, Then the repo
  gains `ai-factory/` and nothing else but `AGENTS.md`, `CLAUDE.md` and `Makefile`;
  `ai-factory/.sdlc.json` is written and tracks every received file at its `ai-factory/` path;
  `bash ai-factory/make/sync-adapters.sh` generates `.claude/`, `.cursor/` and `.codex/`; and
  `make -n ai TASK=spec` resolves the `ai-factory/make/ai.mk` include and prints the recipe.
  Checked dry, without invoking a model: the include is what a rename breaks, and a live headless
  run would spend tokens proving nothing about it.
- **AC4** Given this repo, When the root is listed, Then `ai/`, `specs/` and `docs/` are gone;
  `ai-factory/` holds the former `ai/**` plus `ai-factory/specs/0001-*.md … 0006-*.md`,
  `ai-factory/adr/0000-template.md … 0007-*.md` and `ai-factory/docs/workflow.md`;
  `ai-factory/tasks/`, `ai-factory/agents/` and `ai-factory/make/` are real directories whose
  entries are per-file symlinks — 12, 4 and 4 — and `ai-factory/models.yaml` and
  `ai-factory/adr/0000-template.md` are two more, 22 in all, each resolving into
  `skills/ai-layout/templates/ai-factory/` or `agents/`; every one of the 22 resolves, and no
  real file sits under `ai-factory/tasks/`; and `git log --follow` on one moved spec, one moved
  ADR and
  `ai-factory/docs/workflow.md` reaches the commit that created each — moved, not re-created.
- **AC5** Given the release, When the pre-1.0.0 paths are scanned for across `agents/`,
  `commands/`, `hooks/`, `skills/`, `README.md`, `ai-factory/AGENTS.md` and `ai-factory/docs/`,
  Then nothing is found: no `ai/`, `specs/`, `docs/adr` or `docs/workflow` survives in any prompt,
  agent, skill, hook, command, context doc or README.
  Two things the obvious pattern gets wrong, both found while doing the rename.
  `(^|[^-[:alnum:]_./])(ai/|…)` excludes a preceding `/` so that `~/code/ai/ai-sdlc` survives —
  and is therefore blind to `templates/ai/` and `templates/specs/`, which is where half the stale
  references were. The scan must neutralise the correct prefix first and then match with `/`
  allowed before, allow-listing the two paths that are not layout references at all (the GitLab
  group in the remote URL and the workspace directory), and exempting lines marked
  deliberate.
  And **records are not scanned**: specs, plans, designs, analyses, ADRs and the CHANGELOG keep the
  paths that were true when they were written (AC9). `ai-factory/adr/0008-*` is therefore out of
  the set, not in it — it decides the rename and cannot state the decision without naming `ai/`.
- **AC6** Given the release, When the hooks run in a repo that holds only `ai/` — updated
  plugin, migration not yet run — Then every hook behaves exactly as it did before the rename:
  the Stop hook appends its row, `guard-paths.js` refuses a write to a dont-touch path, and
  nothing prints to stdout. And given a repo that holds only `ai-factory/`, the same. And given
  a repo holding both, `ai-factory/` is the one used. And given a repo holding neither, every
  script no-ops as it does today. `hooks/hooks.json`'s description states both names.
- **AC7** Given every file that cites a moved path — `templates/ai-factory/tasks/{spec,plan,adr}.md`,
  `templates/ai-factory/agents/{architect,specifier}.md`, `templates/ai-factory/AGENTS.md`,
  `templates/ai-factory/docs/{knowledge,tracker}.md`, all eight `agents/*.md`, this repo's
  `ai-factory/AGENTS.md` and `ai-factory/docs/{knowledge,fleet,coding-standards,definition-of-done,architecture}.md`,
  `skills/ai-layout/SKILL.md`, `skills/ai-hooks/SKILL.md`, `commands/*.md`, `README.md`, the
  comment citations in `skills/ai-layout/scripts/*.sh` and the links inside `workflow.md` itself
  — When read after the release, Then each names the new path, and a citation of an ai-sdlc ADR
  inside a template still reads as a citation of ai-sdlc's ADR rather than of a file the
  adopting repo holds.
- **AC8** Given the release, When `ai-factory/adr/` is listed, Then a new ADR numbered `0008`
  records this decision with Context, Decision, Consequences and a Date; states that the layout
  directory is `ai-factory/` and every loop artefact lives in it; and names the blast radius —
  breaking for every adopted repo, migrated by the command of AC13, with the hook fallback of
  AC6 as the reason nothing breaks silently in between.
- **AC9** Given already-released history — the plans in `ai-factory/plans/`, the designs, the
  analysis, specs `0001`–`0005`, ADRs `0001`–`0007` and the CHANGELOG entries for versions up to
  0.27.1 — When diffed against before the release, Then their prose is unchanged: a record of
  what was decided keeps the paths that were true when it was written. Only their own location
  changes, for the files AC4 moves.
- **AC10** Given the release, When `bash ai-factory/make/sync-adapters.sh` is run twice, Then
  the first run exits 0, the second produces no diff, `bash
  skills/ai-layout/scripts/check-adapters.sh` passes, and the generated
  `.claude/commands/t4/*.md` and `.codex/skills/t4-*/SKILL.md` name `ai-factory/` — including
  `t4-adr` naming `ai-factory/adr/` and the Codex inline notes naming
  `ai-factory/agents/<name>.md`.
- **AC11** Given the release, When `ai-factory/docs/dont-touch.md` is read, Then its rules name
  `ai-factory/runs/`, `ai-factory/tasks/`, `ai-factory/agents/` and `ai-factory/make/`; and When
  a write to `ai-factory/tasks/spec.md` is attempted, Then `guard-paths.js` refuses it, while a
  write to `ai-factory/specs/0007-x.md` is allowed — the guard stays data-driven, reading the
  backticked prefixes rather than knowing the directory name.
- **AC12** Given the release, When the log path changes, Then `ai-factory/runs/log.csv` keeps
  the same 16 columns in the same order, `bash skills/ai-hooks/fixtures/check-log-schema.sh`
  passes, `node skills/ai-hooks/scripts/session-stop.js < skills/ai-hooks/fixtures/stop.json`
  behaves as before, and `manifest.js` skips `ai-factory/runs/` as it skipped `ai/runs/`.

### The migration

- **AC13** Given the release, When the plugin's commands are listed, Then `/t4:migrate-layout`
  exists, is described as the move an adopted repo makes when it takes this update, and is
  backed by `skills/ai-layout/scripts/migrate-layout.sh`. And When `adopt-sdlc.md`,
  `sync-sdlc.md`, `hooks/hooks.json` and every task prompt are read, Then none of them invokes
  it: it runs only because a developer ran it.
- **AC14** Given a repo with `ai/`, a non-empty `specs/`, a non-empty `docs/adr/`, a clean
  working tree and `ai/.sdlc.json` written by 0.27.1, When `/t4:migrate-layout` is run in it,
  Then afterwards: `ai-factory/` holds what `ai/` held, plus `ai-factory/specs/` and
  `ai-factory/adr/` holding what those two directories held, all reachable by `git log
  --follow`; `docs/` is gone if nothing else was in it and untouched if something was; every
  file under `ai-factory/`, plus root `AGENTS.md`, `CLAUDE.md`, `Makefile`, `.gitignore` and
  `.gitattributes`, names `ai-factory/` where it named `ai/`, `specs/` or `docs/adr/`;
  `ai-factory/make/sync-adapters.sh` has been re-run; `ai-factory/.sdlc.json` has been refreshed
  by `manifest.js write`; nothing is committed; and the command has printed every path it moved
  and every file it rewrote.
- **AC15** Given a repo where the migration cannot be applied cleanly, When
  `/t4:migrate-layout` is run, Then it moves and rewrites nothing, exits non-zero, and names
  the reason — for each of: neither `ai/` nor `ai-factory/` present (pointing at
  `/t4:adopt-sdlc`); both present; both `specs/` and `ai-factory/specs/` non-empty; both
  `docs/adr/` and `ai-factory/adr/` non-empty; and uncommitted changes to tracked files, so the
  move is reviewable as its own commit. An untracked file is not among them: it cannot affect the
  move, and refusing for one blocked a real migration over a scratch directory an MCP server had
  made. It is named in the output instead, since the second commit's `git add -A` would take it.
- **AC16** Given a repo already on the new layout, When `/t4:migrate-layout` is run, Then it
  exits 0, reports that there is nothing to move, and leaves the working tree byte-identical —
  running it twice in a row is the same as running it once.
- **AC17** Given a repo still holding `ai/`, When `/t4:sync-sdlc` is run in it, Then it says the
  layout has been renamed, tells the developer to run `/t4:migrate-layout`, and syncs nothing —
  generating adapters from a directory the prompts no longer name would be worse than doing
  nothing. `/t4:sync-sdlc` still changes nothing under the layout directory and moves nothing.
  The drift report must be short-circuited too, and not because it would be long: measured, the
  per-file report is unreachable. `MANIFEST` moved to `ai-factory/.sdlc.json` in 1.0.0, so a repo
  holding a perfectly good `ai/.sdlc.json` looks like it has none, and the no-manifest branch
  tells it "adopted before manifests existed" (false), sends it to a baseline write that refuses
  for want of an `ai-factory/`, and from there to `/t4:adopt-sdlc`, which would scaffold a SECOND
  layout beside the first. Three wrong answers in a row, replaced by one instruction.
- **AC18** Given a migrated repo whose `ai-factory/.sdlc.json` was refreshed by AC14, When
  `node skills/ai-layout/scripts/manifest.js check <repo> <plugin>` is run, Then it exits 0 and
  reports the repo up to date — no "removed upstream", no "new upstream", no "missing locally"
  — proving the migration left a baseline that matches the templates it came from.

### Guards

- **AC19** Given a scratch copy of the repo in which one file under `agents/` or
  `skills/ai-layout/templates/ai-factory/` has had `ai-factory/` edited back to `ai/`, When the
  check script that owns AC5 is run, Then it exits non-zero and names that file; and given the
  repo unmodified, When the same script is run, Then it exits 0.
- **AC20** Given the release, When `skills/ai-layout/scripts/check-migrate.sh` is run, Then it
  pins `migrate-layout.sh` against synthetic repos built in a temp dir — old layout, already
  migrated, each refusal of AC15, and a repo with `ai/` but no `specs/` — and fails if any case
  departs from AC14–AC16. It never touches the developer's own repos.
- **AC21** Given the release, When the manifests and the CHANGELOG are read, Then every manifest
  that carries a version carries `1.0.0` — `.claude-plugin/plugin.json`,
  `.codex-plugin/plugin.json` and `.claude-plugin/marketplace.json`, three of them, not four:
  `.agents/plugins/marketplace.json` resolves its plugin from a local source and pins no version,
  which ADR 0003 prefers, since the version lives in one place and a pin exists only where the
  format demands one. `bash skills/ai-layout/scripts/check-versions.sh` passes, and
  the CHANGELOG entry marks the change breaking, tells an adopted repo to run
  `/t4:migrate-layout`, states that the hooks keep working in the meantime (AC6), and tells the
  developer to grep their own CI, deployment and tooling config for `ai/` — paths the plugin
  cannot see and does not touch.

- **AC22** Given `/t4:doctor` run in a repo that holds both `ai/` and `ai-factory/`, or that
  holds only `ai/` with this plugin installed, Then it reports the layout as renamed and the repo
  as half-migrated or unmigrated, names which directory the hooks are actually using (AC6), and
  tells the developer to run `/t4:migrate-layout`; and given a fully migrated repo, Then it
  reports the layout healthy and says nothing about migrating. `check-doctor.sh` pins both cases
  against synthetic repos, as it already pins the install and cache branches.
- **AC23** Given the migration run of AC14, When the resulting diff of the repo's own files is
  inspected, Then every changed line contains one of the old paths in its old and new form and
  nothing else differs — no upstream prompt text, no reworded rule and no new template content
  arrives with the migration; and the command's report separates what it moved from what it
  rewrote, so the rewrite can be reviewed, and reverted, on its own.
- **AC24** Given the release, When `ai-factory/adr/0008-*.md` is read, Then it records the AC14
  rewrite as a bounded exception to `/t4:sync-sdlc`'s rule that taking an upstream change is a
  separate reviewable edit — bounded by AC23 to path strings, and taken because without it the
  move orphans every prompt in the repo — and records both `/t4:migrate-layout` and the AC6 hook
  fallback as transitional — the command removed in 1.1.0, the fallback not before 2.0.0, because
  dropping it is itself a silent break. And When the CHANGELOG entry for 1.0.0 is
  read, Then it carries that deprecation notice.

## Out of scope
- Root `AGENTS.md`, `CLAUDE.md` and `Makefile`. Tools discover these at the repo root; they
  stay, and `CLAUDE.md` keeps its single `@` import, now `@ai-factory/AGENTS.md`.
- `README.md`, `CHANGELOG.md`, `LICENSE` — plugin-level documentation and licence, which belong
  at the root of any repo. Their *contents* change where they name a moved path (AC7).
- The plugin's own name and its skill names: `ai-sdlc`, `ai-layout`, `ai-hooks`, the `t4:`
  command prefix and the `make ai` target all stay. This renames a directory in adopted repos,
  not the product.
- The plugin's own source layout: `agents/`, `commands/`, `skills/`, `hooks/`,
  `.claude-plugin/`, `.codex-plugin/`, `.agents/`. Claude Code and Codex require these paths.
- Generated adapter trees `.claude/`, `.cursor/`, `.codex/` — regenerated by
  `sync-adapters.sh`, never hand-edited (AC10).
- The 16 log columns, `models.yaml`'s shape, the tracker and knowledge seams, and what any task
  prompt does. Only where files live, and one command to move them.
- Renumbering, rewording or splitting any moved spec or ADR (AC9).
- Committing, branching, pushing or opening an MR on the developer's behalf: the migration
  leaves its changes for review (AC14).
- Anything outside the repo that names `ai/` — CI jobs, pipeline config, dashboards, other
  tooling. The plugin cannot see them; AC21 tells the developer to look.
- Migrating a repo nobody runs the command in. ADR 0002 stands: no registry, no reaching in.

## Open questions
None. All nine are settled, and where each landed:

1. The AC5 scan is its own script, `skills/ai-layout/scripts/check-paths.sh`, lifting
   `check-adapters.sh`'s `scan_banned` pattern and its scratch-prompt self-proof rather than
   inventing a second way to prove a scan works (AC19).
2. `ai-factory/docs/workflow.md`, beside the other context docs.
3. The migration does rewrite the repo's own prompts, as a bounded exception recorded in
   `ai-factory/adr/0008` — path strings only, asserted by AC23, reported as its own list. Without
   it the move orphans every prompt in the repo.
4. The refusal is on uncommitted changes to **tracked** files. An untracked file is named, not
   refused: it cannot affect the move, and refusing for one blocked a real migration over a
   scratch directory an MCP server had created.
5. Settled with 1 above.
6. Yes — `/t4:doctor` reports all three states and says which directory the hooks are reading
   (AC22).
7. 1.0.0.
8. They do not expire together. `/t4:migrate-layout` goes in 1.1.0; the hooks' fallback waits for
   2.0.0, because removing it disarms the guard silently in any repo that never migrated.
9. `ai-factory`, confirmed before the rename began.

## Data touched
No models, no schema, no database — this repo is markdown prompts and Node hook scripts. What
changes is paths:
- Renamed in the templates: `templates/ai/**` → `templates/ai-factory/**`;
  `templates/specs/**` → `templates/ai-factory/specs/**`; `templates/docs/adr/**` →
  `templates/ai-factory/adr/**`.
- Renamed in this repo: `ai/**` → `ai-factory/**` (including the three symlinks and their
  targets' new home); `specs/**` → `ai-factory/specs/**`; `docs/adr/**` → `ai-factory/adr/**`;
  `docs/workflow.md` → `ai-factory/docs/workflow.md`.
- Code that names the directory, each a single point: `skills/ai-hooks/scripts/_common.js`
  `aiDir()` — the one detection function, and the one place AC6's fallback belongs;
  `skills/ai-layout/scripts/manifest.js` `MANIFEST` and the `SKIP` run-log pattern;
  `skills/ai-hooks/scripts/{_log-schema.js,log-flush.js,guard-paths.js}`;
  `templates/ai-factory/make/{sync-adapters.sh,ai.mk,log.js,gate.js}`;
  `skills/ai-layout/scripts/{doctor.sh,check-adapters.sh,check-doctor.sh,check-manifest.sh,check-versions.sh}`;
  `skills/ai-hooks/fixtures/check-log-schema.sh`.
- Prose and prompts that name a moved path: all eight `agents/*.md`; all twelve
  `templates/ai-factory/tasks/*.md`; `templates/ai-factory/agents/*.md`;
  `templates/ai-factory/AGENTS.md`; `templates/ai-factory/docs/*.md`;
  `templates/{AGENTS.md,CLAUDE.md,Makefile}`; this repo's `ai-factory/AGENTS.md` and
  `ai-factory/docs/*.md`; `skills/{ai-layout,ai-hooks}/SKILL.md`; all four `commands/*.md`;
  `README.md`; `.gitignore`; `.gitattributes`; `hooks/hooks.json` description.
- New: `commands/migrate-layout.md`, `skills/ai-layout/scripts/migrate-layout.sh`,
  `skills/ai-layout/scripts/check-migrate.sh`, `ai-factory/adr/0008-*.md`, one CHANGELOG entry,
  and the AC5 scan's check script (open question 1).
- Unchanged: the 16 columns of `runs/log.csv`, `models.yaml`'s keys, `plugin.json`'s `name`, the
  `t4:` prefix, the `make ai` target name, and every task prompt's behaviour.

## Routes touched
None. The surfaces are the twelve `/t4:*` task commands plus `/t4:adopt-sdlc`, `/t4:sync-sdlc`,
`/t4:doctor` and `/t4:setup-tracker`, all regenerated from the prompts by `sync-adapters.sh`
(AC10). One command is added: `/t4:migrate-layout` (AC13). None is removed. The five hook
events in `hooks/hooks.json` are unchanged; only what they detect moves (AC6).

## Components likely involved
- `skills/ai-layout/templates/` — the tree rename (AC1) and every reference in it.
- `skills/ai-hooks/scripts/_common.js` — `aiDir()`; the whole of AC6 lives here.
- `skills/ai-layout/scripts/manifest.js` — `MANIFEST`, `SKIP`, and nothing else: `walk` reads
  the templates tree, so it follows the rename on its own (AC18).
- `skills/{ai-layout,ai-hooks}/SKILL.md` — the layout inventory and the gitignore/gitattributes
  prescriptions (AC1, AC2, AC7).
- `commands/migrate-layout.md` + `skills/ai-layout/scripts/migrate-layout.sh` — the migration;
  thin prompt, script does the `git mv`, the rewrite, the adapter run and the manifest refresh,
  and owns every refusal in AC15.
- `commands/sync-sdlc.md` — the old-layout short-circuit (AC17).
- `commands/adopt-sdlc.md` — copies the template tree verbatim, so the rename needs no edit
  here; AC3 is what exercises it end to end.
- `agents/*.md` — the eight plugin agents; each names the directory it may write (AC5, AC7).
- `skills/ai-layout/scripts/check-adapters.sh` or a new sibling — the AC5/AC19 scan.
- `skills/ai-layout/scripts/check-migrate.sh` — new; fixture-driven, modelled on
  `check-doctor.sh`, which already builds synthetic repos in a temp dir (AC20).
- `skills/ai-layout/scripts/{doctor.sh,check-doctor.sh}` — the directory it looks for, plus the
  half-migrated and unmigrated reports of AC22.
- `ai-factory/docs/workflow.md`, `README.md`, `CHANGELOG.md`, `ai-factory/adr/0008-*.md` and the
  four manifests (`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
  `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`).
