# Using the sdlc plugin

How to install it, what each command is for, and the order to run them in.

The plugin gives you three things: an `ai/` directory in your repo that holds the project's
context and prompts, slash commands generated from it, and three agents. Everything a command
does is written in a file you can read and change — `ai/tasks/<name>.md`. If a command keeps
needing steering in chat, the prompt is missing a line; fix the prompt, don't repeat yourself.

---

## 1. Install, once per machine

```
/plugin marketplace add git@gitlab.nsix.io:ai/sdlc.git
/plugin install sdlc@n6
```

Working on the plugin itself: `claude --plugin-dir ~/code/nsix/ai/ai-sdlc`.

You now have three commands in **every** repo — `/sdlc:adopt`, `/sdlc:explore`, `/sdlc:sync`
— plus hooks that stay silent in repos without an `ai/` directory.

No model configuration is required. The plugin runs whatever model your tool is already
configured with, whatever the provider.

## 2. Set a repo up, once per repo

```
/sdlc:adopt                 # detects your stack and its build/lint/test commands
/ai-fleet                   # fills in ai/docs/fleet.md by asking you
```

`/sdlc:adopt` copies the layout in, writes `ai/.sdlc.json`, and generates `.claude/` and
`.cursor/`. It refuses if `ai/` already exists — use `/sdlc:sync` there instead.

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

Restart the session (or `/reload-plugins`) and the eleven `/ai-*` commands appear.

---

## 3. Which command do I want?

```
Is it a bug?                              → /ai-fix
Is it a small chore, no behaviour change? → /ai-chore
Does it cross a service boundary,
  change a contract, or have no home yet? → /ai-design   then /ai-adr, then /ai-spec
Could it be built more than one way?      → /ai-explore  then /ai-spec
Otherwise                                 → /ai-spec
```

`/ai-explore` is optional for small obvious changes and **mandatory** when the request could
be built more than one way, or touches a queue contract, a schema, or a public API.

`/ai-design` sits above `/ai-explore`: design decides **where** a capability lives and what
it exposes, explore decides **how** to build it in one repo whose home is already settled.

## 4. The main loop

```
/ai-spec  →  /ai-plan  →  /ai-test red  →  /ai-step ×N  →  /ai-test gaps  →  /ai-check
```

A worked example — adding CSV export to a reports page:

```
/ai-explore let users export a report as CSV
    → ai/explorations/0003-csv-export.md — 3 options, a recommendation,
      and the /ai-spec line to run next

/ai-spec add CSV export to the reports page
    → specs/0007-csv-export.md — AC1…AC5 as Given/When/Then, plus open questions.
      Answer the open questions before planning. A spec with open questions is not buildable.

/ai-plan specs/0007-csv-export.md
    → ai/plans/0007-csv-export.md — files to touch, then
      - [ ] Step 1 — …  - [ ] Step 2 — …  each naming the tests that prove it

/ai-test red specs/0007-csv-export.md
    → tests for AC1…AC5, written from the spec by an agent that has not seen your
      implementation. They MUST fail, and fail for the right reason.

/ai-step ai/plans/0007-csv-export.md step 1
    → implements step 1 only, runs lint/typecheck/tests, ticks the checkbox

    …repeat per step, one at a time…

/ai-test gaps specs/0007-csv-export.md
    → covers any AC that ended up with no test

/ai-check
    → the reviewer agent on the branch diff; JSON verdict
```

Then commit as `ai(<task>): …` and open an MR labelled `ai-assisted`.

### The rules that make it work

- **One step per `/ai-step` run.** It is told not to start the next one. Let it stop.
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
| `/sdlc:adopt` | adding the layout to an existing repo | the whole `ai/` layout + `ai/.sdlc.json` |
| `/sdlc:explore <request>` | you want options before a spec, in a repo with no layout yet | `ai/explorations/NNNN-*.md` |
| `/sdlc:sync` | after pulling a new plugin version, or when `/ai-*` are missing | regenerates `.claude/`, `.cursor/`; reports drift |

### Project-level — generated from `ai/tasks/`

| Command | Use it when | Writes | Never does |
|---|---|---|---|
| `/ai-fleet` | once per repo, then when a service or contract changes | `ai/docs/fleet.md` | ask anything in CI — it fills what it can and marks the rest TBD |
| `/ai-design <capability>` | the capability spans services or changes a contract | `ai/designs/NNNN-*.md` | write specs, plans or code |
| `/ai-design review <plan>` | a plan crosses a boundary or adds a dependency | nothing — JSON verdict | review correctness or style; that is `/ai-check` |
| `/ai-adr <decision>` | any decision that outlives the change, **every new dependency** | `docs/adr/NNNN-*.md` | reopen a decision an accepted ADR settled |
| `/ai-explore <request>` | the request could be built more than one way | `ai/explorations/NNNN-*.md` | change code |
| `/ai-spec <feature>` | you know what to build, not yet how | `specs/NNNN-*.md` | write the plan or the code |
| `/ai-plan <spec>` | the spec's open questions are answered | `ai/plans/NNNN-*.md` | change code |
| `/ai-test red <spec>` | before implementing | test files | touch production code — if a test needs a change there, it stops and says so |
| `/ai-step <plan> step N` | implementing, one step at a time | code + tests | start step N+1 |
| `/ai-test gaps <spec>` | after the steps are done | test files | weaken an assertion to reach green |
| `/ai-fix <bug>` | something is broken | a failing test first, then the fix | refactor anything unrelated |
| `/ai-chore <change>` | small maintenance, no behaviour change | code + tests | change behaviour beyond the request |
| `/ai-check` | before committing | nothing — JSON verdict | fix anything it finds |

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

`/sdlc:sync` regenerates the adapters and then tells you how your `ai/` compares with the
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
| The eleven `/ai-*` tasks | yes | yes |
| Headless | `make ai` | `make ai TOOL=codex` |
| `reviewer` / `tester` / `architect` | separate subagent, own context | **inlined into the same session** |
| Session log, edit log, cost row | yes | no |
| `dont-touch.md` guard | enforced by a hook | **not enforced** |

Two differences are worth taking seriously rather than skimming:

**The agents lose their independence.** Codex plugins cannot ship subagents, so `/ai-check`,
`/ai-test`, `/ai-design` and `/ai-adr` tell the session to follow `ai/agents/<name>.md` itself.
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

## 10. When something is wrong

| Symptom | Cause |
|---|---|
| No `/ai-*` commands | this repo has no `ai/` layout, or the adapters were not generated — run `/sdlc:adopt` or `/sdlc:sync` |
| `/ai-*` missing in Codex only | `.codex/skills/` was generated by an older plugin — run `/sdlc:sync` |
| A command behaves oddly | read `ai/tasks/<name>.md`; that text *is* the behaviour. Fix it there via MR |
| An edit was blocked | it matched `ai/docs/dont-touch.md`. Edit the source, not the generated copy |
| `.claude/` looks wrong | never edit it — it is generated. Change `ai/` and run `/sdlc:sync` |
| The reviewer is too lenient | add project checks to `ai/agents/reviewer.md` |
| Tests pass but prove nothing | `/ai-test gaps` — it flags ACs whose tests would still pass if the behaviour were reverted |

## 11. The short version

```
once:      /sdlc:adopt  →  /ai-fleet  →  fill in ai/docs/*
per change: /ai-design? → /ai-explore? → /ai-spec → /ai-plan
            → /ai-test red → /ai-step ×N → /ai-test gaps → /ai-check
            → commit ai(<task>): …  →  MR labelled ai-assisted
per dependency or lasting decision: /ai-adr
```
