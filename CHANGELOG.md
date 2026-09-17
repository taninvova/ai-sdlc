# Changelog

## 0.24.0 — 2026-09-17
- **`ai/runs/log.csv` no longer blocks `git checkout`.** The Stop hook wrote one row into the
  tracked file after every turn, so it was dirty for the whole session, every branch switch was
  refused ("Your local changes … would be overwritten by checkout"), and two branches' rows
  conflicted on merge. `session-stop.js` now appends to `ai/runs/log.pending.csv` (gitignored);
  a new PreToolUse Bash hook, `log-flush.js`, moves those rows into `log.csv` and stages it when
  the session runs `git commit` — and only then; a dry run or any other command leaves them.
  The log changes inside the commit that produced the work, which is where the `accepted`
  column was always meant to be filled.
- `make log-flush` does the same move for a commit made from a terminal; rows never flushed
  simply wait for the next commit.
- The schema guard moved out of `session-stop.js` into `scripts/_log-schema.js`, required by
  both plugin-side scripts. The headless writer keeps its byte-identical copy;
  `check-log-schema.sh` now diffs against the module, asserts the Stop hook carries no copy of
  its own, and gains the flush cases: not on `git status`, not on `--dry-run`, once per commit,
  staged, and a pre-schema `log.csv` migrated when the flush reaches it.
- Adopted repos: add `ai/runs/log.pending.csv` to `.gitignore` and `ai/runs/log.csv merge=union`
  to `.gitattributes` (both listed in the ai-hooks skill; `/t4:adopt-sdlc` step 5 writes them
  for a new repo). Until the plugin is updated and the session restarted, the old hook keeps
  writing straight into `log.csv`.

## 0.23.0 — 2026-09-07
- **The plugin's own repo is recognised again once the plugin is installed.** `isPluginItself`
  compared repo-root to plugin-root, which is only equal while the plugin runs from its working
  tree. Installed, plugin-root is the cache, the paths differ, and the source repo looked like
  an ordinary adopter. Both `manifest.js` and `/t4:doctor` now test identity — a repo carrying
  this plugin's own name in its own `plugin.json` **is** this plugin — and keep the path
  comparison as the fast case.
- **What that cost, found by running `/t4:doctor` for the first time from a real install:** it
  reported "no `ai/.sdlc.json` — start a baseline" in the plugin's own repo, and following that
  advice wrote a manifest into it. `check-manifest.sh` asserts that never happens; the invariant
  was intact and the test could not see the case, because it passed the same path for both
  arguments.
- Both tests now cover the installed shape: `check-manifest.sh` runs `write` with the plugin
  copied elsewhere, and `check-doctor.sh` gains a ninth case for the same. Each verified by
  reverting its fix and watching the suite fail.
- `check-manifest.sh` cleans up in its trap rather than inline. A failing assertion exits before
  any cleanup after it, so the test that provoked a manifest into this repo was leaving it there
  — a test that fails dirty makes the next run's result meaningless.

## 0.22.0 — 2026-09-07
- **`/t4:doctor` now says when your install is behind.** It compared a repo against whichever
  plugin it was handed and never looked at whether that plugin was current, so a repo could be
  perfectly in step with an install several releases old and report entirely green. That is the
  exact invisible state the command exists for, and it was blind to it. `specs/0002` AC13.
- **It compares against the marketplace copy already on disk, not the remote**, and says so in
  the message. "Behind what you have fetched" is a smaller claim than "behind the world", it
  needs no network, and conflating the two would make the command lie on a stale clone.
  `specs/0002` AC14.
- Version comparison is numeric per component, not lexical. The fixture uses 0.9.0 against
  0.10.0 for that reason: a string comparison calls 0.9.0 the newer, and would have reported a
  behind install as current. Verified by replacing the comparison with `<` and watching the
  fixture fail.
