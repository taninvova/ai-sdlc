# 0006 — live runs, for the MR

Three real headless Claude Code sessions, the plugin loaded from this working tree:

```
claude -p "/t4:<command>" --plugin-dir <this repo> --output-format stream-json --verbose --dangerously-skip-permissions
```

The raw stream-json transcripts are not committed — `ai-factory/runs/*.jsonl` is gitignored and they
come to ~490 KB. What each session reported is below, verbatim and trimmed, which is what a reviewer
needs. Definition of done item 2.

## 1. `/t4:adopt-sdlc --owner dev` in a repo with no layout

A small Node library (package.json, src/csv.js, README). Proves AC3.

`30 turns · 173s · exit 0`

```
The ai-sdlc layout is in place. `ai-factory/` did not exist beforehand, so adoption ran clean.

## Detected stack

`package.json` (`csv-tools` 0.1.0), JS source in `src/`, no lockfile → npm:

| | |
|---|---|
| build | `npm run build` (tsc) |
| lint | `npm run lint` (eslint .) |
| typecheck | `npm run typecheck` (tsc --noEmit) |
| test | `npm test` (node --test) |

## Files created

**Root** — `AGENTS.md` ("See ai-factory/AGENTS.md"), `CLAUDE.md` ("@ai-factory/AGENTS.md"), `Makefile`, `.gitignore`, `.gitattributes`

**`ai-factory/`** — 42 files: `AGENTS.md` contract, `models.yaml`, 7 context docs (`architecture`, `fleet`, `coding-standards`, `definition-of-done`, `dont-touch`, `knowledge`, `tracker`), 12 task prompts, 8 agents, `adr/0000-template.md`, `specs/0000-scaffold.md`, `make/` (`ai.mk`, `gate.js`, `log.js`, `sync-adapters.sh`), `runs/log.csv` with the 16-column header, and empty `analyses/ designs/ explorations/ plans/done/ skills/`.

**Adapters** (generated, never hand-edit) — `.claude/commands/t4/` ×12, `.claude/agents/` ×8 symlinks, `.codex/skills/t4-*` ×12, `.cursor/rules/ai.mdc`.

**`ai-factory/.sdlc.json`** — records ai-sdlc 0.27.1 and 38 tracked file hashes. `manifest.js check` reports up to date; `doctor.sh` reports layout, adapters, version and drift all ok.

## Two things to flag

1. **The Makefile deviates from the template.** The template recipes call `pnpm lint/test/e2e`; this repo is npm and has no `e2e` script, so `make check` is `lint typecheck test review` on npm. The manifest recorded the edited file, so this is not drift.
2. **`npm run lint` / `bui
```

## 2. `/t4:migrate-layout` — refused

A repo adopted at 0.27.1. Serena had created .serena/ during the session, so the tree was dirty. Kept because the refusal, and the session declining to work around it, is the evidence.

`3 turns · 15s · exit 0`

```
**The migration refused. Nothing was moved or rewritten.**

Its output, as-is:

`​``
migrate-layout: the working tree has uncommitted changes. Commit or stash them first: this move touches every prompt in the repo, and it is only reviewable as a commit of its own.
`​``

The dirt is a single untracked directory:

`​``
?? .serena/
`​``

That's a Serena MCP scratch directory, not repo content — it appeared during this session, after the clean snapshot at session start. Deciding what happens to it is yours, not mine, so I've stopped here. The options are to gitignore it, delete it, or commit it; once the tree is clean, re-run:

`​``
bash "/Users/tanin/code/nsix/ai/sdlc/skills/ai-layout/scripts/migrate-layout.sh"
`​``
```

## 3. `/t4:migrate-layout` — the move

The same repo with the tree clean. Proves AC14 and, after the two commits, AC18.

`3 turns · 25s · exit 0`

```
Script output, verbatim:

`​``
migrate-layout: done. Nothing has been committed — review and commit this as its own change.

moved (4):
  ai/ -> ai-factory/
  specs/ -> ai-factory/specs/
  docs/adr/ -> ai-factory/adr/
  docs/ (empty, removed)

rewritten — path strings only, no new prompt text (36):
  .gitattributes
  .gitignore
  AGENTS.md
  CLAUDE.md
  Makefile
  ai-factory/AGENTS.md
  ai-factory/adr/0001-queue-choice.md
  ai-factory/agents/analyst.md
  ai-factory/agents/architect.md
  ai-factory/agents/explorer.md
  ai-factory/agents/implementer.md
  ai-factory/agents/planner.md
  ai-factory/agents/reviewer.md
  ai-factory/agents/specifier.md
  ai-factory/docs/coding-standards.md
  ai-factory/docs/definition-of-done.md
  ai-factory/docs/dont-touch.md
  ai-factory/docs/knowledge.md
  ai-factory/docs/tracker.md
  ai-factory/make/ai.mk
  ai-factory/make/log.js
  ai-factory/make/sync-adapters.sh
  ai-factory/models.yaml
  ai-factory/plans/0001-csv-export.md
  ai-factory/specs/0000-scaffold.md
  ai-factory/specs/0002-scheduled-reports.md
  ai-factory/tasks/adr.md
  ai-factory/tasks/analyse.md
  ai-factory/tasks/chore.md
  ai-factory/tasks/design.md
  ai-factory/tasks/explore.md
  ai-factory/tasks/fix.md
  ai-factory/tasks/fleet.md
  ai-factory/tasks/plan.md
  ai-factory/tasks/run.md
  ai-factory/tasks/spec.md

adapters regenerated; ai-factory/.sdlc.json refreshed.

Commit it as TWO commits, in this order — that is what keeps file history:
  git commit -m 'ai(chore): move the layout to ai-factory/ (paths unchanged)'
  git add -A && git commit -m 'ai(chore): point the prompts at 
```

## Verified after the runs

- **AC3** — only `ai-factory/` plus `AGENTS.md`, `CLAUDE.md`, `Makefile` arrived; no top-level `ai/`,
  `specs/` or `docs/`; the manifest tracks 38 files, none naming the old layout; 12 Claude commands,
  12 Codex skills, 1 Cursor rule; `make -n ai TASK=spec` resolves the include.
- **AC14** — 4 paths moved, 36 files rewritten, nothing committed, moves staged and rewrite unstaged,
  and the hand-edited paragraph in `ai/tasks/spec.md` survived with its paths rewritten.
- **History** — after the two commits the command prints, `git log --follow` reaches the original
  commit for the AGENTS, spec, ADR and plan files.
- **AC18** — `manifest.js check` afterwards: "up to date — every tracked file matches."
