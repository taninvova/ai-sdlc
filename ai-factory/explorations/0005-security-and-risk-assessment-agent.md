# 0005 — Security and risk assessment agent

## Request
Add a ninth step agent to the plugin, plus a way to invoke it, that assesses one target
(a spec, a plan, or a change: working tree, branch or supplied diff) for security threats
(authorization, data exposure, secrets, injection, dependency/supply chain) and delivery
risk (migrations, rollback, blast radius), and reports each finding with a severity and a
mitigation. The exploration has to settle four things: where it fits in the loop (its own
command, part of `/t4:check`, a gate before `/t4:plan`, or a requirement of the spec 0021
assurance presets), what it writes, and whether it is read-only.

## What exists today
- **Agents.** `agents/*.md` are the canonical procedures. Adopted repos get copies in
  `ai-factory/agents/`, and the plugin registers each one as `t4:<name>`
  (`skills/ai-layout/templates/ai-factory/make/sync-adapters.js:68-77` has a hard-coded
  `nativeClaudeAgents` set). Either an agent is read-only (`reviewer`: tools
  `Read, Grep, Glob, Bash`, JSON verdict) or it writes into exactly one workspace directory
  (`explorer` writes `explorations/`, `analyst` writes `analyses/`, `architect` writes
  `designs/` and `adr/`).
- **Security coverage today.** `agents/reviewer.md` check 6 covers "Security — unvalidated
  input, secrets, privilege, injection" and check 7 covers "Operability … migrations". Both
  apply only to a diff, and come sixth and seventh in priority. Nothing assesses a spec or a
  plan for threats. `agents/planner.md:32` asks for "Risks and how each is checked", but
  that list has no fixed categories.
- **Risk routing.** `tasks/start.md:26-28` and `tasks/quick.md:16-18` already treat
  authorization, migrations, dependencies and public contracts as triggers that force planned
  work. They only route the request; they do not assess it.
- **Severity and verdict machinery.** `make/gate.js:28` accepts `blocker|major|minor` only,
  and `GATE_ENFORCE=1` fails on any blocker. Per spec 0012, unknown fields in a verdict are
  ignored, so an optional `category` field would stay compatible with the gate.
- **Assurance.** `make/assurance.js` resolves `light|standard|strict` into
  `review_required`, `review_independence` and completion rules. Spec 0021 lists "new agents"
  as **Out of scope**, and its presets know nothing about threat assessment.
- **Precedent for adding an agent.** `analyst` (CHANGELOG 0.25.0) shipped as a new agent
  file, a task template, a `.gitkeep` workspace directory and generated `commands/` and
  `codex-skills/` wrappers. Adopted repos got new files only, so it was not breaking.
- **Constraint.** Spec 0012 AC10 says checks reach no external integration or package
  download. Running `npm audit`-style tools would therefore be a new network behaviour.
- `/t4:check` explicitly never launches another review (`tasks/check.md`).

## Options
**A. A read-only `/t4:assess` that reports JSON and writes nothing.**
New `agents/assessor.md` (tools without Write) and `tasks/assess.md`. It takes a spec path,
a plan path or a review scope and returns one JSON object in the reviewer's shape, with
`category` and `mitigation` added to each finding.
- Changes: agent file, task template, generated wrappers, `nativeClaudeAgents`,
  `plugin.json` descriptions, `docs/workflow.md` ("eight agents"), CHANGELOG.
- Effort: S–M. It is a copy of the reviewer pattern with no new artefact.
- Risks: findings live only in chat or the run log. A mitigation for a spec cannot reach the
  planner except by the developer pasting it in.
- Later: an output that `gate.js` can parse would make headless gating cheap.

**B. A `/t4:assess` that writes one artefact (`ai-factory/assessments/<NNNN>-<slug>.md`) and nothing else.**
Same agent and task as A, but the assessor may write only into `assessments/`, like explorer
and analyst. The file holds the target, the categories assessed, a findings table
(id · category · severity `blocker|major|minor` · evidence path · mitigation) and residual
risks. The specifier and the planner read the assessment when one exists for the feature.
A planner would turn each mitigation into a step or a risk check.
- Changes: everything in A, plus `templates/ai-factory/assessments/.gitkeep`, the workspace
  list in `check-entrypoints.sh:62-63`, one paragraph each in `agents/planner.md` and
  `agents/specifier.md`, and docs.