- `check-doctor.sh` is now eight cases, adding update-available, up-to-date, and no-marketplace.
- `specs/0001` AC4 and AC5 said the session "asks how to proceed" when a key does not resolve.
  Impossible on the path AC4 itself names — `make ai` runs with no session behind it — so both
  now say report and write nothing, asking only where there is someone to ask. Wording only;
  the behaviour has been report-and-stop since 0.19.0.

## 0.21.0 — 2026-09-07
- **`/t4:setup-tracker`** — points a repo at a tracker and proves it, so turning `specs/0001`
  on no longer means knowing a filename, a key and its exact shape from reading a design
  document. Detects the reachable site, shows it, asks before writing, writes `base_url` and
  nothing else, then resolves one key to demonstrate the result works. Implements
  `specs/0003-tracker-setup.md`.
- **It refuses before it reads or writes.** No `ai/docs/tracker.md` means the layout predates
  tracker support, and it will not create that file — it is a template, and a local copy would
  fork from the one that ships. A non-interactive run stops rather than proceeding on assumed
  answers: a config written from guesses is worse than none, because the repo then looks
  configured.
- **It will not silently replace an existing `ai/jira.yaml`.** That file is hand-owned and
  deliberately outside `dont-touch.md`, so a second confirmation is required and the current
  contents are shown first.
- **Committing it is a choice, and the cost of not committing is stated when you make it.**
  Choosing `.gitignore` leaves the repo configured for one developer: a teammate who clones it
  gets the unconfigured behaviour, so `/t4:spec ABC-12` means different things to different
  people on one team. That is allowed; being surprised by it is not.
- **Writing the file is not evidence it works.** With a key it resolves one and reports what
  came back; with none it says the configuration is unverified and names what would verify it.
- **Nothing is written to the tracker** — checked against a real ticket rather than asserted:
  comments, status, resolution, labels and the `updated` timestamp all unchanged after the
  work, the timestamp being the one Jira moves on any field write.
- **Not yet proved:** the unreachable-tracker path (`specs/0003` AC4). Every other criterion
  ran. That one needs a session where the connector is unavailable, and manufacturing it costs
  a re-authorisation, so it waits for a session already in that state.

## 0.20.0 — 2026-09-07
- **`/t4:doctor`** — one read-only command that reports what is wrong with a repo's setup and
  the command that fixes each thing. Layout, adapters against tasks, the version the repo
  records against the one the session loaded, drift, where the plugin is installed, and whether
  older cached copies are still around. Implements `specs/0002-t4-doctor.md`.
- **It never fixes anything, and that is the point.** Every remedy is a command you run. Being
  read-only is what makes it safe as the *first* thing you try, before you know what is wrong —
  and it always exits 0, so it stays usable in CI. A doctor that fails the build when it finds
  something is a doctor nobody runs.
- **It reports the two things that are hardest to work out by hand:** a plugin installed for a
  different project than the one you are in, and older cached copies that a session which has
  not restarted may still be running. Both took several rounds of manual digging to identify
  while building the tracker work; both are now one line each.
- **The one thing it cannot report is in `docs/workflow.md` instead.** If `/t4:doctor` does not
  exist in a repo, the plugin is not enabled there — and no command can say so, because in that
  repo none of them are there to run. Its absence is the diagnosis.
- Names are read from the plugin's own manifest rather than hardcoded, because this plugin and
  its marketplace have each been renamed more than once; a check pinned to a literal handle
  would have been wrong three renames ago.
- `check-doctor.sh` covers five cases — no layout, no manifest, behind the templates, healthy,
  and no config directory at all — each verified by breaking the doctor rather than by passing.
- **Known gap, recorded in `ai/plans/0002`:** the doctor compares a repo against the plugin it
  was handed and never says a newer release exists. A repo pinned to an older install therefore
  reports green while a newer version sits published. Closing it needs a new acceptance
  criterion, not a quiet addition.

