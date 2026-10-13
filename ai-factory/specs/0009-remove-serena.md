# 0009 — Remove `.serena`

Summary: take the untracked `.serena/` directory out of this repo's working tree.

The request is two words, and most of what an implementer needs to know is not in them. What
follows records exactly what is asked, and moves everything the phrase leaves open — whether the
`.gitignore` lines go too, whether Serena should stop being used here at all, whether the
directory simply reappears — into Open questions. The spec is not buildable until they are
answered.

## What is there today
Facts, established by reading the repo:

- `.serena/` sits at the root of `ai/sdlc`. It holds `.gitignore`, `project.yml`,
  `project.local.yml`, an empty `memories/` and an empty `cache/typescript/`.
- **Nothing under it has ever been tracked.** `git ls-files` returns no path under `.serena/`,
  and the directory does not appear in `git status` because `.gitignore` line 21 ignores it.
- `.gitignore` lines 18–21 are a three-line comment and the `.serena/` rule. The comment states
  the standing decision: running Serena is a personal choice, the directory regenerates on
  activation, so nothing is lost by not sharing it — "local decision, not a pattern for adopters".
- `.serena/` is **not** among the gitignore lines `skills/ai-hooks/SKILL.md` prescribes for every
  repo, so `skills/ai-layout/scripts/check-entrypoints.sh` does not assert it. No check reads it.
- No code in this repo reads, writes or names `.serena/`. The only other mentions are historical:
  `ai-factory/plans/done/0006-ai-factory-layout.md` (lines 148, 177) and
  `ai-factory/runs/0006-live-runs.md` (lines 51, 67, 70), which record a run that the directory's
  sudden appearance blocked. `ai-factory/runs/` is on `ai-factory/docs/dont-touch.md`.
- Nothing in this repo configures the Serena MCP server — there is no `.mcp.json`. The server is
  attached at the developer's level, outside the repo, and the repo cannot turn it off.
- `ai/sdlc` is the only repo in the workspace with a `.serena/`.

## User story
As a developer working in `ai/sdlc`, I want `.serena/` gone from the repo, so that the working
tree holds only files this repo owns.

## Acceptance criteria

- **AC1** Given `.serena/` exists at the repo root, When the change is applied, Then no path
  under `.serena/` exists in the working tree — `test -e .serena` fails.
- **AC2** Given no path under `.serena/` has ever been tracked, When the change is applied, Then
  the commit records no deletion of a tracked file under `.serena/`, and `git log -- .serena`
  stays empty. The removal is a working-tree deletion, not a `git rm` of repo content.
- **AC3** Given the repo's own checks, When every `check-*.sh` under
  `skills/ai-layout/scripts/` and `skills/ai-hooks/fixtures/` is run directly after the change,
  Then each exits 0 — `check-entrypoints.sh` in particular, which reads `.gitignore` and must
  still find the five lines `skills/ai-hooks/SKILL.md` prescribes.
- **AC4** Given the change is applied, When the branch diff is read, Then `.gitignore` is the only
  tracked file that differs, and it differs only if Open question 2 says it should.
  `ai-factory/plans/done/0006-ai-factory-layout.md` and `ai-factory/runs/0006-live-runs.md` are
  byte-identical: they are the record of a past run, and the second is under dont-touch.
- **AC5** Given a session in this repo after the change, When no Serena tool is called, Then
  `.serena/` does not reappear and `git status` stays clean. What happens when one *is* called is
  Open question 1, not a criterion here.

## Out of scope
- **Editing the historical mentions.** The two files that name `.serena/` describe what happened
  during the 0006 run and stay as written; one of them is on `ai-factory/docs/dont-touch.md`.
- **Anything in the templates.** `.serena/` was never prescribed to an adopting repo, so nothing
  under `skills/ai-layout/templates/` or `skills/ai-hooks/SKILL.md` is in play, and no adopted repo
  is affected. No CHANGELOG entry and no manifest version bump follow from this.
- **Other repos in the workspace.** No sibling repo has a `.serena/`; see Open question 3 before
  widening.
- **The developer's Serena MCP configuration.** It lives outside this repo (see Open question 5).

## Open questions
None of these is answered by the request. The spec is not buildable until they are.

1. **Does "remove" mean delete the directory, or stop using Serena here?** The Serena MCP server
   is attached to the developer's session and recreates `.serena/` on activation. A deletion alone
   is undone the next time anyone calls a Serena tool in this repo, which is precisely the
   situation `ai-factory/runs/0006-live-runs.md` records. If the intent is that it stays gone, that
   needs a mechanism this spec does not have, and the repo may not be able to supply one.
2. **Do `.gitignore` lines 18–21 go with the directory?** The three-line comment and the
   `.serena/` rule are independent of the directory's existence. Keeping them is the only thing
   that keeps the tree clean if question 1 is answered "delete it locally"; removing them makes a
   regenerated `.serena/` show up as untracked in every `git status` from then on. Both readings
   fit "remove `.serena`".
3. **Is `ai/sdlc` the whole scope?** `ai/sdlc` is its own git repo; the workspace root is not one and
   carries no `.gitignore` rule for Serena. Today only this repo has a `.serena/`. Should the
   answer to question 2 be written anywhere above this repo, or is this a one-repo change?
4. **Is anything in `.serena/` wanted before it goes?** `memories/` and `cache/typescript/` are
   empty and `project.local.yml` is comments only, so nothing is lost today. `project.yml` does
   carry settings for this repo — `project_name: "sdlc"`, `language_servers: [typescript]`,
   `ignore_all_files_in_gitignore: true` — and whether those choices should be preserved anywhere
   before deletion is unstated.
5. **Should the Serena MCP server be detached from this project entirely?** That configuration is
   the developer's, not the repo's, so it cannot be changed from here — but it is what decides
   whether question 1's answer holds. Naming who does it, and where, belongs in the answer.

## Data touched
No model, no field, no schema. `.serena/` is untracked scratch state that no code in this repo
reads. The files removed are `.serena/.gitignore`, `.serena/project.yml`,
`.serena/project.local.yml`, `.serena/memories/` and `.serena/cache/typescript/`.
`.gitignore` lines 18–21 are the one tracked file possibly touched — pending Open question 2.

## Routes touched
None. This repo exposes no routes; no command, skill, hook or `/t4:*` surface changes.

## Components likely involved
None of the plugin's code. `skills/ai-layout/scripts/check-entrypoints.sh` reads `.gitignore`, but
asserts only the lines `skills/ai-hooks/SKILL.md` prescribes — `ai-factory/runs/*.json`,
`ai-factory/runs/*.jsonl`, `ai-factory/runs/log.pending.csv`, `.claude/settings.local.json`,
`CLAUDE.local.md` — none of which is the Serena rule. `ai-factory/docs/dont-touch.md` governs
`ai-factory/runs/0006-live-runs.md`, one of the two files that must not move.
