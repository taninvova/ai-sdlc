# Using the ai-sdlc plugin

How to install it, what each command is for, and the order to run them in.

The plugin gives you three things: an `ai-factory/` directory in your repo that holds the project's
context and prompts, slash commands generated from it, and eight agents. Everything a command
does is written in a file you can read and change — `ai-factory/tasks/<name>.md`. If a command keeps
needing steering in chat, the prompt is missing a line; fix the prompt, don't repeat yourself.

---

## 1. Install, once per machine

```
/plugin marketplace add git@gitlab.nsix.io:ai/sdlc.git  <!-- path-scan-ok -->
/plugin install t4@sdlc
```

Working on the plugin itself: `claude --plugin-dir ~/code/nsix/ai/sdlc`.  <!-- path-scan-ok -->

You now have two commands in **every** repo — `/t4:adopt-sdlc` and `/t4:sync-sdlc` — plus
hooks that stay silent in repos without an `ai-factory/` directory. `/t4:explore` is a project
command: it arrives with the layout, so a repo has to adopt before it can explore.

No model configuration is required. The plugin runs whatever model your tool is already
configured with, whatever the provider.

## 2. Set a repo up, once per repo

```
/t4:adopt-sdlc                 # detects your stack and its build/lint/test commands
/t4:fleet                   # fills in ai-factory/docs/fleet.md by asking you
/t4:setup-tracker           # optional — only if you want /t4:spec ABC-12 to work
```

`/t4:adopt-sdlc` copies the layout in, writes `ai-factory/.sdlc.json`, and generates `.claude/` and
`.cursor/`. It refuses if `ai-factory/` already exists — use `/t4:sync-sdlc` there instead.

Then **fill in the prose it left as TBD**. This is the step people skip, and it is the step
that decides whether any of the rest is worth running:

| File | What it must say | Who reads it |
|---|---|---|
| `ai-factory/AGENTS.md` | what this project is, the real build/lint/test commands | every task |
| `ai-factory/docs/architecture.md` | the module map, data ownership, what is deliberately absent | explore, plan, design |
| `ai-factory/docs/coding-standards.md` | the rules that are not obvious from the code | step, fix, chore, reviewer |
| `ai-factory/docs/dont-touch.md` | paths nothing may edit — enforced by a hook, not a convention | the guard |
| `ai-factory/docs/fleet.md` | your services, what each owns, what crosses a boundary | design, adr |

An agent with a placeholder `architecture.md` produces placeholder-quality work.

Restart the session (or `/reload-plugins`) and the twelve `/t4:*` commands appear.

---

## 3. Which command do I want?

```
Is it a bug?                              → /t4:fix
Is it a small chore, no behaviour change? → /t4:chore
Is it a business description — actors,
  rules, permissions, undecided policy?   → /t4:analyse  then /t4:spec
Does it cross a service boundary,
  change a contract, or have no home yet? → /t4:design   then /t4:adr, then /t4:spec
Could it be built more than one way?      → /t4:explore  then /t4:spec
Otherwise                                 → /t4:spec
```

`/t4:explore` is optional for small obvious changes and **mandatory** when the request could
be built more than one way, or touches a queue contract, a schema, or a public API.

`/t4:design` sits above `/t4:explore`: design decides **where** a capability lives and what
it exposes, explore decides **how** to build it in one repo whose home is already settled.

`/t4:analyse` sits before both when the request is still a business description: it settles
**what** is needed — actors, permissions, rules, states, data, undecided policy — as a pack in
`ai-factory/analyses/` that `/t4:spec` reads. A small, well-understood change does not need it.

## 4. The main loop

```
/t4:spec  →  /t4:plan  →  /t4:test red  →  /t4:run ×N  →  /t4:test gaps  →  /t4:check
```

A worked example — adding CSV export to a reports page:

```
/t4:explore let users export a report as CSV
    → ai-factory/explorations/0003-csv-export.md — 3 options, a recommendation,
      and the /t4:spec line to run next

/t4:spec add CSV export to the reports page
    → ai-factory/specs/0007-csv-export.md — AC1…AC5 as Given/When/Then, plus open questions.
      Answer the open questions before planning. A spec with open questions is not buildable.

/t4:plan ai-factory/specs/0007-csv-export.md
    → ai-factory/plans/0007-csv-export.md — files to touch, then
      - [ ] Step 1 — …  - [ ] Step 2 — …  each naming the tests that prove it

/t4:test red ai-factory/specs/0007-csv-export.md
    → tests for AC1…AC5, written from the spec by an agent that has not seen your
      implementation. They MUST fail, and fail for the right reason.

/t4:run ai-factory/plans/0007-csv-export.md step 1
    → implements step 1 only, runs lint/typecheck/tests, ticks the checkbox

    …repeat per step, one at a time…

/t4:test gaps ai-factory/specs/0007-csv-export.md
    → covers any AC that ended up with no test

/t4:check
    → the reviewer agent on the branch diff; JSON verdict
```