## 0.19.0 — 2026-09-07
- **`/t4:spec` can draft from a tracker ticket.** In a repo that has committed `ai/jira.yaml`,
  `/t4:spec ABC-12` resolves the key and specs the ticket, recording it as a vendor-neutral
  `Ticket: ABC-12` line under the title so later work can find its way back. Implements
  `specs/0001-spec-accepts-a-ticket-key.md`; decided in `docs/adr/0004`, `0005` and `0006`.
- **Off unless you turn it on, and the gate is configuration — never the shape of what you
  typed.** A repo with no `ai/jira.yaml` behaves exactly as it did before: `/t4:spec UTF-8`
  specs UTF-8. That matters because `UTF-8`, `ISO-8601` and `RFC-7231` all match a ticket-key
  pattern end to end, so keying off the argument would have made a repo with no tracker stop
  and ask about a ticket that cannot exist.
- **A repo without a tracker cannot tell this shipped — including from what the session says.**
  The first real run failed exactly there: the artefact was right, but the report announced
  that `ai/jira.yaml` was missing, which told a repo that had configured nothing that a
  mechanism existed. A report is output. `argument-hint` is unchanged for the same reason: the
  command menu is output too.
- **Criteria come from the ticket's description and nothing else**, and what the description
  leaves implicit becomes an Open question rather than an invented Given/When/Then. Proved
  against a real ticket whose entire description was one sentence: one criterion, nine open
  questions. Eight plausible criteria would have looked more useful and been a fabrication.
- **New template: `ai/docs/tracker.md`** — the one file allowed to name a vendor, a connector,
  a URL or a config filename. `check-adapters.sh` now fails if any of those reach a task prompt
  or a generated command.
- **`ai/jira.yaml` is deliberately not in `dont-touch.md`.** Everything on that list is
  generated or secret; this is hand-written config a developer must author, and the guard
  blocks edits outright — listing it would stop a session creating the file that turns the
  feature on.
- **Nothing writes to a tracker.** `docs/adr/0006` allows comments and gates transitions behind
  a seam arm that does not exist yet; neither is built. Setup and resolution read only.
- **Blast radius: every adopted repo**, on its next sync, receives `ai/docs/tracker.md` and
  gains nothing else until it writes `ai/jira.yaml`. Outside Claude Code — Codex, and headless
  `make ai` — a key cannot be resolved at all until `ai/make/jira.sh` exists, and the task
  stops and says so rather than guessing.

## 0.18.0 — 2026-09-07
- **`make ai` never ran a task under `claude`.** `ai.mk` passed the prompt as an argument —
  `claude -p "$(cat $PF)"` — and every task file opens with YAML frontmatter, so the CLI read
  `---` as an option and exited before starting. The prompt now goes in on stdin, which is
  what the Codex branch has always done. Found by running the acceptance criteria of
  `specs/0001` for real; reproduced with `chore`, so it was never specific to one task.
- **And it reported that failure as success.** The recipe ran on regardless: it printed
  `run saved`, appended a row to `ai/runs/log.csv` for a run that never happened, and exited
  0. CI would have gone green on an empty file. `make ai` now exits non-zero when the tool
  fails or writes nothing, says how many bytes it got, and logs no row — a failed run is not
  a run. `make review` inherits this, since it chains on `&&`.
- **Blast radius: every adopted repo, but not automatically.** `ai/make/ai.mk` is a template,
  and `/t4:sync-sdlc` regenerates adapters without touching `ai/`, so a repo keeps its broken
  copy until it takes the drift the sync reports. Any repo relying on `make ai` or
  `make review` in CI should take this one.

## 0.17.0 — 2026-09-07
- **`/t4:step` is now `/t4:run`.** `ai/tasks/step.md` becomes `ai/tasks/run.md`; the task
  itself is unchanged. Breaking for anyone with the old command in a script or a habit.
