# Using the ai-sdlc plugin

How to install it, what each command is for, and the order to run them in.

The plugin gives you three things: an `ai/` directory in your repo that holds the project's
context and prompts, slash commands generated from it, and three agents. Everything a command
does is written in a file you can read and change — `ai/tasks/<name>.md`. If a command keeps
needing steering in chat, the prompt is missing a line; fix the prompt, don't repeat yourself.

---

## 1. Install, once per machine

```
/plugin marketplace add git@gitlab.nsix.io:ai/sdlc.git
/plugin install t4@sdlc
```

Working on the plugin itself: `claude --plugin-dir ~/code/nsix/ai/ai-sdlc`.

You now have two commands in **every** repo — `/t4:adopt-sdlc` and `/t4:sync-sdlc` — plus
hooks that stay silent in repos without an `ai/` directory. `/t4:explore` is a project
command: it arrives with the layout, so a repo has to adopt before it can explore.

No model configuration is required. The plugin runs whatever model your tool is already
configured with, whatever the provider.

## 2. Set a repo up, once per repo

```
/t4:adopt-sdlc                 # detects your stack and its build/lint/test commands
/t4:fleet                   # fills in ai/docs/fleet.md by asking you
```

`/t4:adopt-sdlc` copies the layout in, writes `ai/.sdlc.json`, and generates `.claude/` and
`.cursor/`. It refuses if `ai/` already exists — use `/t4:sync-sdlc` there instead.

Then **fill in the prose it left as TBD**. This is the step people skip, and it is the step
that decides whether any of the rest is worth running:

| File | What it must say | Who reads it |
|---|---|---|
| `ai/AGENTS.md` | what this project is, the real build/lint/test commands | every task |
| `ai/docs/architecture.md` | the module map, data ownership, what is deliberately absent | explore, plan, design |
| `ai/docs/coding-standards.md` | the rules that are not obvious from the code | step, fix, chore, reviewer |
| `ai/docs/dont-touch.md` | paths nothing may edit — enforced by a hook, not a convention | the guard |
| `ai/docs/fleet.md` | your services, what each owns, what crosses a boundary | design, adr |

An agent with a placeholder `architecture.md` produces placeholder-quality work.

Restart the session (or `/reload-plugins`) and the eleven `/t4:*` commands appear.

---

## 3. Which command do I want?

```
Is it a bug?                              → /t4:fix
Is it a small chore, no behaviour change? → /t4:chore
Does it cross a service boundary,
  change a contract, or have no home yet? → /t4:design   then /t4:adr, then /t4:spec
Could it be built more than one way?      → /t4:explore  then /t4:spec
Otherwise                                 → /t4:spec
```

`/t4:explore` is optional for small obvious changes and **mandatory** when the request could
be built more than one way, or touches a queue contract, a schema, or a public API.

`/t4:design` sits above `/t4:explore`: design decides **where** a capability lives and what
it exposes, explore decides **how** to build it in one repo whose home is already settled.

## 4. The main loop

```
/t4:spec  →  /t4:plan  →  /t4:test red  →  /t4:step ×N  →  /t4:test gaps  →  /t4:check
```

A worked example — adding CSV export to a reports page:

```
/t4:explore let users export a report as CSV
    → ai/explorations/0003-csv-export.md — 3 options, a recommendation,
      and the /t4:spec line to run next

/t4:spec add CSV export to the reports page
    → specs/0007-csv-export.md — AC1…AC5 as Given/When/Then, plus open questions.
      Answer the open questions before planning. A spec with open questions is not buildable.

/t4:plan specs/0007-csv-export.md
    → ai/plans/0007-csv-export.md — files to touch, then
      - [ ] Step 1 — …  - [ ] Step 2 — …  each naming the tests that prove it

/t4:test red specs/0007-csv-export.md
    → tests for AC1…AC5, written from the spec by an agent that has not seen your
      implementation. They MUST fail, and fail for the right reason.

/t4:step ai/plans/0007-csv-export.md step 1
    → implements step 1 only, runs lint/typecheck/tests, ticks the checkbox

    …repeat per step, one at a time…

/t4:test gaps specs/0007-csv-export.md
    → covers any AC that ended up with no test

/t4:check
    → the reviewer agent on the branch diff; JSON verdict
```