Then commit as `ai(<task>): …` and open an MR labelled `ai-assisted`.

### The rules that make it work

- **One step per `/t4:run`.** It is told not to start the next one. Let it stop.
- **Back after time away? `/t4:state` before `/t4:run`.** It lists the specs and plans still
  outstanding, each outstanding plan with its incomplete steps, so you pick the next step up from
  the artefacts on disk rather than from what you remember of the last session. Read-only — it
  names the work and starts none of it.
- **Plan first for anything touching more than ~3 files.** Small changes do not need the
  ceremony; large ones fall apart without it.
- **Steering in chat for 20+ minutes with code changed?** Stop. Write the decision into the
  plan, commit, and continue. Long chat threads lose the decision.
- **Answer a spec's open questions before planning.** They are listed because the model could
  not resolve them, and a plan built on a guess encodes the guess.

## 5. Every command

### Plugin-level — available in any repo

| Command | Use it when | Writes |
|---|---|---|
| `/t4:adopt-sdlc` | adding the layout to an existing repo | the whole `ai-factory/` layout + `ai-factory/.sdlc.json` |
| `/t4:state` | coming back to a repo and asking what is left, before picking a step up | nothing — terminal output only |
| `/t4:sync-sdlc` | after pulling a new plugin version, or when `/t4:*` are missing | regenerates `.claude/`, `.cursor/`; reports drift |

#### Taking the 1.0.0 rename

1.0.0 renamed the layout: `ai/` became `ai-factory/`, and `specs/` and `docs/adr/` moved inside it.  <!-- path-scan-ok -->
`/t4:migrate-layout` made that move, and **2.1.0 removed it** — a one-shot migration, kept for as
long as it was a command anyone here still needed. A repo that has not run it still can: check out
ai-sdlc at 2.0.0 or earlier, point your tool at that copy, and run the command from there.
Then commit what it leaves in **two** commits, in the order it prints — the moves first, the path
rewrite second. Git pairs a rename by similarity, so in one commit a file whose path lines are most
of its content loses its history; two commits make that independent of how big the file is.

Until you run it the hooks still work: they accept the old directory name until 3.0.0, so the
dont-touch guard and the run log keep going. The prompts do not — they name `ai-factory/` only, so
`/t4:spec` and the rest will look in a directory that is not there yet. `/t4:doctor` says which of
the three states a repo is in, and `/t4:sync-sdlc` stops and points here rather than syncing.

### Project-level — generated from `ai-factory/tasks/`

| Command | Use it when | Writes | Never does |
|---|---|---|---|
| `/t4:fleet` | once per repo, then when a service or contract changes | `ai-factory/docs/fleet.md` | ask anything in CI — it fills what it can and marks the rest TBD |
| `/t4:design <capability>` | the capability spans services or changes a contract | `ai-factory/designs/NNNN-*.md` | write specs, plans or code |
| `/t4:design review <plan>` | a plan crosses a boundary or adds a dependency | nothing — JSON verdict | review correctness or style; that is `/t4:check` |
| `/t4:adr <decision>` | any decision that outlives the change, **every new dependency** | `ai-factory/adr/NNNN-*.md` | reopen a decision an accepted ADR settled |
| `/t4:analyse <feature description>` | the request is a business description — actors, rules, permissions, a lifecycle, undecided policy | `ai-factory/analyses/NNNN-*.md` | write specs, plans or code; invent policy, estimates or approvals; create anything outside the repo |
| `/t4:explore <request>` | the request could be built more than one way | `ai-factory/explorations/NNNN-*.md` | change code |
| `/t4:spec <feature>` | you know what to build, not yet how | `ai-factory/specs/NNNN-*.md` | write the plan or the code |
| `/t4:plan <spec>` | the spec's open questions are answered | `ai-factory/plans/NNNN-*.md` | change code |
| `/t4:test red <spec>` | before implementing | test files | touch production code — if a test needs a change there, it stops and says so |
| `/t4:run <plan> step N` | implementing, one step at a time | code + tests | start step N+1 |
| `/t4:test gaps <spec>` | after the steps are done | test files | weaken an assertion to reach green |
| `/t4:fix <bug>` | something is broken | a failing test first, then the fix | refactor anything unrelated |
| `/t4:chore <change>` | small maintenance, no behaviour change | code + tests | change behaviour beyond the request |
| `/t4:check` | before committing | nothing — JSON verdict | fix anything it finds |

