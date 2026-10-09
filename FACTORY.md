---
name: T4 AI SDLC
description: "T4 AI SDLC core: a cross-role agent workflow from requirements to review."
owner: T4 platform
authors:
  - "Volodymyr Tanin <volodymyr_tanin@epam.com>"
install_script: "git clone git@git.epam.com:volodymyr_tanin/ai-sdlc-plugin.git && claude --plugin-dir ./ai-sdlc-plugin"
install_script_unix: "git clone git@git.epam.com:volodymyr_tanin/ai-sdlc-plugin.git && claude --plugin-dir ./ai-sdlc-plugin"
sdlc_phase: Accelerated Feature Development
support_level: Self-Serve
use_cases:
  - Spec-driven development
  - Requirements analysis and solution design
  - Acceptance-test generation from specs
  - Automated code review
---

# T4 AI SDLC

A curated collection of agents, skills, rules and conventions that stitches eight agents
into one cross-role, cross-phase workflow. Each agent is a separate role with its own
tool permissions; they hand off through **files on disk**, not through a shared chat
context, so every step is reviewable, re-runnable and diffable on its own.

All of it lives in one directory per repo, `ai-factory/`: context docs, task procedures,
agent additions and every handoff artifact below. Adoption preserves existing root and
host files.

## The handoff chain

Requirements flow left to right. Each agent reads the previous artifact and writes the
next one — a business analyst's output feeds the spec, which feeds the plan, which feeds
both the developer and, independently, QA.

| Phase | Role | Agent | Command | Reads | Writes |
| --- | --- | --- | --- | --- | --- |
| Architecture | Architect | `architect` | `/t4:design`, `/t4:adr` | `ai-factory/docs/fleet.md` | `ai-factory/designs/`, `ai-factory/adr/` |
| Requirements | Business analyst | `analyst` | `/t4:analyse` | feature description | `ai-factory/analyses/` |
| Options | Explorer | `explorer` | `/t4:explore` | code, `ai-factory/analyses/` | `ai-factory/explorations/` |
| Specification | Specifier | `specifier` | `/t4:spec` | `ai-factory/analyses/`, `ai-factory/explorations/` | `ai-factory/specs/` |
| Planning | Planner | `planner` | `/t4:plan` | `ai-factory/specs/` | `ai-factory/plans/` |
| QA | Tester | `tester` | `/t4:test` | `ai-factory/specs/` (ACs only) | test files |
| Development | Implementer | `implementer` | `/t4:run` | `ai-factory/plans/` one step | source |
| Review | Reviewer | `reviewer` | `/t4:check` | branch diff vs `ai-factory/specs/`, `ai-factory/plans/` | JSON verdict |
| Handoff | Developer | none | `/t4:report` | contract sidecars and evidence of one delivery | `ai-factory/reports/<id>/` completion report |

Two properties the file handoff buys:

- **The tester is blind to the implementation.** It derives tests from the spec's
  acceptance criteria only, so the ACs fail first and the implementer cannot quietly
  redefine what "done" means.
- **The reviewer is independent and read-only.** It judges the branch diff against the
  spec, the plan and the repo's coding standards, never against its own prior work.

### Validated handoffs (opt-in)

With `node ai-factory/make/contracts.js enable`, each handoff also leaves a small JSON sidecar
beside its Markdown, and nothing moves on unchecked. The specifier and planner record the
delivery ID, the AC IDs, each plan step's criteria and its verification commands. The tester and
implementer record what actually ran with `make -f ai-factory/make/ai.mk verify`, and `make
review DELIVERY=<id>` binds the verdict to the reviewed code. `make -f ai-factory/make/ai.mk
contracts` then reports every artifact as `valid`, `invalid`, `stale` or `legacy_unverified`.
Freshness is judged by content digests, never by timestamps. Editing the spec makes the plan and
its evidence stale, editing code makes the final and review evidence stale, and a ticked box
without passing evidence is `not_run`. This is structural validation only: it proves the pieces
agree, not that a requirement is right. Existing specs and plans are drafted into sidecars only
by an explicit `contracts.js migrate --write`, which never edits prose. Details are in
`ai-factory/contracts/README.md`.