- Effort: M. The new directory has to be wired into manifest and sync, and the reading rule
  needs a before/after run.
- Risks: two places now talk about security, this and reviewer check 6. The procedure has to
  say which owns what.
- Later: makes D straightforward, because there is a durable record to require. Adopted repos
  get new files only, so it is not breaking.

**C. No new agent: deepen `/t4:check`.**
Expand reviewer checks 6 and 7 into a fixed category list (the eight in the request) and add
optional `category` and `mitigation` fields. Optionally add an `--assess` focus argument.
- Changes: `agents/reviewer.md`, `tasks/check.md`, `check-review-gate.sh` fixtures.
- Effort: S.
- Risks: it covers diffs only, never a spec or a plan, so "before /t4:plan" is impossible.
  Security also competes with correctness inside one review budget. This changes the template
  of the most-used agent in every adopted repo.
- Later: it is the quickest to undo. It also keeps the agent count down.

**D. A security assessment as an assurance requirement.**
Add an assessment evidence kind (a schema under `contracts/schema/`, recorded by
`contracts.js`). `strict` (and possibly `standard`) would require a fresh assessment with no
open blocker before completion, and `delivery-report.js` would show it.
- Changes: assurance.js, contracts.js, a new schema, delivery-report.js, the runner,
  check-assurance and check-contracts fixtures, plus an agent from A or B.
- Effort: L. It needs a new spec that extends 0021, whose scope excludes new agents.
- Risks: a structural "assessment exists" check can pass off a weak assessment as assurance.
  It only reaches repos with contracts enabled.
- Later: this is the only option that can enforce anything. It needs an ADR-level decision on
  what counts as proof.

## Comparison
| Option | Effort | Risk | Reversibility | Fits architecture.md | Recommendation |
|---|---|---|---|---|---|
| A read-only `/t4:assess`, JSON | S–M | low | high (new files only) | yes | fallback |
| B `/t4:assess` writing `assessments/` | M | low–medium (overlap with reviewer) | high (new files only) | yes (one workspace dir, like analyst) | **recommended** |
| C deepen `/t4:check` | S | medium (diff-only, changes reviewer template) | high | yes | no: misses spec and plan |
| D assurance requirement | L | medium–high (structural ≠ real) | low (schema and evidence) | yes, but needs a spec extending 0021 | later, on top of B |

## Recommendation (opinion)
Option B: a standalone `/t4:assess <spec|plan|working-tree|branch>` backed by an `assessor`
agent.
- **What it writes:** `ai-factory/assessments/` only. Toward code, specs, plans and evidence it
  is read-only, and it runs no network or dependency-audit tools.
- **What it reports:** severity uses the existing `blocker|major|minor` scale. Every finding
  carries a category and a mitigation.
- **Where it fits:** an optional step between `/t4:spec` and `/t4:plan`. It may also run on the
  diff before `/t4:check`. The planner turns its mitigations into steps and risks.
- **What it does not do (yet):** gate anything. Reviewer check 6 stays as it is.

Reasons:
- It is the only option that covers all three targets the request names.
- It leaves a durable record the loop's next step can read.
- It follows the analyst precedent, which shipped without breaking anything.
- It keeps D available without committing to enforcement now.

What would change my mind:
- If the owner wants this only on diffs, C is enough.
- If findings must not persist (sensitive threat detail committed to the repo), use A.
- If the driver is compliance, so a strict delivery must not complete without an assessment,
  then B plus D should be specified together.

## Open questions
1. Does an assessment that names exploitable paths belong in a committed `ai-factory/`
   directory, or should it go in `runs/` (which is gitignored)? This decides between A and B.
2. Numbering: should an assessment reuse the spec or plan number it assesses (like plans do),
   or take the next free number of its own?
3. Should `/t4:start` (rule 3) or `/t4:plan` *suggest* `/t4:assess` when a risk trigger is
   present? A suggestion, not a gate.
4. Should reviewer check 6 defer to an existing assessment, or stay independent of it?
5. The agent's name: `assessor`, `security`, or something else? It becomes `t4:<name>` and
   `/t4:assess`.
6. Is a dependency or supply-chain check allowed to run local lockfile inspection only, given
   spec 0012 AC10?

## Next
`/t4:spec Add an assessor agent and /t4:assess task that assesses a spec, plan or change for security threats and delivery risk and writes ai-factory/assessments/ only (exploration 0005, option B)`