- The word "step" stays everywhere it means a step *within* a plan, which is most places:
  the description is still "Implement one step of a plan", the argument hint is still
  `<plan path> <step>`, and `/t4:plan` still writes `- [ ] Step N — …`. Only the command
  moved. Two sentences were reworded to avoid "`/t4:run` run".
- Past CHANGELOG entries keep saying `/t4:step`, unlike the org and plugin renames where
  the records were rewritten. Rewriting here would turn "tasks renamed explore, step, fix,
  check" in the 0.5.0 entry into a claim about a rename that happened today, and "step" is
  an ordinary word in those sentences rather than a name being retired.
- The stale `step` adapters were removed by the sync fix shipped in 0.16.0 — first real
  exercise of it.

## 0.16.0 — 2026-09-07
- **Sync removes the commands it generated under older naming.** Cleanup matched
  `ai-<task>.md` and `t4/<task>.md` only, so a repo adopted before 0.5.0 kept its bare
  `.claude/commands/spec.md` through every sync and answered both `/spec` and `/t4:spec` —
  the same task twice, under two names, one of them pointing at a task file that may no
  longer exist. Found in a repo scaffolded at ai-base 0.1.2.
- **Ours is identified by the include, not by the name.** A generated command carries
  `@../../ai/tasks/<name>.md`; a hand-written one does not. Matching on that is what makes
  deleting safe — a name glob wide enough to catch `spec.md` would also delete a command
  someone wrote themselves and called `spec.md`. Codex skills are matched the same way, by
  the `ai/tasks/` path in the skill body.
- Pinned by a test that reproduces the case: a pre-0.5.0 bare command, a 0.5.0-era `ai-`
  command and a stale codex skill must all go, and a hand-written `spec-of-mine.md` must
  survive. Verified by restoring the old glob, which fails it.

## 0.15.0 — 2026-09-07
- **The marketplace is `sdlc`; the handle is `t4@sdlc`.** A handle reads
  `<plugin>@<marketplace>`, so this renames the marketplace only. The plugin stays `t4` —
  its name is what makes the commands `/t4:`, and renaming it would take them with it.
  0.13.0 had both called `t4`, which worked but read as a stutter and hid which half meant
  what.
- The marketplace now matches the git project it is served from, `ai/sdlc.git`, so the name
  in the manifest and the name in the URL finally agree.
- Unchanged: the org is still `t4 platform`, the plugin is still `t4`, the repo is still
  `ai-sdlc`, and `/plugin marketplace add git@gitlab.nsix.io:ai/sdlc.git` is the same line
  as before. Only the handle's right-hand side moved.
- The 0.13.0 entry's claim that "plugin and marketplace share a name" was left in place as a
  sentence but is no longer true, so it is removed there rather than left to mislead.

## 0.14.0 — 2026-09-07
- **A task that needs input now asks for it.** Every task ended with a label — `Feature:
  $ARGUMENTS`, `Bug: $ARGUMENTS` — and an empty invocation left a dangling colon, which a
  session fills in by guessing: a feature inferred from the branch name, a bug it went
  looking for, the newest spec assumed to be the one you meant. The nine tasks that require
  input now say what to do when they get none, and say it specifically — `/t4:plan` lists the
  paths in `specs/` rather than assuming the newest, `/t4:step` names the unticked steps
  rather than starting one.
- **`/t4:check` and `/t4:fleet` deliberately do not ask.** Both work with no argument by
  design — check reviews the branch diff, fleet maps the whole repo — so a prompt would be an
  obstacle rather than a safeguard. Their input is marked optional with brackets instead.
- **`argument-hint` reaches the command menu.** Each task declares one and
  `sync-adapters.sh` copies it into the generated command, so the expected input is visible
  before running rather than discovered by running. A task with no hint gets no empty one.
- Two assertions pin this, both verified by breaking them: a task whose hint says it takes
  input must carry the prompt, and the generated command's hint must match its task's. The
  first catches a task that gains an argument without gaining the question; the second
  catches a generator that quietly stops propagating.