### The agents

Eight subagents do the work the commands delegate. Each is deliberately narrow. Four run the
loop steps, so that each step starts from its artefacts and not from the chat that produced
them; the session keeps what only a session can do — refuse an empty argument, ask a question,
resolve a tracker key, relay the report:

- **`explorer`** — `/t4:explore`: reads the code the request touches, writes two to four
  options with a comparison and one recommendation to `ai-factory/explorations/`. Never code.
- **`specifier`** — `/t4:spec`: builds on the exploration's chosen option and the analysis if
  either exists, writes Given/When/Then criteria to `ai-factory/specs/`; anything implicit is an open
  question, never a criterion. Never the plan or code.
- **`planner`** — `/t4:plan`: turns one spec into steps sized for one `/t4:run`, each naming
  the tests that prove it, in `ai-factory/plans/`. Never code.
- **`implementer`** — `/t4:run`: implements exactly one step, runs lint, typecheck and tests,
  ticks the box only when green. Red, or a test it cannot find: stops and explains. Never the
  next step, never a knowledge source, and the dont-touch guard blocks it like anyone else.

Four stand outside the loop's steps:


- **`reviewer`** — reads the branch diff against the spec, plan and standards. Read-only,
  JSON verdict. Checks correctness, scope, tests, spec drift, boundaries, security,
  operability. Does not comment on formatting; the linter owns that.
- **`tester`** — writes acceptance tests from the spec's ACs. Reads the implementation's
  *public surface only* and never the diff, because a test derived from an implementation
  restates it instead of checking it. Writes test files only.
- **`architect`** — decides where a capability belongs, writes designs and ADRs. Treats an
  accepted ADR as binding. Proposes changes to context docs rather than making them.
- **`analyst`** — turns a feature description into a requirements pack: objectives, scope,
  permission matrix, use cases and lifecycles, functional and non-functional requirements,
  business rules, data dictionary, integrations, stories with Given/When/Then ACs, test
  scenarios and traceability. Labels every statement a supplied fact, assumption, proposal
  or open question and never lets one become another. Invents no policy, estimate, approval
  or existing architecture. Writes `ai-factory/analyses/` only.

Their project copies live in `ai-factory/agents/` — add project-specific checks there, not to the
plugin.

### External knowledge, read-only

Declare a source in `ai-factory/knowledge_base.md` — one table with `name`, `kind` and `use` — and the
explorer, specifier, planner, analyst, architect and reviewer agents read it. Every fact
they take from it is labelled with the source's name and *external, unverified*, ranks below the
code and an accepted ADR, and a disagreement becomes an open question. Nothing is ever written
back. A source that cannot be reached — Codex, headless, not attached — is one line in the
report; the loop never halts on it, unlike a ticket the tracker cannot resolve, because a ticket
is input and knowledge is enrichment. `ai-factory/docs/knowledge.md` holds every detail; a repo that
declares nothing sees no change at all. `/t4:doctor` says whether a repo is configured.

---

## 6. Headless, for CI

```
make ai TASK=chore INPUT="bump the node version"
make ai TASK=check INPUT_FILE=some.diff     # for anything large, or containing $ or quotes
make review                                 # the branch diff through the reviewer, then gate.js
```

`make review` exits non-zero on a blocker only when `GATE_ENFORCE=1`; without it the gate is
advisory and prints findings. `ai-factory/models.yaml` pins a model per tool if you need one — blank
means "whatever the tool is configured with", which is the default and works anywhere.
Set `CMD=` to run a different binary.

## 7. Staying current

`/t4:sync-sdlc` regenerates the adapters and then tells you how your `ai-factory/` compares with the
installed templates:

| It says | What to do |
|---|---|
| **upstream changed** | your copy is untouched — safe to take the new version |
| **both changed** | you edited it and so did upstream — merge by hand |
| **locally modified** | yours; upstream has not moved. Nothing to do |
| **new upstream** | a file added since you adopted; copy it in if you want it |

It reports only. Taking a change is a separate, reviewable edit — deliberately, so an upstream
template can never silently overwrite something you rely on.

A repo adopted before `ai-factory/.sdlc.json` existed is told how to start a baseline. Never edit that
file by hand; a hook blocks it, because a manifest edited by hand makes the check lie.

