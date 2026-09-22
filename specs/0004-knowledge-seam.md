# 0004 — Agents read a repo-declared knowledge source, behind one seam

Summary: an adopted repo may declare external knowledge sources — an MCP server the developer's
tool has attached, or a knowledge base — in `ai/knowledge_base.md`; agents the seam document
names read them, cite what they used as external and unverified, never write to them, and carry
on with one report line when a declared source cannot be reached. A repo that declares nothing
is byte-identical to today.

Implements `ai/analyses/0001-root-mode-step-agents-orchestrator-knowledge.md` EPIC-001
(US-001…US-004, FR-001…FR-010) under `docs/adr/0007`, which extends `docs/adr/0004`: no repo
or runtime dependency; configuration opens the door, never an argument's shape; one seam
document, and a prompt may name that document and nothing else.

## User story
As a developer whose team keeps decisions, runbooks and product facts outside the repo, I want
the agents to read those sources when I say they exist and to tell me which statements came
from there, so that an exploration or spec reflects what the team already knows without
letting an outside document outrank the code — and so that a repo that never asked for this
sees nothing change.

## Acceptance criteria

- **AC1** Given a repo adopted at the release version with no `ai/knowledge_base.md`, When any
  `/t4:*` task or agent runs, Then its artefact and its report contain no reference to a
  knowledge source, a seam, a declaration or a provider, and are identical to the same run on
  the previous release apart from the artefact number and date.
- **AC2** Given the same repo with an `ai/knowledge_base.md` that is empty, comment-only,
  has no table, has a table with no rows, or has a row missing a required field, When any task
  runs, Then behaviour is identical to AC1. Fail closed: a broken declaration is unconfigured.
- **AC3** Given a repo with a valid declaration and a reachable declared source, When a task
  whose executor the seam document lists runs, Then every fact taken from the source appears
  in the artefact labelled with the source's declared `name` and *external, unverified*, is
  never presented as verified against the code or as a supplied fact, and the report lists the
  sources consulted.
- **AC4** Given the same, When the code, a context doc or an accepted ADR disagrees with the
  source, Then the artefact follows the repo and records the disagreement as an open question
  naming the source; it does not side with the source.
- **AC5** Given the same and a source that also offers create, update, delete, comment or
  transition operations, When the task runs, Then no such operation is invoked, verified from
  the tool-call transcript. There is no configuration key that turns writing on.
- **AC6** Given the same and a source whose returned text reads as an instruction, When the
  agent reads it, Then the artefact treats it as quoted content and the agent's behaviour,
  output files and report are unchanged by it.
- **AC7** Given a valid declaration and a runtime in which a declared source cannot be reached
  — no MCP connection, Codex, headless, timeout, mid-query error — When a task runs, Then the
  artefact is written, the report carries exactly one line naming the source not consulted and
  why, no question is asked, and the task does not retry beyond what the tool does itself.
- **AC8** Given the same in headless mode, When `make ai TASK=<any task> …` runs, Then it
  exits 0 and writes a row to `ai/runs/log.csv`.
- **AC9** Given a task whose executor the seam document does not list — `tester` and, for
  now, `run` (decision 1) — When it runs in a configured repo, Then it consults no
  declared source and its artefact carries no external label.
- **AC10** Given the plugin's templates, When `ai/tasks/*.md`, `commands/*.md`, `agents/*.md`,
  the generated adapters and `skills/ai-layout/templates/ai/agents/*.md` are searched for the
  declaration filename, "MCP", a knowledge provider or product name, a URL or a query syntax,
  Then the only file that matches is the seam document itself.
- **AC11** Given `skills/ai-layout/scripts/check-adapters.sh`, When a task prompt, plugin
  command or generated adapter is given a term from the knowledge banned list, Then the check
  fails naming the file and line; with the term removed it passes. The list carries at least
  the declaration filename, which the existing `\.yaml` pattern does not catch.
- **AC12** Given the seam document, When it is read, Then it states: what "configured" means
  for `ai/knowledge_base.md` and the required fields of a source row; each supported `kind`
  and what "read" means for it; per runtime — Claude Code, Codex, headless — which kinds can be
  reached; which executors consult a source; and that the declaration carries identity only
  and credentials stay in the developer's tool configuration. Its filename carries no vendor,
  product or protocol name.
- **AC13** Given an example declaration in the seam document or the templates, When it is
  read, Then it contains no token, secret or endpoint that carries a secret, and the synthetic
  `name` values are visibly not real systems.