Then commit as `ai(<task>): …` and open an MR labelled `ai-assisted`.

### The rules that make it work

- **One step per `/t4:step` run.** It is told not to start the next one. Let it stop.
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
| `/t4:adopt-sdlc` | adding the layout to an existing repo | the whole `ai/` layout + `ai/.sdlc.json` |
| `/t4:sync-sdlc` | after pulling a new plugin version, or when `/t4:*` are missing | regenerates `.claude/`, `.cursor/`; reports drift |

### Project-level — generated from `ai/tasks/`

| Command | Use it when | Writes | Never does |
|---|---|---|---|
| `/t4:fleet` | once per repo, then when a service or contract changes | `ai/docs/fleet.md` | ask anything in CI — it fills what it can and marks the rest TBD |
| `/t4:design <capability>` | the capability spans services or changes a contract | `ai/designs/NNNN-*.md` | write specs, plans or code |
| `/t4:design review <plan>` | a plan crosses a boundary or adds a dependency | nothing — JSON verdict | review correctness or style; that is `/t4:check` |
| `/t4:adr <decision>` | any decision that outlives the change, **every new dependency** | `docs/adr/NNNN-*.md` | reopen a decision an accepted ADR settled |
| `/t4:explore <request>` | the request could be built more than one way | `ai/explorations/NNNN-*.md` | change code |
| `/t4:spec <feature>` | you know what to build, not yet how | `specs/NNNN-*.md` | write the plan or the code |
| `/t4:plan <spec>` | the spec's open questions are answered | `ai/plans/NNNN-*.md` | change code |
| `/t4:test red <spec>` | before implementing | test files | touch production code — if a test needs a change there, it stops and says so |
| `/t4:step <plan> step N` | implementing, one step at a time | code + tests | start step N+1 |
| `/t4:test gaps <spec>` | after the steps are done | test files | weaken an assertion to reach green |
| `/t4:fix <bug>` | something is broken | a failing test first, then the fix | refactor anything unrelated |
| `/t4:chore <change>` | small maintenance, no behaviour change | code + tests | change behaviour beyond the request |
| `/t4:check` | before committing | nothing — JSON verdict | fix anything it finds |

### The agents

Three subagents do the work the commands delegate. Each is deliberately narrow:

- **`reviewer`** — reads the branch diff against the spec, plan and standards. Read-only,
  JSON verdict. Checks correctness, scope, tests, spec drift, boundaries, security,
  operability. Does not comment on formatting; the linter owns that.
- **`tester`** — writes acceptance tests from the spec's ACs. Reads the implementation's
  *public surface only* and never the diff, because a test derived from an implementation
  restates it instead of checking it. Writes test files only.
- **`architect`** — decides where a capability belongs, writes designs and ADRs. Treats an
  accepted ADR as binding. Proposes changes to context docs rather than making them.

Their project copies live in `ai/agents/` — add project-specific checks there, not to the
plugin.

---

## 6. Headless, for CI

```
make ai TASK=chore INPUT="bump the node version"
make ai TASK=check INPUT_FILE=some.diff     # for anything large, or containing $ or quotes
make review                                 # the branch diff through the reviewer, then gate.js
```

`make review` exits non-zero on a blocker only when `GATE_ENFORCE=1`; without it the gate is
advisory and prints findings. `ai/models.yaml` pins a model per tool if you need one — blank
means "whatever the tool is configured with", which is the default and works anywhere.
Set `CMD=` to run a different binary.

## 7. Staying current

`/t4:sync-sdlc` regenerates the adapters and then tells you how your `ai/` compares with the
installed templates:

| It says | What to do |
|---|---|
| **upstream changed** | your copy is untouched — safe to take the new version |
| **both changed** | you edited it and so did upstream — merge by hand |
| **locally modified** | yours; upstream has not moved. Nothing to do |
| **new upstream** | a file added since you adopted; copy it in if you want it |

It reports only. Taking a change is a separate, reviewable edit — deliberately, so an upstream
template can never silently overwrite something you rely on.