## 8. Using it from Codex

`sync-adapters.sh` generates `.codex/skills/` alongside `.claude/` and `.cursor/`, so the same
twelve tasks are slash commands in Codex too. Nothing extra to install — Codex picks up
`.codex/skills/` with no configuration.

| | Claude Code | Codex |
|---|---|---|
| The twelve `/t4:*` tasks | yes | yes |
| Headless | `make ai` | `make ai TOOL=codex` |
| the eight agents — reviewer, tester, architect, analyst, explorer, specifier, planner, implementer | separate subagent, own context | **inlined into the same session** |
| Session log, edit log, cost row | yes | no |
| `dont-touch.md` guard | enforced by a hook | **not enforced** |

Two differences are worth taking seriously rather than skimming:

**The agents lose their independence.** Codex plugins cannot ship subagents, so `/t4:check`,
`/t4:test`, `/t4:design`, `/t4:adr`, `/t4:analyse`, `/t4:explore`, `/t4:spec`, `/t4:plan` and
`/t4:run` tell the session to follow `ai-factory/agents/<name>.md` itself.
The generated skill says so. It matters most for the tester and the reviewer, whose whole point
is independence: a tester that has seen the implementation writes tests that restate it, and a
reviewer that wrote the code is not reviewing it. The four step agents lose something quieter:
under Codex the step runs in the session that held the chat, so a spec can absorb twenty minutes
of discussion that never reached the exploration. Treat every inlined agent's output as a
self-check — useful, but not the second opinion the Claude Code path gives you.

**The dont-touch guard does not run.** The hooks are Claude Code's; under Codex a path listed
in `ai-factory/docs/dont-touch.md` is protected by nothing but the prompt. If a repo relies on that
guard, run the change through Claude Code.

Headless costs: `codex exec` reports token counts but no price, so the `cost_usd` column stays
empty for Codex rows rather than being filled with a guess. Its `input_tokens` include cached
tokens, which `log.js` subtracts back out so the column means the same thing in every row.

## 9. What the hooks record

Silently, into `ai-factory/runs/` — nothing prints to your terminal:

- `log.csv` — one row per session: tokens, cache hit rate, cost, model, branch. The row is
  buffered in `log.pending.csv` (gitignored) and moved into `log.csv` when the session runs
  `git commit`, so the tracked file changes only inside the commit that produced the work and
  never blocks a `git checkout`. Committing from a terminal instead? `make log-flush`. Fill the
  `accepted` column (y/n/partial) at commit time; it is the only honest measure of whether
  this is working. Each row is the **increment** since that session's previous row, so the rows of
  one session add up to what it spent rather than each restating a running total.
- Tokens spent inside a subagent are in the log too, as their own rows. Every agent that
  concludes — the reviewer and tester, and the explorer, specifier, planner and implementer that
  `/t4:explore`, `/t4:spec`, `/t4:plan` and `/t4:run` delegate to — adds a row summed from its own
  transcript. The `source` column says which kind you are looking at: `session` for a turn, `agent`
  for a concluded subagent, `make` for a headless CI run. An `agent` row names the agent in the
  `agent` column and carries the `/t4:` command the session was running in `task`, so you can ask
  where the money went by agent, by task, by branch or by model — not just how much the repo spent.
  A record is counted once however many transcripts carry a copy of it, keyed on its message uuid;
  a record whose transcript format omits that key is counted every time instead, which over-counts
  rather than losing the tokens quietly.
- Because the header changed in 2.0.0 (17 columns — `agent` is new), the first write after you take
  that update moves your existing rows to `log.previous.csv` and starts a clean file. Those rows
  were cumulative, not increments, and nothing reinterprets them. `make log-flush` refuses while
  `log.pending.csv` and `log.csv` have different headers, which is exactly the state right after the
  upgrade — let a session flush first, so the hook migrates the file, then flush by hand as usual.
- `sessions.jsonl`, `edits.jsonl`, `cmds.jsonl` — what ran, what was edited, which test and
  lint commands were used.
- The guard blocks any edit to a path in `ai-factory/docs/dont-touch.md` and says which rule matched.

`ai-factory/runs/*.json`, `*.jsonl` and `log.pending.csv` are gitignored; `log.csv` is committed, with
`merge=union` in `.gitattributes` so two branches' rows never conflict.

Hooks run from the **installed** plugin, not from a working copy. After updating the plugin,
restart the session — until you do, an older hook keeps writing the older row shape, and a
`log.csv` already migrated to a newer header will collect rows that do not match it. If that
happens, move the mismatched rows to `ai-factory/runs/log.previous.csv`; that is what the current
writer does automatically.