For a small, well-understood local change the full chain is overhead: `/t4:quick` makes
the change with focused checks and a self-review it labels as such, and hands back to the
chain when the change turns out to touch authorization, public contracts, migrations,
dependencies or service ownership.

## Project archetype

This is the archetype-**neutral** base: it assumes only a git repo and adds no runtime
dependency. Node, Bash, Git and a configured AI CLI are the host prerequisites, and
verification commands are detected rather than assumed to be JavaScript. Overlay plugins
specialize it for an archetype by filling the `{{…_extra}}` slots in its templates, so a
stack-specific factory inherits the whole chain above and only supplies what differs.

Two optional paths reach outside the repo and are inert until configured: a tracker
(`ai-factory/jira.yaml`, which makes `/t4:spec ABC-12` resolve a ticket key) and a
read-only knowledge source (`ai-factory/knowledge_base.md`, an MCP server or knowledge base
that the explorer, specifier, planner, analyst, architect and reviewer cite as external and
unverified).

## Also included

| Kind | Artifacts |
| --- | --- |
| Skills | `ai-layout` (where an AI-related file belongs), `ai-hooks` (run logging, dont-touch guard) |
| Setup commands | `/t4:adopt-sdlc`, `/t4:doctor`, `/t4:state` (`--done`, `--next`), `/t4:setup-tracker`, `/t4:setup-knowledge`, `/t4:sync-sdlc` |
| Other loop commands | `/t4:quick`, `/t4:fleet`, `/t4:fix`, `/t4:chore`, `/t4:report` |
| Hooks | session / edit / test-command / usage logging to `ai-factory/runs/`, one row per concluded subagent; dont-touch guard — for Claude Code (`hooks/hooks.json`) and Codex (`hooks/codex.json`) |
| Headless runner | `make -f ai-factory/make/ai.mk ai TASK=<task> INPUT="…"`, no root Makefile needed |
| Review gate | `make -f ai-factory/make/ai.mk review`, advisory by default, `GATE_ENFORCE=1` to block |
| Cost report | `make -f ai-factory/make/ai.mk cost`, token spend by task, agent, branch and day |
| Model selection | `ai-factory/models.yaml`: optional model per tool and for review, plus pricing; opt-in per-task routing for headless and interactive tasks |
| Conventions | commit `ai(<task>): …`, MR labelled `ai-assisted` |

## Where the work is left

`/t4:state` lists every outstanding spec and plan, each plan with its incomplete steps. It
is read-only and deterministic, so two people on the same commit get the same answer.
`--done` lists only finished items. `--next` names the one item to pick up, chosen by git
commit date. Steps a plan explicitly withdraws are not counted as pending.

## Headless runs and the review gate

The same tasks run without an interactive session, for scripts and CI:

```
make -f ai-factory/make/ai.mk ai TASK=quick INPUT="…"   # any task
make -f ai-factory/make/ai.mk review                    # the reviewer, headless
```

`review` reads staged, unstaged and nonignored untracked changes by default.
`REVIEW_SCOPE=branch` reviews the committed branch instead, and supplied input is reviewed
as given. The gate is advisory unless `GATE_ENFORCE=1`. It then passes only a schema-valid
`approve` with no blockers; `request_changes`, a malformed verdict or a missing one fails.

With contracts enabled, `make -f ai-factory/make/ai.mk contracts [DELIVERY=…] [JSON=1]` validates
the handoff chain read-only, and `make -f ai-factory/make/ai.mk verify DELIVERY=… [STEP=S<N>]
[PHASE=red|step|final]` runs a step's declared commands without a shell and records the outcome
(`passed`, `failed`, `not_run` or `unavailable`). `make -f ai-factory/make/ai.mk review DELIVERY=…`
also records review evidence bound to the exact gated output, including its findings.

`make -f ai-factory/make/ai.mk delivery-report DELIVERY=…` is the headless form of `/t4:report`.
It writes `ai-factory/reports/<id>/completion.md` and `completion.json` with one status —
`ready`, `incomplete`, `blocked` or `unverified` — and every reason with its evidence. It exits 0
only when the delivery is `ready`, so it works as a CI gate. It runs no check and publishes
nothing, and its MR description is a draft. The `completion` block in the contracts config
decides:
- whether review is required;
- which finding severities block;
- whether human attestations (`contracts.js attest`) may count.