A repo adopted before `ai/.sdlc.json` existed is told how to start a baseline. Never edit that
file by hand; a hook blocks it, because a manifest edited by hand makes the check lie.

## 8. Using it from Codex

`sync-adapters.sh` generates `.codex/skills/` alongside `.claude/` and `.cursor/`, so the same
eleven tasks are slash commands in Codex too. Nothing extra to install — Codex picks up
`.codex/skills/` with no configuration.

| | Claude Code | Codex |
|---|---|---|
| The eleven `/t4:*` tasks | yes | yes |
| Headless | `make ai` | `make ai TOOL=codex` |
| `reviewer` / `tester` / `architect` | separate subagent, own context | **inlined into the same session** |
| Session log, edit log, cost row | yes | no |
| `dont-touch.md` guard | enforced by a hook | **not enforced** |

Two differences are worth taking seriously rather than skimming:

**The agents lose their independence.** Codex plugins cannot ship subagents, so `/t4:check`,
`/t4:test`, `/t4:design` and `/t4:adr` tell the session to follow `ai/agents/<name>.md` itself.
The generated skill says so. It matters because independence is the whole point of those two
agents: a tester that has seen the implementation writes tests that restate it, and a reviewer
that wrote the code is not reviewing it. Under Codex, treat their findings as a self-check —
useful, but not the second opinion the Claude Code path gives you.

**The dont-touch guard does not run.** The hooks are Claude Code's; under Codex a path listed
in `ai/docs/dont-touch.md` is protected by nothing but the prompt. If a repo relies on that
guard, run the change through Claude Code.

Headless costs: `codex exec` reports token counts but no price, so the `cost_usd` column stays
empty for Codex rows rather than being filled with a guess. Its `input_tokens` include cached
tokens, which `log.js` subtracts back out so the column means the same thing in every row.

## 9. What the hooks record

Silently, into `ai/runs/` — nothing prints to your terminal:

- `log.csv` — one row per session: tokens, cache hit rate, cost, model, branch. Fill the
  `accepted` column (y/n/partial) at commit time; it is the only honest measure of whether
  this is working.
- `sessions.jsonl`, `edits.jsonl`, `cmds.jsonl` — what ran, what was edited, which test and
  lint commands were used.
- The guard blocks any edit to a path in `ai/docs/dont-touch.md` and says which rule matched.

`ai/runs/*.json` and `*.jsonl` are gitignored; `log.csv` is committed.

Hooks run from the **installed** plugin, not from a working copy. After updating the plugin,
restart the session — until you do, an older hook keeps writing the older row shape, and a
`log.csv` already migrated to a newer header will collect rows that do not match it. If that
happens, move the mismatched rows to `ai/runs/log.previous.csv`; that is what the current
writer does automatically.

## 10. When something is wrong

| Symptom | Cause |
|---|---|
| No `/t4:*` commands | this repo has no `ai/` layout, or the adapters were not generated — run `/t4:adopt-sdlc` or `/t4:sync-sdlc` |
| `/t4:*` missing in Codex only | `.codex/skills/` was generated by an older plugin — run `/t4:sync-sdlc` |
| A command behaves oddly | read `ai/tasks/<name>.md`; that text *is* the behaviour. Fix it there via MR |
| An edit was blocked | it matched `ai/docs/dont-touch.md`. Edit the source, not the generated copy |
| `.claude/` looks wrong | never edit it — it is generated. Change `ai/` and run `/t4:sync-sdlc` |
| The reviewer is too lenient | add project checks to `ai/agents/reviewer.md` |
| Tests pass but prove nothing | `/t4:test gaps` — it flags ACs whose tests would still pass if the behaviour were reverted |

## 11. The short version

```
once:      /t4:adopt-sdlc  →  /t4:fleet  →  fill in ai/docs/*
per change: /t4:design? → /t4:explore? → /t4:spec → /t4:plan
            → /t4:test red → /t4:step ×N → /t4:test gaps → /t4:check
            → commit ai(<task>): …  →  MR labelled ai-assisted
per dependency or lasting decision: /t4:adr
```