### `make cost` — where the tokens went

`make cost` reads `ai-factory/runs/log.csv` and prints token spend grouped by **task**, **agent**,
**branch** and **day**, then a total. `make cost JSON=1` and `make cost TSV=1` print the same numbers
as a machine-readable document instead. All three are read-only over the log and write nothing.

**It reports tokens and turns, never money.** Decided 2026-09-27: `cost_usd` is not read at all.
Nine of the ten logs in this workspace sit in layouts that may run different models, the column is
already `~`-marked or empty per row, and a rolled-up dollar figure would be summing prices set in ten
separate `models.yaml` files. Anything that wants money prices the token counts itself, with one
price list, so its totals are comparable by construction.

What it **can** answer: which task, agent, branch or day the tokens went to; how many runs and turns
each took; the cache hit rate per group, recomputed from the summed tokens rather than averaged over
rows. Per-agent and per-task numbers are meaningful only for rows written by the 2.0.0 collection
change — older rows carry no `agent` column and an empty `task`, and appear under `(unattributed)`.

What the log **cannot** see, at any effort, and which `make cost` therefore never shows:
per-plan-step cost inside `/t4:run`, wall-clock duration, tool-call counts, lines changed, and
**anything from Cursor**, which has no local export of any kind. If Cursor is in use here, this is
not a complete picture of spend and cannot be made into one.

Two lines appear only when they mean something. The `accepted` column is hand-filled and usually
empty, so a coverage line is printed only once some row carries a value rather than reading
"0 of N" forever. And a total drawn from more than one `tool` carries a footnote naming them: Codex
inlines the agent into the session, so one session is both the task and the agent, while Claude
spreads across named agents — without the note, the by-agent table invites comparing a part with a
whole.

### The export is a contract

The JSON and TSV forms are read by collectors outside this repo, which no fixture here can reach. So
they carry a **schema version**, and it is a plain integer starting at `1`:

- **Adding** a field does **not** change the version. A consumer reading version 1 keeps working when
  a field it never reads appears, so consumers must ignore fields they do not recognise.
- **Renaming** a field, **removing** one, or changing what an existing one means **does** change it.
  Any of those is a breaking change for a consumer this repo cannot see.

`skills/ai-layout/scripts/check-cost.sh` asserts the exact field-name set and fails on a rename, a
removal *and* an addition. The asymmetry is deliberate: the check guards against accidental drift,
while the version communicates breakage. An addition means editing that expected list by hand, which
is the point.

## 10. When something is wrong

**Run `/t4:doctor` first.** It reports the layout, the adapters, the version this repo records
against the one the session loaded, drift, where the plugin is installed and whether older
cached copies are still around — each with the command that fixes it. It changes nothing, so
there is no reason not to run it before guessing.

**If `/t4:doctor` itself does not exist, that is the diagnosis.** The plugin is not enabled in
this repo, and no command can tell you so — in a repo without it, none of them are there to
run. Install it at user scope, or enable it here:

```
/plugin install t4@sdlc
```

Then restart the session: commands and hooks are loaded at startup, so a plugin installed
mid-session is not yet running.

| Symptom | Cause |
|---|---|
| No `/t4:*` commands | this repo has no `ai-factory/` layout, or the adapters were not generated — run `/t4:adopt-sdlc` or `/t4:sync-sdlc` |
| `/t4:*` missing in Codex only | `.codex/skills/` was generated by an older plugin — run `/t4:sync-sdlc` |
| A command behaves oddly | read `ai-factory/tasks/<name>.md`; that text *is* the behaviour. Fix it there via MR |
| An edit was blocked | it matched `ai-factory/docs/dont-touch.md`. Edit the source, not the generated copy |
| `.claude/` looks wrong | never edit it — it is generated. Change `ai-factory/` and run `/t4:sync-sdlc` |
| The reviewer is too lenient | add project checks to `ai-factory/agents/reviewer.md` |
| Tests pass but prove nothing | `/t4:test gaps` — it flags ACs whose tests would still pass if the behaviour were reverted |

## 11. The short version

```
once:      /t4:adopt-sdlc  →  /t4:fleet  →  fill in ai-factory/docs/*
per change: /t4:design? → /t4:analyse? → /t4:explore? → /t4:spec → /t4:plan
            → /t4:test red → /t4:run ×N → /t4:test gaps → /t4:check
            → commit ai(<task>): …  →  MR labelled ai-assisted
per dependency or lasting decision: /t4:adr
```