- Codex needs no separate handling — its skills point at `ai/tasks/<name>.md` rather than
  copying it, so the prompt arrives with the task.

## 0.13.0 — 2026-09-07
- **Every command lives under `/t4:`.** The eleven project tasks become `/t4:spec`,
  `/t4:plan`, `/t4:step` and so on; the plugin's two become `/t4:adopt-sdlc` and
  `/t4:sync-sdlc`. Reinstall with `/plugin install t4@sdlc`.
- **The plugin is named `t4`.** That is not cosmetic: a plugin's command namespace *is* its
  name, so `/t4:adopt-sdlc` is only reachable by renaming the plugin. The repo stays
  `ai-sdlc`.
- **The project commands are namespaced by directory, not by prefix.** `sync-adapters.sh`
  now writes `.claude/commands/t4/<task>.md` instead of `.claude/commands/ai-<task>.md`,
  because a subdirectory under `.claude/commands/` is what Claude Code reads as a namespace.
  That puts the generated file one level deeper, so its `@` include needed another `../` —
  a wrong depth still generates a perfectly valid-looking command that silently includes
  nothing, so `check-adapters.sh` now resolves every include and asserts it lands on the task
  file. Verified by reverting the depth: it fails.
- **Codex skills read `t4-<task>`, not `t4:<task>`.** Codex skill names are invoked as
  `/name` and take no colon, so the two tools differ here by necessity: `/t4:spec` under
  Claude Code, `/t4-spec` under Codex.
- **`/t4:explore` is now project-only.** The plugin shipped its own `explore` for repos with
  no `ai/` layout, and under one namespace it collided head-on with the task of the same
  name. The plugin copy is removed and the project one keeps the plain verb, so exploring a
  repo now requires adopting the layout first — the one capability this release drops.
  `README.md` and `docs/workflow.md` no longer offer it.

## 0.12.0 — 2026-09-07
- **The plugin is `ai-sdlc` again, not `sdlc`.** Breaking twice over: the handle is now
  `ai-sdlc@t4`, and every command moves namespace — `/sdlc:adopt` `/sdlc:explore` `/sdlc:sync`
  become `/t4:adopt-sdlc` `/t4:explore` `/t4:sync-sdlc`. Reinstall with
  `/plugin install ai-sdlc@t4`. This undoes the rename made in 0.5.0; plugin and repo name
  now agree again.
- The eleven project commands are untouched — they are generated from `ai/tasks/` into each
  repo and were already `/ai-*`, never namespaced by the plugin.
- **`ai/.sdlc.json` keeps its name.** The drift manifest is plumbing, not the handle, and
  every adopted repo already has one; renaming it would make `manifest.js` miss the file and
  report a fresh repo, silently losing each repo's drift baseline. The prose around it now
  says ai-sdlc while the filename does not — a deliberate seam, not an oversight.
- The git remote is unchanged: `git@gitlab.nsix.io:ai/sdlc.git`. The GitLab project keeps
  the short name; only the plugin was renamed.
- Records were rewritten rather than left standing, matching the choice made for the org
  rename in 0.11.0. Two entries now assert things that were never true, and are left that
  way knowingly: 0.5.0 reads "Plugin renamed `ai-sdlc`" when it was in fact renamed *from*
  that to `sdlc`, and 0.11.0 offers `ai-sdlc@n6` and `ai-sdlc@t4`, handles that did not
  exist at the time it describes. History here records the current naming, not the naming
  in force on the day.

## 0.11.0 — 2026-09-07
- **The marketplace is now `t4`, not `n6`.** Breaking for anyone who installed by handle:
  `ai-sdlc@n6` no longer resolves. Re-point with `/plugin marketplace remove n6`, then
  `/plugin marketplace add git@gitlab.nsix.io:ai/sdlc.git` and `/plugin install ai-sdlc@t4`.
  The git remote is unchanged — only the marketplace handle and the org name moved.
