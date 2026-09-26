# 0005 — Step agents: explorer, specifier, planner, implementer

Summary: the four loop steps `/t4:explore`, `/t4:spec`, `/t4:plan` and `/t4:run` each run in an
agent of their own — `explorer`, `specifier`, `planner`, `implementer` — so every step starts
from its inputs rather than from the developer's chat, and so an orchestrator has units to call.
The task prompts keep what only a session can do: refuse an empty argument, ask a question, and
relay the report. Codex, which cannot run subagents, gets the inline note it already gets for
the five agent-backed tasks. The dont-touch guard must be shown to hold inside the implementer.

Implements `ai/analyses/0001-root-mode-step-agents-orchestrator-knowledge.md` EPIC-002
(US-005…US-007, FR-011…FR-021) under DEC-002 (four step agents only; fleet, fix and chore stay
in the session; reviewer, tester, architect and analyst unchanged) and DEC-010 (hooks fire for
a subagent's tool calls; the session row does not carry subagent tokens). It precedes the
orchestrator (EPIC-003), which calls these agents.

## User story
As a developer running the loop, I want each step to be done by an agent that reads the
artefacts and nothing else, so that a spec is not shaped by twenty minutes of chat that never
reached the exploration, a plan is not shaped by the spec's drafting, and a step is
implemented from the plan alone — and so that the step I delegate is still the step I get back,
with the same questions asked and the same report.

## Acceptance criteria

- **AC1** Given the release, When `agents/` is listed, Then `explorer.md`, `specifier.md`,
  `planner.md` and `implementer.md` exist, each with frontmatter `name:` equal to the filename
  stem, `model: inherit`, and `tools:` no wider than Read, Grep, Glob, Write, Edit, Bash; and
  `skills/ai-layout/templates/ai/agents/` holds a project stub for each in the shape of the
  existing stubs.
- **AC2** Given the four task prompts, When read, Then `explore.md`, `spec.md`, `plan.md` and
  `run.md` each carry the exact phrase ``Delegate to the `<agent>` subagent`` naming its agent,
  and `bash ai/make/sync-adapters.sh` followed by `check-adapters.sh` passes with the Codex
  inline note present in `.codex/skills/t4-{explore,spec,plan,run}/SKILL.md`, naming
  `ai/agents/{explorer,specifier,planner,implementer}.md`. Nine of the twelve generated Codex
  skills then carry a note.
- **AC3** Given each step agent's prompt, When read, Then it names one write target and forbids
  the rest: explorer writes `ai/explorations/` only and never code; specifier writes `specs/`
  only, never the plan or code; planner writes `ai/plans/` only, never code; implementer writes
  source, tests and the one checkbox of the step it was given, and never starts the next step.
  Every prohibition the four task prompts state today appears in the corresponding agent.
- **AC4** Given a scratch repo, When `/t4:spec add CSV export to the reports page` runs under
  Claude Code, Then the transcript shows a `specifier` invocation, the spec is written where
  the task says, and the report is the spec path plus the open questions, unchanged in shape.
  The same holds for `/t4:explore` (path and recommended option), `/t4:plan` (path and
  ambiguities) and `/t4:run` (files changed, tests, what the plan got wrong).
- **AC5** Given `/t4:plan` with nothing after the command name and two files in `specs/`, When
  it runs, Then the main session asks which spec, lists both paths, and invokes no agent. The
  same holds for the other three tasks with an empty argument.
- **AC6** Given a step agent reaches a point its prompt resolves by asking — a spec argument
  that is a configured tracker key resolving to nothing, a plan asked for with several specs
  and none named, a run step whose tests cannot be made green — When it stops, Then it writes
  no artefact for that decision and returns the question in its report; the task then asks the
  developer in an interactive session, or reports and stops in a headless one. Nothing is
  guessed.
- **AC7** Given `/t4:run <plan> step N` where the tests cannot be made green, When the
  implementer stops, Then the step's checkbox is not ticked and the report says why.
- **AC8** Given a scratch repo whose `ai/docs/dont-touch.md` lists `prisma/migrations/` and a
  plan step that would write there, When the implementer attempts the write under Claude Code,
  Then the write is blocked with the guard's message, exactly as a main-session edit is. This is
  the run that verifies DEC-010's first half, which is a supplied fact until it is run.
- **AC9** Given a session that delegated a step, When it ends and commits, Then
  `skills/ai-hooks/SKILL.md` and `docs/workflow.md` §9 state that tokens spent inside a subagent
  are not in the session's `log.csv` row, and the row is still written.
- **AC10** Given the MR diff, When reviewed, Then `agents/reviewer.md`, `agents/tester.md`,
  `agents/architect.md`, `agents/analyst.md` and their project stubs are unchanged.
- **AC11** Given `ai/models.yaml`, When read, Then it has no new key: the four agents use
  `model: inherit` and the tool's configured model applies.
- **AC12** Given `ai/docs/knowledge.md`, When read, Then its list of executors that consult a
  declared source names the `explorer`, `specifier` and `planner` agents in place of the
  explore, spec and plan tasks, and states that the implementer does not consult one (decision 1);
  and `check-adapters.sh` still passes, since the agents' prompts name only the seam document.
- **AC13** Given `docs/workflow.md`, When read, Then §5 lists all eight agents with one line
  each, §8's Codex table names all eight as inlined, and the decision tree and command table
  are otherwise unchanged.
- **AC14** Given a repo adopted at 0.26.0, When `/t4:sync-sdlc` runs at this release, Then it
  reports the four task prompts as upstream changed and the four agent stubs as new upstream,
  and nothing else from this feature; a repo that had edited one of the four prompts sees it
  reported as both changed, to merge by hand.

## Out of scope
- Agents for `/t4:fleet`, `/t4:fix` and `/t4:chore` (DEC-002).
- The orchestrator that drives these agents (EPIC-003, its own spec).
- Recovering subagent token usage into the session row, for example through a SubagentStop
  hook (PROP-013). AC9 documents the under-count; closing it is a later change.
- Any change to what the four steps produce. This moves where each step runs, not what it
  writes; the artefact formats and report shapes are those of the task prompts today.
- Restricting an agent's write paths through `tools:`. Claude Code cannot express "write only
  `specs/`"; the scope is prompt-enforced plus the guard (RISK-002), which AC8 verifies.

## Decisions
Answered by the owner (tanin) on 2026-09-22, each taking the proposal.

1. **The implementer does not consult a declared knowledge source.** A source shapes what is
   built, which is settled before the plan exists; an implementer that reads a wiki mid-step can
   drift from the plan it was given. `ai/docs/knowledge.md` says so (AC12), and the seam's
   executor list is: explorer, specifier, planner, analyst, architect, reviewer.
2. **Not a breaking release.** An adopter who edited one of the four task prompts sees it
   reported as changed on both sides and merges by hand, as the 0.19.0 precedent handled edited
   prompts. The CHANGELOG says so.
3. **Tests the implementer cannot find or run:** stop and explain, naming the command it tried
   and what it could not find; the checkbox stays unticked. AC7 covers the red case and this
   extends it to the absent case.
4. **Headless reach is measured, not assumed.** One headless `make ai TASK=explore` run in the
   scratch repo is part of the AC4 evidence and reported either way. It does not block the
   interactive path.

## Open questions
None. A spec with open questions is not buildable; this one is.

## Data touched
- Four new agent files in `agents/` and four project stubs in the templates.
- Four task prompts in the templates, each losing the steps that move into its agent and
  gaining the delegation line; their empty-argument paragraph and their report stay.
- `ai/docs/knowledge.md` executor list (AC12); `skills/ai-hooks/SKILL.md` and
  `docs/workflow.md` §9 (AC9); `docs/workflow.md` §5 and §8 (AC13).
- No change to `ai/runs/log.csv` columns, `ai/models.yaml` or `hooks/hooks.json`.

## Routes touched
None. The surfaces are the four slash commands and their generated Codex skills, which
`sync-adapters.sh` regenerates from the task prompts (AC2).

## Components likely involved
- `agents/explorer.md`, `agents/specifier.md`, `agents/planner.md`, `agents/implementer.md` —
  new; each carries the reading list, the steps and the prohibitions of its task prompt today.
- `skills/ai-layout/templates/ai/agents/{explorer,specifier,planner,implementer}.md` — stubs.
- `skills/ai-layout/templates/ai/tasks/{explore,spec,plan,run}.md` — delegation, relay, the
  empty-argument refusal kept in the session.
- `skills/ai-layout/scripts/check-adapters.sh` — no change expected; its delegation assertions
  already cover any task that delegates (AC2).
- `skills/ai-hooks/scripts/guard-paths.js` — no change expected; AC8 is the run that proves it.
- `skills/ai-layout/templates/ai/docs/knowledge.md` and this repo's copy — executor list.
- `docs/workflow.md`, `skills/ai-hooks/SKILL.md`, `skills/ai-layout/SKILL.md`, `README.md`,
  `CHANGELOG.md` and the three manifests.