- **AC14** Given a configured repo, When `/t4:doctor` runs, Then one line says the knowledge
  seam is configured and names no provider; given an unconfigured repo whose layout has the
  seam document, the line says it is not configured; given a layout that predates the seam
  document, the line says so and names `/t4:sync-sdlc`.
- **AC15** Given a repo adopted before this release, When `/t4:sync-sdlc` runs, Then the seam
  document appears as a new upstream file and no existing file is reported changed by this
  feature except the task and agent prompts that now name the seam document.

## Out of scope
- Writing anything back to a declared source. `docs/adr/0007` defers it outright; a new ADR
  would be needed, not a key.
- A command that writes `ai/knowledge_base.md` for the developer, the way `/t4:setup-tracker`
  writes the tracker file. Hand-written for now.
- Caching or storing query results anywhere under `ai/`; the artefact keeps only what it cites.
- The tracker seam (`ai/docs/tracker.md`): unchanged; its stop-and-ask on a missing ticket
  stays, and the seam document explains why the two behaviours differ.
- Root mode (EPIC-004) and the step agents (EPIC-002): a source declared at a workspace root,
  and whether an `implementer` agent consults one, wait for their own specs.

## Decisions
Answered by the owner (tanin) on 2026-09-22, each taking the pack's proposal. Recorded here so
the plan can build on them; the pack's registers (Q-010, Q-018, Q-019) cite this section.

1. **Executors that consult a source:** the `explore`, `spec` and `plan` tasks, and the
   `analyst`, `architect` and `reviewer` agents. The `tester` never does (`docs/adr/0007`). The
   `implementer` is decided in the step-agents spec (EPIC-002), not here; until then `/t4:run`
   consults nothing.
2. **Banned-term list:** the declaration filename `knowledge_base.md`, plus the name of every
   provider or product the seam document itself names. "MCP" and "knowledge base" are not
   banned: both are legitimate prose that `agents/analyst.md` already uses, and the seam is
   held by the filename and the provider names, which is where a leak would show.
3. **Seam document:** `ai/docs/knowledge.md`.
4. **"Configured"** means `ai/knowledge_base.md` exists and contains one markdown table with
   columns `name` (required, non-empty, unique in the file), `kind` (required; values fixed by
   the seam document) and `use` (optional free text), with at least one row. A row whose `kind`
   is unknown is ignored and named in the report; a duplicate `name` makes the file
   unconfigured; absent, empty, no table or no rows is unconfigured.
5. **Reachability per kind:** for an MCP server, the server is in the tool session's attached
   list; for a knowledge base reached by a declared tool name, that tool exists in the session.
   The one report line names the source and which of these failed, or the error the tool
   returned.
6. **The reviewer may consult a source.** A source describes intended behaviour, not the
   implementation, so it does not compromise the independence the reviewer exists for.

## Open questions
None. A spec with open questions is not buildable; this one is.

## Data touched
- New template `ai/docs/knowledge.md` — the seam document, shipped to every adopted repo as
  new upstream.
- `ai/knowledge_base.md` in the adopting repo — hand-written, identity only; whether it is
  committed or gitignored is the adopter's choice, as for the tracker file.
- No new fields in `ai/runs/log.csv`; no stored query results.

## Routes touched
None. The plugin has no application surface; the "routes" here are the task prompts and
agents that gain one sentence naming the seam document: `ai/tasks/explore.md`,
`ai/tasks/spec.md`, `ai/tasks/plan.md`, `ai/tasks/analyse.md`, `ai/tasks/design.md`,
`ai/tasks/check.md` (decision 1), and `commands/doctor.md` for AC14.

## Components likely involved
- `skills/ai-layout/templates/ai/docs/` — the seam document.
- `agents/analyst.md`, `agents/architect.md`, `agents/reviewer.md` and their template stubs —
  a "What you read" line for the seam document and the provenance label.
- `skills/ai-layout/scripts/check-adapters.sh` — the knowledge banned-term list and its test
  cases; `skills/ai-layout/scripts/check-doctor.sh` — a configured / unconfigured / predates
  case for AC14.
- `commands/doctor.md` — the one line.
- `docs/workflow.md`, `skills/ai-layout/SKILL.md`, `ai/docs/fleet.md` Boundaries and both
  manifest descriptions — the wording `docs/adr/0007` proposes for the narrowed standalone
  claim; `CHANGELOG.md` and a version bump in every manifest.