- The rename is total: manifests, install instructions, the owner and author fields, the
  LICENSE holder, and the earlier changelog entry that named the old org. Outside this entry
  the old name survives nowhere, which is what a straight org rename calls for. Two things
  that follow from it and are easy to miss: rewriting the earlier entry edits a record of
  what was true at the time rather than noting a change on top of it, and this entry has to
  keep naming the old handle, because migration instructions are useless without it.

## 0.10.0 — 2026-09-07
- **The log guard measures every row, not just the header.** 0.7.0 moved a log.csv aside when
  its header was not the current one, which catches a file that predates the schema but not a
  writer that appends into a current one. An older hook still installed elsewhere kept writing
  12-field rows under the 16-field header for an entire session, and nothing noticed: the
  header it was checked against still matched. Both writers now check each row's width and move
  only the rows that fail, under a dated comment saying why. Rows are still never reinterpreted
  into the new columns — width cannot say which writer produced a row, and guessing is what
  caused the mixed-schema bug in the first place.
- **Field counting is quote-aware.** `csv()` quotes any value holding a comma or a newline, so
  counting commas would have quarantined a valid row whose `user` is `"Doe, Jane"`, and torn a
  row with an embedded newline into two malformed halves. Records are split on quote state and
  an unclosed quote is treated as unmeasurable rather than counted as some width.
- The guard is duplicated in both writers for the same reason `HEADER` is — they run from
  different places and cannot share a module — so `fixtures/check-log-schema.sh` now diffs the
  two copies and fails on drift. Three new cases cover a short row under a matching header, a
  quoted comma surviving, and the headless writer guarding the same way. Each was verified to
  fail with the guard removed, the quote handling removed, and the copies drifted — not just
  to pass today.

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
- **Layout drift detection.** `/t4:adopt-sdlc` now writes `ai/.sdlc.json` recording which ai-sdlc
  version a repo received and a hash per file; `/t4:sync-sdlc` compares it against the installed
  templates and reports six states — upstream changed (safe to take), both changed (merge by
  hand), locally modified, new upstream, removed upstream, missing locally — plus a version
  comparison. Before this an adopted repo had no way to learn it was behind, and `/t4:sync-sdlc`
  regenerated adapters without comparing anything. Implements
  `ai/designs/0001-layout-version-and-drift.md`; decisions in `docs/adr/0001`-`0003`.
- **Two hashes per file, not one.** The design sketched a single hash, which cannot work:
  adopt substitutes `{{app}}`, `{{stack}}` and friends, so a repo file never equals its
  template and every substituted file would report as modified forever. The manifest records
  `received` (what landed in the repo) and `template` (what it came from).
- `/t4:sync-sdlc` still changes nothing under `ai/` — it reports, and taking an upstream change
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
- No t4-specific configuration remains in the templates: the AGENTS.md setup section names
  no provider, and `ai/docs/architecture.md` no longer claims a LiteLLM proxy resolves aliases.

## 0.5.1 — 2026-09-06
- **Standalone.** The plugin names, reads and version-pins no other repo. There was never a
  functional dependency — no package manager, lockfile, submodule or out-of-repo path, and
  the hooks use the Node standard library only — but eight documents named the framework
  scaffold repos and pinned their versions, most of it written into `ai/docs/fleet.md` by
  the first `/t4:fleet` run reading sibling checkouts off disk. Consumers are now described
  generically: overlay plugins and adopted repos, named nowhere.
- `ai/docs/fleet.md` is scoped to this repo alone, its **Consumes** column deliberately
  empty, with the one-way dependency written into Boundaries so `/t4:design review` enforces
  it on future plans.

## 0.5.0 — 2026-09-06
- New `architect` agent: decides where a capability belongs across services, what contract
  it exposes and who owns the data. Writes design docs and ADRs only — never source, specs
  or plans; changes to other context docs are proposed as replacement text, not applied.