Opt-in lifecycle telemetry works alongside the review gate. It is enabled with
`"lifecycle": {"enabled": true}` in the contracts config. Headless runs, and interactive tasks
that bracket their work with `lifecycle.js start`/`end`, emit local events.
`make -f ai-factory/make/ai.mk lifecycle` then reports per-delivery elapsed, waiting and active
time, retries, outcomes, tokens and cost coverage. Only explicitly associated runs count;
everything else is shown as unattributed, and nothing measured is shown as zero.

`TOOL=claude|codex` picks the CLI. The model comes from an explicit `MODEL=…`, then
`ai-factory/models.yaml` (a `routing.tasks.<task>` entry when routing is enabled, `review:` for
reviews, then the tool's entry), then whatever the CLI is already configured with. Blank entries
inherit, so any provider or gateway works. With routing enabled the same mapping applies to
interactive `/t4:<task>` and `$t4-<task>`: the task runs in a generated worker agent pinned to
that model (`sync-adapters.sh --adapters=routing`), and a task that cannot be honored stops
instead of running on the chat's model.

## Run and cost accounting

The hooks write a 17-column run log with one row per turn and one per concluded subagent.
Rows collect in `log.pending.csv` and move into the committed `ai-factory/runs/log.csv` on
`git commit`. The `task` column records the `/t4:` command that started the
session, and the `agent` column records which agent spent the tokens. Rows are increments,
so they add up. A usage record copied into several transcripts is counted once.

`make cost` groups that spend by task, agent, branch and day. `JSON=1` or `TSV=1` prints
the same numbers for other tools. Prices come from `models.yaml`; a cost the table could
not price is marked `~` as an estimate. Codex rows carry tokens but no cost.

Lifecycle telemetry is a separate, opt-in layer on the same accounting, and it leaves the run log
and `make cost` exactly as they are. Runs, phases and waits are recorded explicitly, and each
counted usage record is linked to at most one run.
- **What it reports.** `make -f ai-factory/make/ai.mk lifecycle` gives per-delivery elapsed time as
  an interval union, active and waiting time, agent effort, retries, outcomes, tokens and cost.
- **Cost** is a known subtotal plus an unpriced remainder, each with its provenance.
- **Unknown stays unknown.** Anything unmeasured, or not explicitly attributed, is shown as unknown
  or unattributed, never as zero.

## Safety

- The dont-touch guard checks the real target of every edit, including Codex patch
  targets, rename destinations, symlinks and nested directories. A missing or malformed
  policy in an adopted repo blocks edits instead of allowing them.
- The runner passes configuration values as data, never as shell. `CMD` must name one
  executable. Each run gets private scratch space.
- Hook and runner writers refuse symlinked or shared destinations.

The guard adds a layer of protection but is not a sandbox. The host's own sandbox still
governs arbitrary shell commands.

## Hosts

Claude Code and Codex run the same procedures. The plugin ships all 22 `/t4:` commands
natively for Claude Code and the matching `$t4-<task>` skills for Codex; each loads the
repo's own `ai-factory/tasks/<name>.md`, so project customizations are kept. Built-in tasks
need no project pointers — `/t4:sync-sdlc` generates them only for project-specific tasks
and for opt-in hosts such as Cursor.

## Install

Claude Code:

```
git clone git@git.epam.com:volodymyr_tanin/ai-sdlc-plugin.git
claude --plugin-dir ./ai-sdlc-plugin
```

Codex: `codex plugin marketplace add /absolute/path/to/ai-sdlc-plugin`, then
`codex plugin add t4@sdlc`, and restart the session.

Then, once per repo: `/t4:adopt-sdlc` to add the `ai-factory/` layout, `/t4:doctor` to
report what is still wrong. Full walkthrough with a worked example:
[ai-factory/docs/workflow.md](ai-factory/docs/workflow.md).

Working on the plugin itself: `make check` at the repo root runs its whole regression
suite and stops at the first failure.