- New `/t4:design`: the capability's home, its contracts and its data ownership, before any
  spec. Output in `ai/designs/`, ending with the `/t4:adr` and `/t4:spec` lines to run.
  `/t4:design review <plan>` checks a plan for architectural fit and emits the same JSON
  shape the reviewer does, so `ai/make/gate.js` reads it unchanged.
  Use it only when a capability spans services or changes a contract between them —
  `/t4:explore` still decides how to build a feature inside one repo.
- New `/t4:adr`: writes `docs/adr/NNNN-slug.md`. Three documents already required an ADR for
  every new dependency and nothing in the loop produced one; now something does.
- New `ai/docs/fleet.md` — the service map the architect reads — and **`/t4:fleet`, which
  fills it in**: it detects what it can from the repo (remotes, manifests, compose and k8s
  files, routes, queue names, CODEOWNERS) and asks you for the rest, offering what it
  detected as the default. It refreshes rather than overwrites, and asks nothing in a
  non-interactive `make ai` run. The map ships scoped to the project with this repo as its
  only row.
- Definition of done gains item 7: a change crossing a service boundary or changing a
  contract has a design doc, an ADR, and an up-to-date fleet map.
- New overlay slot `{{fleet_extra}}`.
- **Adopted repos: run `/t4:sync-sdlc` for the three new commands, then `/t4:fleet` once** —
  until it runs, `ai/docs/fleet.md` is the unfilled default and `/t4:design` will say so.

## 0.4.0 — 2026-09-06
- New `tester` agent and `/t4:test` task: writes acceptance tests from the spec's ACs,
  reading the implementation's public surface only and never the diff, so tests are not
  shaped by the code they check. Modes `red` (before `/t4:step`, ACs must fail first) and
  `gaps` (after, close uncovered ACs). Writes test files only; never production code.
- Loop is now `/t4:explore → /t4:spec → /t4:plan → /t4:test red → /t4:step → /t4:test gaps → /t4:check`.
- `sync-adapters.sh`: `shopt -s nullglob` — a repo with no `ai/skills/*/` subdirectory
  previously created a directory literally named `.claude/skills/*`. Agent symlinks now
  loop over `ai/agents/*.md` instead of hardcoding the reviewer, so a new agent needs no
  script change. **Adopted repos should run `/t4:sync-sdlc`.**
- Definition-of-done item 2 now names `/t4:test` as the source of AC tests.
- ai-sdlc adopts its own `ai/` layout, symlinked to `skills/ai-layout/templates/`.

## 0.3.0 — 2026-09-06
- Plugin renamed `ai-sdlc` (repo stays ai-sdlc). Commands: `/t4:adopt-sdlc` (was init), `/t4:explore` (was investigate), `/t4:sync-sdlc`.
- Project commands now prefixed `ai-`: `/t4:explore /t4:spec /t4:plan /t4:step /t4:fix /t4:chore /t4:check` (tasks renamed explore, step, fix, check; `/review` collided with a Claude Code built-in). `ai/investigations/` → `ai/explorations/`.

## 0.2.0 — 2026-09-06
- Renamed from ai-base and split: Next.js pieces moved to the nextjs-scaffold plugin; NestJS lives in nestjs-scaffold.
- New `/t4:explore` command + task: 2–4 implementation options with trade-offs before a spec; output in `ai/explorations/`.
- New `/t4:adopt-sdlc` command: add the ai/ layout to an existing repo without a framework scaffold.
- `/ai-sync` renamed `/t4:sync-sdlc`; guards against repos without `ai/`.
- Generic templates are framework-neutral with `{{…_extra}}` slots overlays fill.

## 0.1.2 / 0.1.1 / 0.1.0 — 2026-09-05 (as ai-base)
- Initial layout, hooks, reviewer; skills hidden from the slash menu; sync guard.
